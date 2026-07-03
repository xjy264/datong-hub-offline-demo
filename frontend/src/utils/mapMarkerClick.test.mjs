import { test } from 'node:test'
import assert from 'node:assert/strict'
import { nextSidebarStationId } from './mapMarkerClick.ts'

test('view mode marker click selects station for sidebar', () => {
  assert.equal(nextSidebarStationId(false, 'old-station', 'new-station'), 'new-station')
})

test('edit mode marker click keeps current sidebar selection', () => {
  assert.equal(nextSidebarStationId(true, 'old-station', 'new-station'), 'old-station')
})
