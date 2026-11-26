import { defineEventHandler } from 'h3';
import { requireUserId } from '~/lib/currentUser';
import { getLightingPreferences } from '~/utils/lightingRecommendations';

export default defineEventHandler(event => getLightingPreferences(requireUserId(event)));
