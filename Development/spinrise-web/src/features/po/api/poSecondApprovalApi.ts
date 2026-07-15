import { createPoApprovalApi } from './createPoApprovalApi'

// PO Second Level Approval — real backend (Spinrise.API PoApprovalController,
// api/v1/po-approval/second/*). See createPoApprovalApi.ts for the shared
// HTTP client.
export const poSecondApprovalApi = createPoApprovalApi('second')
