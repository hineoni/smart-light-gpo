import { getPositioningSummary } from '~/utils/positioningRuntime';
import { onlineDevices } from '~/utils/wsRuntime';

export default defineEventHandler(() => {
  return getPositioningSummary(onlineDevices());
});
