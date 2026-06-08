import { http, HttpResponse } from 'msw'

const BASE = '/api/v1/finallevel-pr'

export const finalApprovalHandlers = [
  http.get(`${BASE}`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: {
        items: [
          {
            prNo: 12345, prSno: 1, divCode: '01', depCode: 'ENG',
            itemCode: 'ITEM001', itemName: 'Test Item',
            qtyRequired: 10, lpoRate: 100, disposition: 2,
            rowVersion: 'AAAAAAAAAA==',
          },
        ],
        totalCount: 1,
        totalCost: 1000,
      },
    }),
  ),

  http.post(`${BASE}/approve`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: { approvedCount: 1, message: 'Purchase Requisition Approval Completed.' },
    }),
  ),

  http.get(`${BASE}/companies`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [{ dbName: 'JAT', companyName: 'Test Company' }],
    }),
  ),

  http.get(`${BASE}/divisions`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [{ divCode: '01', divName: 'Main Division' }],
    }),
  ),

  http.get(`${BASE}/items/:itemCode/purchase-history`, () =>
    HttpResponse.json({ success: true, message: '', data: [] }),
  ),
]
