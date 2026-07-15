// Client public-IP lookup — browsers have no API for this (the backend only
// ever sees the IP at connection time, via HttpContext.Connection.RemoteIpAddress),
// so a third-party lookup is the only way the SPA itself can learn its own public
// IP. Uses plain fetch() rather than the shared `api` axios instance deliberately:
// that instance is pinned to the Spinrise backend's baseURL and attaches
// Authorization/X-Processing-Date headers via interceptors, neither of which
// belongs on a call to an external service.
const IP_LOOKUP_URL = 'https://api.ipify.org?format=json'
const IP_LOOKUP_TIMEOUT_MS = 3000

let cachedIpPromise: Promise<string | null> | null = null

async function fetchClientIp(): Promise<string | null> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), IP_LOOKUP_TIMEOUT_MS)
  try {
    const res = await fetch(IP_LOOKUP_URL, { signal: controller.signal })
    if (!res.ok) return null
    const data = (await res.json()) as { ip?: string }
    return data.ip?.trim() || null
  } catch (err) {
    if (import.meta.env.DEV) {
      console.warn('[ipAddress] Failed to retrieve client IP address:', err)
    }
    return null
  } finally {
    clearTimeout(timer)
  }
}

/**
 * Returns the client's public IP address, or null if it could not be
 * retrieved (network failure, timeout, blocked request, etc.) — never throws,
 * so callers never need to guard a lookup failure themselves.
 *
 * Memoised for the lifetime of the page: concurrent/repeated calls (e.g. a
 * page-load pre-warm followed by the actual login submit, or a double-clicked
 * Login button) share the one in-flight or resolved lookup rather than firing
 * a new request each time. A failed lookup is NOT cached — the next call
 * retries, so one transient network blip doesn't permanently disable IP
 * capture for the rest of the session.
 */
export function getClientIpAddress(): Promise<string | null> {
  if (!cachedIpPromise) {
    cachedIpPromise = fetchClientIp().then((ip) => {
      if (ip === null) cachedIpPromise = null
      return ip
    })
  }
  return cachedIpPromise
}
