#!/usr/bin/env python3
"""Expose the shared USB light sensor on loopback; cloud auth stays in the app.

Run with the ESP-IDF Python environment (contains pyserial):
  python tools/ambient_light_bridge.py --port /dev/cu.usbserial-10 --device-id smartlight_d01c94-new
The app's local-test release uses --dart-define=LIGHT_SENSOR_BASE_URL=http://127.0.0.1:8765
No Wi-Fi configuration or other board commands are sent.
"""

import argparse
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import serial

STALE_SECONDS = 5
MARKER = "SENSOR_DATA "


def parse_lamp(data):
    if not isinstance(data, dict) or data.get("available") is not True:
        return None
    if type(data.get("isOn")) is not bool:
        return None
    for key in ("brightness", "r", "g", "b"):
        if type(data.get(key)) is not int or not 0 <= data[key] <= 255:
            return None
    if data["isOn"] != (data["brightness"] > 0):
        return None
    return {key: data[key] for key in ("available", "isOn", "brightness", "r", "g", "b")}


def parse_sensor_line(line):
    if MARKER not in line:
        return None
    try:
        data = json.loads(line.split(MARKER, 1)[1])
        if data.get("available") is False:
            reading = {"available": False}
        else:
            raw, percent = data["raw"], data["percent"]
            if data.get("available") is not True:
                return None
            if type(raw) is not int or not 0 <= raw <= 4095:
                return None
            if type(percent) is not int or not 0 <= percent <= 100:
                return None
            reading = {"available": True, "raw": raw, "percent": percent}
        lamp = parse_lamp(data.get("lamp"))
        if lamp is not None:
            reading["lamp"] = lamp
        return reading
    except (ValueError, KeyError, TypeError, AttributeError):
        return None


class SensorState:
    def __init__(self, device_id=None):
        self.lock = threading.Lock()
        self.reading = {"available": False}
        self.received_at = None
        self.received_monotonic = None
        self.device_id = device_id

    def update(self, reading):
        with self.lock:
            self.reading = reading
            self.received_at = time.time()
            self.received_monotonic = time.monotonic()

    def snapshot(self):
        with self.lock:
            fresh = self.received_monotonic is not None and (
                time.monotonic() - self.received_monotonic <= STALE_SECONDS
            )
            return {
                **self.reading,
                "lamp": self.reading.get("lamp") if fresh else None,
                "available": self.reading["available"] and fresh,
                "receivedAt": int(self.received_at * 1000) if self.received_at else None,
                "source": "usb",
                "shared": True,
                "deviceId": self.device_id,
            }


def read_serial(port, state, stop):
    while not stop.is_set():
        try:
            # Set control lines before opening: observing telemetry must not reset ESP32.
            connection = serial.Serial(baudrate=115200, timeout=1)
            connection.dtr = False
            connection.rts = False
            connection.port = port
            connection.open()
            print(f"Reading light sensor on {port}", flush=True)
            with connection:
                while not stop.is_set():
                    line = connection.readline().decode("utf-8", errors="replace").strip()
                    reading = parse_sensor_line(line)
                    if reading is not None:
                        state.update(reading)
        except (serial.SerialException, OSError):
            state.update({"available": False})
            stop.wait(2)


def make_handler(state):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path not in ("/ambient-light", "/health"):
                self.send_error(404)
                return
            payload = state.snapshot() if self.path == "/ambient-light" else {"ok": True}
            encoded = json.dumps(payload).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

        def log_message(self, *_):
            pass

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default="/dev/cu.usbserial-10")
    parser.add_argument("--http-port", type=int, default=8765)
    parser.add_argument("--device-id", required=True, help="Existing ESP32 ID verified from its saved configuration")
    args = parser.parse_args()
    state = SensorState(args.device_id)
    stop = threading.Event()
    server = ThreadingHTTPServer(("127.0.0.1", args.http_port), make_handler(state))
    reader = threading.Thread(target=read_serial, args=(args.port, state, stop), daemon=True)
    reader.start()
    print(f"Shared sensor: http://127.0.0.1:{args.http_port}/ambient-light", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        server.server_close()
        reader.join(timeout=3)


if __name__ == "__main__":
    main()
