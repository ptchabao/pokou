"use client"

import * as React from "react"
import { IconPlus } from "@tabler/icons-react"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { ReasonDialog } from "@/components/reason-dialog"
import { Fields, SearchInput, Section, TeamActions, act, useTabParam } from "@/components/service-ui"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useApi, useAuth } from "@/lib/auth"
import { fcfa, when } from "@/lib/api"
import { AUDIT_ACTIONS } from "@/lib/audit-labels"
import { StatusBadge } from "@/lib/labels"
import type { Paged } from "@/lib/types"

type Order = {
  id: number; status: string; pharmacy: string | null; pharmacy_id: number; patient: string | null
  courier: string | null; total: number | null; refund_due: number; refund_pending: boolean
  created_at: string; updated_at: string | null
}
type OrderDetail = Order & {
  medicines_total: number | null; delivery_price: number | null; has_prescription: boolean
  original_required: boolean; patient_paid_declared_at: string | null; payment_not_received_at: string | null
  missing_amount: number | null; missing_choice: string | null; refund_requested_at: string | null
  refund_reason: string | null; refund_confirmed_at: string | null; courier_paid_at: string | null
  delivered_at: string | null; can_cancel: boolean; refund_on_cancel: boolean
  timeline: { status: string; by: string; at: string; note: string | null }[]
}
type Pharmacy = {
  id: number; name: string; country: string; address: string; phone: string; status: string
  suspension_reason: string | null; wallet_phone: string | null; wallet_verified: boolean
  subscription_plan: string | null; subscription_until: string | null; subscription_active: boolean
  credit_balance: number; is_on_duty: boolean; created_at: string
}
type PharmacyDetail = Pharmacy & {
  opening_hours: string | null
  staff: { name: string | null; phone: string | null; role: string }[]
  couriers: { name: string | null; status: string }[]
  orders_by_status: Record<string, number>; refunds_pending: number
  team_actions: { action: string; actor: string | null; reason: string | null; at: string }[]
}
type Courier = {
  user_id: number; name: string | null; phone: string | null; country: string; city: string | null
  zones: string | null; wallet_phone: string | null; status: string; defaults_count: number
  rules_accepted_at: string | null; validated_at: string | null; suspended_at: string | null
  trial_ends_at: string | null; membership_until: string | null; current_pack: string | null; created_at: string
}
type Waitlist = { country: string; city: string; role: string; count: number }

const ORDER_STATUSES = ["SUBMITTED", "QUOTED", "ACCEPTED", "PAID", "READY", "IN_DELIVERY", "DELIVERED", "REJECTED", "EXPIRED", "CANCELLED"]
const PLANS: Record<string, string> = { WETRI: "Wétri (mensuel)", EPE: "ÉPÉ (annuel)" }

type Pending =
  | { kind: "cancel"; order: OrderDetail }
  | { kind: "pharmacy"; id: number; action: "suspend" | "reactivate" | "exclude" }
  | { kind: "courier"; c: Courier; action: "reject" | "request-info" | "suspend" | "reinstate" }

const COURIER_DIALOG = {
  reject: { title: "Refuser cette candidature ?", description: "Le candidat reçoit le motif dans ses notifications.", confirm: "Refuser", destructive: true },
  "request-info": { title: "Demander des compléments ?", description: "La candidature reste en attente ; le candidat la complète depuis l'app. Écris précisément ce qui manque.", confirm: "Envoyer", destructive: false },
  suspend: { title: "Suspendre ce coursier ?", description: "Il ne peut plus accepter de course ; il est prévenu avec le motif.", confirm: "Suspendre", destructive: true },
  reinstate: { title: "Réactiver ce coursier ?", description: "Il retrouve son essai ou son adhésion, et son compteur de défauts repart de zéro.", confirm: "Réactiver", destructive: false },
} as const

