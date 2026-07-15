export function nextSidebarStationId(editMode: boolean, currentStationId: string, markerStationId: string) {
  return editMode ? currentStationId : markerStationId
}

export function sidebarSelectionOnEditToggle(editMode: boolean, currentSelectionId: string) {
  return editMode ? '' : currentSelectionId
}
