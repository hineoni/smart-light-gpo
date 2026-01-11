import { getDevice } from '~/utils/deviceStorage';

export default defineEventHandler((event) => {
  const id = getRouterParam(event, 'id');
  const device = getDevice(id!);

  if (!device) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  return device;
});
