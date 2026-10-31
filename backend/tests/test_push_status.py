from unittest.mock import MagicMock, patch

import pytest

from app.services.notifications import push_service


@pytest.fixture(autouse=True)
def _reset_firebase_app_cache():
    """_get_firebase_app() memoizes in module globals — without resetting
    these between tests, whichever case runs first would "stick" for the
    rest of the suite."""
    push_service._firebase_app = None
    push_service._firebase_init_failed = False
    yield
    push_service._firebase_app = None
    push_service._firebase_init_failed = False


def _settings(fcm_enabled=False, firebase_credentials_path="", firebase_credentials_json=""):
    """Les TROIS réglages sont posés explicitement, y compris à vide.

    Un MagicMock fabrique ses attributs à la demande, et un attribut fabriqué
    est VRAI : quand le code a gagné l'option `firebase_credentials_json`
    (le secret en variable d'environnement, pour Dokploy), le faux la
    satisfaisait tout seul et le service partait sur ce chemin-là. Le test
    échouait alors sans que rien ne soit cassé — il décrivait un réglage
    qu'il n'avait pas choisi."""
    settings = MagicMock()
    settings.fcm_enabled = fcm_enabled
    settings.firebase_credentials_path = firebase_credentials_path
    settings.firebase_credentials_json = firebase_credentials_json
    return settings


def test_push_status_reports_disabled_by_default():
    with patch.object(push_service, "get_settings", return_value=_settings(fcm_enabled=False)):
        message = push_service.push_status_message()
    assert "désactivé" in message
    assert "FCM_ENABLED=false" in message


def test_push_status_reports_missing_credentials_when_enabled():
    with patch.object(
        push_service, "get_settings", return_value=_settings(fcm_enabled=True, firebase_credentials_path="")
    ):
        message = push_service.push_status_message()
    # Le message ne nomme plus une variable en particulier, et c'est juste :
    # depuis l'ajout de FIREBASE_CREDENTIALS_JSON, l'une OU l'autre suffit,
    # donc dire « FIREBASE_CREDENTIALS_PATH manquant » serait trompeur pour
    # qui a choisi de passer par le secret JSON.
    assert "credentials Firebase manquants" in message
    assert "désactivé de fait" in message


def test_push_status_reports_init_failure_for_an_unreadable_credentials_file():
    with patch.object(
        push_service,
        "get_settings",
        return_value=_settings(fcm_enabled=True, firebase_credentials_path="/does/not/exist.json"),
    ):
        message = push_service.push_status_message()
    assert "initialisation Firebase a échoué" in message


def test_send_push_is_a_silent_no_op_when_fcm_is_disabled():
    db = MagicMock()
    with patch.object(push_service, "get_settings", return_value=_settings(fcm_enabled=False)):
        push_service.send_push(db, user_id=1, title="Test", body="Body")
    db.query.assert_not_called()


def test_push_status_accepts_the_json_secret_alone():
    """Le secret JSON en variable d'environnement suffit, sans fichier — c'est
    ce qui permet de configurer FCM sur Dokploy sans monter de volume. Sans ce
    test, rien ne distinguait « aucun credential » de « credentials fournis
    autrement que par un chemin »."""
    with patch.object(
        push_service,
        "get_settings",
        return_value=_settings(fcm_enabled=True, firebase_credentials_json="{}"),
    ):
        message = push_service.push_status_message()

    # Il ne se plaint plus de credentials manquants : il va jusqu'à tenter
    # l'initialisation (qui échoue ici, le JSON étant vide de contenu utile).
    assert "credentials Firebase manquants" not in message


def test_le_secret_json_seul_lance_vraiment_l_initialisation():
    """Le test précédent vérifiait le MESSAGE, pas le comportement.

    `push_status_message` avait sa propre vérification, correcte, et disait
    donc la bonne chose ; `_get_firebase_app`, lui, exigeait le CHEMIN et
    abandonnait avant d'essayer quoi que ce soit. Résultat : le diagnostic
    annonçait une tentative d'initialisation qui n'avait jamais lieu, et FCM
    restait éteint pour quiconque configurait par le seul secret JSON — la
    voie la plus simple sur Dokploy.

    On vérifie donc que `credentials.Certificate` est RÉELLEMENT appelé, avec
    le contenu du secret.
    """
    certificate = MagicMock()
    fake_credentials = MagicMock(Certificate=certificate)
    fake_firebase = MagicMock()

    with patch.object(
        push_service,
        "get_settings",
        return_value=_settings(
            fcm_enabled=True,
            firebase_credentials_json='{"project_id": "pokou-test"}',
        ),
    ), patch.dict(
        "sys.modules",
        {
            "firebase_admin": fake_firebase,
            "firebase_admin.credentials": fake_credentials,
        },
    ):
        fake_firebase.credentials = fake_credentials
        push_service._get_firebase_app()

    certificate.assert_called_once_with({"project_id": "pokou-test"})


def test_le_diagnostic_nomme_la_source_des_credentials():
    """Un diagnostic qui parle d'un chemin alors que l'exploitant a fourni un
    JSON l'envoie chercher au mauvais endroit — c'est exactement ce qui est
    arrivé : il se plaignait d'un chemin vide."""
    with patch.object(
        push_service,
        "get_settings",
        return_value=_settings(fcm_enabled=True, firebase_credentials_json="{}"),
    ):
        message = push_service.push_status_message()
    assert "FIREBASE_CREDENTIALS_JSON" in message

    with patch.object(
        push_service,
        "get_settings",
        return_value=_settings(fcm_enabled=True, firebase_credentials_path="/tmp/cle.json"),
    ):
        message = push_service.push_status_message()
    assert "/tmp/cle.json" in message


def test_sans_aucun_credential_on_n_essaie_meme_pas():
    """FCM_ENABLED seul ne doit rien tenter : une exception d'initialisation
    à chaque appel polluerait les journaux sans rien apprendre."""
    with patch.object(
        push_service,
        "get_settings",
        return_value=_settings(fcm_enabled=True),
    ):
        assert push_service._get_firebase_app() is None
