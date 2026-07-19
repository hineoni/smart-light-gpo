import { requireUserId } from '~/lib/currentUser';
import { aimDeviceAtTarget } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const sourceDeviceId = getRouterParam(event, 'id');
  const body = await readBody<{ targetDeviceId?: string }>(event);

  if (!sourceDeviceId || !body.targetDeviceId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Source device ID and targetDeviceId are required',
    });
  }

  try {
    return await aimDeviceAtTarget(userId, sourceDeviceId, body.targetDeviceId);
  } catch (error) {
    throw createError({
      statusCode: 404,
      statusMessage: (error as Error).message,
    });
  }
});
