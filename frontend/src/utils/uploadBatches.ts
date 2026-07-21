const MAX_BATCH_SIZE = 20
const MAX_FILE_SIZE = 50 * 1024 * 1024
const MAX_BATCH_BYTES = 90 * 1024 * 1024

export function splitUploadBatches<T extends { size?: number }>(files: Iterable<T>) {
  const list = Array.from(files)
  if (list.some((file) => (file.size || 0) > MAX_FILE_SIZE)) throw new Error('单张图片不能超过50MB')
  const batches: T[][] = []
  let batch: T[] = []
  let batchBytes = 0
  for (const file of list) {
    const fileBytes = file.size || 0
    if (batch.length && (batch.length >= MAX_BATCH_SIZE || batchBytes + fileBytes > MAX_BATCH_BYTES)) {
      batches.push(batch)
      batch = []
      batchBytes = 0
    }
    batch.push(file)
    batchBytes += fileBytes
  }
  if (batch.length) batches.push(batch)
  return batches
}
