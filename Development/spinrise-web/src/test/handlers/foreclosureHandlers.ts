import { http, HttpResponse } from 'msw'

const BASE = '/api/v1/pr-foreclosure'

export const foreclosureHandlers = [
  http.get(`${BASE}/open-lines`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [
        {
          prNo: 12345, prSno: 1, itemCode: 'ITEM001', itemName: 'Test Item',
          depCode: 'ENG', depName: 'Engineering', balance: 5,
          prDate: '2026-01-15', macNo: null,
        },
      ],
    }),
  ),

  http.post(`${BASE}/save`, () =>
    HttpResponse.json({
      success: true,
      message: '1 line force-closed. Audit written to LogDet_PO.',
      data: { count: 1 },
    }),
  ),
]
