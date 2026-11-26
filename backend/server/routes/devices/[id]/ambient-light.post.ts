import { createError, defineEventHandler, getRouterParam, readValidatedBody } from 'h3';
import { z } from 'zod';
import { requireUserId } from '~/lib/currentUser';
import { prisma } from '~/lib/prisma';
import { MAX_AMBIENT_LUX } from '~/utils/lightingRecommendations';

const readingSchema = z.strictObject({
  lux: z.number().min(0).max(MAX_AMBIENT_LUX),
  measuredAt: z.iso.datetime({ offset: true }),
});

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const id = getRouterParam(event, 'id', { decode: true });
  if (!id) {
    throw createError({ statusCode: 400, statusMessage: 'Device ID is required' });
  }

  const reading = await readValidatedBody(event, body => readingSchema.parse(body));
  const measuredAt = new Date(reading.measuredAt);
  if (measuredAt.getTime() > Date.now()) {
    throw createError({ statusCode: 400, statusMessage: 'Measurement time must not be in the future' });
  }

  const where = { id, userId };
  const { count } = await prisma.device.updateMany({
    where: {
      ...where,
      OR: [{ ambientMeasuredAt: null }, { ambientMeasuredAt: { lt: measuredAt } }],
    },
    data: { ambientLux: reading.lux, ambientMeasuredAt: measuredAt },
  });
  if (count === 0) {
    const device = await prisma.device.findFirst({
      where,
      select: { ambientLux: true, ambientMeasuredAt: true },
    });
    if (!device) {
      throw createError({ statusCode: 404, statusMessage: 'Device not found' });
    }
    if (device.ambientMeasuredAt?.getTime() !== measuredAt.getTime() || device.ambientLux !== reading.lux) {
      throw createError({ statusCode: 409, statusMessage: 'A reading with the same or newer timestamp already exists' });
    }
  }

  return { deviceId: id, lux: reading.lux, measuredAt: measuredAt.toISOString() };
});
