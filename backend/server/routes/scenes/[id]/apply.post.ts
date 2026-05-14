import { applyScene } from '~/utils/sceneRuntime';

export default defineEventHandler((event) => {
  const sceneId = getRouterParam(event, 'id');
  if (!sceneId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Scene ID is required',
    });
  }

  try {
    return applyScene(sceneId);
  } catch (error) {
    throw createError({
      statusCode: 404,
      statusMessage: (error as Error).message,
    });
  }
});

