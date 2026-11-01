"""Pokou — upload/téléchargement des pièces jointes. Voir
app/services/media_storage.py pour le stockage et les règles de type/taille."""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Channel, ChannelMember, ChannelPost, Community, CommunityMember, Contact, DirectMessage, Group, GroupMember, GroupMessage, MarketplaceProduct, MarketplaceProductImage, MediaAsset, MessageType, SellerVerificationApplication, Status, SparkLike, SparkMatch, SparkPhoto, SparkProfile, SparkRoomMessage, User, UserRole, VipPost, VipRoom, VipSubscription
from app.services.media import media_storage, object_storage, sticker_service, thumbnail_service
from app.services.privacy import privacy_service, status_privacy_service
from app.core.security import get_current_user

#: Rôles autorisés à examiner une pièce d'identité — les mêmes qui
#: instruisent les dossiers de vérification (voir marketplace_admin.py).
_TEAM_ROLES = {UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.AI_OPERATOR}

router = APIRouter(prefix="/media", tags=["Pokou media"])


@router.post("/upload")
async def upload_media(
    message_type: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    try:
        parsed_type = MessageType(message_type.upper())
    except ValueError:
        raise HTTPException(status_code=400, detail="Type de message invalide")
    if parsed_type == MessageType.TEXT:
        raise HTTPException(status_code=400, detail="Un message texte n'a pas de pièce jointe")

    try:
        asset = await media_storage.save_upload(db, current_user["user_id"], file, parsed_type)
    except media_storage.MediaStorageUnavailableError as exc:
        # 503 et non 400 : la requête est valide, c'est le stockage qui est
        # en panne — le client peut réessayer tel quel.
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except media_storage.MediaError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


def _is_contact_of(db: Session, viewer_id: int, owner_id: int) -> bool:
    """Vrai si l'un des deux a l'autre dans son carnet — la relation
    Contact est unidirectionnelle (A peut avoir B sans que B ait A, ex. B
    répond à un appel de A sans jamais l'avoir ajouté lui-même), donc la
    visibilité d'un avatar ne doit pas dépendre du sens précis."""
    if viewer_id == owner_id:
        return True
    return db.query(Contact).filter(
        or_(
            (Contact.owner_user_id == viewer_id) & (Contact.contact_user_id == owner_id),
            (Contact.owner_user_id == owner_id) & (Contact.contact_user_id == viewer_id),
        )
    ).first() is not None


def _channel_readable(db: Session, channel: Optional[Channel], user_id: int) -> bool:
    """Une chaîne publique se lit sans s'abonner ; une chaîne PRIVÉE exige
    l'abonnement (même règle que channels.py::_exiger_acces, appliquée ici à
    l'octet près : sans cela, qui devinait un identifiant de fichier lisait
    le logo et les images d'une chaîne qu'il ne voyait pas dans le fil)."""
    if channel is None:
        return False
    if not channel.is_private:
        return True
    return (
        db.query(ChannelMember.id)
        .filter(ChannelMember.channel_id == channel.id, ChannelMember.user_id == user_id)
        .first()
        is not None
    )


def _can_access(db: Session, asset: MediaAsset, user_id: int) -> bool:
    if asset.uploader_id == user_id:
        return True

    # Ordonnance HONAM : l'équipe de l'officine destinataire, et elle seule.
    # Ni le coursier ni les autres officines : une ordonnance dit une
    # maladie.
    from app.models.honam import HonamOrder, PharmacyStaff

    prescription = db.query(HonamOrder.pharmacy_id).filter(HonamOrder.prescription_media_id == asset.id).all()
    if prescription:
        pharmacy_ids = [row[0] for row in prescription]
        return db.query(PharmacyStaff.id).filter(
            PharmacyStaff.pharmacy_id.in_(pharmacy_ids), PharmacyStaff.user_id == user_id
        ).first() is not None

    # Les pièces d'un dossier Pokou Business (registre du commerce, pièce
    # d'identité du représentant) : l'équipe qui l'examine, et personne
    # d'autre — même règle que les dossiers vendeur.
    from app.models.business import BusinessOrganization

    dossier = (
        db.query(BusinessOrganization.id)
        .filter((BusinessOrganization.rccm_media_id == asset.id) | (BusinessOrganization.identity_media_id == asset.id))
        .first()
    )
    if dossier is not None:
        viewer = db.query(User).filter(User.id == user_id).first()
        return viewer is not None and viewer.role in _TEAM_ROLES

    # Justificatif Pokou certifié Pro : le support qui le vérifie, et lui
    # seul. Jamais affiché sur le profil Pro.
    from app.models.certified import CertifiedProApplication

    if db.query(CertifiedProApplication.id).filter(CertifiedProApplication.document_media_id == asset.id).first():
        viewer = db.query(User).filter(User.id == user_id).first()
        return viewer is not None and viewer.role in _TEAM_ROLES

    # ── Avatar de profil, TOUT DE SUITE ───────────────────────────────────
    #
    # Visible de ses contacts, comme GET /users/{id}/profile. Cette branche
    # était en septième position, après les messages directs, les groupes,
    # les statuts et les deux requêtes du catalogue.
    #
    # Or l'avatar est, de très loin, le média le plus demandé de
    # l'application : il y en a un par ligne de la liste des discussions, un
    # par contact, un par entrée du journal d'appels, un en tête de chaque
    # conversation. Chacun payait donc cinq requêtes SQL qui ne pouvaient
    # pas le concerner avant d'être reconnu — soit, sur un écran de
    # cinquante contacts, deux cent cinquante requêtes pour rien.
    #
    # L'ordre des branches n'a aucun effet sur QUI a le droit : chacune
    # accorde l'accès indépendamment des autres. Il n'a d'effet que sur le
    # temps qu'il faut pour le dire. C'est le même raisonnement que celui
    # déjà écrit plus bas pour les stickers.
    avatar_owner = db.query(User).filter(User.avatar_media_id == asset.id).first()
    if avatar_owner is not None:
        # `privacy_service` et non `_is_contact_of` : la photo de profil a
        # désormais sa propre règle, que la personne choisit — tout le monde,
        # ses contacts, personne. Le contrôle est ICI, à l'octet près, et pas
        # seulement dans la réponse JSON qui porte l'URL : sinon quiconque
        # avait noté l'adresse une fois continuerait de voir la photo après
        # qu'elle a été masquée.
        if privacy_service.peut_voir(
            db,
            avatar_owner.id,
            user_id,
            privacy_service.Aspect.PHOTO_DE_PROFIL,
            cible=avatar_owner,
        ):
            return True

    # Tous les messages qui portent ce fichier et où l'on est partie
    # prenante, et non le premier trouvé : un même fichier est référencé par
    # autant de messages qu'il a été transféré, et il suffit qu'UN d'eux
    # donne encore l'accès.
    for linked_message in db.query(DirectMessage).filter(
        DirectMessage.media_asset_id == asset.id,
        (DirectMessage.sender_id == user_id) | (DirectMessage.recipient_id == user_id),
    ).all():
        # Vue unique déjà consultée : le destinataire perd l'accès au
        # fichier. Sans ce verrou ICI, il suffirait de rappeler
        # GET /media/{id} pour revoir le contenu et la promesse de la vue
        # unique ne vaudrait rien. L'expéditeur, lui, garde son propre
        # fichier (branche `uploader_id` ci-dessus).
        if linked_message.view_once and linked_message.recipient_id == user_id and linked_message.viewed_at:
            continue
        return True

    # Média envoyé dans un GROUPE — c'était le trou : sans cette branche,
    # seul l'auteur de l'envoi pouvait revoir l'image/la vidéo/le document
    # ensuite ; pour tous les autres membres, GET /media/{id} rendait 404 et
    # la pièce jointe s'affichait cassée dans leur app. Accès tant qu'on est
    # ENCORE membre du groupe qui porte le message — pas seulement au moment
    # de l'envoi, comme le fil du groupe lui-même reste lisible tant qu'on y
    # est.
    for linked_group_message in db.query(GroupMessage).filter(GroupMessage.media_asset_id == asset.id).all():
        if db.query(GroupMember).filter(
            GroupMember.group_id == linked_group_message.group_id, GroupMember.user_id == user_id
        ).first():
            return True

    # Statut (photo/vidéo) — exactement la même règle de visibilité que le
    # fil. Sans ce verrou ici, il suffirait d'appeler GET /media/{id} pour
    # voir la photo d'un statut qu'on n'a pas le droit de voir.
    linked_status = db.query(Status).filter(Status.media_asset_id == asset.id).first()
    if linked_status is not None and status_privacy_service.can_view_statuses_of(
        db, linked_status.user_id, user_id
    ):
        return True

    # Photo d'un produit en vente — visible de TOUT utilisateur authentifié,
    # contrairement aux autres médias : un catalogue est fait pour être
    # parcouru, et c'était le trou qui rendait les photos des produits des
    # AUTRES vendeurs cassées (seul l'auteur du téléversement y accédait).
    # Le produit doit être EN LIGNE, et c'est deux conditions, pas une :
    #
    # - `is_active` : la modération ne l'a pas retiré ;
    # - `deleted_at is NULL` : le vendeur ne l'a pas supprimé lui-même.
    #
    # Seul `is_active` était vérifié. Or l'application n'y touche jamais —
    # elle appelle `DELETE /marketplace/{id}`, qui pose `deleted_at` et
    # laisse `is_active` à vrai. Autrement dit : un vendeur retirait son
    # annonce, la fiche disparaissait du marché, et ses PHOTOS restaient
    # lisibles par tout utilisateur authentifié qui avait gardé l'adresse.
    #
    # Le test qui couvrait ce cas passait parce qu'il désactivait l'annonce
    # par le levier de la MODÉRATION, que le vendeur n'a pas.
    en_ligne = (
        MarketplaceProduct.is_active.is_(True),
        MarketplaceProduct.deleted_at.is_(None),
    )
    is_active_product_image = db.query(MarketplaceProduct).filter(
        *en_ligne,
        MarketplaceProduct.image_media_id == asset.id,
    ).first()
    if is_active_product_image is not None:
        return True
    in_active_gallery = (
        db.query(MarketplaceProductImage)
        .join(MarketplaceProduct, MarketplaceProduct.id == MarketplaceProductImage.product_id)
        .filter(
            MarketplaceProductImage.media_asset_id == asset.id,
            *en_ligne,
        )
        .first()
    )
    if in_active_gallery is not None:
        return True

    # ── Photos de CHAÎNE et publications de chaîne ────────────────────────────
    # Visibles de tout utilisateur authentifié, comme les photos de produits
    # et pour la même raison : une chaîne est PUBLIQUE et se lit avant qu'on
    # s'y abonne (voir channels.py::list_posts). Sans ces deux branches, le
    # logo d'une chaîne et chaque image publiée n'étaient visibles que de
    # l'admin qui les avait téléversées — pour tous les autres, l'app
    # affichait des cadres cassés, ce que montrait le 404 sur GET /media/23
    # juste après GET /channels dans les journaux de production.
    #
    # Publiques seulement : le logo et les images d'une chaîne PRIVÉE ne sont
    # lisibles que de ses abonnés (voir `_channel_readable`).
    for channel in db.query(Channel).filter(Channel.avatar_media_id == asset.id).all():
        if _channel_readable(db, channel, user_id):
            return True
    for post in db.query(ChannelPost).filter(ChannelPost.media_asset_id == asset.id).all():
        if _channel_readable(db, db.query(Channel).filter(Channel.id == post.channel_id).first(), user_id):
            return True

    # Sticker d'un pack PUBLIC — visible de tout utilisateur authentifié,
    # comme les photos du catalogue et les visuels de chaîne, et pour la
    # même raison : le panneau montre le catalogue AVANT le moindre envoi,
    # donc il n'existe encore aucun message pour justifier l'accès. Un
    # sticker de pack personnel n'est pas concerné : celui qui le reçoit y
    # accède par la branche « message » plus haut.
    #
    # APRÈS les avatars et les chaînes, délibérément : un sticker n'est
    # téléchargé qu'une fois par appareil (le fichier est ensuite en cache
    # local), alors qu'un avatar se redemande bien plus souvent. Placée
    # plus haut, cette requête aurait été payée par chacun d'eux.
    if sticker_service.is_public_sticker_media(db, asset.id):
        return True

    # ── Spark ─────────────────────────────────────────────────────────────────
    #
    # Trois médias, trois règles différentes, et aucune ne se déduit des
    # autres. Sans elles, la photo d'un profil, le vocal d'un Super Spark et
    # celui d'une salle d'entrée n'étaient lisibles que par CELUI QUI LES A
    # ENVOYÉS — c'est-à-dire par la seule personne qui n'en a pas besoin.

    # La photo d'une fiche Spark : visible de qui est sur Spark, et de
    # personne d'autre. Le flux montre des profils à 5 km ; refaire ce calcul
    # ici coûterait une requête géographique par image, et casserait les
    # cartes déjà affichées dès que quelqu'un change d'intention. La borne
    # est donc l'APPARTENANCE au module : quelqu'un qui a ouvert Spark a
    # accepté d'y être vu, et un utilisateur ordinaire de Pokou ne peut pas
    # parcourir des photos de rencontre.
    spark_photo = db.query(SparkPhoto).filter(SparkPhoto.media_asset_id == asset.id).first()
    if spark_photo is not None:
        viewer_has_spark = (
            db.query(SparkProfile.id).filter(SparkProfile.user_id == user_id).first()
        )
        return viewer_has_spark is not None

    # Le vocal d'un Super Spark : son destinataire, et lui seul. C'est ce
    # qu'il a payé, et le destinataire doit l'écouter avant de trancher.
    spark_voice = db.query(SparkLike).filter(SparkLike.voice_media_id == asset.id).first()
    if spark_voice is not None:
        return user_id in {spark_voice.from_user_id, spark_voice.to_user_id}

    # Un vocal de Salle d'Entrée : les deux du match, et personne d'autre.
    # Dix minutes de conversation privée n'ont pas à survivre au-delà de ceux
    # qui les ont tenues.
    room_media = (
        db.query(SparkRoomMessage)
        .filter(SparkRoomMessage.media_asset_id == asset.id)
        .first()
    )
    if room_media is not None:
        match = db.query(SparkMatch).filter(SparkMatch.id == room_media.match_id).first()
        return match is not None and user_id in {match.low_user_id, match.high_user_id}

    # ── Publication d'un salon VIP ────────────────────────────────────────────
    # Réservée aux abonnés EN COURS et au créateur. Sans cette branche, le
    # texte d'une publication passerait le verrou du salon mais son image
    # reviendrait cassée ; avec une règle trop large, on paierait pour un
    # contenu que tout le monde peut déjà voir par /media/{id}.
    vip_post = db.query(VipPost).filter(VipPost.media_asset_id == asset.id).first()
    if vip_post is not None:
        room = db.query(VipRoom).filter(VipRoom.id == vip_post.room_id).first()
        if room is not None:
            if room.owner_id == user_id:
                return True
            active = (
                db.query(VipSubscription)
                .filter(
                    VipSubscription.room_id == room.id,
                    VipSubscription.subscriber_id == user_id,
                    VipSubscription.expires_at > datetime.utcnow(),
                )
                .first()
            )
            if active is not None:
                return True

    # ── Photos de GROUPE et de COMMUNAUTÉ ─────────────────────────────────────
    # Réservées à leurs membres, elles : contrairement à une chaîne, un
    # groupe et une communauté ne sont pas publics. Même règle que leur
    # contenu — tant qu'on y est, on la voit.
    for group in db.query(Group).filter(Group.avatar_media_id == asset.id).all():
        if db.query(GroupMember).filter(
            GroupMember.group_id == group.id, GroupMember.user_id == user_id
        ).first():
            return True
    for community in db.query(Community).filter(Community.avatar_media_id == asset.id).all():
        if db.query(CommunityMember).filter(
            CommunityMember.community_id == community.id, CommunityMember.user_id == user_id
        ).first():
            return True

    # ── Pièce d'identité d'un dossier de vérification vendeur ────────────────
    #
    # EN DERNIER, et c'est voulu : c'est le cas le plus rare de toute la
    # fonction — quelques dossiers, contre des milliers d'images de
    # conversation. Placée en tête, sa requête aurait été payée par CHAQUE
    # ouverture de média, sur une route qui est parmi les plus sollicitées de
    # l'application.
    #
    # C'est aussi la seule branche qui repose sur un RÔLE et non sur une
    # relation, et ça se justifie dans les deux sens :
    #
    # - sans elle, l'équipe recevait un 404 en ouvrant le document qu'elle
    #   doit examiner. L'écran d'administration listait les dossiers sans
    #   permettre de les instruire — une file d'attente qu'on peut voir mais
    #   pas traiter ;
    # - l'ouvrir à tout le monde serait bien pire : ce sont des cartes
    #   d'identité. L'accès est donc doublement borné — aux rôles d'équipe, et
    #   au seul document effectivement rattaché à un dossier.
    identity_application = (
        db.query(SellerVerificationApplication)
        .filter(SellerVerificationApplication.identity_media_id == asset.id)
        .first()
    )
    if identity_application is not None:
        reviewer = db.query(User).filter(User.id == user_id).first()
        return reviewer is not None and reviewer.role in _TEAM_ROLES

    return False


class DirectUploadRequest(BaseModel):
    """Ce que le client annonce AVANT de déposer.

    `mime_type` et `message_type` servent à borner l'URL — ils ne sont pas
    crus sur parole : `confirm_direct_upload` revérifie ce qui a réellement
    été déposé."""

    message_type: str
    mime_type: str
    filename: Optional[str] = None


class DirectUploadConfirm(BaseModel):
    storage_path: str
    message_type: str
    filename: Optional[str] = None


@router.post("/direct-upload")
async def open_direct_upload(
    payload: DirectUploadRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Ouvre un dépôt DIRECT vers le stockage objet.

    Le fichier ne transite plus par l'API : elle autorise, elle ne
    transporte pas. Voir services/media_storage.py::prepare_direct_upload
    pour ce que l'URL borne — la clé, le type, la taille, l'expiration.

    `POST /media` continue d'exister pour les petits fichiers et pour les
    clients qui ne connaissent pas encore ce chemin. Les deux coexistent le
    temps que le parc se renouvelle.
    """
    try:
        parsed_type = MessageType(payload.message_type.upper())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Type de message inconnu") from exc

    try:
        return media_storage.prepare_direct_upload(
            uploader_id=current_user["user_id"],
            message_type=parsed_type,
            mime_type=payload.mime_type,
            filename=payload.filename,
        )
    except media_storage.MediaTypeNotAllowedError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    except media_storage.MediaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/direct-upload/confirm")
async def confirm_direct_upload(
    payload: DirectUploadConfirm,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Enregistre un objet déposé, après l'avoir VÉRIFIÉ auprès du stockage.

    Idempotent : une confirmation rejouée — réseau lent, réessai du client —
    rend le même média plutôt que d'en créer un second pour le même objet.
    """
    try:
        parsed_type = MessageType(payload.message_type.upper())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Type de message inconnu") from exc

    try:
        asset = media_storage.confirm_direct_upload(
            db,
            uploader_id=current_user["user_id"],
            storage_path=payload.storage_path,
            message_type=parsed_type,
            original_filename=payload.filename,
        )
    except media_storage.MediaTooLargeError as exc:
        raise HTTPException(status_code=413, detail=str(exc)) from exc
    except media_storage.MediaTypeNotAllowedError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    except media_storage.MediaError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return {
        "id": asset.id,
        "mime_type": asset.mime_type,
        "size_bytes": asset.size_bytes,
        "original_filename": asset.original_filename,
    }


@router.get("/{media_id}/download-url")
async def media_download_url(
    media_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Une URL de lecture directe, pour ne pas faire transiter le fichier.

    Le contrôle d'accès est le MÊME que celui de `GET /media/{id}` — c'est
    `_can_access` qui décide, et rien d'autre. Sans lui, cette route serait
    un contournement de toutes les règles patiemment posées là-bas : vue
    unique, appartenance au groupe, confidentialité des statuts.
    """
    asset = db.query(MediaAsset).filter(MediaAsset.id == media_id).first()
    if not asset or not _can_access(db, asset, current_user["user_id"]):
        raise HTTPException(status_code=404, detail="Fichier introuvable")
    if asset.storage_backend != media_storage.BACKEND_OBJECT:
        # Média stocké sur disque local : il n'y a pas d'URL à signer, le
        # client doit passer par GET /media/{id}.
        raise HTTPException(status_code=409, detail="Ce fichier n'est pas en stockage objet")

    try:
        return {"url": object_storage.presigned_get(asset.storage_path)}
    except object_storage.PresignError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


#: Le contenu d'un média ne change JAMAIS pour un identifiant donné — un
#: nouveau fichier reçoit un nouvel id. On peut donc dire au client de le
#: garder pour de bon. `private` parce que l'accès dépend de qui demande :
#: aucun cache partagé ne doit conserver la photo d'un statut privé.
_CACHE_MEDIA = "private, max-age=31536000, immutable"


@router.get("/{media_id}")
async def get_media(
    media_id: int,
    w: Optional[int] = Query(
        None,
        description="Largeur de vignette souhaitée (96, 320 ou 1080). "
        "Toute autre valeur est ignorée et l'original est servi.",
    ),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Le fichier, ou sa VIGNETTE quand le client dit à quelle taille il
    l'affiche.

    Jusqu'ici l'original partait toujours, quelle que soit la place qu'il
    allait occuper : une photo de deux à cinq méga-octets pour une pastille
    de contact de 40 points. Une liste de contacts téléchargeait des dizaines
    de méga-octets pour afficher quelques dizaines de kilo-octets.

    `?w=` ne peut pas échouer : une largeur inconnue, un format qui ne se
    redimensionne pas, une image déjà plus petite — dans tous ces cas on
    sert l'original, exactement comme avant.
    """
    asset = db.query(MediaAsset).filter(MediaAsset.id == media_id).first()
    if not asset or not _can_access(db, asset, current_user["user_id"]):
        raise HTTPException(status_code=404, detail="Fichier introuvable")

    largeur = thumbnail_service.largeur_valide(w)
    if largeur and thumbnail_service.peut_etre_redimensionne(asset.mime_type):
        vignette = _vignette(asset, largeur)
        if vignette is not None:
            return FileResponse(
                vignette,
                media_type="image/jpeg",
                headers={"Cache-Control": _CACHE_MEDIA},
            )

    if media_storage.uses_object_storage(asset):
        try:
            chunks, content_length = media_storage.open_stream(asset)
        except media_storage.MediaStorageUnavailableError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        # Content-Length issu du stockage, pas de asset.size_bytes : c'est
        # l'objet réellement servi qui fait foi.
        headers = {"Cache-Control": _CACHE_MEDIA}
        if content_length is not None:
            headers["Content-Length"] = str(content_length)
        return StreamingResponse(chunks, media_type=asset.mime_type, headers=headers)

    path = media_storage.resolve_path(asset)
    if not path:
        raise HTTPException(status_code=404, detail="Fichier introuvable")

    return FileResponse(
        path, media_type=asset.mime_type, headers={"Cache-Control": _CACHE_MEDIA}
    )


def _vignette(asset: MediaAsset, largeur: int):
    """Le chemin de la vignette, en lisant l'original seulement si besoin.

    La lecture des octets sources est PARESSEUSE : une vignette déjà
    fabriquée est servie sans rouvrir l'original — ce qui, en stockage
    objet, éviterait autrement un aller-retour réseau complet pour rien,
    c'est-à-dire exactement le coût qu'on cherche à supprimer.
    """
    from pathlib import Path

    deja = thumbnail_service._chemin_vignette(asset.id, largeur)
    if deja.exists():
        return deja

    try:
        if media_storage.uses_object_storage(asset):
            chunks, _ = media_storage.open_stream(asset)
            source = b"".join(chunks)
        else:
            chemin: Optional[Path] = media_storage.resolve_path(asset)
            if not chemin:
                return None
            source = chemin.read_bytes()
    except (media_storage.MediaStorageUnavailableError, OSError):
        return None

    return thumbnail_service.vignette(asset, largeur, source)
