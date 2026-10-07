import { requireUserId } from '~/lib/currentUser';
import { getDevices } from '~/utils/deviceStorage';
import { getDistances } from '~/utils/positioningRuntime';

export default defineEventHandler(async (event) => {
  const devices = await getDevices(requireUserId(event));
  const allowedIds = new Set(devices.map(device => device.id));

  return getDistances().filter(distance => (
    allowedIds.has(distance.fromDeviceId) && allowedIds.has(distance.toDeviceId)
  ));
});
