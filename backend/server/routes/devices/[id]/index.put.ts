import { requireUserId } from '~/lib/currentUser';
import { getUserDevice, renameDevice } from '~/utils/deviceStorage';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const id = getRouterParam(event, 'id');
  const device = await getUserDevice(userId, id!);

  if (!device) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  const body = await readBody(event);

  if (body.name && typeof body.name === 'string') {
    return { success: true, device: await renameDevice(userId, id!, body.name) };
  }

  return { success: true, device };
});
