"""Schémas de l'authentification : sessions, profil courant, erreurs."""
from datetime import datetime
from enum import Enum
from typing import Any, Dict, Optional

from pydantic import BaseModel, EmailStr, field_validator


class UserRoleSchema(str, Enum):
    USER = "user"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"
    AI_OPERATOR = "ai_operator"
    SUPPORT = "support"
    VIEWER = "viewer"


class TokenSchema(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserUpdate(BaseModel):
    full_name: Optional[str] = None


class UserResponse(BaseModel):
    id: int
    # Un compte Pokou naît d'un numéro de téléphone : l'email est facultatif.
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    full_name: Optional[str] = None
    role: UserRoleSchema
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

    @field_validator("role", mode="before")
    def _normalize_role(cls, v):
        try:
            return str(v.value).lower()
        except Exception:
            if isinstance(v, str):
                return v.lower()
            return v


class LoginResponse(TokenSchema):
    user: UserResponse


class ErrorResponse(BaseModel):
    error_code: str
    message: str
    trace_id: str
    details: Optional[Dict[str, Any]] = None
