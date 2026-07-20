type Position = { x: number; y: number }

const handledApiErrors = new WeakSet<object>()

export function normalizeRequiredName(value: string) {
  return value.trim() || null
}

export function loginNotice(reason: unknown) {
  return reason === 'expired' ? '登录状态已过期，请重新登录。' : ''
}

export function positionSnapshot(position: Position): Position {
  return { x: position.x, y: position.y }
}

export function restorePosition(target: Position, original: Position) {
  target.x = original.x
  target.y = original.y
}

export function markHandledApiError<T>(error: T): T {
  if ((typeof error === 'object' && error !== null) || typeof error === 'function') {
    handledApiErrors.add(error as object)
  }
  return error
}

export function isHandledApiError(error: unknown) {
  return ((typeof error === 'object' && error !== null) || typeof error === 'function')
    && handledApiErrors.has(error as object)
}
