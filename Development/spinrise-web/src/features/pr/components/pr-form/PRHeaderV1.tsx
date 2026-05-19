import { Col, DatePicker, Form, Input, Row, Select, Tag } from 'antd'
import { CalendarOutlined } from '@ant-design/icons'
import type { FormInstance } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import { prefixFilterOption, priorityFilterSort } from '@/shared/utils/selectUtils'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import type { DepartmentOption, EmployeeOption, PrTypeOption } from '../../types'

// ── Design tokens ──────────────────────────────────────────────────────────────
const ACCENT = '#185FA5'
const LABEL: React.CSSProperties = { fontSize: 11, fontWeight: 600, color: '#475569', letterSpacing: '0.01em' }
const ITEM: React.CSSProperties  = { marginBottom: 0 }
const VIEW_VALUE: React.CSSProperties = { fontSize: 12, color: '#1e293b', fontWeight: 500, lineHeight: 1.4 }

export interface PRHeaderFormValues {
  prDate:  Dayjs
  depCode: string
  section: string
  iType:   string
  reqName: string
  refNo:   string
  poGrp:   string
}

function Lbl({ text, required }: { text: string; required?: boolean }) {
  return (
    <span style={LABEL}>
      {text}
      {required && <span style={{ color: '#ef4444', marginLeft: 2 }}>*</span>}
    </span>
  )
}

function ViewField({ label, value, required }: { label: string; value?: string | null; required?: boolean }) {
  return (
    <div style={{ marginBottom: 6 }}>
      <Lbl text={label} required={required} />
      <div style={VIEW_VALUE}>{value || '—'}</div>
    </div>
  )
}

interface PRHeaderV1Props {
  form:          FormInstance<PRHeaderFormValues>
  departments:   DepartmentOption[]
  employees:     EmployeeOption[]
  prTypes:       PrTypeOption[]
  savedPrNo?:    number | null
  disabled?:     boolean
  createdBy?:    string | null
  onValuesChange?: () => void
}

