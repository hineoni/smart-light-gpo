import { requireUserId } from '~/lib/currentUser';
import { applyScene } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const sceneId = decodeURIComponent(getRouterParam(event, 'id') ?? '');
  if (!sceneId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Scene ID is required',
    });
  }

  try {
    return await applyScene(userId, sceneId);
  } catch (error) {
    throw createError({
      statusCode: 404,
      statusMessage: (error as Error).message,
    });
  }
});
