export type AdminUser = {
  id: number
  full_name: string | null
  phone: string | null
  role: string
  role_label: string
  is_active: boolean
  is_verified: boolean
  created_at: string | null
  last_seen_at: string | null
}
export type Paged<T> = { items: T[]; total: number; page?: number; size?: number }
