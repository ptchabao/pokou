"use client"

import * as React from "react"
import { IconLock } from "@tabler/icons-react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useApi } from "@/lib/auth"
import { api, when } from "@/lib/api"

type Setting = {
  key: string; group: string; label: string; help: string; secret: boolean; configured: boolean
  value: string | null; env_fallback: boolean; env_overrides: boolean
  updated_at: string | null; updated_by: string | null
}

type Pricing = {
  values: Record<string, number>
  defaults: Record<string, number>
  labels: Record<string, { label: string; help: string }>
}

/** Mêmes formats que ceux que l'API exige. */
const PATTERNS: Record<string, { re: RegExp; hint: string }> = {
  ngh_api_key: { re: /^\S{4,255}$/, hint: "4 caractères au moins, sans espace" },
  ngh_api_secret: { re: /^\S{4,255}$/, hint: "4 caractères au moins, sans espace" },
  semoa_login: { re: /^\S{1,255}$/, hint: "Sans espace" },
  semoa_api_key: { re: /^\S{4,255}$/, hint: "4 caractères au moins, sans espace" },
  semoa_api_reference: { re: /^\S{1,255}$/, hint: "Sans espace" },
  semoa_gateway_id: { re: /^\d{1,9}$/, hint: "Un nombre" },
  semoa_webhook_secret: { re: /^[A-Za-z0-9_-]{16,255}$/, hint: "16 caractères au moins : lettres, chiffres, - et _" },
  twilio_verify_service_sid: { re: /^VA[0-9a-fA-F]{32}$/, hint: "VA suivi de 32 caractères hexadécimaux" },
}

const PRICING_ORDER = ["service_price", "initiated_price", "tax_rate_bp", "min_recharge", "max_recharge"]

