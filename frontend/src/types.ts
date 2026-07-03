export interface Position {
  x: number
  y: number
}

export interface StationImage {
  id: string
  name: string
  type: string
  size: number
  addedAt: string
  url: string
}

export interface StationFolder {
  id: string
  name: string
  order: number
  children: StationFolder[]
  images: StationImage[]
}

export interface Station {
  id: string
  name: string
  autoName: string
  type: string
  color: 'red' | 'blue' | string
  line: string
  mileage: string
  position: Position
  size: number
  workshopId: string
  notes: string
  folders: StationFolder[]
}
