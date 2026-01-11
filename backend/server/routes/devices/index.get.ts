import { getDevices } from '~/utils/deviceStorage';

export default defineEventHandler(async () => {
  return getDevices();
});
