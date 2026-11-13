"use client"

import * as React from "react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { ReasonDialog } from "@/components/reason-dialog"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { Separator } from "@/components/ui/separator"
import { Badge } from "@/components/ui/badge"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { useApi, useAuth } from "@/lib/auth"
import { api, when } from "@/lib/api"
import { ActiveBadge, ROLE_OPTIONS } from "@/lib/labels"
import type { AdminUser, Paged } from "@/lib/types"

type Detail = AdminUser & {
  stats: Record<string, number>
  certified: { status: string; plan: string } | null
  devices: { id: number; platform: string; registered_at: string | null }[]
  has_avatar: boolean
  active_sessions: number
}

const isDeleted = (u: AdminUser) => !u.is_active && !u.phone && !u.email
const digits = (s: string) => s.replace(/\D/g, "")

const STAT_LABELS: Record<string, string> = {
  groups: "Groupes", direct_sent: "Messages directs envoyés", pots_organized: "Cagnottes Kory organisées",
  honam_orders: "Commandes Honam", products: "Annonces Assimé", reports_received: "Signalements reçus",
}

export default function UsersPage() {
  const { can, me } = useAuth()
  const [q, setQ] = React.useState("")
  const [search, setSearch] = React.useState("")
  const [status, setStatus] = React.useState("all")
  const [role, setRole] = React.useState("all")
  const [page, setPage] = React.useState(1)
  const params = new URLSearchParams({ page: String(page), size: "25" })
  if (search) params.set("q", search)
  if (status === "team") params.set("team", "true")
  else if (status !== "all") params.set("status", status)
  if (role !== "all") params.set("role", role)
  const list = useApi<Paged<AdminUser>>(`/admin/users?${params}`)
  const [selected, setSelected] = React.useState<number | null>(null)
  const detail = useApi<Detail>(selected ? `/admin/users/${selected}` : null)
  const [suspending, setSuspending] = React.useState(false)
  const [removingAvatar, setRemovingAvatar] = React.useState(false)
  const [loggingOut, setLoggingOut] = React.useState(false)
  const [renaming, setRenaming] = React.useState(false)
  const [newName, setNewName] = React.useState("")
  const [renameReason, setRenameReason] = React.useState("")
  const [deleting, setDeleting] = React.useState(false)
  const [confirmText, setConfirmText] = React.useState("")
  const [deleteReason, setDeleteReason] = React.useState("")
  const [busy, setBusy] = React.useState(false)

  React.useEffect(() => {
    const t = setTimeout(() => { setSearch(q.trim()); setPage(1) }, 300)
    return () => clearTimeout(t)
  }, [q])

  async function reactivate(id: number) {
    try {
      await api(`/admin/users/${id}/reactivate`, { method: "POST" })
      toast.success("Compte réactivé")
      detail.reload(); list.reload()
    } catch (e) { toast.error((e as Error).message) }
  }

  function refresh() { detail.reload(); list.reload() }

  async function act(fn: () => Promise<unknown>, success: string) {
    setBusy(true)
    try { await fn(); toast.success(success); refresh(); return true }
    catch (e) { toast.error((e as Error).message); return false }
    finally { setBusy(false) }
  }

  async function removeDevice(deviceId: number) {
    await act(() => api(`/admin/users/${selected}/devices/${deviceId}`, { method: "DELETE" }),
      "Appareil retiré : ses notifications et sa session sont coupées")
  }

  const d = selected && detail.data?.id === selected ? detail.data : null
  // Mêmes règles que l'API : pas d'action sur soi, ni sur un membre de
  // l'équipe sans le droit de gérer l'équipe, ni sur un compte supprimé.
  const canAct = !!d && can("users.manage") && d.id !== me?.id && !isDeleted(d)
    && (d.role === "USER" || can("team.manage"))
  const nameOk = newName.trim().length >= 1 && newName.trim().length <= 120 && renameReason.trim().length >= 3
  const expected = d?.phone ? digits(d.phone) : "SUPPRIMER"
  const confirmOk = d?.phone ? digits(confirmText) === expected : confirmText.trim() === "SUPPRIMER"
  const deleteOk = confirmOk && deleteReason.trim().length >= 3
  return (
    <ConsoleShell title="Utilisateurs" permission="users.view">
      <div className="flex flex-wrap items-center gap-2">
        <Input className="max-w-xs" placeholder="Nom, numéro ou e-mail…" value={q} onChange={(e) => setQ(e.target.value)} />
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(1) }}>
          <SelectTrigger className="w-40"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Tous les statuts</SelectItem>
            <SelectItem value="active">Actifs</SelectItem>
            <SelectItem value="suspended">Suspendus</SelectItem>
            <SelectItem value="team">Équipe</SelectItem>
          </SelectContent>
        </Select>
        <Select value={role} onValueChange={(v) => { setRole(v); setPage(1) }}>
          <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Tous les rôles</SelectItem>
            {ROLE_OPTIONS.map((r) => (
              <SelectItem key={r.value} value={r.value}>{r.value === "USER" ? "Utilisateur" : r.label}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable
        rows={list.data?.items ?? null}
        onRowClick={(u) => setSelected(u.id)}
        page={page} total={list.data?.total} size={25} onPage={setPage}
        empty="Aucun utilisateur ne correspond."
        columns={[
          { header: "Nom", cell: (u) => <span className="font-medium">{u.full_name ?? "—"}</span> },
          { header: "Numéro", cell: (u) => u.phone ?? "—" },
          { header: "Rôle", cell: (u) => u.role === "USER" ? <span className="text-muted-foreground">Utilisateur</span> : u.role_label },
          { header: "E-mail", cell: (u) => u.email ?? "—" },
          { header: "Statut", cell: (u) => isDeleted(u) ? <Badge variant="outline">Supprimé</Badge> : <ActiveBadge active={u.is_active} /> },
          { header: "Inscrit le", cell: (u) => when(u.created_at) },
          { header: "Vu le", cell: (u) => when(u.last_seen_at) },
        ]}
      />
      <Sheet open={selected !== null} onOpenChange={(o) => !o && setSelected(null)}>
        <SheetContent className="overflow-y-auto">
          <SheetHeader>
            <SheetTitle>{d ? (isDeleted(d) ? "Compte supprimé" : d.full_name ?? "Sans nom") : "Utilisateur"}</SheetTitle>
            <SheetDescription>{[d?.phone, d?.email].filter(Boolean).join(" · ")}</SheetDescription>
          </SheetHeader>
          {d ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div className="flex items-center gap-2">
                {isDeleted(d) ? <Badge variant="outline">Supprimé</Badge> : <ActiveBadge active={d.is_active} />}
                <span className="text-muted-foreground">{d.role === "USER" ? "Utilisateur" : d.role_label}</span>
              </div>
              <div className="grid grid-cols-2 gap-y-1">
                <span className="text-muted-foreground">Inscrit le</span><span>{when(d.created_at)}</span>
                <span className="text-muted-foreground">Vu le</span><span>{when(d.last_seen_at)}</span>
                <span className="text-muted-foreground">Pokou certifié</span>
                <span>{d.certified ? `${d.certified.plan} · ${d.certified.status}` : "Non"}</span>
                <span className="text-muted-foreground">Photo de profil</span><span>{d.has_avatar ? "Oui" : "Non"}</span>
                <span className="text-muted-foreground">Sessions ouvertes</span><span className="tabular-nums">{d.active_sessions}</span>
              </div>
              <Separator />
              <div className="flex flex-col gap-1">
                <span className="font-medium">Notifications</span>
                {d.devices.length === 0 ? (
                  <span className="text-destructive">
                    Aucun téléphone enregistré : ce compte ne reçoit aucune notification.
                  </span>
                ) : (
                  d.devices.map((device, i) => (
                    <div key={device.id ?? i} className="flex items-center justify-between gap-2">
                      <span className="text-muted-foreground">
                        {device.platform === "ios" ? "iPhone" : device.platform === "android" ? "Android" : device.platform}
                        {" · enregistré le "}
                        {when(device.registered_at)}
                      </span>
                      {canAct && (
                        <Button size="sm" variant="ghost" disabled={busy} onClick={() => removeDevice(device.id)}>Retirer</Button>
                      )}
                    </div>
                  ))
                )}
              </div>
              <Separator />
              <div className="grid grid-cols-2 gap-y-1">
                {Object.entries(d.stats).map(([k, v]) => (
                  <React.Fragment key={k}>
                    <span className="text-muted-foreground">{STAT_LABELS[k] ?? k}</span><span className="tabular-nums">{v}</span>
                  </React.Fragment>
                ))}
              </div>
              <p className="text-xs text-muted-foreground">
                Les messages sont chiffrés de bout en bout : la console n&apos;y a pas accès.
              </p>
              {canAct && (
                <div className="flex flex-col gap-2">
                  <Separator />
                  <span className="font-medium">Actions</span>
                  <div className="grid grid-cols-2 gap-2">
                    <Button variant="outline" onClick={() => { setNewName(d.full_name ?? ""); setRenameReason(""); setRenaming(true) }}>
                      Modifier le nom
                    </Button>
                    <Button variant="outline" disabled={!d.has_avatar} onClick={() => setRemovingAvatar(true)}>
                      Retirer la photo
                    </Button>
                    <Button variant="outline" disabled={d.active_sessions === 0} onClick={() => setLoggingOut(true)}>
                      Déconnecter partout
                    </Button>
                    {d.is_active
                      ? <Button variant="outline" onClick={() => setSuspending(true)}>Suspendre</Button>
                      : <Button variant="outline" onClick={() => reactivate(d.id)}>Réactiver</Button>}
                  </div>
                  {d.role === "USER" ? (
                    <Button variant="destructive" onClick={() => { setConfirmText(""); setDeleteReason(""); setDeleting(true) }}>
                      Supprimer le compte
                    </Button>
                  ) : (
                    <p className="text-xs text-muted-foreground">
                      Membre de l&apos;équipe : retire-le de l&apos;équipe avant de pouvoir supprimer son compte.
                    </p>
                  )}
                </div>
              )}
            </div>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{detail.error ?? "Chargement…"}</p>
          )}
        </SheetContent>
      </Sheet>
      <ReasonDialog open={suspending} onOpenChange={setSuspending} destructive
        title="Suspendre ce compte ?"
        description="La personne est déconnectée et ne peut plus se reconnecter tant que le compte n'est pas réactivé."
        confirm="Suspendre"
        onConfirm={async (reason) => {
          try {
            await api(`/admin/users/${selected}/suspend`, { body: { reason } })
            toast.success("Compte suspendu")
            detail.reload(); list.reload()
          } catch (e) { toast.error((e as Error).message); throw e }
        }} />
      <ReasonDialog open={removingAvatar} onOpenChange={setRemovingAvatar} destructive
        title="Retirer la photo de profil ?"
        description="La photo disparaît chez tous ses contacts. La personne pourra en choisir une autre."
        confirm="Retirer"
        onConfirm={async (reason) => {
          if (!(await act(() => api(`/admin/users/${selected}/avatar/remove`, { body: { reason } }), "Photo retirée"))) throw new Error()
        }} />
      <Dialog open={loggingOut} onOpenChange={setLoggingOut}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Déconnecter toutes ses sessions ?</DialogTitle>
            <DialogDescription>
              Chaque appareil connecté à ce compte est déconnecté tout de suite. La personne peut se reconnecter
              avec un nouveau code.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setLoggingOut(false)}>Annuler</Button>
            <Button disabled={busy} onClick={async () => {
              if (await act(() => api(`/admin/users/${selected}/logout-all`, { method: "POST" }), "Sessions fermées")) setLoggingOut(false)
            }}>Déconnecter</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={renaming} onOpenChange={setRenaming}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Modifier le nom affiché</DialogTitle>
            <DialogDescription>Le nouveau nom apparaît aussitôt chez ses contacts. Le motif part au journal d&apos;audit.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor="new-name">Nom affiché</Label>
              <Input id="new-name" maxLength={120} value={newName} onChange={(e) => setNewName(e.target.value)} />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="rename-reason">Motif</Label>
              <Textarea id="rename-reason" maxLength={280} value={renameReason} onChange={(e) => setRenameReason(e.target.value)}
                placeholder="Motif (obligatoire)" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRenaming(false)}>Annuler</Button>
            <Button disabled={!nameOk || busy} onClick={async () => {
              const ok = await act(() => api(`/admin/users/${selected}/name`, {
                method: "PUT", body: { full_name: newName.trim(), reason: renameReason.trim() },
              }), "Nom modifié")
              if (ok) setRenaming(false)
            }}>Enregistrer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={deleting} onOpenChange={setDeleting}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Supprimer définitivement ce compte ?</DialogTitle>
            <DialogDescription>
              Même règle que la suppression depuis l&apos;application : carnet d&apos;adresses, statuts, groupes,
              appareils et sessions sont effacés ; le nom, le numéro et la photo sont anonymisés. Les messages déjà
              reçus par d&apos;autres restent chez eux. Irréversible.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor="confirm-delete">
                {d?.phone ? <>Retape le numéro du compte ({d.phone})</> : <>Tape SUPPRIMER</>}
              </Label>
              <Input id="confirm-delete" autoComplete="off" value={confirmText} onChange={(e) => setConfirmText(e.target.value)} />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="delete-reason">Motif</Label>
              <Textarea id="delete-reason" maxLength={280} value={deleteReason} onChange={(e) => setDeleteReason(e.target.value)}
                placeholder="Motif (obligatoire)" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleting(false)}>Annuler</Button>
            <Button variant="destructive" disabled={!deleteOk || busy} onClick={async () => {
              const ok = await act(() => api(`/admin/users/${selected}/delete`, {
                body: { confirm: confirmText.trim(), reason: deleteReason.trim() },
              }), "Compte supprimé et anonymisé")
              if (ok) setDeleting(false)
            }}>Supprimer le compte</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </ConsoleShell>
  )
}
