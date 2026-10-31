"""Les stickers : packs, favoris, récents, recherche et suggestions.

── Ce qu'un sticker N'EST PAS ────────────────────────────────────────────

Ce n'est pas une image. Il s'affiche sans cadre ni fond, ne s'ouvre pas en
plein écran, ne se télécharge pas dans la galerie, et ne compte pas dans les
« photos » d'une conversation. D'où un `MessageType` à part : ranger les
stickers avec les images obligerait chaque écran à redécouvrir ces règles à
partir d'un drapeau, au lieu de les lire dans le type.

── Deux chemins de recherche, et ils ne se confondent pas ────────────────

`emoji_tags` sert aux SUGGESTIONS : quelqu'un tape 😂, on lui propose les
stickers marqués 😂, sans qu'il ait rien demandé.

`keywords` sert à la recherche ÉCRITE : on tape « bravo », on cherche dans
les mots.

Les fondre dans un seul champ rendrait impossible de suggérer sans aussi
chercher — et proposer des stickers à chaque mot tapé serait insupportable.
"""
import logging
import re
import unicodedata
from datetime import datetime
from typing import Any, Optional

from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload

from app.models import MediaAsset, Sticker, StickerFavorite, StickerPack, StickerRecent, User, UserStickerPack

logger = logging.getLogger(__name__)

#: Au-delà, la liste des récents ne sert plus à rien : on ne fait défiler que
#: les premiers, et les garder tous ferait grandir la table sans fin.
MAX_RECENTS = 32

#: Un pack personnel est borné. La limite protège deux choses : le temps de
#: chargement du panneau, et la facture de stockage d'un compte qui
#: téléverserait sans fin.
MAX_PERSONAL_STICKERS = 30


def _slugify(value: str) -> str:
    """Un identifiant lisible et partageable, tiré du nom.

    Les accents sont dépliés plutôt que supprimés : « Café » devient
    « cafe » et non « caf », ce qui resterait cherchable.
    """
    sans_accent = "".join(
        c for c in unicodedata.normalize("NFD", value) if unicodedata.category(c) != "Mn"
    )
    slug = re.sub(r"[^a-z0-9]+", "-", sans_accent.lower()).strip("-")
    return slug[:48] or "pack"


def _unique_slug(db: Session, base: str) -> str:
    slug = base
    suffixe = 2
    while db.query(StickerPack.id).filter(StickerPack.slug == slug).first():
        slug = f"{base}-{suffixe}"
        suffixe += 1
    return slug


def serialize_sticker(sticker: Sticker) -> dict[str, Any]:
    return {
        "id": sticker.id,
        "pack_id": sticker.pack_id,
        "media_id": sticker.media_asset_id,
        "emoji_tags": (sticker.emoji_tags or "").split(),
        "keywords": (sticker.keywords or ""),
    }


def serialize_pack(
    pack: StickerPack, *, installed: bool = False, with_stickers: bool = True
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "id": pack.id,
        "slug": pack.slug,
        "name": pack.name,
        "author_name": pack.author_name,
        "cover_media_id": pack.cover_media_id,
        "is_animated": pack.is_animated,
        "is_personal": pack.owner_user_id is not None,
        "installed": installed,
        "sticker_count": len(pack.stickers),
    }
    if with_stickers:
        payload["stickers"] = [
            serialize_sticker(s)
            for s in sorted(pack.stickers, key=lambda s: (s.position, s.id))
        ]
    return payload


# ── Ce que l'utilisateur a ───────────────────────────────────────────────


def installed_packs(db: Session, user_id: int) -> list[dict[str, Any]]:
    """Les packs de quelqu'un, DANS SON ORDRE.

    Ses packs personnels sont toujours présents sans installation : les lui
    faire installer serait absurde, il les a créés.
    """
    liens = (
        db.query(UserStickerPack)
        .filter(UserStickerPack.user_id == user_id)
        .order_by(UserStickerPack.position, UserStickerPack.id)
        .all()
    )
    ids_installes = [lien.pack_id for lien in liens]

    packs = (
        db.query(StickerPack)
        .options(joinedload(StickerPack.stickers))
        .filter(
            or_(
                StickerPack.id.in_(ids_installes) if ids_installes else False,
                StickerPack.owner_user_id == user_id,
            )
        )
        .all()
    )
    par_id = {p.id: p for p in packs}

    ordonnes: list[dict[str, Any]] = []
    for pack_id in ids_installes:
        pack = par_id.pop(pack_id, None)
        if pack:
            ordonnes.append(serialize_pack(pack, installed=True))
    # Les packs personnels non explicitement installés viennent ensuite.
    for pack in par_id.values():
        ordonnes.append(serialize_pack(pack, installed=False))
    return ordonnes


