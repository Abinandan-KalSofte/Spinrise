export interface LoginDto {
  divCode:  string
  userName: string
  password: string
}

export interface ActiveDivisionDto {
  divCode: string
  divName: string
}

export type UserRole = 'Admin' | 'Manager' | 'User'

export interface AuthUser {
  id:       number
  userId:   string
  userName: string
  email:    string
  role:     UserRole
  divCode:  string
  divName:  string
}

export interface AuthTokens {
  accessToken:  string
  refreshToken: string
}

export interface AuthResponse {
  user:   AuthUser
  tokens: AuthTokens
}
