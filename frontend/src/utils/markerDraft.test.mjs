import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createMarkerDraft } from './markerDraft.ts'

test('new marker draft starts without a bound station', () => {
  assert.deepEqual(createMarkerDraft({ x: 12, y: 34 }), {
    marker: { x: 12, y: 34, size: 4.4 },
    stationId: '',
    size: 4.4
  })
})
