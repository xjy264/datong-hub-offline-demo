export const DEFAULT_MARKER_SIZE = 4.4

type MarkerStyleTarget = {
  x: number
  y: number
  size?: number
  color?: string
}

export function markerColor(color?: string) {
  return color === 'blue' ? '#0000ff' : '#ff0000'
}

export function markerCssVars(marker: MarkerStyleTarget) {
  return {
    '--x': `${marker.x}px`,
    '--y': `${marker.y}px`,
    '--size': `${marker.size || DEFAULT_MARKER_SIZE}px`,
    '--marker-color': markerColor(marker.color)
  }
}
