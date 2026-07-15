type IntervalGeometryTarget = {
  x: number
  y: number
  length: number
  angle: number
}

export function intervalGeometry(interval: IntervalGeometryTarget) {
  return {
    x: interval.x,
    y: interval.y,
    width: interval.length,
    angle: interval.angle
  }
}

export function intervalPreviewGeometry(interval: IntervalGeometryTarget & { id: string }, selectedIntervalId: string, form: IntervalGeometryTarget) {
  return intervalGeometry(interval.id === selectedIntervalId ? form : interval)
}
