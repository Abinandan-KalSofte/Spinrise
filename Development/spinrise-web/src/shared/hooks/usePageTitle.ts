import { useEffect } from 'react'

const APP_NAME = 'Spinrise ERP'

export function usePageTitle(pageTitle: string): void {
  useEffect(() => {
    document.title = `${pageTitle} | ${APP_NAME}`
    return () => { document.title = APP_NAME }
  }, [pageTitle])
}
