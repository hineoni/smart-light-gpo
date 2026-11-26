import { createError, defineEventHandler, readValidatedBody } from 'h3';
import { z } from 'zod';
import { requireUserId } from '~/lib/currentUser';
import { prisma } from '~/lib/prisma';
import { MAX_AMBIENT_LUX } from '~/utils/lightingRecommendations';

const brightness = z.number().int().min(0).max(255);
const preferencesSchema = z.strictObject({
  targetLux: z.number().int().min(1).max(MAX_AMBIENT_LUX),
  minBrightness: brightness,
  maxBrightness: brightness,
}).refine(preferences => preferences.minBrightness <= preferences.maxBrightness, {
  path: ['minBrightness'],
  message: 'Minimum brightness must not exceed maximum brightness',
});

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const preferences = await readValidatedBody(event, body => preferencesSchema.parse(body));
  const { count } = await prisma.user.updateMany({
    where: { id: userId },
    data: {
      lightingTargetLux: preferences.targetLux,
      lightingMinBrightness: preferences.minBrightness,
      lightingMaxBrightness: preferences.maxBrightness,
    },
  });
  if (count === 0) {
    throw createError({ statusCode: 404, statusMessage: 'User not found' });
  }

  return preferences;
});
