import { requireUserId } from '~/lib/currentUser';
import { listScenes } from '~/utils/sceneRuntime';

export default defineEventHandler(async (event) => {
  return listScenes(requireUserId(event));
});
