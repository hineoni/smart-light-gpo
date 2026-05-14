import { listScenes } from '~/utils/sceneRuntime';

export default defineEventHandler(() => {
  return listScenes();
});

