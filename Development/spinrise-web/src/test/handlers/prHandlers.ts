import { http, HttpResponse } from 'msw'

const BASE = '/api/v1/pr'

export const prHandlers = [
  http.get(`${BASE}/parameters`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: { manualIndNo: 'N', budgetQty: 'N', pendingOrderPara: 'N' },
    }),
  ),

  http.get(`${BASE}/departments`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [{ depCode: 'ENG', depName: 'Engineering' }],
    }),
  ),

  http.get(`${BASE}/pr-types`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [{ prType: 'I', prTypeName: 'Indent' }],
    }),
  ),

  http.get(`${BASE}/items`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: { items: [], totalCount: 0 },
    }),
  ),

  http.get(`${BASE}/last`, () =>
    HttpResponse.json({ success: true, message: '', data: null }),
  ),

  http.get(`${BASE}`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: { records: [], totalCount: 0 },
    }),
  ),

  http.get(`${BASE}/:prNo`, ({ params }) =>
    HttpResponse.json({
      success: true, message: '',
      data: {
        header: { prNo: Number(params.prNo), depCode: 'ENG', prDate: '2026-01-15' },
        lines: [],
      },
    }),
  ),

  http.post(`${BASE}`, () =>
    HttpResponse.json({
      success: true, message: 'PR No. for your transaction is 12345',
      data: { prNo: 12345 },
    }),
  ),

  http.put(`${BASE}`, () =>
    HttpResponse.json({ success: true, message: 'PR updated successfully.', data: { prNo: 12345 } }),
  ),

  http.delete(`${BASE}`, () =>
    HttpResponse.json({ success: true, message: 'PR deleted successfully.' }),
  ),

  http.get(`${BASE}/permissions`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: { canAdd: true, canEdit: true, canDelete: true, canPrint: true },
    }),
  ),

  http.get(`${BASE}/pre-add-checks`, () =>
    HttpResponse.json({ success: true, message: '', data: { allowed: true } }),
  ),
]
