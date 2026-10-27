import unittest
from unittest.mock import patch

from ambient_light_bridge import SensorState, parse_sensor_line, parse_lamp


class BridgeTests(unittest.TestCase):
    def test_lamp_state_is_confirmed_data_and_expires(self):
        lamp = {"available": True, "isOn": False, "brightness": 0, "r": 255, "g": 255, "b": 255}
        self.assertEqual(parse_lamp(lamp), lamp)
        self.assertIsNone(parse_lamp({**lamp, "brightness": 100}))
        self.assertIsNone(parse_lamp({**lamp, "brightness": False}))
        state = SensorState('smartlight_d01c94-new')
        with patch('ambient_light_bridge.time.monotonic', return_value=100):
            state.update(parse_sensor_line('SENSOR_DATA {"available":false,"lamp":' + __import__('json').dumps(lamp) + '}'))
            self.assertEqual(state.snapshot()['lamp'], lamp)
        with patch('ambient_light_bridge.time.monotonic', return_value=106):
            self.assertIsNone(state.snapshot()['lamp'])
    def test_only_sensor_frames_are_accepted(self):
        self.assertIsNone(parse_sensor_line('WiFi credentials: hidden'))
        self.assertIsNone(parse_sensor_line('SENSOR_DATA not-json'))
        self.assertIsNone(parse_sensor_line('SENSOR_DATA null'))
        self.assertIsNone(parse_sensor_line('SENSOR_DATA {"available":true,"raw":false,"percent":0}'))
        self.assertIsNone(parse_sensor_line('SENSOR_DATA {"available":true,"raw":4096,"percent":0}'))
        self.assertIsNone(parse_sensor_line('SENSOR_DATA {"available":true,"raw":1,"percent":101}'))
        self.assertEqual(parse_sensor_line('I (10) LIGHT_SENSOR: SENSOR_DATA {"available":true,"raw":4095,"percent":0}'),
                         {"available": True, "raw": 4095, "percent": 0})

    def test_unavailable_and_stale_readings_are_not_presented_as_current(self):
        state = SensorState('smartlight_d01c94')
        self.assertEqual(state.snapshot()['deviceId'], 'smartlight_d01c94')
        self.assertFalse(state.snapshot()['available'])
        with patch('ambient_light_bridge.time.monotonic', return_value=100):
            state.update({"available": True, "raw": 0, "percent": 100})
            self.assertTrue(state.snapshot()['available'])
        with patch('ambient_light_bridge.time.monotonic', return_value=106):
            self.assertFalse(state.snapshot()['available'])
        state.update({"available": False})
        self.assertFalse(state.snapshot()['available'])


if __name__ == '__main__':
    unittest.main()
