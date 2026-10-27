import { requireUserId } from '~/lib/currentUser';
import { getUserDevice } from '~/utils/deviceStorage';
import { getRuntimeByDevice } from '~/utils/wsRuntime';
import { currentAmbientLight } from '~/utils/ambientLight';

export default defineEventHandler(async (event) => {
  const userId = requireUserId(event);
  const id = getRouterParam(event, 'id');
  if (!id || !(await getUserDevice(userId, id))) {
    throw createError({ statusCode: 404, statusMessage: 'Device not found' });
  }
  return {
    ...currentAmbientLight(getRuntimeByDevice(id)?.ambientLight),
    source: 'device',
    shared: false,
    deviceId: id,
  };
});
