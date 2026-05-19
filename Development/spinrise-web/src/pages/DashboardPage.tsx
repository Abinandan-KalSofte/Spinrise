import { Button, Layout, Typography } from 'antd'
import { useNavigate } from 'react-router-dom'
import { authApi } from '../features/auth/api/authApi'
import { useAuthStore } from '../features/auth/store/useAuthStore'

const { Header, Content } = Layout

export default function DashboardPage() {
  const navigate          = useNavigate()
  const user              = useAuthStore((s) => s.user)
  const tokens            = useAuthStore((s) => s.tokens)
  const clearAuthSession  = useAuthStore((s) => s.clearAuthSession)

  const handleLogout = async () => {
    await authApi.logout(tokens?.refreshToken).catch(() => {})
    clearAuthSession()
    navigate('/login', { replace: true })
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography.Title level={4} style={{ color: '#fff', margin: 0 }}>
          Spinrise ERP V2
        </Typography.Title>
        <div style={{ color: '#fff', display: 'flex', gap: 16, alignItems: 'center' }}>
          <span>{user?.userName}</span>
          <Button size="small" onClick={handleLogout}>Sign Out</Button>
        </div>
      </Header>
      <Content style={{ padding: 24 }}>
        <Typography.Title level={4}>Dashboard</Typography.Title>
        <Typography.Text type="secondary">
          Welcome, {user?.userName}. Modules will appear here as they are built.
        </Typography.Text>
      </Content>
    </Layout>
  )
}
