"""Carnet de contacts."""
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class Contact(Base):
    """Pokou — carnet d'adresses personnel d'un utilisateur, façon WhatsApp :
    ajouté par numéro de téléphone, sans accord mutuel requis pour
    l'ajout (mais la messagerie ne fonctionne évidemment que si l'autre
    numéro est aussi un utilisateur Pokou — voir contact_user_id)."""
    __tablename__ = "contacts"

    id = Column(Integer, primary_key=True, index=True)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    # Indexé : rattaché à chaque connexion par contact_linking.py, sur le
    # chemin critique de la validation du code.
    phone = Column(String(32), nullable=False, index=True)
    display_name = Column(String(255), nullable=False)
    # NULL tant que ce numéro n'est pas (encore) un utilisateur Pokou.
    contact_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    # Mode Bouclier — BUSINESS/FOURNISSEUR/CLIENT/BOSS/AMI, NULL par défaut.
    # Les quatre premiers sont "prioritaires" (voir app/services/shield_service.py).
    priority_tag = Column(String(12), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # ── Gestion de la conversation avec ce contact ────────────────────────────
    # Bloqué : ses messages et appels sont refusés à l'entrée.
    is_blocked = Column(Boolean, default=False, nullable=False)
    # Archivée : sortie de la liste principale, sans rien perdre.
    is_archived = Column(Boolean, default=False, nullable=False)
    # Épinglée en tête de liste ; `pinned_at` sert à ordonner plusieurs
    # épingles entre elles.
    is_pinned = Column(Boolean, default=False, nullable=False)
    pinned_at = Column(DateTime, nullable=True)
    # Silencieuse jusqu'à cette date. Une DATE et non un booléen : « 8 heures »
    # et « toujours » se disent alors de la même façon (une date lointaine),
    # et le silence expire tout seul sans tâche de fond.
    muted_until = Column(DateTime, nullable=True)
    # Messages éphémères : durée de vie en secondes des nouveaux messages de
    # cette conversation. Nul = pas d'expiration.
    disappearing_seconds = Column(Integer, nullable=True)

    owner = relationship("User", foreign_keys=[owner_user_id])
    contact_user = relationship("User", foreign_keys=[contact_user_id])

    __table_args__ = (UniqueConstraint("owner_user_id", "phone", name="uq_contact_owner_phone"),)
