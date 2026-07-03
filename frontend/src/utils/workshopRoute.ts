import type { Workshop } from '../types'

export function workshopPath(workshop: Pick<Workshop, 'id'>) {
  return `/workshops/${workshop.id}`
}

export function workshopName(workshops: Workshop[], id: number | string | null | undefined) {
  const text = id == null ? '' : String(id)
  return workshops.find((item) => String(item.id) === text)?.name || '未分组车间'
}

export function resolveWorkshopRoute(workshops: Workshop[], param: string) {
  const byId = workshops.find((item) => String(item.id) === param)
  if (byId) return { workshop: byId, replacePath: '' }
  const byCode = workshops.find((item) => item.code === param)
  return { workshop: byCode || null, replacePath: byCode ? workshopPath(byCode) : '' }
}
