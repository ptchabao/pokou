"use client"

import * as React from "react"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { ReasonDialog } from "@/components/reason-dialog"
import { Fields, SearchInput, Section, TeamActions, act } from "@/components/service-ui"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { Switch } from "@/components/ui/switch"
import { Label } from "@/components/ui/label"
import { useApi, useAuth } from "@/lib/auth"
import { fcfa, when } from "@/lib/api"
import { AUDIT_ACTIONS } from "@/lib/audit-labels"
import { StatusBadge } from "@/lib/labels"
import type { Paged } from "@/lib/types"

type Pot = {
  id: number; title: string; kind: string; status: string; goal_amount: number | null
  amount_per_member: number | null; period: string | null
  confirmed_total: number; pending: number; contested: number
  organizer: string | null; collector: string | null
  due_at: string | null; created_at: string; closed_at: string | null
  dissolved_at: string | null; dissolve_reason: string | null
}
type Detail = Pot & {
  description: string | null; beneficiary_name: string | null; deputy: string | null
  group_id: number | null; group_members: number; join_code: string
  draw_mode: string | null; draw_seal: string | null; drawn_at: string | null; ends_at: string | null
  pending_invites: number
  members: { user_id: number; name: string | null; joined_at: string; accepted_at: string | null; declined_at: string | null
    pledge_base: number | null; pledge_daily: number | null; confirmed_total: number
    fee_paid_at: string | null; fee_amount: number | null; fee_status: string | null }[]
  rounds: { number: number; beneficiary: string | null; status: string; due_at: string | null; closed_at: string | null }[]
  entries: { id: number; contributor: string | null; amount: number; status: string; period_label: string | null
    round_number: number | null; wallet_reference: string | null; declared_at: string; reviewed_at: string | null
    review_reason: string | null; has_proof: boolean }[]
  fees: { paid: number; total: number }
  team_actions: { action: string; actor: string | null; reason: string | null; at: string }[]
}
type Action = "close" | "reopen" | "dissolve"

const KINDS: Record<string, string> = { CAGNOTTE: "Cagnotte", COTISATION: "Cotisation", TONTINE: "Tontine (Kory Plus)" }
const ENTRY: Record<string, string> = { DECLARED: "À confirmer", CONFIRMED: "Confirmée", REJECTED: "Contestée" }
const DIALOG: Record<Action, { title: string; description: string; confirm: string }> = {
  close: {
    title: "Clôturer cette collecte ?",
    description: "Plus aucune contribution ne pourra être déclarée. Le journal et les montants restent intacts ; tous les participants sont prévenus avec ce motif.",
    confirm: "Clôturer",
  },
  reopen: { title: "Rouvrir cette collecte ?", description: "Les participants sont prévenus.", confirm: "Rouvrir" },
  dissolve: {
    title: "Dissoudre cette tontine ?",
    description: "Aucun tour ne sera plus appelé ; le tour en cours s'arrête. Ce qui a été versé se règle entre membres : Pokou ne touche jamais l'argent.",
    confirm: "Dissoudre",
  },
}

