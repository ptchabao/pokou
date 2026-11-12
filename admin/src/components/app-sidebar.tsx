"use client"

import * as React from "react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import {
  IconBuildingStore,
  IconCertificate,
  IconDashboard,
  IconFirstAidKit,
  IconFlag,
  IconHistory,
  IconKey,
  IconLogout,
  IconPigMoney,
  IconPuzzle,
  IconSpeakerphone,
  IconShieldLock,
  IconUsers,
} from "@tabler/icons-react"

import { useAuth } from "@/lib/auth"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { PasswordDialog } from "@/components/password-dialog"

/** La navigation, filtrée par les permissions du rôle (RBAC). */
export const NAV = [
  { group: "Pilotage", items: [
    { title: "Tableau de bord", url: "/dashboard/", icon: IconDashboard, perm: "dashboard.view" },
  ] },
  { group: "Communauté", items: [
    { title: "Utilisateurs", url: "/users/", icon: IconUsers, perm: "users.view" },
    { title: "Signalements", url: "/reports/", icon: IconFlag, perm: "reports.view" },
  ] },
  { group: "Services", items: [
    { title: "Kory", url: "/kory/", icon: IconPigMoney, perm: "kory.view" },
    { title: "Honam", url: "/honam/", icon: IconFirstAidKit, perm: "honam.view" },
    { title: "Assimé", url: "/assime/", icon: IconBuildingStore, perm: "assime.view" },
    { title: "Pokou certifié", url: "/certified/", icon: IconCertificate, perm: "certified.view" },
    { title: "Modules", url: "/modules/", icon: IconPuzzle, perm: "modules.manage" },
    { title: "Bannières", url: "/banners/", icon: IconSpeakerphone, perm: "banners.view" },
  ] },
  { group: "Administration", items: [
    { title: "Équipe et rôles", url: "/team/", icon: IconShieldLock, perm: "team.view" },
    { title: "Journal d'audit", url: "/audit/", icon: IconHistory, perm: "audit.view" },
  ] },
]

export function AppSidebar(props: React.ComponentProps<typeof Sidebar>) {
  const { me, can, logout } = useAuth()
  const pathname = usePathname()
  const [passwordOpen, setPasswordOpen] = React.useState(false)
  const initials = (me?.full_name ?? "P")
    .split(" ")
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("")
  return (
    <Sidebar collapsible="offcanvas" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton asChild className="data-[slot=sidebar-menu-button]:!p-1.5">
              <Link href="/dashboard/">
                <span className="flex size-6 items-center justify-center rounded-md bg-primary text-xs font-bold text-primary-foreground">
                  P
                </span>
                <span className="text-base font-semibold">Pokou · Console</span>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        {NAV.map((section) => {
          const items = section.items.filter((i) => can(i.perm))
          if (items.length === 0) return null
          return (
            <SidebarGroup key={section.group}>
              <SidebarGroupLabel>{section.group}</SidebarGroupLabel>
              <SidebarGroupContent>
                <SidebarMenu>
                  {items.map((item) => (
                    <SidebarMenuItem key={item.url}>
                      <SidebarMenuButton
                        asChild
                        tooltip={item.title}
                        isActive={pathname?.startsWith(item.url.replace(/\/$/, ""))}
                      >
                        <Link href={item.url}>
                          <item.icon />
                          <span>{item.title}</span>
                        </Link>
                      </SidebarMenuButton>
                    </SidebarMenuItem>
                  ))}
                </SidebarMenu>
              </SidebarGroupContent>
            </SidebarGroup>
          )
        })}
      </SidebarContent>
      <SidebarFooter>
        <SidebarMenu>
          <SidebarMenuItem>
            <div className="flex items-center gap-2 rounded-md p-2">
              <Avatar className="size-8 rounded-lg">
                <AvatarFallback className="rounded-lg">{initials}</AvatarFallback>
              </Avatar>
              <div className="grid flex-1 text-left text-sm leading-tight">
                <span className="truncate font-medium">{me?.full_name ?? me?.phone ?? me?.email}</span>
                <span className="truncate text-xs text-muted-foreground">{me?.role_label}</span>
              </div>
              <button
                onClick={() => setPasswordOpen(true)}
                title="Mot de passe de la console"
                className="rounded-md p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground"
              >
                <IconKey className="size-4" />
              </button>
              <button
                onClick={logout}
                title="Se déconnecter"
                className="rounded-md p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground"
              >
                <IconLogout className="size-4" />
              </button>
            </div>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
      <PasswordDialog open={passwordOpen} onOpenChange={setPasswordOpen} />
    </Sidebar>
  )
}
