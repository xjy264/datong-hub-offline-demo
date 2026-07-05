export type ImageDimensions = { width: number; height: number } | null | undefined
export type ViewportDimensions = { width: number; height: number }

const DEFAULT_PADDING_X = 144
const DEFAULT_PADDING_Y = 120
const DEFAULT_MAX_SCALE = 4

function validDimension(value: number) {
  return Number.isFinite(value) && value > 0
}

export function imageViewerScale(image: ImageDimensions, viewport: ViewportDimensions, maxScale = DEFAULT_MAX_SCALE) {
  if (!image || !validDimension(image.width) || !validDimension(image.height) || !validDimension(viewport.width) || !validDimension(viewport.height)) {
    return 1
  }

  const availableWidth = Math.max(1, viewport.width - DEFAULT_PADDING_X)
  const availableHeight = Math.max(1, viewport.height - DEFAULT_PADDING_Y)
  const fitScale = Math.min(availableWidth / image.width, availableHeight / image.height)

  if (!Number.isFinite(fitScale) || fitScale <= 1) return 1
  return Math.min(maxScale, Math.round(fitScale * 100) / 100)
}
