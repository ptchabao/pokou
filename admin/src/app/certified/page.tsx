"use client"

import * as React from "react"
import { toast } from "sonner"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { ReasonDialog } from "@/components/reason-dialog"
import { Fields, SearchInput, Section, act, useTabParam } from "@/components/service-ui"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useApi, useAuth } from "@/lib/auth"
import { when } from "@/lib/api"
import { openMedia } from "@/lib/download"
import { StatusBadge } from "@/lib/labels"
import type { Paged } from "@/lib/types"

type Application = {
  id: number; user_id: number; verified_name: string | null; phone: string | null; business_name: string
  activity: string | null; city: string | null; document_media_id: number | null; status: string
  review_note: string | null; submitted_at: string; review_due_at: string; overdue: boolean
  reviewed_at: string | null; reviewer: string | null
}
type ApplicationDetail = Application & {
  subscription: { status: string; plan: string; current_period_end: string | null } | null
  history: { action: string; actor: string | null; decision: string | null; note: string | null; at: string }[]
}
type Subscription = {
  user_id: number; name: string | null; phone: string | null; plan: string; status: string
  wallet_holder_name: string | null; badge_visible: boolean; trial_ends_at: string | null
  current_period_end: string | null; first_paid_at: string | null; updated_at: string | null
}
type Decision = "APPROVE" | "CORRECTION" | "REJECT"

const PLANS: Record<string, string> = {
  PARTICULIER_MONTHLY: "Particulier, mensuel", PARTICULIER_YEARLY: "Particulier, annuel", PRO_MONTHLY: "Pro, mensuel",
}
const DECISIONS: Record<Decision, string> = { APPROVE: "Approuvé", CORRECTION: "À corriger", REJECT: "Refusé" }
const PRO_DIALOG: Record<Decision, { title: string; confirm: string }> = {
  APPROVE: { title: "Approuver ce dossier Pro ?", confirm: "Approuver" },
  CORRECTION: { title: "Demander une correction ?", confirm: "Envoyer" },
  REJECT: { title: "Refuser ce dossier ?", confirm: "Refuser" },
}
const SUB_DIALOG: Record<Decision, { title: string; description: string; confirm: string }> = {
  APPROVE: {
    title: "Activer le badge malgré la différence de nom ?",
    description: "À faire seulement après vérification (pièce présentée, nom abrégé…). Le motif part au journal d'audit et la personne est prévenue.",
    confirm: "Activer le badge",
  },
  CORRECTION: {
    title: "Demander à la personne de corriger son nom ?",
    description: "Elle reçoit ce message ; l'app lui propose déjà « Corriger mon nom ». Ne donne jamais le nom du titulaire du wallet.",
    confirm: "Envoyer",
  },
  REJECT: {
    title: "Retirer le badge ?",
    description: "Le badge est masqué ; le mode preuve reste ouvert tant que l'abonnement court. La personne reçoit le motif.",
    confirm: "Retirer le badge",
  },
}

