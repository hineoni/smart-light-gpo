import { prisma } from '../lib/prisma';
import {
  assignDeviceZoneInStorage,
  getDevices,
  getUserDevice,
  updateDeviceAngles,
  updateDeviceLed,
} from './deviceStorage';
import { getPositioningSummary } from './positioningRuntime';
import { onlineDevices, sendServoCommand, sendToDevice } from './wsRuntime';

export interface RoomZone {
  id: string;
  name: string;
  x: number;
  y: number;
  heightM?: number;
  createdAt: string;
  updatedAt: string;
}

export interface SceneDeviceState {
  deviceId: string;
  zoneId?: string;
  brightness: number;
  colorR: number;
  colorG: number;
  colorB: number;
  servo1Angle: number;
  servo2Angle: number;
  uwbLocalAddress?: number;
  x?: number;
  y?: number;
  heightM?: number;
}

function nowIso() {
  return new Date().toISOString();
}

function toIso(value: Date | string | null | undefined) {
  if (!value) return nowIso();
  return value instanceof Date ? value.toISOString() : value;
}

function zoneIdFor(userId: string, slug: string) {
  return `${userId}:${slug}`;
}

function slugify(input: string) {
  const base = input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9а-яё]+/giu, '-')
    .replace(/^-+|-+$/g, '');
  return base || `item-${Date.now()}`;
}

function clamp01(value: unknown, fallback: number) {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.min(1, Math.max(0, value))
    : fallback;
}

function clampAngle(value: unknown, fallback: number) {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.min(180, Math.max(0, value))
    : fallback;
}

function clampByte(value: unknown, fallback: number) {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.min(255, Math.max(0, Math.round(value)))
    : fallback;
}

function normalizeBrightness(value: unknown, fallback = 255) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return value <= 1 ? clampByte(value * 255, fallback) : clampByte(value, fallback);
}

function toRoomZone(zone: any): RoomZone {
  return {
    id: zone.id,
    name: zone.name,
    x: zone.x,
    y: zone.y,
    heightM: zone.heightM ?? undefined,
    createdAt: toIso(zone.createdAt),
    updatedAt: toIso(zone.updatedAt),
  };
}

function toScene(scene: any) {
  return {
    id: scene.id,
    name: scene.name,
    zoneId: scene.zoneId ?? undefined,
    devices: (scene.devices ?? []).map((device: any) => ({
      deviceId: device.deviceId,
      zoneId: device.zoneId ?? undefined,
      brightness: device.brightness,
      colorR: device.colorR,
      colorG: device.colorG,
      colorB: device.colorB,
      servo1Angle: device.servo1Angle,
      servo2Angle: device.servo2Angle,
      uwbLocalAddress: device.uwbLocalAddress ?? undefined,
      x: device.x ?? undefined,
      y: device.y ?? undefined,
      heightM: device.heightM ?? undefined,
    })),
    positioningSnapshot: scene.positioningSnapshot,
    createdAt: toIso(scene.createdAt),
    updatedAt: toIso(scene.updatedAt),
  };
}

async function ensureDefaultZones(userId: string) {
  const count = await prisma.zone.count({ where: { userId } });
  if (count > 0) return;

  const defaults = [
    { id: zoneIdFor(userId, 'left-wall'), name: 'Левая стена', x: 0.12, y: 0.45, heightM: 1.6 },
    { id: zoneIdFor(userId, 'center'), name: 'Центр', x: 0.5, y: 0.5, heightM: 1.4 },
    { id: zoneIdFor(userId, 'table'), name: 'Стол', x: 0.55, y: 0.78, heightM: 0.8 },
    { id: zoneIdFor(userId, 'shelf'), name: 'Полка', x: 0.82, y: 0.34, heightM: 1.8 },
  ];

  await prisma.zone.createMany({
    data: defaults.map(zone => ({ ...zone, userId })),
    skipDuplicates: true,
  });
}

export async function listZones(userId: string) {
  await ensureDefaultZones(userId);
  const zones = await prisma.zone.findMany({
    where: { userId },
    orderBy: { name: 'asc' },
  });
  return zones.map(toRoomZone);
}

export async function upsertZone(
  userId: string,
  input: { id?: string; name: string; x?: number; y?: number; heightM?: number },
) {
  await ensureDefaultZones(userId);

  const id = input.id || zoneIdFor(userId, slugify(input.name));
  const existing = await prisma.zone.findFirst({ where: { id, userId } });
  const zone = await prisma.zone.upsert({
    where: { id },
    update: {
      name: input.name.trim() || existing?.name || 'Зона',
      x: clamp01(input.x, existing?.x ?? 0.5),
      y: clamp01(input.y, existing?.y ?? 0.5),
      heightM: typeof input.heightM === 'number' && Number.isFinite(input.heightM)
        ? Math.max(0, input.heightM)
        : existing?.heightM,
    },
    create: {
      id,
      userId,
      name: input.name.trim() || 'Зона',
      x: clamp01(input.x, 0.5),
      y: clamp01(input.y, 0.5),
      heightM: typeof input.heightM === 'number' && Number.isFinite(input.heightM)
        ? Math.max(0, input.heightM)
        : undefined,
    },
  });

  return toRoomZone(zone);
}

