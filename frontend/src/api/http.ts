import axios from 'axios'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '../stores/auth'
import { unauthorizedSessionAction } from '../utils/unauthorizedAction'

export interface ApiResult<T> {
  code: number
  message: string
  data: T
}

export const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || '/api',
  timeout: 60000,
  withCredentials: true
})

function readCookie(name: string) {
  return document.cookie
    .split(';')
    .map((item) => item.trim())
    .find((item) => item.startsWith(`${name}=`))
    ?.slice(name.length + 1) || ''
}

http.interceptors.request.use((config) => {
  const method = (config.method || 'get').toUpperCase()
  if (!['GET', 'HEAD', 'OPTIONS'].includes(method)) {
    const csrfToken = readCookie('XSRF-TOKEN')
    if (csrfToken) {
      config.headers = config.headers || {}
      config.headers['X-XSRF-TOKEN'] = csrfToken
    }
  }
  return config
})

http.interceptors.response.use(
  (response) => {
    const result = response.data as ApiResult<unknown>
    if (result && typeof result.code === 'number' && result.code !== 200) {
      ElMessage.error(result.message || '操作未完成，请稍后重试。')
      return Promise.reject(new Error(result.message))
    }
    return response
  },
  (error) => {
    const status = error.response?.status
    const message = error.response?.data?.message || (status === 401 ? '登录状态已失效，请重新登录。' : '无法连接系统服务，请确认网络正常后重试。')
    if (status === 401) {
      const action = unauthorizedSessionAction(window.location.pathname)
      if (action.clearLocalSession) useAuthStore().logoutLocal()
      if (action.redirectToLogin) window.location.replace('/login')
    } else {
      ElMessage.error(message)
    }
    return Promise.reject(error)
  }
)

export async function apiGet<T>(url: string, params?: Record<string, unknown>) {
  const { data } = await http.get<ApiResult<T>>(url, { params })
  return data.data
}

export async function apiPost<T>(url: string, body?: unknown, config?: Record<string, unknown>) {
  const { data } = await http.post<ApiResult<T>>(url, body, config)
  return data.data
}

export async function apiPut<T>(url: string, body?: unknown) {
  const { data } = await http.put<ApiResult<T>>(url, body)
  return data.data
}

export async function apiDelete<T>(url: string) {
  const { data } = await http.delete<ApiResult<T>>(url)
  return data.data
}

export async function apiGetSilent<T>(url: string) {
  const { data } = await http.get<ApiResult<T>>(url, { headers: { 'X-Silent-Error': '1' } })
  return data.data
}
