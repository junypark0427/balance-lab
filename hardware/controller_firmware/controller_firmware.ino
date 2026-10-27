// Build with the VERIFIED GPIO numbers, not board silk-screen D labels.
// Existing hardware/*_test and esp32_mpu6050_quick sketches are unchanged.
#include <Wire.h>
#include <math.h>
#include <esp_system.h>
#include <esp_mac.h>
#if !defined(ARDUINO_ARCH_ESP32)
#error This firmware is for a verified ESP32 board only.
#endif
#if !defined(BALANCE_SDA) || !defined(BALANCE_SCL)
#error Supply verified BALANCE_SDA and BALANCE_SCL build flags.
#endif

char deviceId[24], command[32];
uint8_t commandLength = 0, address = 0;
bool overflow = false, running = false, filterReady = false;
float roll = 0, pitch = 0, bias[3] = {0,0,0}, biasSum[3] = {0,0,0};
uint16_t biasSamples = 0;
bool biasing = false;
uint32_t sequence = 0, lastSample = 0, lastHello = 0, lastRetry = 0;
uint32_t bootId = 0, biasStarted = 0;

float wrap(float a) { while (a > 180) a -= 360; while (a < -180) a += 360; return a; }
int16_t word(const uint8_t *p) { return (int16_t)(((uint16_t)p[0] << 8) | p[1]); }
bool readBytes(uint8_t reg, uint8_t *data, uint8_t count) {
  Wire.beginTransmission(address); Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(address, count) != count) { while (Wire.available()) Wire.read(); return false; }
  for (uint8_t i=0; i<count; ++i) data[i]=Wire.read();
  return true;
}
bool writeByte(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(address); Wire.write(reg); Wire.write(value);
  return Wire.endTransmission() == 0;
}
void hello() {
  Serial.printf("{\"v\":1,\"kind\":\"hello\",\"id\":\"%s\",\"boot\":%lu,\"board\":\"ESP32\",\"pins\":[%d,%d]}\n",deviceId,(unsigned long)bootId,BALANCE_SDA,BALANCE_SCL);
}
void fault(const char *reason) {
  Serial.printf("{\"v\":1,\"id\":\"%s\",\"seq\":%lu,\"ms\":%lu,\"ok\":false,\"error\":\"%s\"}\n",deviceId,(unsigned long)++sequence,(unsigned long)millis(),reason);
}
bool startSensor() {
  Wire.end();
  if (!Wire.begin(BALANCE_SDA, BALANCE_SCL, 100000)) return false;
  Wire.setTimeOut(25);
  address=0;
  for (uint8_t candidate=0x68; candidate<=0x69; ++candidate) {
    address=candidate; uint8_t identity=0;
    if (readBytes(0x75,&identity,1) && identity==0x68) break;
    address=0;
  }
  if (!address || !writeByte(0x6B,0)) return false;
  delay(100);
  const uint8_t regs[]={0x6B,0x6C,0x1A,0x19,0x1B,0x1C};
  const uint8_t values[]={0,0,3,19,0,0}; // +/-2g, +/-250 deg/s, DLPF, 50 Hz.
  for (uint8_t i=0; i<sizeof(regs); ++i) {
    uint8_t actual=255;
    if (!writeByte(regs[i],values[i]) || !readBytes(regs[i],&actual,1) || actual!=values[i]) return false;
  }
  filterReady=false; lastSample=millis();
  return true;
}
void setup() {
  Serial.begin(115200);
  bootId=esp_random();
  uint8_t mac[6]; esp_read_mac(mac, ESP_MAC_WIFI_STA);
  snprintf(deviceId,sizeof(deviceId),"esp32-%02X%02X%02X%02X%02X%02X",mac[0],mac[1],mac[2],mac[3],mac[4],mac[5]);
  hello(); // I2C starts only after the bridge sends START.
}
void loop() {
  while (Serial.available()) {
    char c=Serial.read();
    if (c=='\n' || c=='\r') {
      command[commandLength]=0;
      if (!overflow && !strcmp(command,"HELLO")) hello();
      else if (!overflow && !strcmp(command,"START")) {
        if (!running) { running=startSensor(); if (!running) fault("i2c_init"); }
      } else if (!overflow && !strcmp(command,"STOP")) {
        running=false; Wire.end(); filterReady=false; biasing=false; fault("stopped");
      } else if (!overflow && !strcmp(command,"BIAS") && running) {
        biasing=true; biasSamples=0; biasStarted=millis(); for (int i=0;i<3;++i) biasSum[i]=0;
        fault("calibrating");
      }
      commandLength=0; overflow=false;
    } else if (commandLength<sizeof(command)-1) command[commandLength++]=c;
    else overflow=true;
  }
  uint32_t now=millis();
  if (now-lastHello>=1000) { hello(); lastHello=now; }
  if (!running || now-lastSample<20) return;
  float dt=fminf((now-lastSample)*0.001f,0.1f); lastSample=now;
  uint8_t data[14];
  if (!readBytes(0x3B,data,sizeof(data))) {
    filterReady=false; fault("i2c_read");
    // Retry the configured bus, never probe unrelated GPIO pins.
    if (now-lastRetry>1000) { running=startSensor(); lastRetry=now; }
    return;
  }
  float a[3],g[3];
  for (int i=0;i<3;++i) { a[i]=word(data+2*i)/16384.f; g[i]=word(data+8+2*i)/131.f; }
  float norm=sqrtf(a[0]*a[0]+a[1]*a[1]+a[2]*a[2]);
  if (norm<0.25f || norm>2.5f) { fault("acceleration"); filterReady=false; return; }
  if (biasing) {
    if (now-biasStarted>6000) { biasing=false; fault("calibration_motion"); return; }
    bool still=fabsf(norm-1.f)<0.15f && fabsf(g[0])<8.f && fabsf(g[1])<8.f && fabsf(g[2])<8.f;
    if (!still) {
      biasSamples=0; for (int i=0;i<3;++i) biasSum[i]=0;
      fault("calibrating"); return;
    }
    for (int i=0;i<3;++i) biasSum[i]+=g[i];
    ++biasSamples;
    if (biasSamples>=60) {
      for (int i=0;i<3;++i) bias[i]=biasSum[i]/biasSamples;
      biasing=false; filterReady=false;
    } else { fault("calibrating"); return; }
  }
  for (int i=0;i<3;++i) g[i]-=bias[i];
  float ar=atan2f(a[1],a[2])*180.f/PI;
  float ap=atan2f(-a[0],sqrtf(a[1]*a[1]+a[2]*a[2]))*180.f/PI;
  if (!filterReady) { roll=ar; pitch=ap; filterReady=true; }
  else {
    // Euler-rate correction around upside-down mountings. Avoid the pitch singularity.
    float r=roll*PI/180.f, p=pitch*PI/180.f;
    float cp=cosf(p), dr=g[0], dp=cosf(r)*g[1]-sinf(r)*g[2];
    if (fabsf(cp)>0.15f) dr+=(sinf(r)*g[1]+cosf(r)*g[2])*tanf(p);
    float predicted=wrap(roll+dr*dt), predictedPitch=constrain(pitch+dp*dt,-90.f,90.f);
    float alpha=expf(-dt/0.35f);
    roll=wrap(predicted+(1-alpha)*wrap(ar-predicted));
    pitch=alpha*predictedPitch+(1-alpha)*ap;
  }
  Serial.printf("{\"v\":1,\"id\":\"%s\",\"seq\":%lu,\"ms\":%lu,\"ok\":true,\"roll\":%.2f,\"pitch\":%.2f,\"a\":[%.3f,%.3f,%.3f],\"g\":[%.2f,%.2f,%.2f]}\n",deviceId,(unsigned long)++sequence,(unsigned long)now,roll,pitch,a[0],a[1],a[2],g[0],g[1],g[2]);
}
