import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createMarkerDraft } from './markerDraft.ts'

test('new marker draft starts without a bound station', () => {
  assert.deepEqual(createMarkerDraft({ x: 12, y: 34 }), {
    marker: { x: 12, y: 34, size: 2.8 },
    stationId: '',
    size: 2.8
  })
})
