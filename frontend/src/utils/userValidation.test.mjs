import { test } from 'node:test'
import assert from 'node:assert/strict'
import { normalizeRegisterPhone, normalizeRegisterRealName } from './userValidation.ts'

test('normalizes valid register name and phone', () => {
  assert.equal(normalizeRegisterRealName(' 张三 '), '张三')
  assert.equal(normalizeRegisterRealName('阿·三'), '阿·三')
  assert.equal(normalizeRegisterPhone(' 13800138000 '), '13800138000')
})

test('rejects invalid register name and phone', () => {
  assert.equal(normalizeRegisterRealName('tom'), '')
  assert.equal(normalizeRegisterRealName('张'), '')
  assert.equal(normalizeRegisterPhone('123'), '')
})
