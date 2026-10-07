import { requireUserId } from '~/lib/currentUser';
import { deleteDevice } from '~/utils/deviceStorage';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const id = getRouterParam(event, 'id');
  const success = await deleteDevice(userId, id!);

  if (!success) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  return { success: true };
});
