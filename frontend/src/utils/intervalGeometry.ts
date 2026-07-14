type Point = { x: number; y: number }

const ENDPOINT_GAP = 1

export function intervalGeometry(stationA: Point, stationB: Point) {
  const dx = stationB.x - stationA.x
  const dy = stationB.y - stationA.y
  const distance = Math.hypot(dx, dy)
  return {
    x: (stationA.x + stationB.x) / 2,
    y: (stationA.y + stationB.y) / 2,
    width: Math.max(2, distance - ENDPOINT_GAP * 2),
    angle: Math.atan2(dy, dx) * 180 / Math.PI
  }
}
