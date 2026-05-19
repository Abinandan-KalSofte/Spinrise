import { PR_STATUS_BADGE } from '../types'

interface Props {
  status: string
}

export default function PrStatusBadge({ status }: Props) {
  const style = PR_STATUS_BADGE[status] ?? { color: '#4A4A4A', bg: '#F5F5F3' }
  return (
    <span
      style={{
        display:       'inline-flex',
        alignItems:    'center',
        padding:       '2px 10px',
        borderRadius:  9999,
        fontSize:      11,
        fontWeight:    600,
        letterSpacing: '0.04em',
        color:         style.color,
        background:    style.bg,
        whiteSpace:    'nowrap',
      }}
    >
      {status}
    </span>
  )
}
