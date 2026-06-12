import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App as AntApp, ConfigProvider } from 'antd'
import themeConfig from './shared/theme/themeConfig'
import App from './App'
import './index.css'

// Runtime API mocks (demo/UAT without a backend). Enabled only when
// VITE_ENABLE_MOCKS === 'true'; the worker (and all mock code) is dynamically
// imported so production builds with the flag off tree-shake it away.
// TODO: Replace with actual backend API when available — set VITE_ENABLE_MOCKS=false.
async function enableMocking() {
  if (import.meta.env.VITE_ENABLE_MOCKS !== 'true') return
  const { worker } = await import('./mocks/browser')
  await worker.start({ onUnhandledRequest: 'bypass' })
}

void enableMocking().then(() => {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <ConfigProvider theme={themeConfig}>
        <AntApp>
          <App />
        </AntApp>
      </ConfigProvider>
    </StrictMode>,
  )
})
