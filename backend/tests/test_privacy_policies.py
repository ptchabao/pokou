"""Les règles de confidentialité, appliquées côté SERVEUR.

La tentation, sur ce chantier, est de poser huit interrupteurs et de laisser
le client cacher ce qu'il faut. Ce serait une fuite avec une case à cocher
devant : un champ masqué côté application se retrouve tôt ou tard dans un
cache, une capture de requête, ou un écran qui a oublié la règle.

Ce fichier vérifie donc une seule chose, sous huit angles : **la donnée
interdite NE PART PAS**. Pas « n'est pas affichée » — ne part pas.

Deux propriétés de conception y sont aussi verrouillées :

- **un défaut qui ne change rien.** Une migration de confidentialité qui
  modifie ce que les gens partagent sans qu'ils l'aient demandé est une
  faute, dans un sens comme dans l'autre ;
- **`null` et non 403** sur les champs masqués. Un refus explicite
  apprendrait au demandeur que quelqu'un se cache — exactement ce qu'il ne
  veut pas dire. L'exception est l'ajout à un groupe, qui est une ACTION :
  celui qui la tente doit savoir qu'elle a échoué, sinon il recommence.
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import PrivacyAudience, User
from app.services.auth import otp_service
from app.services.privacy import privacy_service

TEST_DATABASE_URL = "sqlite:///./test_privacy_policies.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def client():
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as envoi:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", envoi.call_args.args[2]).group(1)
    body = client.post(
        "/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}
    ).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _ajouter_contact(client, entetes, phone):
    return client.post(
        "/api/v1/contacts", json={"phone": phone, "display_name": "X"}, headers=entetes
    )


def _regler(user_id: int, **regles):
    with TestingSessionLocal() as db:
        user = db.query(User).filter(User.id == user_id).one()
        for champ, valeur in regles.items():
            setattr(user, champ, valeur)
        db.commit()


# ── Le défaut ne change rien ──────────────────────────────────────────────


def test_par_defaut_tout_est_visible_par_ses_contacts(client):
    """Le comportement d'avant les règles, à l'identique.

    Pokou montrait déjà l'avatar et la présence aux contacts, et à eux
    seuls. Le défaut `CONTACTS` reproduit exactement ça : personne ne voit
    son partage changer sans l'avoir demandé.
    """
    entetes_a, id_a = _signup(client, "+22893300001")
    with TestingSessionLocal() as db:
        user = db.query(User).filter(User.id == id_a).one()
        reglages = privacy_service.reglages(user)

    assert reglages["last_seen"] == "CONTACTS"
    assert reglages["online"] == "CONTACTS"
    assert reglages["profile_photo"] == "CONTACTS"
    assert reglages["profile_info"] == "CONTACTS"
    assert reglages["group_membership"] == "CONTACTS"
    assert reglages["group_invites"] == "CONTACTS"
    assert reglages["read_receipts"] is True


# ── « Mes contacts » se lit dans le bon sens ──────────────────────────────


def test_mes_contacts_se_lit_dans_les_deux_sens(client):
    """Ce que « mes contacts » a toujours voulu dire dans Pokou.

    La relation Contact est unidirectionnelle : quelqu'un peut répondre à un
    appel ou à un message sans avoir enregistré son interlocuteur. C'est
    pourquoi `media.py::_is_contact_of` regarde les deux carnets depuis le
    début, et pourquoi cette règle fait de même.

    Une première version ne regardait que le carnet de celui qui se montre.
    Deux tests l'ont immédiatement mise en défaut : la présence disparaissait
    entre deux personnes qui se parlaient, et créer un groupe échouait en 403
    dès qu'un invité n'avait pas ajouté l'organisateur — c'est-à-dire, sur ce
    marché, presque toujours.

    Autrement dit, ce réglage RESSERRAIT le produit sans que personne l'ait
    demandé. Qui veut vraiment restreindre a `NOBODY`, qui est sans
    ambiguïté.
    """
    entetes_a, id_a = _signup(client, "+22893300002")
    entetes_b, id_b = _signup(client, "+22893300003")

    # B ajoute A. A n'a pas ajouté B — un seul carnet suffit.
    _ajouter_contact(client, entetes_b, "+22893300002")

    with TestingSessionLocal() as db:
        assert privacy_service.peut_voir(
            db, id_a, id_b, privacy_service.Aspect.PHOTO_DE_PROFIL
        )
        assert privacy_service.peut_voir(
            db, id_b, id_a, privacy_service.Aspect.PHOTO_DE_PROFIL
        )


def test_un_inconnu_ne_voit_rien(client):
    """Deux personnes sans aucun lien : « mes contacts » les exclut."""
    entetes_a, id_a = _signup(client, "+22893300023")
    entetes_b, id_b = _signup(client, "+22893300024")
    with TestingSessionLocal() as db:
        assert not privacy_service.peut_voir(
            db, id_a, id_b, privacy_service.Aspect.PHOTO_DE_PROFIL
        )


def test_soi_meme_voit_toujours_tout(client):
    """Un écran de réglages qui masque ce qu'il règle serait absurde."""
    entetes_a, id_a = _signup(client, "+22893300004")
    _regler(id_a, privacy_profile_photo=PrivacyAudience.NOBODY)
    with TestingSessionLocal() as db:
        assert privacy_service.peut_voir(
            db, id_a, id_a, privacy_service.Aspect.PHOTO_DE_PROFIL
        )


