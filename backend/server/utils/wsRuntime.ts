interface RuntimeEntry {
  deviceId: string;
  peer: any; // Nitro CrossWS peer
  lastHeartbeat: number;
  servo1Angle?: number;
  servo2Angle?: number;
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
}

const runtime: Map<string, RuntimeEntry> = new Map(); // key: peer.id

export function registerPeer(deviceId: string, peer: any) {
  runtime.set(peer.id, { deviceId, peer, lastHeartbeat: Date.now() });
}

export function unregisterPeer(peerId: string) {
  runtime.delete(peerId);
}

export function updateHeartbeat(
  peerId: string,
  s1?: number,
  s2?: number,
  uwb?: {
    ready?: boolean;
    rangeCount?: number;
    uartBytes?: number;
    discardedBytes?: number;
    parsedFrames?: number;
    invalidFrames?: number;
    parsedLines?: number;
    invalidLines?: number;
    lastByteAtMs?: number;
    lastRxHex?: string;
  }
) {
  const entry = runtime.get(peerId);
  if (!entry) return null;
  entry.lastHeartbeat = Date.now();
  if (typeof s1 === 'number') entry.servo1Angle = s1;
  if (typeof s2 === 'number') entry.servo2Angle = s2;
  if (typeof uwb?.ready === 'boolean') entry.uwbReady = uwb.ready;
  if (typeof uwb?.rangeCount === 'number') entry.uwbRangeCount = uwb.rangeCount;
  if (typeof uwb?.uartBytes === 'number') entry.uwbUartBytes = uwb.uartBytes;
  if (typeof uwb?.discardedBytes === 'number') entry.uwbDiscardedBytes = uwb.discardedBytes;
  if (typeof uwb?.parsedFrames === 'number') entry.uwbParsedFrames = uwb.parsedFrames;
  if (typeof uwb?.invalidFrames === 'number') entry.uwbInvalidFrames = uwb.invalidFrames;
  if (typeof uwb?.parsedLines === 'number') entry.uwbParsedLines = uwb.parsedLines;
  if (typeof uwb?.invalidLines === 'number') entry.uwbInvalidLines = uwb.invalidLines;
  if (typeof uwb?.lastByteAtMs === 'number') entry.uwbLastByteAtMs = uwb.lastByteAtMs;
  if (typeof uwb?.lastRxHex === 'string') entry.uwbLastRxHex = uwb.lastRxHex;
  return entry;
}

export function getRuntimeByDevice(deviceId: string) {
  for (const e of runtime.values()) {
    if (e.deviceId === deviceId) return e;
  }
  return null;
}

export function onlineDevices(): Array<{
  deviceId: string;
  lastHeartbeat: number;
  servo1Angle?: number;
  servo2Angle?: number;
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
}> {
  const now = Date.now();
  return Array.from(runtime.values())
    .filter(e => now - e.lastHeartbeat < 30000) // 30s window
    .map(e => ({
      deviceId: e.deviceId,
      lastHeartbeat: e.lastHeartbeat,
      servo1Angle: e.servo1Angle,
      servo2Angle: e.servo2Angle,
      uwbReady: e.uwbReady,
      uwbRangeCount: e.uwbRangeCount,
      uwbUartBytes: e.uwbUartBytes,
      uwbDiscardedBytes: e.uwbDiscardedBytes,
      uwbParsedFrames: e.uwbParsedFrames,
      uwbInvalidFrames: e.uwbInvalidFrames,
      uwbParsedLines: e.uwbParsedLines,
      uwbInvalidLines: e.uwbInvalidLines,
      uwbLastByteAtMs: e.uwbLastByteAtMs,
      uwbLastRxHex: e.uwbLastRxHex,
    }));
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

