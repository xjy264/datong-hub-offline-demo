import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
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

test('map view exposes the persisted workshop toggle and grouped toolbar', () => {
  const view = readFileSync(new URL('../views/MapView.vue', import.meta.url), 'utf8')
  const styles = readFileSync(new URL('../styles/main.css', import.meta.url), 'utf8')

  assert.match(view, /v-show="!workshopStripCollapsed" class="workshop-strip"/)
  assert.match(view, /class="workshop-strip-toggle"/)
  assert.match(view, /class="tool-row map-filter-controls"/)
  assert.match(view, /class="tool-row map-action-controls"/)
  assert.match(styles, /grid-template-columns:\s*minmax\(0, 1fr\) auto/)
  assert.match(styles, /\.map-filter-controls \.search-field\s*\{[^}]*flex:\s*0 0 260px/)
  assert.match(styles, /\.map-filter-controls \.select-field\s*\{[^}]*flex:\s*0 0 180px/)
  assert.match(styles, /\.map-filter-controls \.el-radio-group\s*\{[^}]*flex:\s*0 0 auto[^}]*flex-wrap:\s*nowrap/)
  assert.match(styles, /@media \(max-width: 1180px\)/)
})
