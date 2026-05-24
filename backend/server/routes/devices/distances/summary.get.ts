import { requireUserId } from '~/lib/currentUser';
import { getDevices } from '~/utils/deviceStorage';
import { getPositioningSummary } from '~/utils/positioningRuntime';
import { onlineDevices } from '~/utils/wsRuntime';

export default defineEventHandler(async (event) => {
  const devices = await getDevices(requireUserId(event));
  const allowedIds = new Set(devices.map(device => device.id));
  const summary = getPositioningSummary(
    onlineDevices().filter(device => allowedIds.has(device.deviceId)),
  );

  return {
    ...summary,
    distances: summary.distances.filter(distance => (
      allowedIds.has(distance.fromDeviceId) && allowedIds.has(distance.toDeviceId)
    )),
    nodes: summary.nodes.filter(node => allowedIds.has(node.deviceId)),
    layout: {
      ...summary.layout,
      nodes: summary.layout.nodes.filter(node => allowedIds.has(node.deviceId)),
    },
  };
});
