"use client"

import * as React from "react"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Textarea } from "@/components/ui/textarea"

/** Confirmation qui exige un motif écrit (il part au journal d'audit). */
export function ReasonDialog({
  open, onOpenChange, title, description, confirm, destructive, optional, onConfirm,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description?: string
  confirm: string
  destructive?: boolean
  optional?: boolean
  onConfirm: (reason: string) => Promise<void>
}) {
  const [reason, setReason] = React.useState("")
  const [busy, setBusy] = React.useState(false)
  React.useEffect(() => { if (open) setReason("") }, [open])
  const ok = optional || reason.trim().length >= 3
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description && <DialogDescription>{description}</DialogDescription>}
        </DialogHeader>
        <Textarea placeholder={optional ? "Note (facultative)" : "Motif (obligatoire)"} value={reason}
          onChange={(e) => setReason(e.target.value)} maxLength={280} />
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Annuler</Button>
          <Button variant={destructive ? "destructive" : "default"} disabled={!ok || busy}
            onClick={async () => {
              setBusy(true)
              try { await onConfirm(reason.trim()); onOpenChange(false) } catch { /* déjà signalé */ } finally { setBusy(false) }
            }}>
            {confirm}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
