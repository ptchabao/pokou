"use client"

import * as React from "react"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { useApi } from "@/lib/auth"
import { when } from "@/lib/api"
import type { Paged } from "@/lib/types"

type Entry = { id: number; action: string; entity_type: string; entity_id: number | null
  changes: Record<string, unknown> | null; created_at: string; actor: string | null }

const ACTIONS: Record<string, string> = {
  suspend: "Suspension", reactivate: "Réactivation", role_change: "Changement de rôle",
  report_dismiss: "Signalement classé", report_suspend: "Signalement sanctionné", login: "Connexion",
}

export default function AuditPage() {
  const [page, setPage] = React.useState(1)
  const list = useApi<Paged<Entry>>(`/admin/audit?page=${page}&size=50`)
  return (
    <ConsoleShell title="Journal d'audit" permission="audit.view">
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable illustration="audit" empty="Aucune action enregistrée." rows={list.data?.items ?? null} page={page} total={list.data?.total} size={50} onPage={setPage}
        columns={[
          { header: "Date", cell: (e) => when(e.created_at) },
          { header: "Par", cell: (e) => e.actor ?? "—" },
          { header: "Action", cell: (e) => ACTIONS[e.action] ?? e.action },
          { header: "Cible", cell: (e) => `${e.entity_type}${e.entity_id ? ` #${e.entity_id}` : ""}` },
          { header: "Détails", cell: (e) => e.changes ? (
            <code className="line-clamp-2 max-w-md whitespace-normal text-xs text-muted-foreground">
              {Object.entries(e.changes).map(([k, v]) => `${k}: ${typeof v === "object" ? JSON.stringify(v) : v}`).join(" · ")}
            </code>
          ) : "—" },
        ]} />
    </ConsoleShell>
  )
}
