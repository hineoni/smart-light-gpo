import { getDevice, updateDeviceStatus, autoRegisterDevice, updateDeviceUwbStatus } from '~/utils/deviceStorage';
import { registerPeer, unregisterPeer, updateHeartbeat } from '~/utils/wsRuntime';
import { updateDeviceRanges } from '~/utils/positioningRuntime';

interface IncomingBase { type: string; }
interface RegisterMsg extends IncomingBase { type: 'register'; deviceId: string; }
interface HeartbeatMsg extends IncomingBase {
  type: 'heartbeat';
  servo1?: { angle: number };
  servo2?: { angle: number };
  uwb?: {
    ready?: boolean;
    rangeCount?: number;
    uartBytes?: number;
    parsedFrames?: number;
    invalidFrames?: number;
    parsedLines?: number;
    invalidLines?: number;
    lastByteAtMs?: number;
    ranges?: Array<{ peerId: string; distanceM: number; updatedAtMs?: number; rssiDbm?: number }>;
  };
}

type IncomingMessage = RegisterMsg | HeartbeatMsg | any;
const heartbeatLogAtByPeer = new Map<string, number>();

function logIncoming(peerId: string, payload: IncomingMessage) {
  if (payload.type !== 'heartbeat') {
    console.log(`[ws] incoming from ${peerId}:`, payload.type, payload);
    return;
  }

  const now = Date.now();
  const lastLogAt = heartbeatLogAtByPeer.get(peerId) ?? 0;
  if (now - lastLogAt < 5000) return;

  heartbeatLogAtByPeer.set(peerId, now);
  console.log(`[ws] heartbeat from ${peerId}:`, {
    servo1: payload.servo1,
    servo2: payload.servo2,
    uwb: payload.uwb,
  });
}

export default defineWebSocketHandler({
  open(peer: any) {
    console.log('[ws] open', peer.id);
  },
  message(peer: any, message: any) {
    let payload: IncomingMessage;
    try {
      payload = JSON.parse(message.text());
    } catch (e) {
      console.log(`[ws] incoming from ${peer.id}: invalid_json`);
      peer.send(JSON.stringify({ type: 'error', error: 'invalid_json' }));
      return;
    }

    logIncoming(peer.id, payload);

    if (payload.type === 'register') {
      const { deviceId } = payload as RegisterMsg;
      
      // Пытаемся получить устройство или автоматически регистрируем
      let dev = getDevice(deviceId);
      if (!dev) {
        console.log(`[ws] auto-registering new device: ${deviceId}`);
        // Получаем IP адрес из peer (если доступен)
        const clientIP = peer.request?.socket?.remoteAddress || 'unknown';
        dev = autoRegisterDevice(deviceId, clientIP);
      }
      
      registerPeer(deviceId, peer);
      updateDeviceStatus(deviceId, 'connected');
      peer.send(JSON.stringify({ type: 'ack', action: 'register', deviceId }));
      console.log(`[ws] device ${deviceId} registered successfully`);
      return;
    }

    if (payload.type === 'heartbeat') {
      const rt = updateHeartbeat(peer.id, payload.servo1?.angle, payload.servo2?.angle, payload.uwb);
      if (rt?.deviceId) {
        updateDeviceStatus(rt.deviceId, 'connected');
        updateDeviceUwbStatus(rt.deviceId, payload.uwb?.ready, payload.uwb?.rangeCount, payload.uwb);
        updateDeviceRanges(rt.deviceId, payload.uwb?.ranges);
      }
      peer.send(JSON.stringify({ type: 'ack', action: 'heartbeat' }));
      return;
    }

    // Unknown type
    peer.send(JSON.stringify({ type: 'error', error: 'unknown_type' }));
  },
  close(peer: any) {
    console.log('[ws] close', peer.id);
    heartbeatLogAtByPeer.delete(peer.id);
    unregisterPeer(peer.id);
  },
  error(peer: any, error: any) {
    console.log('[ws] error', peer.id, error);
  }
});
