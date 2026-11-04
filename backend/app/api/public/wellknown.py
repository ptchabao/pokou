"""Vérification de domaine pour les liens d'invitation Pokou cliquables
(Android App Links / iOS Universal Links).

Firebase Dynamic Links — le produit historiquement utilisé pour ce genre de
lien — est OFFICIELLEMENT ARRÊTÉ par Google depuis août 2025 : ce module ne
s'en sert PAS. Le remplacement standard des deux plateformes repose sur deux
fichiers statiques, servis EN CLAIR (sans authentification, sans préfixe de
version d'API) à la racine du domaine qui héberge les liens :
- Android exige `/.well-known/assetlinks.json`, vérifié automatiquement
  quand l'intent-filter porte `android:autoVerify="true"` (voir
  mobile/android/app/src/main/AndroidManifest.xml) ;
- iOS exige `/.well-known/apple-app-site-association`, vérifié via la
  capacité "Associated Domains" du projet Xcode (non câblée ici : pas
  d'environnement macOS/Xcode disponible pour ce ticket, voir le rapport de
  livraison).

Ces deux routes sont enregistrées SANS le préfixe `/api/v1` (voir
`app/main.py`) — les vérificateurs de domaine d'Android/iOS vont chercher
ces fichiers à un chemin fixe, ils n'ont aucune notion de version d'API.

Domaine : `pok.app`.

────────────────────────────────────────────────────────────────────────────
TROIS CONDITIONS, ET AUCUNE NE SE SIGNALE QUAND ELLE MANQUE
────────────────────────────────────────────────────────────────────────────

La console Play affiche « Échec de la validation de 1 domaine » quelle que
soit celle qui manque, et un lien qui ne s'ouvre pas dans l'application
ressemble exactement à un lien qui s'ouvre normalement dans le navigateur.
D'où cette liste, et la commande qui va avec.

1. **Le domaine doit RÉSOUDRE**, vers un reverse-proxy qui route
   `/.well-known/*` vers cette API SANS authentification et SANS le
   préfixe `/api/v1`.

2. **L'empreinte de la clé Play doit être publiée.** Google RESIGNE le
   bundle téléversé avec sa propre clé : c'est elle que les appareils
   vérifient, pas le keystore local. Voir `_play_app_signing_fingerprints()`,
   qui la lit dans `ANDROID_PLAY_SIGNING_SHA256`.

3. **Les chemins déclarés doivent couvrir les liens réellement produits.**
   L'application génère `/invite/…`, `/c/…` et `/channel/…` ; le manifeste
   Android et la liste `paths` ci-dessous doivent déclarer les trois.

Vérification, dans l'ordre — la première qui échoue est la cause :

    dig +short pok.app
    curl -sS https://pok.app/.well-known/assetlinks.json | jq .
    curl -sS "https://digitalassetlinks.googleapis.com/v1/statements:list\
?source.web.site=https://pok.app\
&relation=delegate_permission/common.handle_all_urls" | jq .

La troisième est le vérificateur de Google lui-même : c'est exactement ce que
l'appareil interroge, et il dit pourquoi il refuse.
"""
import os
from typing import List

from fastapi import APIRouter

router = APIRouter(tags=["well-known"])


# Empreintes SHA-256 des certificats autorisés à ouvrir les liens
# pok.app. Une LISTE, et non une valeur : Android accepte plusieurs
# empreintes pour un même paquet, ce qui est nécessaire ici parce que trois
# certificats différents coexistent légitimement.
#
# Toute empreinte manquante fait échouer la vérification EN SILENCE pour les
# binaires signés avec ce certificat : le lien s'ouvre alors dans le
# navigateur au lieu de l'application, sans message d'erreur nulle part.
_BUILT_IN_SHA256_FINGERPRINTS = [
    # Keystore de RELEASE (clé de téléversement, voir
    # mobile/android/key.properties). ATTENTION : c'est la clé de TÉLÉVERSEMENT, pas celle qui
    # signe ce que les utilisateurs installent, dès lors que Play App Signing
    # est activé — voir _play_app_signing_fingerprints().
    "5F:2C:D7:94:E2:35:96:3D:2E:7B:0D:09:7E:41:A7:95:B4:13:D2:2C:12:51:B9:5A:76:87:5F:3E:3A:00:A5:7A",
    # Keystore de DEBUG de la machine de développement — conservé pour que
    # les liens fonctionnent aussi sur un build lancé depuis l'IDE. Sans
    # risque : cette clé ne signe rien qui soit distribué, et elle n'autorise
    # que l'ouverture de liens, pas l'accès à des données.
    "C6:2E:93:50:78:7A:FF:46:51:DC:6B:48:58:52:D7:33:86:0F:D2:15:A5:FC:E6:84:00:34:3B:70:04:DE:4B:7B",
    # La clé de signature GÉRÉE PAR GOOGLE (Play App Signing) n'est PAS ici :
    # elle est propre à chaque fiche Play et n'existe qu'une fois
    # l'application créée dans la console. Elle se déclare par
    # ANDROID_PLAY_SIGNING_SHA256 — voir _play_app_signing_fingerprints().
]


