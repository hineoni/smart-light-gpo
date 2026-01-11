import { onlineDevices } from '~/utils/wsRuntime';
import { getDevice } from '~/utils/deviceStorage';

export default defineEventHandler(() => {
  const list = onlineDevices().map(d => {
    const dev = getDevice(d.deviceId);
    return {
      deviceId: d.deviceId,
      name: dev?.name,
      ip: dev?.ip,
      lastHeartbeat: d.lastHeartbeat,
      servo1Angle: d.servo1Angle,
      servo2Angle: d.servo2Angle
    };
  });
  return list;
});