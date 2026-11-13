// Fichiers protégés : un lien <a href> n'emporte pas le jeton de la console,
// on passe donc par fetch avec l'en-tête Authorization, puis une URL blob.
import { ApiError, api, getToken } from "@/lib/api"

const BASE = (process.env.NEXT_PUBLIC_API_BASE ?? "") + "/api/v1"

async function authorizedBlob(path: string): Promise<{ blob: Blob; filename: string | null }> {
  const token = getToken()
  const response = await fetch(BASE + path, { headers: token ? { Authorization: `Bearer ${token}` } : {} })
  if (!response.ok) {
    let message = `Erreur ${response.status}`
    try {
      const body = await response.json()
      if (typeof body.detail === "string") message = body.detail
    } catch {}
    throw new ApiError(response.status, message)
  }
  const disposition = response.headers.get("content-disposition") ?? ""
  const match = /filename="?([^";]+)"?/.exec(disposition)
  return { blob: await response.blob(), filename: match ? match[1] : null }
}

/** Ouvre un média (justificatif, visuel) dans un nouvel onglet. L'onglet est
 *  ouvert tout de suite, pour ne pas être bloqué par le navigateur. */
export async function openMedia(mediaId: number) {
  const tab = window.open("", "_blank")
  try {
    let url: string
    try {
      url = (await api<{ url: string }>(`/media/${mediaId}/download-url`)).url
    } catch (e) {
      if (!(e instanceof ApiError) || e.status !== 409) throw e
      url = URL.createObjectURL((await authorizedBlob(`/media/${mediaId}`)).blob)
    }
    if (tab) tab.location.href = url
    else window.open(url, "_blank")
  } catch (e) {
    tab?.close()
    throw e
  }
}

/** Télécharge un fichier rendu par l'API (export CSV…). */
export async function downloadFile(path: string, fallbackName: string) {
  const { blob, filename } = await authorizedBlob(path)
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = filename ?? fallbackName
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 10_000)
}

/** « /api/media/12 » (format des anciennes routes) → 12. */
export function mediaIdOf(url: string | null | undefined): number | null {
  const m = url ? /\/media\/(\d+)/.exec(url) : null
  return m ? Number(m[1]) : null
}
