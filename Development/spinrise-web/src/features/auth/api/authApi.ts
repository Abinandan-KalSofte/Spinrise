import { api, apiHelpers } from '@/shared/api/client'
import type { ApiResponse } from '@/shared/api/client'
import type { ActiveCompanyDto, ActiveDivisionDto, AuthResponse, LoginDto } from '../types'

export const authApi = {
  login: (data: LoginDto) =>
    api.post<ApiResponse<AuthResponse>>('auth/login', data),

  getDatabases: () =>
    apiHelpers.get<string[]>('databases'),

  getActiveCompanies: (dbName: string) =>
    apiHelpers.get<ActiveCompanyDto[]>(`companies/active?db=${encodeURIComponent(dbName)}`),

  getActiveDivisions: (dbName: string) =>
    apiHelpers.get<ActiveDivisionDto[]>(`divisions/active?db=${encodeURIComponent(dbName)}`),

  refreshToken: (refreshToken: string) =>
    api.post<ApiResponse<AuthResponse>>('auth/refresh', { refreshToken }),

  logout: (refreshToken?: string) =>
    api.post('auth/logout', { refreshToken }),
}
