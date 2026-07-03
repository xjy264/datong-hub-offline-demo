import { DEFAULT_MARKER_SIZE } from './markerStyle.ts'

export function createMarkerDraft(point: { x: number; y: number }) {
  return {
    marker: { x: point.x, y: point.y, size: DEFAULT_MARKER_SIZE },
    stationId: '',
    size: DEFAULT_MARKER_SIZE
  }
}