def install(db: Session, user_id: int, pack_id: int) -> bool:
    """Ajoute un pack. Idempotent : réinstaller ne duplique rien."""
    pack = db.query(StickerPack).filter(StickerPack.id == pack_id).first()
    if pack is None:
        return False
    # Un pack personnel non publié n'est installable que par son auteur.
    if pack.owner_user_id is not None and not pack.is_public:
        if pack.owner_user_id != user_id:
            return False

    existant = (
        db.query(UserStickerPack)
        .filter(
            UserStickerPack.user_id == user_id, UserStickerPack.pack_id == pack_id
        )
        .first()
    )
    if existant:
        return True

    derniere = (
        db.query(func.max(UserStickerPack.position))
        .filter(UserStickerPack.user_id == user_id)
        .scalar()
    )
    db.add(
        UserStickerPack(
            user_id=user_id, pack_id=pack_id, position=(derniere or 0) + 1
        )
    )
    db.commit()
    return True


def uninstall(db: Session, user_id: int, pack_id: int) -> None:
    """Retire un pack de sa liste.

    Le pack lui-même n'est pas touché : d'autres l'ont peut-être installé, et
    un pack personnel se supprime autrement (voir `delete_personal_pack`).
    """
    db.query(UserStickerPack).filter(
        UserStickerPack.user_id == user_id, UserStickerPack.pack_id == pack_id
    ).delete(synchronize_session=False)
    db.commit()


def reorder(db: Session, user_id: int, pack_ids: list[int]) -> None:
    """Range les packs dans l'ordre donné.

    Les identifiants inconnus sont ignorés plutôt que refusés : une liste
    envoyée depuis un écran ouvert depuis longtemps peut citer un pack
    désinstallé entre-temps, et faire échouer tout le réordonnancement pour
    ça serait disproportionné.
    """
    liens = {
        lien.pack_id: lien
        for lien in db.query(UserStickerPack).filter(
            UserStickerPack.user_id == user_id
        )
    }
    for position, pack_id in enumerate(pack_ids):
        lien = liens.get(pack_id)
        if lien:
            lien.position = position
    db.commit()


# ── Favoris et récents ───────────────────────────────────────────────────


def favorites(db: Session, user_id: int) -> list[dict[str, Any]]:
    lignes = (
        db.query(Sticker)
        .join(StickerFavorite, StickerFavorite.sticker_id == Sticker.id)
        .filter(StickerFavorite.user_id == user_id)
        .order_by(StickerFavorite.created_at.desc())
        .all()
    )
    return [serialize_sticker(s) for s in lignes]


def toggle_favorite(db: Session, user_id: int, sticker_id: int) -> bool:
    """Ajoute ou retire des favoris. Renvoie l'état APRÈS l'opération."""
    existant = (
        db.query(StickerFavorite)
        .filter(
            StickerFavorite.user_id == user_id,
            StickerFavorite.sticker_id == sticker_id,
        )
        .first()
    )
    if existant:
        db.delete(existant)
        db.commit()
        return False
    if not db.query(Sticker.id).filter(Sticker.id == sticker_id).first():
        return False
    db.add(StickerFavorite(user_id=user_id, sticker_id=sticker_id))
    db.commit()
    return True


def recents(db: Session, user_id: int, limit: int = MAX_RECENTS) -> list[dict[str, Any]]:
    lignes = (
        db.query(Sticker)
        .join(StickerRecent, StickerRecent.sticker_id == Sticker.id)
        .filter(StickerRecent.user_id == user_id)
        .order_by(StickerRecent.used_at.desc())
        .limit(limit)
        .all()
    )
    return [serialize_sticker(s) for s in lignes]


