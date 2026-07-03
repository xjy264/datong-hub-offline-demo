import { defineStore } from 'pinia'
import { apiDelete, apiGet, apiPost, apiPut } from '../api/http'
import type { Station, StationImage } from '../types'

export const useMapStore = defineStore('map', {
  state: () => ({
    stations: [] as Station[],
    loading: false
  }),
  getters: {
    stationById: (state) => (id: string) => state.stations.find((item) => item.id === id)
  },
  actions: {
    async load(force = false) {
      if (this.stations.length && !force) return
      this.loading = true
      try {
        this.stations = await apiGet<Station[]>('/map')
      } finally {
        this.loading = false
      }
    },
    async updateProfile(stationId: string, body: { name: string; notes: string; workshopId: string }) {
      await apiPut(`/stations/${stationId}/profile`, body)
      await this.load(true)
    },
    async addFolder(stationId: string, parentId: string | null) {
      await apiPost(`/stations/${stationId}/folders`, { parentId, name: '新建目录' })
      await this.load(true)
    },
    async renameFolder(folderId: string, name: string) {
      await apiPut(`/folders/${folderId}`, { name })
      await this.load(true)
    },
    async deleteFolder(folderId: string) {
      await apiDelete(`/folders/${folderId}`)
      await this.load(true)
    },
    async uploadImages(stationId: string, folderId: string, files: FileList | File[]) {
      const form = new FormData()
      Array.from(files).forEach((file) => form.append('files', file))
      await apiPost<StationImage[]>(`/stations/${stationId}/folders/${folderId}/images`, form, { headers: { 'Content-Type': 'multipart/form-data' } })
      await this.load(true)
    },
    async deleteImage(imageId: string) {
      await apiDelete(`/images/${imageId}`)
      await this.load(true)
    },
    async importJson(file: File) {
      const form = new FormData()
      form.append('file', file)
      await apiPost('/import', form, { headers: { 'Content-Type': 'multipart/form-data' } })
      await this.load(true)
    }
  }
})
