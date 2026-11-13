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
import { ActiveBadge, StatusBadge } from "@/lib/labels"
import type { AdminUser, Paged } from "@/lib/types"

type Report = {
  id: number
  status: string
  reason: string | null
  blocked: boolean
  created_at: string
  resolved_at: string | null
  resolution: string | null
  target: AdminUser | null
  reporter: AdminUser | null
  target_reports: number
}
type Detail = Report & {
  resolved_by: string | null
  history: { id: number; status: string; reason: string | null; resolution: string | null; created_at: string }[]
}
type Action = "dismiss" | "suspend" | "warn"

const DIALOG: Record<Action, { title: string; description: string; confirm: string }> = {
  dismiss: { title: "Classer sans suite ?", description: "Le signalement est clos sans sanction.", confirm: "Classer" },
  warn: {
    title: "Avertir le compte signalé ?",
    description: "Ce message arrive dans son centre de notifications, signé « l'équipe Pokou ». Le compte reste actif.",
    confirm: "Envoyer l'avertissement",
  },
  suspend: {
    title: "Suspendre le compte signalé ?",
    description: "La personne est déconnectée tout de suite ; ses autres signalements ouverts sont marqués comme sanctionnés.",
    confirm: "Suspendre",
  },
}

export default function ReportsPage() {
  const { can } = useAuth()
  const [status, setStatus] = React.useState("OPEN")
  const [q, setQ] = React.useState("")
  const [page, setPage] = React.useState(1)
  const params = new URLSearchParams({ status, page: String(page), size: "25" })
  if (q) params.set("q", q)
  const list = useApi<Paged<Report>>(`/admin/reports/search?${params}`)
  const [selected, setSelected] = React.useState<number | null>(null)
  const detail = useApi<Detail>(selected ? `/admin/reports/${selected}` : null)
  const [acting, setActing] = React.useState<{ id: number; action: Action } | null>(null)
  const d = selected && detail.data?.id === selected ? detail.data : null

  function actions(r: Report) {
    if (r.status !== "OPEN" || !can("reports.manage")) return null
    return (
      <div className="flex flex-wrap justify-end gap-2">
        <Button size="sm" variant="outline" onClick={(e) => { e.stopPropagation(); setActing({ id: r.id, action: "dismiss" }) }}>Classer</Button>
        <Button size="sm" variant="secondary" onClick={(e) => { e.stopPropagation(); setActing({ id: r.id, action: "warn" }) }}>Avertir</Button>
        {can("users.manage") && (
          <Button size="sm" variant="destructive" onClick={(e) => { e.stopPropagation(); setActing({ id: r.id, action: "suspend" }) }}>Suspendre</Button>
        )}
      </div>
    )
  }

  return (
    <ConsoleShell title="Signalements" permission="reports.view">
      <div className="flex flex-wrap items-center gap-2">
        <Tabs value={status} onValueChange={(v) => { setStatus(v); setPage(1) }}>
          <TabsList>
            <TabsTrigger value="OPEN">À traiter</TabsTrigger>
            <TabsTrigger value="ACTIONED">Sanctionnés</TabsTrigger>
            <TabsTrigger value="DISMISSED">Classés</TabsTrigger>
            <TabsTrigger value="ALL">Tous</TabsTrigger>
          </TabsList>
        </Tabs>
        <SearchInput placeholder="Compte signalé, numéro, motif…" onSearch={(v) => { setQ(v); setPage(1) }} />
      </div>
      <p className="text-sm text-muted-foreground">
        Les signalements viennent de l&apos;app (« Signaler » sur une discussion). Le contenu des messages
        n&apos;est jamais transmis : on juge sur le motif, le nombre de signalements et l&apos;historique du compte.
      </p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable
        rows={list.data?.items ?? null}
        onRowClick={(r) => setSelected(r.id)}
        page={page} total={list.data?.total} size={25} onPage={setPage}
        empty="Aucun signalement ici. Tout est calme." illustration="all_clear"
        columns={[
          { header: "Reçu le", cell: (r) => when(r.created_at) },
          { header: "Compte signalé", cell: (r) => (
            <div className="flex flex-col">
              <span className="font-medium">{r.target?.full_name ?? "—"}</span>
              <span className="text-xs text-muted-foreground">{r.target?.phone}</span>
            </div>
          ) },
          { header: "Motif", cell: (r) => <span className="line-clamp-2 max-w-sm whitespace-normal">{r.reason ?? "—"}</span> },
          { header: "Total reçus", cell: (r) => <span className="tabular-nums">{r.target_reports}</span> },
          { header: "Compte", cell: (r) => r.target ? <ActiveBadge active={r.target.is_active} /> : "—" },
          { header: "Statut", cell: (r) => <StatusBadge status={r.status} /> },
          { header: "", className: "text-right", cell: actions },
        ]}
      />
      <Sheet open={selected !== null} onOpenChange={(o) => !o && setSelected(null)}>
        <SheetContent className="overflow-y-auto">
          <SheetHeader>
            <SheetTitle>Signalement #{selected}</SheetTitle>
            <SheetDescription>{d ? `Reçu le ${when(d.created_at)}` : ""}</SheetDescription>
          </SheetHeader>
          {d ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div className="flex items-center gap-2"><StatusBadge status={d.status} />{d.blocked && <span className="text-muted-foreground">· bloqué par l&apos;auteur</span>}</div>
              <Fields rows={[
                ["Compte signalé", d.target ? `${d.target.full_name ?? "—"} · ${d.target.phone ?? ""}` : "—"],
                ["État du compte", d.target ? <ActiveBadge active={d.target.is_active} /> : "—"],
                ["Signalé par", d.reporter?.full_name ?? "—"],
                ["Motif", d.reason ?? "—"],
                ["Signalements reçus", d.target_reports],
              ]} />
              {d.status !== "OPEN" && (
                <Section title="Décision">
                  <Fields rows={[
                    ["Par", d.resolved_by ?? "—"],
                    ["Le", when(d.resolved_at)],
                    ["Note", d.resolution ?? "—"],
                  ]} />
                </Section>
              )}
              <Section title="Autres signalements de ce compte">
                {d.history.length === 0 ? <span className="text-muted-foreground">Aucun.</span> : (
                  <ul className="flex flex-col gap-1">
                    {d.history.map((h) => (
                      <li key={h.id} className="flex items-start justify-between gap-2">
                        <span>{when(h.created_at)} — {h.reason ?? "sans motif"}</span>
                        <StatusBadge status={h.status} />
                      </li>
                    ))}
                  </ul>
                )}
              </Section>
              {actions(d)}
            </div>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{detail.error ?? "Chargement…"}</p>
          )}
        </SheetContent>
      </Sheet>
      <ReasonDialog
        open={acting !== null}
        onOpenChange={(o) => !o && setActing(null)}
        destructive={acting?.action === "suspend"}
        optional={acting?.action === "dismiss"}
        title={acting ? DIALOG[acting.action].title : ""}
        description={acting ? DIALOG[acting.action].description : undefined}
        confirm={acting ? DIALOG[acting.action].confirm : ""}
        onConfirm={async (note) => {
          if (!acting) return
          if (acting.action === "warn") {
            await act(`/admin/reports/${acting.id}/warn`, { body: { message: note } }, "Avertissement envoyé")
          } else {
            await act(`/admin/reports/${acting.id}/resolve`, { body: { action: acting.action, note: note || null } },
              acting.action === "suspend" ? "Compte suspendu" : "Signalement classé")
          }
          list.reload(); detail.reload()
        }}
      />
    </ConsoleShell>
  )
}
