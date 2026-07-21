import { test } from 'node:test'
import assert from 'node:assert/strict'
import { splitUploadBatches } from './uploadBatches.ts'

test('splits large selections into sequential batches of twenty', () => {
  const files = Array.from({ length: 45 }, (_, index) => ({ name: `${index}.png` }))
  assert.deepEqual(splitUploadBatches(files).map((batch) => batch.length), [20, 20, 5])
})

test('accepts images up to fifty megabytes and rejects larger files', () => {
  assert.doesNotThrow(() => splitUploadBatches([{ name: 'limit.png', size: 50 * 1024 * 1024 }]))
  assert.throws(() => splitUploadBatches([{ name: 'large.png', size: 50 * 1024 * 1024 + 1 }]), /单张图片不能超过50MB/)
})

test('splits batches before their total size exceeds ninety megabytes', () => {
  const mb = 1024 * 1024
  const files = [{ size: 45 * mb }, { size: 45 * mb }, { size: 10 * mb }]
  assert.deepEqual(splitUploadBatches(files).map((batch) => batch.length), [2, 1])
})
