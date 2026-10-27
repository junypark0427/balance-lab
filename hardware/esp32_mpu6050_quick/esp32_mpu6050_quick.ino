#include <Wire.h>

uint8_t address = 0;
bool ready = false;

bool readBytes(uint8_t reg, uint8_t *data, uint8_t count) {
  Wire.beginTransmission(address);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(address, count) != count) return false;
  for (uint8_t i = 0; i < count; ++i) data[i] = Wire.read();
  return true;
}

bool writeByte(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(address);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}

int16_t word(const uint8_t *p) {
  return (int16_t)(((uint16_t)p[0] << 8) | p[1]);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("ESP32 MPU6050 quick test | SDA=21 SCL=22");
  Wire.begin(21, 22);
  Wire.setClock(100000);
  Wire.setTimeOut(50);
  for (uint8_t candidate = 0x68; candidate <= 0x69; ++candidate) {
    Wire.beginTransmission(candidate);
    uint8_t status = Wire.endTransmission();
    Serial.printf("Probe 0x%02X: status=%u\n", candidate, status);
    if (status != 0) continue;
    address = candidate;
    uint8_t id;
    if (readBytes(0x75, &id, 1)) {
      Serial.printf("WHO_AM_I: 0x%02X\n", id);
      if (id == 0x68) { ready = true; break; }
    }
    address = 0;
  }
  if (!ready) {
    Serial.println("ERROR: MPU6050 not found at 0x68/0x69 with expected identity");
    return;
  }
  ready = writeByte(0x6B, 0) && writeByte(0x1C, 0);
  delay(100);
  uint8_t power, range;
  ready = ready && readBytes(0x6B, &power, 1) && power == 0 &&
          readBytes(0x1C, &range, 1) && range == 0;
  if (!ready) {
    Serial.println("ERROR: MPU6050 initialization failed");
    return;
  }
  Serial.printf("MPU6050 FOUND: 0x%02X\n", address);
}

void loop() {
  if (!ready) {
    Serial.println("ERROR: sensor unavailable; check wiring with power disconnected, then reset");
    delay(2000);
    return;
  }
  uint8_t data[6];
  if (!readBytes(0x3B, data, sizeof(data))) {
    Serial.println("ERROR: acceleration read failed");
  } else {
    Serial.printf("ms=%lu Accel X: %.4f g | Accel Y: %.4f g | Accel Z: %.4f g\n",
      (unsigned long)millis(), word(data) / 16384.0f,
      word(data + 2) / 16384.0f, word(data + 4) / 16384.0f);
  }
  delay(200);
}