export default function CertifiedPage() {
  const { can } = useAuth()
  const manage = can("certified.manage")
  const [tab, setTab] = useTabParam("pro", ["pro", "subscriptions"])

  const [astatus, setAstatus] = React.useState("PENDING")
  const [aq, setAq] = React.useState("")
  const [apage, setApage] = React.useState(1)
  const ap = new URLSearchParams({ status: astatus, page: String(apage), size: "25" })
  if (aq) ap.set("q", aq)
  const applications = useApi<Paged<Application>>(tab === "pro" ? `/admin/certified/applications?${ap}` : null)
  const [appId, setAppId] = React.useState<number | null>(null)
  const application = useApi<ApplicationDetail>(appId ? `/admin/certified/applications/${appId}` : null)
  const ad = appId && application.data?.id === appId ? application.data : null

  const [sstatus, setSstatus] = React.useState("NAME_MISMATCH")
  const [sq, setSq] = React.useState("")
  const [spage, setSpage] = React.useState(1)
  const sp = new URLSearchParams({ page: String(spage), size: "25" })
  if (sq) sp.set("q", sq)
  if (sstatus !== "all") sp.set("status", sstatus)
  const subs = useApi<Paged<Subscription>>(tab === "subscriptions" ? `/admin/certified/subscriptions?${sp}` : null)

  const [pending, setPending] = React.useState<
    { kind: "pro"; id: number; decision: Decision } | { kind: "sub"; s: Subscription; decision: Decision } | null
  >(null)

  async function showDocument(id: number | null) {
    if (!id) return
    try { await openMedia(id) } catch (e) { toast.error((e as Error).message) }
  }

  function proActions(a: Application) {
    if (!manage || a.status !== "PENDING") return null
    return (
      <div className="flex flex-wrap justify-end gap-2" onClick={(e) => e.stopPropagation()}>
        <Button size="sm" variant="ghost" onClick={() => setPending({ kind: "pro", id: a.id, decision: "REJECT" })}>Refuser</Button>
        <Button size="sm" variant="outline" onClick={() => setPending({ kind: "pro", id: a.id, decision: "CORRECTION" })}>À corriger</Button>
        <Button size="sm" onClick={() => setPending({ kind: "pro", id: a.id, decision: "APPROVE" })}>Approuver</Button>
      </div>
    )
  }

  const dialog = !pending ? null
    : pending.kind === "pro"
      ? { ...PRO_DIALOG[pending.decision], optional: pending.decision === "APPROVE",
          description: pending.decision === "APPROVE" ? "La personne pourra souscrire la formule Pro." : "La personne reçoit ce message : dis-lui précisément ce qui ne va pas." }
      : { ...SUB_DIALOG[pending.decision], optional: false }

  return (
    <ConsoleShell title="Pokou certifié" permission="certified.view">
      <Tabs value={tab} onValueChange={setTab}>
        <TabsList>
          <TabsTrigger value="pro">Dossiers Pro</TabsTrigger>
          <TabsTrigger value="subscriptions">Abonnements</TabsTrigger>
        </TabsList>

        <TabsContent value="pro" className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <Tabs value={astatus} onValueChange={(v) => { setAstatus(v); setApage(1) }}>
              <TabsList>
                <TabsTrigger value="PENDING">À examiner</TabsTrigger>
                <TabsTrigger value="CORRECTION">À corriger</TabsTrigger>
                <TabsTrigger value="APPROVED">Approuvés</TabsTrigger>
                <TabsTrigger value="REJECTED">Refusés</TabsTrigger>
                <TabsTrigger value="ALL">Tous</TabsTrigger>
              </TabsList>
            </Tabs>
            <SearchInput placeholder="Entreprise, titulaire, numéro…" onSearch={(v) => { setAq(v); setApage(1) }} />
          </div>
          <p className="text-sm text-muted-foreground">Réponse promise sous 48 h ; le plus proche de son échéance en premier.</p>
          {applications.error && <p className="text-sm text-destructive">{applications.error}</p>}
          <SimpleTable rows={applications.data?.items ?? null} page={apage} total={applications.data?.total} size={25} onPage={setApage}
            onRowClick={(a) => setAppId(a.id)} empty="Aucun dossier ici." illustration="certified"
            columns={[
              { header: "Entreprise", cell: (a) => (
                <div className="flex flex-col"><span className="font-medium">{a.business_name}</span>
                  <span className="text-xs text-muted-foreground">{[a.activity, a.city].filter(Boolean).join(" · ")}</span></div>
              ) },
              { header: "Titulaire", cell: (a) => a.verified_name ?? "—" },
              { header: "Échéance", cell: (a) => (
                <div className="flex items-center gap-2">{when(a.review_due_at)}{a.overdue && <Badge variant="destructive">En retard</Badge>}</div>
              ) },
              { header: "Statut", cell: (a) => <StatusBadge status={a.status} /> },
              { header: "", className: "text-right", cell: proActions },
            ]} />
        </TabsContent>

        <TabsContent value="subscriptions" className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput placeholder="Nom ou numéro…" onSearch={(v) => { setSq(v); setSpage(1) }} />
            <Select value={sstatus} onValueChange={(v) => { setSstatus(v); setSpage(1) }}>
              <SelectTrigger className="w-52"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="NAME_MISMATCH">Noms différents</SelectItem>
                <SelectItem value="ACTIVE">Actifs</SelectItem>
                <SelectItem value="TRIAL">Essai</SelectItem>
                <SelectItem value="PAUSED">En pause</SelectItem>
                <SelectItem value="EXPIRED">Expirés</SelectItem>
                <SelectItem value="all">Tous</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <p className="text-sm text-muted-foreground">
            Le badge s&apos;allume seul quand le nom du titulaire du wallet qui paie correspond au nom du profil.
            Les « noms différents » attendent une décision humaine.
          </p>
          {subs.error && <p className="text-sm text-destructive">{subs.error}</p>}
          <SimpleTable rows={subs.data?.items ?? null} page={spage} total={subs.data?.total} size={25} onPage={setSpage}
            empty="Aucun abonnement ici." illustration="certified"
            columns={[
              { header: "Personne", cell: (s) => (
                <div className="flex flex-col"><span className="font-medium">{s.name ?? "—"}</span><span className="text-xs text-muted-foreground">{s.phone}</span></div>
              ) },
              { header: "Titulaire du wallet", cell: (s) => s.wallet_holder_name ?? "—" },
              { header: "Formule", cell: (s) => PLANS[s.plan] ?? s.plan },
              { header: "Jusqu'au", cell: (s) => when(s.current_period_end ?? s.trial_ends_at) },
              { header: "Badge", cell: (s) => s.badge_visible ? <Badge variant="secondary">Visible</Badge> : "—" },
              { header: "Statut", cell: (s) => <StatusBadge status={s.status} /> },
              { header: "", className: "text-right", cell: (s) => manage ? (
                <div className="flex flex-wrap justify-end gap-2">
                  {s.status === "NAME_MISMATCH" && <>
                    <Button size="sm" variant="outline" onClick={() => setPending({ kind: "sub", s, decision: "CORRECTION" })}>À corriger</Button>
                    <Button size="sm" onClick={() => setPending({ kind: "sub", s, decision: "APPROVE" })}>Approuver</Button>
                  </>}
                  {s.status === "ACTIVE" && s.badge_visible && (
                    <Button size="sm" variant="ghost" className="text-destructive" onClick={() => setPending({ kind: "sub", s, decision: "REJECT" })}>Retirer le badge</Button>
                  )}
                </div>
              ) : null },
            ]} />
        </TabsContent>
      </Tabs>

      <Sheet open={appId !== null} onOpenChange={(o) => !o && setAppId(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{ad?.business_name ?? "Dossier Pro"}</SheetTitle>
            <SheetDescription>{ad ? `Déposé le ${when(ad.submitted_at)}` : ""}</SheetDescription>
          </SheetHeader>
          {ad ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div className="flex items-center gap-2"><StatusBadge status={ad.status} />{ad.overdue && <Badge variant="destructive">En retard</Badge>}</div>
              <Fields rows={[
                ["Activité", ad.activity],
                ["Ville", ad.city],
                ["Titulaire (nom vérifié)", ad.verified_name],
                ["Téléphone", ad.phone],
                ["Justificatif", ad.document_media_id
                  ? <Button size="sm" variant="link" className="h-auto px-0" onClick={() => showDocument(ad.document_media_id)}>Ouvrir le justificatif</Button> : "—"],
                ["Échéance d'examen", when(ad.review_due_at)],
                ["Abonnement certifié", ad.subscription ? `${PLANS[ad.subscription.plan] ?? ad.subscription.plan} · ${ad.subscription.status}` : "Aucun"],
              ]} />
              {ad.review_note && <p className="text-muted-foreground">Dernière note : « {ad.review_note} »{ad.reviewer ? ` — ${ad.reviewer}` : ""}</p>}
              <Section title="Historique des décisions">
                {ad.history.length === 0 ? <span className="text-muted-foreground">Aucune décision encore.</span> : (
                  <ul className="flex flex-col gap-1">
                    {ad.history.map((h, i) => (
                      <li key={i}>{DECISIONS[(h.decision ?? "") as Decision] ?? h.decision} · {h.actor ?? "—"} · {when(h.at)}
                        {h.note ? <span className="text-muted-foreground"> — « {h.note} »</span> : null}</li>
                    ))}
                  </ul>
                )}
              </Section>
              {proActions(ad)}
            </div>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{application.error ?? "Chargement…"}</p>
          )}
        </SheetContent>
      </Sheet>

      <ReasonDialog open={pending !== null} onOpenChange={(o) => !o && setPending(null)}
        optional={dialog?.optional} destructive={pending?.decision === "REJECT"}
        title={dialog?.title ?? ""} description={dialog?.description} confirm={dialog?.confirm ?? ""}
        onConfirm={async (note) => {
          if (!pending) return
          if (pending.kind === "pro") {
            await act(`/admin/certified/pro/${pending.id}/review`, { body: { decision: pending.decision, note: note || null } }, "Décision enregistrée")
            applications.reload(); application.reload()
          } else {
            await act(`/admin/certified/subscriptions/${pending.s.user_id}/review`, { body: { decision: pending.decision, note } }, "Décision enregistrée")
            subs.reload()
          }
        }} />
    </ConsoleShell>
  )
}
