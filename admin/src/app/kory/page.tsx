"use client"

import * as React from "react"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { Progress } from "@/components/ui/progress"
import { useApi } from "@/lib/auth"
import { fcfa, when } from "@/lib/api"
import { StatusBadge } from "@/lib/labels"
import type { Paged } from "@/lib/types"

type Pot = {
  id: number; title: string; kind: string; status: string; goal_amount: number | null
  confirmed_total: number; pending: number; contested: number; organizer: string | null
  due_at: string | null; created_at: string
}

export default function KoryPage() {
  const [page, setPage] = React.useState(1)
  const list = useApi<Paged<Pot>>(`/admin/kory/pots?page=${page}&size=25`)
  return (
    <ConsoleShell title="Kory · cagnottes" permission="kory.view">
      <p className="text-sm text-muted-foreground">
        Pokou ne détient jamais l&apos;argent : les montants sont ceux déclarés puis confirmés par l&apos;organisateur.
      </p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable rows={list.data?.items ?? null} page={page} total={list.data?.total} size={25} onPage={setPage}
        empty="Aucune cagnotte pour l'instant." illustration="kory"
        columns={[
          { header: "Cagnotte", cell: (p) => (
            <div className="flex flex-col"><span className="font-medium">{p.title}</span>
              <span className="text-xs text-muted-foreground">{p.organizer ?? "—"} · {p.kind}</span></div>
          ) },
          { header: "Confirmé", cell: (p) => (
            <div className="flex min-w-40 flex-col gap-1">
              <span className="tabular-nums">{fcfa(p.confirmed_total)}{p.goal_amount ? ` / ${fcfa(p.goal_amount)}` : ""}</span>
              {p.goal_amount ? <Progress value={Math.min(100, (100 * p.confirmed_total) / p.goal_amount)} /> : null}
            </div>
          ) },
          { header: "À confirmer", cell: (p) => <span className="tabular-nums">{p.pending}</span> },
          { header: "Contestées", cell: (p) => <span className={p.contested ? "font-medium text-destructive" : "tabular-nums"}>{p.contested}</span> },
          { header: "Échéance", cell: (p) => when(p.due_at) },
          { header: "Statut", cell: (p) => <StatusBadge status={p.status} /> },
        ]} />
    </ConsoleShell>
  )
}
