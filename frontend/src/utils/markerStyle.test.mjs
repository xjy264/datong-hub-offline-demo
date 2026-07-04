import { test } from 'node:test'
import assert from 'node:assert/strict'
import { DEFAULT_MARKER_SIZE, markerCssVars } from './markerStyle.ts'

test('new station marker uses the slightly smaller round button size', () => {
  assert.equal(DEFAULT_MARKER_SIZE, 4)
})

test('marker css vars keep coordinates, small default size, and default red color', () => {
  assert.deepEqual(markerCssVars({ x: 10, y: 20 }), {
    '--x': '10px',
    '--y': '20px',
    '--size': '4px',
    '--marker-color': '#ff0000'
  })
})

test('marker css vars renders legacy 4.4px stations at the smaller 4px size', () => {
  assert.equal(markerCssVars({ x: 10, y: 20, size: 4.4 })['--size'], '4px')
})

test('marker css vars preserves explicitly custom sizes', () => {
  assert.equal(markerCssVars({ x: 10, y: 20, size: 6 })['--size'], '6px')
})

test('marker css vars maps withdrawn stations to blue', () => {
  assert.equal(markerCssVars({ x: 10, y: 20, color: 'blue' })['--marker-color'], '#0000ff')
})