# ── Ce qui ne doit pas PARTIR ─────────────────────────────────────────────


def test_une_photo_masquee_ne_part_pas_dans_le_profil(client):
    entetes_a, id_a = _signup(client, "+22893300005")
    entetes_b, id_b = _signup(client, "+22893300006")
    _ajouter_contact(client, entetes_a, "+22893300006")
    _ajouter_contact(client, entetes_b, "+22893300005")

    _regler(id_b, privacy_profile_photo=PrivacyAudience.NOBODY)

    profil = client.get(f"/api/v1/users/{id_b}/profile", headers=entetes_a)
    # 200 et non 403 : un refus apprendrait à A que B se cache.
    assert profil.status_code == 200, profil.text
    assert profil.json()["avatar"] is None
    assert profil.json()["avatar_media_id"] is None


def test_des_infos_masquees_ne_partent_pas(client):
    entetes_a, id_a = _signup(client, "+22893300007")
    entetes_b, id_b = _signup(client, "+22893300008")
    _ajouter_contact(client, entetes_a, "+22893300008")
    _ajouter_contact(client, entetes_b, "+22893300007")

    client.put(
        "/api/v1/users/me/profile", json={"about": "Grossiste à Lomé"}, headers=entetes_b
    )
    avant = client.get(f"/api/v1/users/{id_b}/profile", headers=entetes_a).json()
    assert avant["about"] == "Grossiste à Lomé"

    _regler(id_b, privacy_profile_info=PrivacyAudience.NOBODY)
    apres = client.get(f"/api/v1/users/{id_b}/profile", headers=entetes_a).json()
    assert apres["about"] is None


def test_en_ligne_et_derniere_activite_se_reglent_separement(client):
    """Deux informations, deux règles.

    « En ligne maintenant » et « vu à 23 h 14 » ne disent pas la même chose :
    on peut vouloir qu'un correspondant sache qu'on est joignable à
    l'instant, sans lui apprendre à quelle heure on s'est couché. Les fondre
    aurait obligé à renoncer aux deux pour en cacher une.
    """
    entetes_a, id_a = _signup(client, "+22893300009")
    entetes_b, id_b = _signup(client, "+22893300010")
    _ajouter_contact(client, entetes_a, "+22893300010")
    _ajouter_contact(client, entetes_b, "+22893300009")

    _regler(
        id_b,
        privacy_online=PrivacyAudience.CONTACTS,
        privacy_last_seen=PrivacyAudience.NOBODY,
    )
    reponse = client.get(f"/api/v1/presence/{id_b}", headers=entetes_a)
    assert reponse.status_code == 200, reponse.text
    corps = reponse.json()
    # `is_online` a une réponse (False, personne n'a de WebSocket ouvert en
    # test) ; `last_seen_at` est tu.
    assert corps["last_seen_at"] is None

    # L'inverse : présence masquée, dernière activité permise.
    _regler(
        id_b,
        privacy_online=PrivacyAudience.NOBODY,
        privacy_last_seen=PrivacyAudience.CONTACTS,
    )
    corps = client.get(f"/api/v1/presence/{id_b}", headers=entetes_a).json()
    # `null` et non `false` : « je ne dis pas » n'est pas « hors ligne ».
    assert corps["is_online"] is None


def test_une_presence_masquee_est_nulle_et_jamais_false(client):
    """La nuance porte tout le comportement du point vert.

    Renvoyer `false` ferait dessiner « hors ligne » — une affirmation. Le
    client doit pouvoir distinguer « cette personne est hors ligne » de
    « cette personne ne le dit pas », et ne dessiner le point que sur un oui
    franc.
    """
    entetes_a, id_a = _signup(client, "+22893300011")
    entetes_b, id_b = _signup(client, "+22893300012")
    _ajouter_contact(client, entetes_a, "+22893300012")
    _ajouter_contact(client, entetes_b, "+22893300011")

    _regler(id_b, privacy_online=PrivacyAudience.NOBODY)
    corps = client.get(f"/api/v1/presence/{id_b}", headers=entetes_a).json()
    assert corps["is_online"] is None
    assert corps["is_online"] is not False


