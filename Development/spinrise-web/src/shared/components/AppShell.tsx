import { useState } from 'react'
import { Layout, Menu, Button, Dropdown, Tag } from 'antd'
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

const NAV_ITEMS: MenuItem[] = [
  mk('/dashboard', 'Dashboard', <DashboardOutlined />),
  mk('grp-purchase', 'Purchase Order', <ShoppingCartOutlined />, [
    mk('/purchase-requisition', 'Purchase Requisition', <FileTextOutlined />),
    mk('/rmi-purchase-order', 'RMI Purchase Order', <FileTextOutlined />, undefined, true),
  ]),
]

const BREADCRUMB_MAP: Record<string, string[]> = {
  '/dashboard':             ['Dashboard'],
  '/purchase-requisition':  ['Purchase Order', 'Purchase Requisition'],
  '/rmi-purchase-order':    ['Purchase Order', 'RMI Purchase Order'],
}

function getOpenKeys(path: string): string[] {
  if (path.startsWith('/purchase-requisition') || path.startsWith('/rmi-purchase-order')) {
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
  const breadcrumbs  = BREADCRUMB_MAP[location.pathname] ?? []

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
        width={220}
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

        {/* Collapse toggle */}
        <div style={{
          borderTop: '1px solid rgba(255,255,255,0.08)',
          padding: '8px',
          display: 'flex',
          justifyContent: collapsed ? 'center' : 'flex-end',
          flexShrink: 0,
        }}>
          <Button
            type="text"
            icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
            onClick={() => setCollapsed(!collapsed)}
            style={{ color: 'rgba(255,255,255,0.5)', fontSize: 14 }}
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
          {/* Breadcrumb */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13 }}>
            {breadcrumbs.map((crumb, i) => (
              <span key={crumb} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                {i > 0 && <span style={{ color: '#cbd5e1' }}>/</span>}
                <span style={{ color: i === breadcrumbs.length - 1 ? '#1e293b' : '#94a3b8', fontWeight: i === breadcrumbs.length - 1 ? 600 : 400 }}>
                  {crumb}
                </span>
              </span>
            ))}
          </div>

          {/* User info */}
          <Dropdown menu={{ items: userMenuItems }} placement="bottomRight" trigger={['click']}>
            <div style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{
                width: 28, height: 28, borderRadius: '50%',
                background: 'linear-gradient(135deg, #185FA5, #1677ff)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0,
              }}>
                <UserOutlined style={{ color: '#fff', fontSize: 13 }} />
              </div>
              <span style={{ fontSize: 13, color: '#374151', fontWeight: 500 }}>
                {user?.userName}
              </span>
              {user?.divCode && (
                <Tag color="blue" style={{ fontSize: 11, margin: 0, lineHeight: '18px' }}>
                  {user.divCode}
                </Tag>
              )}
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
