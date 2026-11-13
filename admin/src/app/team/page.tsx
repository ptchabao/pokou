"use client"

import * as React from "react"
import { IconCheck, IconUserPlus } from "@tabler/icons-react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useApi, useAuth } from "@/lib/auth"
import { api, when } from "@/lib/api"
import { ActiveBadge, PERMISSION_LABELS, ROLE_OPTIONS } from "@/lib/labels"
import type { AdminUser } from "@/lib/types"

type Role = { role: string; label: string; permissions: string[] }

export default function TeamPage() {
  const { me, can } = useAuth()
  const team = useApi<{ items: AdminUser[] }>("/admin/team")
  const roles = useApi<{ items: Role[] }>("/admin/roles")
  const [adding, setAdding] = React.useState(false)
  const [email, setEmail] = React.useState("")
  const [name, setName] = React.useState("")
  const [secret, setSecret] = React.useState<{ email: string; password: string } | null>(null)
  const [newRole, setNewRole] = React.useState("SUPPORT")
  const manage = can("team.manage")
  const [editing, setEditing] = React.useState<AdminUser | null>(null)
  const [editName, setEditName] = React.useState("")
  const [editEmail, setEditEmail] = React.useState("")
  const [cutting, setCutting] = React.useState<AdminUser | null>(null)
  const [busy, setBusy] = React.useState(false)
  const emailRe = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

  async function saveProfile() {
    if (!editing) return
    setBusy(true)
    try {
      await api(`/admin/team/${editing.id}/profile`, { method: "PUT", body: { full_name: editName.trim(), email: editEmail.trim() } })
      toast.success("Membre modifié")
      setEditing(null)
      team.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  async function cutAccess() {
    if (!cutting) return
    setBusy(true)
    try {
      await api(`/admin/team/${cutting.id}/console-access/disable`, { method: "POST" })
      toast.success("Accès à la console coupé")
      setCutting(null)
      team.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  async function changeRole(u: AdminUser, role: string) {
    try {
      await api(`/admin/team/${u.id}`, { method: "PUT", body: { role } })
      toast.success(role === "USER" ? "Retiré de l'équipe" : "Rôle modifié")
      team.reload()
    } catch (e) { toast.error((e as Error).message) }
  }

  async function add() {
    try {
      const r = await api<AdminUser & { temporary_password: string | null }>("/admin/team", {
        body: { email: email.trim(), full_name: name.trim(), role: newRole },
      })
      toast.success("Ajouté à l'équipe")
      setAdding(false); setEmail(""); setName("")
      if (r.temporary_password) setSecret({ email: r.email ?? email.trim(), password: r.temporary_password })
      team.reload()
    } catch (e) { toast.error((e as Error).message) }
  }

  async function resetPassword(u: AdminUser) {
    try {
      const r = await api<{ temporary_password: string }>(`/admin/team/${u.id}/reset-password`, { method: "POST" })
      setSecret({ email: u.email ?? "", password: r.temporary_password })
      team.reload()
    } catch (e) { toast.error((e as Error).message) }
  }

  const allPerms = Object.keys(PERMISSION_LABELS)
  return (
    <ConsoleShell title="Équipe et rôles" permission="team.view"
      actions={manage && <Button size="sm" onClick={() => setAdding(true)}><IconUserPlus />Ajouter</Button>}>
      <SimpleTable
        rows={team.data?.items ?? null}
        empty="Personne dans l'équipe." illustration="team"
        columns={[
          { header: "Nom", cell: (u) => <span className="font-medium">{u.full_name ?? "—"}{u.id === me?.id && " (toi)"}</span> },
          { header: "E-mail", cell: (u) => u.email ?? <span className="text-muted-foreground">sans accès console</span> },
          { header: "Rôle", cell: (u) => manage && u.id !== me?.id ? (
            <Select value={u.role} onValueChange={(v) => changeRole(u, v)}>
              <SelectTrigger size="sm" className="w-52"><SelectValue /></SelectTrigger>
              <SelectContent>
                {ROLE_OPTIONS.map((r) => <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>)}
              </SelectContent>
            </Select>
          ) : u.role_label },
          { header: "Compte", cell: (u) => <ActiveBadge active={u.is_active} /> },
          { header: "Console", cell: (u) => u.console_access
            ? <Badge variant="secondary">Accès ouvert</Badge>
            : <Badge variant="outline">Accès coupé</Badge> },
          { header: "Vu le", cell: (u) => when(u.last_seen_at) },
          { header: "", className: "text-right", cell: (u) => manage ? (
            <div className="flex justify-end gap-1">
              <Button size="sm" variant="ghost" onClick={() => { setEditName(u.full_name ?? ""); setEditEmail(u.email ?? ""); setEditing(u) }}>
                Modifier
              </Button>
              {u.id !== me?.id && u.email && (
                <Button size="sm" variant="outline" onClick={() => resetPassword(u)}>
                  {u.console_access ? "Nouveau mot de passe" : "Rétablir l'accès"}
                </Button>
              )}
              {u.id !== me?.id && u.console_access && (
                <Button size="sm" variant="ghost" className="text-destructive" onClick={() => setCutting(u)}>Couper l&apos;accès</Button>
              )}
            </div>
          ) : null },
        ]}
      />
      <Card>
        <CardHeader>
          <CardTitle>Ce que chaque rôle permet</CardTitle>
          <CardDescription>
            Les droits sont vérifiés par l&apos;API à chaque requête : la console ne fait que cacher ce qui serait refusé.
          </CardDescription>
        </CardHeader>
        <CardContent className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Permission</TableHead>
                {roles.data?.items.map((r) => <TableHead key={r.role} className="text-center">{r.label}</TableHead>)}
              </TableRow>
            </TableHeader>
            <TableBody>
              {allPerms.map((p) => (
                <TableRow key={p}>
                  <TableCell>{PERMISSION_LABELS[p]}</TableCell>
                  {roles.data?.items.map((r) => (
                    <TableCell key={r.role} className="text-center">
                      {r.permissions.includes(p) ? <IconCheck className="mx-auto size-4 text-primary" /> : <span className="text-muted-foreground">·</span>}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
      <Dialog open={adding} onOpenChange={setAdding}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Ajouter un membre</DialogTitle>
            <DialogDescription>
              Un compte de console est créé avec un mot de passe provisoire, à transmettre à la personne.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-2">
              <Label htmlFor="name">Nom</Label>
              <Input id="name" value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="email">E-mail</Label>
              <Input id="email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="prenom@pokou.app" />
            </div>
            <div className="grid gap-2">
              <Label>Rôle</Label>
              <Select value={newRole} onValueChange={setNewRole}>
                <SelectTrigger className="w-full"><SelectValue /></SelectTrigger>
                <SelectContent>
                  {ROLE_OPTIONS.filter((r) => r.value !== "USER").map((r) => <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAdding(false)}>Annuler</Button>
            <Button disabled={!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim()) || name.trim().length < 2} onClick={add}>Ajouter</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={editing !== null} onOpenChange={(o) => !o && setEditing(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Modifier le membre</DialogTitle>
            <DialogDescription>L&apos;e-mail sert d&apos;identifiant de connexion à la console.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-2">
              <Label htmlFor="edit-name">Nom</Label>
              <Input id="edit-name" maxLength={120} value={editName} onChange={(e) => setEditName(e.target.value)} />
              {editName.trim().length > 0 && editName.trim().length < 2 && <p className="text-xs text-destructive">2 caractères au moins.</p>}
            </div>
            <div className="grid gap-2">
              <Label htmlFor="edit-email">E-mail</Label>
              <Input id="edit-email" type="email" value={editEmail} onChange={(e) => setEditEmail(e.target.value)} />
              {editEmail && !emailRe.test(editEmail.trim()) && <p className="text-xs text-destructive">Adresse invalide.</p>}
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditing(null)}>Annuler</Button>
            <Button disabled={busy || editName.trim().length < 2 || !emailRe.test(editEmail.trim())} onClick={saveProfile}>Enregistrer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={cutting !== null} onOpenChange={(o) => !o && setCutting(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Couper l&apos;accès de {cutting?.full_name ?? cutting?.email} à la console ?</DialogTitle>
            <DialogDescription>
              Son mot de passe de console est effacé et ses sessions de console sont fermées. Son compte et son rôle
              restent en place ; « Rétablir l&apos;accès » lui donnera un nouveau mot de passe provisoire.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCutting(null)}>Annuler</Button>
            <Button variant="destructive" disabled={busy} onClick={cutAccess}>Couper l&apos;accès</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={secret !== null} onOpenChange={(o) => !o && setSecret(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Mot de passe provisoire</DialogTitle>
            <DialogDescription>
              Affiché une seule fois. Transmets-le à la personne par un canal sûr : elle le changera à sa première connexion.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-1 rounded-lg bg-muted p-4 font-mono text-sm">
            <span>{secret?.email}</span>
            <span className="select-all text-base font-semibold">{secret?.password}</span>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => { navigator.clipboard?.writeText(secret?.password ?? ""); toast.success("Copié") }}>Copier</Button>
            <Button onClick={() => setSecret(null)}>J&apos;ai transmis le mot de passe</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </ConsoleShell>
  )
}
