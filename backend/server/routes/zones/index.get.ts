import { requireUserId } from '~/lib/currentUser';
import { listZones } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  return listZones(requireUserId(event));
});
