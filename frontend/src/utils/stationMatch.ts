import type { Station } from '../types'

export function findStationByName<T extends Pick<Station, 'name'>>(stations: T[], name: string): T | null {
  const normalized = name.trim()
  if (!normalized) return null
  return stations.find((station) => station.name.trim() === normalized) || null
}
