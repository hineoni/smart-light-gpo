import { aimDeviceAtTarget } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const sourceDeviceId = getRouterParam(event, 'id');
  const body = await readBody<{ targetDeviceId?: string }>(event);

  if (!sourceDeviceId || !body.targetDeviceId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Source device ID and targetDeviceId are required',
    });
  }

  try {
    return aimDeviceAtTarget(sourceDeviceId, body.targetDeviceId);
  } catch (error) {
    throw createError({
      statusCode: 404,
      statusMessage: (error as Error).message,
    });
  }
});

