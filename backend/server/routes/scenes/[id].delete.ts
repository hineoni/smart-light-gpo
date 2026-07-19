import { requireUserId } from '~/lib/currentUser';
import { deleteScene } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const sceneId = decodeURIComponent(getRouterParam(event, 'id') ?? '');
  if (!sceneId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Scene ID is required',
    });
  }

  if (!(await deleteScene(userId, sceneId))) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Scene not found',
    });
  }

  return { success: true, sceneId };
});
