import { test } from 'node:test'
import assert from 'node:assert/strict'
import { unauthorizedSessionAction } from './unauthorizedAction.ts'

test('unauthorized handling clears local session and redirects from protected pages', () => {
  assert.deepEqual(unauthorizedSessionAction('/map'), {
    clearLocalSession: true,
    redirectToLogin: true
  })
})

test('unauthorized handling does not redirect again on login page', () => {
  assert.deepEqual(unauthorizedSessionAction('/login'), {
    clearLocalSession: true,
    redirectToLogin: false
  })
})
