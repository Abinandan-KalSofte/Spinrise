import dayjs from 'dayjs'
import { apiHelpers } from '@/shared/api/client'
import { formatPoNo } from '../types'
import type {
  DivisionOption,
  PoApprovalLine,
  PoApprovalLineItem,
  PoApprovalGetResponse,
  PoApprovalSaveRequest,
  PoApprovalSaveResult,
} from '../types/poApprovalTypes'

// Real backend — Spinrise.API PoApprovalController (api/v1/po-approval/{level}),
// backed by ksp_PO_GetPending{First,Second,Final}Approval / ksp_PO_Set{First,
// Second,Final}Approval. Shared factory so First/Second/Final Level each get
// their own api module (own `level` segment) without duplicating HTTP plumbing.

type Level = 'first' | 'second' | 'final'

interface DivisionRow { divCode: string; divName: string }

interface LineItemDto {
  pordSno:       number
  itemCode:      string
  itemName:      string
  qty:           number
  uom:           string
  rate:          number
  value:         number
  onlineRemarks: string
  fClosed:       'Y' | 'N'
}

interface ProvenanceDto { by: string; on: string }

interface LineDto {
  divCode:        string
  divName:        string
  poNo:           number
  poDate:         string   // yyyy-MM-dd
  orderType:      string
  supplierCode:   string
  supplierName:   string
  supplierPlace:  string
  currency:       string
  paymentTerm:    string
  netTotal:       number
  amendNo:        number
  firstLevelApp:  'Y' | 'N'
  secondLevelApp: 'Y' | 'N'
  conflg:         'Y' | 'N'
  lines?:         LineItemDto[]
  lineCount?:     number
  poValue?:       number
  firstLevel?:    ProvenanceDto
  secondLevel?:   ProvenanceDto
}

function mapLineItem(l: LineItemDto): PoApprovalLineItem {
  return {
    pordsno: l.pordSno, itemCode: l.itemCode, itemName: l.itemName, qty: l.qty,
    uom: l.uom, rate: l.rate, value: l.value, onlineRemarks: l.onlineRemarks, fclosed: l.fClosed,
  }
}

function mapLine(dto: LineDto): Omit<PoApprovalLine, 'disposition' | 'remarks' | 'status' | 'selected'> {
  return {
    pordno:  formatPoNo(dto.poNo),
    poNo:    dto.poNo,
    poDate:  dto.poDate,
    porddt:  dayjs(dto.poDate).format('DD/MM/YYYY'),
    divCode: dto.divCode,
    divName: dto.divName,
    supplier: { code: dto.supplierCode, name: dto.supplierName, place: dto.supplierPlace },
    orderType: dto.orderType, currency: dto.currency, paymentTerm: dto.paymentTerm,
    netTotal: dto.netTotal, amendNo: dto.amendNo,
    firstLevelApp: dto.firstLevelApp, secondLevelApp: dto.secondLevelApp, conflg: dto.conflg,
    lines: dto.lines?.map(mapLineItem),
    lineCount: dto.lineCount,
    poValue: dto.poValue,
    firstLevel: dto.firstLevel,
    secondLevel: dto.secondLevel,
  }
}

export interface PoApprovalApiClient {
  getDivisions(): Promise<DivisionOption[]>
  // 10-Jul-2026: FY guard (yfDate/ylDate), same pattern as the PR module's
  // getPendingList — computed client-side via getFYBounds(processingDate).
  getPending(divCode: string, yfDate: string, ylDate: string, poNoSearch: string): Promise<PoApprovalGetResponse>
  saveActions(request: PoApprovalSaveRequest): Promise<PoApprovalSaveResult>
}

export function createPoApprovalApi(level: Level): PoApprovalApiClient {
  const BASE = `po-approval/${level}`

  return {
    async getDivisions() {
      const divisions = await apiHelpers.get<DivisionRow[]>(`${BASE}/divisions`)
      return [
        { code: '0', name: 'ALL Divisions' },
        ...divisions.map((d): DivisionOption => ({ code: d.divCode, name: d.divName })),
      ]
    },

    async getPending(divCode, yfDate, ylDate, poNoSearch) {
      const p = new URLSearchParams({ divCode, yfDate, ylDate })
      if (poNoSearch) p.set('search', poNoSearch)
      const resp = await apiHelpers.get<{ items: LineDto[] }>(`${BASE}/pending?${p}`)
      const items = resp.items.map((dto) => ({
        ...mapLine(dto),
        disposition: 2 as const,
        remarks: '',
        status: 'pending' as const,
        selected: false,
      }))
      return { items }
    },

    async saveActions(request) {
      const pordnoByPoNo = new Map(request.items.map((i) => [i.poNo, i.pordno]))
      // 10-Jul-2026 bug fix: divCode travels per-item now, not as one request-level
      // value — under "ALL Divisions" the filter's divCode ('0') never matches a
      // row's real division, so every save under that filter was silently failing.
      const resp = await apiHelpers.post<{ saved: number[] }>(`${BASE}/save`, {
        items: request.items.map((i) => ({
          divCode: i.divCode, poNo: i.poNo, poDate: i.poDate,
          disposition: i.disposition, remarks: i.remarks, postponeDate: i.postponeDate,
        })),
      })
      return { saved: resp.saved.map((n) => pordnoByPoNo.get(n) ?? formatPoNo(n)) }
    },
  }
}
