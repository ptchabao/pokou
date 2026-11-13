"""Console d'administration : configuration des pays, réglages système,
actions de gestion des comptes et de l'équipe.

Chaque route exige une permission (app/core/permissions.py) ; chaque
modification écrit une ligne d'audit. Les réglages SECRETS (clés, mots de
passe) ne sont jamais renvoyés : on sait seulement s'ils sont renseignés, et
on peut les remplacer.
"""
import json
import re
from datetime import datetime
from typing import Annotated, Any, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Path, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.v1.admin.admin import _audit, _revoke_sessions, _user_json
from app.core.countries import _DEFAULTS, _FALLBACK, MODULES, country_config
from app.core.database import get_db
from app.core.permissions import permissions_of, require_permission
from app.models import DeviceToken, SystemSetting, Token, User, UserRole
from app.services.settings_service import get_setting, set_setting

router = APIRouter(prefix="/admin", tags=["Administration"])

# ── Pays ─────────────────────────────────────────────────────────────────

CountryCode = Annotated[str, Path(pattern=r"^[A-Za-z]{2}$")]
_PREFIX = "country."
_ALWAYS_OPEN = {"kory", "honam"}

Price = Optional[Annotated[int, Field(strict=True, ge=0, le=10_000_000)]]
EmergencyNumber = Optional[Annotated[str, Field(pattern=r"^[0-9]{2,10}$")]]


class EmergencyNumbers(BaseModel):
    model_config = ConfigDict(extra="forbid")
    police: EmergencyNumber = None
    pompiers: EmergencyNumber = None
    samu: EmergencyNumber = None


class CountryBody(BaseModel):
    """La fiche complète d'un pays. Tous les champs sont requis : la fiche
    enregistrée remplace la surcharge précédente en entier."""
    model_config = ConfigDict(extra="forbid")

    currency: Annotated[str, Field(pattern=r"^[A-Z]{3}$")]
    vat_rate: Annotated[float, Field(strict=True, ge=0, le=0.5)]
    delivery_price: Optional[Annotated[int, Field(strict=True, ge=0, le=100_000)]]
    pharmacy_monthly_price: Price
    pharmacy_yearly_price: Price
    kory_plus_fee_ht: Annotated[int, Field(strict=True, ge=0, le=100_000)]
    honam_cities: Annotated[list[Annotated[str, Field(min_length=2, max_length=60)]], Field(max_length=50)]
    emergency_numbers: EmergencyNumbers
    modules: Annotated[list[Literal[MODULES]], Field(max_length=len(MODULES))]  # type: ignore[valid-type]

    @field_validator("honam_cities")
    @classmethod
    def _cities(cls, value: list[str]) -> list[str]:
        seen, out = set(), []
        for city in value:
            city = " ".join(city.split())
            if len(city) < 2:
                raise ValueError("Nom de ville trop court")
            if city.lower() not in seen:
                seen.add(city.lower())
                out.append(city)
        return out


def _stored_codes(db: Session) -> dict[str, SystemSetting]:
    rows = db.query(SystemSetting).filter(SystemSetting.key.like(f"{_PREFIX}%")).all()
    return {r.key[len(_PREFIX):].upper(): r for r in rows if re.fullmatch(r"[A-Za-z]{2}", r.key[len(_PREFIX):])}


def _effective(db: Session, code: str) -> dict[str, Any]:
    config = country_config(db, code)
    config.pop("country", None)
    return config


def _country_json(db: Session, code: str, row: Optional[SystemSetting]) -> dict[str, Any]:
    defaults = dict(_DEFAULTS.get(code, _FALLBACK))
    return {
        "code": code,
        "builtin": code in _DEFAULTS,
        "has_override": row is not None,
        "updated_at": row.updated_at.isoformat() if row is not None and row.updated_at else None,
        "config": _effective(db, code),
        "defaults": defaults,
        "always_open": sorted(_ALWAYS_OPEN),
        "modules_known": list(MODULES),
    }


