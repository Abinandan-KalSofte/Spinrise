import { useState } from 'react'

export function useAsync<TArgs extends unknown[], TResult>(
  asyncFn: (...args: TArgs) => Promise<TResult>,
) {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<unknown>(null)

  const execute = async (...args: TArgs) => {
    setLoading(true)
    setError(null)
    try {
      return await asyncFn(...args)
    } catch (err) {
      setError(err)
      throw err
    } finally {
      setLoading(false)
    }
  }

  return { execute, loading, error, resetError: () => setError(null) }
}
