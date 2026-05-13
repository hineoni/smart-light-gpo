import { getDistances } from '~/utils/positioningRuntime';

export default defineEventHandler(() => {
  return getDistances();
});