@router.get("/countries")
def list_countries(
    user: User = Depends(require_permission("countries.view")),
    db: Session = Depends(get_db),
):
    stored = _stored_codes(db)
    codes = sorted(set(_DEFAULTS) | set(stored))
    items = []
    for code in codes:
        config = _effective(db, code)
        row = stored.get(code)
        items.append({
            "code": code,
            "builtin": code in _DEFAULTS,
            "has_override": row is not None,
            "updated_at": row.updated_at.isoformat() if row is not None and row.updated_at else None,
            "currency": config.get("currency"),
            "vat_rate": config.get("vat_rate"),
            "modules": config.get("modules", []),
        })
    return {"items": items, "modules": list(MODULES)}


@router.get("/countries/{code}")
def get_country(
    code: CountryCode,
    user: User = Depends(require_permission("countries.view")),
    db: Session = Depends(get_db),
):
    code = code.upper()
    row = db.query(SystemSetting).filter(SystemSetting.key == f"{_PREFIX}{code}").first()
    return _country_json(db, code, row)


@router.put("/countries/{code}")
def put_country(
    code: CountryCode, body: CountryBody, request: Request,
    user: User = Depends(require_permission("countries.manage")),
    db: Session = Depends(get_db),
):
    code = code.upper()
    before = _effective(db, code)
    data = body.model_dump()
    data["emergency_numbers"] = {k: v for k, v in data["emergency_numbers"].items() if v}
    enabled = set(data["modules"]) | _ALWAYS_OPEN
    data["modules"] = [m for m in MODULES if m in enabled]
    if data["pharmacy_monthly_price"] is not None and data["pharmacy_yearly_price"] is not None \
            and data["pharmacy_yearly_price"] < data["pharmacy_monthly_price"]:
        raise HTTPException(status_code=422, detail="L'abonnement annuel ne peut pas coûter moins que le mensuel")
    changes = {k: {"from": before.get(k), "to": v} for k, v in data.items() if before.get(k) != v}
    _audit(db, user, "country_update", "country", None, {"country": code, "changes": changes}, request)
    set_setting(db, f"{_PREFIX}{code}", json.dumps(data, ensure_ascii=False), updated_by_admin_id=user.id)
    row = db.query(SystemSetting).filter(SystemSetting.key == f"{_PREFIX}{code}").first()
    return _country_json(db, code, row)


@router.delete("/countries/{code}")
def reset_country(
    code: CountryCode, request: Request,
    user: User = Depends(require_permission("countries.manage")),
    db: Session = Depends(get_db),
):
    """Revenir aux valeurs par défaut. Pour un pays sans défaut écrit dans le
    code, il retombe sur la configuration générique et sort de la liste."""
    code = code.upper()
    row = db.query(SystemSetting).filter(SystemSetting.key == f"{_PREFIX}{code}").first()
    if row is None:
        raise HTTPException(status_code=404, detail="Ce pays n'a pas de réglage propre")
    before = _effective(db, code)
    db.delete(row)
    _audit(db, user, "country_reset", "country", None, {"country": code, "previous": before}, request)
    db.commit()
    return _country_json(db, code, None)


# ── Réglages système ─────────────────────────────────────────────────────
#
# Seulement les réglages que le code LIT réellement via get_setting. Les
# réglages pays (country.*) ont leur page ; ceux du marché Assimé (listes de
# catégories, devises, formules) ont leur propre route d'administration.

