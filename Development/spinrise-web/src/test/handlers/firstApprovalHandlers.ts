import { http, HttpResponse } from 'msw'

const BASE = '/api/v1/pr-first-approval'

export const firstApprovalHandlers = [
  http.get(`${BASE}/po-para`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: { userLevel: 'L1', isFirstLevel: true },
    }),
  ),

  http.get(`${BASE}/departments`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [{ depCode: 'ENG', depName: 'Engineering' }],
    }),
  ),

  http.get(`${BASE}/pending`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [
        {
          prNo: 12345, depCode: 'ENG', depName: 'Engineering',
          prDate: '2026-01-15T00:00:00', itemCode: 'ITEM001',
          itemName: 'Test Item', qtyReqd: 10, firstAppQty: null,
        },
      ],
    }),
  ),

  http.get(`${BASE}/approved`, () =>
    HttpResponse.json({ success: true, message: '', data: [] }),
  ),

  http.get(`${BASE}/detail`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: {
        header: { prNo: 12345, depCode: 'ENG', prDate: '2026-01-15T00:00:00' },
        lines: [{ prSno: 1, itemCode: 'ITEM001', qtyReqd: 10 }],
      },
    }),
  ),

  http.post(`${BASE}/approve`, () =>
    HttpResponse.json({
      success: true,
      message: 'PR-12345 — First Level Approval saved. PRSTATUS → F.',
    }),
  ),

  http.post(`${BASE}/delete-approval`, () =>
    HttpResponse.json({
      success: true,
      message: 'PR-12345 — First Level Approval deleted. PRSTATUS → Requested.',
    }),
  ),
]
