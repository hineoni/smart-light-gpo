import { getDevices, getDevice, updateDeviceAngles, updateDeviceLed } from './deviceStorage';
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

export interface LightScene {
  id: string;
  name: string;
  zoneId?: string;
  devices: SceneDeviceState[];
  positioningSnapshot: ReturnType<typeof getPositioningSummary>;
  createdAt: string;
  updatedAt: string;
}

const zones = new Map<string, RoomZone>();
const scenes = new Map<string, LightScene>();
const deviceZoneIds = new Map<string, string>();

function nowIso() {
  return new Date().toISOString();
}

function slugify(input: string) {
  const base = input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9а-яё]+/giu, '-')
    .replace(/^-+|-+$/g, '');
  return base || `item-${Date.now()}`;
}

function ensureDefaultZones() {
  if (zones.size > 0) return;

  const createdAt = nowIso();
  const defaults: Array<Omit<RoomZone, 'createdAt' | 'updatedAt'>> = [
    { id: 'left-wall', name: 'Левая стена', x: 0.12, y: 0.45, heightM: 1.6 },
    { id: 'center', name: 'Центр', x: 0.5, y: 0.5, heightM: 1.4 },
    { id: 'table', name: 'Стол', x: 0.55, y: 0.78, heightM: 0.8 },
    { id: 'shelf', name: 'Полка', x: 0.82, y: 0.34, heightM: 1.8 },
  ];

  for (const zone of defaults) {
    zones.set(zone.id, { ...zone, createdAt, updatedAt: createdAt });
  }
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

function buildSceneDeviceStates(zoneId?: string): SceneDeviceState[] {
  const summary = getPositioningSummary(onlineDevices());
  const positionByDeviceId = new Map(summary.nodes.map((node, index) => [
    node.deviceId,
    { x: summary.nodes.length <= 1 ? 0.5 : index / Math.max(1, summary.nodes.length - 1), y: 0.5 },
  ]));

  return getDevices().map(device => {
    const assignedZoneId = deviceZoneIds.get(device.id) ?? zoneId;
    const zone = assignedZoneId ? zones.get(assignedZoneId) : undefined;
    const position = positionByDeviceId.get(device.id);

    return {
      deviceId: device.id,
      zoneId: assignedZoneId,
      brightness: device.brightness ?? 0.5,
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

export function listZones() {
  ensureDefaultZones();
  return Array.from(zones.values()).sort((a, b) => a.name.localeCompare(b.name));
}

export function upsertZone(input: {
  id?: string;
  name: string;
  x?: number;
  y?: number;
  heightM?: number;
}) {
  ensureDefaultZones();

  const id = input.id || slugify(input.name);
  const existing = zones.get(id);
  const timestamp = nowIso();
  const zone: RoomZone = {
    id,
    name: input.name.trim() || existing?.name || 'Зона',
    x: clamp01(input.x, existing?.x ?? 0.5),
    y: clamp01(input.y, existing?.y ?? 0.5),
    heightM: typeof input.heightM === 'number' && Number.isFinite(input.heightM)
      ? Math.max(0, input.heightM)
      : existing?.heightM,
    createdAt: existing?.createdAt ?? timestamp,
    updatedAt: timestamp,
  };
  zones.set(id, zone);
  return zone;
}

export function assignDeviceZone(deviceId: string, zoneId: string) {
  ensureDefaultZones();
  if (!getDevice(deviceId)) {
    throw new Error(`Device ${deviceId} not found`);
  }
  if (!zones.has(zoneId)) {
    throw new Error(`Zone ${zoneId} not found`);
  }
  deviceZoneIds.set(deviceId, zoneId);
  return { deviceId, zoneId };
}

export function listScenes() {
  return Array.from(scenes.values()).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
}

export function saveScene(input: { name: string; zoneId?: string }) {
  ensureDefaultZones();
  const timestamp = nowIso();
  const id = `${slugify(input.name)}-${Date.now()}`;
  const scene: LightScene = {
    id,
    name: input.name.trim() || 'Сцена',
    zoneId: input.zoneId,
    devices: buildSceneDeviceStates(input.zoneId),
    positioningSnapshot: getPositioningSummary(onlineDevices()),
    createdAt: timestamp,
    updatedAt: timestamp,
  };
  scenes.set(id, scene);
  return scene;
}

export function applyScene(sceneId: string) {
  const scene = scenes.get(sceneId);
  if (!scene) {
    throw new Error(`Scene ${sceneId} not found`);
  }

  const results = scene.devices.map(deviceState => {
    const ledColorSent = sendToDevice(deviceState.deviceId, {
      type: 'set_led_color',
      r: deviceState.colorR,
      g: deviceState.colorG,
      b: deviceState.colorB,
    });
    const ledBrightnessSent = sendToDevice(deviceState.deviceId, {
      type: 'set_led_brightness',
      brightness: Math.round(deviceState.brightness * 255),
    });
    const servo1Sent = sendServoCommand(deviceState.deviceId, 1, deviceState.servo1Angle);
    const servo2Sent = sendServoCommand(deviceState.deviceId, 2, deviceState.servo2Angle);

    updateDeviceLed(
      deviceState.deviceId,
      Math.round(deviceState.brightness * 255),
      deviceState.colorR,
      deviceState.colorG,
      deviceState.colorB
    );
    updateDeviceAngles(deviceState.deviceId, deviceState.servo1Angle, deviceState.servo2Angle);
    if (deviceState.zoneId) {
      deviceZoneIds.set(deviceState.deviceId, deviceState.zoneId);
    }

    return {
      deviceId: deviceState.deviceId,
      ledColorSent,
      ledBrightnessSent,
      servo1Sent,
      servo2Sent,
    };
  });

  return { sceneId, results };
}

