export interface LoginDto {
  dbName:   string
  divCode:  string
  userName: string
  password: string
}

export interface DatabaseDto {
  name: string
}

export interface ActiveCompanyDto {
  compCode: string
  compName: string
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
  compCode: string
  compName: string
  dbName:   string
  modules:  string   // comma-separated module numbers e.g. "1,3,4"
}

export interface ActiveCompanyDto {
  compCode: string
  compName: string
}

export interface AuthTokens {
  accessToken:  string
  refreshToken: string
}

export interface AuthResponse {
  user:   AuthUser
  tokens: AuthTokens
}
