import { defineNitroConfig } from 'nitropack/config'

export default defineNitroConfig({
  compatibilityDate: 'latest',
  srcDir: 'server',
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
