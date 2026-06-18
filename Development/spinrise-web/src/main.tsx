import { createRoot } from 'react-dom/client'
import { App as AntApp, ConfigProvider } from 'antd'
import themeConfig from './shared/theme/themeConfig'
import { NotificationBridge } from './shared/lib/notification'
import App from './App'
import './index.css'
import './shared/styles/notification.css'

createRoot(document.getElementById('root')!).render(
  <>
    <ConfigProvider theme={themeConfig}>
      <AntApp notification={{ placement: 'topRight' }}>
        <NotificationBridge />
        <App />
      </AntApp>
    </ConfigProvider>
  </>,
)
