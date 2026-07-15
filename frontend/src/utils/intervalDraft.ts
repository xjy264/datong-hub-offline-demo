export const DEFAULT_INTERVAL_LENGTH = 12

export function createIntervalDraft(point: { x: number; y: number }) {
  return {
    x: point.x,
    y: point.y,
    length: DEFAULT_INTERVAL_LENGTH,
    angle: 0
  }
}
