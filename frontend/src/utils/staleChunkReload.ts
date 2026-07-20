const dynamicImportFailure = /failed to fetch dynamically imported module|error loading dynamically imported module|importing a module script failed/i

export function staleChunkReloadTarget(error: unknown, target: string, previousTarget: string | null) {
  const message = error instanceof Error ? error.message : String(error)
  return dynamicImportFailure.test(message) && previousTarget !== target ? target : null
}
