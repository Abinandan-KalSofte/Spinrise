import axios, {
  type AxiosInstance,
  type AxiosRequestConfig,
  type InternalAxiosRequestConfig,
  type AxiosError,
} from 'axios'
import { handleApiError } from '@/shared/lib/errorHandler'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import type { AuthResponse } from '@/features/auth/types'

export interface ApiResponse<T> {
  success: boolean
  message: string
  data?: T
  errors?: Record<string, string[]> | object
}

interface RetryableRequest extends InternalAxiosRequestConfig {
  _retry?: boolean
}

export const api: AxiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api/v1',
  headers: {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  },
  timeout: 60000,
})

// ── request interceptor: attach token + processing date ─────────────────────
api.interceptors.request.use((config) => {
  const state = useAuthStore.getState()
  if (state.tokens?.accessToken && config.headers)
    config.headers.Authorization = `Bearer ${state.tokens.accessToken}`
  if (state.processingDate && config.headers)
    config.headers['X-Processing-Date'] = state.processingDate
  return config
})

// ── refresh queue: holds requests that arrived while a refresh is in flight ──
let isRefreshing = false
let failedQueue: Array<{ resolve: (token: string) => void; reject: (err: unknown) => void }> = []

function processQueue(error: unknown, token: string | null = null) {
  failedQueue.forEach(({ resolve, reject }) => {
    if (error) reject(error)
    else resolve(token!)
  })
  failedQueue = []
}

function triggerSessionExpired() {
  const store = useAuthStore.getState()
  store.clearAuthSession()
  store.setSessionExpired(true)
}

// ── response interceptor: auto-refresh on 401, show modal on total failure ───
api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError<ApiResponse<unknown>>) => {
    const originalRequest = error.config as RetryableRequest | undefined

    if (error.response?.status === 401 && originalRequest && !originalRequest._retry) {
      const store = useAuthStore.getState()
      const refreshToken = store.tokens?.refreshToken

      // Auth endpoints themselves returned 401 — do not loop
      const url = originalRequest.url ?? ''
      if (url.includes('auth/')) {
        triggerSessionExpired()
        return Promise.reject(handleApiError(error))
      }

      // No refresh token stored — session is gone
      if (!refreshToken) {
        triggerSessionExpired()
        return Promise.reject(handleApiError(error))
      }

      // Another refresh is already in flight — queue this request
      if (isRefreshing) {
        return new Promise<string>((resolve, reject) => {
          failedQueue.push({ resolve, reject })
        }).then((newToken) => {
          if (originalRequest.headers)
            originalRequest.headers.Authorization = `Bearer ${newToken}`
          return api(originalRequest as AxiosRequestConfig)
        })
      }

      originalRequest._retry = true
      isRefreshing = true

      try {
        const response = await api.post<ApiResponse<AuthResponse>>('auth/refresh', { refreshToken })
        const payload = response.data.data
        if (!payload?.tokens) throw new Error('Empty refresh response')

        const newTokens = payload.tokens
        const user = payload.user ?? store.user!
        store.setAuthSession({ user, tokens: newTokens })

        processQueue(null, newTokens.accessToken)

        if (originalRequest.headers)
          originalRequest.headers.Authorization = `Bearer ${newTokens.accessToken}`

        return api(originalRequest as AxiosRequestConfig)
      } catch {
        processQueue(error, null)
        triggerSessionExpired()
        return Promise.reject(handleApiError(error))
      } finally {
        isRefreshing = false
      }
    }

    return Promise.reject(handleApiError(error))
  },
)

export const apiHelpers = {
  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const res = await api.get<ApiResponse<T>>(url, config)
    return res.data.data as T
  },
  async post<T>(url: string, payload: unknown, config?: AxiosRequestConfig): Promise<T> {
    const res = await api.post<ApiResponse<T>>(url, payload, config)
    return res.data.data as T
  },
  async put<T>(url: string, payload: unknown, config?: AxiosRequestConfig): Promise<T> {
    const res = await api.put<ApiResponse<T>>(url, payload, config)
    return res.data.data as T
  },
  async del<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const res = await api.delete<ApiResponse<T>>(url, config)
    return res.data.data as T
  },
}

export default api
