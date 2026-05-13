export interface UwbRangeInput {
  peerId: string;
  distanceM: number;
  updatedAtMs?: number;
}

export interface DeviceDistance {
  fromDeviceId: string;
  toDeviceId: string;
  distanceM: number;
  updatedAt: string;
  source: 'device' | 'mock';
}

const distances: Map<string, DeviceDistance> = new Map();

function normalizePair(fromDeviceId: string, toDeviceId: string) {
  return [fromDeviceId, toDeviceId].sort().join('::');
}

export function updateDeviceRanges(
  fromDeviceId: string,
  ranges: UwbRangeInput[] | undefined,
  source: 'device' | 'mock' = 'device'
) {
  if (!Array.isArray(ranges)) return;

  for (const range of ranges) {
    if (!range || typeof range.peerId !== 'string' || range.peerId.length === 0) {
      continue;
    }

    if (range.peerId === fromDeviceId || typeof range.distanceM !== 'number' || !Number.isFinite(range.distanceM)) {
      continue;
    }

    if (range.distanceM < 0 || range.distanceM > 100) {
      continue;
    }

    const key = normalizePair(fromDeviceId, range.peerId);
    distances.set(key, {
      fromDeviceId,
      toDeviceId: range.peerId,
      distanceM: Number(range.distanceM.toFixed(3)),
      updatedAt: new Date().toISOString(),
      source,
    });
  }
}

export function getDistances() {
  const now = Date.now();
  return Array.from(distances.values())
    .filter(distance => now - new Date(distance.updatedAt).getTime() < 30000)
    .sort((a, b) => `${a.fromDeviceId}:${a.toDeviceId}`.localeCompare(`${b.fromDeviceId}:${b.toDeviceId}`));
}

export function setMockDistances(nextDistances: DeviceDistance[]) {
  for (const distance of nextDistances) {
    if (!distance.fromDeviceId || !distance.toDeviceId || typeof distance.distanceM !== 'number') {
      continue;
    }

    const key = normalizePair(distance.fromDeviceId, distance.toDeviceId);
    distances.set(key, {
      ...distance,
      distanceM: Number(distance.distanceM.toFixed(3)),
      updatedAt: distance.updatedAt || new Date().toISOString(),
      source: 'mock',
    });
  }
}
