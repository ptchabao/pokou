"use client"

import * as React from "react"
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
import { toast } from "sonner"
import { useApi, useAuth } from "@/lib/auth"
import { fcfa, when } from "@/lib/api"
import { AUDIT_ACTIONS } from "@/lib/audit-labels"
import { mediaIdOf, openMedia } from "@/lib/download"
import { StatusBadge } from "@/lib/labels"
import type { Paged } from "@/lib/types"

type Product = { id: number; name: string; price: number; currency: string; seller_id: number; seller_name: string
  is_active: boolean; deleted_by_seller: boolean; created_at: string }
type ProductDetail = {
  id: number; name: string; description: string | null; category: string; location: string | null
  price: number; currency: string; image_media_id: number | null; is_active: boolean; deleted_by_seller: boolean
  sold_at: string | null; created_at: string
  seller: { id: number; name: string | null; phone: string | null; is_certified_seller: boolean; products: number }
  boosts: { id: number; days: number | null; starts_at: string | null; expires_at: string | null; active: boolean; status_moderation: string | null; impressions: number; contacts: number }[]
  team_actions: { action: string; actor: string | null; reason: string | null; is_active: boolean | null; at: string }[]
}
type Seller = { id: number; name: string; phone: string | null; is_active: boolean; is_certified_seller: boolean
  certified_seller_until: string | null; products: number; hidden_products: number; rating: number | null; reviews: number }
type Verification = {
  id: number; seller_name: string; status: string; plan: string | null; duration_days: number | null
  identity_media_url: string | null; payment_status: string | null; reviewer_name: string | null
  review_note: string | null; created_at: string
}
type Boost = { id: number; product_id: number | null; product: string | null; seller: string | null; city: string | null
  days: number | null; starts_at: string | null; expires_at: string | null; active: boolean; status_moderation: string | null
  impressions: number; status_views: number; contacts: number }
type Ad = { id: number; advertiser_name: string; title: string; body: string; media_url: string | null; placement: string
  status: string; created_at: string; starts_at: string | null; expires_at: string | null }
type Review = { id: number; seller: string | null; author: string | null; rating: number; comment: string | null; created_at: string }

const price = (n: number, currency: string) => (currency === "XOF" ? fcfa(n) : `${new Intl.NumberFormat("fr-FR").format(n)} ${currency}`)
const MODERATION: Record<string, string> = { PENDING: "Statut à relire", APPROVED: "Statut approuvé", REJECTED: "Statut refusé" }

type Pending =
  | { kind: "product"; id: number; hide: boolean }
  | { kind: "verification"; v: Verification; approved: boolean }
  | { kind: "boost"; id: number; approve: boolean }
  | { kind: "ad-reject"; ad: Ad }
  | { kind: "review"; r: Review }
  | { kind: "badge"; s: Seller }

