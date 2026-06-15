import { Drawer, Descriptions, Statistic, Tag, Divider, Image } from 'antd'
import { SectionLoader } from '@/components/common/loading'
import type { ItemDetail } from '../types'

interface Props {
  open:    boolean
  item:    ItemDetail | null
  loading: boolean
  onClose: () => void
}

export default function ItemDetailDrawer({ open, item, loading, onClose }: Props) {
  return (
    <Drawer
      title="Item Information"
      placement="right"
      width={340}
      open={open}
      onClose={onClose}
      styles={{ body: { padding: '16px 20px' } }}
    >
      {loading && <SectionLoader message="Loading item details…" />}
      {!loading && item && (
          <>
            {item.itemImage && (
              <div style={{ textAlign: 'center', marginBottom: 16 }}>
                <Image
                  src={`data:image/jpeg;base64,${item.itemImage}`}
                  alt={item.itemName}
                  width={160}
                  height={160}
                  style={{ objectFit: 'contain', borderRadius: 8, border: '1px solid #E2E2E2' }}
                  fallback="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAYAAABw4pVUAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4AgUDCQkOzlULgAAAUFJREFUeNrt2cEKgkAYROF7Vv//y3oqoiBKS3Zn3JN3zz8C4YIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                />
              </div>
            )}

            <Descriptions column={1} size="small" bordered>
              <Descriptions.Item label="Item Id">
                <code style={{ fontSize: 12, color: '#185FA5' }}>{item.itemCode}</code>
              </Descriptions.Item>
              <Descriptions.Item label="Item Name">{item.itemName}</Descriptions.Item>
              <Descriptions.Item label="UOM">
                <Tag>{item.uom}</Tag>
              </Descriptions.Item>
              <Descriptions.Item label="Min Order Qty">
                {item.minLevel > 0 ? item.minLevel.toFixed(3) : '—'}
              </Descriptions.Item>
            </Descriptions>

            <Divider style={{ margin: '16px 0' }}>Stock & Rates</Divider>

            <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
              <Statistic
                title="Current Stock"
                value={item.currentStock}
                precision={3}
                valueStyle={{ fontSize: 16 }}
              />
              {item.lpoRate != null && (
                <Statistic
                  title="Last PO Rate"
                  value={item.lpoRate}
                  precision={4}
                  prefix="₹"
                  valueStyle={{ fontSize: 16, color: '#185FA5' }}
                />
              )}
              {item.avgRate != null && (
                <Statistic
                  title="Avg Rate (FY)"
                  value={item.avgRate}
                  precision={4}
                  prefix="₹"
                  valueStyle={{ fontSize: 16, color: '#BA7517' }}
                />
              )}
            </div>

            {item.lpoDate && (
              <div style={{ marginTop: 12, fontSize: 12, color: '#888' }}>
                Last PO Date: {new Date(item.lpoDate).toLocaleDateString('en-IN')}
              </div>
            )}
          </>
      )}
    </Drawer>
  )
}
