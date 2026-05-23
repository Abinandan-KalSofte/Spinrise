import axios, { type AxiosInstance, type AxiosRequestConfig, type AxiosError } from 'axios'
import { handleApiError } from '@/shared/lib/errorHandler'
import { useAuthStore } from '@/features/auth/store/useAuthStore'

export interface ApiResponse<T> {
  success: boolean
  message: string
  data?: T
  errors?: Record<string, string[]> | object
}

export const api: AxiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api/v1',  // proxied by Vite → localhost:5001
  headers: {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  },
  timeout: 60000,
})

api.interceptors.request.use((config) => {
  const state = useAuthStore.getState()
  if (state.tokens?.accessToken && config.headers)
    config.headers.Authorization = `Bearer ${state.tokens.accessToken}`
  if (state.processingDate && config.headers)
    config.headers['X-Processing-Date'] = state.processingDate
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error: AxiosError<ApiResponse<unknown>>) => {
    if (error.response?.status === 401) {
      const store = useAuthStore.getState()
      const refreshToken = store.tokens?.refreshToken
      if (refreshToken) void api.post('auth/logout', { refreshToken }).catch(() => {})
      store.clearAuthSession()
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
