import type { ReactElement } from 'react'
import { render } from '@testing-library/react'
import type { RenderOptions, RenderResult } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

// Spinrise uses Zustand (no Redux/Context providers needed).
// Zustand stores are module-level singletons — components access them directly.
// This wrapper provides only the Router context required by react-router-dom hooks.
export function renderWithProviders(
  ui: ReactElement,
  options?: { initialEntries?: string[] } & Omit<RenderOptions, 'wrapper'>,
): RenderResult {
  const { initialEntries = ['/'], ...renderOptions } = options ?? {}
  return render(
    <MemoryRouter initialEntries={initialEntries}>{ui}</MemoryRouter>,
    renderOptions,
  )
}
