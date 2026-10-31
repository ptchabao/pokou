"""Garde-fous globaux de la suite de tests.

Le stockage objet (MinIO) est configuré dans api/.env. Sans ce fichier, un
`pytest` lancé depuis le dossier api chargerait ce .env, et les suites qui
déposent des pièces jointes (test_pokou_messaging, test_pokou_status,
test_pokou_groups, test_pokou_calls) écriraient dans le bucket de
PRODUCTION. On neutralise donc les identifiants avant que `Settings` ne soit
construit : les tests écrivent sur le disque local, sauf ceux qui injectent
eux-mêmes des réglages (voir test_media_object_storage.py, qui utilise un S3
simulé par moto).

Les variables d'environnement ont priorité sur le .env dans
pydantic-settings, donc les vider ici suffit.
"""
import os

# Stockage objet.
for _key in ("S3_ENDPOINT_URL", "S3_ACCESS_KEY", "S3_SECRET_KEY"):
    os.environ[_key] = ""

# Passerelle WhatsApp. `generate_and_send_otp` envoie désormais le code par
# WhatsApp en plus du SMS, et le helper `_signup` de la quasi-totalité des
# suites passe par cette fonction : sans ce garde-fou, un `pytest` complet
# enverrait des centaines de messages à la VRAIE passerelle avec des numéros
# de test — quota gaspillé, journaux pollués, et un envoi massif de textes
# identiques vers des numéros inconnus est exactement ce que WhatsApp
# considère comme du spam.
#
# Neutraliser Twilio ET l'URL de passerelle : send_whatsapp essaie Twilio
# d'abord, et ne renonce (retour immédiat, sans réseau ni retry) que si les
# deux sont vides. Les tests qui vérifient send_whatsapp lui-même
# réinjectent leur propre configuration.
for _key in (
    "WHATSAPP_SERVICE_URL",
    "WHATSAPP_GATEWAY_SECRET",
    "TWILIO_ACCOUNT_SID",
    "TWILIO_AUTH_TOKEN",
    "TWILIO_WHATSAPP_FROM",
):
    os.environ[_key] = ""
