export const DEFAULT_MARKER_SIZE = 4.4

type MarkerStyleTarget = {
  x: number
  y: number
  size?: number
}

export function markerCssVars(marker: MarkerStyleTarget) {
  return {
    '--x': `${marker.x}px`,
    '--y': `${marker.y}px`,
    '--size': `${marker.size || DEFAULT_MARKER_SIZE}px`
  }
}
