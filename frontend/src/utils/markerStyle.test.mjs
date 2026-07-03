import { test } from 'node:test'
import assert from 'node:assert/strict'
import { DEFAULT_MARKER_SIZE, markerCssVars } from './markerStyle.ts'

test('new station marker uses the original small button size', () => {
  assert.equal(DEFAULT_MARKER_SIZE, 4.4)
})

test('marker css vars keep coordinates and small default size', () => {
  assert.deepEqual(markerCssVars({ x: 10, y: 20 }), {
    '--x': '10px',
    '--y': '20px',
    '--size': '4.4px'
  })
})