# ── Les invitations de groupe : une ACTION, donc un refus explicite ───────


def test_personne_ne_peut_m_ajouter_si_je_l_ai_decide(client):
    entetes_a, id_a = _signup(client, "+22893300013")
    entetes_b, id_b = _signup(client, "+22893300014")
    _ajouter_contact(client, entetes_a, "+22893300014")

    _regler(id_b, privacy_group_invites=PrivacyAudience.NOBODY)

    reponse = client.post(
        "/api/v1/groups",
        json={"name": "Chantier", "member_user_ids": [id_b]},
        headers=entetes_a,
    )
    # 403 ASSUMÉ, contrairement aux champs masqués : ajouter quelqu'un est
    # une action, et celui qui la tente doit savoir qu'elle a échoué — sinon
    # il croit la personne ajoutée.
    assert reponse.status_code == 403, reponse.text


def test_autoriser_tout_le_monde_ouvre_vraiment(client):
    entetes_a, id_a = _signup(client, "+22893300015")
    entetes_b, id_b = _signup(client, "+22893300016")
    _ajouter_contact(client, entetes_a, "+22893300016")

    _regler(id_b, privacy_group_invites=PrivacyAudience.EVERYONE)
    reponse = client.post(
        "/api/v1/groups",
        json={"name": "Chantier", "member_user_ids": [id_b]},
        headers=entetes_a,
    )
    assert reponse.status_code in (200, 201), reponse.text


# ── La route de réglages ──────────────────────────────────────────────────


def test_un_envoi_partiel_ne_remet_pas_les_autres_a_zero(client):
    """C'est le défaut qui rouvre en silence ce que quelqu'un avait fermé.

    L'écran change une ligne à la fois. Si un PUT partiel remettait les cinq
    autres à leur défaut, masquer sa photo puis régler autre chose la
    redécouvrirait — sans que personne ne le remarque avant des semaines.
    """
    entetes, user_id = _signup(client, "+22893300017")

    client.put(
        "/api/v1/account-privacy/privacy",
        json={"profile_photo": "NOBODY"},
        headers=entetes,
    )
    apres = client.put(
        "/api/v1/account-privacy/privacy",
        json={"last_seen": "EVERYONE"},
        headers=entetes,
    )
    assert apres.status_code == 200, apres.text
    assert apres.json()["profile_photo"] == "NOBODY"
    assert apres.json()["last_seen"] == "EVERYONE"


def test_une_valeur_inconnue_est_refusee_sans_rien_ecrire(client):
    entetes, user_id = _signup(client, "+22893300018")
    client.put(
        "/api/v1/account-privacy/privacy",
        json={"profile_photo": "NOBODY"},
        headers=entetes,
    )
    mauvais = client.put(
        "/api/v1/account-privacy/privacy",
        json={"profile_photo": "MES_AMIS"},
        headers=entetes,
    )
    assert mauvais.status_code == 422
    # Et le réglage précédent est intact : un client fautif ne doit pas
    # faire perdre ce qui était en place.
    lu = client.get("/api/v1/account-privacy/privacy", headers=entetes).json()
    assert lu["profile_photo"] == "NOBODY"


def test_l_ancienne_route_des_accuses_de_lecture_marche_toujours(client):
    """Un client déjà déployé ne doit pas cesser de fonctionner."""
    entetes, user_id = _signup(client, "+22893300019")
    assert client.put(
        "/api/v1/account-privacy/read-receipts",
        json={"enabled": False},
        headers=entetes,
    ).status_code == 200
    lu = client.get("/api/v1/account-privacy/privacy", headers=entetes).json()
    assert lu["read_receipts"] is False


# ── Le repli du service ───────────────────────────────────────────────────


def test_une_regle_absente_retombe_sur_le_plus_restrictif(client):
    """Une ligne écrite avant la migration ne doit pas tout ouvrir.

    Se tromper vers « personne ne voit » se corrige d'un réglage ; se
    tromper vers « tout le monde voit » ne se rattrape pas.
    """

    class SansRegles:
        id = 999

    assert (
        privacy_service.regle(SansRegles(), privacy_service.Aspect.PHOTO_DE_PROFIL)
        is PrivacyAudience.CONTACTS
    )


