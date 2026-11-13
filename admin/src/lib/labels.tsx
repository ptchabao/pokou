import { Badge } from "@/components/ui/badge"

export const ROLE_OPTIONS = [
  { value: "SUPER_ADMIN", label: "Super administrateur" },
  { value: "ADMIN", label: "Administrateur" },
  { value: "SUPPORT", label: "Support" },
  { value: "AI_OPERATOR", label: "Opérateur IA" },
  { value: "VIEWER", label: "Lecture seule" },
  { value: "USER", label: "Utilisateur (retirer de l'équipe)" },
]

export const PERMISSION_LABELS: Record<string, string> = {
  "dashboard.view": "Voir le tableau de bord",
  "users.view": "Voir les utilisateurs",
  "users.manage": "Gérer les comptes (suspendre, déconnecter, supprimer…)",
  "team.view": "Voir l'équipe",
  "team.manage": "Gérer l'équipe et les rôles",
  "reports.view": "Voir les signalements",
  "reports.manage": "Traiter les signalements",
  "kory.view": "Voir Kory",
  "kory.manage": "Clôturer / dissoudre une collecte Kory",
  "honam.view": "Voir Honam",
  "honam.manage": "Gérer Honam",
  "assime.view": "Voir Assimé",
  "assime.manage": "Gérer Assimé",
  "certified.view": "Voir Pokou certifié",
  "certified.manage": "Examiner les dossiers",
  "modules.manage": "Ouvrir / fermer les modules",
  "banners.view": "Voir les bannières de l'accueil",
  "banners.manage": "Gérer les bannières de l'accueil",
  "audit.view": "Voir le journal d'audit",
  "countries.view": "Voir la configuration des pays",
  "countries.manage": "Modifier la configuration des pays",
  "settings.manage": "Gérer les réglages système",
}

const TONES: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  OPEN: "destructive", FROZEN: "destructive", PENDING: "default", ACTIVE: "default", APPROVED: "secondary",
  ACTIONED: "secondary", DISMISSED: "outline", REJECTED: "outline", CLOSED: "outline",
  SUSPENDED: "destructive", EXCLUDED: "destructive", NAME_MISMATCH: "destructive", CORRECTION: "default",
  PAID: "default", TRIAL: "secondary", MEMBER: "secondary", CONFIRMED: "secondary", DECLARED: "default",
  CURRENT: "default", FAILED: "destructive",
}

const STATUS_LABELS: Record<string, string> = {
  OPEN: "Ouvert", FROZEN: "Suspendue", PENDING: "En attente", ACTIVE: "Actif", APPROVED: "Approuvé",
  ACTIONED: "Sanctionné", DISMISSED: "Classé", REJECTED: "Refusé", CLOSED: "Clôturé",
  COMPLETED: "Terminé", CANCELLED: "Annulé", DELIVERED: "Livré", PAUSED: "En pause",
  SUSPENDED: "Suspendu", EXCLUDED: "Exclu", SUBMITTED: "Ordonnance envoyée", QUOTED: "Devis envoyé",
  ACCEPTED: "Devis accepté", PAID: "Payé", READY: "Prête", IN_DELIVERY: "En livraison", EXPIRED: "Expiré",
  TRIAL: "Essai", MEMBER: "Membre", ENDED: "Essai fini", CORRECTION: "À corriger",
  NAME_MISMATCH: "Noms différents", DECLARED: "Déclarée", CONFIRMED: "Confirmé", UPCOMING: "À venir",
  CURRENT: "En cours", DONE: "Terminé", FAILED: "Échoué",
}

export function StatusBadge({ status }: { status?: string | null }) {
  if (!status) return <span className="text-muted-foreground">—</span>
  return <Badge variant={TONES[status] ?? "outline"}>{STATUS_LABELS[status] ?? status}</Badge>
}

export function ActiveBadge({ active }: { active: boolean }) {
  return active ? <Badge variant="secondary">Actif</Badge> : <Badge variant="destructive">Suspendu</Badge>
}
