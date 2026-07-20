import { test } from 'node:test'
import assert from 'node:assert/strict'

const feedback = await import('./actionFeedback.ts').catch(() => ({}))

test('normalizes confirmed prompt names and rejects blank values', () => {
  assert.equal(feedback.normalizeRequiredName?.('  北区地图  '), '北区地图')
  assert.equal(feedback.normalizeRequiredName?.('   '), null)
})

test('maps the expired login reason to one user-facing notice', () => {
  assert.equal(feedback.loginNotice?.('expired'), '登录状态已过期，请重新登录。')
  assert.equal(feedback.loginNotice?.('other'), '')
  assert.equal(feedback.loginNotice?.(['expired']), '')
})

test('captures and restores an optimistic position', () => {
  const item = { x: 12, y: 34 }
  const original = feedback.positionSnapshot?.(item)
  item.x = 88
  item.y = 99
  feedback.restorePosition?.(item, original)
  assert.deepEqual(item, { x: 12, y: 34 })
})

test('marks only handled API errors for console suppression', () => {
  const handled = new Error('request failed')
  const programError = new Error('render failed')
  assert.equal(feedback.isHandledApiError?.(handled), false)
  assert.equal(feedback.markHandledApiError?.(handled), handled)
  assert.equal(feedback.isHandledApiError?.(handled), true)
  assert.equal(feedback.isHandledApiError?.(programError), false)
})

test('replaces one saved entity without requiring a follow-up refresh', () => {
  const original = [{ id: 'a', x: 1 }, { id: 'b', x: 2 }]
  const updated = { id: 'b', x: 9 }
  assert.deepEqual(feedback.replaceById?.(original, updated), [{ id: 'a', x: 1 }, updated])
})

test('locks one auto-save target until its pending request finishes', () => {
  const lock = feedback.createActionLock?.()
  assert.equal(lock?.tryStart('marker:a'), true)
  assert.equal(lock?.tryStart('marker:a'), false)
  lock?.finish('marker:a')
  assert.equal(lock?.tryStart('marker:a'), true)
})
