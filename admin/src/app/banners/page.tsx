"use client"

import * as React from "react"
import { IconPhoto, IconPlus, IconTrash } from "@tabler/icons-react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Textarea } from "@/components/ui/textarea"
import { useApi, useAuth } from "@/lib/auth"
import { api, getToken, when } from "@/lib/api"

type Banner = {
  id: number; label: string | null; title: string; body: string | null
  image: { id: number; original_filename: string | null } | null; image_media_id: number | null
  cta_label: string | null; cta_url: string | null; country: string | null; region: string | null
  position: number; is_active: boolean; is_live: boolean; starts_at: string | null; ends_at: string | null
}

type Draft = {
  id: number | null; label: string; title: string; body: string; image_media_id: number | null; image_name: string
  cta_label: string; cta_url: string; country: string; region: string; position: string; is_active: boolean
  starts_at: string; ends_at: string
}

const EMPTY: Draft = {
  id: null, label: "", title: "", body: "", image_media_id: null, image_name: "", cta_label: "", cta_url: "",
  country: "", region: "", position: "0", is_active: true, starts_at: "", ends_at: "",
}

const API_BASE = (process.env.NEXT_PUBLIC_API_BASE ?? "") + "/api/v1"

/** L'API parle en UTC sans fuseau ; le champ `datetime-local`, en heure locale. */
function toLocalInput(iso: string | null): string {
  if (!iso) return ""
  const d = new Date(iso.endsWith("Z") || iso.includes("+") ? iso : iso + "Z")
  const pad = (n: number) => String(n).padStart(2, "0")
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const fromLocalInput = (value: string) => (value ? new Date(value).toISOString() : null)

function zone(b: Banner) {
  if (!b.country) return "Tous les pays"
  return b.region ? `${b.country} · ${b.region}` : `${b.country} (tout le pays)`
}

export default function BannersPage() {
  const { can } = useAuth()
  const list = useApi<{ items: Banner[] }>("/admin/banners")
  const [draft, setDraft] = React.useState<Draft | null>(null)
  const [busy, setBusy] = React.useState(false)
  const manage = can("banners.manage")
  const set = (patch: Partial<Draft>) => setDraft((d) => (d ? { ...d, ...patch } : d))

  function edit(b: Banner) {
    setDraft({
      id: b.id, label: b.label ?? "", title: b.title, body: b.body ?? "", image_media_id: b.image_media_id,
      image_name: b.image?.original_filename ?? (b.image_media_id ? "Image actuelle" : ""),
      cta_label: b.cta_label ?? "", cta_url: b.cta_url ?? "", country: b.country ?? "", region: b.region ?? "",
      position: String(b.position), is_active: b.is_active,
      starts_at: toLocalInput(b.starts_at), ends_at: toLocalInput(b.ends_at),
    })
  }

  async function upload(file: File) {
    setBusy(true)
    try {
      const form = new FormData()
      form.append("message_type", "IMAGE")
      form.append("file", file)
      const response = await fetch(API_BASE + "/media/upload", {
        method: "POST", headers: { Authorization: `Bearer ${getToken() ?? ""}` }, body: form,
      })
      if (!response.ok) throw new Error((await response.json().catch(() => ({}))).detail ?? `Erreur ${response.status}`)
      const media = (await response.json()) as { id: number }
      set({ image_media_id: media.id, image_name: file.name })
      toast.success("Image ajoutée")
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  async function save() {
    if (!draft) return
    setBusy(true)
    const body = {
      label: draft.label, title: draft.title.trim(), body: draft.body, image_media_id: draft.image_media_id,
      cta_label: draft.cta_label, cta_url: draft.cta_url, country: draft.country, region: draft.region,
      position: Number(draft.position) || 0, is_active: draft.is_active,
      starts_at: fromLocalInput(draft.starts_at), ends_at: fromLocalInput(draft.ends_at),
    }
    try {
      if (draft.id === null) await api("/admin/banners", { body })
      else await api(`/admin/banners/${draft.id}`, { method: "PUT", body })
      toast.success(draft.id === null ? "Bannière créée" : "Bannière modifiée")
      setDraft(null)
      list.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  async function remove(b: Banner) {
    if (!confirm(`Supprimer la bannière « ${b.title} » ?`)) return
    try {
      await api(`/admin/banners/${b.id}`, { method: "DELETE" })
      toast.success("Bannière supprimée")
      list.reload()
    } catch (e) { toast.error((e as Error).message) }
  }

  return (
    <ConsoleShell title="Bannières de l'accueil" permission="banners.view"
      actions={manage && <Button size="sm" onClick={() => setDraft(EMPTY)}><IconPlus />Nouvelle bannière</Button>}>
      <p className="text-sm text-muted-foreground">
        Le carrousel en bas de l&apos;accueil de l&apos;application. Chaque bannière vise un pays (déduit du numéro de
        téléphone) et, si besoin, une région ou une ville. Sans pays, elle s&apos;affiche partout. Au plus 8 bannières
        par personne, de la plus précise à la plus générale.
      </p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable
        rows={list.data?.items ?? null}
        empty="Aucune bannière. L'accueil affiche seulement le rappel du chiffrement." illustration="market"
        onRowClick={manage ? edit : undefined}
        columns={[
          { header: "Bannière", cell: (b) => (
            <div className="flex items-center gap-2">
              {b.image_media_id && <IconPhoto className="size-4 text-muted-foreground" />}
              <div>
                <div className="font-medium">{b.title}</div>
                {b.label && <div className="text-xs text-muted-foreground">{b.label}</div>}
              </div>
            </div>
          ) },
          { header: "Zone", cell: zone },
          { header: "Période", cell: (b) => (b.starts_at || b.ends_at
            ? `${b.starts_at ? when(b.starts_at) : "dès maintenant"} → ${b.ends_at ? when(b.ends_at) : "sans fin"}`
            : "Sans limite") },
          { header: "Ordre", cell: (b) => b.position },
          { header: "État", cell: (b) => b.is_live
            ? <Badge>En ligne</Badge>
            : <Badge variant="outline">{b.is_active ? "Hors période" : "Coupée"}</Badge> },
          { header: "", className: "text-right", cell: (b) => manage ? (
            <Button size="icon" variant="ghost" aria-label="Supprimer"
              onClick={(e) => { e.stopPropagation(); remove(b) }}><IconTrash /></Button>
          ) : null },
        ]}
      />
      <Dialog open={draft !== null} onOpenChange={(o) => !o && setDraft(null)}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
          <DialogHeader>
            <DialogTitle>{draft?.id === null ? "Nouvelle bannière" : "Modifier la bannière"}</DialogTitle>
            <DialogDescription>Ce que verront les utilisateurs de la zone, en bas de leur accueil.</DialogDescription>
          </DialogHeader>
          {draft && (
            <div className="grid gap-3">
              <div className="grid gap-2">
                <Label htmlFor="title">Titre</Label>
                <Input id="title" maxLength={80} value={draft.title} onChange={(e) => set({ title: e.target.value })} />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="label">Annonceur ou mention (petite ligne au-dessus)</Label>
                <Input id="label" maxLength={40} placeholder="Sponsorisé" value={draft.label} onChange={(e) => set({ label: e.target.value })} />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="body">Texte</Label>
                <Textarea id="body" maxLength={200} rows={2} value={draft.body} onChange={(e) => set({ body: e.target.value })} />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="image">Image de fond (paysage, 1200 × 600 conseillé)</Label>
                <Input id="image" type="file" accept="image/png,image/jpeg,image/webp" disabled={busy}
                  onChange={(e) => { const f = e.target.files?.[0]; if (f) upload(f) }} />
                {draft.image_media_id && (
                  <div className="flex items-center justify-between text-xs text-muted-foreground">
                    <span>{draft.image_name}</span>
                    <button className="underline" onClick={() => set({ image_media_id: null, image_name: "" })}>Retirer l&apos;image</button>
                  </div>
                )}
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div className="grid gap-2">
                  <Label htmlFor="cta_label">Texte du bouton</Label>
                  <Input id="cta_label" maxLength={30} placeholder="Découvrir" value={draft.cta_label} onChange={(e) => set({ cta_label: e.target.value })} />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="cta_url">Lien</Label>
                  <Input id="cta_url" placeholder="https://… ou app:kory" value={draft.cta_url} onChange={(e) => set({ cta_url: e.target.value })} />
                </div>
              </div>
              <p className="text-xs text-muted-foreground">
                Lien <code>https://</code> (ouvert dans le navigateur) ou <code>app:kory</code>, <code>app:honam</code>,
                {" "}<code>app:assime</code> (ouvre le module).
              </p>
              <div className="grid grid-cols-3 gap-3">
                <div className="grid gap-2">
                  <Label htmlFor="country">Pays</Label>
                  <Input id="country" maxLength={2} placeholder="TG" className="uppercase" value={draft.country}
                    onChange={(e) => set({ country: e.target.value.toUpperCase() })} />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="region">Région ou ville</Label>
                  <Input id="region" maxLength={80} placeholder="Lomé" value={draft.region} onChange={(e) => set({ region: e.target.value })} />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="position">Ordre</Label>
                  <Input id="position" type="number" min={0} max={999} value={draft.position} onChange={(e) => set({ position: e.target.value })} />
                </div>
              </div>
              <p className="text-xs text-muted-foreground">
                Pays vide : tous les pays. Région vide : tout le pays. Une bannière régionale n&apos;est montrée qu&apos;aux
                personnes dont on connaît la ville.
              </p>
              <div className="grid grid-cols-2 gap-3">
                <div className="grid gap-2">
                  <Label htmlFor="starts_at">Début</Label>
                  <Input id="starts_at" type="datetime-local" value={draft.starts_at} onChange={(e) => set({ starts_at: e.target.value })} />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="ends_at">Fin</Label>
                  <Input id="ends_at" type="datetime-local" value={draft.ends_at} onChange={(e) => set({ ends_at: e.target.value })} />
                </div>
              </div>
              <div className="flex items-center justify-between rounded-lg border p-3">
                <div>
                  <div className="text-sm font-medium">Active</div>
                  <div className="text-xs text-muted-foreground">Coupée, elle disparaît de l&apos;accueil sans être supprimée.</div>
                </div>
                <Switch checked={draft.is_active} onCheckedChange={(v) => set({ is_active: v })} />
              </div>
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setDraft(null)}>Annuler</Button>
            <Button disabled={busy || !draft || draft.title.trim().length === 0} onClick={save}>Enregistrer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </ConsoleShell>
  )
}
