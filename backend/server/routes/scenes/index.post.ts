import { requireUserId } from '~/lib/currentUser';
import { saveScene } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const body = await readBody<{ name?: string; zoneId?: string }>(event);

  if (!body.name || typeof body.name !== 'string') {
    throw createError({
      statusCode: 400,
      statusMessage: 'Scene name is required',
    });
  }

  try {
    return await saveScene(userId, {
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
