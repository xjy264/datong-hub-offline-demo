import type { StationFolder } from '../types'

export type NumberedFolderNode = {
  id: string
  folder: StationFolder
  number: string
  pathText: string
  children: NumberedFolderNode[]
}

export function numberedFolderTree(folders: StationFolder[], prefix: number[] = [], path: StationFolder[] = []): NumberedFolderNode[] {
  return folders.map((folder, index) => {
    const nextPrefix = [...prefix, index + 1]
    const nextPath = [...path, folder]
    return {
      id: folder.id,
      folder,
      number: nextPrefix.join('.'),
      pathText: nextPath.map((item) => item.name).join(' / '),
      children: numberedFolderTree(folder.children, nextPrefix, nextPath)
    }
  })
}

export function findNumberedFolderNode(nodes: NumberedFolderNode[], id: string): NumberedFolderNode | null {
  for (const node of nodes) {
    if (node.id === id) return node
    const child = findNumberedFolderNode(node.children, id)
    if (child) return child
  }
  return null
}
