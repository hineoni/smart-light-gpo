interface RuntimeEntry {
  deviceId: string;
  peer: any; // Nitro CrossWS peer
  lastHeartbeat: number;
  servo1Angle?: number;
  servo2Angle?: number;
}

const runtime: Map<string, RuntimeEntry> = new Map(); // key: peer.id

export function registerPeer(deviceId: string, peer: any) {
  runtime.set(peer.id, { deviceId, peer, lastHeartbeat: Date.now() });
}

export function unregisterPeer(peerId: string) {
  runtime.delete(peerId);
}

export function updateHeartbeat(peerId: string, s1?: number, s2?: number) {
  const entry = runtime.get(peerId);
  if (!entry) return null;
  entry.lastHeartbeat = Date.now();
  if (typeof s1 === 'number') entry.servo1Angle = s1;
  if (typeof s2 === 'number') entry.servo2Angle = s2;
  return entry;
}

export function getRuntimeByDevice(deviceId: string) {
  for (const e of runtime.values()) {
    if (e.deviceId === deviceId) return e;
  }
  return null;
}

export function onlineDevices(): Array<{ deviceId: string; lastHeartbeat: number; servo1Angle?: number; servo2Angle?: number }> {
  const now = Date.now();
  return Array.from(runtime.values())
    .filter(e => now - e.lastHeartbeat < 30000) // 30s window
    .map(e => ({ deviceId: e.deviceId, lastHeartbeat: e.lastHeartbeat, servo1Angle: e.servo1Angle, servo2Angle: e.servo2Angle }));
}

export function sendServoCommand(deviceId: string, servo: number, angle: number) {
  const entry = getRuntimeByDevice(deviceId);
  if (!entry) return false;
  entry.peer.send(JSON.stringify({ type: 'set_servo', id: servo, angle }));
  return true;
}

export function sendToDevice(deviceId: string, command: any) {
  const entry = getRuntimeByDevice(deviceId);
  if (!entry) return false;
  entry.peer.send(JSON.stringify(command));
  return true;
}

