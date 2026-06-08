import { http, HttpResponse } from 'msw'

const BASE = '/api/v1/pr-cancellation'

export const cancellationHandlers = [
  http.get(`${BASE}/cancellable`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [
        { prNo: 12345, depCode: 'ENG', depName: 'Engineering', prDate: '2026-01-15T00:00:00' },
      ],
    }),
  ),

  http.get(`${BASE}/detail`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: {
        header: { prNo: 12345, depCode: 'ENG' },
        lines: [{ prSno: 1, itemCode: 'ITEM001', qty: 10 }],
      },
    }),
  ),

  http.post(`${BASE}/cancel`, () =>
    HttpResponse.json({
      success: true,
      message: 'PR-12345 cancelled. Audit written to LogDet_PO.',
    }),
  ),

  http.get(`${BASE}/cancelled-for-undo`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [
        {
          prNo: 12345, depCode: 'ENG', depName: 'Engineering',
          cancelReason: 'Vendor not available', rowVersion: 'AAAAAAAAAA==',
        },
      ],
    }),
  ),

  // DEF-PRC-02 regression: undo must succeed without RowVersion error
  http.post(`${BASE}/undo`, () =>
    HttpResponse.json({
      success: true,
      message: 'PR-12345 restored. Audit written to LogDet_PO.',
    }),
  ),
]