def mark_used(db: Session, user_id: int, sticker_id: int) -> None:
    """Note qu'un sticker vient d'être envoyé.

    Une ligne PAR (personne, sticker), mise à jour — et non une par envoi.
    L'historique complet ne sert à rien et ferait grandir la table à chaque
    message.
    """
    if not db.query(Sticker.id).filter(Sticker.id == sticker_id).first():
        return
    ligne = (
        db.query(StickerRecent)
        .filter(
            StickerRecent.user_id == user_id, StickerRecent.sticker_id == sticker_id
        )
        .first()
    )
    if ligne:
        ligne.used_at = datetime.utcnow()
    else:
        db.add(StickerRecent(user_id=user_id, sticker_id=sticker_id))
    db.commit()
    _trim_recents(db, user_id)


def _trim_recents(db: Session, user_id: int) -> None:
    """Ne garde que les plus récents.

    Sans cette coupe, la table grandit d'une ligne par sticker jamais
    réutilisé, indéfiniment.
    """
    surplus = (
        db.query(StickerRecent.id)
        .filter(StickerRecent.user_id == user_id)
        .order_by(StickerRecent.used_at.desc())
        .offset(MAX_RECENTS)
        .all()
    )
    if not surplus:
        return
    db.query(StickerRecent).filter(
        StickerRecent.id.in_([row[0] for row in surplus])
    ).delete(synchronize_session=False)
    db.commit()


# ── Recherche et suggestions ─────────────────────────────────────────────


def search(db: Session, user_id: int, query: str, limit: int = 40) -> list[dict[str, Any]]:
    """Cherche dans les mots-clés, le nom du pack, et les emojis.

    Les trois ensemble : quelqu'un qui tape « rire » cherche le mot,
    quelqu'un qui colle 😂 cherche l'emoji, et quelqu'un qui tape le nom d'un
    pack cherche son contenu. Les séparer en trois routes obligerait
    l'interface à deviner laquelle appeler.
    """
    terme = (query or "").strip()
    if not terme:
        return []
    motif = f"%{terme.lower()}%"

    lignes = (
        db.query(Sticker)
        .join(StickerPack, StickerPack.id == Sticker.pack_id)
        .filter(
            or_(
                StickerPack.owner_user_id.is_(None),
                StickerPack.is_public.is_(True),
                StickerPack.owner_user_id == user_id,
            )
        )
        .filter(
            or_(
                func.lower(Sticker.keywords).like(motif),
                func.lower(StickerPack.name).like(motif),
                Sticker.emoji_tags.like(f"%{terme}%"),
            )
        )
        .limit(limit)
        .all()
    )
    return [serialize_sticker(s) for s in lignes]


#: Les emojis se composent : un visage peut porter un modificateur de teint,
#: un sélecteur de variante, un joncteur. Comparer les chaînes brutes ferait
#: manquer 👍🏾 quand le sticker est marqué 👍.
_MODIFIERS = re.compile("[\U0001F3FB-\U0001F3FF️‍]")


def normalize_emoji(raw: str) -> str:
    """Réduit un emoji à sa forme de base, pour que les variantes s'associent."""
    return _MODIFIERS.sub("", raw or "").strip()


def suggest_for_emoji(
    db: Session, user_id: int, emoji: str, limit: int = 12
) -> list[dict[str, Any]]:
    """Les stickers à proposer quand quelqu'un tape cet emoji.

    Bornée aux packs que la personne A — proposer un sticker qu'elle ne peut
    pas envoyer serait une invitation à un échec. C'est la différence avec la
    recherche, qui explore tout ce qui est public.
    """
    base = normalize_emoji(emoji)
    if not base:
        return []

    ids_packs = [
        row[0]
        for row in db.query(UserStickerPack.pack_id).filter(
            UserStickerPack.user_id == user_id
        )
    ]
    ids_packs += [
        row[0]
        for row in db.query(StickerPack.id).filter(
            StickerPack.owner_user_id == user_id
        )
    ]
    if not ids_packs:
        return []

    lignes = (
        db.query(Sticker)
        .filter(Sticker.pack_id.in_(ids_packs))
        .filter(Sticker.emoji_tags.like(f"%{base}%"))
        .limit(limit)
        .all()
    )
    return [serialize_sticker(s) for s in lignes]


# ── Packs personnels ─────────────────────────────────────────────────────


