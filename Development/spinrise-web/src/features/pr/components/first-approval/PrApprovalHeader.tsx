import { DatePicker, Row, Col, Tag } from 'antd'
import { CalendarOutlined } from '@ant-design/icons'
import type { PoParaApproval, PrApprovalHeader as HeaderDto } from '../../types/prFirstApprovalTypes'
import type { ApprovalScreenMode } from '../../types/prFirstApprovalTypes'
import dayjs from 'dayjs'

// ── Design tokens ─────────────────────────────────────────────────────────────
const ACCENT = '#185FA5'

const LABEL: React.CSSProperties = {
  fontSize: 10, fontWeight: 600, color: '#94a3b8',
  textTransform: 'uppercase', letterSpacing: '0.05em',
  display: 'block', marginBottom: 2,
}

const VALUE: React.CSSProperties = {
  fontSize: 12, fontWeight: 500, color: '#1e293b', lineHeight: 1.4,
}

const MONO_VALUE: React.CSSProperties = {
  ...VALUE, fontFamily: 'monospace',
}

// ── View field (label + plain text — no borders) ──────────────────────────────
function VF({
  label, value, mono = false, empty = '—',
}: {
  label: string
  value?: string | null
  mono?: boolean
  empty?: string
}) {
  return (
    <div>
      <span style={LABEL}>{label}</span>
      <span style={mono ? MONO_VALUE : VALUE}>{value || empty}</span>
    </div>
  )
}

interface Props {
  header:          HeaderDto | null
  poPara:          PoParaApproval | null
  mode:            ApprovalScreenMode
  appDate:         string
  onAppDateChange: (v: string) => void
}

export default function PrApprovalHeader({
  header, poPara, mode, appDate,
}: Props) {
  const isEditable = mode === 'APPROVE'

  const swStyle = (active: boolean): React.CSSProperties => ({
    display: 'inline-flex', alignItems: 'center', gap: 5,
    padding: '2px 10px', borderRadius: 20,
    fontSize: 11, fontWeight: 700,
    background: active ? '#EAF3DE' : '#f0f0f0',
    color:      active ? '#3B6D11' : '#888',
    border:     `1px solid ${active ? '#b6d98a' : '#d9d9d9'}`,
  })

  return (
    <div style={{ background: '#fff', borderBottom: '1px solid #e2e2e2', flexShrink: 0 }}>

      {/* ── Section header ─────────────────────────────────────────────────── */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '7px 18px', borderBottom: '1px solid #f0f0f0',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 10, fontWeight: 700, color: ACCENT, letterSpacing: '0.06em' }}>
            Approval Details
          </span>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            background: 'linear-gradient(135deg,#eff6ff,#dbeafe)',
            border: '1px solid #bfdbfe', borderRadius: 20, padding: '1px 8px',
          }}>
            <CalendarOutlined style={{ color: ACCENT, fontSize: 10 }} />
            <span style={{ fontSize: 10, fontWeight: 700, color: '#1e40af' }}>
              {dayjs().format('DD MMM YYYY')}
            </span>
          </div>
        </div>

        {/* Approval level badges — labels from PoParaDto.AppUserLabel1/2/3 (FSD BR) */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={swStyle(!!header?.app1)}>
            {poPara?.appUserLabel1 ?? 'SM'}{header?.app1 ? ' ✓' : ''}
          </span>
          <span style={{ width: 1, height: 14, background: '#e2e2e2', display: 'inline-block' }} />
          <span style={swStyle(!!header?.app2)}>
            {poPara?.appUserLabel2 ?? 'FM'}{header?.app2 ? ' ✓' : ''}
          </span>
          <span style={{ width: 1, height: 14, background: '#e2e2e2', display: 'inline-block' }} />
          <span style={swStyle(!!header?.app3)}>
            {poPara?.appUserLabel3 ?? 'GM'}{header?.app3 ? ' ✓' : ''}
          </span>
        </div>
      </div>

      {/* ── Field rows ─────────────────────────────────────────────────────── */}
      <div style={{ padding: '10px 18px 12px', display: 'flex', flexDirection: 'column', gap: 10 }}>

        {/* Row 1 — identifiers */}
        <Row gutter={24} align="bottom">
          <Col flex="none">
            <span style={LABEL}>PR No.</span>
            {header?.prNo
              ? <Tag color="blue" style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 12, margin: 0, padding: '1px 10px' }}>
                  {header.prNo}
                </Tag>
              : <span style={{ ...VALUE, color: '#94a3b8' }}>—</span>
            }
          </Col>
          <Col flex="none">
            <VF label="PR Date" value={header?.prDate ? dayjs(header.prDate).format('DD-MMM-YYYY') : null} mono />
          </Col>
          <Col flex="none">
            <span style={LABEL}>
              Approve Date <span style={{ color: '#ef4444' }}>*</span>
            </span>
            {isEditable ? (
              <DatePicker
                size="small"
                value={appDate ? dayjs(appDate) : null}
                format="DD-MMM-YYYY"
                disabled
                style={{ width: 148 }}
              />
            ) : (
              <span style={MONO_VALUE}>
                {header?.app1Date ? dayjs(header.app1Date).format('DD-MMM-YYYY') : '—'}
              </span>
            )}
          </Col>
        </Row>

        {/* Divider */}
        <div style={{ height: 1, background: '#f0f0f0' }} />

        {/* Row 2 — department */}
        <Row gutter={24}>
          <Col flex="80px">
            <VF label="Dept Id" value={header?.depCode} mono />
          </Col>
          <Col flex="220px">
            <VF label="Department Name" value={header?.depName} />
          </Col>
          <Col flex="140px">
            <VF label="Reference No." value={header?.refNo} />
          </Col>
          <Col flex="140px">
            <VF label="Section" value={header?.section} />
          </Col>
          <Col flex="1" />
        </Row>

        {/* Row 3 — cost centre + requester */}
        <Row gutter={24}>
          <Col flex="80px">
            <VF label="SCC Id" value={header?.subCost} mono />
          </Col>
          <Col flex="220px">
            <VF label="Sub Cost Centre Name" value={header?.sccName} />
          </Col>
          <Col flex="200px">
            <VF label="Requester Name" value={header?.reqName} />
          </Col>
          <Col flex="1" />
        </Row>

      </div>
    </div>
  )
}
