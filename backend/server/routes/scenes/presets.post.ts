import { createError, defineEventHandler, readBody } from 'h3';
import { requireUserId } from '~/lib/currentUser';
import { createPresetScene } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const body = await readBody<{ key?: string; zoneId?: string }>(event);

  if (!body.key) {
    throw createError({ statusCode: 400, statusMessage: 'Preset key is required' });
  }

  try {
    return await createPresetScene(userId, body.key, body.zoneId);
  } catch (error) {
    throw createError({ statusCode: 404, statusMessage: (error as Error).message });
  }
});