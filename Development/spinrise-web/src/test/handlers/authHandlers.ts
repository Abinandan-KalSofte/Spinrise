import { http, HttpResponse } from 'msw'

export const authHandlers = [
  http.post('/api/v1/auth/login', async ({ request }) => {
    const body = await request.json() as { userId: string; password: string }
    if (body?.userId === 'testuser' && body?.password === 'testpass') {
      return HttpResponse.json({
        success: true,
        message: 'Login successful.',
        data: {
          accessToken: 'test-access-token',
          refreshToken: 'test-refresh-token',
          user: {
            userId: 'testuser',
            userName: 'Test User',
            divCode: '01',
            dbName: 'JAT',
            role: 'User',
          },
        },
      })
    }
    return HttpResponse.json(
      { success: false, message: 'Invalid credentials.' },
      { status: 401 },
    )
  }),

  http.post('/api/v1/auth/logout', () => {
    return HttpResponse.json({ success: true, message: 'Logout successful.' })
  }),

  http.post('/api/v1/auth/refresh', () => {
    return HttpResponse.json({
      success: true,
      message: 'Token refreshed successfully.',
      data: { accessToken: 'new-access-token', refreshToken: 'new-refresh-token' },
    })
  }),
]