def _play_app_signing_fingerprints() -> List[str]:
    """Empreinte(s) de la clé de signature GÉRÉE PAR GOOGLE.

    C'est le piège central des App Links sur le Play Store, et il ne se
    signale nulle part : on téléverse un bundle signé avec SA clé, puis
    **Google le resigne avec la sienne** avant de le distribuer. L'empreinte
    que les appareils vérifient est donc celle de Google, pas celle du
    keystore local — et tant qu'elle manque ici, la vérification échoue pour
    tout le monde sauf sur les binaires installés à la main.

    À renseigner dès la création de l'application dans la console Play :
    sans elle, les liens s'ouvrent dans le navigateur sur tout binaire
    installé depuis le Store.

    Où la trouver : console Play → Test et publication → Intégrité de
    l'application → Certificat de la clé de signature de l'application →
    empreinte SHA-256.

    Format accepté : une ou plusieurs empreintes séparées par des virgules,
    avec ou sans les deux-points.
    """
    raw = os.getenv("ANDROID_PLAY_SIGNING_SHA256", "").strip()
    if not raw:
        return []
    return [fingerprint.strip().upper() for fingerprint in raw.split(",") if fingerprint.strip()]


def android_fingerprints() -> List[str]:
    return _BUILT_IN_SHA256_FINGERPRINTS + _play_app_signing_fingerprints()

# Nom de package réel — mobile/android/app/build.gradle.kts::namespace/applicationId.
_ANDROID_PACKAGE_NAME = "com.pokou.pokou"

# Identifiant de bundle réel — mobile/ios/Runner.xcodeproj/project.pbxproj::PRODUCT_BUNDLE_IDENTIFIER.
_IOS_BUNDLE_ID = "com.pokou.pokou"

# Apple Team ID du compte développeur qui signe l'application (APPLE_TEAM_ID).
# Sans lui, iOS ne vérifie pas les Universal Links.
def _apple_app_id() -> str:
    return f"{os.getenv('APPLE_TEAM_ID', 'TEAMID').strip() or 'TEAMID'}.{_IOS_BUNDLE_ID}"


@router.get("/.well-known/assetlinks.json")
async def android_asset_links():
    """Déclare Pokou comme gestionnaire autorisé des liens
    `https://pok.app/invite/...` pour Android App Links."""
    return [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": _ANDROID_PACKAGE_NAME,
                "sha256_cert_fingerprints": android_fingerprints(),
            },
        }
    ]


@router.get("/.well-known/apple-app-site-association")
async def apple_app_site_association():
    """Équivalent iOS d'assetlinks.json pour les Universal Links. Servi sans
    extension `.json` par convention Apple, mais avec un contenu JSON —
    FastAPI encode ce dict en `application/json` par défaut, ce qui suffit
    au vérificateur d'Apple."""
    return {
        "applinks": {
            "apps": [],
            "details": [
                {
                    "appID": _apple_app_id(),
                    # Chaque chemin reconnu par invite_link_parser.dart doit
                    # être déclaré ici, sinon iOS l'ouvre dans le navigateur.
                    "paths": [
                        "/invite/*",
                        "/c/*",
                        "/channel/*",
                        "/bot/*",
                        "/kory/*",
                        "/honam/order/*",
                        "/kory/pots/*",
                        "/honam/orders/*",
                    ],
                }
            ],
        }
    }
