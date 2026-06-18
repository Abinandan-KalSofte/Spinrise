import { useState } from 'react'
import { Layout, Menu, Button, Dropdown, ConfigProvider, Modal } from 'antd'
import { Outlet, useNavigate, useLocation } from 'react-router-dom'
import { useNavigationGuardStore } from '@/shared/store/useNavigationGuardStore'
import {
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  ShoppingCartOutlined,
  LogoutOutlined,
  UserOutlined,
  DownOutlined,
  LayoutOutlined,        // or AppstoreOutlined for Dashboard
  FileDoneOutlined,      // PR sub-group
  FormOutlined,          // PR Amendment
  LockOutlined,          // PR Foreclosure
  CloseCircleOutlined,   // PR Cancellation
  CheckCircleOutlined,   // PR First Level Approval
  SafetyCertificateOutlined, // PR Final Level Approval
  RetweetOutlined,
  FileExcelOutlined,
  FileExclamationOutlined,
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

// Paths that live under the "Purchase Requisition (PR)" sub-group.
const PR_PATHS = [
  '/purchase-requisition',
  '/pr-amendment',
  '/pr-foreclosure',
  '/pr-cancellation',
  '/pr-first-approval',
  '/pr-final-approval',
  '/pr-report',
]

const NAV_ITEMS: MenuItem[] = [
  mk('/dashboard', 'Dashboard', <LayoutOutlined />),
  { type: 'divider', style: { borderColor: 'rgba(255,255,255,0.08)', margin: '8px 16px' } } as MenuItem,
  mk('grp-purchase', 'Purchase Order', <ShoppingCartOutlined  />, [
    mk('grp-pr', wrapLabel('Purchase Requisition (PR)'), '', [
      mk('/purchase-requisition', wrapLabel('Purchase Requisition (PR)'), <FileDoneOutlined />),
      mk('/pr-amendment',         wrapLabel('Purchase Requisition Amendment'),    <FormOutlined />),
      mk('/pr-foreclosure',       wrapLabel('Purchase Requisition Foreclosure'),  <LockOutlined />),
      mk('/pr-cancellation',      wrapLabel('Purchase Requisition Cancellation'), <CloseCircleOutlined />),
      mk('/pr-first-approval',    wrapLabel('Purchase Requisition First Level Approval'),           <CheckCircleOutlined />),
      mk('/pr-final-approval',    wrapLabel('Purchase Requisition Final Level Approval'),           <SafetyCertificateOutlined />),
    ]),
    mk('grp-transfer', wrapLabel('PR to PO Transfer'), '', [
      mk('/po/transfer', wrapLabel('PR to PO Transfer'), <RetweetOutlined />),
    ]),
  ]),
   mk('grp-reports', 'Reports', <FileExclamationOutlined  />, [
    mk('grp-reports-pr', wrapLabel('Periodic Reports'), '', [
      mk('/pr-report',            wrapLabel('Purchase Requisition Report'),                         <FileExcelOutlined />),
    ]),
  ]),
]

function getOpenKeys(path: string): string[] {
  if (PR_PATHS.some((p) => path.startsWith(p))) return ['grp-purchase', 'grp-pr']
  if (path.startsWith('/po/transfer'))          return ['grp-purchase', 'grp-transfer']
  return []
}

export default function AppShell() {
  const navigate          = useNavigate()
  const location          = useLocation()
  const [collapsed, setCollapsed] = useState(false)

  const user             = useAuthStore((s) => s.user)
  const tokens           = useAuthStore((s) => s.tokens)
  const clearAuthSession = useAuthStore((s) => s.clearAuthSession)

  const isDirty          = useNavigationGuardStore((s) => s.isDirty)
  const onConfirmDiscard = useNavigationGuardStore((s) => s.onConfirmDiscard)

  // Guard-aware navigate: shows confirm dialog when page has unsaved changes.
  const guardedNavigate = (to: string, replace?: boolean) => {
    if (isDirty) {
      Modal.confirm({
        title:      'Unsaved Changes',
        content:    'You have unsaved changes in the current screen. Do you want to discard the changes and continue?',
        okText:     'YES',
        cancelText: 'NO',
        okButtonProps: { danger: true },
        onOk: () => { onConfirmDiscard?.(); navigate(to, { replace }) },
      })
    } else {
      navigate(to, { replace })
    }
  }

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
        width={270}
        collapsedWidth={64}
        breakpoint="lg"
        onBreakpoint={(broken) => setCollapsed(broken)}
        style={{
          background: '#0f172a',
          height: '100vh',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
          boxShadow: '2px 0 12px rgba(0,0,0,0.18)',
          zIndex: 20,
        }}
        trigger={null}
      >
        {/* Brand */}
        <div
          style={{
            height: 56,
            display: 'flex',
            alignItems: 'center',
            justifyContent: collapsed ? 'center' : 'flex-start',
            padding: collapsed ? 0 : '0 10px',
            borderBottom: '1px solid rgba(255,255,255,0.07)',
            gap: 11,
            flexShrink: 0,
            cursor: 'pointer',
          }}
          onClick={() => guardedNavigate('/dashboard')}
        >
          <div style={{
            width: 32, height: 32, borderRadius: 8, flexShrink: 0,
            background: 'linear-gradient(135deg, #185FA5, #1677ff)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 2px 8px rgba(22,119,255,0.35)',
          }}>
            <span style={{ color: '#fff', fontSize: 15, fontWeight: 800 }}>S</span>
          </div>
          {!collapsed && (
            <span style={{ color: '#fff', fontWeight: 700, fontSize: 15, letterSpacing: '0.02em', whiteSpace: 'nowrap', overflow: 'hidden' }}>
              Spinrise ERP
            </span>
          )}
        </div>

        {/* Navigation menu */}
        <div className="spinrise-nav-scroll" style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', padding: '10px 0' }}>
          <ConfigProvider
            theme={{
              components: {
                Menu: {
                  darkItemBg: 'transparent',
                  darkSubMenuItemBg: 'transparent',
                  darkPopupBg: '#0f172a',
                  darkItemColor: 'rgba(255,255,255,0.68)',
                  darkItemHoverColor: '#ffffff',
                  darkItemHoverBg: 'rgba(255,255,255,0.06)',
                  darkItemSelectedBg: 'rgba(56,132,255,0.22)',
                  darkItemSelectedColor: '#ffffff',
                  itemHeight: 35,
                  itemMarginInline: 10,
                  itemMarginBlock: 4,
                  itemBorderRadius: 8,
                  iconSize: 16,
                  fontSize: 13,
                },
              },
            }}
          >
            <Menu
              className="spinrise-nav"
              mode="inline"
              theme="dark"
              inlineIndent={12}
              selectedKeys={selectedKeys}
              defaultOpenKeys={getOpenKeys(location.pathname)}
              items={NAV_ITEMS}
              style={{ background: 'transparent', borderRight: 'none' }}
              onClick={({ key }) => { if (key.startsWith('/')) guardedNavigate(key) }}
            />
          </ConfigProvider>
        </div>

      </Sider>

      {/* ── Main area ── */}
      <Layout style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0 }}>

        {/* Header */}
        <Header style={{
          height: 48, lineHeight: '48px',
          padding: '0 10px',
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
