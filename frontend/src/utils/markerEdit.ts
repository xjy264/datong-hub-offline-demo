import type { Station } from '../types'

type MarkerType = 'red' | 'blue'

export function markerEditStationOptions<T extends Pick<Station, 'id'>>(stations: T[]) {
  return stations
}

export function intervalMarkerLabel(marker: { station: Pick<Station, 'name'> }) {
  return marker.station.name
}

export function markerTypeForStation<T extends Pick<Station, 'id' | 'color'>>(stations: T[], stationId: string, fallback: MarkerType): MarkerType {
  const station = stations.find((item) => item.id === stationId)
  if (!station) return fallback
  return station.color === 'blue' ? 'blue' : 'red'
}
