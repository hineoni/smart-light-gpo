import { getDevice } from '~/utils/deviceStorage';
import { sendToDevice } from '~/utils/wsRuntime';
import { updateDeviceLed } from '~/utils/deviceStorage';

export default defineEventHandler(async (event) => {
  const deviceId = getRouterParam(event, 'id');
  
  if (!deviceId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Device ID required'
    });
  }

  const device = getDevice(deviceId);
  if (!device) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Device not found'
    });
  }

  const body = await readBody(event);

  // Валидация команд LED
  if (!body.type || typeof body.type !== 'string') {
    throw createError({
      statusCode: 400,
      statusMessage: 'Command type is required'
    });
  }

  let command: any = { type: body.type };

  switch (body.type) {
    case 'set_led_color':
      if (typeof body.r !== 'number' || typeof body.g !== 'number' || typeof body.b !== 'number' ||
          body.r < 0 || body.r > 255 || body.g < 0 || body.g > 255 || body.b < 0 || body.b > 255) {
        throw createError({
          statusCode: 400,
          statusMessage: 'Invalid RGB values. Each must be between 0-255'
        });
      }
      command = { type: body.type, r: body.r, g: body.g, b: body.b };
      break;

    case 'set_led_brightness':
      if (typeof body.brightness !== 'number' || body.brightness < 0 || body.brightness > 255) {
        throw createError({
          statusCode: 400,
          statusMessage: 'Invalid brightness value. Must be between 0-255'
        });
      }
      command = { type: body.type, brightness: body.brightness };
      break;

    case 'clear_leds':
      // Эта команда не требует дополнительных параметров
      break;

    default:
      throw createError({
        statusCode: 400,
        statusMessage: `Unknown LED command: ${body.type}`
      });
  }

  // Отправляем команду на устройство
  const success = sendToDevice(deviceId, command);
  
  if (!success) {
    throw createError({
      statusCode: 503,
      statusMessage: 'Device is not connected'
    });
  }

  // Обновляем локальное состояние
  switch (body.type) {
    case 'set_led_color':
      updateDeviceLed(deviceId, undefined, body.r, body.g, body.b);
      break;
    case 'set_led_brightness':
      updateDeviceLed(deviceId, body.brightness);
      break;
  }

  return {
    success: true,
    message: `LED command ${body.type} sent successfully`,
    deviceId
  };
});