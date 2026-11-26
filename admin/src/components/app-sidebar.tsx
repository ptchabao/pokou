"use client"

import * as React from "react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import {
  IconBuildingStore,
  IconCertificate,
  IconChevronRight,
  IconDashboard,
  IconDotsVertical,
  IconFirstAidKit,
  IconFlag,
  IconHistory,
  IconKey,
  IconLifebuoy,
  IconLogout,
  IconPigMoney,
  IconPuzzle,
  IconSettings,
  IconShieldLock,
  IconSpeakerphone,
  IconUserCircle,
  IconUsers,
  IconWorld,
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
  SidebarMenuSub,
  SidebarMenuSubButton,
  SidebarMenuSubItem,
  SidebarRail,
  useSidebar,
} from "@/components/ui/sidebar"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { PasswordDialog } from "@/components/password-dialog"

type SubItem = { title: string; url: string; perm?: string }
type NavItem = { title: string; url: string; icon: React.ComponentType<{ className?: string }>; perm: string; items?: SubItem[] }

/** La navigation, filtrée par les permissions du rôle (RBAC). Chaque module
 *  a ses pages : les sous-menus remplacent les onglets. */
export const NAV: { group: string; items: NavItem[] }[] = [
  { group: "Pilotage", items: [
    { title: "Tableau de bord", url: "/dashboard/", icon: IconDashboard, perm: "dashboard.view" },
  ] },
  { group: "Communauté", items: [
    { title: "Utilisateurs", url: "/users/", icon: IconUsers, perm: "users.view" },
    { title: "Signalements", url: "/reports/", icon: IconFlag, perm: "reports.view", items: [
      { title: "À traiter", url: "/reports/" },
      { title: "Sanctionnés", url: "/reports/sanctionnes/" },
      { title: "Classés", url: "/reports/classes/" },
      { title: "Tous", url: "/reports/tous/" },
    ] },
    { title: "Support", url: "/support/", icon: IconLifebuoy, perm: "reports.view", items: [
      { title: "À traiter", url: "/support/" },
      { title: "Répondues", url: "/support/repondues/" },
      { title: "Closes", url: "/support/closes/" },
      { title: "Toutes", url: "/support/toutes/" },
    ] },
  ] },
  { group: "Services", items: [
    { title: "Kory", url: "/kory/", icon: IconPigMoney, perm: "kory.view" },
    { title: "Honam", url: "/honam/", icon: IconFirstAidKit, perm: "honam.view", items: [
      { title: "Commandes", url: "/honam/" },
      { title: "Officines", url: "/honam/officines/" },
      { title: "Coursiers", url: "/honam/coursiers/" },
      { title: "Liste d'attente", url: "/honam/liste-attente/", perm: "honam.manage" },
    ] },
    { title: "Assimé", url: "/assime/", icon: IconBuildingStore, perm: "assime.view", items: [
      { title: "Annonces", url: "/assime/" },
      { title: "Vendeurs", url: "/assime/vendeurs/" },
      { title: "Vérifications", url: "/assime/verifications/" },
      { title: "Mises en avant", url: "/assime/mises-en-avant/" },
      { title: "Publicités", url: "/assime/publicites/" },
      { title: "Avis", url: "/assime/avis/" },
    ] },
    { title: "Pokou certifié", url: "/certified/", icon: IconCertificate, perm: "certified.view", items: [
      { title: "Dossiers Pro", url: "/certified/" },
      { title: "Abonnements", url: "/certified/abonnements/" },
    ] },
    { title: "Modules", url: "/modules/", icon: IconPuzzle, perm: "modules.manage" },
    { title: "Bannières", url: "/banners/", icon: IconSpeakerphone, perm: "banners.view" },
  ] },
  { group: "Administration", items: [
    { title: "Équipe", url: "/team/", icon: IconShieldLock, perm: "team.view", items: [
      { title: "Membres", url: "/team/" },
      { title: "Rôles et permissions", url: "/team/roles/" },
    ] },
    { title: "Pays", url: "/countries/", icon: IconWorld, perm: "countries.view" },
    { title: "Réglages système", url: "/settings/", icon: IconSettings, perm: "settings.manage" },
    { title: "Journal d'audit", url: "/audit/", icon: IconHistory, perm: "audit.view" },
  ] },
]

const norm = (p?: string | null) => (p ?? "/").replace(/\/?$/, "/")

