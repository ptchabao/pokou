// Client de l'API Pokou. Même origine en production (/api/v1) ; en
// développement, NEXT_PUBLIC_API_BASE pointe vers l'API.
const BASE = (process.env.NEXT_PUBLIC_API_BASE ?? "") + "/api/v1"
const TOKEN_KEY = "pokou_console_token"

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message)
  }
}

export function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY)
  } catch {
    return null
  }
}

export function setToken(token: string | null) {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token)
    else localStorage.removeItem(TOKEN_KEY)
  } catch {
    /* navigation privée : la session ne survivra pas au rechargement */
  }
}

export async function api<T = unknown>(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<T> {
  const token = getToken()
  const response = await fetch(BASE + path, {
    method: init.method ?? (init.body ? "POST" : "GET"),
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: init.body ? JSON.stringify(init.body) : undefined,
  })
  if (response.status === 401) {
    setToken(null)
    if (typeof window !== "undefined" && !location.pathname.endsWith("/login/")) {
      location.href = "/console/login/"
    }
  }
  if (!response.ok) {
    let message = `Erreur ${response.status}`
    try {
      const body = await response.json()
      if (typeof body.detail === "string") message = body.detail
    } catch {}
    throw new ApiError(response.status, message)
  }
  return (await response.json()) as T
}

export const fcfa = (n: number | null | undefined) =>
  `${new Intl.NumberFormat("fr-FR").format(n ?? 0)} FCFA`

export const when = (iso?: string | null) =>
  iso
    ? new Intl.DateTimeFormat("fr-FR", { dateStyle: "medium", timeStyle: "short" }).format(
        new Date(iso.endsWith("Z") || iso.includes("+") ? iso : iso + "Z"),
      )
    : "—"