export default function SettingsPage() {
  const data = useApi<{ items: Setting[]; business_pricing: Pricing }>("/admin/settings")
  const [editing, setEditing] = React.useState<Setting | null>(null)
  const [value, setValue] = React.useState("")
  const [busy, setBusy] = React.useState(false)
  const [pricing, setPricing] = React.useState<Record<string, string> | null>(null)

  React.useEffect(() => {
    const v = data.data?.business_pricing.values
    if (v) setPricing(Object.fromEntries(PRICING_ORDER.map((k) => [k, String(v[k] ?? 0)])))
  }, [data.data])

  const groups = React.useMemo(() => {
    const map = new Map<string, Setting[]>()
    for (const s of data.data?.items ?? []) map.set(s.group, [...(map.get(s.group) ?? []), s])
    return [...map.entries()]
  }, [data.data])

  const pattern = editing ? PATTERNS[editing.key] : undefined
  const valueOk = value.trim().length > 0 && (!pattern || pattern.re.test(value.trim()))

  async function saveSetting() {
    if (!editing) return
    setBusy(true)
    try {
      await api(`/admin/settings/${editing.key}`, { method: "PUT", body: { value: value.trim() } })
      toast.success(`${editing.label} : enregistré`)
      setEditing(null)
      data.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  const pricingErrors: Record<string, string> = {}
  if (pricing) {
    for (const k of PRICING_ORDER) {
      const max = k === "tax_rate_bp" ? 5000 : k.endsWith("recharge") ? 100_000_000 : 100_000
      if (!/^\d+$/.test(pricing[k] ?? "") || Number(pricing[k]) > max) pricingErrors[k] = `Entier entre 0 et ${max.toLocaleString("fr-FR")}`
    }
    if (!pricingErrors.min_recharge && !pricingErrors.max_recharge && Number(pricing.min_recharge) > Number(pricing.max_recharge))
      pricingErrors.min_recharge = "Dépasse la recharge maximale"
  }

  async function savePricing() {
    if (!pricing) return
    setBusy(true)
    try {
      await api("/admin/settings/business/pricing", {
        method: "PUT", body: Object.fromEntries(PRICING_ORDER.map((k) => [k, Number(pricing[k])])),
      })
      toast.success("Tarifs Pokou Business enregistrés")
      data.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  const bp = data.data?.business_pricing
  return (
    <ConsoleShell title="Réglages système" permission="settings.manage">
      <p className="text-sm text-muted-foreground">
        Réglages lus par l&apos;API à chaque usage : un changement s&apos;applique sans redéploiement. Les valeurs
        secrètes ne sont jamais réaffichées, même masquées ; on peut seulement les remplacer.
      </p>
      {data.error && <p className="text-sm text-destructive">{data.error}</p>}
      {!data.data && !data.error && <p className="text-sm text-muted-foreground">Chargement…</p>}
      {groups.map(([group, items]) => (
        <Card key={group}>
          <CardHeader><CardTitle>{group}</CardTitle></CardHeader>
          <CardContent className="flex flex-col divide-y">
            {items.map((s) => (
              <div key={s.key} className="flex flex-col gap-2 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-start sm:justify-between">
                <div className="grid gap-1 text-sm">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-medium">{s.label}</span>
                    {s.secret && <Badge variant="outline"><IconLock className="size-3" />Secret</Badge>}
                    {s.configured
                      ? <Badge variant="secondary">Renseigné</Badge>
                      : s.env_fallback
                        ? <Badge variant="outline">Variable d&apos;environnement</Badge>
                        : <Badge variant="destructive">Non renseigné</Badge>}
                    {s.env_overrides && <Badge variant="outline">Remplacé par l&apos;environnement</Badge>}
                  </div>
                  <span className="text-muted-foreground">{s.help}</span>
                  {!s.secret && s.value && <code className="w-fit rounded bg-muted px-1.5 py-0.5 text-xs">{s.value}</code>}
                  {s.updated_at && (
                    <span className="text-xs text-muted-foreground">
                      Modifié le {when(s.updated_at)}{s.updated_by ? ` par ${s.updated_by}` : ""}
                    </span>
                  )}
                </div>
                <Button size="sm" variant="outline" className="shrink-0"
                  onClick={() => { setValue(s.secret ? "" : s.value ?? ""); setEditing(s) }}>
                  {s.secret ? (s.configured ? "Remplacer" : "Renseigner") : "Modifier"}
                </Button>
              </div>
            ))}
          </CardContent>
        </Card>
      ))}
      {bp && pricing && (
        <Card>
          <CardHeader>
            <CardTitle>Tarifs Pokou Business</CardTitle>
            <CardDescription>Prix des messages envoyés par les bots des entreprises, et bornes des recharges.</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            {PRICING_ORDER.map((k) => (
              <div key={k} className="grid gap-1.5">
                <Label htmlFor={k}>{bp.labels[k]?.label ?? k}</Label>
                <Input id={k} inputMode="numeric" value={pricing[k]} onChange={(e) => setPricing({ ...pricing, [k]: e.target.value })} />
                {pricingErrors[k]
                  ? <p className="text-xs text-destructive">{pricingErrors[k]}</p>
                  : <p className="text-xs text-muted-foreground">{bp.labels[k]?.help} Défaut : {bp.defaults[k]?.toLocaleString("fr-FR")}.</p>}
              </div>
            ))}
          </CardContent>
          <CardFooter className="justify-end">
            <Button disabled={busy || Object.keys(pricingErrors).length > 0} onClick={savePricing}>Enregistrer les tarifs</Button>
          </CardFooter>
        </Card>
      )}
      <Dialog open={editing !== null} onOpenChange={(o) => !o && setEditing(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing?.label}</DialogTitle>
            <DialogDescription>
              {editing?.secret
                ? "La nouvelle valeur remplace l'ancienne, qui n'est jamais réaffichée. Le changement est journalisé sans la valeur."
                : editing?.help}
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-1.5">
            <Label htmlFor="setting-value">{editing?.secret ? "Nouvelle valeur" : "Valeur"}</Label>
            <Input id="setting-value" type={editing?.secret ? "password" : "text"} autoComplete="off"
              value={value} onChange={(e) => setValue(e.target.value)} />
            {value && !valueOk
              ? <p className="text-xs text-destructive">{pattern?.hint ?? "Valeur invalide"}</p>
              : pattern && <p className="text-xs text-muted-foreground">{pattern.hint}</p>}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditing(null)}>Annuler</Button>
            <Button disabled={!valueOk || busy} onClick={saveSetting}>Enregistrer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </ConsoleShell>
  )
}
