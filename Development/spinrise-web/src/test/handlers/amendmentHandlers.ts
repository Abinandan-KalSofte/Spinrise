import { http, HttpResponse } from 'msw'

const BASE = '/api/v1/pr-amendment'

export const amendmentHandlers = [
  http.get(`${BASE}`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: { records: [], totalCount: 0 },
    }),
  ),

  http.get(`${BASE}/for-new/:prNo/:prDate`, ({ params }) =>
    HttpResponse.json({
      success: true, message: '',
      data: {
        header: { prNo: Number(params.prNo), depCode: 'ENG', amendNo: 0 },
        lines: [],
      },
    }),
  ),

  http.get(`${BASE}/:prNo/:prDate/:amendNo`, ({ params }) =>
    HttpResponse.json({
      success: true, message: '',
      data: {
        header: { prNo: Number(params.prNo), amendNo: Number(params.amendNo) },
        lines: [],
      },
    }),
  ),

  http.post(`${BASE}`, () =>
    HttpResponse.json({
      success: true,
      message: 'Amendment No. 1 created successfully.',
      data: { amendNo: 1 },
    }),
  ),

  http.put(`${BASE}/:prNo/:prDate/:amendNo`, () =>
    HttpResponse.json({ success: true, message: 'Amendment updated successfully.' }),
  ),

  http.delete(`${BASE}/:prNo/:prDate/:amendNo`, () =>
    HttpResponse.json({ success: true, message: 'Amendment deleted successfully.' }),
  ),
]
