type ImageFolder = { images?: unknown[]; children?: ImageFolder[] }
type StationImages = { overviewImages?: unknown[]; folders?: ImageFolder[] }

export function countFolderImages(folders: ImageFolder[] = []): number {
  return folders.reduce((sum, folder) => sum + (folder.images?.length || 0) + countFolderImages(folder.children), 0)
}

export function countStationImages(station: StationImages): number {
  return (station.overviewImages?.length || 0) + countFolderImages(station.folders)
}
