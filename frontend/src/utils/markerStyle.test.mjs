import { test } from 'node:test'
import assert from 'node:assert/strict'
import { DEFAULT_MARKER_SIZE, markerCssVars } from './markerStyle.ts'

test('new station marker uses the original small button size', () => {
  assert.equal(DEFAULT_MARKER_SIZE, 4.4)
})

test('marker css vars keep coordinates, small default size, and default red color', () => {
  assert.deepEqual(markerCssVars({ x: 10, y: 20 }), {
    '--x': '10px',
    '--y': '20px',
    '--size': '4.4px',
    '--marker-color': '#ff0000'
  })
})

test('marker css vars maps withdrawn stations to blue', () => {
  assert.equal(markerCssVars({ x: 10, y: 20, color: 'blue' })['--marker-color'], '#0000ff')
})
