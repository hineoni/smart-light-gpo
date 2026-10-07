import { scenePresets } from '~/utils/sceneRuntime';

export default defineEventHandler(() => scenePresets.map(({ key, name, description }) => ({
  key,
  name,
  description,
})));