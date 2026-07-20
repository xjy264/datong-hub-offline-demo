import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

test('keeps the interval rail in map coordinates so it moves and scales with the background', async () => {
  const view = await readFile(new URL('../views/MapView.vue', import.meta.url), 'utf8')
  const css = await readFile(new URL('../styles/main.css', import.meta.url), 'utf8')

  assert.doesNotMatch(view, /--map-inverse-scale/)
  assert.doesNotMatch(css, /--map-inverse-scale/)
  assert.match(css, /width: var\(--interval-width\); height: 1\.25px/)
  assert.match(css, /#dce4ea 0 25%, #111827 25% 75%, #dce4ea 75%/)
  assert.match(css, /background-size: 100% 100%, 6px 100%/)
  assert.match(css, /background-position: center; background-repeat: no-repeat, repeat/)
})
