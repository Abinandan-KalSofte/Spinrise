import { lazy, Suspense } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { Spin } from 'antd'
import ProtectedRoute from './shared/components/ProtectedRoute'

const LoginPage     = lazy(() => import('./features/auth/pages/LoginPage'))
const DashboardPage = lazy(() => import('./pages/DashboardPage'))

export default function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={<Spin fullscreen />}>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            path="/dashboard"
            element={
              <ProtectedRoute>
                <DashboardPage />
              </ProtectedRoute>
            }
          />
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  )
}
