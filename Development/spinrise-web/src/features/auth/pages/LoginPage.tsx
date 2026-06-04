import { useCallback, useEffect, useState } from 'react'
import { App as AntApp, Button, DatePicker, Form, Input, Select, Spin } from 'antd'
import {
  ApartmentOutlined,
  BankOutlined,
  CalendarOutlined,
  LockOutlined,
  UserOutlined,
} from '@ant-design/icons'
import dayjs from 'dayjs'
import { useNavigate } from 'react-router-dom'
import { useAsync } from '@/shared/hooks/useAsync'
import { getErrorMessage } from '@/shared/lib/errorHandler'
import { authApi } from '../api/authApi'
import { authService } from '../services/authService'
import { useAuthStore } from '../store/useAuthStore'
import type { ActiveCompanyDto, ActiveDivisionDto, LoginDto } from '../types'

const LAST_DB_KEY = 'spinrise_last_db'

interface LoginFormValues extends LoginDto {
  processingDate: ReturnType<typeof dayjs>
}

export default function LoginPage() {
  const { message } = AntApp.useApp()
  const [form] = Form.useForm<LoginFormValues>()
  const setAuthSession    = useAuthStore((s) => s.setAuthSession)
  const setProcessingDate = useAuthStore((s) => s.setProcessingDate)
  const navigate          = useNavigate()
  const { execute, loading } = useAsync(authService.login)

  const [databases,    setDatabases]   = useState<string[]>([])
  const [dbsLoading,   setDbsLoading]  = useState(true)
  const [companies,    setCompanies]   = useState<ActiveCompanyDto[]>([])
  const [divisions,    setDivisions]   = useState<ActiveDivisionDto[]>([])
  const [divsLoading,  setDivsLoading] = useState(false)
  const [dbErrorMsg,   setDbErrorMsg]  = useState<string | null>(null)
  const [backendError, setBackendError] = useState(false)
  const [currentTime,  setCurrentTime] = useState(dayjs())

  const dataReady = !dbsLoading && !backendError

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(dayjs()), 1000)
    return () => clearInterval(timer)
  }, [])

  const loadDivisions = useCallback(async (dbName: string) => {
    setDivsLoading(true)
    setDivisions([])
    form.setFieldValue('divCode', undefined)
    try {
      const divs = await authApi.getActiveDivisions(dbName)
      setDivisions(divs ?? [])
      if (divs && divs.length > 0) {
        form.setFieldValue('divCode', divs[0].divCode)
      }
    } catch {
      setDbErrorMsg('Database not recognised — unable to load Spinrise configuration.')
    } finally {
      setDivsLoading(false)
    }
  }, [form])

  const loadCompanyName = useCallback(async (dbName: string) => {
    try {
      const comps = await authApi.getActiveCompanies(dbName)
      setCompanies(comps ?? [])
    } catch {
      setCompanies([])
    }
  }, [])

  const loadInitialData = useCallback(async () => {
    setBackendError(false)
    setDbsLoading(true)
    try {
      const dbs = await authApi.getDatabases()
      setDatabases(dbs ?? [])

      const lastDb = localStorage.getItem(LAST_DB_KEY)
      const toSelect = lastDb && (dbs ?? []).includes(lastDb) ? lastDb : null
      if (toSelect) {
        form.setFieldValue('dbName', toSelect)
        await Promise.all([loadDivisions(toSelect), loadCompanyName(toSelect)])
      }
    } catch {
      setBackendError(true)
    } finally {
      setDbsLoading(false)
    }
  }, [form, loadDivisions, loadCompanyName])

  useEffect(() => {
    void loadInitialData()
  }, [loadInitialData])

  const onDbChange = (dbName: string) => {
    setDbErrorMsg(null)
    localStorage.setItem(LAST_DB_KEY, dbName)
    setCompanies([])
    void Promise.all([loadDivisions(dbName), loadCompanyName(dbName)])
  }

  const onFinish = async (values: LoginFormValues) => {
    try {
      const procDate = values.processingDate.format('YYYY-MM-DD')
      const { processingDate: _pd, ...loginPayload } = values
      const session = await execute(loginPayload)

      localStorage.setItem(LAST_DB_KEY, values.dbName)

      const compName = companies[0]?.compName ?? values.dbName

      setAuthSession({
        user:   { ...session.user, compCode: values.dbName, compName, dbName: values.dbName },
        tokens: session.tokens,
      })
      setProcessingDate(procDate)
      void message.success(`Welcome, ${session.user.userName} — ${session.user.divName || session.user.divCode}`)
      navigate('/dashboard', { replace: true })
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  return (
    <div className="login-root">
      <div className="login-canvas">

        {/* Header */}
        <header className="login-header">
          <div className="login-header__brand">
            <img src="/kalsofte-logo.png" alt="Kalsofte" className="login-header__logo" />
            <div className="login-header__brand-text">
              <span className="login-header__brand-name">SpinRise</span>
              <span className="login-header__brand-sub">ERP Platform</span>
            </div>
          </div>
          <div className="login-header__datetime">
            {currentTime.format('DD MMM YYYY  |  hh:mm:ss A')}
          </div>
        </header>

        {/* Stage */}
        <main className="login-stage">
          <div className="login-card">

            {/* Left panel */}
            <div className="login-card__left">
              <div className="login-card__left-deco" aria-hidden="true" />
              <div className="login-card__left-orbs" aria-hidden="true">
                <span className="login-card__left-orb login-card__left-orb--1" />
                <span className="login-card__left-orb login-card__left-orb--2" />
                <span className="login-card__left-orb login-card__left-orb--3" />
              </div>
              <div className="login-card__left-content">
                <div className="login-card__left-logo-wrap">
                  <img src="/kalsofte-logo.png" alt="Kalpatharu Software Ltd" className="login-card__left-logo" />
                </div>
                <div className="login-card__left-divider" />
                <h2 className="login-card__left-company">Kalpatharu Software Ltd</h2>
                <p className="login-card__left-tagline">Enterprise Resource Planning</p>
                <div className="login-card__left-status">
                  <span className="login-card__left-status-dot" />
                  <span className="login-card__left-status-text">Licensed Portal</span>
                </div>
              </div>
              <div className="login-card__left-foot">
                <span className="login-card__left-ver">SpinRise ERP v2.0</span>
              </div>
            </div>

            {/* Right panel */}
            <div className="login-card__right" style={{ position: 'relative' }}>

              {/* ── Overlay: loading or backend error ────────────────── */}
              {(dbsLoading || backendError) && (
                <div style={{
                  position: 'absolute', inset: 0, zIndex: 10,
                  display: 'flex', flexDirection: 'column',
                  alignItems: 'center', justifyContent: 'center',
                  background: 'rgba(255,255,255,0.94)',
                  borderRadius: '0 16px 16px 0',
                  gap: 16, padding: '32px 40px', textAlign: 'center',
                }}>
                  <style>{`
                    @keyframes loginPulse { 0%,100%{opacity:1} 50%{opacity:0.35} }
                  `}</style>

                  {backendError ? (
                    /* ── Backend not reachable ── */
                    <>
                      <div style={{ fontSize: 40, lineHeight: 1 }}>⚠️</div>
                      <div style={{ fontSize: 15, fontWeight: 700, color: '#b91c1c' }}>
                        Cannot Connect to Server
                      </div>
                      <div style={{ fontSize: 12, color: '#64748b', maxWidth: 260, lineHeight: 1.6 }}>
                        SPINRISE ERP server is not reachable.<br />
                        Please check your network connection or contact your system administrator.
                      </div>
                      <div style={{
                        fontSize: 11, color: '#94a3b8', fontFamily: 'monospace',
                        background: '#f8fafc', border: '1px solid #e2e8f0',
                        borderRadius: 6, padding: '4px 12px',
                      }}>
                        http://172.16.16.40:5001
                      </div>
                      <Button
                        type="primary"
                        onClick={() => void loadInitialData()}
                        style={{ marginTop: 4 }}
                      >
                        Retry Connection
                      </Button>
                    </>
                  ) : (
                    /* ── Initial data loading ── */
                    <>
                      <Spin size="large" />
                      <span style={{
                        fontSize: 13, color: '#64748b', letterSpacing: '0.02em',
                        animation: 'loginPulse 1.6s ease-in-out infinite',
                      }}>
                        Connecting to SPINRISE ERP…
                      </span>
                    </>
                  )}
                </div>
              )}

              <div className="login-card__body" style={{
                opacity: dataReady ? 1 : 0,
                transition: 'opacity 0.3s ease',
                pointerEvents: dataReady ? 'auto' : 'none',
              }}>

                <div className="login-card__form-header">
                  <div className="login-card__form-title">Sign In</div>
                  <div className="login-card__form-sub">Purchase Requisition System</div>
                </div>

                <Form
                  form={form}
                  layout="vertical"
                  onFinish={onFinish}
                  initialValues={{ processingDate: dayjs() }}
                  requiredMark={false}
                  className="login-form"
                >
                  {/* Company */}
                  <Form.Item
                    label="Company"
                    name="dbName"
                    rules={[{ required: true, message: 'Please select a company' }]}
                    validateStatus={dbErrorMsg ? 'error' : undefined}
                    help={dbErrorMsg ?? undefined}
                  >
                    <Select
                      showSearch
                      loading={dbsLoading}
                      placeholder="Select company"
                      optionFilterProp="label"
                      suffixIcon={<ApartmentOutlined style={{ color: '#9ca3af' }} />}
                      options={databases.map((db) => ({ value: db, label: db }))}
                      filterOption={(input, option) =>
                        (option?.label ?? '').toLowerCase().includes(input.toLowerCase())
                      }
                      onChange={onDbChange}
                    />
                  </Form.Item>

                  {/* Division */}
                  <Form.Item
                    label="Division"
                    name="divCode"
                    rules={[{ required: true, message: 'Please select your division' }]}
                  >
                    <Select
                      showSearch
                      loading={divsLoading}
                      placeholder="Select Division"
                      disabled={divisions.length === 0 && !divsLoading}
                      optionFilterProp="label"
                      suffixIcon={<BankOutlined style={{ color: '#9ca3af' }} />}
                      options={divisions.map((d) => ({
                        value: d.divCode,
                        label: `${d.divCode} – ${d.divName}`,
                      }))}
                      filterOption={(input, option) =>
                        (option?.label ?? '').toLowerCase().includes(input.toLowerCase())
                      }
                    />
                  </Form.Item>

                  <div className="login-form-divider"><span>Credentials</span></div>

                  {/* User ID */}
                  <Form.Item
                    label="User ID"
                    name="userName"
                    rules={[{ required: true, message: 'Please enter your User ID' }]}
                  >
                    <Input
                      prefix={<UserOutlined style={{ color: '#9ca3af' }} />}
                      placeholder="Enter your User ID"
                      maxLength={100}
                      autoComplete="username"
                    />
                  </Form.Item>

                  {/* Password */}
                  <Form.Item
                    label="Password"
                    name="password"
                    rules={[{ required: true, message: 'Please enter your password' }]}
                  >
                    <Input.Password
                      prefix={<LockOutlined style={{ color: '#9ca3af' }} />}
                      placeholder="Enter your password"
                      autoComplete="current-password"
                    />
                  </Form.Item>

                  {/* Date + Live clock */}
                  <div className="login-form__date-time-row">
                    <Form.Item
                      label="Transaction Date"
                      name="processingDate"
                      rules={[{ required: true, message: 'Please select a date' }]}
                      className="login-form__date-item"
                    >
                      <DatePicker
                        style={{ width: '100%' }}
                        format="DD-MMM-YYYY"
                        suffixIcon={<CalendarOutlined style={{ color: '#9ca3af' }} />}
                        disabledDate={(d) => d.isAfter(dayjs(), 'day')}
                        allowClear={false}
                      />
                    </Form.Item>

                    <div
                      className="login-form__time-chip"
                      aria-label={`Current time ${currentTime.format('hh:mm:ss A')}`}
                    >
                      <span className="login-form__time-dot" />
                      <div className="login-form__time-copy">
                        <span className="login-form__time-label">Live Time</span>
                        <span className="login-form__time-value">
                          {currentTime.format('hh:mm:ss A')}
                        </span>
                      </div>
                    </div>
                  </div>

                  <Form.Item style={{ marginBottom: 0, marginTop: 8 }}>
                    <Button
                      type="primary"
                      htmlType="submit"
                      loading={loading}
                      block
                      className="login-submit-btn"
                    >
                      Log In
                    </Button>
                  </Form.Item>
                </Form>

              </div>

              <div className="login-card__footer-note">
                © {new Date().getFullYear()} Kalpatharu Software Ltd. All rights reserved.
              </div>
            </div>

          </div>
        </main>

      </div>
    </div>
  )
}
