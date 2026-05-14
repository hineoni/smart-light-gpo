import { deleteZone } from '~/utils/sceneRuntime';

export default defineEventHandler((event) => {
  const zoneId = decodeURIComponent(getRouterParam(event, 'id') ?? '');
  if (!zoneId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Zone ID is required',
    });
  }

  if (!deleteZone(zoneId)) {
    throw createError({
      statusCode: 404,
      statusMessage: 'Zone not found',
    });
  }

  return { success: true, zoneId };
});
