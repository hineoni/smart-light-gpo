import { getDevice } from '~/utils/deviceStorage';
import { sendServoCommand } from '~/utils/wsRuntime';
import { updateDeviceAngles } from '~/utils/deviceStorage';

interface ServoRequest {
  servo: number;
  angle: number;
}

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id');
  const device = getDevice(id!);

  if (!device) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  const body = await readBody<ServoRequest>(event);

  if (!body.servo || body.angle === undefined) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Servo number and angle are required'
    });
  }

  if (body.angle < 0 || body.angle > 180) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Angle must be between 0 and 180'
    });
  }

  // Сначала пытаемся через WebSocket
  const wsSent = sendServoCommand(device.id, body.servo, body.angle);
  if (wsSent) {
    updateDeviceAngles(device.id, body.servo === 1 ? body.angle : undefined, body.servo === 2 ? body.angle : undefined);
    return { success: true, transport: 'websocket' };
  }

  // Fallback HTTP
  try {
    const url = `http://${device.ip}/api/servo${body.servo}`;
    const response = await $fetch(url, {
      method: 'POST',
      body: { angle: body.angle }
    });
    updateDeviceAngles(device.id, body.servo === 1 ? body.angle : undefined, body.servo === 2 ? body.angle : undefined);
    return { success: true, transport: 'http', response };
  } catch (error) {
    throw createError({
      statusCode: 503,
      statusMessage: 'Failed to control servo',
      data: { details: (error as Error).message }
    });
  }
});