_SETTINGS: list[dict[str, Any]] = [
    {"key": "ngh_api_key", "group": "SMS (NGH)", "label": "Clé d'API NGH", "secret": True,
     "pattern": r"^\S{4,255}$",
     "help": "Clé de la passerelle SMS NGH (codes de connexion envoyés par SMS). "
             "À défaut, la variable d'environnement NGH_API_KEY est utilisée."},
    {"key": "ngh_api_secret", "group": "SMS (NGH)", "label": "Secret d'API NGH", "secret": True,
     "pattern": r"^\S{4,255}$",
     "help": "Secret associé à la clé NGH. À défaut, la variable d'environnement NGH_API_SECRET est utilisée."},
    {"key": "semoa_login", "group": "Paiements (Semoa)", "label": "Identifiant Semoa", "secret": False,
     "pattern": r"^\S{1,255}$",
     "help": "Identifiant « Cashpay Auth » qui signe nos appels vers Semoa (paiements Mobile Money)."},
    {"key": "semoa_api_key", "group": "Paiements (Semoa)", "label": "Clé d'API Semoa", "secret": True,
     "pattern": r"^\S{4,255}$",
     "help": "Clé « Cashpay Auth » qui signe chaque appel sortant vers Semoa."},
    {"key": "semoa_api_reference", "group": "Paiements (Semoa)", "label": "Référence d'API Semoa", "secret": False,
     "pattern": r"^\S{1,255}$",
     "help": "Référence de l'intégration Semoa, envoyée avec chaque commande."},
    {"key": "semoa_gateway_id", "group": "Paiements (Semoa)", "label": "Passerelle Mobile Money", "secret": False,
     "pattern": r"^[0-9]{1,9}$",
     "help": "Numéro de la passerelle Semoa utilisée pour créer une commande (liste : GET /gateways chez Semoa)."},
    {"key": "semoa_webhook_secret", "group": "Paiements (Semoa)", "label": "Secret des notifications Semoa",
     "secret": True, "pattern": r"^[A-Za-z0-9_\-]{16,255}$",
     "help": "Secret ajouté à l'URL de rappel de chaque paiement et vérifié à chaque notification entrante. "
             "Sans lui, aucune URL de rappel n'est envoyée à Semoa. Lettres, chiffres, - et _, 16 caractères au moins."},
    {"key": "twilio_verify_service_sid", "group": "Codes de connexion (Twilio Verify)",
     "label": "Service Twilio Verify", "secret": False, "pattern": r"^VA[0-9a-fA-F]{32}$",
     "help": "Identifiant du service Verify (VA…) qui envoie les codes. Retrouvé ou créé automatiquement "
             "s'il est vide ; la variable d'environnement TWILIO_VERIFY_SERVICE_SID passe avant ce réglage."},
]
_BY_KEY = {s["key"]: s for s in _SETTINGS}

_PRICING_LABELS = {
    "service_price": ("Réponse dans les 24 h", "Prix d'un message du bot qui répond à quelqu'un lui ayant écrit dans les 24 heures (FCFA)."),
    "initiated_price": ("Message à l'initiative du bot", "Prix d'un message envoyé en premier par le bot, hors fenêtre de 24 heures (FCFA)."),
    "tax_rate_bp": ("Taxe (points de base)", "1 800 = 18 %. Au plus 5 000 (50 %)."),
    "min_recharge": ("Recharge minimale", "Montant minimal d'une recharge du solde Business (FCFA)."),
    "max_recharge": ("Recharge maximale", "Montant maximal d'une recharge du solde Business (FCFA)."),
}


def _env_overrides(key: str) -> bool:
    from app.core.config import get_settings
    s = get_settings()
    if key == "twilio_verify_service_sid":
        return bool((getattr(s, "twilio_verify_service_sid", "") or "").strip())
    return False


def _env_fallback(key: str) -> bool:
    from app.core.config import get_settings
    if key in ("ngh_api_key", "ngh_api_secret"):
        return bool(getattr(get_settings(), key, "") or "")
    return False


def _setting_json(db: Session, spec: dict[str, Any], names: dict[int, str]) -> dict[str, Any]:
    row = db.query(SystemSetting).filter(SystemSetting.key == spec["key"]).first()
    value = row.value if row is not None else None
    return {
        "key": spec["key"], "group": spec["group"], "label": spec["label"], "help": spec["help"],
        "secret": spec["secret"],
        "configured": bool(value),
        # Un secret n'est JAMAIS renvoyé, même masqué.
        "value": None if spec["secret"] else value,
        "env_fallback": _env_fallback(spec["key"]),
        "env_overrides": _env_overrides(spec["key"]),
        "updated_at": row.updated_at.isoformat() if row is not None and row.updated_at else None,
        "updated_by": names.get(row.updated_by_admin_id) if row is not None and row.updated_by_admin_id else None,
    }


def _names(db: Session) -> dict[int, str]:
    ids = {r.updated_by_admin_id for r in db.query(SystemSetting).filter(
        SystemSetting.key.in_(list(_BY_KEY))).all() if r.updated_by_admin_id}
    if not ids:
        return {}
    return {u.id: (u.full_name or u.email or u.phone or str(u.id))
            for u in db.query(User).filter(User.id.in_(ids)).all()}


