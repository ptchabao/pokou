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
import { useApi, useAuth } from "@/lib/auth"
import { api, when } from "@/lib/api"
import { ActiveBadge, ROLE_OPTIONS } from "@/lib/labels"
import type { AdminUser, Paged } from "@/lib/types"

type Detail = AdminUser & {
  stats: Record<string, number>
  certified: { status: string; plan: string } | null
  devices: { platform: string; registered_at: string | null }[]
}

const STAT_LABELS: Record<string, string> = {
  groups: "Groupes", direct_sent: "Messages directs envoyés", pots_organized: "Cagnottes Kory organisées",
  honam_orders: "Commandes Honam", products: "Annonces Assimé", reports_received: "Signalements reçus",
}

export default function UsersPage() {
  const { can } = useAuth()
  const [q, setQ] = React.useState("")
  const [search, setSearch] = React.useState("")
  const [status, setStatus] = React.useState("all")
  const [role, setRole] = React.useState("all")
  const [page, setPage] = React.useState(1)
  const params = new URLSearchParams({ page: String(page), size: "25" })
  if (search) params.set("q", search)
  if (status !== "all") params.set("status", status)
  if (role !== "all") params.set("role", role)
  const list = useApi<Paged<AdminUser>>(`/admin/users?${params}`)
  const [selected, setSelected] = React.useState<number | null>(null)
  const detail = useApi<Detail>(selected ? `/admin/users/${selected}` : null)
  const [suspending, setSuspending] = React.useState(false)

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

  const d = selected && detail.data?.id === selected ? detail.data : null
  return (
    <ConsoleShell title="Utilisateurs" permission="users.view">
      <div className="flex flex-wrap items-center gap-2">
        <Input className="max-w-xs" placeholder="Nom ou numéro…" value={q} onChange={(e) => setQ(e.target.value)} />
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(1) }}>
          <SelectTrigger className="w-40"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Tous les statuts</SelectItem>
            <SelectItem value="active">Actifs</SelectItem>
            <SelectItem value="suspended">Suspendus</SelectItem>
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
          { header: "Statut", cell: (u) => <ActiveBadge active={u.is_active} /> },
          { header: "Inscrit le", cell: (u) => when(u.created_at) },
          { header: "Vu le", cell: (u) => when(u.last_seen_at) },
        ]}
      />
      <Sheet open={selected !== null} onOpenChange={(o) => !o && setSelected(null)}>
        <SheetContent className="overflow-y-auto">
          <SheetHeader>
            <SheetTitle>{d?.full_name ?? "Utilisateur"}</SheetTitle>
            <SheetDescription>{d?.phone}</SheetDescription>
          </SheetHeader>
          {d ? (
            <div className="flex flex-col gap-4 px-4 pb-6 text-sm">
              <div className="flex items-center gap-2">
                <ActiveBadge active={d.is_active} />
                <span className="text-muted-foreground">{d.role === "USER" ? "Utilisateur" : d.role_label}</span>
              </div>
              <div className="grid grid-cols-2 gap-y-1">
                <span className="text-muted-foreground">Inscrit le</span><span>{when(d.created_at)}</span>
                <span className="text-muted-foreground">Vu le</span><span>{when(d.last_seen_at)}</span>
                <span className="text-muted-foreground">Pokou certifié</span>
                <span>{d.certified ? `${d.certified.plan} · ${d.certified.status}` : "Non"}</span>
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
                    <span key={i} className="text-muted-foreground">
                      {device.platform === "ios" ? "iPhone" : device.platform === "android" ? "Android" : device.platform}
                      {" · enregistré le "}
                      {when(device.registered_at)}
                    </span>
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
              {can("users.manage") && (
                d.is_active
                  ? <Button variant="destructive" onClick={() => setSuspending(true)}>Suspendre le compte</Button>
                  : <Button onClick={() => reactivate(d.id)}>Réactiver le compte</Button>
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
    </ConsoleShell>
  )
}
