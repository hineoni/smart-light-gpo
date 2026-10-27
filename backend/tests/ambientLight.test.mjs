import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseAmbientLight, currentAmbientLight } from '../server/utils/ambientLight.ts';

test('valid extremes retain zero and get a server timestamp', () => {
  assert.deepEqual(parseAmbientLight({ available: true, raw: 4095, percent: 0, receivedAt: 99999 }, 1000),
    { available: true, raw: 4095, percent: 0, receivedAt: 1000 });
  assert.equal(parseAmbientLight({ available: true, raw: 0, percent: 100 }, 1000).percent, 100);
});

test('missing, malformed and unavailable data do not become light measurements', () => {
  for (const value of [undefined, null, {}, { available: true },
    { available: true, raw: -1, percent: 20 }, { available: true, raw: 4096, percent: 20 },
    { available: true, raw: 1, percent: NaN }, { available: true, raw: 1, percent: '20' },
    { available: true, raw: 1, percent: 101 }, { available: true, raw: 1, percent: .5 }]) {
    assert.equal(parseAmbientLight(value, 1000), undefined);
  }
  assert.deepEqual(parseAmbientLight({ available: false, percent: 0 }, 1000), { available: false, receivedAt: 1000 });
});

test('readings expire independently of a device heartbeat', () => {
  const reading = parseAmbientLight({ available: true, raw: 20, percent: 100 }, 1000);
  assert.equal(currentAmbientLight(reading, 31000).available, true);
  assert.deepEqual(currentAmbientLight(reading, 31001), { available: false });
  assert.deepEqual(currentAmbientLight(undefined), { available: false });
});

test('lamp state is reported separately from ambient light and never fabricated', () => {
  const lamp = { available: true, isOn: false, brightness: 0, r: 255, g: 255, b: 255 };
  assert.deepEqual(parseAmbientLight({ available: false, lamp }, 1000), { available: false, receivedAt: 1000, lamp });
  assert.equal(parseAmbientLight({ available: true, raw: 100, percent: 90, lamp: { ...lamp, brightness: 150 } }, 1000).lamp, undefined);
  assert.equal(currentAmbientLight(parseAmbientLight({ available: false, lamp }, 1000), 32000).lamp, undefined);
});
