export const DEFAULT_MARKER_SIZE = 2.8
const LEGACY_MARKER_SIZES = [3.6, 4, 4.4]

type MarkerStyleTarget = {
  x: number
  y: number
  size?: number
  color?: string
}

export function renderMarkerSize(size?: number) {
  if (!size) return DEFAULT_MARKER_SIZE
  return LEGACY_MARKER_SIZES.some((legacySize) => Math.abs(size - legacySize) < 0.01) ? DEFAULT_MARKER_SIZE : size
}

export function markerColor(color?: string) {
  return color === 'blue' ? '#0000ff' : '#ff0000'
}

export function markerCssVars(marker: MarkerStyleTarget) {
  return {
    '--x': `${marker.x}px`,
    '--y': `${marker.y}px`,
    '--size': `${renderMarkerSize(marker.size)}px`,
    '--marker-color': markerColor(marker.color)
  }
}
