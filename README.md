# mprls-pressure-reader

Firmware + Python tools for reading a **SparkFun Qwiic MicroPressure** sensor
(Honeywell **MPRLS**, 0–25 PSI) over USB serial via an **Adafruit QT Py M0**.

Originally built to read the internal air pressure of a bubble tactile gripper,
but nothing here is gripper-specific — it works for any MPRLS use case.

## Hardware

- [Adafruit QT Py M0 (SAMD21)](https://www.adafruit.com/product/4600)
- [SparkFun Qwiic MicroPressure sensor](https://www.sparkfun.com/products/16476)
- One Qwiic (STEMMA QT) cable between them; USB-C to the host.

Each sensor needs its own QT Py — the MPRLS has a fixed I2C address (0x18),
so two sensors cannot share one board's bus. Multiple boards on one host are
supported (see below).

## Setup and flashing

```bash
./setup_firmware.sh setup     # one-time: arduino-cli + Adafruit SAMD core + libraries
./setup_firmware.sh flash     # compile + upload (plug in one board at a time)
```

If the upload cannot find the board, double-tap the QT Py's reset button to
enter the bootloader. The onboard NeoPixel shows **green** when running and
blinks **red** if the sensor is not found on the Qwiic cable.

The script can also be sourced to reuse its functions
(`mpr_setup`, `mpr_compile`, `mpr_flash`, `mpr_find_port`).

## Reading pressure

```bash
pip install pyserial
python read_pressure.py               # auto-detect the board
python read_pressure.py /dev/ttyACM0  # explicit port
python read_pressure.py 0             # index, when several boards are attached
```

Prints absolute pressure (hPa), delta from the baseline captured at startup,
and per-read latency at ~10 Hz. As a library:

```python
from read_pressure import PressureSensor

sensor = PressureSensor()          # or PressureSensor("/dev/ttyACM0"), PressureSensor("1")
p = sensor.get_pressure()          # hPa; ambient is ~1013
delta = p - sensor.base_pressure   # rise above ambient at startup
```

## Protocol

The host writes a single byte `0x01`; the firmware replies with 4 bytes — a
little-endian float32 pressure in **kPa** (one MPRLS conversion, ~5 ms). The
Python side multiplies by 10 to report **hPa**. Any other byte is ignored.
The 921600 baud setting is nominal; the QT Py's native USB CDC ignores it.

## License

MIT (see [LICENSE](LICENSE)). Firmware library dependencies
(SparkFun MicroPressure — MIT, Adafruit NeoPixel — LGPL-3.0) are installed at
setup time by `arduino-cli` and are not redistributed here.