export async function assignDeviceZone(
  userId: string,
  deviceId: string,
  zoneId: string,
) {
  await ensureDefaultZones(userId);

  const [device, zone] = await Promise.all([
    getUserDevice(userId, deviceId),
    prisma.zone.findFirst({ where: { id: zoneId, userId } }),
  ]);

  if (!device) {
    throw new Error(`Device ${deviceId} not found`);
  }
  if (!zone) {
    throw new Error(`Zone ${zoneId} not found`);
  }

  await assignDeviceZoneInStorage(userId, deviceId, zoneId);
  return { deviceId, zoneId };
}

export async function listScenes(userId: string) {
  const scenes = await prisma.lightScene.findMany({
    where: { userId },
    include: { devices: true },
    orderBy: { updatedAt: 'desc' },
  });

  return scenes.map(toScene);
}

export async function deleteScene(userId: string, sceneId: string) {
  const scene = await prisma.lightScene.findFirst({
    where: { id: sceneId, userId },
  });
  if (!scene) return false;

  await prisma.lightScene.delete({ where: { id: sceneId } });
  return true;
}

export async function updateScene(
  userId: string,
  sceneId: string,
  input: { name?: string; zoneId?: string | null },
) {
  await ensureDefaultZones(userId);
  const scene = await prisma.lightScene.findFirst({
    where: { id: sceneId, userId },
    include: { devices: true },
  });
  if (!scene) {
    throw new Error(`Scene ${sceneId} not found`);
  }

  const nextZoneId = input.zoneId === null ? null : input.zoneId ?? scene.zoneId;
  const zone = nextZoneId
    ? await prisma.zone.findFirst({ where: { id: nextZoneId, userId } })
    : undefined;

  if (nextZoneId && !zone) {
    throw new Error(`Zone ${nextZoneId} not found`);
  }

  const updated = await prisma.$transaction(async tx => {
    await tx.lightScene.update({
      where: { id: sceneId },
      data: {
        name: typeof input.name === 'string' && input.name.trim().length > 0
          ? input.name.trim()
          : scene.name,
        zoneId: nextZoneId,
      },
    });

    if (input.zoneId !== undefined) {
      await tx.lightSceneDeviceState.updateMany({
        where: { sceneId },
        data: {
          zoneId: nextZoneId,
          x: zone?.x,
          y: zone?.y,
          heightM: zone?.heightM,
        },
      });
    }

    return tx.lightScene.findUnique({
      where: { id: sceneId },
      include: { devices: true },
    });
  });

  return toScene(updated);
}

async function buildSceneDeviceStates(userId: string, zoneId?: string): Promise<SceneDeviceState[]> {
  await ensureDefaultZones(userId);

  const [devices, zones] = await Promise.all([
    getDevices(userId),
    prisma.zone.findMany({ where: { userId } }),
  ]);
  const zoneById = new Map(zones.map(zone => [zone.id, zone]));
  const summary = getPositioningSummary(onlineDevices());
  const positionByDeviceId = new Map(summary.nodes.map((node, index) => [
    node.deviceId,
    { x: summary.nodes.length <= 1 ? 0.5 : index / Math.max(1, summary.nodes.length - 1), y: 0.5 },
  ]));

  return devices.map(device => {
    const assignedZoneId = device.zoneId ?? zoneId;
    const zone = assignedZoneId ? zoneById.get(assignedZoneId) : undefined;
    const position = positionByDeviceId.get(device.id);

    return {
      deviceId: device.id,
      zoneId: assignedZoneId,
      brightness: normalizeBrightness(device.brightness),
      colorR: device.colorR ?? 255,
      colorG: device.colorG ?? 255,
      colorB: device.colorB ?? 255,
      servo1Angle: device.servo1Angle ?? 90,
      servo2Angle: device.servo2Angle ?? 90,
      uwbLocalAddress: device.uwbLocalAddress,
      x: zone?.x ?? position?.x,
      y: zone?.y ?? position?.y,
      heightM: zone?.heightM,
    };
  });
}

export async function saveScene(
  userId: string,
  input: { name: string; zoneId?: string },
) {
  await ensureDefaultZones(userId);

  if (input.zoneId) {
    const zone = await prisma.zone.findFirst({
      where: { id: input.zoneId, userId },
    });
    if (!zone) {
      throw new Error(`Zone ${input.zoneId} not found`);
    }
  }

  const devices = await buildSceneDeviceStates(userId, input.zoneId);
  const scene = await prisma.lightScene.create({
    data: {
      userId,
      name: input.name.trim() || 'Сцена',
      zoneId: input.zoneId,
      positioningSnapshot: getPositioningSummary(onlineDevices()) as any,
      devices: {
        create: devices.map(device => ({
          deviceId: device.deviceId,
          zoneId: device.zoneId,
          brightness: device.brightness,
          colorR: device.colorR,
          colorG: device.colorG,
          colorB: device.colorB,
          servo1Angle: device.servo1Angle,
          servo2Angle: device.servo2Angle,
          uwbLocalAddress: device.uwbLocalAddress,
          x: device.x,
          y: device.y,
          heightM: device.heightM,
        })),
      },
    },
    include: { devices: true },
  });

  return toScene(scene);
}

