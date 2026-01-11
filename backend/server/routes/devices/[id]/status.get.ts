import { getDevice, updateDeviceStatus } from '~/utils/deviceStorage';

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id');
  const device = getDevice(id!);

  if (!device) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  try {
    const response = await $fetch(`http://${device.ip}/api/status`);
    updateDeviceStatus(id!, 'connected');

    return {
      device: id,
      status: 'connected',
      data: response
    };
  } catch (error) {
    updateDeviceStatus(id!, 'disconnected');

    return {
      device: id,
      status: 'disconnected',
      error: 'Cannot reach device'
    };
  }
});
