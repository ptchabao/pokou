"""Rôles de la console, modifiables (RBAC).

Deux sortes de lignes :
- les rôles PRÉDÉFINIS (`is_system`, clé = valeur de UserRole : ADMIN,
  SUPPORT…) : leurs permissions se modifient, pas leur nom ;
- les rôles CRÉÉS par l'équipe : nom, description et permissions libres.

Le super-administrateur n'a pas de ligne : il a toujours tout (voir
app/core/permissions.py), pour que personne ne puisse fermer la console.
"""
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text
from sqlalchemy.types import JSON

from app.core.database import Base


class AdminRole(Base):
    __tablename__ = "admin_roles"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(60), unique=True, nullable=False, index=True)
    label = Column(String(80), nullable=False)
    description = Column(Text, nullable=True)
    permissions = Column(JSON, nullable=False, default=list)
    is_system = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    def permission_set(self) -> set:
        return set(self.permissions or [])
