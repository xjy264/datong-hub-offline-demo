import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createIntervalDraft } from './intervalDraft.ts'

test('new interval draft starts at the drop point with default geometry', () => {
  assert.deepEqual(createIntervalDraft({ x: 120.5, y: 80.25 }), {
    x: 120.5,
    y: 80.25,
    length: 12,
    angle: 0
  })
})
