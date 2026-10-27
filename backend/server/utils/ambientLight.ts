export interface AmbientLightReading {
  available: boolean;
  raw?: number;
  percent?: number;
  receivedAt: number;
  lamp?: { available: true; isOn: boolean; brightness: number; r: number; g: number; b: number };
}

export function parseAmbientLight(value: unknown, now = Date.now()): AmbientLightReading | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const data = value as Record<string, unknown>;
  const led = data.lamp as Record<string, unknown> | undefined;
  const lamp = led?.available === true && typeof led.isOn === 'boolean' &&
    ['brightness', 'r', 'g', 'b'].every(key => Number.isInteger(led[key]) && (led[key] as number) >= 0 && (led[key] as number) <= 255) &&
    led.isOn === ((led.brightness as number) > 0)
    ? { available: true as const, isOn: led.isOn, brightness: led.brightness as number,
        r: led.r as number, g: led.g as number, b: led.b as number } : undefined;
  if (data.available === false) return { available: false, receivedAt: now, ...(lamp ? { lamp } : {}) };
  if (data.available !== true ||
      !Number.isInteger(data.raw) || (data.raw as number) < 0 || (data.raw as number) > 4095 ||
      !Number.isInteger(data.percent) || (data.percent as number) < 0 || (data.percent as number) > 100) {
    return undefined;
  }
  return { available: true, raw: data.raw as number, percent: data.percent as number, receivedAt: now, ...(lamp ? { lamp } : {}) };
}

export function currentAmbientLight(reading: AmbientLightReading | undefined, now = Date.now()) {
  if (!reading || now - reading.receivedAt > 30000) return { available: false };
  return reading;
}
