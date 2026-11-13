"use client"

import * as React from "react"
import { IconDownload } from "@tabler/icons-react"
import { toast } from "sonner"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { SearchInput } from "@/components/service-ui"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useApi } from "@/lib/auth"
import { when } from "@/lib/api"
import { AUDIT_ACTIONS, AUDIT_TYPES } from "@/lib/audit-labels"
import { downloadFile } from "@/lib/download"
import type { Paged } from "@/lib/types"

type Entry = { id: number; action: string; entity_type: string; entity_id: number | null
  changes: Record<string, unknown> | null; ip_address: string | null; created_at: string; actor: string | null; actor_id: number }

export default function AuditPage() {
  const [actor, setActor] = React.useState("")
  const [action, setAction] = React.useState("all")
  const [type, setType] = React.useState("all")
  const [since, setSince] = React.useState("")
  const [until, setUntil] = React.useState("")
  const [page, setPage] = React.useState(1)
  const [exporting, setExporting] = React.useState(false)
  const facets = useApi<{ actions: string[]; entity_types: string[] }>("/admin/audit/facets")

  const filters = new URLSearchParams()
  if (actor) filters.set("actor", actor)
  if (action !== "all") filters.set("action", action)
  if (type !== "all") filters.set("entity_type", type)
  if (since) filters.set("since", since)
  if (until) filters.set("until", until)
  const list = useApi<Paged<Entry>>(`/admin/audit/search?${filters}&page=${page}&size=50`)
  const reset = (fn: () => void) => { fn(); setPage(1) }
  const filtered = filters.toString() !== ""

  async function exportCsv() {
    setExporting(true)
    try {
      await downloadFile(`/admin/audit/export?${filters}`, "pokou-audit.csv")
      toast.success("Export téléchargé (10 000 lignes au plus)")
    } catch (e) { toast.error((e as Error).message) } finally { setExporting(false) }
  }

  return (
    <ConsoleShell title="Journal d'audit" permission="audit.view"
      actions={<Button size="sm" variant="outline" disabled={exporting} onClick={exportCsv}><IconDownload className="size-4" />Exporter (CSV)</Button>}>
      <div className="flex flex-wrap items-end gap-2">
        <div className="flex flex-col gap-1">
          <Label>Acteur</Label>
          <SearchInput placeholder="Nom, e-mail, n° de compte…" onSearch={(v) => reset(() => setActor(v))} className="w-56" />
        </div>
        <div className="flex flex-col gap-1">
          <Label>Action</Label>
          <Select value={action} onValueChange={(v) => reset(() => setAction(v))}>
            <SelectTrigger className="w-60"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Toutes les actions</SelectItem>
              {(facets.data?.actions ?? []).map((a) => <SelectItem key={a} value={a}>{AUDIT_ACTIONS[a] ?? a}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-col gap-1">
          <Label>Type</Label>
          <Select value={type} onValueChange={(v) => reset(() => setType(v))}>
            <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Tous les types</SelectItem>
              {(facets.data?.entity_types ?? []).map((t) => <SelectItem key={t} value={t}>{AUDIT_TYPES[t] ?? t}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-col gap-1">
          <Label htmlFor="since">Du</Label>
          <Input id="since" type="date" className="w-40" value={since} onChange={(e) => reset(() => setSince(e.target.value))} />
        </div>
        <div className="flex flex-col gap-1">
          <Label htmlFor="until">Au</Label>
          <Input id="until" type="date" className="w-40" value={until} onChange={(e) => reset(() => setUntil(e.target.value))} />
        </div>
        {(action !== "all" || type !== "all" || since || until) && (
          <Button variant="ghost" onClick={() => reset(() => { setAction("all"); setType("all"); setSince(""); setUntil("") })}>Effacer les filtres</Button>
        )}
      </div>
      <p className="text-xs text-muted-foreground">Dates en UTC. L&apos;export suit les filtres affichés et il est lui-même journalisé.</p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable illustration="audit" empty={filtered ? "Aucune action ne correspond à ces filtres." : "Aucune action enregistrée."}
        rows={list.data?.items ?? null} page={page} total={list.data?.total} size={50} onPage={setPage}
        columns={[
          { header: "Date", cell: (e) => when(e.created_at) },
          { header: "Par", cell: (e) => e.actor ?? `#${e.actor_id}` },
          { header: "Action", cell: (e) => AUDIT_ACTIONS[e.action] ?? e.action },
          { header: "Cible", cell: (e) => `${AUDIT_TYPES[e.entity_type] ?? e.entity_type}${e.entity_id ? ` #${e.entity_id}` : ""}` },
          { header: "Détails", cell: (e) => e.changes ? (
            <code className="line-clamp-2 max-w-md whitespace-normal text-xs text-muted-foreground" title={JSON.stringify(e.changes)}>
              {Object.entries(e.changes).map(([k, v]) => `${k}: ${typeof v === "object" ? JSON.stringify(v) : v}`).join(" · ")}
            </code>
          ) : "—" },
          { header: "IP", cell: (e) => <span className="text-xs text-muted-foreground">{e.ip_address ?? "—"}</span> },
        ]} />
    </ConsoleShell>
  )
}
