import { test } from 'node:test'
import assert from 'node:assert/strict'
import { intervalGeometry } from './intervalGeometry.ts'

test('interval hit area connects stations while leaving endpoint buttons clear', () => {
  assert.deepEqual(intervalGeometry({ x: 10, y: 20 }, { x: 110, y: 20 }), {
    x: 60,
    y: 20,
    width: 84,
    angle: 0
  })
})

test('interval geometry follows vertical station movement', () => {
  assert.deepEqual(intervalGeometry({ x: 30, y: 10 }, { x: 30, y: 110 }), {
    x: 30,
    y: 60,
    width: 84,
    angle: 90
  })
})
