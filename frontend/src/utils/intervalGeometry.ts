type Point = { x: number; y: number }

const ENDPOINT_GAP = 1

export function intervalPreviewDirection(interval: { id: string; directionOffset: number }, selectedIntervalId: string, formDirectionOffset: number) {
  return interval.id === selectedIntervalId ? formDirectionOffset : interval.directionOffset
}

export function intervalGeometry(stationA: Point, stationB: Point, directionOffset = 0) {
  const dx = stationB.x - stationA.x
  const dy = stationB.y - stationA.y
  const distance = Math.hypot(dx, dy)
  return {
    x: (stationA.x + stationB.x) / 2,
    y: (stationA.y + stationB.y) / 2,
    width: Math.max(2, distance - ENDPOINT_GAP * 2),
    angle: Math.atan2(dy, dx) * 180 / Math.PI + directionOffset
  }
}
