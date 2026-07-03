import { test } from 'node:test'
import assert from 'node:assert/strict'
import { resolveWorkshopRoute, workshopName, workshopPath } from './workshopRoute.ts'

const workshops = [
  { id: 1, code: 'north', name: '北部车间', color: '#0f766e' },
  { id: 2, code: 'middle', name: '中部车间', color: '#1d4ed8' }
]

test('builds workshop route with numeric database id', () => {
  assert.equal(workshopPath(workshops[0]), '/workshops/1')
})

test('resolves legacy workshop code to numeric route', () => {
  assert.deepEqual(resolveWorkshopRoute(workshops, 'north'), { workshop: workshops[0], replacePath: '/workshops/1' })
})

test('keeps numeric route without redirect', () => {
  assert.deepEqual(resolveWorkshopRoute(workshops, '2'), { workshop: workshops[1], replacePath: '' })
})

test('returns fallback name for missing workshop', () => {
  assert.equal(workshopName(workshops, 99), '未分组车间')
})
