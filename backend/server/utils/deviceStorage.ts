import { prisma } from '../lib/prisma';

export interface DeviceConfig {
  id: string;
  name: string;
  ip: string;
  status: 'connected' | 'disconnected';
  createdAt: string;
  servo1Angle?: number;
  servo2Angle?: number;
  brightness?: number;
  colorR?: number;
  colorG?: number;
  colorB?: number;
  lastHeartbeat?: string;
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
  zoneId?: string;
  userId?: string;
}

export interface UwbDiagnostics {
  uartBytes?: number;
  discardedBytes?: number;
  parsedFrames?: number;
  invalidFrames?: number;
  parsedLines?: number;
  invalidLines?: number;
  lastByteAtMs?: number;
  lastRxHex?: string;
  autoConfig?: boolean;
  role?: number;
  pid?: number;
  period?: number;
  localAddress?: number;
  peer0Address?: number;
}

const runtimeDevices: Map<string, DeviceConfig> = new Map();

function toIso(value: Date | string | null | undefined) {
  if (!value) return undefined;
  return value instanceof Date ? value.toISOString() : value;
}

function toDeviceConfig(device: any): DeviceConfig {
  return {
    id: device.id,
    name: device.name,
    ip: device.ip,
    status: device.status === 'connected' ? 'connected' : 'disconnected',
    createdAt: toIso(device.createdAt) ?? new Date().toISOString(),
    servo1Angle: device.servo1Angle ?? undefined,
    servo2Angle: device.servo2Angle ?? undefined,
    brightness: device.brightness ?? undefined,
    colorR: device.colorR ?? undefined,
    colorG: device.colorG ?? undefined,
    colorB: device.colorB ?? undefined,
    lastHeartbeat: toIso(device.lastHeartbeat),
    uwbReady: device.uwbReady ?? undefined,
    uwbRangeCount: device.uwbRangeCount ?? undefined,
    uwbUartBytes: device.uwbUartBytes ?? undefined,
    uwbDiscardedBytes: device.uwbDiscardedBytes ?? undefined,
    uwbParsedFrames: device.uwbParsedFrames ?? undefined,
    uwbInvalidFrames: device.uwbInvalidFrames ?? undefined,
    uwbParsedLines: device.uwbParsedLines ?? undefined,
    uwbInvalidLines: device.uwbInvalidLines ?? undefined,
    uwbLastByteAtMs: device.uwbLastByteAtMs ?? undefined,
    uwbLastRxHex: device.uwbLastRxHex ?? undefined,
    uwbAutoConfig: device.uwbAutoConfig ?? undefined,
    uwbRole: device.uwbRole ?? undefined,
    uwbPid: device.uwbPid ?? undefined,
    uwbPeriod: device.uwbPeriod ?? undefined,
    uwbLocalAddress: device.uwbLocalAddress ?? undefined,
    uwbPeer0Address: device.uwbPeer0Address ?? undefined,
    zoneId: device.zoneId ?? undefined,
    userId: device.userId ?? undefined,
  };
}

function mergeRuntime(device: DeviceConfig) {
  runtimeDevices.set(device.id, {
    ...runtimeDevices.get(device.id),
    ...device,
  });
  return runtimeDevices.get(device.id)!;
}

function defaultName(deviceId: string) {
  return `Smart Light (${deviceId.split('_')[1] || deviceId.substring(0, 8)})`;
}

export async function getDevices(userId: string): Promise<DeviceConfig[]> {
  const devices = await prisma.device.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
  });

  return devices.map(device => mergeRuntime(toDeviceConfig(device)));
}

export async function getUserDevice(
  userId: string,
  id: string,
): Promise<DeviceConfig | undefined> {
  const device = await prisma.device.findFirst({
    where: { id, userId },
  });

  return device ? mergeRuntime(toDeviceConfig(device)) : undefined;
}

export async function getDevice(id: string): Promise<DeviceConfig | undefined> {
  const runtime = runtimeDevices.get(id);
  if (runtime) return runtime;

  const device = await prisma.device.findUnique({
    where: { id },
  });

  return device ? mergeRuntime(toDeviceConfig(device)) : undefined;
}

export async function addDevice(
  userId: string,
  name: string,
  ip: string,
  customId?: string,
): Promise<DeviceConfig> {
  const id = customId || Date.now().toString();
  const existing = await prisma.device.findUnique({ where: { id } });

  if (existing?.userId && existing.userId !== userId) {
    throw new Error('Device already belongs to another user');
  }

  const runtime = runtimeDevices.get(id);
  const device = await prisma.device.upsert({
    where: { id },
    update: {
      userId,
      name: name.trim() || existing?.name || runtime?.name || defaultName(id),
      ip: ip || existing?.ip || runtime?.ip || 'unknown',
    },
    create: {
      id,
      userId,
      name: name.trim() || runtime?.name || defaultName(id),
      ip: ip || runtime?.ip || 'unknown',
      status: runtime?.status ?? 'disconnected',
      brightness: runtime?.brightness ?? 0.5,
      colorR: runtime?.colorR ?? 255,
      colorG: runtime?.colorG ?? 255,
      colorB: runtime?.colorB ?? 255,
    },
  });

  return mergeRuntime(toDeviceConfig(device));
}