export function AppSidebar(props: React.ComponentProps<typeof Sidebar>) {
  const { can } = useAuth()
  const pathname = norm(usePathname())
  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <Link href="/dashboard/">
                <div className="flex aspect-square size-8 items-center justify-center rounded-lg bg-primary text-sm font-bold text-primary-foreground">
                  P
                </div>
                <div className="grid flex-1 text-left text-sm leading-tight">
                  <span className="truncate font-semibold">Pokou</span>
                  <span className="truncate text-xs text-muted-foreground">Console d&apos;administration</span>
                </div>
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
                  {items.map((item) => {
                    const inModule = pathname.startsWith(item.url)
                    const subs = item.items?.filter((s) => !s.perm || can(s.perm))
                    if (!subs || subs.length === 0) {
                      return (
                        <SidebarMenuItem key={item.url}>
                          <SidebarMenuButton asChild tooltip={item.title} isActive={inModule}>
                            <Link href={item.url}>
                              <item.icon />
                              <span>{item.title}</span>
                            </Link>
                          </SidebarMenuButton>
                        </SidebarMenuItem>
                      )
                    }
                    return (
                      <Collapsible key={item.url} asChild defaultOpen={inModule} className="group/collapsible">
                        <SidebarMenuItem>
                          <CollapsibleTrigger asChild>
                            <SidebarMenuButton tooltip={item.title}>
                              <item.icon />
                              <span>{item.title}</span>
                              <IconChevronRight className="ml-auto transition-transform duration-200 group-data-[state=open]/collapsible:rotate-90" />
                            </SidebarMenuButton>
                          </CollapsibleTrigger>
                          <CollapsibleContent>
                            <SidebarMenuSub>
                              {subs.map((sub) => (
                                <SidebarMenuSubItem key={sub.url}>
                                  <SidebarMenuSubButton asChild isActive={pathname === norm(sub.url)}>
                                    <Link href={sub.url}>
                                      <span>{sub.title}</span>
                                    </Link>
                                  </SidebarMenuSubButton>
                                </SidebarMenuSubItem>
                              ))}
                            </SidebarMenuSub>
                          </CollapsibleContent>
                        </SidebarMenuItem>
                      </Collapsible>
                    )
                  })}
                </SidebarMenu>
              </SidebarGroupContent>
            </SidebarGroup>
          )
        })}
      </SidebarContent>
      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}

/** Le compte connecté (bloc « nav-user » de shadcn) : profil, mot de passe,
 *  déconnexion. */
function NavUser() {
  const { me, logout } = useAuth()
  const { isMobile } = useSidebar()
  const [passwordOpen, setPasswordOpen] = React.useState(false)
  const initials = (me?.full_name ?? "P")
    .split(" ")
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("")
  const name = me?.full_name ?? me?.email ?? me?.phone ?? ""
  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <SidebarMenuButton size="lg" className="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground">
              <Avatar className="size-8 rounded-lg">
                <AvatarFallback className="rounded-lg">{initials}</AvatarFallback>
              </Avatar>
              <div className="grid flex-1 text-left text-sm leading-tight">
                <span className="truncate font-medium">{name}</span>
                <span className="truncate text-xs text-muted-foreground">{me?.role_label}</span>
              </div>
              <IconDotsVertical className="ml-auto size-4" />
            </SidebarMenuButton>
          </DropdownMenuTrigger>
          <DropdownMenuContent className="min-w-56 rounded-lg" side={isMobile ? "bottom" : "right"} align="end" sideOffset={4}>
            <DropdownMenuLabel className="p-0 font-normal">
              <div className="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
                <Avatar className="size-8 rounded-lg">
                  <AvatarFallback className="rounded-lg">{initials}</AvatarFallback>
                </Avatar>
                <div className="grid flex-1 text-left text-sm leading-tight">
                  <span className="truncate font-medium">{name}</span>
                  <span className="truncate text-xs text-muted-foreground">{me?.email}</span>
                </div>
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuGroup>
              <DropdownMenuItem asChild>
                <Link href="/account/"><IconUserCircle />Mon profil</Link>
              </DropdownMenuItem>
              <DropdownMenuItem onSelect={() => setPasswordOpen(true)}>
                <IconKey />Changer mon mot de passe
              </DropdownMenuItem>
            </DropdownMenuGroup>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={logout}>
              <IconLogout />Se déconnecter
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <PasswordDialog open={passwordOpen} onOpenChange={setPasswordOpen} />
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
