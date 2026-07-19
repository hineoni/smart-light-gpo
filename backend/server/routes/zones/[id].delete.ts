import { requireUserId } from '~/lib/currentUser';
import { deleteZone } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const zoneId = decodeURIComponent(getRouterParam(event, 'id') ?? '');
  if (!zoneId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Zone ID is required',
    });
  }

  if (!(await deleteZone(userId, zoneId))) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Zone not found',
    });
  }

  return { success: true, zoneId };
});
