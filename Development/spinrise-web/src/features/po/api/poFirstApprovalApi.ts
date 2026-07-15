import { createPoApprovalApi } from './createPoApprovalApi'

// PO First Level Approval — real backend (Spinrise.API PoApprovalController,
// api/v1/po-approval/first/*). See createPoApprovalApi.ts for the shared
// HTTP client. CD-08 (row_version optimistic concurrency) is enforced
// server-side in ksp_PO_SetFirstApproval for every disposition, not just
// as a First-Level-only demo.
export const poFirstApprovalApi = createPoApprovalApi('first')
