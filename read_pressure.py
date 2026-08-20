"""Minimal reader for the SparkFun Qwiic MicroPressure sensor (Honeywell MPRLS)
attached to an Adafruit QT Py M0 running firmware/micropressure_serial.

Protocol: write byte 0x01, read back 4 bytes = little-endian float32 pressure in kPa.

Usage:
    python read_pressure.py               # auto-detect the QT Py M0 port
    python read_pressure.py /dev/ttyACM0  # or give the port explicitly
    python read_pressure.py 0             # with several boards attached: pick by index
                                          # (sorted by USB serial number; run with no
                                          # args once to see the numbered listing)

Requires: pip install pyserial
"""

import struct
import sys
import time

import serial
import serial.tools.list_ports as list_ports

DEVICE_NAME = "QT Py M0"   # matched against the USB port description
BAUD_RATE = 921600
REQUEST = bytes([1])       # firmware command: send one pressure sample
READ_FORMAT = "<f"         # little-endian float32, in kPa


def find_port(device_name: str = DEVICE_NAME, index: int = None) -> str:
    """Find a matching board. With several boards attached, pass index (0, 1, ...);
    matches are sorted by USB serial number so the ordering is stable across replugs."""
    ports = list(list_ports.comports())
    matches = sorted((p for p in ports if device_name in p.description),
                     key=lambda p: p.serial_number or p.device)
    if not matches:
        available = ", ".join(f"{p.device} ({p.description})" for p in ports) or "none"
        raise RuntimeError(f"'{device_name}' not found. Available ports: {available}")
    if len(matches) > 1 and index is None:
        listing = "\n".join(f"  [{i}] {p.device}  serial={p.serial_number}"
                            for i, p in enumerate(matches))
        raise RuntimeError(f"Multiple '{device_name}' boards found — "
                           f"pass an index (0..{len(matches)-1}) or a port path:\n{listing}")
    return matches[index or 0].device


class PressureSensor:
    def __init__(self, port: str = None, baud_rate: int = BAUD_RATE, timeout: float = 1.0):
        if port is None or (isinstance(port, str) and port.isdigit()):
            port = find_port(index=int(port) if port is not None else None)
        self.serial = serial.Serial(port, baud_rate, timeout=timeout)
        self.base_pressure = self.get_pressure()  # ambient reference at startup

    def get_pressure(self) -> float:
        """Return the current pressure in hPa."""
        self.serial.write(REQUEST)
        raw = self.serial.read(struct.calcsize(READ_FORMAT))
        if len(raw) != struct.calcsize(READ_FORMAT):
            raise TimeoutError("Incomplete response from sensor (check port and baud rate).")
        return struct.unpack(READ_FORMAT, raw)[0] * 10  # kPa -> hPa

    def close(self):
        self.serial.close()


if __name__ == "__main__":
    port = sys.argv[1] if len(sys.argv) > 1 else None
    sensor = PressureSensor(port)
    print(f"Connected on {sensor.serial.port}, base pressure {sensor.base_pressure:.2f} hPa")
    print("pressure (hPa) | delta from base (hPa) | read time (ms)")
    try:
        while True:
            t0 = time.time()
            p = sensor.get_pressure()
            dt_ms = 1e3 * (time.time() - t0)
            print(f"{p:14.2f} | {p - sensor.base_pressure:21.2f} | {dt_ms:.1f}")
            time.sleep(max(0.0, 0.1 - (time.time() - t0)))  # ~10 Hz
    except KeyboardInterrupt:
        pass
    except serial.SerialException as e:
        print(f"Serial error: {e}")
    finally:
        sensor.close()
