import { defineStore } from 'pinia'
import { apiGetSilent, apiPost } from '../api/http'

export interface LoginUser {
  id: number
  username: string
  phone: string
  realName: string
  isSuperAdmin: boolean
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null as LoginUser | null,
    permissions: [] as string[],
    initialized: false
  }),
  getters: {
    isAuthenticated: (state) => Boolean(state.user),
    canManageUsers: (state) => state.permissions.includes('USER_ADMIN')
  },
  actions: {
    setSession(user: LoginUser, permissions: string[]) {
      this.user = user
      this.permissions = permissions
      this.initialized = true
    },
    markInitialized() {
      this.initialized = true
    },
    logoutLocal() {
      this.user = null
      this.permissions = []
      this.initialized = true
    },
    async restoreSession() {
      if (this.initialized) return
      try {
        const session = await apiGetSilent<{ user: LoginUser; permissions: string[] }>('/auth/me')
        this.setSession(session.user, session.permissions)
      } catch {
        this.logoutLocal()
      } finally {
        this.markInitialized()
      }
    },
    async logout() {
      try {
        await apiPost('/auth/logout')
      } finally {
        this.logoutLocal()
      }
    }
  }
})
