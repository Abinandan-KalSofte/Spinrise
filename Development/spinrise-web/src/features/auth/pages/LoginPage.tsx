import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Card, Form, Input, Select, Typography, message } from 'antd';
import { login } from '../api/authApi';
import { useAuthStore } from '../store/authStore';

const { Title } = Typography;

interface LoginForm {
  divCode: string;
  userName: string;
  password: string;
}

const DIV_CODES = [
  { label: 'Division 01', value: '01' },
  { label: 'Division 02', value: '02' },
];

export default function LoginPage() {
  const navigate = useNavigate();
  const setAuth = useAuthStore((s) => s.setAuth);
  const [loading, setLoading] = useState(false);

  const onFinish = async (values: LoginForm) => {
    setLoading(true);
    try {
      const res = await login(values);
      setAuth(res.user, res.tokens.accessToken, res.tokens.refreshToken);
      navigate('/dashboard', { replace: true });
    } catch {
      message.error('Invalid credentials. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f0f2f5' }}>
      <Card style={{ width: 400, boxShadow: '0 4px 24px rgba(0,0,0,0.08)' }}>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <Title level={3} style={{ margin: 0 }}>Spinrise ERP</Title>
          <Typography.Text type="secondary">Sign in to your account</Typography.Text>
        </div>

        <Form layout="vertical" onFinish={onFinish} autoComplete="off">
          <Form.Item label="Division" name="divCode" rules={[{ required: true, message: 'Select a division' }]}>
            <Select placeholder="Select Division" options={DIV_CODES} />
          </Form.Item>

          <Form.Item label="User Name" name="userName" rules={[{ required: true, message: 'Enter your user name' }]}>
            <Input placeholder="User Name" />
          </Form.Item>

          <Form.Item label="Password" name="password" rules={[{ required: true, message: 'Enter your password' }]}>
            <Input.Password placeholder="Password" />
          </Form.Item>

          <Form.Item style={{ marginBottom: 0 }}>
            <Button type="primary" htmlType="submit" block loading={loading}>
              Sign In
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
}
