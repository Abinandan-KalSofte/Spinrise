import { Button, Layout, Typography } from 'antd';
import { useNavigate } from 'react-router-dom';
import { logout } from '../features/auth/api/authApi';
import { useAuthStore } from '../features/auth/store/authStore';

const { Header, Content } = Layout;

export default function DashboardPage() {
  const navigate = useNavigate();
  const { user, clearAuth } = useAuthStore();

  const handleLogout = async () => {
    const token = localStorage.getItem('refreshToken');
    if (token) await logout(token).catch(() => {});
    clearAuth();
    navigate('/login', { replace: true });
  };

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography.Title level={4} style={{ color: '#fff', margin: 0 }}>
          Spinrise ERP
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
  );
}
