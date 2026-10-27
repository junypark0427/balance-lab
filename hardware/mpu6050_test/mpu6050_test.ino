// Electrical safety must be confirmed BEFORE connecting/powering the sensor.
// No I2C activity until the serial command START is received.
#include <Wire.h>
#include <math.h>
#include <string.h>

#if !defined(__AVR_ATmega32U4__) || F_CPU != 16000000L
#error Select SparkFun Pro Micro / ATmega32U4 (5V, 16 MHz)
#endif

uint8_t sensorAddress = 0;
bool running = false, filterReady = false;
float rollFiltered = 0, pitchFiltered = 0;
uint32_t lastSample = 0, lastPrint = 0;
char command[16];
uint8_t commandLength = 0;
bool commandOverflow = false;

bool writeRegister(uint8_t reg, uint8_t value) {
  Wire.clearWireTimeoutFlag();
  Wire.beginTransmission(sensorAddress);
  Wire.write(reg);
  Wire.write(value);
  uint8_t result = Wire.endTransmission();
  return result == 0 && !Wire.getWireTimeoutFlag();
}

bool readRegisters(uint8_t reg, uint8_t *data, uint8_t count) {
  Wire.clearWireTimeoutFlag();
  Wire.beginTransmission(sensorAddress);
  Wire.write(reg);
  uint8_t result = Wire.endTransmission(false);
  if (result != 0 || Wire.getWireTimeoutFlag()) return false;
  uint8_t received = Wire.requestFrom(sensorAddress, count, (uint8_t)true);
  if (received != count || Wire.getWireTimeoutFlag()) {
    while (Wire.available()) Wire.read();
    return false;
  }
  for (uint8_t i = 0; i < count; ++i) data[i] = Wire.read();
  return true;
}

void stopTest() {
  running = false;
  filterReady = false;
  Wire.end();
}

bool startTest() {
  Wire.begin(); // AVR enables VCC pullups: use a verified safe interface.
  Wire.setClock(100000UL);
  Wire.setWireTimeout(25000UL, true);
  sensorAddress = 0;
  for (uint8_t address = 0x68; address <= 0x69; ++address) {
    Wire.clearWireTimeoutFlag();
    Wire.beginTransmission(address);
    uint8_t result = Wire.endTransmission();
    Serial.print(F("Probe 0x")); Serial.print(address, HEX);
    Serial.print(F(": I2C status=")); Serial.println(result);
    if (Wire.getWireTimeoutFlag()) {
      Serial.println(F("ERROR: I2C timeout; check bus wiring/pullups after power-off."));
      return false;
    }
    if (result != 0) continue;
    sensorAddress = address;
    uint8_t identity = 0;
    if (!readRegisters(0x75, &identity, 1)) {
      Serial.println(F("ERROR: WHO_AM_I read failed."));
      sensorAddress = 0;
      continue;
    }
    Serial.print(F("WHO_AM_I: 0x")); Serial.println(identity, HEX);
    if (identity == 0x68) break; // AD0 does not change WHO_AM_I.
    Serial.println(F("ERROR: unexpected identity; not validated as MPU6050."));
    sensorAddress = 0;
  }
  if (sensorAddress == 0) {
    Serial.println(F("ERROR: MPU6050 not found at 0x68 or 0x69."));
    return false;
  }
  // Wake using internal clock; +/-2g, +/-250 deg/s, ~44Hz accel DLPF,
  // 50Hz sample rate (1kHz / (19 + 1)).
  if (!writeRegister(0x6B, 0x00)) return false;
  delay(100);
  if (!writeRegister(0x6C, 0x00) || !writeRegister(0x1A, 0x03) ||
      !writeRegister(0x19, 19) || !writeRegister(0x1B, 0x00) ||
      !writeRegister(0x1C, 0x00)) return false;
  const uint8_t regs[] = {0x6B, 0x6C, 0x1A, 0x19, 0x1B, 0x1C};
  const uint8_t expected[] = {0, 0, 3, 19, 0, 0};
  for (uint8_t i = 0; i < sizeof(regs); ++i) {
    uint8_t actual;
    if (!readRegisters(regs[i], &actual, 1) || actual != expected[i]) {
      Serial.println(F("ERROR: sensor configuration readback failed."));
      return false;
    }
  }
  Serial.print(F("MPU6050 FOUND: 0x")); Serial.println(sensorAddress, HEX);
  filterReady = false;
  lastSample = lastPrint = millis();
  return true;
}

