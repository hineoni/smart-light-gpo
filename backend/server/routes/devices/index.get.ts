import { requireUserId } from '~/lib/currentUser';
import { getDevices } from '~/utils/deviceStorage';

export default defineEventHandler(async (event) => {
  return getDevices(requireUserId(event));
});
