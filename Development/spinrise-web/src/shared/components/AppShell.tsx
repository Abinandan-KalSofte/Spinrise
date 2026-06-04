import { useState } from 'react'
import { Layout, Menu, Button, Dropdown } from 'antd'
import { Outlet, useNavigate, useLocation } from 'react-router-dom'
import {
  DashboardOutlined,
  FileTextOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  ShoppingCartOutlined,
  LogoutOutlined,
  UserOutlined,
  DownOutlined,
} from '@ant-design/icons'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { authApi } from '@/features/auth/api/authApi'
import type { MenuProps } from 'antd'

const { Sider, Header, Content } = Layout

type MenuItem = Required<MenuProps>['items'][number]

function mk(
  key: string,
  label: React.ReactNode,
  icon?: React.ReactNode,
  children?: MenuItem[],
  disabled?: boolean,
): MenuItem {
  return { key, label, icon, children, disabled } as MenuItem
}

function wrapLabel(text: string) {
  return <span style={{ whiteSpace: 'normal', wordBreak: 'break-word', lineHeight: 1.35, display: 'inline-block' }}>{text}</span>
}

const NAV_ITEMS: MenuItem[] = [
  mk('/dashboard', 'Dashboard', <DashboardOutlined />),
  mk('grp-purchase', 'Purchase Order', <ShoppingCartOutlined />, [
    mk('/purchase-requisition', wrapLabel('Purchase Requisition (PR)'), <FileTextOutlined />),
    //mk('/pr-amendment',         wrapLabel('Purchase Requisition Amendment '),        <FileTextOutlined />),
    mk('/pr-foreclosure',       wrapLabel('Purchase Requisition Foreclosure '),      <FileTextOutlined />),
    mk('/pr-cancellation',      wrapLabel('Purchase Requisition Cancellation'),           <FileTextOutlined />),
    mk('/pr-first-approval',    wrapLabel('Purchase Requisition First Level Approval'),   <FileTextOutlined />),
    mk('/pr-final-approval',    wrapLabel('Purchase Requisition Final Level Approval'),   <FileTextOutlined />),
  ]),
]

function getOpenKeys(path: string): string[] {
  if (
    path.startsWith('/purchase-requisition') ||
    path.startsWith('/pr-amendment') ||
    path.startsWith('/pr-foreclosure') ||
    path.startsWith('/pr-cancellation') ||
    path.startsWith('/pr-first-approval') ||
    path.startsWith('/pr-final-approval') ||
    path.startsWith('/rmi-purchase-order')
  ) {
    return ['grp-purchase']
  }
  return []
}

export default function AppShell() {
  const navigate          = useNavigate()
  const location          = useLocation()
  const [collapsed, setCollapsed] = useState(false)

  const user             = useAuthStore((s) => s.user)
  const tokens           = useAuthStore((s) => s.tokens)
  const clearAuthSession = useAuthStore((s) => s.clearAuthSession)

  const handleLogout = async () => {
    await authApi.logout(tokens?.refreshToken).catch(() => {})
    clearAuthSession()
    navigate('/login', { replace: true })
  }

  const selectedKeys = [location.pathname]

  const userMenuItems: MenuProps['items'] = [
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: 'Sign Out',
      danger: true,
      onClick: () => { void handleLogout() },
    },
  ]

  return (
    <Layout style={{ height: '100vh', overflow: 'hidden' }}>

      {/* ── Sidebar ── */}
      <Sider
        collapsed={collapsed}
        width={260}
        collapsedWidth={52}
        style={{
          background: '#1a2236',
          height: '100vh',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
        }}
        trigger={null}
      >
        {/* Logo */}
        <div
          style={{
            height: 48,
            display: 'flex',
            alignItems: 'center',
            justifyContent: collapsed ? 'center' : 'flex-start',
            padding: collapsed ? 0 : '0 16px',
            borderBottom: '1px solid rgba(255,255,255,0.08)',
            gap: 10,
            flexShrink: 0,
            cursor: 'pointer',
          }}
          onClick={() => navigate('/dashboard')}
        >
          <div style={{
            width: 28, height: 28, borderRadius: 6, flexShrink: 0,
            background: 'linear-gradient(135deg, #185FA5, #1677ff)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <span style={{ color: '#fff', fontSize: 13, fontWeight: 800 }}>S</span>
          </div>
          {!collapsed && (
            <span style={{ color: '#fff', fontWeight: 700, fontSize: 14, whiteSpace: 'nowrap', overflow: 'hidden' }}>
              Spinrise ERP
            </span>
          )}
        </div>

        {/* Navigation menu */}
        <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden' }}>
          <Menu
            mode="inline"
            theme="dark"
            selectedKeys={selectedKeys}
            defaultOpenKeys={getOpenKeys(location.pathname)}
            items={NAV_ITEMS}
            style={{ background: '#1a2236', borderRight: 'none' }}
            onClick={({ key }) => { if (key.startsWith('/')) navigate(key) }}
          />
        </div>

      </Sider>

      {/* ── Main area ── */}
      <Layout style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0 }}>

        {/* Header */}
        <Header style={{
          height: 48, lineHeight: '48px',
          padding: '0 16px',
          background: '#fff',
          borderBottom: '1px solid #e8e8e8',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexShrink: 0,
        }}>
          {/* Sidebar toggle */}
          <Button
            type="text"
            icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
            onClick={() => setCollapsed(!collapsed)}
            style={{ color: '#64748b', fontSize: 14, marginRight: 4 }}
          />
          {/* Company name */}
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', minWidth: 0 }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: '#1e293b', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', letterSpacing: '0.02em', minWidth: 0, display: 'block', maxWidth: '100%' }}>
              {user?.compName ?? user?.divName ?? ''}
            </span>
          </div>

          {/* User info */}
          <Dropdown menu={{ items: userMenuItems }} placement="bottomRight" trigger={['click']}>
            <div style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{
                width: 32, height: 32, borderRadius: '50%',
                background: 'linear-gradient(135deg, #185FA5, #1677ff)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0,
              }}>
                <UserOutlined style={{ color: '#fff', fontSize: 14 }} />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.2 }}>
                <span style={{ fontSize: 13, color: '#1e293b', fontWeight: 600 }}>
                  {user?.userName}
                </span>
                {(user?.divName || user?.divCode) && (
                  <span style={{ fontSize: 11, color: '#64748b', fontWeight: 400 }}>
                    {user.divName || user.divCode}
                  </span>
                )}
              </div>
              <DownOutlined style={{ color: '#94a3b8', fontSize: 10 }} />
            </div>
          </Dropdown>
        </Header>

        {/* Page content */}
        <Content style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', minHeight: 0 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}
