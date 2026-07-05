import { test } from 'node:test'
import assert from 'node:assert/strict'
import { findStationByName } from './stationMatch.ts'

const stations = [
  { id: 'a', name: '红进塔' },
  { id: 'b', name: ' 偏关 ' }
]

test('finds existing station by trimmed exact display name', () => {
  assert.equal(findStationByName(stations, ' 红进塔 ')?.id, 'a')
  assert.equal(findStationByName(stations, '偏关')?.id, 'b')
})

test('does not fuzzy match new station names', () => {
  assert.equal(findStationByName(stations, '红进'), null)
  assert.equal(findStationByName(stations, '  '), null)
})
