import { Navigate } from 'react-router-dom'
import { useAuthStore } from '../../features/auth/store/useAuthStore'

interface Props {
  children: React.ReactNode
}

export default function ProtectedRoute({ children }: Props) {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated)
  const sessionExpired  = useAuthStore((s) => s.sessionExpired)

  if (!isAuthenticated) {
    // Session expired: hold position so SessionExpiredModal can show; modal handles the /login redirect
    if (sessionExpired) return null
    return <Navigate to="/login" replace />
  }
  return <>{children}</>
}
