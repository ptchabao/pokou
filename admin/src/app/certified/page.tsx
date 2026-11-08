"use client"

import * as React from "react"
import { toast } from "sonner"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { ReasonDialog } from "@/components/reason-dialog"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { useApi, useAuth } from "@/lib/auth"
import { api, when } from "@/lib/api"

type Application = {
  id: number; user_id: number; verified_name: string | null; business_name: string; activity: string | null
  city: string | null; document_media_id: number | null; review_due_at: string; overdue: boolean
}
type Decision = "APPROVE" | "CORRECTION" | "REJECT"

const TITLES: Record<Decision, string> = {
  APPROVE: "Approuver ce dossier Pro ?", CORRECTION: "Demander une correction ?", REJECT: "Refuser ce dossier ?",
}

export default function CertifiedPage() {
  const { can } = useAuth()
  const list = useApi<{ items: Application[] }>("/admin/certified/pro/pending")
  const [deciding, setDeciding] = React.useState<{ a: Application; decision: Decision } | null>(null)
  return (
    <ConsoleShell title="Pokou certifié · dossiers Pro" permission="certified.view">
      <p className="text-sm text-muted-foreground">Le plus proche de son échéance d&apos;examen en premier.</p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable rows={list.data?.items ?? null} empty="Aucun dossier en attente." illustration="certified"
        columns={[
          { header: "Entreprise", cell: (a) => (
            <div className="flex flex-col"><span className="font-medium">{a.business_name}</span>
              <span className="text-xs text-muted-foreground">{[a.activity, a.city].filter(Boolean).join(" · ")}</span></div>
          ) },
          { header: "Titulaire", cell: (a) => a.verified_name ?? "—" },
          { header: "Échéance", cell: (a) => (
            <div className="flex items-center gap-2">{when(a.review_due_at)}{a.overdue && <Badge variant="destructive">En retard</Badge>}</div>
          ) },
          { header: "", className: "text-right", cell: (a) => can("certified.manage") ? (
            <div className="flex justify-end gap-2">
              <Button size="sm" variant="ghost" onClick={() => setDeciding({ a, decision: "REJECT" })}>Refuser</Button>
              <Button size="sm" variant="outline" onClick={() => setDeciding({ a, decision: "CORRECTION" })}>À corriger</Button>
              <Button size="sm" onClick={() => setDeciding({ a, decision: "APPROVE" })}>Approuver</Button>
            </div>
          ) : null },
        ]} />
      <ReasonDialog open={deciding !== null} onOpenChange={(o) => !o && setDeciding(null)}
        optional={deciding?.decision === "APPROVE"} destructive={deciding?.decision === "REJECT"}
        title={deciding ? TITLES[deciding.decision] : ""}
        description={deciding?.decision === "APPROVE" ? undefined : "La personne reçoit ce message : dis-lui précisément ce qui ne va pas."}
        confirm={deciding?.decision === "APPROVE" ? "Approuver" : deciding?.decision === "CORRECTION" ? "Envoyer" : "Refuser"}
        onConfirm={async (note) => {
          if (!deciding) return
          try {
            await api(`/admin/certified/pro/${deciding.a.id}/review`, { body: { decision: deciding.decision, note: note || null } })
            toast.success("Décision enregistrée")
            list.reload()
          } catch (e) { toast.error((e as Error).message); throw e }
        }} />
    </ConsoleShell>
  )
}
