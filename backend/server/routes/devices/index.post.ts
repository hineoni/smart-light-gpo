import { requireUserId } from '~/lib/currentUser';
import { addDevice } from '~/utils/deviceStorage';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const body = await readBody<{
    id?: string;
    name?: string;
    ip?: string;
  }>(event);

  if (!body.name || typeof body.name !== 'string') {
    throw createError({
      statusCode: 400,
      statusMessage: 'Device name is required',
    });
  }

  try {
    return await addDevice(userId, body.name, body.ip ?? 'unknown', body.id);
  } catch (error) {
    throw createError({
      statusCode: 409,
      statusMessage: (error as Error).message,
    });
  }
});
