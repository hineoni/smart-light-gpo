import { requireUserId } from '~/lib/currentUser';
import { onlineDevices } from '~/utils/wsRuntime';
import { getDevices } from '~/utils/deviceStorage';

export default defineEventHandler(async (event) => {
  const devices = await getDevices(requireUserId(event));
  const devicesById = new Map(devices.map(device => [device.id, device]));
  const list = onlineDevices().filter(d => devicesById.has(d.deviceId)).map(d => {
    const dev = devicesById.get(d.deviceId);
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
      uwbDiscardedBytes: d.uwbDiscardedBytes,
      uwbParsedFrames: d.uwbParsedFrames,
      uwbInvalidFrames: d.uwbInvalidFrames,
      uwbParsedLines: d.uwbParsedLines,
      uwbInvalidLines: d.uwbInvalidLines,
      uwbLastByteAtMs: d.uwbLastByteAtMs,
      uwbLastRxHex: d.uwbLastRxHex,
      uwbAutoConfig: d.uwbAutoConfig,
      uwbRole: d.uwbRole,
      uwbPid: d.uwbPid,
      uwbPeriod: d.uwbPeriod,
      uwbLocalAddress: d.uwbLocalAddress,
      uwbPeer0Address: d.uwbPeer0Address,
    };
  });
  return list;
});
