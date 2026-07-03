import { test } from 'node:test'
import assert from 'node:assert/strict'
import { stationDetailPath } from './stationRoute.ts'

test('builds readable station detail route with stable station id', () => {
  assert.equal(
    stationDetailPath({ name: '大同南', id: 'red-72439-43376' }),
    '/stations/%E5%A4%A7%E5%90%8C%E5%8D%97/red-72439-43376'
  )
})

test('encodes station names that would break path segments', () => {
  assert.equal(
    stationDetailPath({ name: 'A/B 站', id: 'red-1' }),
    '/stations/A%2FB%20%E7%AB%99/red-1'
  )
})
