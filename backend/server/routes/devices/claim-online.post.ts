import { requireUserId } from '~/lib/currentUser';
import { claimOnlineDevices } from '~/utils/deviceStorage';
import { onlineDevices } from '~/utils/wsRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const body = await readBody<{ deviceId?: string }>(event).catch(() => ({}));
  const onlineIds = onlineDevices().map(device => device.deviceId);
  const deviceIds = body.deviceId ? [body.deviceId] : onlineIds;

  return claimOnlineDevices(userId, deviceIds);
});
