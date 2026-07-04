import { test } from 'node:test'
import assert from 'node:assert/strict'
import { findNumberedFolderNode, numberedFolderTree } from './folderTree.ts'

const folders = [
  {
    id: 'root-a',
    name: '资料',
    order: 0,
    images: [],
    children: [
      { id: 'child-a', name: '照片', order: 0, images: [], children: [] },
      { id: 'child-b', name: '台账', order: 1, images: [], children: [] }
    ]
  },
  { id: 'root-b', name: '验收', order: 1, images: [], children: [] }
]

test('numbers nested folders like an ordered tree', () => {
  const tree = numberedFolderTree(folders)

  assert.equal(tree[0].number, '1')
  assert.equal(tree[0].children[0].number, '1.1')
  assert.equal(tree[0].children[1].number, '1.2')
  assert.equal(tree[1].number, '2')
})

test('finds selected folder node with its display path', () => {
  const node = findNumberedFolderNode(numberedFolderTree(folders), 'child-b')

  assert.equal(node?.pathText, '资料 / 台账')
  assert.equal(node?.number, '1.2')
})
