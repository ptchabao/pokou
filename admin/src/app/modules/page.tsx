"use client"

import * as React from "react"
import { toast } from "sonner"
import { ConsoleShell } from "@/components/console-shell"
import { Card, CardAction, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Switch } from "@/components/ui/switch"
import { Badge } from "@/components/ui/badge"
import { useApi } from "@/lib/auth"
import { api } from "@/lib/api"

type Module = { id: number; slug: string; name: string; tagline: string | null; category: string | null
  is_enabled: boolean; is_recommended: boolean; user_count: number }

export default function ModulesPage() {
  const list = useApi<{ items: Module[] }>("/admin/modules")
  async function toggle(m: Module, field: "is_enabled" | "is_recommended", value: boolean) {
    try {
      await api(`/admin/modules/${m.slug}`, { method: "PUT", body: { [field]: value } })
      toast.success(`${m.name} : ${field === "is_enabled" ? (value ? "ouvert" : "fermé") : value ? "recommandé" : "plus recommandé"}`)
      list.reload()
    } catch (e) { toast.error((e as Error).message) }
  }
  return (
    <ConsoleShell title="Modules" permission="modules.manage">
      <p className="text-sm text-muted-foreground">
        Fermer un module ne supprime aucune activation : elles reprennent à la réouverture.
      </p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <div className="grid grid-cols-1 gap-4 @xl/main:grid-cols-2 @5xl/main:grid-cols-3">
        {list.data?.items.map((m) => (
          <Card key={m.slug}>
            <CardHeader>
              <CardTitle>{m.name}</CardTitle>
              <CardDescription>{m.tagline}</CardDescription>
              <CardAction><Switch checked={m.is_enabled} onCheckedChange={(v) => toggle(m, "is_enabled", v)} /></CardAction>
            </CardHeader>
            <CardFooter className="flex items-center justify-between text-sm text-muted-foreground">
              <span>{m.user_count} activations{m.category ? ` · ${m.category}` : ""}</span>
              <button onClick={() => toggle(m, "is_recommended", !m.is_recommended)}>
                {m.is_recommended ? <Badge>Recommandé</Badge> : <Badge variant="outline">Recommander</Badge>}
              </button>
            </CardFooter>
          </Card>
        ))}
      </div>
    </ConsoleShell>
  )
}
