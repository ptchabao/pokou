"use client"

import * as React from "react"
import { toast } from "sonner"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { ReasonDialog } from "@/components/reason-dialog"
import { Button } from "@/components/ui/button"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useApi, useAuth } from "@/lib/auth"
import { api, when } from "@/lib/api"
import { StatusBadge } from "@/lib/labels"

type Verification = {
  id: number; seller_name: string; status: string; plan: string | null; duration_days: number | null
  identity_media_url: string | null; payment_status: string | null; reviewer_name: string | null
  review_note: string | null; created_at: string
}

export default function AssimePage() {
  const { can } = useAuth()
  const [status, setStatus] = React.useState("PENDING")
  const list = useApi<{ items: Verification[] }>(`/admin/marketplace/verifications?status=${status}`)
  const [deciding, setDeciding] = React.useState<{ v: Verification; approved: boolean } | null>(null)

  return (
    <ConsoleShell title="Assimé · vendeurs vérifiés" permission="assime.view">
      <Tabs value={status} onValueChange={setStatus}>
        <TabsList>
          <TabsTrigger value="PENDING">À examiner</TabsTrigger>
          <TabsTrigger value="APPROVED">Approuvés</TabsTrigger>
          <TabsTrigger value="REJECTED">Refusés</TabsTrigger>
        </TabsList>
      </Tabs>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable rows={list.data?.items ?? null} empty="Aucun dossier ici." illustration="assime"
        columns={[
          { header: "Vendeur", cell: (v) => <span className="font-medium">{v.seller_name}</span> },
          { header: "Formule", cell: (v) => v.plan ? `${v.plan}${v.duration_days ? ` · ${v.duration_days} j` : ""}` : "—" },
          { header: "Paiement", cell: (v) => <StatusBadge status={v.payment_status} /> },
          { header: "Pièce d'identité", cell: (v) => v.identity_media_url
            ? <a className="text-primary underline-offset-4 hover:underline" href={v.identity_media_url} target="_blank" rel="noreferrer">Ouvrir</a> : "—" },
          { header: "Déposé le", cell: (v) => when(v.created_at) },
          { header: "Statut", cell: (v) => (
            <div className="flex flex-col gap-1"><StatusBadge status={v.status} />
              {v.review_note && <span className="text-xs text-muted-foreground">{v.review_note}</span>}</div>
          ) },
          { header: "", className: "text-right", cell: (v) => v.status === "PENDING" && can("assime.manage") ? (
            <div className="flex justify-end gap-2">
              <Button size="sm" variant="outline" onClick={() => setDeciding({ v, approved: false })}>Refuser</Button>
              <Button size="sm" onClick={() => setDeciding({ v, approved: true })}>Approuver</Button>
            </div>
          ) : null },
        ]} />
      <ReasonDialog open={deciding !== null} onOpenChange={(o) => !o && setDeciding(null)}
        optional={deciding?.approved} destructive={deciding?.approved === false}
        title={deciding?.approved ? "Accorder le badge vendeur vérifié ?" : "Refuser ce dossier ?"}
        description={deciding?.approved ? undefined : "Le vendeur reçoit le motif : dis-lui quoi corriger."}
        confirm={deciding?.approved ? "Approuver" : "Refuser"}
        onConfirm={async (note) => {
          if (!deciding) return
          try {
            await api(`/admin/marketplace/verifications/${deciding.v.id}`, { method: "PUT", body: { approved: deciding.approved, note: note || null } })
            toast.success(deciding.approved ? "Badge accordé" : "Dossier refusé")
            list.reload()
          } catch (e) { toast.error((e as Error).message); throw e }
        }} />
    </ConsoleShell>
  )
}