def create_personal_pack(
    db: Session, user_id: int, name: str
) -> Optional[StickerPack]:
    nom = (name or "").strip()[:64]
    if not nom:
        return None
    auteur = db.query(User).filter(User.id == user_id).first()
    pack = StickerPack(
        name=nom,
        slug=_unique_slug(db, _slugify(nom)),
        author_name=(auteur.full_name if auteur else None),
        owner_user_id=user_id,
        is_public=False,
    )
    db.add(pack)
    db.commit()
    db.refresh(pack)
    return pack


class StickerLimitReached(Exception):
    """Le pack est plein."""


def add_to_personal_pack(
    db: Session,
    user_id: int,
    pack_id: int,
    media_asset_id: int,
    emoji_tags: str = "",
    keywords: str = "",
) -> Optional[Sticker]:
    """Ajoute un sticker créé depuis une photo.

    Le média doit appartenir à celui qui l'ajoute : sans ce contrôle, on
    pourrait fabriquer un sticker à partir de la photo de quelqu'un d'autre
    en devinant un identifiant.
    """
    pack = (
        db.query(StickerPack)
        .filter(StickerPack.id == pack_id, StickerPack.owner_user_id == user_id)
        .first()
    )
    if pack is None:
        return None

    if len(pack.stickers) >= MAX_PERSONAL_STICKERS:
        raise StickerLimitReached(
            f"Un pack contient au plus {MAX_PERSONAL_STICKERS} stickers."
        )

    media = (
        db.query(MediaAsset)
        .filter(MediaAsset.id == media_asset_id, MediaAsset.uploader_id == user_id)
        .first()
    )
    if media is None:
        return None

    sticker = Sticker(
        pack_id=pack.id,
        media_asset_id=media.id,
        # NORMALISÉ à l'écriture, comme à la lecture.
        #
        # `suggest_for_emoji` cherche la forme de base (`normalize_emoji`)
        # par un LIKE. Ranger la forme brute ici rendait certains stickers
        # INTROUVABLES : une étiquette 👨‍👩‍👧 porte des joncteurs que la
        # recherche a justement retirés du terme cherché, donc la
        # sous-chaîne ne correspondait jamais. Les deux côtés doivent
        # parler la même forme, et c'est le seul moyen de s'en assurer.
        emoji_tags=normalize_emoji(emoji_tags)[:128] or None,
        keywords=(keywords or "").strip()[:255] or None,
        position=len(pack.stickers),
    )
    # La première image devient la couverture : un pack sans vignette est
    # indistinguable des autres dans la liste.
    if pack.cover_media_id is None:
        pack.cover_media_id = media.id
    db.add(sticker)
    db.commit()
    db.refresh(sticker)
    return sticker


def delete_personal_pack(db: Session, user_id: int, pack_id: int) -> bool:
    pack = (
        db.query(StickerPack)
        .filter(StickerPack.id == pack_id, StickerPack.owner_user_id == user_id)
        .first()
    )
    if pack is None:
        return False
    db.delete(pack)
    db.commit()
    return True


# ── Le droit d'envoyer, et le droit de voir ──────────────────────────────
#
# Ces deux fonctions existent parce qu'un sticker CASSE l'hypothèse que tout
# le reste de l'application tient pour acquise : « la pièce jointe d'un
# message a été téléversée par celui qui l'envoie ».
#
# Un sticker, non. Il appartient au pack — donc à son auteur, ou au compte
# officiel. Sans exception explicite, `POST /messages` répondrait
# « Pièce jointe introuvable » à chaque sticker, et la fonctionnalité
# entière serait morte à l'envoi.
#
# L'exception est écrite ICI, une seule fois, et pas recopiée dans
# messages.py puis dans groups.py. La règle « qui puis-je joindre » avait
# été écrite à quatre endroits dans ce dépôt ; trois avaient divergé, et
# c'est ce qui a produit un 403 en production. On ne recommence pas.


def sender_may_attach(db: Session, media_asset_id: int, user_id: int) -> bool:
    """Cet utilisateur a-t-il le droit d'ENVOYER ce média comme sticker ?

    Deux cas, et deux seulement : un pack public (le catalogue, ouvert à
    tous), ou un pack personnel dont il est le propriétaire.

    Ce que ça n'autorise PAS, et c'est le point : joindre le média de
    quelqu'un d'autre en devinant son identifiant. Un id qui ne correspond
    à aucun sticker retombe sur la règle ordinaire du téléversement.
    """
    return (
        db.query(Sticker.id)
        .join(StickerPack, StickerPack.id == Sticker.pack_id)
        .filter(
            Sticker.media_asset_id == media_asset_id,
            or_(
                StickerPack.is_public.is_(True),
                StickerPack.owner_user_id == user_id,
            ),
        )
        .first()
        is not None
    )


