type Position = { x: number; y: number }

const handledApiErrors = new WeakSet<object>()

export function normalizeRequiredName(value: string) {
  return value.trim() || null
}

export function normalizeFolderName(value: string) {
  return value.trim() || '新建目录'
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

export function replaceById<T extends { id: string }>(items: T[], updated: T) {
  return items.map((item) => item.id === updated.id ? updated : item)
}

export function createActionLock() {
  const active = new Set<string>()
  return {
    isActive(key: string) {
      return active.has(key)
    },
    tryStart(key: string) {
      if (active.has(key)) return false
      active.add(key)
      return true
    },
    finish(key: string) {
      active.delete(key)
    }
  }
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
