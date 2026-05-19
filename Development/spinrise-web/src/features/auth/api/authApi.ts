import apiClient from '../../../shared/api/client';
import type { AuthResponse, LoginRequest } from '../types';

export const login = async (data: LoginRequest): Promise<AuthResponse> => {
  const res = await apiClient.post<{ data: AuthResponse }>('/auth/login', data);
  return res.data.data;
};

export const logout = async (refreshToken: string): Promise<void> => {
  await apiClient.post('/auth/logout', { refreshToken });
};
