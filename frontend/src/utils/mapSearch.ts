type SearchMarker = {
  id: string
  x: number
  y: number
  station: {
    id: string
    name: string
    autoName?: string
    mileage?: string
    workshopId?: number | string | null
  }
}

type ViewportSize = {
  width: number
  height: number
}

export function markerSuggestions(markers: SearchMarker[], query: string, workshopName: (id: number | string | null | undefined) => string) {
  const text = query.trim().toLowerCase()
  if (!text) return []
  const seen = new Set<string>()
  return markers
    .filter((marker) => {
      const station = marker.station
      const haystack = `${station.name} ${station.autoName || ''} ${station.mileage || ''} ${workshopName(station.workshopId)}`.toLowerCase()
      return haystack.includes(text)
    })
    .filter((marker) => {
      if (seen.has(marker.station.id)) return false
      seen.add(marker.station.id)
      return true
    })
    .slice(0, 20)
    .map((marker) => ({
      value: marker.station.name,
      markerId: marker.id,
      stationId: marker.station.id,
      detail: [marker.station.mileage, workshopName(marker.station.workshopId)].filter(Boolean).join(' · ')
    }))
}

export function focusMarkerTransform(marker: SearchMarker, markers: SearchMarker[], viewport: ViewportSize) {
  const gap = medianGap(markers.map((item) => item.y))
  const scale = clamp(round(viewport.height / (gap * 6)), 0.1, 8)
  return {
    scale,
    panX: round(viewport.width / 2 - marker.x * scale),
    panY: round(viewport.height / 2 - marker.y * scale)
  }
}

function medianGap(values: number[]) {
  const sorted = [...new Set(values)].sort((a, b) => a - b)
  const gaps = sorted.slice(1).map((value, index) => value - sorted[index]).filter((gap) => gap > 0)
  if (!gaps.length) return 80
  return gaps[Math.floor(gaps.length / 2)]
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value))
}

function round(value: number) {
  return Math.round(value * 100) / 100
}
