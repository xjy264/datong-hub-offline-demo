import { test } from 'node:test'
import assert from 'node:assert/strict'
import { splitUploadBatches } from './uploadBatches.ts'

test('splits large selections into sequential batches of twenty', () => {
  const files = Array.from({ length: 45 }, (_, index) => ({ name: `${index}.png` }))
  assert.deepEqual(splitUploadBatches(files).map((batch) => batch.length), [20, 20, 5])
})

test('rejects files larger than twenty megabytes before upload', () => {
  assert.throws(() => splitUploadBatches([{ name: 'large.png', size: 20 * 1024 * 1024 + 1 }]), /单张图片不能超过20MB/)
})