@router.get("/settings")
def list_settings(
    user: User = Depends(require_permission("settings.manage")),
    db: Session = Depends(get_db),
):
    from app.services.business import pricing
    names = _names(db)
    return {
        "items": [_setting_json(db, spec, names) for spec in _SETTINGS],
        "business_pricing": {
            "values": pricing.tarifs(db),
            "defaults": dict(pricing.TARIFS_PAR_DEFAUT),
            "labels": {k: {"label": a, "help": b} for k, (a, b) in _PRICING_LABELS.items()},
        },
    }


class SettingValue(BaseModel):
    model_config = ConfigDict(extra="forbid")
    value: Annotated[str, Field(min_length=1, max_length=255)]


class PricingBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    service_price: Annotated[int, Field(strict=True, ge=0, le=100_000)]
    initiated_price: Annotated[int, Field(strict=True, ge=0, le=100_000)]
    tax_rate_bp: Annotated[int, Field(strict=True, ge=0, le=5000)]
    min_recharge: Annotated[int, Field(strict=True, ge=0, le=100_000_000)]
    max_recharge: Annotated[int, Field(strict=True, ge=0, le=100_000_000)]


@router.put("/settings/business/pricing")
def put_business_pricing(
    body: PricingBody, request: Request,
    user: User = Depends(require_permission("settings.manage")),
    db: Session = Depends(get_db),
):
    from app.services.business import pricing
    before = pricing.tarifs(db)
    data = body.model_dump()
    if data["min_recharge"] > data["max_recharge"]:
        raise HTTPException(status_code=422, detail="La recharge minimale dépasse la maximale")
    changes = {k: {"from": before.get(k), "to": v} for k, v in data.items() if before.get(k) != v}
    _audit(db, user, "setting_update", "system_setting", None,
           {"key": pricing.CLE_TARIFS, "changes": changes}, request)
    try:
        values = pricing.enregistrer(db, data, user.id)
    except pricing.TarifsInvalides as exc:
        db.rollback()
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    db.commit()
    return values


@router.put("/settings/{key}")
def put_setting(
    key: str, body: SettingValue, request: Request,
    user: User = Depends(require_permission("settings.manage")),
    db: Session = Depends(get_db),
):
    spec = _BY_KEY.get(key)
    if spec is None:
        raise HTTPException(status_code=404, detail="Réglage inconnu")
    value = body.value.strip()
    if not re.fullmatch(spec["pattern"], value):
        raise HTTPException(status_code=422, detail=f"Valeur invalide pour « {spec['label']} »")
    previous = get_setting(db, key)
    if spec["secret"]:
        changes = {"key": key, "replaced": bool(previous)}
    else:
        changes = {"key": key, "from": previous, "to": value}
    _audit(db, user, "setting_update", "system_setting", None, changes, request)
    set_setting(db, key, value, updated_by_admin_id=user.id)
    if key == "twilio_verify_service_sid":
        # Le service retrouvé est gardé en mémoire : on l'oublie pour que la
        # nouvelle valeur serve dès le prochain code (sur cette instance).
        from app.services.auth import twilio_verify
        twilio_verify._cached_sid = None
    return _setting_json(db, spec, _names(db))


# ── Comptes utilisateurs ─────────────────────────────────────────────────

def _managed_target(db: Session, actor: User, user_id: int) -> User:
    """Le compte visé par une action de gestion. Même règle que la
    suspension : un membre de l'équipe ne se gère que par qui gère l'équipe,
    et on n'agit pas sur soi-même depuis cette fiche."""
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    if target.id == actor.id:
        raise HTTPException(status_code=409, detail="Action impossible sur ton propre compte")
    if (target.role or UserRole.USER) != UserRole.USER and "team.manage" not in permissions_of(actor):
        raise HTTPException(status_code=403, detail="Seul un super-administrateur agit sur un membre de l'équipe")
    return target


