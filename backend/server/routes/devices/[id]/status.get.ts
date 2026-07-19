import { requireUserId } from '~/lib/currentUser';
import { getUserDevice, updateDeviceStatus } from '~/utils/deviceStorage';

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

  try {
    const response = await $fetch(`http://${device.ip}/api/status`);
    await updateDeviceStatus(id!, 'connected');

    return {
      device: id,
      status: 'connected',
      data: response
    };
  } catch (error) {
    await updateDeviceStatus(id!, 'disconnected');

    return {
      device: id,
      status: 'disconnected',
      error: 'Cannot reach device'
    };
  }
});
