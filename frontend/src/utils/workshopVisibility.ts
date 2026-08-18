type WorkshopVisibilityStorage = Pick<Storage, 'getItem' | 'setItem'>

export const WORKSHOP_STRIP_STORAGE_KEY = 'datong-map:workshop-strip-collapsed'

export function readWorkshopStripCollapsed(storage: WorkshopVisibilityStorage | null = browserStorage()) {
  try {
    return storage?.getItem(WORKSHOP_STRIP_STORAGE_KEY) === 'true'
  } catch {
    return false
  }
}

export function writeWorkshopStripCollapsed(collapsed: boolean, storage: WorkshopVisibilityStorage | null = browserStorage()) {
  try {
    storage?.setItem(WORKSHOP_STRIP_STORAGE_KEY, String(collapsed))
  } catch {
    // The layout toggle still works when browser storage is unavailable.
  }
}

function browserStorage(): Storage | null {
  try {
    return typeof window === 'undefined' ? null : window.localStorage
  } catch {
    return null
  }
}
