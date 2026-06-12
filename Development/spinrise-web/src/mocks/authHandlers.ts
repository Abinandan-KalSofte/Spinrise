import { http, HttpResponse } from 'msw'

// ── Demo auth (runtime mock) ─────────────────────────────────────────────────
// Lets testers log in with ANY non-empty credentials so the PO module can be
// reached without a backend. Division 'S' matches the PO mock data.
// TODO: Replace with actual backend API when available

export const demoAuthHandlers = [
  // TODO: Replace with actual backend API when available
  http.post('/api/v1/auth/login', async ({ request }) => {
    const body = (await request.json().catch(() => null)) as { userId?: string; password?: string } | null
    if (!body?.userId || !body?.password) {
      return HttpResponse.json({ success: false, message: 'Enter user id and password.' }, { status: 401 })
    }
    return HttpResponse.json({
      success: true, message: 'Login successful.',
      data: {
        tokens: { accessToken: 'demo-access-token', refreshToken: 'demo-refresh-token' },
        user: {
          userId: body.userId, userName: 'Demo User', divCode: 'S', divName: 'Spinning',
          compName: 'KALPATHARU SPINNERS PVT. LTD.', dbName: 'SpinRiseSaranya', role: 'User',
        },
        processingDate: '2026-06-12',
      },
    })
  }),

  // TODO: Replace with actual backend API when available
  http.post('/api/v1/auth/logout', () => HttpResponse.json({ success: true, message: 'Logout successful.' })),

  // TODO: Replace with actual backend API when available
  http.post('/api/v1/auth/refresh', () =>
    HttpResponse.json({
      success: true, message: 'Token refreshed.',
      data: { tokens: { accessToken: 'demo-access-token-2', refreshToken: 'demo-refresh-token-2' } },
    })),
]