export default function KoryPage() {
  const { can } = useAuth()
  const [q, setQ] = React.useState("")
  const [kind, setKind] = React.useState("all")
  const [status, setStatus] = React.useState("all")
  const [contested, setContested] = React.useState(false)
  const [page, setPage] = React.useState(1)
  const params = new URLSearchParams({ page: String(page), size: "25" })
  if (q) params.set("q", q)
  if (kind !== "all") params.set("kind", kind)
  if (status !== "all") params.set("status", status)
  if (contested) params.set("contested", "true")
  const list = useApi<Paged<Pot>>(`/admin/kory/pots/search?${params}`)
  const [selected, setSelected] = React.useState<number | null>(null)
  const detail = useApi<Detail>(selected ? `/admin/kory/pots/${selected}` : null)
  const [acting, setActing] = React.useState<Action | null>(null)
  const d = selected && detail.data?.id === selected ? detail.data : null
  const teamClosed = d?.team_actions[0]?.action === "kory_close"

  return (
    <ConsoleShell title="Kory · collectes" permission="kory.view">
      <p className="text-sm text-muted-foreground">
        Pokou ne détient jamais l&apos;argent : les montants sont ceux déclarés par les membres puis confirmés par
        celui qui reçoit. La console ne modifie aucun montant.
      </p>
      <div className="flex flex-wrap items-center gap-2">
        <SearchInput placeholder="Titre, code, organisateur, n°…" onSearch={(v) => { setQ(v); setPage(1) }} />
        <Select value={kind} onValueChange={(v) => { setKind(v); setPage(1) }}>
          <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Tous les types</SelectItem>
            {Object.entries(KINDS).map(([k, v]) => <SelectItem key={k} value={k}>{v}</SelectItem>)}
          </SelectContent>
        </Select>
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(1) }}>
          <SelectTrigger className="w-40"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Tous les statuts</SelectItem>
            <SelectItem value="OPEN">Ouvertes</SelectItem>
            <SelectItem value="PENDING">En attente (tontine)</SelectItem>
            <SelectItem value="CLOSED">Clôturées</SelectItem>
          </SelectContent>
        </Select>
        <div className="flex items-center gap-2">
          <Switch id="contested" checked={contested} onCheckedChange={(v) => { setContested(v); setPage(1) }} />
          <Label htmlFor="contested">Avec contestations</Label>
        </div>
      </div>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable rows={list.data?.items ?? null} page={page} total={list.data?.total} size={25} onPage={setPage}
        onRowClick={(p) => setSelected(p.id)}
        empty="Aucune collecte ne correspond." illustration="kory"
        columns={[
          { header: "Collecte", cell: (p) => (
            <div className="flex flex-col"><span className="font-medium">{p.title}</span>
              <span className="text-xs text-muted-foreground">{p.organizer ?? "—"} · {KINDS[p.kind] ?? p.kind}</span></div>
          ) },
          { header: "Confirmé", cell: (p) => (
            <div className="flex min-w-40 flex-col gap-1">
              <span className="tabular-nums">{fcfa(p.confirmed_total)}{p.goal_amount ? ` / ${fcfa(p.goal_amount)}` : ""}</span>
              {p.goal_amount ? <Progress value={Math.min(100, (100 * p.confirmed_total) / p.goal_amount)} /> : null}
            </div>
          ) },
          { header: "À confirmer", cell: (p) => <span className="tabular-nums">{p.pending}</span> },
          { header: "Contestées", cell: (p) => <span className={p.contested ? "font-medium text-destructive" : "tabular-nums"}>{p.contested}</span> },
          { header: "Créée le", cell: (p) => when(p.created_at) },
          { header: "Statut", cell: (p) => p.dissolved_at ? <Badge variant="destructive">Dissoute</Badge> : <StatusBadge status={p.status} /> },
        ]} />
      <Sheet open={selected !== null} onOpenChange={(o) => !o && setSelected(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-xl">
          <SheetHeader>
            <SheetTitle>{d?.title ?? "Collecte"}</SheetTitle>
            <SheetDescription>{d ? `${KINDS[d.kind] ?? d.kind} · n° ${d.id} · code ${d.join_code}` : ""}</SheetDescription>
          </SheetHeader>
          {d ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div className="flex items-center gap-2">
                {d.dissolved_at ? <Badge variant="destructive">Dissoute</Badge> : <StatusBadge status={d.status} />}
                {d.contested > 0 && <Badge variant="destructive">{d.contested} contestation{d.contested > 1 ? "s" : ""}</Badge>}
              </div>
              <Fields rows={[
                ["Organisateur", d.organizer],
                ["Reçoit l'argent", d.kind === "TONTINE" ? "le bénéficiaire de chaque tour" : d.collector],
                ...(d.deputy ? [["Suppléant", d.deputy] as [string, React.ReactNode]] : []),
                ...(d.beneficiary_name ? [["Pour", d.beneficiary_name] as [string, React.ReactNode]] : []),
                ["Confirmé", fcfa(d.confirmed_total)],
                ["Objectif", d.goal_amount ? fcfa(d.goal_amount) : "—"],
                ["Par membre", d.amount_per_member ? `${fcfa(d.amount_per_member)}${d.period ? ` · ${d.period}` : ""}` : "—"],
                ["Groupe", d.group_id ? `#${d.group_id} · ${d.group_members} membres` : "—"],
                ["Invitations en attente", d.pending_invites],
                ["Échéance", when(d.due_at)],
                ["Créée le", when(d.created_at)],
                ["Clôturée le", when(d.closed_at)],
                ...(d.draw_mode ? [["Ordre des tours", `${d.draw_mode === "DRAW" ? "tiré au sort" : "fixé"}${d.draw_seal ? ` · sceau ${d.draw_seal}` : ""}`] as [string, React.ReactNode]] : []),
                ...(d.dissolve_reason ? [["Motif de dissolution", d.dissolve_reason] as [string, React.ReactNode]] : []),
              ]} />
              {d.description && <p className="text-muted-foreground">{d.description}</p>}
              <Section title={`Membres (${d.members.length})`}>
                {d.members.length === 0 ? <span className="text-muted-foreground">Aucun membre par code{d.group_id ? " (membres du groupe)" : ""}.</span> : (
                  <ul className="flex flex-col gap-1">
                    {d.members.map((m) => (
                      <li key={m.user_id} className="flex items-start justify-between gap-2">
                        <span>
                          {m.name ?? "—"}
                          {m.declined_at && <span className="text-destructive"> · a refusé</span>}
                          {m.pledge_base ? <span className="text-muted-foreground"> · engagement {fcfa(m.pledge_base)}{m.pledge_daily ? ` + ${fcfa(m.pledge_daily)}/j` : ""}</span> : null}
                          {m.fee_paid_at && <span className="text-muted-foreground"> · frais payés le {when(m.fee_paid_at)}{m.fee_amount ? ` (${fcfa(m.fee_amount)})` : ""}</span>}
                        </span>
                        <span className="shrink-0 tabular-nums">{fcfa(m.confirmed_total)}</span>
                      </li>
                    ))}
                  </ul>
                )}
                {d.kind === "TONTINE" && (
                  <span className="text-muted-foreground">Frais Kory Plus : {d.fees.paid} membre{d.fees.paid > 1 ? "s" : ""} · {fcfa(d.fees.total)} (Mobile Money)</span>
                )}
              </Section>
              {d.rounds.length > 0 && (
                <Section title="Tours">
                  <ul className="flex flex-col gap-1">
                    {d.rounds.map((r) => (
                      <li key={r.number} className="flex items-center justify-between gap-2">
                        <span>Tour {r.number} · {r.beneficiary ?? "—"} <span className="text-muted-foreground">{r.due_at ? `· ${when(r.due_at)}` : ""}</span></span>
                        <StatusBadge status={r.status} />
                      </li>
                    ))}
                  </ul>
                </Section>
              )}
              <Section title={`Journal des contributions (${d.entries.length})`}>
                {d.entries.length === 0 ? <span className="text-muted-foreground">Aucune contribution déclarée.</span> : (
                  <ul className="flex flex-col gap-2">
                    {d.entries.map((e) => (
                      <li key={e.id} className={`rounded-md border p-2 ${e.status === "REJECTED" ? "border-destructive/50" : ""}`}>
                        <div className="flex items-center justify-between gap-2">
                          <span className="font-medium">{e.contributor ?? "—"} · <span className="tabular-nums">{fcfa(e.amount)}</span></span>
                          <Badge variant={e.status === "REJECTED" ? "destructive" : e.status === "CONFIRMED" ? "secondary" : "default"}>{ENTRY[e.status] ?? e.status}</Badge>
                        </div>
                        <div className="text-xs text-muted-foreground">
                          Déclarée le {when(e.declared_at)}
                          {e.period_label ? ` · période ${e.period_label}` : ""}
                          {e.round_number ? ` · tour ${e.round_number}` : ""}
                          {e.wallet_reference ? ` · réf. ${e.wallet_reference}` : ""}
                          {e.has_proof ? " · capture jointe (visible du seul destinataire)" : ""}
                        </div>
                        {e.review_reason && <div className="text-xs text-destructive">Motif : {e.review_reason}</div>}
                      </li>
                    ))}
                  </ul>
                )}
              </Section>
              <Section title="Actions de l'équipe">
                <TeamActions items={d.team_actions} labels={AUDIT_ACTIONS} />
              </Section>
              {can("kory.manage") && (
                <div className="flex flex-wrap gap-2">
                  {d.kind === "TONTINE" && (d.status === "OPEN" || d.status === "PENDING") && (
                    <Button variant="destructive" onClick={() => setActing("dissolve")}>Dissoudre la tontine</Button>
                  )}
                  {d.kind !== "TONTINE" && d.status !== "CLOSED" && (
                    <Button variant="destructive" onClick={() => setActing("close")}>Clôturer (fraude)</Button>
                  )}
                  {d.status === "CLOSED" && !d.dissolved_at && teamClosed && (
                    <Button variant="outline" onClick={() => setActing("reopen")}>Rouvrir</Button>
                  )}
                </div>
              )}
            </div>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{detail.error ?? "Chargement…"}</p>
          )}
        </SheetContent>
      </Sheet>
      <ReasonDialog open={acting !== null} onOpenChange={(o) => !o && setActing(null)}
        destructive={acting !== "reopen"}
        title={acting ? DIALOG[acting].title : ""} description={acting ? DIALOG[acting].description : undefined}
        confirm={acting ? DIALOG[acting].confirm : ""}
        onConfirm={async (reason) => {
          if (!acting || !selected) return
          await act(`/admin/kory/pots/${selected}/${acting}`, { body: { reason } },
            acting === "close" ? "Collecte clôturée" : acting === "reopen" ? "Collecte rouverte" : "Tontine dissoute")
          detail.reload(); list.reload()
        }} />
    </ConsoleShell>
  )
}
