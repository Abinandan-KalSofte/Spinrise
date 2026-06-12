import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { PoToolbar } from './PoToolbar'
import type { ScreenMode } from '../../types'

const noop = () => {}

function renderToolbar(overrides: Partial<React.ComponentProps<typeof PoToolbar>> = {}) {
  const props: React.ComponentProps<typeof PoToolbar> = {
    mode: 'VIEW' as ScreenMode,
    canAdd: true, canDelete: true, canPrint: true, busy: false,
    onNew: noop, onDelete: noop, onSave: noop, onCancel: noop, onPrint: noop,
    ...overrides,
  }
  return render(<PoToolbar {...props} />)
}

const btn = (label: string) => screen.getByText(label).closest('button') as HTMLButtonElement

describe('PoToolbar', () => {
  it('disables Print when the user lacks print permission (gate)', () => {
    renderToolbar({ canPrint: false })
    expect(btn('Print')).toBeDisabled()
  })

  it('enables Print in VIEW when permitted', () => {
    renderToolbar({ canPrint: true })
    expect(btn('Print')).not.toBeDisabled()
  })

  it('enables New PO in VIEW and disables Save/Cancel', () => {
    renderToolbar({ mode: 'VIEW' })
    expect(btn('New PO')).not.toBeDisabled()
    expect(btn('Save')).toBeDisabled()
    expect(btn('Cancel')).toBeDisabled()
  })

  it('shows a danger Confirm Delete and enables Save in DELETE mode', () => {
    renderToolbar({ mode: 'DELETE' })
    expect(btn('Confirm Delete')).not.toBeDisabled()
    expect(btn('New PO')).toBeDisabled()
  })

  it('fires onNew when New PO is clicked', () => {
    const onNew = vi.fn()
    renderToolbar({ onNew })
    btn('New PO').click()
    expect(onNew).toHaveBeenCalledOnce()
  })

  it('keeps Find disabled (deferred this sprint)', () => {
    renderToolbar()
    expect(btn('Find')).toBeDisabled()
  })
})
