"use client"

import * as React from "react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { ReasonDialog } from "@/components/reason-dialog"
import { Button } from "@/components/ui/button"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useApi, useAuth } from "@/lib/auth"
import { api, when } from "@/lib/api"
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

export default function ReportsPage() {
  const { can } = useAuth()
  const [status, setStatus] = React.useState("OPEN")
  const list = useApi<Paged<Report>>(`/admin/reports?status=${status}`)
  const [acting, setActing] = React.useState<{ report: Report; action: "dismiss" | "suspend" } | null>(null)

  return (
    <ConsoleShell title="Signalements" permission="reports.view">
      <Tabs value={status} onValueChange={setStatus}>
        <TabsList>
          <TabsTrigger value="OPEN">À traiter</TabsTrigger>
          <TabsTrigger value="ACTIONED">Sanctionnés</TabsTrigger>
          <TabsTrigger value="DISMISSED">Classés</TabsTrigger>
          <TabsTrigger value="ALL">Tous</TabsTrigger>
        </TabsList>
      </Tabs>
      <p className="text-sm text-muted-foreground">
        Les signalements viennent de l&apos;app (« Signaler » sur une discussion). Le contenu des messages
        n&apos;est jamais transmis : on juge sur le motif, le nombre de signalements et l&apos;historique du compte.
      </p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable
        rows={list.data?.items ?? null}
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
          { header: "Signalé par", cell: (r) => r.reporter?.full_name ?? "—" },
          { header: "Total reçus", cell: (r) => <span className="tabular-nums">{r.target_reports}</span> },
          { header: "Compte", cell: (r) => r.target ? <ActiveBadge active={r.target.is_active} /> : "—" },
          { header: "Statut", cell: (r) => (
            <div className="flex flex-col gap-1">
              <StatusBadge status={r.status} />
              {r.resolution && <span className="text-xs text-muted-foreground">{r.resolution}</span>}
            </div>
          ) },
          { header: "", className: "text-right", cell: (r) => r.status === "OPEN" && can("reports.manage") ? (
            <div className="flex justify-end gap-2">
              <Button size="sm" variant="outline" onClick={() => setActing({ report: r, action: "dismiss" })}>Classer</Button>
              <Button size="sm" variant="destructive" onClick={() => setActing({ report: r, action: "suspend" })}>Suspendre</Button>
            </div>
          ) : null },
        ]}
      />
      <ReasonDialog
        open={acting !== null}
        onOpenChange={(o) => !o && setActing(null)}
        destructive={acting?.action === "suspend"}
        optional={acting?.action === "dismiss"}
        title={acting?.action === "suspend" ? "Suspendre le compte signalé ?" : "Classer ce signalement ?"}
        description={acting?.action === "suspend"
          ? "Le compte est suspendu et tous ses signalements ouverts sont marqués comme sanctionnés."
          : "Le signalement est clos sans sanction."}
        confirm={acting?.action === "suspend" ? "Suspendre" : "Classer"}
        onConfirm={async (note) => {
          if (!acting) return
          try {
            await api(`/admin/reports/${acting.report.id}/resolve`, { body: { action: acting.action, note: note || null } })
            toast.success(acting.action === "suspend" ? "Compte suspendu" : "Signalement classé")
            list.reload()
          } catch (e) { toast.error((e as Error).message); throw e }
        }}
      />
    </ConsoleShell>
  )
}