async def _announce(db: Session, user_id: int) -> None:
    from app.api.v1.account.profile import _announce_profile_change
    try:
        await _announce_profile_change(db, user_id)
        from app.api.v1.messaging.ws import manager
        await manager.send_to_user(user_id, {"type": "user:profile_updated", "user_id": user_id})
    except Exception:  # pragma: no cover - temps réel best-effort
        pass


@router.post("/users/{user_id}/logout-all")
def logout_all(
    user_id: int, request: Request,
    user: User = Depends(require_permission("users.manage")),
    db: Session = Depends(get_db),
):
    target = _managed_target(db, user, user_id)
    revoked = db.query(func.count(Token.id)).filter(
        Token.user_id == target.id, Token.revoked_at.is_(None)).scalar() or 0
    _revoke_sessions(db, target.id)
    _audit(db, user, "user_sessions_revoked", "user", target.id, {"sessions": int(revoked)}, request)
    db.commit()
    return {"revoked": int(revoked)}


class NameBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    full_name: Annotated[str, Field(min_length=1, max_length=120)]
    reason: Annotated[str, Field(min_length=3, max_length=280)]


@router.put("/users/{user_id}/name")
async def rename_user(
    user_id: int, body: NameBody, request: Request,
    user: User = Depends(require_permission("users.manage")),
    db: Session = Depends(get_db),
):
    target = _managed_target(db, user, user_id)
    name = " ".join(body.full_name.split())
    if not name:
        raise HTTPException(status_code=422, detail="Le nom ne peut pas être vide")
    old = target.full_name
    target.full_name = name
    _audit(db, user, "user_rename", "user", target.id,
           {"from": old, "to": name, "reason": body.reason.strip()}, request)
    db.commit()
    await _announce(db, target.id)
    return _user_json(target)


class ReasonBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    reason: Annotated[str, Field(min_length=3, max_length=280)]


@router.post("/users/{user_id}/avatar/remove")
async def remove_avatar(
    user_id: int, body: ReasonBody, request: Request,
    user: User = Depends(require_permission("users.manage")),
    db: Session = Depends(get_db),
):
    from app.api.v1.account.account_privacy import _delete_media_if_orphan
    target = _managed_target(db, user, user_id)
    if not target.avatar_media_id:
        raise HTTPException(status_code=409, detail="Ce compte n'a pas de photo de profil")
    asset_id = target.avatar_media_id
    target.avatar_media_id = None
    db.flush()
    _delete_media_if_orphan(db, [asset_id])
    _audit(db, user, "user_avatar_removed", "user", target.id,
           {"media_id": asset_id, "reason": body.reason.strip()}, request)
    db.commit()
    await _announce(db, target.id)
    return _user_json(target)


@router.delete("/users/{user_id}/devices/{device_id}")
def remove_device(
    user_id: int, device_id: int, request: Request,
    user: User = Depends(require_permission("users.manage")),
    db: Session = Depends(get_db),
):
    """Retirer un appareil : ses notifications s'arrêtent ET la session qui
    l'a enregistré est révoquée (même règle que « Appareils connectés »)."""
    target = _managed_target(db, user, user_id)
    device = db.query(DeviceToken).filter(DeviceToken.id == device_id, DeviceToken.user_id == target.id).first()
    if device is None:
        raise HTTPException(status_code=404, detail="Appareil introuvable")
    if device.session_jti:
        db.query(Token).filter(
            Token.user_id == target.id, Token.jti == device.session_jti, Token.revoked_at.is_(None),
        ).update({Token.revoked_at: datetime.utcnow()}, synchronize_session=False)
    _audit(db, user, "user_device_removed", "user", target.id,
           {"device_id": device.id, "platform": device.platform}, request)
    db.delete(device)
    db.commit()
    return {"ok": True}


class DeleteBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    confirm: Annotated[str, Field(min_length=1, max_length=40)]
    reason: Annotated[str, Field(min_length=3, max_length=280)]


