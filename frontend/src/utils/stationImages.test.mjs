import { test } from 'node:test'
import assert from 'node:assert/strict'
import { countFolderImages, countStationImages } from './stationImages.ts'

const image = (id) => ({ id })

test('counts overview and nested folder images in the station total', () => {
  const station = {
    overviewImages: [image('overview-1'), image('overview-2')],
    folders: [{ images: [image('folder-1')], children: [{ images: [image('child-1')], children: [] }] }]
  }

  assert.equal(countStationImages(station), 4)
  assert.equal(countFolderImages(station.folders), 2)
})

test('treats a missing overview collection as empty for cached responses', () => {
  assert.equal(countStationImages({ folders: [{ images: [image('folder-1')], children: [] }] }), 1)
})
