#!/bin/zsh
set -eu
sensor_repo="${0:A:h:h}"
sensor_python="${LIGHT_SENSOR_PYTHON:-$HOME/.espressif/python_env/idf6.0_py3.14_env/bin/python}"
sensor_app="$sensor_repo/smart_light/build/macos/Build/Products/Release/smart_light.app"

if ! /usr/bin/curl --silent --fail --max-time 2 http://127.0.0.1:8765/health >/dev/null; then
  /usr/bin/nohup "$sensor_python" "$sensor_repo/tools/ambient_light_bridge.py" \
    --port "${LIGHT_SENSOR_PORT:-/dev/cu.usbserial-10}" \
    --device-id "${LIGHT_SENSOR_DEVICE_ID:-smartlight_d01c94-new}" \
    > /tmp/smart-light-ambient-bridge.log 2>&1 < /dev/null &
fi
/usr/bin/open "$sensor_app"
echo "Smart Light запущен. Общий датчик работает по USB, авторизация — через облачный сервер."
