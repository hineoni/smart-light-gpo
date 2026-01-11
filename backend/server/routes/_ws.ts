import { getDevice, updateDeviceStatus, autoRegisterDevice } from '~/utils/deviceStorage';
import { registerPeer, unregisterPeer, updateHeartbeat } from '~/utils/wsRuntime';

interface IncomingBase { type: string; }
interface RegisterMsg extends IncomingBase { type: 'register'; deviceId: string; }
interface HeartbeatMsg extends IncomingBase { type: 'heartbeat'; servo1?: { angle: number }; servo2?: { angle: number }; }

type IncomingMessage = RegisterMsg | HeartbeatMsg | any;

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

    console.log(`[ws] incoming from ${peer.id}:`, payload.type, payload);

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
      const rt = updateHeartbeat(peer.id, payload.servo1?.angle, payload.servo2?.angle);
      if (rt?.deviceId) updateDeviceStatus(rt.deviceId, 'connected');
      peer.send(JSON.stringify({ type: 'ack', action: 'heartbeat' }));
      return;
    }

    // Unknown type
    peer.send(JSON.stringify({ type: 'error', error: 'unknown_type' }));
  },
  close(peer: any) {
    console.log('[ws] close', peer.id);
    unregisterPeer(peer.id);
  },
  error(peer: any, error: any) {
    console.log('[ws] error', peer.id, error);
  }
});
