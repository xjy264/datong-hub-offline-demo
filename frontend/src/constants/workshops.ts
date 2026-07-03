export const WORKSHOPS = [
  { id: 'north', name: '北部车间', color: '#0f766e' },
  { id: 'middle', name: '中部车间', color: '#1d4ed8' },
  { id: 'south', name: '南部车间', color: '#9f5f1a' },
  { id: 'east', name: '东部车间', color: '#7c3aed' }
]

export function workshopName(id: string) {
  return WORKSHOPS.find((item) => item.id === id)?.name || '未分组车间'
}