export default function AssimePage() {
  const { can } = useAuth()
  const manage = can("assime.manage")
  const [tab, setTab] = useTabParam("products", ["products", "sellers", "verifications", "boosts", "ads", "reviews"])

  const [pq, setPq] = React.useState("")
  const [hiddenOnly, setHiddenOnly] = React.useState(false)
  const [ppage, setPpage] = React.useState(1)
  React.useEffect(() => setPpage(1), [pq, hiddenOnly])
  const products = useApi<{ items: Product[]; total: number }>(tab === "products"
    ? `/admin/marketplace/products?limit=50&page=${ppage}${pq ? `&q=${encodeURIComponent(pq)}` : ""}${hiddenOnly ? "&only_inactive=true" : ""}` : null)
  const [productId, setProductId] = React.useState<number | null>(null)
  const product = useApi<ProductDetail>(productId ? `/admin/marketplace/products/${productId}` : null)
  const pd = productId && product.data?.id === productId ? product.data : null

  const [sq, setSq] = React.useState("")
  const [certified, setCertified] = React.useState("all")
  const [spage, setSpage] = React.useState(1)
  const sp = new URLSearchParams({ page: String(spage), size: "25" })
  if (sq) sp.set("q", sq)
  if (certified !== "all") sp.set("certified", certified)
  const sellers = useApi<Paged<Seller>>(tab === "sellers" ? `/admin/marketplace/sellers?${sp}` : null)

  const [vstatus, setVstatus] = React.useState("PENDING")
  const verifications = useApi<{ items: Verification[] }>(tab === "verifications" ? `/admin/marketplace/verifications?status=${vstatus}` : null)

  const [bstate, setBstate] = React.useState("pending")
  const [bpage, setBpage] = React.useState(1)
  const boosts = useApi<Paged<Boost>>(tab === "boosts" ? `/admin/marketplace/boosts?state=${bstate}&page=${bpage}&size=25` : null)

  const [astatus, setAstatus] = React.useState("PAID")
  const ads = useApi<{ items: Ad[] }>(tab === "ads" ? `/admin/marketplace/ads?status=${astatus}` : null)
  const [approvingAd, setApprovingAd] = React.useState<Ad | null>(null)
  const [adDays, setAdDays] = React.useState("7")

  const [rq, setRq] = React.useState("")
  const [maxRating, setMaxRating] = React.useState("2")
  const [rpage, setRpage] = React.useState(1)
  const rp = new URLSearchParams({ page: String(rpage), size: "25", max_rating: maxRating })
  if (rq) rp.set("q", rq)
  const reviews = useApi<Paged<Review>>(tab === "reviews" ? `/admin/marketplace/reviews?${rp}` : null)

  const [pending, setPending] = React.useState<Pending | null>(null)

  async function showMedia(id: number | null) {
    if (!id) return
    try { await openMedia(id) } catch (e) { toast.error((e as Error).message) }
  }

  async function restore(id: number) {
    await act(`/admin/marketplace/products/${id}`, { method: "PUT", body: { is_active: true, reason: null } }, "Annonce rétablie").catch(() => {})
    product.reload(); products.reload()
  }

  async function approveAd() {
    if (!approvingAd) return
    try {
      await act(`/admin/marketplace/ads/${approvingAd.id}`, { method: "PUT", body: { approved: true, duration_days: Number(adDays) } }, "Campagne diffusée")
      setApprovingAd(null); ads.reload()
    } catch { /* déjà signalé */ }
  }

  const dialog = !pending ? null
    : pending.kind === "product" ? { title: "Masquer cette annonce ?", description: "Elle disparaît du marché ; l'équipe pourra la rétablir. Le motif est gardé au journal.", confirm: "Masquer", destructive: true, optional: false }
    : pending.kind === "verification" ? (pending.approved
      ? { title: "Accorder le badge vendeur vérifié ?", description: undefined, confirm: "Approuver", destructive: false, optional: true }
      : { title: "Refuser ce dossier ?", description: "Le vendeur reçoit le motif : dis-lui quoi corriger.", confirm: "Refuser", destructive: true, optional: false })
    : pending.kind === "boost" ? (pending.approve
      ? { title: "Approuver ce statut sponsorisé ?", description: "Il prend sa place dans la bande des statuts de sa ville.", confirm: "Approuver", destructive: false, optional: true }
      : { title: "Refuser ce statut sponsorisé ?", description: "L'annonce reste mise en avant dans les résultats, sans place dans les statuts.", confirm: "Refuser", destructive: true, optional: false })
    : pending.kind === "ad-reject" ? { title: "Refuser cette publicité ?", description: pending.ad.status === "ACTIVE" ? "La diffusion s'arrête tout de suite." : "Elle ne sera pas diffusée.", confirm: "Refuser", destructive: true, optional: false }
    : pending.kind === "review" ? { title: "Retirer cet avis ?", description: "Il disparaît du profil du vendeur ; son texte reste au journal d'audit.", confirm: "Retirer", destructive: true, optional: false }
    : { title: "Retirer le badge vendeur vérifié ?", description: "Le vendeur est prévenu avec ce motif.", confirm: "Retirer le badge", destructive: true, optional: false }

  return (
    <ConsoleShell title="Assimé · marché" permission="assime.view">
      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="flex-wrap">
          <TabsTrigger value="products">Annonces</TabsTrigger>
          <TabsTrigger value="sellers">Vendeurs</TabsTrigger>
          <TabsTrigger value="verifications">Vérifications</TabsTrigger>
          <TabsTrigger value="boosts">Mises en avant</TabsTrigger>
          <TabsTrigger value="ads">Publicités</TabsTrigger>
          <TabsTrigger value="reviews">Avis</TabsTrigger>
        </TabsList>

        <TabsContent value="products" className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput placeholder="Titre de l'annonce…" onSearch={setPq} />
            <div className="flex items-center gap-2">
              <Switch id="hidden" checked={hiddenOnly} onCheckedChange={setHiddenOnly} />
              <Label htmlFor="hidden">Masquées seulement</Label>
            </div>
          </div>
          {products.error && <p className="text-sm text-destructive">{products.error}</p>}
          <SimpleTable rows={products.data?.items ?? null} onRowClick={(p) => setProductId(p.id)}
            page={ppage} total={products.data?.total} size={50} onPage={setPpage}
            empty="Aucune annonce." illustration="assime"
            columns={[
              { header: "Annonce", cell: (p) => <span className="font-medium">{p.name}</span> },
              { header: "Vendeur", cell: (p) => p.seller_name },
              { header: "Prix", cell: (p) => <span className="tabular-nums">{price(p.price, p.currency)}</span> },
              { header: "Publiée le", cell: (p) => when(p.created_at) },
              { header: "État", cell: (p) => p.deleted_by_seller ? <Badge variant="outline">Supprimée par le vendeur</Badge>
                : p.is_active ? <Badge variant="secondary">En ligne</Badge> : <Badge variant="destructive">Masquée</Badge> },
            ]} />
          <p className="text-xs text-muted-foreground">Les 200 annonces les plus récentes ; affine avec la recherche.</p>
        </TabsContent>

        <TabsContent value="sellers" className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput placeholder="Nom ou numéro…" onSearch={(v) => { setSq(v); setSpage(1) }} />
            <Select value={certified} onValueChange={(v) => { setCertified(v); setSpage(1) }}>
              <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Tous les vendeurs</SelectItem>
                <SelectItem value="true">Vendeurs vérifiés</SelectItem>
                <SelectItem value="false">Non vérifiés</SelectItem>
              </SelectContent>
            </Select>
          </div>
          {sellers.error && <p className="text-sm text-destructive">{sellers.error}</p>}
          <SimpleTable rows={sellers.data?.items ?? null} page={spage} total={sellers.data?.total} size={25} onPage={setSpage}
            empty="Aucun vendeur." illustration="assime"
            columns={[
              { header: "Vendeur", cell: (s) => (
                <div className="flex flex-col"><span className="font-medium">{s.name}</span><span className="text-xs text-muted-foreground">{s.phone}</span></div>
              ) },
              { header: "Annonces", cell: (s) => <span className="tabular-nums">{s.products}{s.hidden_products ? <span className="text-destructive"> · {s.hidden_products} masquée(s)</span> : null}</span> },
              { header: "Note", cell: (s) => s.rating !== null ? `${s.rating} / 5 (${s.reviews})` : "—" },
              { header: "Badge", cell: (s) => s.is_certified_seller ? <Badge variant="secondary">Vérifié{s.certified_seller_until ? ` · ${when(s.certified_seller_until)}` : ""}</Badge> : "—" },
              { header: "Compte", cell: (s) => s.is_active ? "Actif" : <span className="text-destructive">Suspendu</span> },
              { header: "", className: "text-right", cell: (s) => manage && s.is_certified_seller
                ? <Button size="sm" variant="outline" onClick={() => setPending({ kind: "badge", s })}>Retirer le badge</Button> : null },
            ]} />
        </TabsContent>

        <TabsContent value="verifications" className="flex flex-col gap-3">
          <Tabs value={vstatus} onValueChange={setVstatus}>
            <TabsList>
              <TabsTrigger value="PENDING">À examiner</TabsTrigger>
              <TabsTrigger value="APPROVED">Approuvés</TabsTrigger>
              <TabsTrigger value="REJECTED">Refusés</TabsTrigger>
            </TabsList>
          </Tabs>
          {verifications.error && <p className="text-sm text-destructive">{verifications.error}</p>}
          <SimpleTable rows={verifications.data?.items ?? null} empty="Aucun dossier ici." illustration="assime"
            columns={[
              { header: "Vendeur", cell: (v) => <span className="font-medium">{v.seller_name}</span> },
              { header: "Formule", cell: (v) => v.plan ? `${v.plan}${v.duration_days ? ` · ${v.duration_days} j` : ""}` : "—" },
              { header: "Paiement", cell: (v) => <StatusBadge status={v.payment_status} /> },
              { header: "Pièce d'identité", cell: (v) => mediaIdOf(v.identity_media_url)
                ? <Button size="sm" variant="link" className="px-0" onClick={() => showMedia(mediaIdOf(v.identity_media_url))}>Ouvrir</Button> : "—" },
              { header: "Déposé le", cell: (v) => when(v.created_at) },
              { header: "Statut", cell: (v) => (
                <div className="flex flex-col gap-1"><StatusBadge status={v.status} />
                  {v.review_note && <span className="text-xs text-muted-foreground">{v.review_note}</span>}
                  {v.reviewer_name && <span className="text-xs text-muted-foreground">par {v.reviewer_name}</span>}</div>
              ) },
              { header: "", className: "text-right", cell: (v) => v.status === "PENDING" && manage ? (
                <div className="flex justify-end gap-2">
                  <Button size="sm" variant="outline" onClick={() => setPending({ kind: "verification", v, approved: false })}>Refuser</Button>
                  <Button size="sm" disabled={v.payment_status !== "CONFIRMED"} title={v.payment_status !== "CONFIRMED" ? "Paiement non confirmé" : undefined}
                    onClick={() => setPending({ kind: "verification", v, approved: true })}>Approuver</Button>
                </div>
              ) : null },
            ]} />
        </TabsContent>

        <TabsContent value="boosts" className="flex flex-col gap-3">
          <Tabs value={bstate} onValueChange={(v) => { setBstate(v); setBpage(1) }}>
            <TabsList>
              <TabsTrigger value="pending">Statuts à relire</TabsTrigger>
              <TabsTrigger value="active">En cours</TabsTrigger>
              <TabsTrigger value="all">Toutes</TabsTrigger>
            </TabsList>
          </Tabs>
          <p className="text-sm text-muted-foreground">La mise en avant dans les résultats est immédiate ; seule la place dans la bande des statuts (7 jours) attend une relecture.</p>
          {boosts.error && <p className="text-sm text-destructive">{boosts.error}</p>}
          <SimpleTable rows={boosts.data?.items ?? null} page={bpage} total={boosts.data?.total} size={25} onPage={setBpage}
            empty="Rien ici." illustration="assime"
            columns={[
              { header: "Annonce", cell: (b) => b.product_id
                ? <Button variant="link" className="h-auto px-0" onClick={() => setProductId(b.product_id)}>{b.product ?? `#${b.product_id}`}</Button> : "—" },
              { header: "Vendeur", cell: (b) => b.seller ?? "—" },
              { header: "Ville", cell: (b) => b.city ?? "—" },
              { header: "Période", cell: (b) => `${b.days ?? "?"} j · jusqu'au ${when(b.expires_at)}` },
              { header: "Bilan", cell: (b) => <span className="text-xs tabular-nums">{b.impressions} vues · {b.status_views} en statut · {b.contacts} contacts</span> },
              { header: "Statut", cell: (b) => b.status_moderation ? <Badge variant={b.status_moderation === "REJECTED" ? "outline" : "secondary"}>{MODERATION[b.status_moderation] ?? b.status_moderation}</Badge> : (b.active ? "En cours" : "Terminée") },
              { header: "", className: "text-right", cell: (b) => manage && b.status_moderation === "PENDING" ? (
                <div className="flex justify-end gap-2">
                  <Button size="sm" variant="outline" onClick={() => setPending({ kind: "boost", id: b.id, approve: false })}>Refuser</Button>
                  <Button size="sm" onClick={() => setPending({ kind: "boost", id: b.id, approve: true })}>Approuver</Button>
                </div>
              ) : null },
            ]} />
        </TabsContent>

        <TabsContent value="ads" className="flex flex-col gap-3">
          <Tabs value={astatus} onValueChange={setAstatus}>
            <TabsList>
              <TabsTrigger value="PAID">À relire</TabsTrigger>
              <TabsTrigger value="ACTIVE">Diffusées</TabsTrigger>
              <TabsTrigger value="REJECTED">Refusées</TabsTrigger>
              <TabsTrigger value="ALL">Toutes</TabsTrigger>
            </TabsList>
          </Tabs>
          <p className="text-sm text-muted-foreground">Une campagne payée n&apos;est diffusée qu&apos;après relecture humaine ; la durée court à partir de l&apos;approbation.</p>
          {ads.error && <p className="text-sm text-destructive">{ads.error}</p>}
          <SimpleTable rows={ads.data?.items ?? null} empty="Aucune campagne ici." illustration="assime"
            columns={[
              { header: "Campagne", cell: (a) => (
                <div className="flex max-w-md flex-col whitespace-normal"><span className="font-medium">{a.title}</span>
                  <span className="text-xs text-muted-foreground">{a.body}</span></div>
              ) },
              { header: "Annonceur", cell: (a) => a.advertiser_name },
              { header: "Emplacement", cell: (a) => a.placement === "STATUS" ? "Statuts" : "Marché" },
              { header: "Visuel", cell: (a) => mediaIdOf(a.media_url)
                ? <Button size="sm" variant="link" className="px-0" onClick={() => showMedia(mediaIdOf(a.media_url))}>Voir</Button> : "—" },
              { header: "Diffusion", cell: (a) => a.starts_at ? `${when(a.starts_at)} → ${when(a.expires_at)}` : "—" },
              { header: "Statut", cell: (a) => <StatusBadge status={a.status} /> },
              { header: "", className: "text-right", cell: (a) => manage && (a.status === "PAID" || a.status === "ACTIVE") ? (
                <div className="flex justify-end gap-2">
                  <Button size="sm" variant="outline" onClick={() => setPending({ kind: "ad-reject", ad: a })}>{a.status === "ACTIVE" ? "Arrêter" : "Refuser"}</Button>
                  {a.status === "PAID" && <Button size="sm" onClick={() => { setAdDays("7"); setApprovingAd(a) }}>Approuver</Button>}
                </div>
              ) : null },
            ]} />
        </TabsContent>

        <TabsContent value="reviews" className="flex flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput placeholder="Texte, vendeur ou auteur…" onSearch={(v) => { setRq(v); setRpage(1) }} />
            <Select value={maxRating} onValueChange={(v) => { setMaxRating(v); setRpage(1) }}>
              <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="1">1 étoile</SelectItem>
                <SelectItem value="2">2 étoiles ou moins</SelectItem>
                <SelectItem value="3">3 étoiles ou moins</SelectItem>
                <SelectItem value="5">Tous les avis</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <p className="text-sm text-muted-foreground">L&apos;app n&apos;a pas encore de bouton « signaler un avis » : les avis sévères sont listés ici pour relecture.</p>
          {reviews.error && <p className="text-sm text-destructive">{reviews.error}</p>}
          <SimpleTable rows={reviews.data?.items ?? null} page={rpage} total={reviews.data?.total} size={25} onPage={setRpage}
            empty="Aucun avis ne correspond." illustration="assime"
            columns={[
              { header: "Note", cell: (r) => <span className="tabular-nums">{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</span> },
              { header: "Avis", cell: (r) => <span className="line-clamp-3 max-w-md whitespace-normal">{r.comment ?? "—"}</span> },
              { header: "Sur", cell: (r) => r.seller ?? "—" },
              { header: "Par", cell: (r) => r.author ?? "—" },
              { header: "Le", cell: (r) => when(r.created_at) },
              { header: "", className: "text-right", cell: (r) => manage
                ? <Button size="sm" variant="outline" onClick={() => setPending({ kind: "review", r })}>Retirer</Button> : null },
            ]} />
        </TabsContent>
      </Tabs>

      <Sheet open={productId !== null} onOpenChange={(o) => !o && setProductId(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{pd?.name ?? "Annonce"}</SheetTitle>
            <SheetDescription>{pd ? `${pd.category} · ${price(pd.price, pd.currency)}` : ""}</SheetDescription>
          </SheetHeader>
          {pd ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div className="flex items-center gap-2">
                {pd.deleted_by_seller ? <Badge variant="outline">Supprimée par le vendeur</Badge>
                  : pd.is_active ? <Badge variant="secondary">En ligne</Badge> : <Badge variant="destructive">Masquée</Badge>}
                {pd.sold_at && <Badge variant="outline">Vendue le {when(pd.sold_at)}</Badge>}
              </div>
              {pd.description && <p className="whitespace-pre-line">{pd.description}</p>}
              <Fields rows={[
                ["Lieu", pd.location],
                ["Publiée le", when(pd.created_at)],
                ["Photo", pd.image_media_id ? <Button size="sm" variant="link" className="h-auto px-0" onClick={() => showMedia(pd.image_media_id)}>Voir</Button> : "—"],
                ["Vendeur", `${pd.seller.name ?? "—"} · ${pd.seller.phone ?? ""}`],
                ["Vendeur vérifié", pd.seller.is_certified_seller ? "Oui" : "Non"],
                ["Annonces du vendeur", pd.seller.products],
              ]} />
              {pd.boosts.length > 0 && (
                <Section title="Mises en avant">
                  {pd.boosts.map((b) => (
                    <span key={b.id}>{b.days ?? "?"} j · {when(b.starts_at)} → {when(b.expires_at)}{b.active ? " · en cours" : ""}
                      {b.status_moderation ? ` · ${MODERATION[b.status_moderation] ?? b.status_moderation}` : ""}
                      <span className="text-muted-foreground"> · {b.impressions} vues, {b.contacts} contacts</span></span>
                  ))}
                </Section>
              )}
              <Section title="Modération">
                <TeamActions items={pd.team_actions.map((a) => ({ ...a, action: a.action === "moderate" ? (a.is_active ? "Annonce rétablie" : "Annonce masquée") : a.action }))} labels={AUDIT_ACTIONS} />
              </Section>
              {manage && !pd.deleted_by_seller && (pd.is_active
                ? <Button variant="destructive" onClick={() => setPending({ kind: "product", id: pd.id, hide: true })}>Masquer l&apos;annonce</Button>
                : <Button onClick={() => restore(pd.id)}>Rétablir l&apos;annonce</Button>)}
            </div>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{product.error ?? "Chargement…"}</p>
          )}
        </SheetContent>
      </Sheet>

      <ReasonDialog open={pending !== null} onOpenChange={(o) => !o && setPending(null)}
        title={dialog?.title ?? ""} description={dialog?.description} confirm={dialog?.confirm ?? ""}
        destructive={dialog?.destructive} optional={dialog?.optional}
        onConfirm={async (reason) => {
          if (!pending) return
          if (pending.kind === "product") {
            await act(`/admin/marketplace/products/${pending.id}`, { method: "PUT", body: { is_active: false, reason } }, "Annonce masquée")
            product.reload(); products.reload()
          } else if (pending.kind === "verification") {
            await act(`/admin/marketplace/verifications/${pending.v.id}`, { method: "PUT", body: { approved: pending.approved, note: reason || null } },
              pending.approved ? "Badge accordé" : "Dossier refusé")
            verifications.reload()
          } else if (pending.kind === "boost") {
            await act(`/admin/marketplace/sponsored-statuses/${pending.id}`, { method: "PUT", body: { approve: pending.approve, reason: reason || null } },
              pending.approve ? "Statut sponsorisé approuvé" : "Statut sponsorisé refusé")
            boosts.reload(); product.reload()
          } else if (pending.kind === "ad-reject") {
            await act(`/admin/marketplace/ads/${pending.ad.id}`, { method: "PUT", body: { approved: false, reason } }, "Campagne refusée")
            ads.reload()
          } else if (pending.kind === "review") {
            await act(`/admin/marketplace/reviews/${pending.r.id}/remove`, { body: { reason } }, "Avis retiré")
            reviews.reload()
          } else {
            await act(`/admin/marketplace/sellers/${pending.s.id}/revoke-badge`, { body: { reason } }, "Badge retiré")
            sellers.reload()
          }
        }} />

      <Dialog open={approvingAd !== null} onOpenChange={(o) => !o && setApprovingAd(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Diffuser « {approvingAd?.title} » ?</DialogTitle>
            <DialogDescription>Relis le texte et le visuel : la campagne apparaît aussitôt à tous les utilisateurs concernés.</DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-1">
            <Label htmlFor="ad-days">Durée de diffusion (jours)</Label>
            <Input id="ad-days" type="number" min={1} max={90} value={adDays} onChange={(e) => setAdDays(e.target.value)} />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setApprovingAd(null)}>Annuler</Button>
            <Button disabled={!(Number(adDays) >= 1 && Number(adDays) <= 90)} onClick={approveAd}>Diffuser</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </ConsoleShell>
  )
}
