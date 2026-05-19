import { Card, Typography } from 'antd'
import { FileTextOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'

export default function DashboardPage() {
  const navigate = useNavigate()

  return (
    <div style={{ padding: 24 }}>
      <Typography.Title level={4} style={{ marginTop: 0 }}>Dashboard</Typography.Title>
      <Typography.Text type="secondary">Select a module to get started.</Typography.Text>

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
    </div>
  )
}
