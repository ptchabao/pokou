"use client"

import * as React from "react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { api } from "@/lib/api"
import { useAuth } from "@/lib/auth"

/** Définir ou changer le mot de passe de la console. */
export function PasswordDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { me, refresh } = useAuth()
  const [current, setCurrent] = React.useState("")
  const [next, setNext] = React.useState("")
  const [confirm, setConfirm] = React.useState("")
  const [busy, setBusy] = React.useState(false)
  React.useEffect(() => { if (open) { setCurrent(""); setNext(""); setConfirm("") } }, [open])
  const hasPassword = !!me?.has_console_password
  const valid = next.length >= 12 && next === confirm && (!hasPassword || current.length > 0)

  async function save() {
    setBusy(true)
    try {
      await api("/admin/me/password", { method: "PUT", body: { current_password: current || null, new_password: next } })
      toast.success("Mot de passe enregistré")
      await refresh()
      onOpenChange(false)
    } catch (e) {
      toast.error((e as Error).message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{hasPassword ? "Changer mon mot de passe" : "Définir un mot de passe"}</DialogTitle>
          <DialogDescription>
            Pour se connecter à la console par e-mail. Au moins 12 caractères.
          </DialogDescription>
        </DialogHeader>
        <div className="grid gap-3">
          {hasPassword && (
            <div className="grid gap-2">
              <Label htmlFor="current">Mot de passe actuel</Label>
              <Input id="current" type="password" autoComplete="current-password" value={current} onChange={(e) => setCurrent(e.target.value)} />
            </div>
          )}
          <div className="grid gap-2">
            <Label htmlFor="next">Nouveau mot de passe</Label>
            <Input id="next" type="password" autoComplete="new-password" value={next} onChange={(e) => setNext(e.target.value)} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="confirm">Confirmation</Label>
            <Input id="confirm" type="password" autoComplete="new-password" value={confirm} onChange={(e) => setConfirm(e.target.value)} />
            {confirm && next !== confirm && <p className="text-xs text-destructive">Les deux mots de passe diffèrent.</p>}
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Annuler</Button>
          <Button disabled={!valid || busy} onClick={save}>Enregistrer</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
