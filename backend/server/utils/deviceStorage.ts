interface DeviceConfig {
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
  lastHeartbeat?: string; // ISO
  uwbReady?: boolean;
  uwbRangeCount?: number;
  uwbUartBytes?: number;
  uwbParsedFrames?: number;
  uwbInvalidFrames?: number;
  uwbParsedLines?: number;
  uwbInvalidLines?: number;
  uwbLastByteAtMs?: number;
}

let devices: Map<string, DeviceConfig> = new Map();

export function getDevices(): DeviceConfig[] {
  return Array.from(devices.values());
}

export function getDevice(id: string): DeviceConfig | undefined {
  return devices.get(id);
}

export function addDevice(name: string, ip: string, customId?: string): DeviceConfig {
  const id = customId || Date.now().toString(); // используем customId если предоставлен
  const device: DeviceConfig = {
    id,
    name,
    ip,
    status: 'disconnected',
    createdAt: new Date().toISOString(),
    brightness: 0.5,
    colorR: 255,
    colorG: 255,
    colorB: 255,
  };

  devices.set(id, device);
  return device;
}

export function deleteDevice(id: string): boolean {
  return devices.delete(id);
}

export function updateDeviceStatus(id: string, status: 'connected' | 'disconnected'): boolean {
  const device = devices.get(id);
  if (!device) return false;

  device.status = status;
  if (status === 'connected') {
    device.lastHeartbeat = new Date().toISOString();
  }
  devices.set(id, device);
  return true;
}

export function updateDeviceAngles(id: string, s1?: number, s2?: number) {
  const device = devices.get(id);
  if (!device) return;
  if (typeof s1 === 'number') device.servo1Angle = s1;
  if (typeof s2 === 'number') device.servo2Angle = s2;
  device.lastHeartbeat = new Date().toISOString();
  devices.set(id, device);
}

export function updateDeviceLed(id: string, brightness?: number, r?: number, g?: number, b?: number) {
  const device = devices.get(id);
  if (!device) return;
  if (typeof brightness === 'number') device.brightness = brightness;
  if (typeof r === 'number') device.colorR = r;
  if (typeof g === 'number') device.colorG = g;
  if (typeof b === 'number') device.colorB = b;
  device.lastHeartbeat = new Date().toISOString();
  devices.set(id, device);
}

export interface UwbDiagnostics {
  uartBytes?: number;
  parsedFrames?: number;
  invalidFrames?: number;
  parsedLines?: number;
  invalidLines?: number;
  lastByteAtMs?: number;
}

export function updateDeviceUwbStatus(
  id: string,
  ready?: boolean,
  rangeCount?: number,
  diagnostics?: UwbDiagnostics
) {
  const device = devices.get(id);
  if (!device) return;
  if (typeof ready === 'boolean') device.uwbReady = ready;
  if (typeof rangeCount === 'number') device.uwbRangeCount = rangeCount;
  if (typeof diagnostics?.uartBytes === 'number') device.uwbUartBytes = diagnostics.uartBytes;
  if (typeof diagnostics?.parsedFrames === 'number') device.uwbParsedFrames = diagnostics.parsedFrames;
  if (typeof diagnostics?.invalidFrames === 'number') device.uwbInvalidFrames = diagnostics.invalidFrames;
  if (typeof diagnostics?.parsedLines === 'number') device.uwbParsedLines = diagnostics.parsedLines;
  if (typeof diagnostics?.invalidLines === 'number') device.uwbInvalidLines = diagnostics.invalidLines;
  if (typeof diagnostics?.lastByteAtMs === 'number') device.uwbLastByteAtMs = diagnostics.lastByteAtMs;
  device.lastHeartbeat = new Date().toISOString();
  devices.set(id, device);
}

export function autoRegisterDevice(deviceId: string, ip: string): DeviceConfig {
  // Проверяем, не существует ли уже
  const existing = devices.get(deviceId);
  if (existing) {
    // Обновляем IP если изменился
    if (existing.ip !== ip) {
      existing.ip = ip;
      devices.set(deviceId, existing);
    }
    return existing;
  }

  // Создаем новое устройство с красивым именем
  const name = `Smart Light (${deviceId.split('_')[1] || deviceId.substring(0, 8)})`;
  return addDevice(name, ip, deviceId);
}
