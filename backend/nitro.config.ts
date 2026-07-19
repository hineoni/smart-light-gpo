import { defineNitroConfig } from 'nitropack/config'

export default defineNitroConfig({
  compatibilityDate: 'latest',
  srcDir: 'server',
  ignore: ['.output/**', '.nitro/**'],
  watchOptions: {
    ignored: ['**/.output/**', '**/.nitro/**'],
  },
  experimental: {
    websocket: true,
    openAPI: true
  },
  openAPI: {
    ui: {
      swagger: false,
      scalar: {
        theme: "default"
      }
    }
  },
});
