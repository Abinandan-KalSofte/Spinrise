import { useEffect, useState } from 'react'
import { App as AntApp, Button, DatePicker, Form, Input, Select } from 'antd'
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
import type { ActiveDivisionDto, LoginDto } from '../types'

const COMPANIES = [{ value: 'KAL', label: 'Kalpatharu Software Ltd' }]

interface LoginFormValues extends LoginDto {
  processingDate: ReturnType<typeof dayjs>
  compCode: string
}

export default function LoginPage() {
  const { message } = AntApp.useApp()
  const [form] = Form.useForm<LoginFormValues>()
  const setAuthSession    = useAuthStore((s) => s.setAuthSession)
  const setProcessingDate = useAuthStore((s) => s.setProcessingDate)
  const navigate          = useNavigate()
  const { execute, loading } = useAsync(authService.login)

  const [divisions,   setDivisions]   = useState<ActiveDivisionDto[]>([])
  const [divsLoading, setDivsLoading] = useState(false)
  const [divsFailed,  setDivsFailed]  = useState(false)
  const [currentTime, setCurrentTime] = useState(dayjs())

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(dayjs()), 1000)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    setDivsLoading(true)
    authApi.getActiveDivisions()
      .then((divs) => { setDivisions(divs ?? []) })
      .catch(() => { setDivsFailed(true) })
      .finally(() => setDivsLoading(false))
  }, [])

  const onFinish = async (values: LoginFormValues) => {
    try {
      const procDate = values.processingDate.format('YYYY-MM-DD')
      const { processingDate: _pd, compCode: _cc, ...loginPayload } = values
      const session = await execute(loginPayload)
      setAuthSession(session)
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
            <div className="login-card__right">
              <div className="login-card__body">

                <div className="login-card__form-header">
                  <div className="login-card__form-title">Sign In</div>
                  <div className="login-card__form-sub">Purchase Requisition System</div>
                </div>

                <Form
                  form={form}
                  layout="vertical"
                  onFinish={onFinish}
                  initialValues={{ processingDate: dayjs(), compCode: 'KAL' }}
                  requiredMark={false}
                  className="login-form"
                >
                  {/* Company */}
                  <Form.Item
                    label="Company"
                    name="compCode"
                    rules={[{ required: true, message: 'Please select a company' }]}
                  >
                    <Select
                      options={COMPANIES}
                      suffixIcon={<ApartmentOutlined style={{ color: '#9ca3af' }} />}
                    />
                  </Form.Item>

                  {/* Division */}
                  <Form.Item
                    label="Division"
                    name="divCode"
                    rules={[{ required: true, message: 'Please select your division' }]}
                  >
                    {divsFailed ? (
                      <Input
                        prefix={<BankOutlined style={{ color: '#9ca3af' }} />}
                        placeholder="Enter division code"
                        maxLength={4}
                        style={{ textTransform: 'uppercase' }}
                      />
                    ) : (
                      <Select
                        showSearch
                        loading={divsLoading}
                        placeholder="Select division"
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
                    )}
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
