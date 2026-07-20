import { test } from 'node:test'
import assert from 'node:assert/strict'
import { staleChunkReloadTarget } from './staleChunkReload.ts'

test('reloads the target route when a deployed dynamic import is missing', () => {
  const error = new TypeError('Failed to fetch dynamically imported module: http://127.0.0.1:8012/assets/StationView-old.js')
  assert.equal(staleChunkReloadTarget(error, '/stations/name/id', null), '/stations/name/id')
})

test('does not reload ordinary application errors', () => {
  assert.equal(staleChunkReloadTarget(new Error('render failed'), '/map', null), null)
})

test('does not loop when the same route already reloaded once', () => {
  assert.equal(
    staleChunkReloadTarget(new TypeError('Failed to fetch dynamically imported module: /assets/MapView-old.js'), '/map', '/map'),
    null
  )
})
