import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

test('application entry includes the Element Plus message stylesheet', async () => {
  const source = await readFile(new URL('../main.ts', import.meta.url), 'utf8')
  assert.match(source, /element-plus\/theme-chalk\/el-message\.css/)
})