def test_le_filtrage_en_lot_donne_le_meme_resultat_qu_un_par_un(client):
    """Deux chemins, une seule vérité.

    Le lot existe pour qu'une liste de trente personnes n'interroge pas la
    base trente fois. S'il divergeait du chemin unitaire, une liste
    montrerait ce qu'une fiche cache.
    """
    entetes_a, id_a = _signup(client, "+22893300020")
    entetes_b, id_b = _signup(client, "+22893300021")
    entetes_c, id_c = _signup(client, "+22893300022")

    _ajouter_contact(client, entetes_b, "+22893300020")  # lien A↔B, dans un sens
    _regler(id_c, privacy_profile_photo=PrivacyAudience.EVERYONE)

    with TestingSessionLocal() as db:
        lot = privacy_service.filtrer_visibles(
            db, [id_a, id_b, id_c], id_a, privacy_service.Aspect.PHOTO_DE_PROFIL
        )
        un_par_un = {
            uid
            for uid in (id_a, id_b, id_c)
            if privacy_service.peut_voir(
                db, uid, id_a, privacy_service.Aspect.PHOTO_DE_PROFIL
            )
        }
    assert lot == un_par_un
    assert id_a in lot  # soi-même
    assert id_b in lot  # B a A dans ses contacts
    assert id_c in lot  # C montre à tout le monde


# ── Appartenance aux groupes ──────────────────────────────────────────────
#
# La distinction qui porte tout ce bloc : **la confidentialité ne doit pas
# casser le fonctionnement d'un groupe**. Les membres d'un groupe continuent
# de se connaître entre eux quoi qu'il arrive ; ce qui se règle, c'est
# l'AGRÉGAT « voici tous les groupes que cette personne partage avec vous »,
# remis sans qu'on l'ait demandé.


def _groupe_partage(client, entetes_a, id_b, entetes_b) -> int:
    """Un groupe dont A et B sont tous deux membres."""
    groupe = client.post(
        "/api/v1/groups",
        json={"name": "Chantier", "member_user_ids": [id_b]},
        headers=entetes_a,
    )
    assert groupe.status_code in (200, 201), groupe.text
    for invitation in client.get(
        "/api/v1/groups/invitations", headers=entetes_b
    ).json()["items"]:
        client.post(
            f"/api/v1/groups/invitations/{invitation['id']}/accept", headers=entetes_b
        )
    return groupe.json()["id"]


def test_les_groupes_en_commun_suivent_la_regle(client):
    entetes_a, id_a = _signup(client, "+22893300030")
    entetes_b, id_b = _signup(client, "+22893300031")
    _ajouter_contact(client, entetes_a, "+22893300031")
    _ajouter_contact(client, entetes_b, "+22893300030")
    _groupe_partage(client, entetes_a, id_b, entetes_b)

    avant = client.get(f"/api/v1/users/{id_b}/profile", headers=entetes_a).json()
    assert len(avant["common_groups"]) == 1

    _regler(id_b, privacy_group_membership=PrivacyAudience.NOBODY)
    apres = client.get(f"/api/v1/users/{id_b}/profile", headers=entetes_a).json()
    # Liste VIDE, pas de 403 ni de clé absente : l'écran lit « aucun groupe
    # en commun », ce qui se comprend sans avoir à distinguer « pas de
    # groupe » de « je n'ai pas le droit de savoir ».
    assert apres["common_groups"] == []


def test_la_regle_ne_casse_pas_le_groupe(client):
    """La propriété la plus importante de cette règle.

    Quelqu'un réglé sur « Personne » reste parfaitement visible DANS les
    groupes qu'il partage : sinon la confidentialité casserait le
    fonctionnement du groupe, ce qui n'aiderait personne. Ce n'est pas un
    membre qu'on cache, c'est un agrégat qu'on ne sert plus.
    """
    entetes_a, id_a = _signup(client, "+22893300032")
    entetes_b, id_b = _signup(client, "+22893300033")
    _ajouter_contact(client, entetes_a, "+22893300033")
    _ajouter_contact(client, entetes_b, "+22893300032")
    group_id = _groupe_partage(client, entetes_a, id_b, entetes_b)

    _regler(id_b, privacy_group_membership=PrivacyAudience.NOBODY)

    groupe = client.get(f"/api/v1/groups/{group_id}", headers=entetes_a).json()
    membres = {m["user_id"] for m in groupe["members"]}
    assert id_b in membres, "un membre reste un membre, quelle que soit sa règle"

    # Et il continue de recevoir les messages du groupe.
    client.post(
        f"/api/v1/groups/{group_id}/messages",
        json={"content": "Rendez-vous à 8 h"},
        headers=entetes_a,
    )
    lu = client.get(f"/api/v1/groups/{group_id}/messages", headers=entetes_b)
    assert lu.status_code == 200, lu.text
