import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

test('keeps interval rail thickness and sleepers screen-sized while map length scales', async () => {
  const view = await readFile(new URL('../views/MapView.vue', import.meta.url), 'utf8')
  const css = await readFile(new URL('../styles/main.css', import.meta.url), 'utf8')

  assert.match(view, /'--map-inverse-scale': 1 \/ scale\.value/)
  assert.match(css, /width: var\(--interval-width\); height: calc\(8px \* var\(--map-inverse-scale\)\)/)
  assert.match(css, /#dce4ea 0 25%, #111827 25% 75%, #dce4ea 75%/)
  assert.match(css, /calc\(40px \* var\(--map-inverse-scale\)\)/)
  assert.match(css, /background-size: 100% 100%, calc\(40px \* var\(--map-inverse-scale\)\) 100%/)
  assert.match(css, /background-position: center; background-repeat: no-repeat, repeat/)
})