const PHARMACY_DIALOG = {
  suspend: { title: "Suspendre cette officine ?", description: "Elle disparaît de l'annuaire et ne reçoit plus d'ordonnance. Son équipe est prévenue.", confirm: "Suspendre", destructive: true },
  reactivate: { title: "Réactiver cette officine ?", description: "Si un remboursement ou une course reste impayé, la règle HON-35 la suspendra de nouveau.", confirm: "Réactiver", destructive: false },
  exclude: { title: "Exclure cette officine ?", description: "Décision définitive de l'équipe (HON-35) : elle ne se lève qu'à la main.", confirm: "Exclure", destructive: true },
} as const

const EMPTY_PHARMACY = { country: "TG", name: "", address: "", phone: "", opening_hours: "", latitude: "", longitude: "", wallet_phone: "", titulaire_phone: "" }

export default function HonamPage() {
  const { can } = useAuth()
  const manage = can("honam.manage")
  const [tab, setTab] = useTabParam("orders", ["orders", "pharmacies", "couriers", "waitlist"])

  // Commandes
  const [oq, setOq] = React.useState("")
  const [ostatus, setOstatus] = React.useState("all")
  const [refundOnly, setRefundOnly] = React.useState(false)
  const [opage, setOpage] = React.useState(1)
  const op = new URLSearchParams({ page: String(opage), size: "25" })
  if (oq) op.set("q", oq)
  if (ostatus !== "all") op.set("status", ostatus)
  if (refundOnly) op.set("refund", "true")
  const orders = useApi<Paged<Order>>(`/admin/honam/orders/search?${op}`)
  const [orderId, setOrderId] = React.useState<number | null>(null)
  const order = useApi<OrderDetail>(orderId ? `/admin/honam/orders/${orderId}` : null)
  const od = orderId && order.data?.id === orderId ? order.data : null

  // Officines
  const [pq, setPq] = React.useState("")
  const [pstatus, setPstatus] = React.useState("all")
  const [ppage, setPpage] = React.useState(1)
  const pp = new URLSearchParams({ page: String(ppage), size: "25" })
  if (pq) pp.set("q", pq)
  if (pstatus !== "all") pp.set("status", pstatus)
  const pharmacies = useApi<Paged<Pharmacy>>(`/admin/honam/pharmacies/search?${pp}`)
  const [pharmacyId, setPharmacyId] = React.useState<number | null>(null)
  const pharmacy = useApi<PharmacyDetail>(pharmacyId ? `/admin/honam/pharmacies/${pharmacyId}` : null)
  const pd = pharmacyId && pharmacy.data?.id === pharmacyId ? pharmacy.data : null
  const [creating, setCreating] = React.useState<typeof EMPTY_PHARMACY | null>(null)
  const [busy, setBusy] = React.useState(false)

  // Coursiers
  const [cq, setCq] = React.useState("")
  const [cstatus, setCstatus] = React.useState("PENDING")
  const [cpage, setCpage] = React.useState(1)
  const cp = new URLSearchParams({ page: String(cpage), size: "25" })
  if (cq) cp.set("q", cq)
  if (cstatus !== "all") cp.set("status", cstatus)
  const couriers = useApi<Paged<Courier>>(`/admin/honam/couriers?${cp}`)
  const waitlist = useApi<{ items: Waitlist[] }>(manage && tab === "waitlist" ? "/admin/honam/waitlist" : null)

  const [pending, setPending] = React.useState<Pending | null>(null)
  const [refund, setRefund] = React.useState(true)

  async function validateCourier(c: Courier) {
    await act(`/admin/honam/couriers/${c.user_id}/validate`, {}, `${c.name ?? "Coursier"} accepté : essai lancé`).catch(() => {})
    couriers.reload()
  }

  async function verifyWallet(id: number) {
    await act(`/admin/honam/pharmacies/${id}/verify-wallet`, {}, "Wallet validé : l'officine peut recevoir des paiements").catch(() => {})
    pharmacy.reload(); pharmacies.reload()
  }

  async function createPharmacy() {
    if (!creating) return
    setBusy(true)
    try {
      const created = await act<{ id: number }>("/admin/honam/pharmacies", {
        body: {
          ...creating,
          opening_hours: creating.opening_hours || null,
          latitude: Number(creating.latitude), longitude: Number(creating.longitude),
        },
      }, "Officine créée")
      setCreating(null)
      pharmacies.reload()
      setPharmacyId(created.id)
    } catch { /* déjà signalé */ } finally { setBusy(false) }
  }

  const dialog = pending?.kind === "cancel"
    ? { title: "Annuler cette commande (litige) ?", confirm: "Annuler la commande", destructive: true,
        description: pending.order.refund_on_cancel && refund
          ? "Le patient a payé l'officine : le remboursement complet devient dû (2 h, sinon suspension automatique de l'officine). Patient et officine voient ce motif."
          : "Patient et officine sont prévenus et voient ce motif." }
    : pending?.kind === "pharmacy" ? PHARMACY_DIALOG[pending.action]
    : pending?.kind === "courier" ? COURIER_DIALOG[pending.action]
    : null

  function courierActions(c: Courier) {
    if (!manage) return null
    const stop = (e: React.MouseEvent) => e.stopPropagation()
    return (
      <div className="flex flex-wrap justify-end gap-2" onClick={stop}>
        {c.status === "PENDING" && <>
          <Button size="sm" variant="ghost" onClick={() => setPending({ kind: "courier", c, action: "reject" })}>Refuser</Button>
          <Button size="sm" variant="outline" onClick={() => setPending({ kind: "courier", c, action: "request-info" })}>Compléments</Button>
          <Button size="sm" onClick={() => validateCourier(c)}>Accepter</Button>
        </>}
        {["TRIAL", "MEMBER", "ENDED"].includes(c.status) && (
          <Button size="sm" variant="destructive" onClick={() => setPending({ kind: "courier", c, action: "suspend" })}>Suspendre</Button>
        )}
        {c.status === "SUSPENDED" && (
          <Button size="sm" variant="outline" onClick={() => setPending({ kind: "courier", c, action: "reinstate" })}>Réactiver</Button>
        )}
      </div>
    )
  }

  return (
    <ConsoleShell title="Honam · pharmacie" permission="honam.view"
      actions={manage && tab === "pharmacies" ? (
        <Button size="sm" onClick={() => setCreating({ ...EMPTY_PHARMACY })}><IconPlus className="size-4" />Nouvelle officine</Button>
      ) : undefined}>
      <Tabs value={tab} onValueChange={setTab}>
        <TabsList>
          <TabsTrigger value="orders">Commandes</TabsTrigger>
          <TabsTrigger value="pharmacies">Officines</TabsTrigger>
          <TabsTrigger value="couriers">Coursiers</TabsTrigger>
          {manage && <TabsTrigger value="waitlist">Liste d&apos;attente</TabsTrigger>}
        </TabsList>

        <TabsContent value="orders" className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">
            Données de santé protégées : la console ne montre jamais l&apos;ordonnance, les produits ni les notes du patient — seulement les étapes et les montants.
          </p>
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput placeholder="N° de commande ou officine…" onSearch={(v) => { setOq(v); setOpage(1) }} />
            <Select value={ostatus} onValueChange={(v) => { setOstatus(v); setOpage(1) }}>
              <SelectTrigger className="w-52"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Toutes les étapes</SelectItem>
                {ORDER_STATUSES.map((s) => <SelectItem key={s} value={s}><StatusBadge status={s} /></SelectItem>)}
              </SelectContent>
            </Select>
            <div className="flex items-center gap-2">
              <Switch id="refund" checked={refundOnly} onCheckedChange={(v) => { setRefundOnly(v); setOpage(1) }} />
              <Label htmlFor="refund">Remboursement en attente</Label>
            </div>
          </div>
          {orders.error && <p className="text-sm text-destructive">{orders.error}</p>}
          <SimpleTable rows={orders.data?.items ?? null} page={opage} total={orders.data?.total} size={25} onPage={setOpage}
            onRowClick={(o) => setOrderId(o.id)} empty="Aucune commande." illustration="honam"
            columns={[
              { header: "N°", cell: (o) => `#${o.id}` },
              { header: "Officine", cell: (o) => o.pharmacy ?? "—" },
              { header: "Patient", cell: (o) => o.patient ?? "—" },
              { header: "Total", cell: (o) => o.total !== null ? <span className="tabular-nums">{fcfa(o.total)}</span> : "—" },
              { header: "Étape", cell: (o) => (
                <div className="flex items-center gap-1"><StatusBadge status={o.status} />
                  {o.refund_pending && <Badge variant="destructive">Remboursement</Badge>}</div>
              ) },
              { header: "Créée le", cell: (o) => when(o.created_at) },
            ]} />
        </TabsContent>

        <TabsContent value="pharmacies" className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput placeholder="Nom, adresse, téléphone…" onSearch={(v) => { setPq(v); setPpage(1) }} />
            <Select value={pstatus} onValueChange={(v) => { setPstatus(v); setPpage(1) }}>
              <SelectTrigger className="w-52"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Toutes</SelectItem>
                <SelectItem value="TO_VALIDATE">À valider (wallet)</SelectItem>
                <SelectItem value="ACTIVE">Actives</SelectItem>
                <SelectItem value="SUSPENDED">Suspendues</SelectItem>
                <SelectItem value="EXCLUDED">Exclues</SelectItem>
              </SelectContent>
            </Select>
          </div>
          {pharmacies.error && <p className="text-sm text-destructive">{pharmacies.error}</p>}
          <SimpleTable rows={pharmacies.data?.items ?? null} page={ppage} total={pharmacies.data?.total} size={25} onPage={setPpage}
            onRowClick={(p) => setPharmacyId(p.id)} empty="Aucune officine." illustration="honam"
            columns={[
              { header: "Officine", cell: (p) => (
                <div className="flex flex-col"><span className="font-medium">{p.name}</span>
                  <span className="text-xs text-muted-foreground">{p.country} · {p.address}</span></div>
              ) },
              { header: "Wallet", cell: (p) => p.wallet_verified ? <Badge variant="secondary">Vérifié</Badge> : <Badge>À valider</Badge> },
              { header: "Abonnement", cell: (p) => p.subscription_active
                ? `${PLANS[p.subscription_plan ?? ""] ?? p.subscription_plan ?? "—"} · ${when(p.subscription_until)}`
                : <span className="text-muted-foreground">Aucun en cours</span> },
              { header: "Crédit", cell: (p) => <span className="tabular-nums">{fcfa(p.credit_balance)}</span> },
              { header: "Statut", cell: (p) => <StatusBadge status={p.status} /> },
            ]} />
        </TabsContent>

        <TabsContent value="couriers" className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput placeholder="Nom, numéro, ville…" onSearch={(v) => { setCq(v); setCpage(1) }} />
            <Select value={cstatus} onValueChange={(v) => { setCstatus(v); setCpage(1) }}>
              <SelectTrigger className="w-52"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Tous</SelectItem>
                <SelectItem value="PENDING">Candidatures</SelectItem>
                <SelectItem value="TRIAL">En essai</SelectItem>
                <SelectItem value="MEMBER">Membres</SelectItem>
                <SelectItem value="ENDED">Essai fini</SelectItem>
                <SelectItem value="SUSPENDED">Suspendus</SelectItem>
                <SelectItem value="REJECTED">Refusés</SelectItem>
              </SelectContent>
            </Select>
          </div>
          {couriers.error && <p className="text-sm text-destructive">{couriers.error}</p>}
          <SimpleTable rows={couriers.data?.items ?? null} page={cpage} total={couriers.data?.total} size={25} onPage={setCpage}
            empty="Aucun coursier ici." illustration="delivery"
            columns={[
              { header: "Coursier", cell: (c) => (
                <div className="flex flex-col"><span className="font-medium">{c.name ?? "—"}</span>
                  <span className="text-xs text-muted-foreground">{c.phone}</span></div>
              ) },
              { header: "Ville · zones", cell: (c) => (
                <span className="line-clamp-2 max-w-xs whitespace-normal">{[c.country, c.city, c.zones].filter(Boolean).join(" · ")}</span>
              ) },
              { header: "Mobile money", cell: (c) => c.wallet_phone ?? "—" },
              { header: "Règles d'or", cell: (c) => c.rules_accepted_at ? "Acceptées" : <span className="text-destructive">Non</span> },
              { header: "Défauts", cell: (c) => <span className={c.defaults_count ? "text-destructive tabular-nums" : "tabular-nums"}>{c.defaults_count}</span> },
              { header: "Statut", cell: (c) => (
                <div className="flex flex-col"><StatusBadge status={c.status} />
                  <span className="text-xs text-muted-foreground">{c.status === "PENDING" ? `depuis le ${when(c.created_at)}` : c.status === "SUSPENDED" ? when(c.suspended_at) : ""}</span></div>
              ) },
              { header: "", className: "text-right", cell: courierActions },
            ]} />
        </TabsContent>

        <TabsContent value="waitlist" className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">Où ouvrir ensuite : les inscrits sur la liste d&apos;attente, par ville.</p>
          <SimpleTable rows={waitlist.data?.items ?? null} empty="Personne sur la liste d'attente." illustration="delivery"
            columns={[
              { header: "Pays", cell: (w) => w.country },
              { header: "Ville", cell: (w) => w.city },
              { header: "Rôle", cell: (w) => w.role === "COURIER" ? "Coursier" : w.role === "PHARMACY" ? "Officine" : w.role === "PATIENT" ? "Patient" : w.role },
              { header: "Inscrits", cell: (w) => <span className="tabular-nums">{w.count}</span> },
            ]} />
        </TabsContent>
      </Tabs>

      <Sheet open={orderId !== null} onOpenChange={(o) => !o && setOrderId(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>Commande #{orderId}</SheetTitle>
            <SheetDescription>{od ? `${od.pharmacy ?? "—"} · ${when(od.created_at)}` : ""}</SheetDescription>
          </SheetHeader>
          {od ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div className="flex items-center gap-2"><StatusBadge status={od.status} />
                {od.refund_pending && <Badge variant="destructive">Remboursement attendu</Badge>}</div>
              <Fields rows={[
                ["Patient", od.patient],
                ["Officine", od.pharmacy],
                ["Coursier", od.courier],
                ["Médicaments", od.medicines_total !== null ? fcfa(od.medicines_total) : "—"],
                ["Livraison", od.delivery_price !== null ? fcfa(od.delivery_price) : "—"],
                ["Ordonnance", od.has_prescription ? "jointe (visible de l'officine seule)" : "—"],
                ["Original exigé", od.original_required ? "Oui" : "Non"],
                ["Paiement déclaré", when(od.patient_paid_declared_at)],
                ["Paiement non reçu", when(od.payment_not_received_at)],
                ["Livrée le", when(od.delivered_at)],
                ["Course payée", when(od.courier_paid_at)],
              ]} />
              {(od.refund_due > 0 || od.missing_amount !== null) && (
                <Section title="Remboursement">
                  <Fields rows={[
                    ["Montant dû", fcfa(od.refund_due)],
                    ["Produit manquant", od.missing_amount !== null ? `${fcfa(od.missing_amount)}${od.missing_choice ? ` · choix : ${od.missing_choice === "KEEP" ? "garder le reste" : "tout annuler"}` : ""}` : "—"],
                    ["Demandé le", when(od.refund_requested_at)],
                    ["Motif", od.refund_reason],
                    ["Reçu (confirmé par le patient)", od.refund_confirmed_at ? when(od.refund_confirmed_at) : <span className="text-destructive">Pas encore</span>],
                  ]} />
                </Section>
              )}
              <Section title="Historique">
                <ol className="flex flex-col gap-1">
                  {od.timeline.map((e, i) => (
                    <li key={i} className="flex flex-col">
                      <span className="flex items-center gap-2"><StatusBadge status={e.status} /><span className="text-muted-foreground">{e.by} · {when(e.at)}</span></span>
                      {e.note && <span className="text-xs text-muted-foreground">{e.note}</span>}
                    </li>
                  ))}
                </ol>
              </Section>
              {manage && od.can_cancel && (od.status === "ACCEPTED" && od.refund_on_cancel ? (
                <div className="flex flex-col gap-2">
                  <span className="text-muted-foreground">Le patient a déclaré avoir payé, l&apos;officine ne l&apos;a pas confirmé :</span>
                  <div className="flex flex-wrap gap-2">
                    <Button variant="destructive" onClick={() => { setRefund(true); setPending({ kind: "cancel", order: od }) }}>Annuler et exiger le remboursement</Button>
                    <Button variant="outline" onClick={() => { setRefund(false); setPending({ kind: "cancel", order: od }) }}>Annuler sans remboursement</Button>
                  </div>
                </div>
              ) : (
                <Button variant="destructive" onClick={() => { setRefund(true); setPending({ kind: "cancel", order: od }) }}>Annuler pour litige</Button>
              ))}
            </div>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{order.error ?? "Chargement…"}</p>
          )}
        </SheetContent>
      </Sheet>

      <Sheet open={pharmacyId !== null} onOpenChange={(o) => !o && setPharmacyId(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{pd?.name ?? "Officine"}</SheetTitle>
            <SheetDescription>{pd ? `${pd.country} · ${pd.address}` : ""}</SheetDescription>
          </SheetHeader>
          {pd ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div className="flex items-center gap-2"><StatusBadge status={pd.status} />
                {pd.is_on_duty && <Badge variant="outline">De garde</Badge>}</div>
              {pd.suspension_reason && <p className="text-destructive">{pd.suspension_reason}</p>}
              <Fields rows={[
                ["Téléphone", pd.phone],
                ["Horaires", pd.opening_hours],
                ["Wallet", pd.wallet_phone ? `${pd.wallet_phone} · ${pd.wallet_verified ? "vérifié" : "à valider"}` : "—"],
                ["Abonnement", pd.subscription_plan ? `${PLANS[pd.subscription_plan] ?? pd.subscription_plan} jusqu'au ${when(pd.subscription_until)}` : "Aucun"],
                ["Abonnement en cours", pd.subscription_active ? "Oui" : <span className="text-destructive">Non</span>],
                ["Crédit prépayé", fcfa(pd.credit_balance)],
                ["Remboursements en attente", pd.refunds_pending],
                ["Inscrite le", when(pd.created_at)],
              ]} />
              <Section title="Équipe de l'officine">
                {pd.staff.map((s, i) => <span key={i}>{s.name ?? "—"} · {s.phone ?? ""} <span className="text-muted-foreground">({s.role === "TITULAIRE" ? "titulaire" : "collaborateur"})</span></span>)}
              </Section>
              <Section title="Commandes">
                {Object.keys(pd.orders_by_status).length === 0 ? <span className="text-muted-foreground">Aucune.</span> : (
                  <div className="flex flex-wrap gap-2">
                    {Object.entries(pd.orders_by_status).map(([s, n]) => <span key={s} className="flex items-center gap-1"><StatusBadge status={s} /><span className="tabular-nums">{n}</span></span>)}
                  </div>
                )}
              </Section>
              {pd.couriers.length > 0 && (
                <Section title="Coursiers rattachés">
                  {pd.couriers.map((c, i) => <span key={i} className="flex items-center gap-2">{c.name ?? "—"} <StatusBadge status={c.status} /></span>)}
                </Section>
              )}
              <Section title="Actions de l'équipe">
                <TeamActions items={pd.team_actions} labels={AUDIT_ACTIONS} />
              </Section>
              {manage && (
                <div className="flex flex-wrap gap-2">
                  {!pd.wallet_verified && pd.status !== "EXCLUDED" && <Button onClick={() => verifyWallet(pd.id)}>Valider l&apos;inscription (wallet)</Button>}
                  {pd.status === "ACTIVE" && <Button variant="destructive" onClick={() => setPending({ kind: "pharmacy", id: pd.id, action: "suspend" })}>Suspendre</Button>}
                  {pd.status !== "ACTIVE" && <Button variant="outline" onClick={() => setPending({ kind: "pharmacy", id: pd.id, action: "reactivate" })}>Réactiver</Button>}
                  {pd.status !== "EXCLUDED" && <Button variant="ghost" className="text-destructive" onClick={() => setPending({ kind: "pharmacy", id: pd.id, action: "exclude" })}>{pd.wallet_verified ? "Exclure" : "Refuser l'inscription"}</Button>}
                </div>
              )}
            </div>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{pharmacy.error ?? "Chargement…"}</p>
          )}
        </SheetContent>
      </Sheet>

      <ReasonDialog open={pending !== null} onOpenChange={(o) => !o && setPending(null)}
        title={dialog?.title ?? ""} description={dialog?.description} confirm={dialog?.confirm ?? ""}
        destructive={dialog?.destructive}
        onConfirm={async (reason) => {
          if (!pending) return
          if (pending.kind === "cancel") {
            await act(`/admin/honam/orders/${pending.order.id}/cancel`, { body: { reason, refund } }, "Commande annulée")
            order.reload(); orders.reload()
          } else if (pending.kind === "pharmacy") {
            await act(`/admin/honam/pharmacies/${pending.id}/${pending.action}`, { body: { reason } },
              pending.action === "suspend" ? "Officine suspendue" : pending.action === "exclude" ? "Officine exclue" : "Officine réactivée")
            pharmacy.reload(); pharmacies.reload()
          } else {
            await act(`/admin/honam/couriers/${pending.c.user_id}/${pending.action}`, { body: { reason } }, "Décision enregistrée")
            couriers.reload()
          }
        }} />

      <Dialog open={creating !== null} onOpenChange={(o) => !o && setCreating(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Nouvelle officine</DialogTitle>
            <DialogDescription>Le titulaire doit déjà avoir installé Pokou avec son numéro. Le wallet sera à valider ensuite.</DialogDescription>
          </DialogHeader>
          {creating && (
            <div className="grid grid-cols-2 gap-3">
              {([
                ["name", "Nom", 2], ["address", "Adresse", 2], ["country", "Pays (TG, CI…)", 1], ["phone", "Téléphone", 1],
                ["opening_hours", "Horaires", 2], ["latitude", "Latitude", 1], ["longitude", "Longitude", 1],
                ["wallet_phone", "Wallet (mobile money)", 1], ["titulaire_phone", "Téléphone du titulaire", 1],
              ] as [keyof typeof EMPTY_PHARMACY, string, number][]).map(([key, label, span]) => (
                <div key={key} className={`flex flex-col gap-1 ${span === 2 ? "col-span-2" : ""}`}>
                  <Label htmlFor={`ph-${key}`}>{label}</Label>
                  <Input id={`ph-${key}`} value={creating[key]} maxLength={key === "country" ? 2 : 255}
                    onChange={(e) => setCreating({ ...creating, [key]: key === "country" ? e.target.value.toUpperCase() : e.target.value })} />
                </div>
              ))}
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreating(null)}>Annuler</Button>
            <Button disabled={busy || !creating || !creating.name || !creating.address || !creating.phone || !creating.wallet_phone
              || !creating.titulaire_phone || creating.country.length !== 2
              || isNaN(Number(creating.latitude)) || isNaN(Number(creating.longitude)) || !creating.latitude || !creating.longitude}
              onClick={createPharmacy}>Créer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </ConsoleShell>
  )
}
