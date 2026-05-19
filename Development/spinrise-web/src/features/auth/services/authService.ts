import { authApi } from '../api/authApi'
import type { AuthResponse, AuthTokens, AuthUser, LoginDto, UserRole } from '../types'

function mapAuthUser(user: AuthResponse['user']): AuthUser {
  return {
    id:       user.id,
    userId:   user.userId   ?? '',
    userName: user.userName ?? '',
    email:    user.email    ?? '',
    role:     (user.role    ?? 'User') as UserRole,
    divCode:  user.divCode  ?? '',
  }
}

function mapAuthTokens(tokens: AuthResponse['tokens']): AuthTokens {
  return {
    accessToken:  tokens.accessToken,
    refreshToken: tokens.refreshToken,
  }
}

export const authService = {
  async login(data: LoginDto) {
    const response = await authApi.login(data)
    const payload  = response.data.data!
    return {
      user:   mapAuthUser(payload.user),
      tokens: mapAuthTokens(payload.tokens),
    }
  },

  async refreshToken(refreshToken: string) {
    const response = await authApi.refreshToken(refreshToken)
    const payload  = response.data.data!
    return {
      user:   mapAuthUser(payload.user),
      tokens: mapAuthTokens(payload.tokens),
    }
  },

  async logout(refreshToken?: string) {
    await authApi.logout(refreshToken)
  },
}
