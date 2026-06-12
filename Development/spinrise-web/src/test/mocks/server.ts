import { setupServer } from 'msw/node'
import { prHandlers } from '../handlers/prHandlers'
import { amendmentHandlers } from '../handlers/amendmentHandlers'
import { firstApprovalHandlers } from '../handlers/firstApprovalHandlers'
import { finalApprovalHandlers } from '../handlers/finalApprovalHandlers'
import { cancellationHandlers } from '../handlers/cancellationHandlers'
import { foreclosureHandlers } from '../handlers/foreclosureHandlers'
import { poTransferHandlers } from '../handlers/poTransferHandlers'
import { authHandlers } from '../handlers/authHandlers'

export const server = setupServer(
  ...authHandlers,
  ...prHandlers,
  ...poTransferHandlers,
  ...amendmentHandlers,
  ...firstApprovalHandlers,
  ...finalApprovalHandlers,
  ...cancellationHandlers,
  ...foreclosureHandlers,
)
