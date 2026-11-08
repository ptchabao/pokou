"use client"

import * as React from "react"
import { IconCheck, IconUserPlus } from "@tabler/icons-react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
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
          { header: "Vu le", cell: (u) => when(u.last_seen_at) },
          { header: "", className: "text-right", cell: (u) => manage && u.id !== me?.id && u.email ? (
            <Button size="sm" variant="outline" onClick={() => resetPassword(u)}>Nouveau mot de passe</Button>
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
