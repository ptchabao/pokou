"use client"

import * as React from "react"
import { toast } from "sonner"
import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useApi, useAuth } from "@/lib/auth"
import { api, when } from "@/lib/api"
import { StatusBadge } from "@/lib/labels"
import type { Paged } from "@/lib/types"

type Order = { id: number; status: string; pharmacy: string | null; created_at: string }
type Pharmacy = { id: number; name: string; status: string | null; city: string | null }
type Courier = { user_id: number; name: string | null; country: string | null; zones: unknown; wallet_phone: string | null }

export default function HonamPage() {
  const { can } = useAuth()
  const [page, setPage] = React.useState(1)
  const orders = useApi<Paged<Order>>(`/admin/honam/orders?page=${page}&size=25`)
  const pharmacies = useApi<{ items: Pharmacy[] }>("/admin/honam/pharmacies")
  const couriers = useApi<{ items: Courier[] }>(can("honam.manage") ? "/admin/honam/couriers/pending" : null)

  async function validate(c: Courier) {
    try {
      await api(`/admin/honam/couriers/${c.user_id}/validate`, { method: "POST" })
      toast.success(`${c.name ?? "Coursier"} validé`)
      couriers.reload()
    } catch (e) { toast.error((e as Error).message) }
  }

  return (
    <ConsoleShell title="Honam · pharmacie" permission="honam.view">
      <Tabs defaultValue="orders">
        <TabsList>
          <TabsTrigger value="orders">Commandes</TabsTrigger>
          <TabsTrigger value="pharmacies">Pharmacies</TabsTrigger>
          {can("honam.manage") && <TabsTrigger value="couriers">Coursiers à valider</TabsTrigger>}
        </TabsList>
        <TabsContent value="orders" className="flex flex-col gap-3">
          <p className="text-sm text-muted-foreground">
            Données de santé protégées : la console ne montre jamais l&apos;ordonnance ni les produits, seulement l&apos;étape.
          </p>
          <SimpleTable rows={orders.data?.items ?? null} page={page} total={orders.data?.total} size={25} onPage={setPage}
            empty="Aucune commande." illustration="honam"
            columns={[
              { header: "N°", cell: (o) => `#${o.id}` },
              { header: "Pharmacie", cell: (o) => o.pharmacy ?? "—" },
              { header: "Étape", cell: (o) => <StatusBadge status={o.status} /> },
              { header: "Créée le", cell: (o) => when(o.created_at) },
            ]} />
        </TabsContent>
        <TabsContent value="pharmacies">
          <SimpleTable rows={pharmacies.data?.items ?? null} empty="Aucune pharmacie partenaire." illustration="honam"
            columns={[
              { header: "Pharmacie", cell: (p) => <span className="font-medium">{p.name}</span> },
              { header: "Ville", cell: (p) => p.city ?? "—" },
              { header: "Statut", cell: (p) => <StatusBadge status={p.status} /> },
            ]} />
        </TabsContent>
        <TabsContent value="couriers">
          <SimpleTable rows={couriers.data?.items ?? null} empty="Aucune candidature en attente." illustration="delivery"
            columns={[
              { header: "Coursier", cell: (c) => <span className="font-medium">{c.name ?? "—"}</span> },
              { header: "Pays", cell: (c) => c.country ?? "—" },
              { header: "Zones", cell: (c) => Array.isArray(c.zones) ? c.zones.join(", ") : String(c.zones ?? "—") },
              { header: "Mobile money", cell: (c) => c.wallet_phone ?? "—" },
              { header: "", className: "text-right", cell: (c) => <Button size="sm" onClick={() => validate(c)}>Valider</Button> },
            ]} />
        </TabsContent>
      </Tabs>
    </ConsoleShell>
  )
}
