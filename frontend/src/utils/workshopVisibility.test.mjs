import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  WORKSHOP_STRIP_STORAGE_KEY,
  readWorkshopStripCollapsed,
  writeWorkshopStripCollapsed
} from './workshopVisibility.ts'

function memoryStorage(initialValue = null) {
  const values = new Map()
  if (initialValue != null) values.set(WORKSHOP_STRIP_STORAGE_KEY, initialValue)
  return {
    getItem(key) {
      return values.get(key) ?? null
    },
    setItem(key, value) {
      values.set(key, value)
    }
  }
}

test('workshop strip is visible when no valid collapsed state was saved', () => {
  assert.equal(readWorkshopStripCollapsed(memoryStorage()), false)
  assert.equal(readWorkshopStripCollapsed(memoryStorage('invalid')), false)
  assert.equal(readWorkshopStripCollapsed(null), false)
})

test('workshop strip restores the saved collapsed state', () => {
  assert.equal(readWorkshopStripCollapsed(memoryStorage('true')), true)
  assert.equal(readWorkshopStripCollapsed(memoryStorage('false')), false)
})

test('workshop strip persists both collapsed and expanded states', () => {
  const storage = memoryStorage()
  writeWorkshopStripCollapsed(true, storage)
  assert.equal(readWorkshopStripCollapsed(storage), true)
  writeWorkshopStripCollapsed(false, storage)
  assert.equal(readWorkshopStripCollapsed(storage), false)
})

test('workshop strip ignores unavailable browser storage', () => {
  const unavailableStorage = {
    getItem() {
      throw new Error('storage unavailable')
    },
    setItem() {
      throw new Error('storage unavailable')
    }
  }
  assert.equal(readWorkshopStripCollapsed(unavailableStorage), false)
  assert.doesNotThrow(() => writeWorkshopStripCollapsed(true, unavailableStorage))
})
