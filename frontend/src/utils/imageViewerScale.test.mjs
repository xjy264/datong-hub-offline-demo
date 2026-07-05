import { test } from 'node:test'
import assert from 'node:assert/strict'
import { imageViewerScale } from './imageViewerScale.ts'

test('enlarges tiny landscape images to be readable without overflowing', () => {
  assert.equal(imageViewerScale({ width: 193, height: 135 }, { width: 1280, height: 720 }), 4)
})

test('does not add transform scale when image is taller than the preview area', () => {
  assert.equal(imageViewerScale({ width: 474, height: 692 }, { width: 1280, height: 720 }), 1)
})

test('uses available room for medium images without exceeding the cap', () => {
  assert.equal(imageViewerScale({ width: 800, height: 400 }, { width: 1600, height: 1000 }), 1.82)
})

test('returns native scale for missing or invalid dimensions', () => {
  assert.equal(imageViewerScale(null, { width: 1280, height: 720 }), 1)
  assert.equal(imageViewerScale({ width: 0, height: 135 }, { width: 1280, height: 720 }), 1)
  assert.equal(imageViewerScale({ width: 193, height: 135 }, { width: 0, height: 720 }), 1)
})
