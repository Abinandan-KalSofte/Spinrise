import { useCallback, useState } from 'react'
import { App } from 'antd'
import { notifyError, notifySuccess } from '@/shared/lib/notificationHelper'
import { useAuthStore } from '@/features/auth/store/useAuthStore'
import { getFYBounds } from '@/shared/lib/dateUtils'
import * as api from '../api/prForeclosureApi'
import type { PrForeclosureLineDto, PrForeclosureLineKey } from '../types'

const rowKey = (line: PrForeclosureLineDto) => `${line.prNo}-${line.prDate}-${line.itemCode}-${line.depCode}-${line.sccCode}`

export function usePrForeclosure() {
  const { modal } = App.useApp()

  const processingDate = useAuthStore((s) => s.processingDate)
  const { yfDate, ylDate } = getFYBounds(processingDate ? new Date(processingDate) : undefined)

  const [lines,      setLines]      = useState<PrForeclosureLineDto[]>([])
  const [selected,   setSelected]   = useState<Map<string, PrForeclosureLineKey>>(new Map())
  const [prNoFilter, setPrNoFilter] = useState('')
  const [loading,    setLoading]    = useState(false)
  const [hasLoaded,  setHasLoaded]  = useState(false)

  const load = useCallback(async (filter?: string) => {
    setLoading(true)
    try {
      const data = await api.getOpenLines(yfDate, ylDate, filter ?? undefined)
      setLines(data)
      setSelected(new Map())
      setHasLoaded(true)
    } catch {
      notifyError('Failed to load open PR lines.')
    } finally {
      setLoading(false)
    }
  }, [yfDate, ylDate])

  const reset = useCallback(() => {
    setLines([])
    setSelected(new Map())
    setPrNoFilter('')
    setHasLoaded(false)
  }, [])

  const toggleRow = (line: PrForeclosureLineDto, checked: boolean) => {
    setSelected(prev => {
      const next = new Map(prev)
      const key  = rowKey(line)
      if (checked) {
        next.set(key, {
          prNo:     line.prNo,
          prDate:   line.prDate,
          prSno:    line.prSno,
          itemCode: line.itemCode,
          depCode:  line.depCode,
          balance:  line.balance,
        })
      } else {
        next.delete(key)
      }
      return next
    })
  }

  const selectAll = () => {
    setSelected(new Map(
      lines.map(l => [rowKey(l), {
        prNo:     l.prNo,
        prDate:   l.prDate,
        prSno:    l.prSno,
        itemCode: l.itemCode,
        depCode:  l.depCode,
        balance:  l.balance,
      }])
    ))
  }

  const clearAll = () => setSelected(new Map())

  const isSelected = (line: PrForeclosureLineDto) => selected.has(rowKey(line))

  const totalBalance   = lines.reduce((s, l) => s + l.balance, 0)
  const selectedCount  = selected.size
  const selectedBalance = [...selected.values()].reduce((s, l) => s + l.balance, 0)

  const confirmForeclosure = () => {
    if (selected.size === 0) return
    const n    = selected.size
    const selBal = selectedBalance.toFixed(3)

    modal.confirm({
      title:   `Confirm Foreclosure — ${n} Line${n > 1 ? 's' : ''}`,
      icon:    null,
      content: (
        `You are about to foreclose ${n} PR line${n > 1 ? 's' : ''} ` +
        `with a total balance of ${selBal} units.\n\n` +
        `This action cannot be undone — no undo-foreclosure exists.`
      ),
      okText:      `Foreclose ${n} Line${n > 1 ? 's' : ''}`,
      okButtonProps: { danger: true },
      cancelText:  'Cancel',
      onOk: async () => {
        try {
          const result = await api.saveForeclosure([...selected.values()])
          notifySuccess(`${result.count} line${result.count !== 1 ? 's' : ''} force-closed.`)
          await load(prNoFilter || undefined)
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : 'Save failed.'
          notifyError(msg)
        }
      },
    })
  }

  return {
    lines, loading, hasLoaded,
    prNoFilter, setPrNoFilter,
    load, reset,
    selected, toggleRow, selectAll, clearAll, isSelected,
    totalLines:   lines.length,
    selectedCount,
    totalBalance,
    selectedBalance,
    confirmForeclosure,
  }
}
