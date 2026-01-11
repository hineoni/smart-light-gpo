import { getDevice } from '~/utils/deviceStorage';

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id');
  const device = getDevice(id!);

  if (!device) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  const body = await readBody(event);

  if (body.name && typeof body.name === 'string') {
    device.name = body.name;
  }

  return { success: true, device };
});