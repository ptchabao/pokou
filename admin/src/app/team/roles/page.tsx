"use client"

import * as React from "react"
import { IconLock, IconPlus, IconShieldCheck, IconTrash } from "@tabler/icons-react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Checkbox } from "@/components/ui/checkbox"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { Skeleton } from "@/components/ui/skeleton"
import { Textarea } from "@/components/ui/textarea"
import { useApi, useAuth } from "@/lib/auth"
import { api } from "@/lib/api"
import type { Role } from "@/lib/types"

type Catalog = { group: string; permissions: { key: string; label: string; super_admin_only: boolean }[] }[]

/** RBAC : ce que chaque rôle de la console a le droit de faire. */
export default function RolesPage() {
  const { can } = useAuth()
  const manage = can("roles.manage")
  const data = useApi<{ items: Role[]; catalog: Catalog }>("/admin/roles")
  const roles = data.data?.items ?? null
  const catalog = data.data?.catalog ?? []
  const [selectedKey, setSelectedKey] = React.useState<string | null>(null)
  const selected = roles?.find((r) => r.key === selectedKey) ?? roles?.[1] ?? roles?.[0] ?? null
  const [draft, setDraft] = React.useState<{ label: string; description: string; permissions: Set<string> } | null>(null)
  const [creating, setCreating] = React.useState(false)
  const [newLabel, setNewLabel] = React.useState("")
  const [newDescription, setNewDescription] = React.useState("")
  const [copyFrom, setCopyFrom] = React.useState("none")
  const [deleting, setDeleting] = React.useState<Role | null>(null)
  const [busy, setBusy] = React.useState(false)

  React.useEffect(() => {
    if (selected) setDraft({ label: selected.label, description: selected.description ?? "", permissions: new Set(selected.permissions) })
  }, [selected?.key, selected?.permissions.join(","), selected?.label]) // eslint-disable-line react-hooks/exhaustive-deps

  const editable = manage && Boolean(selected?.editable)
  const dirty = Boolean(selected && draft && (
    draft.label !== selected.label ||
    (draft.description || "") !== (selected.description || "") ||
    [...draft.permissions].sort().join(",") !== [...selected.permissions].sort().join(",")
  ))

  function toggle(key: string, on: boolean) {
    setDraft((d) => {
      if (!d) return d
      const next = new Set(d.permissions)
      if (on) next.add(key)
      else next.delete(key)
      return { ...d, permissions: next }
    })
  }

  function toggleGroup(keys: string[], on: boolean) {
    setDraft((d) => {
      if (!d) return d
      const next = new Set(d.permissions)
      keys.forEach((k) => (on ? next.add(k) : next.delete(k)))
      return { ...d, permissions: next }
    })
  }

  async function save() {
    if (!selected?.id || !draft) return
    setBusy(true)
    try {
      await api(`/admin/roles/${selected.id}`, {
        method: "PUT",
        body: { label: draft.label.trim(), description: draft.description.trim(), permissions: [...draft.permissions] },
      })
      toast.success("Rôle enregistré")
      data.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  async function create() {
    setBusy(true)
    try {
      const base = roles?.find((r) => r.key === copyFrom)
      const created = await api<Role>("/admin/roles", {
        body: {
          label: newLabel.trim(), description: newDescription.trim(),
          permissions: (base?.permissions ?? ["dashboard.view"]).filter((p) => p !== "roles.manage"),
        },
      })
      toast.success("Rôle créé")
      setCreating(false); setNewLabel(""); setNewDescription(""); setCopyFrom("none")
      setSelectedKey(created.key)
      data.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  async function remove() {
    if (!deleting?.id) return
    setBusy(true)
    try {
      await api(`/admin/roles/${deleting.id}`, { method: "DELETE" })
      toast.success("Rôle supprimé")
      setDeleting(null); setSelectedKey(null)
      data.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  return (
    <ConsoleShell title="Équipe · Rôles et permissions" permission="team.view"
      actions={manage && <Button size="sm" onClick={() => setCreating(true)}><IconPlus />Nouveau rôle</Button>}>
      <p className="text-sm text-muted-foreground">
        Chaque membre de l&apos;équipe a un rôle ; un rôle est un ensemble de permissions. L&apos;API vérifie la permission
        à chaque requête : la console ne fait que cacher ce qui serait refusé.
      </p>
      {data.error && <p className="text-sm text-destructive">{data.error}</p>}
      <div className="grid gap-4 lg:grid-cols-[minmax(0,320px)_minmax(0,1fr)]">
        <Card className="h-fit">
          <CardHeader>
            <CardTitle>Rôles</CardTitle>
            <CardDescription>{roles ? `${roles.length} rôles` : "Chargement…"}</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-1 px-2">
            {roles === null
              ? Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="mx-2 h-12" />)
              : roles.map((r) => (
                <button key={r.key} type="button" onClick={() => setSelectedKey(r.key)}
                  className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-left transition-colors hover:bg-accent ${selected?.key === r.key ? "bg-accent" : ""}`}>
                  <div className="flex size-9 shrink-0 items-center justify-center rounded-md bg-muted">
                    {r.editable ? <IconShieldCheck className="size-4" /> : <IconLock className="size-4" />}
                  </div>
                  <div className="grid min-w-0 flex-1">
                    <span className="truncate text-sm font-medium">{r.label}</span>
                    <span className="truncate text-xs text-muted-foreground">
                      {r.members} membre{r.members > 1 ? "s" : ""} · {r.permissions.length} permission{r.permissions.length > 1 ? "s" : ""}
                    </span>
                  </div>
                  {!r.is_system && <Badge variant="outline">Créé</Badge>}
                </button>
              ))}
          </CardContent>
        </Card>

        <Card>
          {selected && draft ? (
            <>
              <CardHeader>
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="grid gap-1">
                    <CardTitle className="flex items-center gap-2">
                      {selected.label}
                      {selected.is_system ? <Badge variant="secondary">Prédéfini</Badge> : <Badge variant="outline">Créé par l&apos;équipe</Badge>}
                    </CardTitle>
                    <CardDescription>
                      {!selected.editable
                        ? "Toutes les permissions, toujours : ce rôle ne se modifie pas, pour que personne ne puisse fermer la console."
                        : selected.description || "Coche ce que ce rôle a le droit de faire."}
                    </CardDescription>
                  </div>
                  {manage && selected.deletable && (
                    <Button size="sm" variant="ghost" className="text-destructive" onClick={() => setDeleting(selected)}>
                      <IconTrash />Supprimer
                    </Button>
                  )}
                </div>
                {editable && !selected.is_system && (
                  <div className="mt-3 grid gap-3 sm:grid-cols-2">
                    <div className="grid gap-2">
                      <Label htmlFor="role-label">Nom du rôle</Label>
                      <Input id="role-label" maxLength={80} value={draft.label} onChange={(e) => setDraft({ ...draft, label: e.target.value })} />
                    </div>
                    <div className="grid gap-2">
                      <Label htmlFor="role-desc">Description</Label>
                      <Input id="role-desc" maxLength={500} value={draft.description} onChange={(e) => setDraft({ ...draft, description: e.target.value })} />
                    </div>
                  </div>
                )}
              </CardHeader>
              <CardContent className="grid gap-5">
                {catalog.map((group) => {
                  const keys = group.permissions.filter((p) => !p.super_admin_only).map((p) => p.key)
                  const all = keys.length > 0 && keys.every((k) => draft.permissions.has(k))
                  return (
                    <div key={group.group} className="grid gap-2">
                      <div className="flex items-center justify-between">
                        <h3 className="text-sm font-semibold">{group.group}</h3>
                        {editable && keys.length > 1 && (
                          <button type="button" className="text-xs text-muted-foreground hover:text-foreground" onClick={() => toggleGroup(keys, !all)}>
                            {all ? "Tout décocher" : "Tout cocher"}
                          </button>
                        )}
                      </div>
                      <div className="grid gap-2 sm:grid-cols-2">
                        {group.permissions.map((p) => {
                          const locked = !editable || p.super_admin_only
                          const checked = selected.editable ? draft.permissions.has(p.key) : true
                          return (
                            <label key={p.key} className={`flex items-start gap-3 rounded-lg border p-3 ${locked ? "opacity-80" : "cursor-pointer hover:bg-accent/50"}`}>
                              <Checkbox checked={p.super_admin_only && selected.editable ? false : checked} disabled={locked}
                                onCheckedChange={(v) => toggle(p.key, v === true)} className="mt-0.5" />
                              <span className="grid gap-0.5">
                                <span className="text-sm font-medium">{p.label}</span>
                                <span className="font-mono text-xs text-muted-foreground">
                                  {p.key}{p.super_admin_only ? " · super-administrateur seulement" : ""}
                                </span>
                              </span>
                            </label>
                          )
                        })}
                      </div>
                      <Separator className="mt-2" />
                    </div>
                  )
                })}
              </CardContent>
              {editable && (
                <CardFooter className="sticky bottom-0 justify-end gap-2 border-t bg-card/95 backdrop-blur">
                  <span className="mr-auto text-sm text-muted-foreground">{draft.permissions.size} permissions cochées</span>
                  <Button variant="outline" disabled={!dirty || busy}
                    onClick={() => setDraft({ label: selected.label, description: selected.description ?? "", permissions: new Set(selected.permissions) })}>
                    Annuler
                  </Button>
                  <Button disabled={!dirty || busy || draft.label.trim().length < 2} onClick={save}>Enregistrer</Button>
                </CardFooter>
              )}
            </>
          ) : (
            <CardContent className="grid gap-3 py-6">{Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-14" />)}</CardContent>
          )}
        </Card>
      </div>

      <Dialog open={creating} onOpenChange={setCreating}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Nouveau rôle</DialogTitle>
            <DialogDescription>Donne-lui un nom, puis coche ses permissions. Tu peux partir d&apos;un rôle existant.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-2">
              <Label htmlFor="new-label">Nom</Label>
              <Input id="new-label" maxLength={80} value={newLabel} onChange={(e) => setNewLabel(e.target.value)} placeholder="Modération Assimé" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="new-desc">Description</Label>
              <Textarea id="new-desc" maxLength={500} value={newDescription} onChange={(e) => setNewDescription(e.target.value)} placeholder="À quoi sert ce rôle" />
            </div>
            <div className="grid gap-2">
              <Label>Partir de</Label>
              <Select value={copyFrom} onValueChange={setCopyFrom}>
                <SelectTrigger className="w-full"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">Aucun (tableau de bord seulement)</SelectItem>
                  {(roles ?? []).filter((r) => r.editable).map((r) => <SelectItem key={r.key} value={r.key}>{r.label}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreating(false)}>Annuler</Button>
            <Button disabled={busy || newLabel.trim().length < 2} onClick={create}>Créer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleting !== null} onOpenChange={(o) => !o && setDeleting(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Supprimer le rôle « {deleting?.label} » ?</DialogTitle>
            <DialogDescription>Aucun membre ne l&apos;a. La suppression est définitive et reste dans le journal d&apos;audit.</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleting(null)}>Annuler</Button>
            <Button variant="destructive" disabled={busy} onClick={remove}>Supprimer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </ConsoleShell>
  )
}
