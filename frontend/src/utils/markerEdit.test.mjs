import { test } from 'node:test'
import assert from 'node:assert/strict'
import { markerEditStationOptions, markerTypeForStation } from './markerEdit.ts'

const stations = [
  { id: 'wutai', name: '五台山', color: 'red' },
  { id: 'old', name: '旧站', color: 'blue' }
]

test('selected marker options keep all stations when type changes', () => {
  assert.deepEqual(markerEditStationOptions(stations).map((station) => station.id), ['wutai', 'old'])
})

test('selecting another station syncs marker type to that station', () => {
  assert.equal(markerTypeForStation(stations, 'old', 'red'), 'blue')
  assert.equal(markerTypeForStation(stations, 'missing', 'red'), 'red')
})
