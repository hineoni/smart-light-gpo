import { createError } from 'h3';
import { prisma } from '~/lib/prisma';

export const MAX_AMBIENT_LUX = 200_000;
const MAX_READING_AGE_MS = 5 * 60_000;

const preferencesSelect = {
  lightingTargetLux: true,
  lightingMinBrightness: true,
  lightingMaxBrightness: true,
} as const;

export async function getLightingPreferences(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: preferencesSelect,
  });
  if (!user) {
    throw createError({ statusCode: 404, statusMessage: 'User not found' });
  }

  return {
    targetLux: user.lightingTargetLux,
    minBrightness: user.lightingMinBrightness,
    maxBrightness: user.lightingMaxBrightness,
  };
}

export async function getLightingRecommendations(userId: string, zoneId?: string) {
  if (zoneId !== undefined) {
    const zone = await prisma.zone.findUnique({
      where: { userId_id: { userId, id: zoneId } },
      select: { id: true },
    });
    if (!zone) {
      throw createError({ statusCode: 404, statusMessage: 'Zone not found' });
    }
  }

  const [preferences, devices] = await Promise.all([
    getLightingPreferences(userId),
    prisma.device.findMany({
      where: { userId, zoneId },
      select: {
        id: true,
        zoneId: true,
        ambientLux: true,
        ambientMeasuredAt: true,
      },
      orderBy: { id: 'asc' },
    }),
  ]);

  const now = Date.now();
  const readingsByLocation = new Map<string, { totalLux: number; count: number; hasStaleReading: boolean }>();
  const locations = devices.map(device => ({
    device,
    key: device.zoneId === null ? `device:${device.id}` : `zone:${device.zoneId}`,
  }));

  for (const { device, key } of locations) {
    if (device.ambientLux === null || device.ambientMeasuredAt === null) continue;

    const readings = readingsByLocation.get(key) ?? { totalLux: 0, count: 0, hasStaleReading: false };
    const ageMs = now - device.ambientMeasuredAt.getTime();
    if (ageMs < 0 || ageMs >= MAX_READING_AGE_MS) {
      readings.hasStaleReading = true;
    } else {
      readings.totalLux += device.ambientLux;
      readings.count += 1;
    }
    readingsByLocation.set(key, readings);
  }

  const { targetLux, minBrightness, maxBrightness } = preferences;
  const recommendations = locations.map(({ device, key }) => {
    const target = { deviceId: device.id, zoneId: device.zoneId };
    const readings = readingsByLocation.get(key);
    if (!readings?.count) {
      return {
        ...target,
        status: readings?.hasStaleReading ? 'stale_telemetry' : 'missing_telemetry',
        ambientLux: null,
        sampleCount: 0,
        brightness: null,
      };
    }

    const ambientLux = readings.totalLux / readings.count;
    const deficit = Math.max(0, 1 - ambientLux / targetLux);
    const brightness = Math.round(minBrightness + (maxBrightness - minBrightness) * deficit);
    return {
      ...target,
      status: 'ready',
      reason: ambientLux < targetLux ? 'below_target_lux' : 'at_or_above_target_lux',
      ambientLux,
      sampleCount: readings.count,
      brightness,
    };
  });

  return { preferences, recommendations };
}
