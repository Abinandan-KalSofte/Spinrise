import { createPoApprovalApi } from './createPoApprovalApi'

// PO Final Level Approval — real backend (Spinrise.API PoApprovalController,
// api/v1/po-approval/final/*). See createPoApprovalApi.ts for the shared
// HTTP client. Grouped view (FSD §10.2) — GetPendingAsync returns
// lineCount/poValue aggregates, no line[] detail.
export const poFinalApprovalApi = createPoApprovalApi('final')
