import { defineEventHandler, getValidatedQuery } from 'h3';
import { z } from 'zod';
import { requireUserId } from '~/lib/currentUser';
import { getLightingRecommendations } from '~/utils/lightingRecommendations';

const querySchema = z.object({ zoneId: z.string().trim().min(1).optional() });

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const { zoneId } = await getValidatedQuery(event, query => querySchema.parse(query));
  return getLightingRecommendations(userId, zoneId);
});
