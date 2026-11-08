"use client"

import * as React from "react"
import { api, getToken, setToken } from "@/lib/api"

export type Me = {
  id: number
  full_name: string | null
  phone: string | null
  role: string
  role_label: string
  permissions: string[]
}

type AuthState = {
  me: Me | null
  loading: boolean
  can: (permission: string) => boolean
  refresh: () => Promise<void>
  logout: () => void
}

const AuthContext = React.createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [me, setMe] = React.useState<Me | null>(null)
  const [loading, setLoading] = React.useState(true)

  const refresh = React.useCallback(async () => {
    if (!getToken()) {
      setMe(null)
      setLoading(false)
      return
    }
    try {
      setMe(await api<Me>("/admin/me"))
    } catch {
      setMe(null)
    } finally {
      setLoading(false)
    }
  }, [])

  React.useEffect(() => {
    refresh()
  }, [refresh])

  const value = React.useMemo<AuthState>(
    () => ({
      me,
      loading,
      can: (p) => !!me?.permissions.includes(p),
      refresh,
      logout: () => {
        setToken(null)
        setMe(null)
        location.href = "/console/login/"
      },
    }),
    [me, loading, refresh],
  )
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = React.useContext(AuthContext)
  if (!ctx) throw new Error("useAuth hors de AuthProvider")
  return ctx
}

/** Charge une ressource de l'API, avec rechargement manuel. */
export function useApi<T>(path: string | null) {
  const [data, setData] = React.useState<T | null>(null)
  const [error, setError] = React.useState<string | null>(null)
  const [tick, setTick] = React.useState(0)
  React.useEffect(() => {
    if (!path) return
    let alive = true
    setError(null)
    api<T>(path)
      .then((d) => alive && setData(d))
      .catch((e: Error) => alive && setError(e.message))
    return () => {
      alive = false
    }
  }, [path, tick])
  return { data, error, reload: () => setTick((t) => t + 1) }
}
