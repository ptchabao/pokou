"""Les stickers : packs, favoris, récents, recherche, suggestions.

Ce que ces tests protègent tient à quelques distinctions qui ne se lisent
pas dans les signatures — un favori n'est pas un récent, suggérer n'est pas
chercher, et désinstaller n'est pas supprimer.
"""
from datetime import datetime

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models import MediaAsset, Sticker, StickerFavorite, StickerPack, StickerRecent, User, UserStickerPack
from app.services.media import sticker_service as svc

TEST_DATABASE_URL = "sqlite:///./test_stickers.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
Base.metadata.create_all(bind=engine)
Session = sessionmaker(bind=engine)


@pytest.fixture
def db():
    session = Session()
    # `StickerFavorite` était OUBLIÉ, et SQLite réattribue les identifiants
    # supprimés : un favori laissé par le test précédent portait le même
    # `sticker_id` que le sticker du suivant, qui croyait donc partir d'une
    # ardoise vierge.
    for modele in (
        StickerRecent,
        StickerFavorite,
        Sticker,
        UserStickerPack,
        StickerPack,
        MediaAsset,
        User,
    ):
        session.query(modele).delete()
    session.commit()
    yield session
    session.close()


@pytest.fixture
def alice(db):
    row = User(phone="+22890300001", is_active=True)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _media(db, uploader_id):
    row = MediaAsset(
        uploader_id=uploader_id,
        storage_backend="local",
        storage_path=f"x/{datetime.utcnow().timestamp()}",
        mime_type="image/webp",
        size_bytes=1024,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _pack_officiel(db, nom="Réactions", emojis="😂", mots="rire drole"):
    pack = StickerPack(name=nom, slug=nom.lower().replace(" ", "-"), owner_user_id=None)
    db.add(pack)
    db.commit()
    db.refresh(pack)
    utilisateur = db.query(User).first()
    media = _media(db, uploader_id=utilisateur.id)
    sticker = Sticker(
        pack_id=pack.id, media_asset_id=media.id, emoji_tags=emojis, keywords=mots
    )
    db.add(sticker)
    db.commit()
    db.refresh(sticker)
    return pack, sticker


# ── Installation ─────────────────────────────────────────────────────────


def test_installer_un_pack_puis_le_retrouver(db, alice):
    pack, _ = _pack_officiel(db)

    assert svc.install(db, alice.id, pack.id) is True
    packs = svc.installed_packs(db, alice.id)

    assert [p["id"] for p in packs] == [pack.id]
    assert packs[0]["installed"] is True
    assert packs[0]["sticker_count"] == 1


def test_installer_deux_fois_ne_duplique_pas(db, alice):
    pack, _ = _pack_officiel(db)
    svc.install(db, alice.id, pack.id)
    svc.install(db, alice.id, pack.id)

    assert len(svc.installed_packs(db, alice.id)) == 1


def test_desinstaller_ne_SUPPRIME_pas_le_pack(db, alice):
    # D'autres l'ont peut-être installé. Retirer de sa liste et supprimer
    # sont deux gestes différents.
    pack, _ = _pack_officiel(db)
    svc.install(db, alice.id, pack.id)

    svc.uninstall(db, alice.id, pack.id)

    assert svc.installed_packs(db, alice.id) == []
    assert db.query(StickerPack).filter(StickerPack.id == pack.id).first() is not None


def test_l_ordre_choisi_est_respecte(db, alice):
    p1, _ = _pack_officiel(db, "Un")
    p2, _ = _pack_officiel(db, "Deux")
    svc.install(db, alice.id, p1.id)
    svc.install(db, alice.id, p2.id)

    svc.reorder(db, alice.id, [p2.id, p1.id])

    assert [p["id"] for p in svc.installed_packs(db, alice.id)] == [p2.id, p1.id]


def test_un_pack_desinstalle_entre_temps_ne_casse_pas_le_rangement(db, alice):
    # Une liste envoyée depuis un écran ouvert depuis longtemps peut citer un
    # pack disparu. Faire échouer tout le réordonnancement pour ça serait
    # disproportionné.
    p1, _ = _pack_officiel(db, "Un")
    svc.install(db, alice.id, p1.id)

    svc.reorder(db, alice.id, [999, p1.id])

    assert [p["id"] for p in svc.installed_packs(db, alice.id)] == [p1.id]


# ── Favoris et récents : deux choses différentes ─────────────────────────


def test_un_favori_est_un_choix_pas_une_trace(db, alice):
    """Confondre les deux ferait disparaître un favori dès qu'on s'en sert
    moins."""
    _, sticker = _pack_officiel(db)

    assert svc.toggle_favorite(db, alice.id, sticker.id) is True
    assert [s["id"] for s in svc.favorites(db, alice.id)] == [sticker.id]
    # Un favori n'apparaît PAS dans les récents tant qu'il n'a pas servi.
    assert svc.recents(db, alice.id) == []


def test_le_favori_se_retire_par_la_meme_route(db, alice):
    # Deux routes obligeraient le client à connaître l'état courant avant
    # d'agir, et donc à se tromper dès qu'il est périmé.
    _, sticker = _pack_officiel(db)
    svc.toggle_favorite(db, alice.id, sticker.id)

    assert svc.toggle_favorite(db, alice.id, sticker.id) is False
    assert svc.favorites(db, alice.id) == []


def test_les_recents_suivent_le_dernier_usage(db, alice):
    _, s1 = _pack_officiel(db, "Un", "😂")
    _, s2 = _pack_officiel(db, "Deux", "😢")

    svc.mark_used(db, alice.id, s1.id)
    svc.mark_used(db, alice.id, s2.id)

    assert [s["id"] for s in svc.recents(db, alice.id)] == [s2.id, s1.id]


def test_reutiliser_un_sticker_le_remonte_sans_le_dupliquer(db, alice):
    # Une ligne par (personne, sticker), mise à jour — et non une par envoi :
    # l'historique complet ferait grandir la table à chaque message.
    _, s1 = _pack_officiel(db, "Un", "😂")
    _, s2 = _pack_officiel(db, "Deux", "😢")
    svc.mark_used(db, alice.id, s1.id)
    svc.mark_used(db, alice.id, s2.id)

    svc.mark_used(db, alice.id, s1.id)

    assert [s["id"] for s in svc.recents(db, alice.id)] == [s1.id, s2.id]
    assert db.query(StickerRecent).count() == 2


def test_les_recents_sont_bornes(db, alice):
    """Sans coupe, la table grandit d'une ligne par sticker jamais réutilisé,
    indéfiniment."""
    pack, _ = _pack_officiel(db)
    for i in range(svc.MAX_RECENTS + 6):
        media = _media(db, alice.id)
        s = Sticker(pack_id=pack.id, media_asset_id=media.id)
        db.add(s)
        db.commit()
        db.refresh(s)
        svc.mark_used(db, alice.id, s.id)

    assert db.query(StickerRecent).filter(StickerRecent.user_id == alice.id).count() == svc.MAX_RECENTS


# ── Recherche et suggestions ─────────────────────────────────────────────


def test_la_recherche_trouve_par_mot_par_pack_et_par_emoji(db, alice):
    """Une seule route pour les trois : séparer obligerait l'interface à
    deviner laquelle appeler selon ce qui est tapé."""
    _, sticker = _pack_officiel(db, "Réactions", "😂", "rire drole")

    assert [s["id"] for s in svc.search(db, alice.id, "rire")] == [sticker.id]
    assert [s["id"] for s in svc.search(db, alice.id, "réactions")] == [sticker.id]
    assert [s["id"] for s in svc.search(db, alice.id, "😂")] == [sticker.id]


def test_une_recherche_vide_ne_rend_rien(db, alice):
    _pack_officiel(db)
    assert svc.search(db, alice.id, "   ") == []


def test_suggerer_ne_propose_QUE_ce_qu_on_peut_envoyer(db, alice):
    """La différence avec la recherche. Proposer un sticker d'un pack non
    installé serait une invitation à un échec."""
    pack, sticker = _pack_officiel(db, "Réactions", "😂")

    # Pack non installé : aucune suggestion.
    assert svc.suggest_for_emoji(db, alice.id, "😂") == []

    svc.install(db, alice.id, pack.id)
    assert [s["id"] for s in svc.suggest_for_emoji(db, alice.id, "😂")] == [sticker.id]


def test_une_variante_d_emoji_trouve_quand_meme(db, alice):
    """Les emojis se composent : un pouce peut porter un modificateur de
    teint. Comparer les chaînes brutes ferait manquer 👍🏾 quand le sticker
    est marqué 👍."""
    pack, sticker = _pack_officiel(db, "Bravo", "👍")
    svc.install(db, alice.id, pack.id)

    assert [s["id"] for s in svc.suggest_for_emoji(db, alice.id, "👍🏾")] == [sticker.id]


def test_un_emoji_sans_sticker_ne_propose_rien(db, alice):
    pack, _ = _pack_officiel(db, "Réactions", "😂")
    svc.install(db, alice.id, pack.id)

    assert svc.suggest_for_emoji(db, alice.id, "🐘") == []


# ── Packs personnels ─────────────────────────────────────────────────────


def test_creer_un_pack_personnel_et_y_ajouter_une_photo(db, alice):
    pack = svc.create_personal_pack(db, alice.id, "Mes stickers")
    assert pack is not None

    media = _media(db, alice.id)
    sticker = svc.add_to_personal_pack(db, alice.id, pack.id, media.id, "😀", "moi")

    assert sticker is not None
    db.refresh(pack)
    # La première image devient la couverture : un pack sans vignette est
    # indistinguable des autres dans la liste.
    assert pack.cover_media_id == media.id


def test_on_ne_fabrique_pas_un_sticker_avec_la_photo_d_un_autre(db, alice):
    """Sans ce contrôle, il suffirait de deviner un identifiant de média."""
    autre = User(phone="+22890300002", is_active=True)
    db.add(autre)
    db.commit()
    db.refresh(autre)
    pack = svc.create_personal_pack(db, alice.id, "Mes stickers")
    media_autre = _media(db, autre.id)

    assert svc.add_to_personal_pack(db, alice.id, pack.id, media_autre.id) is None


def test_on_n_ajoute_pas_a_un_pack_qui_n_est_pas_le_sien(db, alice):
    autre = User(phone="+22890300003", is_active=True)
    db.add(autre)
    db.commit()
    db.refresh(autre)
    pack_autre = svc.create_personal_pack(db, autre.id, "Les siens")
    media = _media(db, alice.id)

    assert svc.add_to_personal_pack(db, alice.id, pack_autre.id, media.id) is None


def test_un_pack_personnel_est_borne(db, alice):
    """La limite protège le temps de chargement du panneau et la facture de
    stockage d'un compte qui téléverserait sans fin."""
    pack = svc.create_personal_pack(db, alice.id, "Plein")
    for _ in range(svc.MAX_PERSONAL_STICKERS):
        svc.add_to_personal_pack(db, alice.id, pack.id, _media(db, alice.id).id)

    with pytest.raises(svc.StickerLimitReached):
        svc.add_to_personal_pack(db, alice.id, pack.id, _media(db, alice.id).id)


def test_un_pack_personnel_apparait_sans_installation(db, alice):
    # Faire installer son propre pack serait absurde : on l'a créé.
    pack = svc.create_personal_pack(db, alice.id, "Mes stickers")

    assert pack.id in [p["id"] for p in svc.installed_packs(db, alice.id)]


def test_un_pack_personnel_non_publie_reste_invisible_aux_autres(db, alice):
    autre = User(phone="+22890300004", is_active=True)
    db.add(autre)
    db.commit()
    db.refresh(autre)
    pack = svc.create_personal_pack(db, autre.id, "Privé")
    media = _media(db, autre.id)
    svc.add_to_personal_pack(db, autre.id, pack.id, media.id, keywords="secret")

    assert svc.search(db, alice.id, "secret") == []
    assert svc.install(db, alice.id, pack.id) is False


def test_supprimer_son_pack_emporte_ses_stickers(db, alice):
    pack = svc.create_personal_pack(db, alice.id, "À jeter")
    svc.add_to_personal_pack(db, alice.id, pack.id, _media(db, alice.id).id)

    assert svc.delete_personal_pack(db, alice.id, pack.id) is True
    assert db.query(Sticker).filter(Sticker.pack_id == pack.id).count() == 0


def test_le_slug_reste_unique(db, alice):
    a = svc.create_personal_pack(db, alice.id, "Mes stickers")
    b = svc.create_personal_pack(db, alice.id, "Mes stickers")

    assert a.slug != b.slug


def test_les_accents_sont_deplies_pas_supprimes(db, alice):
    # « Café » doit devenir « cafe » et non « caf », qui resterait
    # cherchable mais absurde.
    pack = svc.create_personal_pack(db, alice.id, "Café")

    assert pack.slug == "cafe"


# ── Le droit d'envoyer, et le droit de voir ──────────────────────────────
#
# Ces tests gardent l'exception la plus délicate du module. Partout ailleurs
# dans Pokou, une pièce jointe doit avoir été téléversée par celui qui
# l'envoie — c'est ce qui empêche de voler le média d'autrui en devinant son
# identifiant. Un sticker doit échapper à cette règle, sans l'ouvrir.


def test_on_peut_envoyer_un_sticker_qu_on_n_a_pas_televerse(db, alice):
    # Le cas normal, et celui qui était cassé : l'image du pack appartient à
    # son auteur. Sans l'exception, `POST /messages` répondait « Pièce
    # jointe introuvable » à CHAQUE sticker.
    proprietaire = User(phone="+22890300777", is_active=True)
    db.add(proprietaire)
    db.commit()
    pack = StickerPack(name="Public", slug="public", owner_user_id=None, is_public=True)
    db.add(pack)
    db.commit()
    media = _media(db, uploader_id=proprietaire.id)
    db.add(Sticker(pack_id=pack.id, media_asset_id=media.id))
    db.commit()

    assert svc.sender_may_attach(db, media.id, alice.id) is True


def test_un_media_ordinaire_ne_devient_pas_envoyable_par_ce_chemin(db, alice):
    # Le garde-fou lui-même : une photo privée de quelqu'un d'autre n'est
    # pas un sticker, et l'exception ne doit pas y toucher.
    autre = User(phone="+22890300888", is_active=True)
    db.add(autre)
    db.commit()
    photo_privee = _media(db, uploader_id=autre.id)

    assert svc.sender_may_attach(db, photo_privee.id, alice.id) is False


def test_le_pack_personnel_d_un_autre_reste_fermé(db, alice):
    # Un pack non public appartenant à quelqu'un d'autre : ses stickers ne
    # sont pas piochables dans le catalogue. Son propriétaire, lui, peut.
    autre = User(phone="+22890300999", is_active=True)
    db.add(autre)
    db.commit()
    pack = StickerPack(
        name="Perso", slug="perso", owner_user_id=autre.id, is_public=False
    )
    db.add(pack)
    db.commit()
    media = _media(db, uploader_id=autre.id)
    db.add(Sticker(pack_id=pack.id, media_asset_id=media.id))
    db.commit()

    assert svc.sender_may_attach(db, media.id, alice.id) is False
    assert svc.sender_may_attach(db, media.id, autre.id) is True


def test_seul_un_pack_public_s_ouvre_au_telechargement(db, alice):
    # `GET /media/{id}` : le panneau montre le catalogue AVANT tout envoi,
    # donc aucun message ne justifie encore l'accès. Un pack personnel, lui,
    # ne s'ouvre que par le message qui porte le sticker.
    public = StickerPack(name="Cat", slug="cat", owner_user_id=None, is_public=True)
    prive = StickerPack(
        name="Mien", slug="mien", owner_user_id=alice.id, is_public=False
    )
    db.add_all([public, prive])
    db.commit()
    media_public = _media(db, uploader_id=alice.id)
    media_prive = _media(db, uploader_id=alice.id)
    db.add_all([
        Sticker(pack_id=public.id, media_asset_id=media_public.id),
        Sticker(pack_id=prive.id, media_asset_id=media_prive.id),
    ])
    db.commit()

    assert svc.is_public_sticker_media(db, media_public.id) is True
    assert svc.is_public_sticker_media(db, media_prive.id) is False


def test_un_sticker_doit_etre_une_image(db):
    # Sans la ligne ajoutée à `_TYPE_PREFIX`, STICKER tombait dans le cas
    # « DOCUMENT », qui accepte tout : on aurait pu déposer un PDF dans un
    # pack et afficher un cadre cassé au milieu des stickers.
    from app.models import MessageType
    from app.services.media.media_storage import MediaTypeNotAllowedError, validate_mime_for_type

    validate_mime_for_type(MessageType.STICKER, "image/webp")
    with pytest.raises(MediaTypeNotAllowedError):
        validate_mime_for_type(MessageType.STICKER, "application/pdf")


# ── Normalisation des emojis ─────────────────────────────────────────────


def test_le_teint_de_peau_ne_change_pas_la_suggestion(db, alice):
    # 👍🏿 et 👍 doivent tomber sur les mêmes stickers. Sans normalisation,
    # chaque variante aurait eu besoin de sa propre étiquette — six par
    # emoji, et autant d'occasions d'en oublier une.
    pack, _ = _pack_officiel(db, nom="Pouces", emojis="👍", mots="bravo")
    svc.install(db, alice.id, pack.id)

    assert svc.suggest_for_emoji(db, alice.id, "👍🏿") != []
    assert svc.suggest_for_emoji(db, alice.id, "👍") != []


def test_un_emoji_composé_reste_trouvable(db, alice):
    # C'était le défaut : l'étiquette était RANGÉE brute et CHERCHÉE
    # normalisée. Une famille porte des joncteurs de largeur nulle que la
    # recherche retire du terme cherché — la sous-chaîne ne correspondait
    # donc jamais, et le sticker était introuvable pour toujours.
    pack = StickerPack(name="Famille", slug="famille", owner_user_id=alice.id)
    db.add(pack)
    db.commit()
    media = _media(db, uploader_id=alice.id)
    svc.add_to_personal_pack(db, alice.id, pack.id, media.id, "👨‍👩‍👧", "famille")

    assert svc.suggest_for_emoji(db, alice.id, "👨‍👩‍👧") != []


# ── Garder un sticker reçu ───────────────────────────────────────────────


def test_garder_un_sticker_recu_le_range_dans_les_siens(db, alice):
    # Le geste demandé : on touche un sticker dans une conversation, on le
    # garde. Son image appartient au créateur du pack, jamais à celui qui
    # l'enregistre — c'est pourquoi `add_to_personal_pack` ne convenait pas.
    auteur = User(phone="+22890301001", is_active=True)
    db.add(auteur)
    db.commit()
    pack = StickerPack(name="Public", slug="pub", owner_user_id=None, is_public=True)
    db.add(pack)
    db.commit()
    media = _media(db, uploader_id=auteur.id)
    db.add(Sticker(pack_id=pack.id, media_asset_id=media.id, emoji_tags="😂", keywords="rire"))
    db.commit()

    garde = svc.save_received(db, alice.id, media.id)

    assert garde is not None
    # MÊME média : dupliquer le fichier ferait une copie par personne qui
    # garde le même sticker, pour un contenu identique à l'octet près.
    assert garde.media_asset_id == media.id
    # Et les étiquettes suivent, sinon le sticker disparaîtrait de la
    # recherche en changeant de pack.
    assert garde.emoji_tags == "😂"
    assert garde.keywords == "rire"


def test_un_sticker_garde_devient_envoyable(db, alice):
    # Tout l'intérêt : une fois dans SON pack personnel, il part comme
    # n'importe quel autre, sans exception supplémentaire côté envoi.
    auteur = User(phone="+22890301002", is_active=True)
    db.add(auteur)
    db.commit()
    pack = StickerPack(name="Perso", slug="perso-autre", owner_user_id=auteur.id)
    db.add(pack)
    db.commit()
    media = _media(db, uploader_id=auteur.id)
    db.add(Sticker(pack_id=pack.id, media_asset_id=media.id))
    db.commit()

    # Avant : le pack de quelqu'un d'autre, non public — refusé.
    assert svc.sender_may_attach(db, media.id, alice.id) is False

    svc.save_received(db, alice.id, media.id)

    assert svc.sender_may_attach(db, media.id, alice.id) is True


def test_garder_deux_fois_ne_duplique_pas(db, alice):
    # Un double appui ne doit pas produire deux vignettes identiques.
    auteur = User(phone="+22890301003", is_active=True)
    db.add(auteur)
    db.commit()
    pack = StickerPack(name="Public", slug="pub2", owner_user_id=None, is_public=True)
    db.add(pack)
    db.commit()
    media = _media(db, uploader_id=auteur.id)
    db.add(Sticker(pack_id=pack.id, media_asset_id=media.id))
    db.commit()

    premier = svc.save_received(db, alice.id, media.id)
    second = svc.save_received(db, alice.id, media.id)

    assert premier.id == second.id
    mes_packs = svc.installed_packs(db, alice.id)
    perso = [p for p in mes_packs if p["is_personal"]]
    assert len(perso) == 1
    assert perso[0]["sticker_count"] == 1


def test_une_photo_ordinaire_ne_se_range_pas_dans_les_stickers(db, alice):
    # Le garde-fou : cette route ne doit pas devenir un moyen de ranger
    # n'importe quelle image reçue dans ses stickers.
    autre = User(phone="+22890301004", is_active=True)
    db.add(autre)
    db.commit()
    photo = _media(db, uploader_id=autre.id)

    with pytest.raises(svc.StickerNotReachable):
        svc.save_received(db, alice.id, photo.id)


def test_le_pack_personnel_plein_refuse_un_sticker_de_plus(db, alice):
    # La limite protège le temps de chargement du panneau et la facture de
    # stockage. Elle doit valoir pour ce chemin comme pour les autres.
    pack = StickerPack(name="Mien", slug="mien-plein", owner_user_id=alice.id)
    db.add(pack)
    db.commit()
    for _ in range(svc.MAX_PERSONAL_STICKERS):
        db.add(Sticker(pack_id=pack.id, media_asset_id=_media(db, alice.id).id))
    db.commit()

    public = StickerPack(name="Public", slug="pub3", owner_user_id=None, is_public=True)
    db.add(public)
    db.commit()
    media = _media(db, uploader_id=alice.id)
    db.add(Sticker(pack_id=public.id, media_asset_id=media.id))
    db.commit()

    with pytest.raises(svc.StickerLimitReached):
        svc.save_received(db, alice.id, media.id)


def test_un_sticker_garde_APPARAIT_dans_ses_stickers(db, alice):
    """La vérification de bout en bout : après enregistrement, il est là.

    Ranger la ligne en base ne suffit pas — encore faut-il que
    `installed_packs`, qui alimente le panneau, la rende. C'est le seul
    test qui relie le geste au résultat visible.
    """
    auteur = User(phone="+22890301010", is_active=True)
    db.add(auteur)
    db.commit()
    pack = StickerPack(name="Public", slug="pub-vue", owner_user_id=None, is_public=True)
    db.add(pack)
    db.commit()
    media = _media(db, uploader_id=auteur.id)
    db.add(Sticker(pack_id=pack.id, media_asset_id=media.id, emoji_tags="🎉"))
    db.commit()

    # Avant : alice n'a aucun pack, son panneau est vide.
    assert svc.installed_packs(db, alice.id) == []

    garde = svc.save_received(db, alice.id, media.id)

    # Après : un pack personnel, avec ce sticker dedans.
    packs = svc.installed_packs(db, alice.id)
    assert len(packs) == 1
    perso = packs[0]
    assert perso["is_personal"] is True
    assert perso["sticker_count"] == 1
    assert [s["id"] for s in perso["stickers"]] == [garde.id]
    assert perso["stickers"][0]["media_id"] == media.id
    # La couverture est posée : sans elle, l'onglet du panneau serait une
    # vignette vide, indistinguable des autres dans la barre.
    assert perso["cover_media_id"] == media.id


def test_un_second_sticker_garde_rejoint_le_meme_pack(db, alice):
    # Sans quoi chaque enregistrement créerait un pack, et la barre
    # d'onglets du panneau deviendrait illisible au bout de cinq stickers.
    auteur = User(phone="+22890301011", is_active=True)
    db.add(auteur)
    db.commit()
    pack = StickerPack(name="Public", slug="pub-deux", owner_user_id=None, is_public=True)
    db.add(pack)
    db.commit()
    premier = _media(db, uploader_id=auteur.id)
    second = _media(db, uploader_id=auteur.id)
    db.add_all([
        Sticker(pack_id=pack.id, media_asset_id=premier.id),
        Sticker(pack_id=pack.id, media_asset_id=second.id),
    ])
    db.commit()

    svc.save_received(db, alice.id, premier.id)
    svc.save_received(db, alice.id, second.id)

    packs = svc.installed_packs(db, alice.id)
    assert len(packs) == 1
    assert packs[0]["sticker_count"] == 2
