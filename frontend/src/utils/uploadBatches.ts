const MAX_BATCH_SIZE = 20
const MAX_FILE_SIZE = 20 * 1024 * 1024

export function splitUploadBatches<T extends { size?: number }>(files: Iterable<T>) {
  const list = Array.from(files)
  if (list.some((file) => (file.size || 0) > MAX_FILE_SIZE)) throw new Error('单张图片不能超过20MB')
  const batches: T[][] = []
  for (let index = 0; index < list.length; index += MAX_BATCH_SIZE) batches.push(list.slice(index, index + MAX_BATCH_SIZE))
  return batches
}
