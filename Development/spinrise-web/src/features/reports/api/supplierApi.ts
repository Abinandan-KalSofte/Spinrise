import { apiHelpers } from '@/shared/api/client'
import type { SupplierOption } from '../types/reportTypes'

const BASE = 'po/suppliers'

export const getSuppliers = (divCode: string): Promise<SupplierOption[]> =>
  apiHelpers.get<SupplierOption[]>(`${BASE}?divCode=${encodeURIComponent(divCode)}&pageSize=9999`)
    .catch(() => [])  // Non-critical
