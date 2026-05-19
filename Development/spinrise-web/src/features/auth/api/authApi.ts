import { api, apiHelpers } from '@/shared/api/client'
import type { ApiResponse } from '@/shared/api/client'
import type { ActiveDivisionDto, AuthResponse, LoginDto } from '../types'

export const authApi = {
  login: (data: LoginDto) =>
    api.post<ApiResponse<AuthResponse>>('auth/login', data),

  getActiveDivisions: () =>
    apiHelpers.get<ActiveDivisionDto[]>('divisions/active'),

  refreshToken: (refreshToken: string) =>
    api.post<ApiResponse<AuthResponse>>('auth/refresh', { refreshToken }),

  logout: (refreshToken?: string) =>
    api.post('auth/logout', { refreshToken }),
}
