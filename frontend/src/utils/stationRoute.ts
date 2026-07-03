type StationRouteTarget = {
  id: string
  name: string
}

export function stationDetailPath(station: StationRouteTarget) {
  return `/stations/${encodeURIComponent(station.name || 'station')}/${encodeURIComponent(station.id)}`
}
