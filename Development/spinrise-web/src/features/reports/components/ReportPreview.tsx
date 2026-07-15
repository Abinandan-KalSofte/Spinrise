import { BarChartOutlined, FilePdfOutlined, LoadingOutlined } from '@ant-design/icons'
import { Spin, Tag } from 'antd'
import dayjs from 'dayjs'
import type { ReportConfig } from '../configs/reportConfigs'
import type { ReportFilter } from '../types/reportTypes'

const BG_COLOR = '#FAFBFD'
const CARD_BG = '#fff'
const BORDER_COLOR = '#E2E8F0'

const typeColor: Record<string, string> = {
  Datewise: 'blue',
  Departmentwise: 'purple',
  Itemwise: 'gold',
  Supplierwise: 'cyan',
}

interface Props {
  config: ReportConfig | null
  filter: ReportFilter | null
  generating: boolean
}

export function ReportPreview({ config, filter, generating }: Props) {
  if (!config || !filter) return null

  return (
    <div style={{
      flex: 1,
      background: CARD_BG,
      border: `1px solid ${BORDER_COLOR}`,
      borderRadius: 10,
      overflow: 'hidden',
      display: 'flex',
      flexDirection: 'column',
    }}>
      {/* Header */}
      <div style={{
        padding: '9px 16px',
        borderBottom: `1px solid ${BORDER_COLOR}`,
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        background: BG_COLOR,
        flexShrink: 0,
      }}>
        <BarChartOutlined style={{ color: '#185FA5', fontSize: 13 }} />
        <span style={{ fontSize: 12, fontWeight: 600, color: '#2D3748' }}>Report Preview</span>
        <div style={{ flex: 1 }} />
        <Tag color={typeColor[filter.reportType] ?? 'blue'} style={{ fontSize: 10, margin: 0, lineHeight: '18px' }}>
          {filter.reportType}
        </Tag>
        {filter.fromDate && filter.toDate && (
          <Tag color="default" style={{ fontSize: 10, margin: 0, lineHeight: '18px' }}>
            {dayjs(filter.fromDate).format('DD MMM YY')} – {dayjs(filter.toDate).format('DD MMM YY')}
          </Tag>
        )}
      </div>

      {/* Body */}
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 40,
      }}>
        {generating ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
            <div style={{
              width: 72,
              height: 72,
              borderRadius: 16,
              background: 'linear-gradient(135deg, #C53030 0%, #E53E3E 100%)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 4px 20px rgba(197,48,48,0.3)',
            }}>
              <Spin
                indicator={<LoadingOutlined style={{ fontSize: 32, color: '#fff' }} />}
                size="large"
              />
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 15, fontWeight: 700, color: '#1A202C', marginBottom: 6 }}>
                Generating Report
              </div>
              <div style={{ fontSize: 12, color: '#718096', lineHeight: 1.8 }}>
                Building your {filter.reportType} {config.subtitle} report from the database.
                <br />
                The preview will open automatically when ready.
              </div>
            </div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, maxWidth: 440, textAlign: 'center' }}>
            <div style={{
              width: 72,
              height: 72,
              borderRadius: 16,
              background: 'linear-gradient(135deg, #C53030 0%, #E53E3E 100%)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 4px 20px rgba(197,48,48,0.2)',
            }}>
              <FilePdfOutlined style={{ fontSize: 34, color: '#fff' }} />
            </div>

            <div>
              <div style={{ fontSize: 16, fontWeight: 700, color: '#1A202C', marginBottom: 8 }}>
                Ready to Generate
              </div>
              <div style={{ fontSize: 12, color: '#718096', lineHeight: 1.9 }}>
                {config.hints[filter.reportType]}
              </div>
            </div>

            <div style={{ width: 48, height: 2, background: '#E2E8F0', borderRadius: 1 }} />

            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '8px 16px',
              background: '#FFF5F5',
              border: '1px solid #FED7D7',
              borderRadius: 8,
            }}>
              <FilePdfOutlined style={{ color: '#C53030', fontSize: 13 }} />
              <span style={{ fontSize: 11, color: '#C53030', fontWeight: 600 }}>
                {config.title} (.pdf) · A4 · Landscape
              </span>
            </div>

            <div style={{ fontSize: 11, color: '#A0AEC0', marginTop: -4 }}>
              Press{' '}
              <kbd style={{
                display: 'inline-block',
                padding: '1px 5px',
                background: '#EDF2F7',
                border: '1px solid #CBD5E0',
                borderRadius: 4,
                fontFamily: 'monospace',
                fontSize: 10,
                color: '#4A5568',
              }}>
                Alt+R
              </kbd>
              {' '}to generate instantly
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
