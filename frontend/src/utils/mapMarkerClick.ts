export function nextSidebarStationId(editMode: boolean, currentStationId: string, markerStationId: string) {
  return editMode ? currentStationId : markerStationId
}
