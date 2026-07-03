import { defineStore } from 'pinia'
import { apiDelete, apiGet, apiPost, apiPut } from '../api/http'
import type { MapDetail, MapMarker, MapSummary, Station, StationImage, Workshop } from '../types'

export const useMapStore = defineStore('map', {
  state: () => ({
    maps: [] as MapSummary[],
    currentMap: null as MapDetail | null,
    stations: [] as Station[],
    workshops: [] as Workshop[],
    loading: false
  }),
  getters: {
    stationById: (state) => (id: string) => state.stations.find((item) => item.id === id),
    workshopById: (state) => (id: number | string | null | undefined) => state.workshops.find((item) => String(item.id) === String(id))
  },
  actions: {
    async load(force = false) {
      if (this.currentMap && this.stations.length && this.workshops.length && !force) return
      this.loading = true
      try {
        this.maps = await apiGet<MapSummary[]>('/maps')
        if (this.maps.length) await this.loadMap(this.currentMap?.id || this.maps[0].id)
        else {
          this.workshops = await apiGet<Workshop[]>('/workshops')
          this.stations = await apiGet<Station[]>('/map')
        }
      } finally {
        this.loading = false
      }
    },
    async loadMap(mapId: string) {
      this.loading = true
      try {
        this.currentMap = await apiGet<MapDetail>(`/maps/${mapId}`)
        this.stations = this.currentMap.stations
        this.workshops = this.currentMap.workshops
      } finally {
        this.loading = false
      }
    },
    async createMap(name: string, file: File) {
      const form = new FormData()
      form.append('name', name)
      form.append('file', file)
      const created = await apiPost<MapDetail>('/maps', form, { headers: { 'Content-Type': 'multipart/form-data' } })
      this.maps = await apiGet<MapSummary[]>('/maps')
      this.currentMap = created
      this.stations = created.stations
      this.workshops = created.workshops
    },
    async createMarker(mapId: string, body: { stationId: string; x: number; y: number; size: number }) {
      await apiPost<MapMarker>(`/maps/${mapId}/markers`, body)
      await this.loadMap(mapId)
    },
    async updateMarker(mapId: string, markerId: string, body: { stationId: string; x: number; y: number; size: number }) {
      await apiPut<MapMarker>(`/maps/${mapId}/markers/${markerId}`, body)
      await this.loadMap(mapId)
    },
    async deleteMarker(mapId: string, markerId: string) {
      await apiDelete(`/maps/${mapId}/markers/${markerId}`)
      await this.loadMap(mapId)
    },
    async updateProfile(stationId: string, body: { name: string; notes: string; workshopId: number | null }) {
      await apiPut(`/stations/${stationId}/profile`, body)
      if (this.currentMap) await this.loadMap(this.currentMap.id)
      else await this.load(true)
    },
    async renameWorkshop(workshopId: number, name: string) {
      await apiPut(`/workshops/${workshopId}`, { name })
      if (this.currentMap) await this.loadMap(this.currentMap.id)
      else await this.load(true)
    },
    async addFolder(stationId: string, parentId: string | null) {
      await apiPost(`/stations/${stationId}/folders`, { parentId, name: '新建目录' })
      if (this.currentMap) await this.loadMap(this.currentMap.id)
      else await this.load(true)
    },
    async renameFolder(folderId: string, name: string) {
      await apiPut(`/folders/${folderId}`, { name })
      if (this.currentMap) await this.loadMap(this.currentMap.id)
      else await this.load(true)
    },
    async deleteFolder(folderId: string) {
      await apiDelete(`/folders/${folderId}`)
      if (this.currentMap) await this.loadMap(this.currentMap.id)
      else await this.load(true)
    },
    async uploadImages(stationId: string, folderId: string, files: FileList | File[]) {
      const form = new FormData()
      Array.from(files).forEach((file) => form.append('files', file))
      await apiPost<StationImage[]>(`/stations/${stationId}/folders/${folderId}/images`, form, { headers: { 'Content-Type': 'multipart/form-data' } })
      if (this.currentMap) await this.loadMap(this.currentMap.id)
      else await this.load(true)
    },
    async deleteImage(imageId: string) {
      await apiDelete(`/images/${imageId}`)
      if (this.currentMap) await this.loadMap(this.currentMap.id)
      else await this.load(true)
    },
    async importJson(file: File) {
      const form = new FormData()
      form.append('file', file)
      await apiPost('/import', form, { headers: { 'Content-Type': 'multipart/form-data' } })
      if (this.currentMap) await this.loadMap(this.currentMap.id)
      else await this.load(true)
    }
  }
})
