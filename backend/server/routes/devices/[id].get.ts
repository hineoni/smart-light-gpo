import { requireUserId } from '~/lib/currentUser';
import { getUserDevice } from '~/utils/deviceStorage';

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

  return device;
});