export function PRHeaderV1({
  form, departments, employees, prTypes,
  savedPrNo = null, disabled = false,
  createdBy = null, onValuesChange,
}: PRHeaderV1Props) {
  const processingDate = useAuthStore((s) => s.processingDate)
  const procDay        = processingDate ? dayjs(processingDate) : dayjs()

  const prDate  = form.getFieldValue('prDate')
  const depCode = form.getFieldValue('depCode')
  const section = form.getFieldValue('section')
  const reqName = form.getFieldValue('reqName')
  const iType   = form.getFieldValue('iType')
  const refNo   = form.getFieldValue('refNo')

  const deptName  = departments.find((d) => d.depCode === depCode)?.depName
  const empName   = employees.find((e) => e.empNo === reqName)?.empName
  const typeLabel = prTypes.find((t) => t.iType === iType)?.iDesc ?? iType

  const deptOpts = departments.map((d) => ({ value: d.depCode, label: `${d.depCode} – ${d.depName}` }))
  const empOpts  = employees.map((e) => ({ value: e.empNo, label: `${e.empNo} – ${e.empName}` }))
  const typeOpts = prTypes.map((t) => ({ value: t.iType, label: t.iDesc }))

  return (
    <div style={{ background: '#fff', borderBottom: '1px solid #e2e2e2', padding: '8px 18px 10px' }}>
      {/* Meta row */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 10, fontWeight: 700, color: ACCENT, letterSpacing: '0.06em' }}>
            Requisition Details
          </span>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            background: 'linear-gradient(135deg,#eff6ff,#dbeafe)',
            border: '1px solid #bfdbfe', borderRadius: 20, padding: '1px 8px',
          }}>
            <CalendarOutlined style={{ color: ACCENT, fontSize: 10 }} />
            <span style={{ fontSize: 10, fontWeight: 700, color: '#1e40af' }}>
              {procDay.format('DD MMM YYYY')}
            </span>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {createdBy && (
            <span style={{ fontSize: 11, color: '#94A3B8' }}>
              Created by <strong style={{ color: '#475569' }}>{createdBy}</strong>
            </span>
          )}
          {savedPrNo && (
            <Tag color="blue" style={{ fontSize: 12, fontWeight: 700, fontFamily: 'monospace', marginRight: 0, padding: '1px 10px' }}>
              PR-{String(savedPrNo).padStart(5, '0')}
            </Tag>
          )}
        </div>
      </div>

      {disabled ? (
        // View mode
        <div style={{ paddingBottom: 6 }}>
          <Row gutter={[10, 6]}>
            <Col xs={24} sm={12} md={3}>
              <ViewField label="PR Date" value={prDate?.format('DD-MMM-YYYY')} required />
            </Col>
            <Col xs={24} sm={12} md={5}>
              <ViewField label="Department" value={depCode ? `${depCode} – ${deptName ?? ''}` : undefined} required />
            </Col>
            <Col xs={24} sm={12} md={4}>
              <ViewField label="Section" value={section} />
            </Col>
            <Col xs={24} sm={12} md={5}>
              <ViewField label="Requested By" value={reqName ? `${reqName} – ${empName ?? ''}` : undefined} />
            </Col>
            <Col xs={24} sm={12} md={4}>
              <div style={{ marginBottom: 6 }}>
                <Lbl text="Requisition Type" required />
                <div style={VIEW_VALUE}>
                  {iType === 'E' ? (
                    <Tag color="error" style={{ margin: 0, fontWeight: 700, fontSize: 11 }}>{typeLabel}</Tag>
                  ) : iType === 'U' ? (
                    <Tag color="warning" style={{ margin: 0, fontWeight: 700, fontSize: 11 }}>{typeLabel}</Tag>
                  ) : (
                    typeLabel || '—'
                  )}
                </div>
              </div>
            </Col>
            <Col xs={24} sm={12} md={3}>
              <ViewField label="Reference No." value={refNo} />
            </Col>
          </Row>
        </div>
      ) : (
        // Edit mode
        <Form
          form={form}
          layout="vertical"
          initialValues={{ prDate: procDay }}
          disabled={disabled}
          size="small"
          onValuesChange={onValuesChange}
        >
          <Row gutter={[10, 4]}>
            <Col xs={24} sm={12} md={3}>
              <Form.Item name="prDate" label={<Lbl text="PR Date" required />}
                rules={[{ required: true, message: 'Required' }]} style={ITEM}>
                <DatePicker format="DD-MMM-YYYY" style={{ width: '100%' }} allowClear={false}
                  disabledDate={(d) => d.isAfter(dayjs(), 'day')} />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12} md={5}>
              <Form.Item name="depCode" label={<Lbl text="Department" required />}
                rules={[{ required: true, message: 'Required' }]} style={ITEM}>
                <Select showSearch placeholder="Select department…" options={deptOpts}
                  filterOption={prefixFilterOption} filterSort={priorityFilterSort} allowClear />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12} md={4}>
              <Form.Item name="section" label={<Lbl text="Section" />} style={ITEM}>
                <Input placeholder="e.g. Ring Frame" maxLength={20} />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12} md={5}>
              <Form.Item name="reqName" label={<Lbl text="Requested By" />} style={ITEM}>
                <Select showSearch placeholder="Select employee…" options={empOpts}
                  filterOption={prefixFilterOption} filterSort={priorityFilterSort} allowClear />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12} md={4}>
              <Form.Item name="iType" label={<Lbl text="Requisition Type" required />}
                rules={[{ required: true, message: 'Required' }]} style={ITEM}>
                <Select placeholder="Select type…" options={typeOpts} allowClear />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12} md={3}>
              <Form.Item name="refNo" label={<Lbl text="Reference No." />} style={ITEM}>
                <Input placeholder="REF-…" maxLength={20}
                  onChange={(e) => form.setFieldValue('refNo', e.target.value.toUpperCase())}
                  style={{ textTransform: 'uppercase' }} />
              </Form.Item>
            </Col>
          </Row>
        </Form>
      )}

      {!disabled && (
        <div style={{ marginTop: 5, display: 'flex', gap: 12 }}>
          {['Tab — move between fields', 'Ctrl+S — save', 'Enter — open item picker'].map((hint) => (
            <span key={hint} style={{ fontSize: 10, color: '#94a3b8' }}>{hint}</span>
          ))}
        </div>
      )}
    </div>
  )
}
