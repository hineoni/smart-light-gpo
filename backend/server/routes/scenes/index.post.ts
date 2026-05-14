import { saveScene } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const body = await readBody<{ name?: string; zoneId?: string }>(event);

  if (!body.name || typeof body.name !== 'string') {
    throw createError({
      statusCode: 400,
      statusMessage: 'Scene name is required',
    });
  }

  return saveScene({
    name: body.name,
    zoneId: body.zoneId,
  });
});

