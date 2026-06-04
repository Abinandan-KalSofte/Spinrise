import axios from 'axios'

const DEFAULT_ERROR_MESSAGE = 'Something went wrong. Please try again.'

export class AppError extends Error {
  status?: number

  constructor(message: string, status?: number) {
    super(message)
    this.name = 'AppError'
    this.status = status
  }
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof AppError) return error.message

  if (axios.isAxiosError(error)) {
    if (!error.response) {
      if (error.code === 'ECONNABORTED') return 'The request timed out. Please check your connection and try again.'
      return 'Unable to reach the server. Please check your network connection.'
    }

    const data = error.response.data as Record<string, unknown> | string | null | undefined

    if (typeof data === 'string' && data.trim()) return data.trim()

    if (data && typeof data === 'object') {
      const apiMessage = data['message']
      if (typeof apiMessage === 'string' && apiMessage.trim()) return apiMessage.trim()

      const errorsObj = data['errors']
      if (errorsObj && typeof errorsObj === 'object') {
        const firstError = Object.values(errorsObj as Record<string, string[]>)
          .flat()
          .find((e): e is string => typeof e === 'string')
        if (firstError) return firstError
      }
      const title = data['title']
      if (typeof title === 'string' && title.trim()) return title.trim()
    }

    switch (error.response.status) {
      case 400: return 'The request could not be processed. Please review the form and try again.'
      case 401: return 'Your session has expired. Please sign in again.'
      case 403: return 'You do not have permission to perform this action.'
      case 404: return 'The requested record was not found.'
      case 409: return 'This record was recently modified by another user. Please reload the page and try again.'
      case 422: return 'The submitted data is invalid. Please review the form and try again.'
    }
    if (error.response.status >= 500) return 'The server encountered an error. Please try again later.'
  }

  if (error instanceof Error && error.message.trim()) return error.message
  return DEFAULT_ERROR_MESSAGE
}

export function handleApiError(error: unknown): AppError {
  if (error instanceof AppError) return error
  if (axios.isAxiosError(error)) return new AppError(getErrorMessage(error), error.response?.status)
  return new AppError(getErrorMessage(error))
}