export async function deleteZone(userId: string, zoneId: string) {
  await ensureDefaultZones(userId);
  const zone = await prisma.zone.findFirst({ where: { id: zoneId, userId } });
  if (!zone) return false;

  await prisma.$transaction([
    prisma.device.updateMany({
      where: { userId, zoneId },
      data: { zoneId: null },
    }),
    prisma.lightScene.updateMany({
      where: { userId, zoneId },
      data: { zoneId: null },
    }),
    prisma.lightSceneDeviceState.updateMany({
      where: {
        zoneId,
        scene: { userId },
      },
      data: { zoneId: null },
    }),
    prisma.zone.delete({ where: { id: zoneId } }),
  ]);

  return true;
}

export async function applyScene(userId: string, sceneId: string) {
  const scene = await prisma.lightScene.findFirst({
    where: { id: sceneId, userId },
    include: { devices: true },
  });
  if (!scene) {
    throw new Error(`Scene ${sceneId} not found`);
  }

  const results = [];
  for (const deviceState of scene.devices) {
    const brightness = normalizeBrightness(deviceState.brightness);
    const ledColorSent = sendToDevice(deviceState.deviceId, {
      type: 'set_led_color',
      r: deviceState.colorR,
      g: deviceState.colorG,
      b: deviceState.colorB,
    });
    const ledBrightnessSent = sendToDevice(deviceState.deviceId, {
      type: 'set_led_brightness',
      brightness,
    });
    const servo1Sent = sendServoCommand(deviceState.deviceId, 1, deviceState.servo1Angle);
    const servo2Sent = sendServoCommand(deviceState.deviceId, 2, deviceState.servo2Angle);

    await updateDeviceLed(
      deviceState.deviceId,
      brightness,
      deviceState.colorR,
      deviceState.colorG,
      deviceState.colorB,
    );
    await updateDeviceAngles(deviceState.deviceId, deviceState.servo1Angle, deviceState.servo2Angle);
    if (deviceState.zoneId) {
      await assignDeviceZoneInStorage(userId, deviceState.deviceId, deviceState.zoneId);
    }

    results.push({
      deviceId: deviceState.deviceId,
      ledColorSent,
      ledBrightnessSent,
      servo1Sent,
      servo2Sent,
    });
  }

  return { sceneId, results };
}

async function fallbackPose(userId: string, deviceId: string) {
  const devices = await getDevices(userId);
  const index = Math.max(0, devices.findIndex(device => device.id === deviceId));
  const count = Math.max(1, devices.length);
  return {
    x: count <= 1 ? 0.5 : 0.2 + (0.6 * index) / Math.max(1, count - 1),
    y: 0.5,
    heightM: 1.4,
  };
}

async function devicePose(userId: string, deviceId: string) {
  const device = await getUserDevice(userId, deviceId);
  const zone = device?.zoneId
    ? await prisma.zone.findFirst({ where: { id: device.zoneId, userId } })
    : undefined;
  const fallback = await fallbackPose(userId, deviceId);
  return {
    zoneId: device?.zoneId,
    x: zone?.x ?? fallback.x,
    y: zone?.y ?? fallback.y,
    heightM: zone?.heightM ?? fallback.heightM,
  };
}

function clampServo(value: number) {
  return Math.min(180, Math.max(0, Math.round(value)));
}

export async function aimDeviceAtTarget(
  userId: string,
  sourceDeviceId: string,
  targetDeviceId: string,
) {
  const [source, target] = await Promise.all([
    getUserDevice(userId, sourceDeviceId),
    getUserDevice(userId, targetDeviceId),
  ]);
  if (!source) {
    throw new Error(`Source device ${sourceDeviceId} not found`);
  }
  if (!target) {
    throw new Error(`Target device ${targetDeviceId} not found`);
  }

  const sourcePose = await devicePose(userId, sourceDeviceId);
  const targetPose = await devicePose(userId, targetDeviceId);
  const dx = targetPose.x - sourcePose.x;
  const dy = targetPose.y - sourcePose.y;
  const dz = targetPose.heightM - sourcePose.heightM;
  const horizontalDistance = Math.max(0.01, Math.hypot(dx, dy));
  const bearingDeg = (Math.atan2(dy, dx) * 180) / Math.PI;
  const elevationDeg = (Math.atan2(dz, horizontalDistance) * 180) / Math.PI;
  const servo1Angle = clampServo(90 + bearingDeg / 2);
  const servo2Angle = clampServo(90 - elevationDeg);

  const servo1Sent = sendServoCommand(sourceDeviceId, 1, servo1Angle);
  const servo2Sent = sendServoCommand(sourceDeviceId, 2, servo2Angle);
  await updateDeviceAngles(sourceDeviceId, servo1Angle, servo2Angle);

  return {
    sourceDeviceId,
    targetDeviceId,
    servo1Angle,
    servo2Angle,
    servo1Sent,
    servo2Sent,
    sourcePose,
    targetPose,
  };
}
