import { lazy, Suspense } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { Spin } from 'antd'
import ProtectedRoute from './shared/components/ProtectedRoute'
import AppShell from './shared/components/AppShell'
import SessionExpiredModal from './shared/components/SessionExpiredModal'

const LoginPage               = lazy(() => import('./features/auth/pages/LoginPage'))
const DashboardPage           = lazy(() => import('./pages/DashboardPage'))
const PurchaseRequisitionPage = lazy(() => import('./features/pr/pages/PurchaseRequisitionPage'))
const PrAmendmentPage         = lazy(() => import('./features/pr/pages/PrAmendmentPage'))
const PrForeclosurePage       = lazy(() => import('./features/pr/pages/PrForeclosurePage'))
const PrCancellationPage      = lazy(() => import('./features/pr/pages/PrCancellationPage'))
const PrFirstApprovalPage     = lazy(() => import('./features/pr/pages/PrFirstApprovalPage'))
const FinalLevelApprovalPage  = lazy(() => import('./features/pr/pages/FinalLevelApprovalPage'))
const PrToPoTransferPage      = lazy(() => import('./features/po/pages/PrToPoTransferPage'))

export default function App() {
  return (
    <BrowserRouter>
      <SessionExpiredModal />
      <Suspense fallback={<Spin fullscreen />}>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            element={
              <ProtectedRoute>
                <AppShell />
              </ProtectedRoute>
            }
          >
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/purchase-requisition"             element={<PurchaseRequisitionPage />} />
            <Route path="/pr-amendment"                   element={<PrAmendmentPage />} />
            <Route path="/pr-foreclosure"                 element={<PrForeclosurePage />} />
            <Route path="/pr-cancellation"                element={<PrCancellationPage />} />
            <Route path="/pr-first-approval"              element={<PrFirstApprovalPage />} />
            <Route path="/pr-final-approval"              element={<FinalLevelApprovalPage />} />
            <Route path="/po/transfer"                    element={<PrToPoTransferPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  )
}
