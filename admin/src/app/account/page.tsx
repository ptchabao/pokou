"use client"

import * as React from "react"
import { IconKey, IconShieldCheck } from "@tabler/icons-react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { PasswordDialog } from "@/components/password-dialog"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useAuth } from "@/lib/auth"
import { api } from "@/lib/api"
import { PERMISSION_LABELS } from "@/lib/labels"

/** « Mon profil » : nom, e-mail de connexion, mot de passe, et ce que mon rôle permet. */
export default function AccountPage() {
  const { me, refresh } = useAuth()
  const [name, setName] = React.useState("")
  const [email, setEmail] = React.useState("")
  const [busy, setBusy] = React.useState(false)
  const [passwordOpen, setPasswordOpen] = React.useState(false)
  const emailRe = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

  React.useEffect(() => {
    setName(me?.full_name ?? "")
    setEmail(me?.email ?? "")
  }, [me?.full_name, me?.email])

  const dirty = name.trim() !== (me?.full_name ?? "") || email.trim().toLowerCase() !== (me?.email ?? "").toLowerCase()
  const initials = (me?.full_name ?? "P").split(" ").slice(0, 2).map((w) => w[0]?.toUpperCase()).join("")

  async function save() {
    setBusy(true)
    try {
      await api("/admin/me/profile", { method: "PUT", body: { full_name: name.trim(), email: email.trim() } })
      toast.success("Profil enregistré")
      await refresh()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  return (
    <ConsoleShell title="Mon profil" permission="dashboard.view">
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <Card>
          <CardHeader className="flex flex-row items-center gap-4">
            <Avatar className="size-14 rounded-xl">
              <AvatarFallback className="rounded-xl text-lg">{initials}</AvatarFallback>
            </Avatar>
            <div className="grid gap-1">
              <CardTitle>{me?.full_name ?? me?.email}</CardTitle>
              <CardDescription className="flex items-center gap-2">
                <Badge variant="secondary"><IconShieldCheck className="size-3" />{me?.role_label}</Badge>
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="grid gap-4">
            <div className="grid gap-2">
              <Label htmlFor="me-name">Nom</Label>
              <Input id="me-name" maxLength={120} value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="me-email">E-mail de connexion</Label>
              <Input id="me-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
              {email && !emailRe.test(email.trim()) && <p className="text-xs text-destructive">Adresse invalide.</p>}
            </div>
          </CardContent>
          <CardFooter className="justify-between gap-2">
            <Button variant="outline" onClick={() => setPasswordOpen(true)}><IconKey />Changer mon mot de passe</Button>
            <Button disabled={!dirty || busy || name.trim().length < 2 || !emailRe.test(email.trim())} onClick={save}>Enregistrer</Button>
          </CardFooter>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Ce que mon rôle permet</CardTitle>
            <CardDescription>{me?.permissions.length ?? 0} permissions · rôle « {me?.role_label} »</CardDescription>
          </CardHeader>
          <CardContent>
            <ul className="grid gap-2 sm:grid-cols-2">
              {(me?.permissions ?? []).map((p) => (
                <li key={p} className="rounded-lg border px-3 py-2 text-sm">
                  {PERMISSION_LABELS[p] ?? p}
                  <span className="block font-mono text-xs text-muted-foreground">{p}</span>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      </div>
      <PasswordDialog open={passwordOpen} onOpenChange={setPasswordOpen} />
    </ConsoleShell>
  )
}
