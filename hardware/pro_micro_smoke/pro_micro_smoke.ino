// Board-only USB test. Does not initialize I2C or drive sensor pins.
#if !defined(__AVR_ATmega32U4__) || F_CPU != 16000000L
#error Select SparkFun Pro Micro / ATmega32U4 (5V, 16 MHz)
#endif

void setup() {
  Serial.begin(115200);
}

void loop() {
  if (Serial) {
    Serial.print(F("BALANCE LAB BOARD OK | ATmega32U4 | F_CPU="));
    Serial.print(F_CPU);
    Serial.print(F(" | uptime_ms="));
    Serial.println(millis());
  }
  delay(1000);
}