export async function claimOnlineDevices(
  userId: string,
  onlineDeviceIds: string[],
): Promise<DeviceConfig[]> {
  const uniqueIds = Array.from(new Set(onlineDeviceIds.filter(Boolean)));
  if (uniqueIds.length === 0) return [];

  await prisma.device.updateMany({
    where: {
      id: { in: uniqueIds },
      userId: null,
    },
    data: { userId },
  });

  const devices = await prisma.device.findMany({
    where: {
      id: { in: uniqueIds },
      userId,
    },
    orderBy: { createdAt: 'asc' },
  });

  return devices.map(device => mergeRuntime(toDeviceConfig(device)));
}

export async function deleteDevice(userId: string, id: string): Promise<boolean> {
  const device = await prisma.device.findFirst({ where: { id, userId } });
  if (!device) return false;

  await prisma.device.update({
    where: { id },
    data: {
      userId: null,
      zoneId: null,
    },
  });

  const runtime = runtimeDevices.get(id);
  if (runtime) {
    runtime.userId = undefined;
    runtime.zoneId = undefined;
    runtimeDevices.set(id, runtime);
  }

  return true;
}

export async function renameDevice(
  userId: string,
  id: string,
  name: string,
): Promise<DeviceConfig | undefined> {
  const device = await prisma.device.findFirst({ where: { id, userId } });
  if (!device) return undefined;

  const updated = await prisma.device.update({
    where: { id },
    data: { name },
  });

  return mergeRuntime(toDeviceConfig(updated));
}

export async function assignDeviceZoneInStorage(
  userId: string,
  deviceId: string,
  zoneId: string | null,
) {
  const device = await prisma.device.findFirst({
    where: { id: deviceId, userId },
  });
  if (!device) return undefined;

  const updated = await prisma.device.update({
    where: { id: deviceId },
    data: { zoneId },
  });

  return mergeRuntime(toDeviceConfig(updated));
}

export async function updateDeviceStatus(
  id: string,
  status: 'connected' | 'disconnected',
): Promise<boolean> {
  const runtime = runtimeDevices.get(id);
  const lastHeartbeat = status === 'connected' ? new Date() : undefined;
  if (runtime) {
    runtime.status = status;
    if (lastHeartbeat) runtime.lastHeartbeat = lastHeartbeat.toISOString();
    runtimeDevices.set(id, runtime);
  }

  try {
    await prisma.device.update({
      where: { id },
      data: {
        status,
        ...(lastHeartbeat ? { lastHeartbeat } : {}),
      },
    });
    return true;
  } catch {
    return false;
  }
}

export async function updateDeviceAngles(id: string, s1?: number, s2?: number) {
  const runtime = runtimeDevices.get(id);
  if (runtime) {
    if (typeof s1 === 'number') runtime.servo1Angle = s1;
    if (typeof s2 === 'number') runtime.servo2Angle = s2;
    runtime.lastHeartbeat = new Date().toISOString();
    runtimeDevices.set(id, runtime);
  }

  await prisma.device.update({
    where: { id },
    data: {
      ...(typeof s1 === 'number' ? { servo1Angle: s1 } : {}),
      ...(typeof s2 === 'number' ? { servo2Angle: s2 } : {}),
      lastHeartbeat: new Date(),
    },
  }).catch(() => undefined);
}

export async function updateDeviceLed(
  id: string,
  brightness?: number,
  r?: number,
  g?: number,
  b?: number,
) {
  const runtime = runtimeDevices.get(id);
  if (runtime) {
    if (typeof brightness === 'number') runtime.brightness = brightness;
    if (typeof r === 'number') runtime.colorR = r;
    if (typeof g === 'number') runtime.colorG = g;
    if (typeof b === 'number') runtime.colorB = b;
    runtime.lastHeartbeat = new Date().toISOString();
    runtimeDevices.set(id, runtime);
  }

  await prisma.device.update({
    where: { id },
    data: {
      ...(typeof brightness === 'number' ? { brightness } : {}),
      ...(typeof r === 'number' ? { colorR: r } : {}),
      ...(typeof g === 'number' ? { colorG: g } : {}),
      ...(typeof b === 'number' ? { colorB: b } : {}),
      lastHeartbeat: new Date(),
    },
  }).catch(() => undefined);
}

