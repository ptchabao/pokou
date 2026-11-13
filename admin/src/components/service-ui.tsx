"use client"

import * as React from "react"
import { toast } from "sonner"
import { Input } from "@/components/ui/input"
import { Separator } from "@/components/ui/separator"
import { api } from "@/lib/api"

/** Champ de recherche avec temporisation (300 ms) ; `onSearch` reçoit le
 *  texte nettoyé. */
export function SearchInput({ placeholder, onSearch, className }: {
  placeholder: string; onSearch: (q: string) => void; className?: string
}) {
  const [q, setQ] = React.useState("")
  const first = React.useRef(true)
  React.useEffect(() => {
    if (first.current) { first.current = false; return }
    const t = setTimeout(() => onSearch(q.trim()), 300)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q])
  return <Input className={className ?? "max-w-xs"} placeholder={placeholder} value={q} onChange={(e) => setQ(e.target.value)} />
}

/** Onglet initial lu dans l'adresse (« ?tab=couriers »), pour les liens du
 *  tableau de bord. */
export function useTabParam(initial: string, allowed: string[]): [string, (t: string) => void] {
  const [tab, setTab] = React.useState(initial)
  React.useEffect(() => {
    const wanted = new URLSearchParams(window.location.search).get("tab")
    if (wanted && allowed.includes(wanted)) setTab(wanted)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  return [tab, setTab]
}

/** Grille « libellé · valeur » d'une fiche. */
export function Fields({ rows }: { rows: [string, React.ReactNode][] }) {
  return (
    <div className="grid grid-cols-[minmax(0,2fr)_minmax(0,3fr)] gap-x-3 gap-y-1">
      {rows.map(([label, value]) => (
        <React.Fragment key={label}>
          <span className="text-muted-foreground">{label}</span>
          <span className="break-words">{value ?? "—"}</span>
        </React.Fragment>
      ))}
    </div>
  )
}

export function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <>
      <Separator />
      <div className="flex flex-col gap-2">
        <span className="font-medium">{title}</span>
        {children}
      </div>
    </>
  )
}

/** Appel d'une action : toast de succès ou d'erreur ; relance l'erreur
 *  pour que la boîte de dialogue reste ouverte. */
export async function act<T = unknown>(path: string, init: { method?: string; body?: unknown }, success: string): Promise<T> {
  try {
    const result = await api<T>(path, { method: init.method ?? "POST", body: init.body })
    toast.success(success)
    return result
  } catch (e) {
    toast.error((e as Error).message)
    throw e
  }
}

/** Petit journal des gestes de l'équipe sur un objet. */
export function TeamActions({ items, labels }: {
  items: { action: string; actor: string | null; reason?: string | null; at: string }[]
  labels?: Record<string, string>
}) {
  if (!items.length) return <span className="text-muted-foreground">Aucune action de l&apos;équipe.</span>
  return (
    <ul className="flex flex-col gap-1">
      {items.map((a, i) => (
        <li key={i} className="text-muted-foreground">
          <span className="text-foreground">{labels?.[a.action] ?? a.action}</span>
          {" · "}{a.actor ?? "—"}{" · "}{new Date(a.at.endsWith("Z") ? a.at : a.at + "Z").toLocaleString("fr-FR")}
          {a.reason ? <> — « {a.reason} »</> : null}
        </li>
      ))}
    </ul>
  )
}
