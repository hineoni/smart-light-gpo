import { getDevice } from '~/utils/deviceStorage';
import { sendServoCommand } from '~/utils/wsRuntime';

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id');
  const servo = Number(getQuery(event).servo);
  const angle = Number(getQuery(event).angle);
  const device = getDevice(id!);

  if (!device) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  if (isNaN(servo) || isNaN(angle)) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Servo number and angle are required'
    });
  }

  if (angle < 0 || angle > 180) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Angle must be between 0 and 180'
    });
  }

  // Сначала пытаемся через WebSocket
  const wsSent = sendServoCommand(device.id, servo, angle);
  if (wsSent) {
    return { success: true, transport: 'websocket' };
  }

  // Fallback HTTP
  try {
    const url = `http://${device.ip}/api/servo${servo}`;
    const response = await $fetch(url, {
      method: 'POST',
      body: { angle }
    });
    return { success: true, transport: 'http', response };
  } catch (error) {
    throw createError({
      statusCode: 503,
      statusMessage: 'Failed to control servo',
      data: { details: (error as Error).message }
    });
  }
});
