"use client"

import * as React from "react"

import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { ReasonDialog } from "@/components/reason-dialog"
import { Fields, SearchInput, Section, act } from "@/components/service-ui"
import { Button } from "@/components/ui/button"
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useApi, useAuth } from "@/lib/auth"
import { when } from "@/lib/api"
import { openMedia } from "@/lib/download"
import { StatusBadge } from "@/lib/labels"
import type { AdminUser, Paged } from "@/lib/types"

type Ticket = {
  id: number
  kind: "SUPPORT" | "PROBLEM"
  category: string
  status: string
  app_version: string | null
  platform: string | null
  has_screenshot: boolean
  created_at: string
  replied_at: string | null
  closed_at: string | null
  user: AdminUser | null
}
type Detail = Ticket & {
  description: string | null
  reply: string | null
  screenshot_media_id: number | null
  replied_by: string | null
}

const KINDS: Record<string, string> = { SUPPORT: "Question", PROBLEM: "Problème" }
const CATEGORIES: Record<string, string> = {
  QUESTION: "Question", ACCOUNT: "Compte et connexion", MESSAGES: "Messages", CALLS: "Appels",
  NOTIFICATIONS: "Notifications", CRASH: "Plantage ou blocage", OTHER: "Autre",
}

/** Demandes envoyées depuis l'app (Réglages › Aide et support : « Écrire au
 *  support », « Signaler un problème »). Le texte est chiffré au repos et ne
 *  se déchiffre qu'à l'ouverture d'une demande. */
export default function SupportPage() {
  const { can } = useAuth()
  const [status, setStatus] = React.useState("OPEN")
  const [q, setQ] = React.useState("")
  const [page, setPage] = React.useState(1)
  const params = new URLSearchParams({ status, page: String(page), size: "25" })
  if (q) params.set("q", q)
  const list = useApi<Paged<Ticket>>(`/admin/support/search?${params}`)
  const [selected, setSelected] = React.useState<number | null>(null)
  const detail = useApi<Detail>(selected ? `/admin/support/${selected}` : null)
  const [replying, setReplying] = React.useState<number | null>(null)
  const d = selected && detail.data?.id === selected ? detail.data : null

  function actions(t: Ticket) {
    if (t.status === "CLOSED" || !can("reports.manage")) return null
    return (
      <div className="flex flex-wrap justify-end gap-2">
        <Button size="sm" variant="secondary" onClick={(e) => { e.stopPropagation(); setReplying(t.id) }}>Répondre</Button>
        <Button size="sm" variant="outline" onClick={async (e) => {
          e.stopPropagation()
          try {
            await act(`/admin/support/${t.id}/close`, {}, "Demande close")
          } catch {
            return
          }
          list.reload(); detail.reload()
        }}>Clore</Button>
      </div>
    )
  }

  return (
    <ConsoleShell title="Support" permission="reports.view">
      <div className="flex flex-wrap items-center gap-2">
        <Tabs value={status} onValueChange={(v) => { setStatus(v); setPage(1) }}>
          <TabsList>
            <TabsTrigger value="OPEN">À traiter</TabsTrigger>
            <TabsTrigger value="ANSWERED">Répondues</TabsTrigger>
            <TabsTrigger value="CLOSED">Closes</TabsTrigger>
            <TabsTrigger value="ALL">Toutes</TabsTrigger>
          </TabsList>
        </Tabs>
        <SearchInput placeholder="Nom ou numéro…" onSearch={(v) => { setQ(v); setPage(1) }} />
      </div>
      <p className="text-sm text-muted-foreground">
        Les demandes viennent de l&apos;app (Réglages › Aide et support). La réponse arrive dans l&apos;app de la
        personne, avec une notification ; aucun message de ses discussions n&apos;est joint.
      </p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable
        rows={list.data?.items ?? null}
        onRowClick={(t) => setSelected(t.id)}
        page={page} total={list.data?.total} size={25} onPage={setPage}
        empty="Aucune demande ici." illustration="all_clear"
        columns={[
          { header: "Reçue le", cell: (t) => when(t.created_at) },
          { header: "Personne", cell: (t) => (
            <div className="flex flex-col">
              <span className="font-medium">{t.user?.full_name ?? "—"}</span>
              <span className="text-xs text-muted-foreground">{t.user?.phone}</span>
            </div>
          ) },
          { header: "Nature", cell: (t) => KINDS[t.kind] ?? t.kind },
          { header: "Catégorie", cell: (t) => CATEGORIES[t.category] ?? t.category },
          { header: "App", cell: (t) => [t.platform, t.app_version].filter(Boolean).join(" · ") || "—" },
          { header: "Statut", cell: (t) => <StatusBadge status={t.status} /> },
          { header: "", className: "text-right", cell: actions },
        ]}
      />
      <Sheet open={selected !== null} onOpenChange={(o) => !o && setSelected(null)}>
        <SheetContent className="overflow-y-auto">
          <SheetHeader>
            <SheetTitle>Demande #{selected}</SheetTitle>
            <SheetDescription>{d ? `Reçue le ${when(d.created_at)}` : ""}</SheetDescription>
          </SheetHeader>
          {d ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div><StatusBadge status={d.status} /></div>
              <Fields rows={[
                ["Personne", d.user ? `${d.user.full_name ?? "—"} · ${d.user.phone ?? ""}` : "—"],
                ["Nature", KINDS[d.kind] ?? d.kind],
                ["Catégorie", CATEGORIES[d.category] ?? d.category],
                ["Application", [d.platform, d.app_version].filter(Boolean).join(" · ") || "—"],
                ["Capture d'écran", d.screenshot_media_id
                  ? <Button size="sm" variant="link" className="h-auto px-0" onClick={() => openMedia(d.screenshot_media_id!)}>Ouvrir la capture</Button>
                  : "—"],
              ]} />
              <Section title="Message">
                <p className="whitespace-pre-wrap">{d.description ?? "Illisible : clé de chiffrement absente ou changée."}</p>
              </Section>
              {d.reply && (
                <Section title="Réponse">
                  <Fields rows={[["Par", d.replied_by ?? "—"], ["Le", when(d.replied_at)]]} />
                  <p className="mt-2 whitespace-pre-wrap">{d.reply}</p>
                </Section>
              )}
              {actions(d)}
            </div>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{detail.error ?? "Chargement…"}</p>
          )}
        </SheetContent>
      </Sheet>
      <ReasonDialog
        open={replying !== null}
        onOpenChange={(o) => !o && setReplying(null)}
        title="Répondre à la demande"
        description="La réponse s'affiche dans l'app, dans « Écrire au support ». Une notification prévient la personne, sans le texte."
        confirm="Envoyer la réponse"
        onConfirm={async (message) => {
          if (replying === null) return
          await act(`/admin/support/${replying}/reply`, { body: { message } }, "Réponse envoyée")
          list.reload(); detail.reload()
        }}
      />
    </ConsoleShell>
  )
}