@router.post("/users/{user_id}/delete")
def delete_user(
    user_id: int, body: DeleteBody, request: Request,
    user: User = Depends(require_permission("users.manage")),
    db: Session = Depends(get_db),
):
    """Supprime un compte selon la règle de la suppression depuis l'app
    (account_privacy.erase_account) : effacé, anonymisé, désactivé. La
    confirmation est le numéro du compte retapé (ou « SUPPRIMER » s'il n'en
    a pas). Un membre de l'équipe doit d'abord en être retiré."""
    from app.api.v1.account.account_privacy import erase_account
    target = _managed_target(db, user, user_id)
    if (target.role or UserRole.USER) != UserRole.USER:
        raise HTTPException(status_code=409, detail="Retire d'abord ce compte de l'équipe")
    if not target.is_active and not target.phone and not target.email:
        raise HTTPException(status_code=409, detail="Ce compte est déjà supprimé")
    digits = "".join(ch for ch in (target.phone or "") if ch.isdigit())
    typed = body.confirm.strip()
    ok = ("".join(ch for ch in typed if ch.isdigit()) == digits) if digits else typed == "SUPPRIMER"
    if not ok:
        raise HTTPException(status_code=400, detail="La confirmation ne correspond pas — la suppression est annulée")
    _audit(db, user, "user_delete", "user", target.id, {"reason": body.reason.strip()}, request)
    target.console_password_hash = None
    result = erase_account(db, target)
    return {"deleted": True, "removed": result.get("removed"), "kept": result.get("kept")}


# ── Équipe ───────────────────────────────────────────────────────────────

class MemberProfileBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    full_name: Annotated[str, Field(min_length=2, max_length=120)]
    email: Annotated[str, Field(min_length=5, max_length=255, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")]


def _member(db: Session, user_id: int) -> User:
    target = db.get(User, user_id)
    if target is None or (target.role or UserRole.USER) == UserRole.USER:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    return target


@router.put("/team/{user_id}/profile")
def update_member_profile(
    user_id: int, body: MemberProfileBody, request: Request,
    user: User = Depends(require_permission("team.manage")),
    db: Session = Depends(get_db),
):
    target = _member(db, user_id)
    email = body.email.strip().lower()
    name = " ".join(body.full_name.split())
    if len(name) < 2:
        raise HTTPException(status_code=422, detail="Nom trop court")
    taken = db.query(User.id).filter(func.lower(User.email) == email, User.id != target.id).first()
    if taken:
        raise HTTPException(status_code=409, detail="Cet e-mail est déjà utilisé par un autre compte")
    changes = {}
    if target.full_name != name:
        changes["full_name"] = {"from": target.full_name, "to": name}
    if (target.email or "").lower() != email:
        changes["email"] = {"from": target.email, "to": email}
    target.full_name = name
    target.email = email
    if changes:
        _audit(db, user, "team_profile_update", "user", target.id, changes, request)
    db.commit()
    return _user_json(target)


@router.post("/team/{user_id}/console-access/disable")
def disable_console_access(
    user_id: int, request: Request,
    user: User = Depends(require_permission("team.manage")),
    db: Session = Depends(get_db),
):
    """Ferme l'accès à la console sans toucher au compte ni au rôle : le mot
    de passe de console est effacé et les sessions de console sont révoquées.
    L'accès se rétablit avec « Nouveau mot de passe »."""
    target = _member(db, user_id)
    if target.id == user.id:
        raise HTTPException(status_code=409, detail="Tu ne peux pas fermer ton propre accès")
    if not target.console_password_hash:
        raise HTTPException(status_code=409, detail="Ce membre n'a déjà plus accès à la console")
    if target.role == UserRole.SUPER_ADMIN:
        others = db.query(func.count(User.id)).filter(
            User.role == UserRole.SUPER_ADMIN, User.id != target.id, User.is_active.is_(True),
            User.console_password_hash.isnot(None)).scalar()
        if not others:
            raise HTTPException(status_code=409, detail="Il faut garder au moins un super-administrateur avec accès")
    target.console_password_hash = None
    target.console_failed_attempts = 0
    target.console_locked_until = None
    db.query(Token).filter(
        Token.user_id == target.id, Token.client == "console", Token.revoked_at.is_(None),
    ).update({Token.revoked_at: datetime.utcnow()}, synchronize_session=False)
    _audit(db, user, "console_access_disabled", "user", target.id, None, request)
    db.commit()
    return _user_json(target)
