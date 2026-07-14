import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const source = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

test('removes user administration and approval copy', () => {
  const router = source('../router/index.ts')
  const layout = source('../views/LayoutView.vue')
  const auth = source('../stores/auth.ts')
  const register = source('../views/RegisterView.vue')

  assert.doesNotMatch(`${router}\n${layout}\n${auth}`, /admin\/users|canManageUsers|USER_ADMIN/)
  assert.doesNotMatch(register, /管理员审核|等待管理员审核/)
  assert.match(register, /注册成功，请登录/)
})
