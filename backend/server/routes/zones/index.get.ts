import { listZones } from '~/utils/sceneRuntime';

export default defineEventHandler(() => {
  return listZones();
});

