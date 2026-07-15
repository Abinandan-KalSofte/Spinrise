import { http, HttpResponse } from 'msw'

const BASE = '/api/v1/po-foreclosure'

export const poForeclosureHandlers = [
  http.get(`${BASE}/lines`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [
        {
          group: 'A', poNo: 4521, poDate: '2026-06-12', slCode: 'SL0231', supplierName: 'Sri Balaji Textiles',
          sNo: 1, itemCode: 'IT100455', itemName: 'Cotton Yarn 40s Combed', balanceQty: 3800,
          prNo: 'PR-000210', prDate: '2026-06-01',
        },
      ],
    }),
  ),

  http.post(`${BASE}/foreclose`, () =>
    HttpResponse.json({
      success: true,
      message: 'Purchase Order Closed Successfully',
    }),
  ),
]
