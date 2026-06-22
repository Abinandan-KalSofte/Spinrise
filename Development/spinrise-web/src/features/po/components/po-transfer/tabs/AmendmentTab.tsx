import { Col, Row, Tag } from 'antd'
import dayjs from 'dayjs'
import { TabPanel, ReadOnlyField } from './_fieldKit'
import { formatPoNo } from '../../../types'
import type { PoHeader, AmdHistoryItem } from '../../../types'

// ── Amendment tab (HTML #htab-panel-amendment) ───────────────────────────────
// Read-only amendment history. PO amendment is raised on a separate screen.
//
// POT-AM-06: supports multiple amendment versions (A1, A2, A3 …).
//   - If the server populates amdHistory[], a full history table is shown.
//   - If only the legacy single-record fields (amdOrderNo / amdDate / …) are
//     present, they are displayed as a single "Amendment 1" row for backward
//     compatibility with older API responses.
//   - amdSeq on PoHeader indicates the CURRENT amendment sequence number for
//     the loaded PO (used by formatPoNo to render "PO-000123-A2").

interface AmendmentTabProps { currentPo: PoHeader | null }

const fmtD = (d: string | null | undefined) =>
  d ? dayjs(d).format('DD-MMM-YYYY') : '—'

// amdRefNo is stored as a string in legacy data but represents a PO number.
// Format it as PO-XXXXXX if numeric, otherwise display as-is.
const fmtRefNo = (v: string | null | undefined): string => {
  if (!v) return '—'
  const n = Number(v)
  return Number.isFinite(n) && n > 0 ? formatPoNo(n) : v
}

// Build a display-ready history list from whichever shape the server returns.
const buildHistory = (po: PoHeader): AmdHistoryItem[] => {
  if (po.amdHistory && po.amdHistory.length > 0) return po.amdHistory
  if (!po.amdOrderNo) return []
  // Fallback: single-record fields become amendment #1 (backward compat).
  return [{
    amdSeq:     po.amdSeq ?? 1,
    amdOrderNo: po.amdOrderNo,
    amdDate:    po.amdDate ?? '',
    amdRefNo:   po.amdRefNo ?? null,
    amdRefDate: po.amdRefDate ?? null,
    raisedBy:   '',
  }]
}

export function AmendmentTab({ currentPo }: AmendmentTabProps) {
  const history = currentPo ? buildHistory(currentPo) : []

  if (history.length === 0) {
    return (
      <TabPanel>
        <div style={{
          marginTop: 6, padding: '10px 12px', background: '#F5F5F3',
          border: '1px solid #e2e2e2', borderRadius: 6,
          fontSize: 11, color: '#888', fontStyle: 'italic',
        }}>
          No amendments raised. Amendment history will appear here once an amendment is created.
        </div>
      </TabPanel>
    )
  }

  return (
    <TabPanel>
      {/* Current amendment quick-view (latest entry) */}
      {history.length === 1 && (
        <Row gutter={[12, 8]}>
          <Col span={6}>
            <ReadOnlyField
              label="AMD No."
              value={formatPoNo(history[0].amdOrderNo)}
              mono
            />
          </Col>
          <Col span={3}>
            <div style={seqLbl}>Seq</div>
            <Tag color="blue" style={{ fontWeight: 700 }}>
              A{history[0].amdSeq}
            </Tag>
          </Col>
          <Col span={6}><ReadOnlyField label="AMD Date" value={fmtD(history[0].amdDate)} /></Col>
          <Col span={6}><ReadOnlyField label="Ref. Order No." value={fmtRefNo(history[0].amdRefNo)} mono /></Col>
          <Col span={3}><ReadOnlyField label="Ref. Date" value={fmtD(history[0].amdRefDate)} /></Col>
        </Row>
      )}

      {/* Full history table when server returns multiple amendments */}
      {history.length > 1 && (
        <div style={{ overflowX: 'auto' }}>
          <table style={{ borderCollapse: 'collapse', width: '100%', fontSize: 12 }}>
            <thead>
              <tr>
                {['Seq', 'AMD PO No.', 'AMD Date', 'Ref. PO No.', 'Ref. Date', 'Raised By'].map((h) => (
                  <th key={h} style={thStyle}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {history.map((row) => (
                <tr key={row.amdSeq} style={{ background: row.amdSeq % 2 === 0 ? '#fafafa' : '#fff' }}>
                  <td style={tdStyle}>
                    <Tag color="blue" style={{ fontWeight: 700, fontSize: 11 }}>A{row.amdSeq}</Tag>
                  </td>
                  <td style={{ ...tdStyle, fontFamily: 'monospace', fontWeight: 600, color: '#185FA5' }}>
                    {formatPoNo(row.amdOrderNo, row.amdSeq)}
                  </td>
                  <td style={tdStyle}>{fmtD(row.amdDate)}</td>
                  <td style={{ ...tdStyle, fontFamily: 'monospace' }}>
                    {fmtRefNo(row.amdRefNo)}
                  </td>
                  <td style={tdStyle}>{fmtD(row.amdRefDate)}</td>
                  <td style={tdStyle}>{row.raisedBy || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </TabPanel>
  )
}

const seqLbl: React.CSSProperties = { fontSize: 10, fontWeight: 600, color: '#475569', marginBottom: 3 }
const thStyle: React.CSSProperties = {
  padding: '5px 10px', textAlign: 'left', fontSize: 10, fontWeight: 700,
  color: '#383838', background: '#f5f5f5', borderBottom: '1px solid #e0e0e0',
  textTransform: 'uppercase', letterSpacing: '0.04em',
}
const tdStyle: React.CSSProperties = {
  padding: '5px 10px', borderBottom: '1px solid #f0f0f0', fontSize: 12,
}