int16_t signedWord(const uint8_t *p) {
  return (int16_t)(((uint16_t)p[0] << 8) | p[1]);
}

void printAxis(const __FlashStringHelper *label, float value,
               const __FlashStringHelper *unit) {
  Serial.print(label); Serial.print(value, 4); Serial.println(unit);
}

void setup() {
  Serial.begin(115200);
}

void loop() {
  static bool announced = false;
  if (!Serial) announced = false;
  if (Serial && !announced) {
    Serial.println(F("BALANCE LAB MPU6050 test / 115200 baud"));
    Serial.println(F("Confirm electrical safety BEFORE powering sensor."));
    Serial.println(F("Send START + newline only after safety confirmation; STOP ends I2C."));
    announced = true;
  }
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      command[commandLength] = '\0';
      if (!commandOverflow && strcmp(command, "START") == 0) {
        stopTest();
        running = startTest();
        if (!running) {
          stopTest();
          Serial.println(F("ERROR: initialization failed. Power off before checking wiring."));
        }
      } else if (!commandOverflow && strcmp(command, "STOP") == 0) {
        stopTest();
        Serial.println(F("STOPPED. Disconnect USB before changing wiring."));
      }
      commandLength = 0;
      commandOverflow = false;
    } else if (commandLength < sizeof(command) - 1) {
      command[commandLength++] = c;
    } else commandOverflow = true;
  }
  if (!running || (uint32_t)(millis() - lastSample) < 20) return;
  lastSample = millis();
  uint8_t data[14];
  if (!readRegisters(0x3B, data, sizeof(data))) {
    stopTest();
    Serial.println(F("ERROR: measurement read failed; test stopped."));
    return;
  }
  float ax = signedWord(data) / 16384.0f;
  float ay = signedWord(data + 2) / 16384.0f;
  float az = signedWord(data + 4) / 16384.0f;
  float gx = signedWord(data + 8) / 131.0f;
  float gy = signedWord(data + 10) / 131.0f;
  float gz = signedWord(data + 12) / 131.0f;
  float norm = sqrtf(ax * ax + ay * ay + az * az);
  if (norm < 0.1f) {
    Serial.println(F("WARN: acceleration magnitude too small for tilt."));
    filterReady = false;
    return;
  }
  float roll = atan2f(ay, az) * 180.0f / PI;
  float pitch = atan2f(-ax, sqrtf(ay * ay + az * az)) * 180.0f / PI;
  if (!filterReady) {
    rollFiltered = roll; pitchFiltered = pitch; filterReady = true;
  } else {
    float delta = roll - rollFiltered;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    rollFiltered += 0.2f * delta;
    if (rollFiltered > 180) rollFiltered -= 360;
    if (rollFiltered < -180) rollFiltered += 360;
    pitchFiltered += 0.2f * (pitch - pitchFiltered);
  }
  if (!Serial || (uint32_t)(millis() - lastPrint) < 200) return;
  lastPrint = millis();
  Serial.print(F("Time ms: ")); Serial.println(lastSample);
  printAxis(F("Accel X: "), ax, F(" g"));
  printAxis(F("Accel Y: "), ay, F(" g"));
  printAxis(F("Accel Z: "), az, F(" g"));
  printAxis(F("Gyro X: "), gx, F(" deg/s"));
  printAxis(F("Gyro Y: "), gy, F(" deg/s"));
  printAxis(F("Gyro Z: "), gz, F(" deg/s"));
  printAxis(F("Roll raw: "), roll, F(" deg"));
  printAxis(F("Pitch raw: "), pitch, F(" deg"));
  printAxis(F("Roll filtered: "), rollFiltered, F(" deg"));
  printAxis(F("Pitch filtered: "), pitchFiltered, F(" deg"));
  printAxis(F("Accel norm: "), norm, F(" g"));
  if (fabsf(norm - 1.0f) > 0.15f)
    Serial.println(F("WARN: dynamic acceleration; tilt may be inaccurate."));
  Serial.println();
}
