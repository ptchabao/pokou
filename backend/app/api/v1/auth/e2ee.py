"""Pokou — annuaire de clés publiques pour le chiffrement de bout en bout.

Ce module est délibérément petit, et c'est la propriété la plus importante
du chiffrement de bout en bout : le serveur n'a qu'un rôle d'ANNUAIRE. Il
publie des clés publiques, en distribue à qui veut ouvrir une session, et
raye les pré-clés à usage unique au passage. Il ne détient aucune clé
privée, ne participe à aucun échange, et ne peut déchiffrer aucun des
messages qu'il stocke.

La seule attaque qu'un serveur d'annuaire peut monter, c'est de substituer
ses propres clés — se placer au milieu. Deux choses la rendent détectable :

- la pré-clé est SIGNÉE par la clé de signature de l'appareil, elle-même
  liée à la clé d'identité ; un annuaire qui substitue la pré-clé sans la
  clé d'identité produit une signature invalide, et le client refuse ;
- s'il substitue AUSSI l'identité, alors elle change — et le client
  l'affiche (« la clé de sécurité de X a changé »), ce qui est précisément
  ce que sert à voir un numéro de sécurité comparé de vive voix.

Autrement dit : ce code ne peut pas garantir l'absence d'attaque, il peut
seulement garantir qu'elle laisse une trace. C'est ce que fait le
chiffrement de bout en bout, et il ne faut pas lui en prêter davantage.
"""
import base64
import logging
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.models import DeviceKeyBundle, OneTimePrekey, User
from app.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/e2ee", tags=["Pokou chiffrement"])

#: En dessous, le client réapprovisionne. Une réserve épuisée n'empêche pas
#: d'ouvrir une session — on retombe sur la pré-clé signée seule, ce qui
#: reste sûr mais perd l'unicité par session (voir OneTimePrekey).
LOW_PREKEY_THRESHOLD = 10
MAX_PREKEYS_PER_UPLOAD = 100


def _b64_len(value: str, expected_bytes: int, field: str) -> str:
    """Valide qu'une clé est bien du base64 de la BONNE TAILLE.

    Ce n'est pas du zèle : une clé X25519 tronquée ou d'une autre courbe
    ferait échouer le déchiffrement chez le correspondant, très loin d'ici,
    sous la forme d'un message illisible sans explication. Refuser à la
    publication transforme une panne silencieuse en erreur nommée.
    """
    try:
        raw = base64.b64decode(value, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail=f"{field} n'est pas du base64 valide")
    if len(raw) != expected_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"{field} fait {len(raw)} octets, {expected_bytes} attendus",
        )
    return value


class PrekeyUpload(BaseModel):
    key_id: int = Field(..., ge=0)
    public_key: str = Field(..., max_length=64)


class BundleUpload(BaseModel):
    device_id: str = Field(..., min_length=8, max_length=64)
    identity_key: str = Field(..., max_length=64)
    signing_key: str = Field(..., max_length=64)
    signed_prekey: str = Field(..., max_length=64)
    signed_prekey_signature: str = Field(..., max_length=128)
    one_time_prekeys: List[PrekeyUpload] = Field(default_factory=list)
    # Ce que l'application sait chiffrer au-delà du texte. Absent chez les
    # versions antérieures : la liste vide est alors la bonne réponse.
    capabilities: List[str] = Field(default_factory=list, max_length=16)


