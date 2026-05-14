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
  uwbDiscardedBytes?: number;
  uwbParsedFrames?: number;
  uwbInvalidFrames?: number;
  uwbParsedLines?: number;
  uwbInvalidLines?: number;
  uwbLastByteAtMs?: number;
  uwbLastRxHex?: string;
  uwbAutoConfig?: boolean;
  uwbRole?: number;
  uwbPid?: number;
  uwbPeriod?: number;
  uwbLocalAddress?: number;
  uwbPeer0Address?: number;
}

export interface PositioningSummary {
  distances: DeviceDistance[];
  nodes: PositioningNode[];
  lastUpdated: string | null;
  ttlMs: number;
}

type StoredDeviceDistance = Omit<DeviceDistance, 'ageMs'>;

const DISTANCE_TTL_MS = 5000;
const FILTER_SAMPLE_COUNT = 7;
const FILTER_ALPHA = 0.22;
const FILTER_OUTLIER_ALPHA = 0.08;
const FILTER_OUTLIER_GATE_M = 0.35;
const DISPLAY_DEADBAND_M = 0.10;
const distances: Map<string, StoredDeviceDistance> = new Map();
const distanceFilters: Map<string, {
  samples: number[];
  filteredDistanceM: number;
  publishedDistanceM: number;
}> = new Map();
const mappedPairFilters: Map<string, number> = new Map();

function normalizePair(fromDeviceId: string, toDeviceId: string) {
  return [fromDeviceId, toDeviceId].sort().join('::');
}

function formatUwbPeerId(address: number) {
  return `uwb_${address.toString(16).padStart(4, '0').toUpperCase()}`;
}

function normalizeRssi(rssiDbm: unknown) {
  return typeof rssiDbm === 'number' && Number.isFinite(rssiDbm)
    ? Math.round(rssiDbm)
    : undefined;
}

function median(values: number[]) {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
}

function smoothDistance(key: string, rawDistanceM: number) {
  const filter = distanceFilters.get(key) ?? {
    samples: [],
    filteredDistanceM: rawDistanceM,
    publishedDistanceM: rawDistanceM,
  };
  filter.samples.push(rawDistanceM);
  if (filter.samples.length > FILTER_SAMPLE_COUNT) {
    filter.samples.shift();
  }

  const medianDistanceM = median(filter.samples);
  const delta = Math.abs(medianDistanceM - filter.filteredDistanceM);
  const alpha = delta > FILTER_OUTLIER_GATE_M ? FILTER_OUTLIER_ALPHA : FILTER_ALPHA;
  filter.filteredDistanceM += (medianDistanceM - filter.filteredDistanceM) * alpha;
  if (Math.abs(filter.filteredDistanceM - filter.publishedDistanceM) >= DISPLAY_DEADBAND_M) {
    filter.publishedDistanceM = filter.filteredDistanceM;
  }
  distanceFilters.set(key, filter);
  return filter.publishedDistanceM;
}

function publishMappedDistance(key: string, distanceM: number) {
  const previous = mappedPairFilters.get(key);
  if (previous === undefined || Math.abs(distanceM - previous) >= DISPLAY_DEADBAND_M) {
    const next = Number(distanceM.toFixed(3));
    mappedPairFilters.set(key, next);
    return next;
  }
  return previous;
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
    const filteredDistanceM = smoothDistance(key, range.distanceM);
    distances.set(key, {
      fromDeviceId,
      toDeviceId: range.peerId,
      distanceM: Number(filteredDistanceM.toFixed(3)),
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
  uwbDiscardedBytes?: number;
  uwbParsedFrames?: number;
  uwbInvalidFrames?: number;
  uwbParsedLines?: number;
  uwbInvalidLines?: number;
  uwbLastByteAtMs?: number;
  uwbLastRxHex?: string;
  uwbAutoConfig?: boolean;
  uwbRole?: number;
  uwbPid?: number;
  uwbPeriod?: number;
  uwbLocalAddress?: number;
  uwbPeer0Address?: number;
}

export function getPositioningSummary(onlineNodes: Array<string | OnlineNodeInput> = []): PositioningSummary {
  const onlineByDeviceId = new Map<string, OnlineNodeInput>();
  const deviceIdByUwbPeerId = new Map<string, string>();

  for (const node of onlineNodes) {
    const onlineNode = typeof node === 'string' ? { deviceId: node } : node;
    onlineByDeviceId.set(onlineNode.deviceId, onlineNode);
    if (typeof onlineNode.uwbLocalAddress === 'number') {
      deviceIdByUwbPeerId.set(formatUwbPeerId(onlineNode.uwbLocalAddress), onlineNode.deviceId);
    }
  }

  const currentDistancesByPair = new Map<string, DeviceDistance[]>();
  for (const distance of getDistances()) {
    const fromDeviceId = deviceIdByUwbPeerId.get(distance.fromDeviceId) ?? distance.fromDeviceId;
    const toDeviceId = deviceIdByUwbPeerId.get(distance.toDeviceId) ?? distance.toDeviceId;
    if (fromDeviceId === toDeviceId) {
      continue;
    }

    const mappedDistance: DeviceDistance = {
      ...distance,
      fromDeviceId,
      toDeviceId,
    };
    const key = normalizePair(fromDeviceId, toDeviceId);
    currentDistancesByPair.set(key, [...(currentDistancesByPair.get(key) ?? []), mappedDistance]);
  }
  const currentDistances = Array.from(currentDistancesByPair.entries())
    .map(([key, pairDistances]) => {
      const latest = pairDistances.reduce((result, distance) => (
        new Date(distance.updatedAt).getTime() > new Date(result.updatedAt).getTime() ? distance : result
      ));
      const averageDistanceM = pairDistances.reduce((sum, distance) => sum + distance.distanceM, 0) / pairDistances.length;
      return {
        ...latest,
        distanceM: publishMappedDistance(key, averageDistanceM),
      };
    })
    .sort((a, b) => `${a.fromDeviceId}:${a.toDeviceId}`.localeCompare(`${b.fromDeviceId}:${b.toDeviceId}`));

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
          uwbDiscardedBytes: onlineNode?.uwbDiscardedBytes,
          uwbParsedFrames: onlineNode?.uwbParsedFrames,
          uwbInvalidFrames: onlineNode?.uwbInvalidFrames,
          uwbParsedLines: onlineNode?.uwbParsedLines,
          uwbInvalidLines: onlineNode?.uwbInvalidLines,
          uwbLastByteAtMs: onlineNode?.uwbLastByteAtMs,
          uwbLastRxHex: onlineNode?.uwbLastRxHex,
          uwbAutoConfig: onlineNode?.uwbAutoConfig,
          uwbRole: onlineNode?.uwbRole,
          uwbPid: onlineNode?.uwbPid,
          uwbPeriod: onlineNode?.uwbPeriod,
          uwbLocalAddress: onlineNode?.uwbLocalAddress,
          uwbPeer0Address: onlineNode?.uwbPeer0Address,
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
    distanceFilters.delete(key);
    mappedPairFilters.delete(key);
    distances.set(key, {
      ...distance,
      distanceM: Number(distance.distanceM.toFixed(3)),
      updatedAt: distance.updatedAt || new Date().toISOString(),
      rssiDbm: normalizeRssi(distance.rssiDbm),
      source: 'mock',
    });
  }
}
