import { Modal } from 'antd'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/features/auth/store/useAuthStore'

export default function SessionExpiredModal() {
  const navigate        = useNavigate()
  const sessionExpired  = useAuthStore((s) => s.sessionExpired)
  const setSessionExpired = useAuthStore((s) => s.setSessionExpired)

  const handleLogin = () => {
    setSessionExpired(false)
    navigate('/login', { replace: true })
  }

  return (
    <Modal
      open={sessionExpired}
      title="Session Closed"
      onOk={handleLogin}
      okText="Login Again"
      closable={false}
      mask={{ closable: false }}
      cancelButtonProps={{ style: { display: 'none' } }}
      centered
    >
      <p>Your session has expired. Please login again to continue.</p>
    </Modal>
  )
}
