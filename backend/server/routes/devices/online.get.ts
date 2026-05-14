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
      servo2Angle: d.servo2Angle,
      uwbReady: d.uwbReady,
      uwbRangeCount: d.uwbRangeCount,
      uwbUartBytes: d.uwbUartBytes,
      uwbParsedFrames: d.uwbParsedFrames,
      uwbInvalidFrames: d.uwbInvalidFrames,
      uwbParsedLines: d.uwbParsedLines,
      uwbInvalidLines: d.uwbInvalidLines,
      uwbLastByteAtMs: d.uwbLastByteAtMs,
    };
  });
  return list;
});
