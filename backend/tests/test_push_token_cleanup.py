"""Un jeton de notification n'est supprimé que si Firebase le déclare mort.

Il l'était à la moindre erreur, passagère comprise : le téléphone ne
recevait plus rien jusqu'au prochain démarrage de l'application."""
from firebase_admin import exceptions, messaging

from app.services.notifications.push_service import _token_is_dead


def test_un_jeton_desinstalle_ou_d_un_autre_projet_est_mort():
    assert _token_is_dead(messaging.UnregisteredError("Requested entity was not found."))
    assert _token_is_dead(messaging.SenderIdMismatchError("mismatch"))
    assert _token_is_dead(exceptions.InvalidArgumentError("The registration token is not a valid FCM registration token"))


def test_une_erreur_passagere_garde_le_jeton():
    assert not _token_is_dead(messaging.QuotaExceededError("quota"))
    assert not _token_is_dead(exceptions.UnavailableError("backend unavailable"))
    assert not _token_is_dead(exceptions.DeadlineExceededError("timeout"))
    assert not _token_is_dead(exceptions.InternalError("internal"))
    assert not _token_is_dead(None)


def test_un_message_mal_forme_ne_tue_pas_le_jeton():
    assert not _token_is_dead(exceptions.InvalidArgumentError("Message payload exceeds the size limit"))


def test_aucune_cle_reservee_par_firebase_ne_part():
    """`message_type` faisait refuser TOUTES les notifications de message."""
    from app.services.notifications.push_service import _firebase_safe_data

    safe = _firebase_safe_data({"message_type": "TEXT", "from": "3", "google.x": "1", "rich": "1"})
    assert safe == {"msg_type": "TEXT", "from_user": "3", "rich": "1"}
    assert _firebase_safe_data({"msg_type": "TEXT", "message_type": "TEXT"}) == {"msg_type": "TEXT"}


def test_les_notifications_de_message_n_utilisent_pas_message_type():
    import inspect
    from app.api.v1.messaging import groups, messages

    assert '"message_type": message.message_type' not in inspect.getsource(messages._rich_push_data)
    assert '"message_type": serialized["message_type"]' not in inspect.getsource(groups)