@router.put("/bundle")
async def publish_bundle(
    payload: BundleUpload,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Publie (ou remplace) son trousseau public.

    Remplacer efface les anciennes pré-clés à usage unique : elles
    appartenaient à une identité qui n'existe plus, et les garder ferait
    dériver des sessions vers une clé privée que plus personne ne détient.
    """
    user_id = current_user["user_id"]

    _b64_len(payload.identity_key, 32, "identity_key")
    _b64_len(payload.signing_key, 32, "signing_key")
    _b64_len(payload.signed_prekey, 32, "signed_prekey")
    _b64_len(payload.signed_prekey_signature, 64, "signed_prekey_signature")
    if len(payload.one_time_prekeys) > MAX_PREKEYS_PER_UPLOAD:
        raise HTTPException(
            status_code=400, detail=f"Au plus {MAX_PREKEYS_PER_UPLOAD} pré-clés par envoi"
        )
    for prekey in payload.one_time_prekeys:
        _b64_len(prekey.public_key, 32, f"pré-clé {prekey.key_id}")

    bundle = db.query(DeviceKeyBundle).filter(DeviceKeyBundle.user_id == user_id).first()
    identity_changed = bundle is not None and bundle.identity_key != payload.identity_key

    if bundle is None:
        bundle = DeviceKeyBundle(user_id=user_id)
        db.add(bundle)

    bundle.device_id = payload.device_id
    bundle.identity_key = payload.identity_key
    bundle.signing_key = payload.signing_key
    bundle.signed_prekey = payload.signed_prekey
    bundle.signed_prekey_signature = payload.signed_prekey_signature
    bundle.capabilities = sorted({c for c in payload.capabilities if 0 < len(c) <= 32})
    bundle.updated_at = datetime.utcnow()
    db.flush()

    if identity_changed:
        db.query(OneTimePrekey).filter(OneTimePrekey.bundle_id == bundle.id).delete()

    existing_ids = {
        row[0]
        for row in db.query(OneTimePrekey.key_id).filter(OneTimePrekey.bundle_id == bundle.id).all()
    }
    added = 0
    for prekey in payload.one_time_prekeys:
        if prekey.key_id in existing_ids:
            continue
        db.add(
            OneTimePrekey(
                bundle_id=bundle.id, key_id=prekey.key_id, public_key=prekey.public_key
            )
        )
        added += 1

    db.commit()
    return {"published": True, "prekeys_added": added, "identity_changed": identity_changed}


@router.get("/prekeys/count")
async def count_prekeys(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Combien de pré-clés me reste-t-il ? — le client réapprovisionne seul.

    Les pré-clés à usage unique s'épuisent sans que leur propriétaire en
    fasse rien : ce sont les CORRESPONDANTS qui les consomment. Sans ce
    compteur, la réserve se viderait en silence.
    """
    bundle = (
        db.query(DeviceKeyBundle)
        .filter(DeviceKeyBundle.user_id == current_user["user_id"])
        .first()
    )
    if not bundle:
        return {"published": False, "available": 0, "low": True}
    available = (
        db.query(OneTimePrekey)
        .filter(OneTimePrekey.bundle_id == bundle.id, OneTimePrekey.claimed_at.is_(None))
        .count()
    )
    return {"published": True, "available": available, "low": available < LOW_PREKEY_THRESHOLD}


@router.get("/bundle/{user_id}")
async def claim_bundle(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Récupère le trousseau de quelqu'un pour lui ouvrir une session.

    CONSOMME une pré-clé à usage unique au passage — d'où un GET qui écrit,
    ce qui mérite d'être dit : la sémantique HTTP voudrait un POST, mais
    l'opération est une LECTURE d'annuaire du point de vue de l'appelant, et
    la rendre idempotente reviendrait à distribuer deux fois la même pré-clé,
    ce qu'elle existe précisément pour empêcher.

    Répond 404 quand la personne n'a pas encore publié de trousseau : elle
    n'a pas de version de l'application qui chiffre, et l'appelant doit
    retomber sur un envoi en clair plutôt que d'échouer.
    """
    if not db.query(User.id).filter(User.id == user_id).first():
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    bundle = (
        db.query(DeviceKeyBundle)
        .options(joinedload(DeviceKeyBundle.one_time_prekeys))
        .filter(DeviceKeyBundle.user_id == user_id)
        .first()
    )
    if not bundle:
        raise HTTPException(
            status_code=404, detail="Cette personne n'a pas encore publié de clés de chiffrement"
        )

    prekey: Optional[OneTimePrekey] = (
        db.query(OneTimePrekey)
        .filter(OneTimePrekey.bundle_id == bundle.id, OneTimePrekey.claimed_at.is_(None))
        .order_by(OneTimePrekey.key_id)
        .with_for_update(skip_locked=True)
        .first()
        if db.bind and db.bind.dialect.name == "postgresql"
        else db.query(OneTimePrekey)
        .filter(OneTimePrekey.bundle_id == bundle.id, OneTimePrekey.claimed_at.is_(None))
        .order_by(OneTimePrekey.key_id)
        .first()
    )
    if prekey is not None:
        prekey.claimed_at = datetime.utcnow()
        db.commit()

    return {
        "user_id": user_id,
        "device_id": bundle.device_id,
        "identity_key": bundle.identity_key,
        "signing_key": bundle.signing_key,
        "signed_prekey": bundle.signed_prekey,
        "signed_prekey_signature": bundle.signed_prekey_signature,
        # `null` est une réponse normale, pas une panne : réserve épuisée, on
        # ouvre la session sans pré-clé unique (voir le docstring du module).
        "one_time_prekey": (
            {"key_id": prekey.key_id, "public_key": prekey.public_key} if prekey else None
        ),
    }


@router.get("/capabilities/{user_id}")
async def peer_capabilities(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ce que l'appareil de quelqu'un sait chiffrer — sans consommer de
    pré-clé, contrairement à /bundle.

    Sert à décider AVANT d'envoyer : une photo ou un appel chiffré vers une
    version qui ne sait pas l'ouvrir arriverait illisible. Liste vide si la
    personne n'a pas de trousseau, ou une version qui ne déclare rien.
    """
    bundle = (
        db.query(DeviceKeyBundle.capabilities, DeviceKeyBundle.identity_key)
        .filter(DeviceKeyBundle.user_id == user_id)
        .first()
    )
    capabilities = (bundle[0] if bundle else None) or []
    return {
        "user_id": user_id,
        "capabilities": list(capabilities),
        # Publique, comme dans /bundle — mais lue ici SANS consommer de
        # pré-clé : l'appelant vérifie que sa session ouverte vise toujours
        # cette identité avant d'y sceller une clé de fichier ou d'appel.
        "identity_key": bundle[1] if bundle else None,
    }

