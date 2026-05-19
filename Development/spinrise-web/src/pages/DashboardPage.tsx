import { Button, Card, Layout, Typography } from 'antd'
import { FileTextOutlined } from '@ant-design/icons'
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
          Welcome, {user?.userName}. Select a module to get started.
        </Typography.Text>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, marginTop: 24 }}>
          <Card
            hoverable
            style={{ width: 220 }}
            onClick={() => navigate('/purchase-requisition')}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <FileTextOutlined style={{ fontSize: 28, color: '#185FA5' }} />
              <div>
                <div style={{ fontWeight: 600, fontSize: 14 }}>Purchase Requisition</div>
                <div style={{ fontSize: 12, color: '#888' }}>Create &amp; manage PRs</div>
              </div>
            </div>
          </Card>
        </div>
      </Content>
    </Layout>
  )
}
