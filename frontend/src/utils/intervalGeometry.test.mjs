import { test } from 'node:test'
import assert from 'node:assert/strict'
import { intervalGeometry, intervalPreviewDirection } from './intervalGeometry.ts'

test('interval hit area extends under endpoint buttons to avoid dead zones', () => {
  assert.deepEqual(intervalGeometry({ x: 10, y: 20 }, { x: 110, y: 20 }), {
    x: 60,
    y: 20,
    width: 98,
    angle: 0
  })
})

test('interval geometry follows vertical station movement', () => {
  assert.deepEqual(intervalGeometry({ x: 30, y: 10 }, { x: 30, y: 110 }), {
    x: 30,
    y: 60,
    width: 98,
    angle: 90
  })
})

test('short interval keeps a readable bar between nearby station dots', () => {
  const geometry = intervalGeometry({ x: 455.49, y: 286.23 }, { x: 467.59, y: 285.93 })

  assert.ok(Math.abs(geometry.x - 461.54) < 0.000001)
  assert.ok(Math.abs(geometry.y - 286.08) < 0.000001)
  assert.ok(Math.abs(geometry.width - 10.103718) < 0.000001)
})

test('direction offset rotates around the unchanged midpoint', () => {
  assert.deepEqual(intervalGeometry({ x: 10, y: 20 }, { x: 110, y: 20 }, 25), {
    x: 60,
    y: 20,
    width: 98,
    angle: 25
  })

  assert.deepEqual(intervalGeometry({ x: 30, y: 10 }, { x: 30, y: 110 }, -30), {
    x: 30,
    y: 60,
    width: 98,
    angle: 60
  })
})

test('selected interval previews the form direction before saving', () => {
  const interval = { id: 'interval-1', directionOffset: 15 }

  assert.equal(intervalPreviewDirection(interval, 'interval-1', -40), -40)
  assert.equal(intervalPreviewDirection(interval, 'another-interval', -40), 15)
})
