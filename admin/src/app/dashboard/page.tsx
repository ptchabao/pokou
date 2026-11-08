"use client"

import * as React from "react"
import { Area, AreaChart, CartesianGrid, XAxis } from "recharts"

import { ConsoleShell } from "@/components/console-shell"
import { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ChartConfig, ChartContainer, ChartLegend, ChartLegendContent, ChartTooltip, ChartTooltipContent } from "@/components/ui/chart"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { useApi, useAuth } from "@/lib/auth"
import { Illustration } from "@/components/illustration"
import { fcfa } from "@/lib/api"

type Overview = {
  users: { total: number; new_7d: number; active_7d: number }
  messages: { direct: number; group: number; days: number }
  groups: number
  kory: { open_pots: number; confirmed_amount: number }
  honam: { orders_by_status: Record<string, number>; pharmacies: number }
  assime: { live_products: number }
  certified: { active: number }
  reports: { open: number }
  activity: { date: string; signups: number; direct: number; group: number }[]
}

const nf = new Intl.NumberFormat("fr-FR")

function greeting() {
  const h = new Date().getHours()
  return h < 12 ? "Bonjour" : h < 18 ? "Bon après-midi" : "Bonsoir"
}

const chartConfig = {
  direct: { label: "Messages directs", color: "var(--chart-1)" },
  group: { label: "Messages de groupe", color: "var(--chart-2)" },
  signups: { label: "Inscriptions", color: "var(--chart-3)" },
} satisfies ChartConfig

function Stat({ label, value, hint, badge }: { label: string; value: string; hint?: string; badge?: React.ReactNode }) {
  return (
    <Card className="@container/card">
      <CardHeader>
        <CardDescription>{label}</CardDescription>
        <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">{value}</CardTitle>
        {badge && <CardAction>{badge}</CardAction>}
      </CardHeader>
      {hint && <CardFooter className="text-sm text-muted-foreground">{hint}</CardFooter>}
    </Card>
  )
}

export default function DashboardPage() {
  const { me } = useAuth()
  const [days, setDays] = React.useState("30")
  const { data, error } = useApi<Overview>(`/admin/overview?days=${days}`)
  const honamTotal = data ? Object.values(data.honam.orders_by_status).reduce((a, b) => a + b, 0) : 0
  return (
    <ConsoleShell title="Tableau de bord" permission="dashboard.view">
      {error && <p className="text-sm text-destructive">{error}</p>}
      <Card className="flex-row items-center justify-between gap-6 overflow-hidden bg-accent py-0">
        <div className="flex flex-col gap-1 py-6 pl-6">
          <p className="text-sm text-accent-foreground/80">{greeting()}{me?.full_name ? `, ${me.full_name.split(" ")[0]}` : ""}</p>
          <h2 className="text-xl font-semibold text-accent-foreground">
            {data && data.reports.open > 0
              ? `${data.reports.open} signalement${data.reports.open > 1 ? "s" : ""} attend${data.reports.open > 1 ? "ent" : ""} une décision`
              : "Tout est calme dans la communauté"}
          </h2>
          <p className="text-sm text-accent-foreground/80">
            {data ? `${nf.format(data.users.new_7d)} nouvelles personnes cette semaine.` : "\u00a0"}
          </p>
        </div>
        <Illustration name={data && data.reports.open > 0 ? "team_work" : "all_clear"} className="hidden h-36 shrink-0 pr-6 sm:block" />
      </Card>
      <div className="grid grid-cols-1 gap-4 @xl/main:grid-cols-2 @5xl/main:grid-cols-4">
        <Stat label="Utilisateurs" value={data ? nf.format(data.users.total) : "…"}
          badge={data && <Badge variant="outline">+{nf.format(data.users.new_7d)} en 7 j</Badge>}
          hint={data ? `${nf.format(data.users.active_7d)} actifs ces 7 derniers jours` : undefined} />
        <Stat label={`Messages (${days} j)`} value={data ? nf.format(data.messages.direct + data.messages.group) : "…"}
          hint={data ? `${nf.format(data.messages.direct)} directs · ${nf.format(data.messages.group)} en groupe · ${nf.format(data.groups)} groupes` : undefined} />
        <Stat label="Kory" value={data ? fcfa(data.kory.confirmed_amount) : "…"}
          hint={data ? `${nf.format(data.kory.open_pots)} cagnottes ouvertes` : undefined} />
        <Stat label="Signalements ouverts" value={data ? nf.format(data.reports.open) : "…"}
          badge={data && data.reports.open > 0 && <Badge variant="destructive">À traiter</Badge>}
          hint="File de modération" />
        <Stat label="Honam" value={data ? nf.format(honamTotal) : "…"}
          hint={data ? `commandes · ${nf.format(data.honam.pharmacies)} pharmacies` : undefined} />
        <Stat label="Assimé" value={data ? nf.format(data.assime.live_products) : "…"} hint="annonces en ligne" />
        <Stat label="Pokou certifié" value={data ? nf.format(data.certified.active) : "…"} hint="abonnements actifs" />
        <Stat label="Groupes" value={data ? nf.format(data.groups) : "…"} hint="groupes et communautés" />
      </div>
      <Card className="@container/card">
        <CardHeader>
          <CardTitle>Activité</CardTitle>
          <CardDescription>Messages envoyés et inscriptions, par jour</CardDescription>
          <CardAction>
            <ToggleGroup type="single" value={days} onValueChange={(v) => v && setDays(v)} variant="outline">
              <ToggleGroupItem value="90">3 mois</ToggleGroupItem>
              <ToggleGroupItem value="30">30 jours</ToggleGroupItem>
              <ToggleGroupItem value="7">7 jours</ToggleGroupItem>
            </ToggleGroup>
          </CardAction>
        </CardHeader>
        <CardContent className="px-2 pt-4 sm:px-6 sm:pt-6">
          <ChartContainer config={chartConfig} className="aspect-auto h-[280px] w-full">
            <AreaChart data={data?.activity ?? []}>
              <defs>
                {(["direct", "group", "signups"] as const).map((k) => (
                  <linearGradient key={k} id={`fill-${k}`} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={`var(--color-${k})`} stopOpacity={0.6} />
                    <stop offset="95%" stopColor={`var(--color-${k})`} stopOpacity={0.05} />
                  </linearGradient>
                ))}
              </defs>
              <CartesianGrid vertical={false} />
              <XAxis dataKey="date" tickLine={false} axisLine={false} tickMargin={8} minTickGap={32}
                tickFormatter={(v) => new Date(v).toLocaleDateString("fr-FR", { day: "numeric", month: "short" })} />
              <ChartTooltip cursor={false} content={
                <ChartTooltipContent indicator="dot"
                  labelFormatter={(v) => new Date(v).toLocaleDateString("fr-FR", { day: "numeric", month: "long" })} />
              } />
              <Area dataKey="group" type="monotone" fill="url(#fill-group)" stroke="var(--color-group)" stackId="m" />
              <Area dataKey="direct" type="monotone" fill="url(#fill-direct)" stroke="var(--color-direct)" stackId="m" />
              <Area dataKey="signups" type="monotone" fill="url(#fill-signups)" stroke="var(--color-signups)" />
              <ChartLegend content={<ChartLegendContent />} />
            </AreaChart>
          </ChartContainer>
        </CardContent>
      </Card>
    </ConsoleShell>
  )
}
