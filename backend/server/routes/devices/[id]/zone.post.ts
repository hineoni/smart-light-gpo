import { requireUserId } from '~/lib/currentUser';
import { assignDeviceZone } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const deviceId = getRouterParam(event, 'id');
  const body = await readBody<{ zoneId?: string }>(event);

  if (!deviceId || !body.zoneId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Device ID and zoneId are required',
    });
  }

  try {
    return await assignDeviceZone(userId, deviceId, body.zoneId);
  } catch (error) {
    throw createError({
      statusCode: 404,
      statusMessage: (error as Error).message,
    });
  }
});
