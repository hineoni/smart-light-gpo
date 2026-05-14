export interface UwbRangeInput {
  peerId: string;
  distanceM: number;
  updatedAtMs?: number;
  rssiDbm?: number;
}

export interface DeviceDistance {
  fromDeviceId: string;
  toDeviceId: string;
  distanceM: number;
  updatedAt: string;
  rssiDbm?: number;
  ageMs: number;
  source: 'device' | 'mock';
}

export interface PositioningNode {
  deviceId: string;
  online: boolean;
  lastSeenAt?: string;
  uwbReady?: boolean;
  uwbRangeCount?: number;
  uwbUartBytes?: number;
  uwbParsedFrames?: number;
  uwbInvalidFrames?: number;
  uwbParsedLines?: number;
  uwbInvalidLines?: number;
  uwbLastByteAtMs?: number;
}

export interface PositioningSummary {
  distances: DeviceDistance[];
  nodes: PositioningNode[];
  lastUpdated: string | null;
  ttlMs: number;
}

type StoredDeviceDistance = Omit<DeviceDistance, 'ageMs'>;

const DISTANCE_TTL_MS = 5000;
const distances: Map<string, StoredDeviceDistance> = new Map();

function normalizePair(fromDeviceId: string, toDeviceId: string) {
  return [fromDeviceId, toDeviceId].sort().join('::');
}

function normalizeRssi(rssiDbm: unknown) {
  return typeof rssiDbm === 'number' && Number.isFinite(rssiDbm)
    ? Math.round(rssiDbm)
    : undefined;
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
      rssiDbm: normalizeRssi(range.rssiDbm),
      source,
    });
  }
}

export function getDistances(): DeviceDistance[] {
  const now = Date.now();
  return Array.from(distances.values())
    .map(distance => ({
      ...distance,
      ageMs: now - new Date(distance.updatedAt).getTime(),
    }))
    .filter(distance => distance.ageMs < DISTANCE_TTL_MS)
    .sort((a, b) => `${a.fromDeviceId}:${a.toDeviceId}`.localeCompare(`${b.fromDeviceId}:${b.toDeviceId}`));
}

interface OnlineNodeInput {
  deviceId: string;
  uwbReady?: boolean;
  uwbRangeCount?: number;
  uwbUartBytes?: number;
  uwbParsedFrames?: number;
  uwbInvalidFrames?: number;
  uwbParsedLines?: number;
  uwbInvalidLines?: number;
  uwbLastByteAtMs?: number;
}

export function getPositioningSummary(onlineNodes: Array<string | OnlineNodeInput> = []): PositioningSummary {
  const currentDistances = getDistances();
  const onlineByDeviceId = new Map<string, OnlineNodeInput>();

  for (const node of onlineNodes) {
    const onlineNode = typeof node === 'string' ? { deviceId: node } : node;
    onlineByDeviceId.set(onlineNode.deviceId, onlineNode);
  }

  const nodeIds = new Set<string>(onlineByDeviceId.keys());

  for (const distance of currentDistances) {
    nodeIds.add(distance.fromDeviceId);
    nodeIds.add(distance.toDeviceId);
  }

  const lastUpdated = currentDistances.reduce<string | null>((latest, distance) => {
    if (latest === null || new Date(distance.updatedAt).getTime() > new Date(latest).getTime()) {
      return distance.updatedAt;
    }
    return latest;
  }, null);

  return {
    distances: currentDistances,
    nodes: Array.from(nodeIds)
      .sort((a, b) => a.localeCompare(b))
      .map(deviceId => {
        const onlineNode = onlineByDeviceId.get(deviceId);
        return {
          deviceId,
          online: onlineNode !== undefined,
          lastSeenAt: currentDistances
            .filter(distance => distance.fromDeviceId === deviceId || distance.toDeviceId === deviceId)
            .map(distance => distance.updatedAt)
            .sort()
            .at(-1),
          uwbReady: onlineNode?.uwbReady,
          uwbRangeCount: onlineNode?.uwbRangeCount,
          uwbUartBytes: onlineNode?.uwbUartBytes,
          uwbParsedFrames: onlineNode?.uwbParsedFrames,
          uwbInvalidFrames: onlineNode?.uwbInvalidFrames,
          uwbParsedLines: onlineNode?.uwbParsedLines,
          uwbInvalidLines: onlineNode?.uwbInvalidLines,
          uwbLastByteAtMs: onlineNode?.uwbLastByteAtMs,
        };
      }),
    lastUpdated,
    ttlMs: DISTANCE_TTL_MS,
  };
}

export function setMockDistances(nextDistances: StoredDeviceDistance[]) {
  for (const distance of nextDistances) {
    if (!distance.fromDeviceId || !distance.toDeviceId || typeof distance.distanceM !== 'number') {
      continue;
    }

    const key = normalizePair(distance.fromDeviceId, distance.toDeviceId);
    distances.set(key, {
      ...distance,
      distanceM: Number(distance.distanceM.toFixed(3)),
      updatedAt: distance.updatedAt || new Date().toISOString(),
      rssiDbm: normalizeRssi(distance.rssiDbm),
      source: 'mock',
    });
  }
}
