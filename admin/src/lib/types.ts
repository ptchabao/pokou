export type AdminUser = {
  id: number
  full_name: string | null
  phone: string | null
  email?: string | null
  role: string
  role_label: string
  is_active: boolean
  is_verified: boolean
  created_at: string | null
  last_seen_at: string | null
  console_access?: boolean
}
export type Paged<T> = { items: T[]; total: number; page?: number; size?: number }

/** Un rôle de la console (RBAC) : prédéfini ou créé par l'équipe. */
export type Role = { id: number | null; key: string; label: string; description: string | null; permissions: string[]; is_system: boolean; editable: boolean; deletable: boolean; members: number }
