import { updateScene } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const sceneId = decodeURIComponent(getRouterParam(event, 'id') ?? '');
  if (!sceneId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Scene ID is required',
    });
  }

  const body = await readBody<{ name?: string; zoneId?: string | null }>(event);

  try {
    return updateScene(sceneId, {
      name: body.name,
      zoneId: body.zoneId,
    });
  } catch (error) {
    throw createError({
      statusCode: 404,
      statusMessage: (error as Error).message,
    });
  }
});
