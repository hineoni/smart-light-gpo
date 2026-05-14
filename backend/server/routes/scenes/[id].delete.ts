import { deleteScene } from '~/utils/sceneRuntime';

export default defineEventHandler((event) => {
  const sceneId = getRouterParam(event, 'id');
  if (!sceneId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Scene ID is required',
    });
  }

  if (!deleteScene(sceneId)) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Scene not found',
    });
  }

  return { success: true, sceneId };
});