def is_public_sticker_media(db: Session, media_asset_id: int) -> bool:
    """Ce média est-il un sticker d'un pack PUBLIC ?

    Sert au téléchargement (`GET /media/{id}`) : le panneau affiche le
    catalogue avant tout envoi, donc il n'existe encore aucun message pour
    justifier l'accès. Un pack public est fait pour être parcouru — c'est
    la même règle que les photos du catalogue et les visuels de chaîne.

    Un sticker de pack PERSONNEL n'est pas concerné : celui qui le reçoit y
    accède par le message qui le porte, pas par le catalogue.
    """
    return (
        db.query(Sticker.id)
        .join(StickerPack, StickerPack.id == Sticker.pack_id)
        .filter(
            Sticker.media_asset_id == media_asset_id,
            StickerPack.is_public.is_(True),
        )
        .first()
        is not None
    )


# ── Garder un sticker qu'on a reçu ───────────────────────────────────────


class StickerNotReachable(Exception):
    """Ce sticker n'est pas à portée de cet utilisateur."""


def save_received(db: Session, user_id: int, media_asset_id: int) -> Optional[Sticker]:
    """Range dans SES stickers celui qu'on vient de recevoir.

    ── Pourquoi ce n'est pas `add_to_personal_pack` ────────────────────

    Celui-là exige que le média appartienne à celui qui l'ajoute — c'est ce
    qui empêche de fabriquer un sticker à partir de la photo d'autrui en
    devinant un identifiant. Un sticker reçu appartient par construction à
    quelqu'un d'autre : le créateur du pack.

    La condition est donc différente, et plus étroite qu'elle n'en a l'air :
    **il faut que ce média soit déjà un sticker**. On ne range pas une photo
    reçue dans ses stickers par ce chemin — seulement quelque chose qui a
    été publié comme sticker, dans un pack public ou dans le pack personnel
    de celui qui l'a envoyé.

    ── Pourquoi on ne recopie pas le fichier ──────────────────────────

    La nouvelle ligne pointe vers le MÊME `MediaAsset`. Dupliquer l'image
    ferait grossir le stockage d'une copie par personne qui garde le même
    sticker, pour un fichier identique à l'octet près. Et le droit d'envoi
    suit : une fois la ligne dans SON pack personnel,
    `sender_may_attach` l'autorise, sans exception supplémentaire.

    Idempotent : ranger deux fois le même sticker rend celui qui est déjà
    là. Un double appui ne doit pas produire un doublon dans la grille.
    """
    source = (
        db.query(Sticker)
        .filter(Sticker.media_asset_id == media_asset_id)
        .first()
    )
    if source is None:
        raise StickerNotReachable("Ce média n'est pas un sticker.")

    pack = (
        db.query(StickerPack)
        .filter(StickerPack.owner_user_id == user_id)
        .order_by(StickerPack.id)
        .first()
    )
    if pack is not None:
        deja = (
            db.query(Sticker)
            .filter(
                Sticker.pack_id == pack.id,
                Sticker.media_asset_id == media_asset_id,
            )
            .first()
        )
        if deja is not None:
            return deja
        if len(pack.stickers) >= MAX_PERSONAL_STICKERS:
            raise StickerLimitReached(
                f"Un pack contient au plus {MAX_PERSONAL_STICKERS} stickers."
            )
    else:
        pack = create_personal_pack(db, user_id, "Mes stickers")
        if pack is None:
            return None

    copie = Sticker(
        pack_id=pack.id,
        media_asset_id=media_asset_id,
        # Les étiquettes suivent : un sticker gardé doit se retrouver par
        # les mêmes emojis et les mêmes mots que l'original, sinon il
        # disparaît de la recherche en changeant de pack.
        emoji_tags=source.emoji_tags,
        keywords=source.keywords,
        position=len(pack.stickers),
    )
    if pack.cover_media_id is None:
        pack.cover_media_id = media_asset_id
    db.add(copie)
    db.commit()
    db.refresh(copie)
    return copie
