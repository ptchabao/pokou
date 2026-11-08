"use client"

import * as React from "react"
import { useRouter } from "next/navigation"

import { AppSidebar } from "@/components/app-sidebar"
import { SiteHeader } from "@/components/site-header"
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { useAuth } from "@/lib/auth"

/** Coquille de toutes les pages : garde d'accès, barre latérale, en-tête. */
export function ConsoleShell({
  title,
  permission,
  actions,
  children,
}: {
  title: string
  permission: string
  actions?: React.ReactNode
  children: React.ReactNode
}) {
  const { me, loading, can } = useAuth()
  const router = useRouter()
  React.useEffect(() => {
    if (!loading && !me) router.replace("/login/")
  }, [loading, me, router])
  if (loading || !me) {
    return <div className="p-10 text-sm text-muted-foreground">Chargement…</div>
  }
  return (
    <SidebarProvider
      style={
        {
          "--sidebar-width": "calc(var(--spacing) * 64)",
          "--header-height": "calc(var(--spacing) * 12)",
        } as React.CSSProperties
      }
    >
      <AppSidebar variant="inset" />
      <SidebarInset>
        <SiteHeader title={title} actions={actions} />
        <div className="@container/main flex flex-1 flex-col gap-4 p-4 lg:p-6">
          {can(permission) ? (
            children
          ) : (
            <Alert variant="destructive">
              <AlertTitle>Accès refusé</AlertTitle>
              <AlertDescription>
                Ton rôle ({me.role_label}) ne donne pas accès à cette page.
              </AlertDescription>
            </Alert>
          )}
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
