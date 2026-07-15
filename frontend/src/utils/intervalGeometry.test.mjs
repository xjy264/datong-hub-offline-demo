import { test } from 'node:test'
import assert from 'node:assert/strict'
import { intervalGeometry, intervalPreviewGeometry } from './intervalGeometry.ts'

test('free interval geometry uses its stored position length and absolute angle', () => {
  assert.deepEqual(intervalGeometry({ x: 460.5, y: 286.2, length: 42, angle: 30 }), {
    x: 460.5,
    y: 286.2,
    width: 42,
    angle: 30
  })
})

test('selected interval previews unsaved form geometry', () => {
  const interval = { id: 'interval-1', x: 100, y: 200, length: 12, angle: 0 }
  const form = { x: 130, y: 240, length: 80, angle: -45 }

  assert.deepEqual(intervalPreviewGeometry(interval, 'interval-1', form), {
    x: 130,
    y: 240,
    width: 80,
    angle: -45
  })
  assert.deepEqual(intervalPreviewGeometry(interval, 'another-interval', form), {
    x: 100,
    y: 200,
    width: 12,
    angle: 0
  })
})