export async function updateDeviceUwbStatus(
  id: string,
  ready?: boolean,
  rangeCount?: number,
  diagnostics?: UwbDiagnostics,
) {
  const runtime = runtimeDevices.get(id);
  if (runtime) {
    if (typeof ready === 'boolean') runtime.uwbReady = ready;
    if (typeof rangeCount === 'number') runtime.uwbRangeCount = rangeCount;
    if (typeof diagnostics?.uartBytes === 'number') runtime.uwbUartBytes = diagnostics.uartBytes;
    if (typeof diagnostics?.discardedBytes === 'number') runtime.uwbDiscardedBytes = diagnostics.discardedBytes;
    if (typeof diagnostics?.parsedFrames === 'number') runtime.uwbParsedFrames = diagnostics.parsedFrames;
    if (typeof diagnostics?.invalidFrames === 'number') runtime.uwbInvalidFrames = diagnostics.invalidFrames;
    if (typeof diagnostics?.parsedLines === 'number') runtime.uwbParsedLines = diagnostics.parsedLines;
    if (typeof diagnostics?.invalidLines === 'number') runtime.uwbInvalidLines = diagnostics.invalidLines;
    if (typeof diagnostics?.lastByteAtMs === 'number') runtime.uwbLastByteAtMs = diagnostics.lastByteAtMs;
    if (typeof diagnostics?.lastRxHex === 'string') runtime.uwbLastRxHex = diagnostics.lastRxHex;
    if (typeof diagnostics?.autoConfig === 'boolean') runtime.uwbAutoConfig = diagnostics.autoConfig;
    if (typeof diagnostics?.role === 'number') runtime.uwbRole = diagnostics.role;
    if (typeof diagnostics?.pid === 'number') runtime.uwbPid = diagnostics.pid;
    if (typeof diagnostics?.period === 'number') runtime.uwbPeriod = diagnostics.period;
    if (typeof diagnostics?.localAddress === 'number') runtime.uwbLocalAddress = diagnostics.localAddress;
    if (typeof diagnostics?.peer0Address === 'number') runtime.uwbPeer0Address = diagnostics.peer0Address;
    runtime.lastHeartbeat = new Date().toISOString();
    runtimeDevices.set(id, runtime);
  }

  await prisma.device.update({
    where: { id },
    data: {
      ...(typeof ready === 'boolean' ? { uwbReady: ready } : {}),
      ...(typeof rangeCount === 'number' ? { uwbRangeCount: rangeCount } : {}),
      ...(typeof diagnostics?.uartBytes === 'number' ? { uwbUartBytes: diagnostics.uartBytes } : {}),
      ...(typeof diagnostics?.discardedBytes === 'number' ? { uwbDiscardedBytes: diagnostics.discardedBytes } : {}),
      ...(typeof diagnostics?.parsedFrames === 'number' ? { uwbParsedFrames: diagnostics.parsedFrames } : {}),
      ...(typeof diagnostics?.invalidFrames === 'number' ? { uwbInvalidFrames: diagnostics.invalidFrames } : {}),
      ...(typeof diagnostics?.parsedLines === 'number' ? { uwbParsedLines: diagnostics.parsedLines } : {}),
      ...(typeof diagnostics?.invalidLines === 'number' ? { uwbInvalidLines: diagnostics.invalidLines } : {}),
      ...(typeof diagnostics?.lastByteAtMs === 'number' ? { uwbLastByteAtMs: diagnostics.lastByteAtMs } : {}),
      ...(typeof diagnostics?.lastRxHex === 'string' ? { uwbLastRxHex: diagnostics.lastRxHex } : {}),
      ...(typeof diagnostics?.autoConfig === 'boolean' ? { uwbAutoConfig: diagnostics.autoConfig } : {}),
      ...(typeof diagnostics?.role === 'number' ? { uwbRole: diagnostics.role } : {}),
      ...(typeof diagnostics?.pid === 'number' ? { uwbPid: diagnostics.pid } : {}),
      ...(typeof diagnostics?.period === 'number' ? { uwbPeriod: diagnostics.period } : {}),
      ...(typeof diagnostics?.localAddress === 'number' ? { uwbLocalAddress: diagnostics.localAddress } : {}),
      ...(typeof diagnostics?.peer0Address === 'number' ? { uwbPeer0Address: diagnostics.peer0Address } : {}),
      lastHeartbeat: new Date(),
    },
  }).catch(() => undefined);
}

export async function autoRegisterDevice(
  deviceId: string,
  ip: string,
): Promise<DeviceConfig> {
  const existing = runtimeDevices.get(deviceId);
  if (existing) {
    if (existing.ip !== ip) {
      existing.ip = ip;
      runtimeDevices.set(deviceId, existing);
    }
  }

  const device = await prisma.device.upsert({
    where: { id: deviceId },
    update: {
      ip,
      updatedAt: new Date(),
    },
    create: {
      id: deviceId,
      name: defaultName(deviceId),
      ip,
      status: 'disconnected',
      brightness: 0.5,
      colorR: 255,
      colorG: 255,
      colorB: 255,
    },
  });

  return mergeRuntime(toDeviceConfig(device));
}
