import { test } from 'node:test'
import assert from 'node:assert/strict'
import { passwordValidationMessage } from './passwordPolicy.ts'

test('validates register password complexity', () => {
  assert.equal(passwordValidationMessage('', 'Aa1!aaaa'), '密码不能为空')
  assert.equal(passwordValidationMessage('Aa1!aaaa', ''), '确认密码不能为空')
  assert.equal(passwordValidationMessage('Aa1!aaaa', 'Aa1!aaab'), '两次输入的密码不一致')
  assert.equal(passwordValidationMessage('Aa1!', 'Aa1!'), '密码长度需为 8-20 位')
  assert.equal(passwordValidationMessage('weakpass', 'weakpass'), '密码缺少大写字母、数字、特殊符号')
  assert.equal(passwordValidationMessage('Aa1!aaaa', 'Aa1!aaaa'), '')
})
