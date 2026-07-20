import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

test('keeps interval rail thickness and sleepers screen-sized while map length scales', async () => {
  const view = await readFile(new URL('../views/MapView.vue', import.meta.url), 'utf8')
  const css = await readFile(new URL('../styles/main.css', import.meta.url), 'utf8')

  assert.match(view, /'--map-inverse-scale': 1 \/ scale\.value/)
  assert.match(css, /width: var\(--interval-width\); height: calc\(8px \* var\(--map-inverse-scale\)\)/)
  assert.match(css, /calc\(5px \* var\(--map-inverse-scale\)\)/)
})
