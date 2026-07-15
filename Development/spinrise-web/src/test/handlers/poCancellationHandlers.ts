import { http, HttpResponse } from 'msw'

const BASE = '/api/v1/po-cancellation'

export const poCancellationHandlers = [
  http.get(`${BASE}/reasons`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [
        { code: '01', name: 'Rate Mismatch' },
        { code: '02', name: 'Supplier Unable to Supply' },
        { code: '03', name: 'Item No Longer Required' },
      ],
    }),
  ),

  http.get(`${BASE}/lines`, () =>
    HttpResponse.json({
      success: true, message: '',
      data: [
        { slCode: 'SL0231', itemCode: 'IT100455', sNo: 1, itemName: 'Cotton Yarn 40s Combed', uom: 'KGS', orderQty: 5000, receivedQty: 1200, rate: 285.5, value: 1427500 },
      ],
    }),
  ),

  http.post(`${BASE}/cancel`, () =>
    HttpResponse.json({
      success: true,
      message: 'PO-004521 cancellation saved.',
    }),
  ),
]
