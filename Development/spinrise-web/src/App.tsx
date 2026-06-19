import { lazy, Suspense } from 'react'
import { RouterProvider, createBrowserRouter, Navigate, Outlet } from 'react-router-dom'
import ProtectedRoute from './shared/components/ProtectedRoute'
import AppShell from './shared/components/AppShell'
import SessionExpiredModal from './shared/components/SessionExpiredModal'
import { AppLoader } from './components/common/loading'

const LoginPage               = lazy(() => import('./features/auth/pages/LoginPage'))
const DashboardPage           = lazy(() => import('./pages/DashboardPage'))
const PurchaseRequisitionPage = lazy(() => import('./features/pr/pages/PurchaseRequisitionPage'))
const PrAmendmentPage         = lazy(() => import('./features/pr/pages/PrAmendmentPage'))
const PrForeclosurePage       = lazy(() => import('./features/pr/pages/PrForeclosurePage'))
const PrCancellationPage      = lazy(() => import('./features/pr/pages/PrCancellationPage'))
const PrFirstApprovalPage     = lazy(() => import('./features/pr/pages/PrFirstApprovalPage'))
const FinalLevelApprovalPage  = lazy(() => import('./features/pr/pages/FinalLevelApprovalPage'))
const PrToPoTransferPage      = lazy(() => import('./features/po/pages/PrToPoTransferPage'))
const PrReportPage            = lazy(() => import('./features/pr/pages/PrReportPage'))

const RouteShell = () => (
  <>
    <SessionExpiredModal />
    <Outlet />
  </>
)

const router = createBrowserRouter([
  {
    element: <RouteShell />,
    children: [
      { path: '/login', element: <Suspense fallback={<AppLoader />}><LoginPage /></Suspense> },
      {
        element: <Suspense fallback={<AppLoader />}><ProtectedRoute><AppShell /></ProtectedRoute></Suspense>,
        children: [
          { path: '/dashboard', element: <DashboardPage /> },
          { path: '/purchase-requisition', element: <PurchaseRequisitionPage /> },
          { path: '/pr-amendment', element: <PrAmendmentPage /> },
          { path: '/pr-foreclosure', element: <PrForeclosurePage /> },
          { path: '/pr-cancellation', element: <PrCancellationPage /> },
          { path: '/pr-first-approval', element: <PrFirstApprovalPage /> },
          { path: '/pr-final-approval', element: <FinalLevelApprovalPage /> },
          { path: '/po-transfer', element: <PrToPoTransferPage /> },
          { path: '/pr-report', element: <PrReportPage /> },
        ],
      },
      { path: '*', element: <Navigate to="/login" replace /> },
    ],
  },
])

export default function App() {
  return <RouterProvider router={router} />
}
