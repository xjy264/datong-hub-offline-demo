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
  workshopId: number | null
  notes: string
  folders: StationFolder[]
}

export interface Workshop {
  id: number
  code: string
  name: string
  color: string
  sortOrder: number
}

export interface MapSummary {
  id: string
  name: string
  backgroundUrl: string
  width: number
  height: number
  createdAt: string
}

export interface MapMarker {
  id: string
  mapId: string
  x: number
  y: number
  size: number
  station: Station
}

export interface MapInterval {
  id: string
  mapId: string
  markerAId: string
  markerBId: string
  baseStations: string[]
}

export interface MapDetail extends MapSummary {
  markers: MapMarker[]
  intervals: MapInterval[]
  stations: Station[]
  workshops: Workshop[]
}
