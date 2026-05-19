export interface LoginRequest {
  divCode: string;
  userName: string;
  password: string;
}

export interface AuthUser {
  id: number;
  userId: string;
  userName: string;
  email: string;
  role: string;
  divCode: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthResponse {
  user: AuthUser;
  tokens: AuthTokens;
}
