import { test } from 'node:test'
import assert from 'node:assert/strict'
import { unauthorizedSessionAction } from './unauthorizedAction.ts'

test('unauthorized handling clears local session and redirects from protected pages', () => {
  assert.deepEqual(unauthorizedSessionAction('/map', true), {
    clearLocalSession: true,
    redirectToLogin: true,
    loginUrl: '/login?reason=expired',
    showMessage: false
  })
})

test('silent session probe does not redirect or warn on login page', () => {
  assert.deepEqual(unauthorizedSessionAction('/login', true), {
    clearLocalSession: true,
    redirectToLogin: false,
    loginUrl: null,
    showMessage: false
  })
})

test('unauthorized session probe stays silent on the registration page', () => {
  assert.deepEqual(unauthorizedSessionAction('/register', true), {
    clearLocalSession: true,
    redirectToLogin: false,
    loginUrl: null,
    showMessage: false
  })
})

test('non-silent unauthorized request on a public page shows its message', () => {
  assert.deepEqual(unauthorizedSessionAction('/login', false), {
    clearLocalSession: true,
    redirectToLogin: false,
    loginUrl: null,
    showMessage: true
  })
})
