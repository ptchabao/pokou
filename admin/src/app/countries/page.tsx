"use client"

import * as React from "react"
import { IconPlus, IconRestore } from "@tabler/icons-react"
import { toast } from "sonner"

import { ConsoleShell } from "@/components/console-shell"
import { SimpleTable } from "@/components/simple-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Separator } from "@/components/ui/separator"
import { Sheet, SheetContent, SheetDescription, SheetFooter, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { Textarea } from "@/components/ui/textarea"
import { useApi, useAuth } from "@/lib/auth"
import { api, when } from "@/lib/api"

type Config = {
  currency: string
  vat_rate: number
  delivery_price: number | null
  pharmacy_monthly_price: number | null
  pharmacy_yearly_price: number | null
  kory_plus_fee_ht: number
  honam_cities: string[]
  emergency_numbers: { police?: string; pompiers?: string; samu?: string }
  modules: string[]
}

type CountryRow = {
  code: string; builtin: boolean; has_override: boolean; updated_at: string | null
  currency: string; vat_rate: number; modules: string[]
}

type CountryDetail = {
  code: string; builtin: boolean; has_override: boolean; updated_at: string | null
  config: Config; defaults: Config; always_open: string[]; modules_known: string[]
}

type Form = {
  currency: string; vat: string; delivery: string; monthly: string; yearly: string; koryFee: string
  cities: string; police: string; pompiers: string; samu: string; modules: string[]
}

const MODULE_LABELS: Record<string, string> = {
  discussions: "Discussions", kory: "Kory", kory_plus: "Kory Plus (tontine)", honam: "Honam",
  assime: "Assimé", certified: "Pokou certifié",
}

const countryName = (code: string) => {
  try {
    return new Intl.DisplayNames(["fr"], { type: "region" }).of(code) ?? code
  } catch {
    return code
  }
}

const num = (v: number | null | undefined) => (v === null || v === undefined ? "" : String(v))

function toForm(c: Config): Form {
  return {
    currency: c.currency ?? "XOF",
    vat: String(Math.round((c.vat_rate ?? 0) * 10000) / 100),
    delivery: num(c.delivery_price), monthly: num(c.pharmacy_monthly_price), yearly: num(c.pharmacy_yearly_price),
    koryFee: num(c.kory_plus_fee_ht),
    cities: (c.honam_cities ?? []).join("\n"),
    police: c.emergency_numbers?.police ?? "", pompiers: c.emergency_numbers?.pompiers ?? "",
    samu: c.emergency_numbers?.samu ?? "",
    modules: c.modules ?? [],
  }
}

const INT = /^\d+$/

/** Valide le formulaire ; rend le corps de la requête ou la liste des erreurs. */
function validate(f: Form): { body?: Config; errors: Record<string, string> } {
  const errors: Record<string, string> = {}
  const optionalInt = (key: string, v: string, max: number) => {
    if (v.trim() === "") return null
    if (!INT.test(v.trim()) || Number(v) > max) { errors[key] = `Entier entre 0 et ${max.toLocaleString("fr-FR")}`; return null }
    return Number(v)
  }
  if (!/^[A-Z]{3}$/.test(f.currency.trim())) errors.currency = "Code à 3 lettres majuscules (ex. XOF)"
  const vat = Number(f.vat.replace(",", "."))
  if (f.vat.trim() === "" || Number.isNaN(vat) || vat < 0 || vat > 50) errors.vat = "Entre 0 et 50 %"
  const delivery = optionalInt("delivery", f.delivery, 100_000)
  const monthly = optionalInt("monthly", f.monthly, 10_000_000)
  const yearly = optionalInt("yearly", f.yearly, 10_000_000)
  if (monthly !== null && yearly !== null && yearly < monthly) errors.yearly = "L'annuel ne peut coûter moins que le mensuel"
  let koryFee = 0
  if (!INT.test(f.koryFee.trim()) || Number(f.koryFee) > 100_000) errors.koryFee = "Entier entre 0 et 100 000"
  else koryFee = Number(f.koryFee)
  const cities = f.cities.split("\n").map((c) => c.trim().replace(/\s+/g, " ")).filter(Boolean)
  if (cities.some((c) => c.length < 2 || c.length > 60)) errors.cities = "Chaque ville : 2 à 60 caractères"
  if (cities.length > 50) errors.cities = "50 villes au plus"
  const emergency: Config["emergency_numbers"] = {}
  for (const k of ["police", "pompiers", "samu"] as const) {
    const v = f[k].trim()
    if (v === "") continue
    if (!/^\d{2,10}$/.test(v)) errors[k] = "2 à 10 chiffres"
    else emergency[k] = v
  }
  if (Object.keys(errors).length) return { errors }
  return {
    errors,
    body: {
      currency: f.currency.trim(), vat_rate: Math.round(vat * 100) / 10000, delivery_price: delivery,
      pharmacy_monthly_price: monthly, pharmacy_yearly_price: yearly, kory_plus_fee_ht: koryFee,
      honam_cities: cities,
      emergency_numbers: { police: emergency.police ?? null, pompiers: emergency.pompiers ?? null, samu: emergency.samu ?? null } as Config["emergency_numbers"],
      modules: f.modules,
    },
  }
}

function Field({ id, label, hint, error, children }: { id: string; label: string; hint?: string; error?: string; children: React.ReactNode }) {
  return (
    <div className="grid gap-1.5">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {error ? <p className="text-xs text-destructive">{error}</p> : hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  )
}

export default function CountriesPage() {
  const { can } = useAuth()
  const manage = can("countries.manage")
  const list = useApi<{ items: CountryRow[]; modules: string[] }>("/admin/countries")
  const [selected, setSelected] = React.useState<string | null>(null)
  const detail = useApi<CountryDetail>(selected ? `/admin/countries/${selected}` : null)
  const [form, setForm] = React.useState<Form | null>(null)
  const [busy, setBusy] = React.useState(false)
  const [adding, setAdding] = React.useState(false)
  const [newCode, setNewCode] = React.useState("")
  const [resetting, setResetting] = React.useState(false)

  const d = selected && detail.data?.code === selected ? detail.data : null
  React.useEffect(() => { if (d) setForm(toForm(d.config)) }, [d])

  const set = (patch: Partial<Form>) => setForm((f) => (f ? { ...f, ...patch } : f))
  const checked = form ? validate(form) : null
  const errors = checked?.errors ?? {}

  async function save() {
    if (!checked?.body || !selected) return
    setBusy(true)
    try {
      await api(`/admin/countries/${selected}`, { method: "PUT", body: checked.body })
      toast.success(`${countryName(selected)} : configuration enregistrée`)
      detail.reload(); list.reload()
    } catch (e) { toast.error((e as Error).message) } finally { setBusy(false) }
  }

  async function reset() {
    if (!selected) return
    try {
      await api(`/admin/countries/${selected}`, { method: "DELETE" })
      toast.success("Valeurs par défaut rétablies")
      const builtin = d?.builtin
      list.reload()
      if (builtin) detail.reload()
      else setSelected(null)
    } catch (e) { toast.error((e as Error).message) }
  }

  const codeOk = /^[A-Za-z]{2}$/.test(newCode.trim())
  const known = new Set(list.data?.items.map((c) => c.code) ?? [])

  return (
    <ConsoleShell title="Configuration des pays" permission="countries.view"
      actions={manage && <Button size="sm" onClick={() => { setNewCode(""); setAdding(true) }}><IconPlus />Ajouter un pays</Button>}>
      <p className="text-sm text-muted-foreground">
        L&apos;application lit cette configuration au démarrage (modules ouverts, prix, numéros d&apos;urgence) selon
        l&apos;indicatif du numéro de la personne. Un changement s&apos;applique sans publication.
      </p>
      {list.error && <p className="text-sm text-destructive">{list.error}</p>}
      <SimpleTable
        rows={list.data?.items ?? null}
        onRowClick={(c) => setSelected(c.code)}
        empty="Aucun pays configuré."
        columns={[
          { header: "Pays", cell: (c) => <span className="font-medium">{countryName(c.code)} <span className="text-muted-foreground">({c.code})</span></span> },
          { header: "Modules", cell: (c) => (
            <div className="flex flex-wrap gap-1">{c.modules.map((m) => <Badge key={m} variant="outline">{MODULE_LABELS[m] ?? m}</Badge>)}</div>
          ) },
          { header: "Devise", cell: (c) => c.currency },
          { header: "TVA", cell: (c) => `${Math.round(c.vat_rate * 10000) / 100} %` },
          { header: "Réglage", cell: (c) => c.has_override
            ? <Badge>Personnalisé</Badge>
            : <span className="text-muted-foreground">Par défaut</span> },
          { header: "Modifié le", cell: (c) => when(c.updated_at) },
        ]}
      />

      <Sheet open={selected !== null} onOpenChange={(o) => !o && setSelected(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-xl">
          <SheetHeader>
            <SheetTitle>{selected ? `${countryName(selected)} (${selected})` : "Pays"}</SheetTitle>
            <SheetDescription>
              {d ? (d.has_override ? `Personnalisé · modifié le ${when(d.updated_at)}` : d.builtin ? "Valeurs par défaut" : "Configuration générique (pays non configuré)") : ""}
            </SheetDescription>
          </SheetHeader>
          {d && form ? (
            <fieldset disabled={!manage} className="flex flex-col gap-5 px-4 pb-2 text-sm">
              <div className="grid gap-2">
                <span className="font-medium">Modules ouverts</span>
                <div className="grid grid-cols-2 gap-2">
                  {d.modules_known.map((m) => {
                    const forced = d.always_open.includes(m)
                    return (
                      <label key={m} className="flex items-center gap-2">
                        <Checkbox checked={forced || form.modules.includes(m)} disabled={forced || !manage}
                          onCheckedChange={(v) => set({ modules: v ? [...form.modules, m] : form.modules.filter((x) => x !== m) })} />
                        <span>{MODULE_LABELS[m] ?? m}</span>
                        {forced && <span className="text-xs text-muted-foreground">toujours ouvert</span>}
                      </label>
                    )
                  })}
                </div>
              </div>
              <Separator />
              <div className="grid grid-cols-2 gap-3">
                <Field id="currency" label="Devise" error={errors.currency}>
                  <Input id="currency" value={form.currency} maxLength={3} onChange={(e) => set({ currency: e.target.value.toUpperCase() })} />
                </Field>
                <Field id="vat" label="TVA (%)" error={errors.vat} hint={`Défaut : ${Math.round(d.defaults.vat_rate * 10000) / 100} %`}>
                  <Input id="vat" inputMode="decimal" value={form.vat} onChange={(e) => set({ vat: e.target.value })} />
                </Field>
                <Field id="delivery" label="Course Honam (FCFA)" error={errors.delivery} hint="Vide : pas de livraison">
                  <Input id="delivery" inputMode="numeric" value={form.delivery} onChange={(e) => set({ delivery: e.target.value })} />
                </Field>
                <Field id="koryFee" label="Frais Kory Plus HT (FCFA)" error={errors.koryFee} hint="Par membre, une fois">
                  <Input id="koryFee" inputMode="numeric" value={form.koryFee} onChange={(e) => set({ koryFee: e.target.value })} />
                </Field>
                <Field id="monthly" label="Officine : mensuel (FCFA)" error={errors.monthly}>
                  <Input id="monthly" inputMode="numeric" value={form.monthly} onChange={(e) => set({ monthly: e.target.value })} />
                </Field>
                <Field id="yearly" label="Officine : annuel (FCFA)" error={errors.yearly}>
                  <Input id="yearly" inputMode="numeric" value={form.yearly} onChange={(e) => set({ yearly: e.target.value })} />
                </Field>
              </div>
              <Separator />
              <Field id="cities" label="Villes Honam" error={errors.cities} hint="Une ville par ligne. Ailleurs, l'offre coursier laisse place à la liste d'attente.">
                <Textarea id="cities" rows={4} value={form.cities} onChange={(e) => set({ cities: e.target.value })} />
              </Field>
              <div className="grid grid-cols-3 gap-3">
                <Field id="police" label="Police" error={errors.police}>
                  <Input id="police" inputMode="numeric" value={form.police} onChange={(e) => set({ police: e.target.value })} />
                </Field>
                <Field id="pompiers" label="Pompiers" error={errors.pompiers}>
                  <Input id="pompiers" inputMode="numeric" value={form.pompiers} onChange={(e) => set({ pompiers: e.target.value })} />
                </Field>
                <Field id="samu" label="SAMU" error={errors.samu}>
                  <Input id="samu" inputMode="numeric" value={form.samu} onChange={(e) => set({ samu: e.target.value })} />
                </Field>
              </div>
            </fieldset>
          ) : (
            <p className="px-4 text-sm text-muted-foreground">{detail.error ?? "Chargement…"}</p>
          )}
          {d && form && manage && (
            <SheetFooter className="flex-row justify-between">
              <Button variant="outline" disabled={!d.has_override} onClick={() => setResetting(true)}>
                <IconRestore />Valeurs par défaut
              </Button>
              <Button disabled={!checked?.body || busy} onClick={save}>Enregistrer</Button>
            </SheetFooter>
          )}
        </SheetContent>
      </Sheet>

      <Dialog open={adding} onOpenChange={setAdding}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Ajouter un pays</DialogTitle>
            <DialogDescription>
              Code ISO à deux lettres (SN pour le Sénégal, BJ pour le Bénin…). La fiche part de la configuration
              générique ; elle n&apos;est créée qu&apos;à l&apos;enregistrement.
            </DialogDescription>
          </DialogHeader>
          <Field id="code" label="Code du pays"
            error={newCode && !codeOk ? "Deux lettres" : codeOk && known.has(newCode.trim().toUpperCase()) ? "Ce pays est déjà dans la liste" : undefined}
            hint={codeOk ? countryName(newCode.trim().toUpperCase()) : undefined}>
            <Input id="code" maxLength={2} value={newCode} onChange={(e) => setNewCode(e.target.value.toUpperCase())} placeholder="SN" />
          </Field>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAdding(false)}>Annuler</Button>
            <Button disabled={!codeOk || known.has(newCode.trim().toUpperCase())}
              onClick={() => { setAdding(false); setSelected(newCode.trim().toUpperCase()) }}>Continuer</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={resetting} onOpenChange={setResetting}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Revenir aux valeurs par défaut ?</DialogTitle>
            <DialogDescription>
              {d?.builtin
                ? "Le réglage personnalisé est supprimé : le pays reprend les valeurs écrites dans le code."
                : "Le réglage est supprimé : le pays retombe sur la configuration générique et sort de la liste."}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setResetting(false)}>Annuler</Button>
            <Button variant="destructive" onClick={async () => { setResetting(false); await reset() }}>Rétablir</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </ConsoleShell>
  )
}
