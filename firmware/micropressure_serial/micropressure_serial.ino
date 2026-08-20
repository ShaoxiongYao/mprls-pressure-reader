/*
  USB-serial pressure reader firmware for Adafruit QT Py M0
  + SparkFun Qwiic MicroPressure sensor (Honeywell MPRLS, I2C addr 0x18, via Qwiic cable).

  Protocol (see read_pressure.py):
    host sends byte 0x01  ->  board replies 4 bytes: little-endian float32, pressure in kPa

  Status LED (onboard NeoPixel): green = running, red = sensor not found.

  Build: Arduino IDE / arduino-cli, board "Adafruit QT Py M0 (SAMD21)"
  (Adafruit SAMD board package). Libraries: SparkFun_MicroPressure and
  Adafruit_NeoPixel — ./setup_firmware.sh setup installs everything.
*/

#include <Wire.h>
#include <SparkFun_MicroPressure.h>
#include <Adafruit_NeoPixel.h>

#ifndef PIN_NEOPIXEL
#define PIN_NEOPIXEL 11  // QT Py M0 onboard NeoPixel
#endif

SparkFun_MicroPressure mpr;
Adafruit_NeoPixel pixel(1, PIN_NEOPIXEL, NEO_GRB + NEO_KHZ800);

const uint8_t CMD_READ_PRESSURE = 0x01;

void setColor(uint8_t r, uint8_t g, uint8_t b) {
  pixel.setPixelColor(0, pixel.Color(r, g, b));
  pixel.show();
}

void setup() {
  pixel.begin();
  pixel.setBrightness(16);

  // Native USB CDC: the baud value is ignored by hardware, but the host opens at 921600.
  Serial.begin(921600);
  Wire.begin();
  Wire.setClock(400000);

  while (!mpr.begin()) {   // MPRLS at default address 0x18
    setColor(255, 0, 0);   // red: sensor not found — check Qwiic cable
    delay(250);
    setColor(0, 0, 0);
    delay(250);
  }
  setColor(0, 255, 0);     // green: ready
}

void loop() {
  if (Serial.available() > 0) {
    int cmd = Serial.read();
    if (cmd == CMD_READ_PRESSURE) {
      float kpa = mpr.readPressure(KPA);  // blocks ~5 ms for conversion
      Serial.write((uint8_t*)&kpa, sizeof(kpa));
    }
    // ignore any other byte
  }
}
