import { test } from 'node:test'
import assert from 'node:assert/strict'
import { focusMarkerTransform, markerSuggestions } from './mapSearch.ts'

const markers = [
  { id: 'm1', x: 100, y: 100, station: { id: 's1', name: '五寨', autoName: '五寨', mileage: '057.950', workshopId: 1 } },
  { id: 'm2', x: 120, y: 140, station: { id: 's2', name: '五台山', autoName: '五台山', mileage: '311.006', workshopId: 2 } },
  { id: 'm3', x: 160, y: 180, station: { id: 's3', name: '忻州', autoName: '忻州', mileage: '001', workshopId: 1 } },
  { id: 'm4', x: 170, y: 220, station: { id: 's2', name: '五台山', autoName: '五台山', mileage: '311.006', workshopId: 2 } }
]

test('marker suggestions search current map markers and dedupe stations', () => {
  assert.deepEqual(markerSuggestions(markers, '五', (id) => (id === 1 ? '北部车间' : '中部车间')), [
    { value: '五寨', markerId: 'm1', stationId: 's1', detail: '057.950 · 北部车间' },
    { value: '五台山', markerId: 'm2', stationId: 's2', detail: '311.006 · 中部车间' }
  ])
})

test('focus transform centers marker with about six station gaps visible', () => {
  assert.deepEqual(focusMarkerTransform(markers[1], markers, { width: 600, height: 480 }), {
    scale: 2,
    panX: 60,
    panY: -40
  })
})
