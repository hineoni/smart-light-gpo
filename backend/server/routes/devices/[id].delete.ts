import { deleteDevice } from '~/utils/deviceStorage';

export default defineEventHandler((event) => {
  const id = getRouterParam(event, 'id');
  const success = deleteDevice(id!);

  if (!success) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  return { success: true };
});
