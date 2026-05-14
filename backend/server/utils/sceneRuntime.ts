import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
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
const stateFilePath = join(process.cwd(), '.data', 'scene-state.json');
let stateLoaded = false;

interface PersistedSceneState {
  zones?: RoomZone[];
  scenes?: LightScene[];
  deviceZoneIds?: Array<[string, string]>;
}

function loadState() {
  if (stateLoaded) return;
  stateLoaded = true;

  if (!existsSync(stateFilePath)) return;

  try {
    const state = JSON.parse(readFileSync(stateFilePath, 'utf8')) as PersistedSceneState;
    for (const zone of state.zones ?? []) {
      zones.set(zone.id, zone);
    }
    for (const scene of state.scenes ?? []) {
      scenes.set(scene.id, scene);
    }
    for (const [deviceId, zoneId] of state.deviceZoneIds ?? []) {
      deviceZoneIds.set(deviceId, zoneId);
    }
  } catch (error) {
    console.warn('[sceneRuntime] failed to load scene state:', error);
  }
}

function saveState() {
  try {
    mkdirSync(dirname(stateFilePath), { recursive: true });
    writeFileSync(
      stateFilePath,
      JSON.stringify({
        zones: Array.from(zones.values()),
        scenes: Array.from(scenes.values()),
        deviceZoneIds: Array.from(deviceZoneIds.entries()),
      } satisfies PersistedSceneState, null, 2)
    );
  } catch (error) {
    console.warn('[sceneRuntime] failed to save scene state:', error);
  }
}

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
  loadState();
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
  saveState();
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
  saveState();
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
  saveState();
  return { deviceId, zoneId };
}

export function listScenes() {
  loadState();
  return Array.from(scenes.values()).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
}

export function deleteScene(sceneId: string) {
  loadState();
  const deleted = scenes.delete(sceneId);
  if (deleted) saveState();
  return deleted;
}

export function saveScene(input: { name: string; zoneId?: string }) {
  ensureDefaultZones();
  const timestamp = nowIso();
  const id = `scene-${Date.now()}`;
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
  saveState();
  return scene;
}

export function applyScene(sceneId: string) {
  loadState();
  const scene = scenes.get(sceneId);
  if (!scene) {
    throw new Error(`Scene ${sceneId} not found`);
  }

  const results = scene.devices.map(deviceState => {
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

    updateDeviceLed(
      deviceState.deviceId,
      brightness,
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

  saveState();
  return { sceneId, results };
}

function fallbackPose(deviceId: string) {
  const devices = getDevices();
  const index = Math.max(0, devices.findIndex(device => device.id === deviceId));
  const count = Math.max(1, devices.length);
  return {
    x: count <= 1 ? 0.5 : 0.2 + (0.6 * index) / Math.max(1, count - 1),
    y: 0.5,
    heightM: 1.4,
  };
}

function devicePose(deviceId: string) {
  const assignedZoneId = deviceZoneIds.get(deviceId);
  const zone = assignedZoneId ? zones.get(assignedZoneId) : undefined;
  return {
    zoneId: assignedZoneId,
    x: zone?.x ?? fallbackPose(deviceId).x,
    y: zone?.y ?? fallbackPose(deviceId).y,
    heightM: zone?.heightM ?? fallbackPose(deviceId).heightM,
  };
}

function clampServo(value: number) {
  return Math.min(180, Math.max(0, Math.round(value)));
}

export function aimDeviceAtTarget(sourceDeviceId: string, targetDeviceId: string) {
  const source = getDevice(sourceDeviceId);
  const target = getDevice(targetDeviceId);
  if (!source) {
    throw new Error(`Source device ${sourceDeviceId} not found`);
  }
  if (!target) {
    throw new Error(`Target device ${targetDeviceId} not found`);
  }

  ensureDefaultZones();
  const sourcePose = devicePose(sourceDeviceId);
  const targetPose = devicePose(targetDeviceId);
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
  updateDeviceAngles(sourceDeviceId, servo1Angle, servo2Angle);

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
