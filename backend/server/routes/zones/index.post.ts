import { requireUserId } from '~/lib/currentUser';
import { upsertZone } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const body = await readBody<{
    id?: string;
    name?: string;
    x?: number;
    y?: number;
    heightM?: number;
  }>(event);

  if (!body.name || typeof body.name !== 'string') {
    throw createError({
      statusCode: 400,
      statusMessage: 'Zone name is required',
    });
  }

  return upsertZone(userId, {
    id: body.id,
    name: body.name,
    x: body.x,
    y: body.y,
    heightM: body.heightM,
  });
});
