import { setMockDistances } from '~/utils/positioningRuntime';

interface MockDistanceRequest {
  distances?: Array<{
    fromDeviceId: string;
    toDeviceId: string;
    distanceM: number;
    rssiDbm?: number;
  }>;
}

export default defineEventHandler(async (event) => {
  const body = await readBody<MockDistanceRequest>(event);
  const now = new Date().toISOString();
  const distances = body.distances || [
    { fromDeviceId: 'smartlight_mock_1', toDeviceId: 'smartlight_mock_2', distanceM: 1.2, rssiDbm: -71 },
    { fromDeviceId: 'smartlight_mock_1', toDeviceId: 'smartlight_mock_3', distanceM: 1.8, rssiDbm: -76 },
    { fromDeviceId: 'smartlight_mock_2', toDeviceId: 'smartlight_mock_3', distanceM: 1.45, rssiDbm: -73 },
  ];

  setMockDistances(distances.map(distance => ({ ...distance, updatedAt: now, source: 'mock' })));

  return {
    success: true,
    distances,
  };
});
