# Console d'administration Pokou

La console sert à l'équipe Pokou : modération, suivi des services,
gestion de l'équipe et de ses droits. Elle n'a rien à voir avec l'app :
aucun utilisateur de Pokou n'y a accès, et l'équipe ne s'y connecte jamais
avec son numéro de téléphone.

| | |
|---|---|
| Adresse | `https://apipokou.cabinet-p-et-associes.com/console/` |
| Code | `admin/` (Next.js 15, shadcn/ui « dashboard-01 », Tailwind 4) |
| API | `/api/v1/admin/*` (`backend/app/api/v1/admin/admin.py`) |
| Droits | `backend/app/core/permissions.py` |
| Sessions | `backend/app/services/auth/console_session.py` |

## 1. Se connecter

**E-mail et mot de passe uniquement.** La page de connexion ne propose
rien d'autre. Le mot de passe de console est distinct de tout ce qui existe
dans l'app (colonne `users.console_password_hash`, bcrypt).

- Après 5 mots de passe faux, le compte est bloqué 15 minutes (HTTP 429).
- La réponse est la même que l'e-mail existe ou non : impossible de
  deviner les comptes de l'équipe.
- Une session de console dure **8 heures**, puis il faut se reconnecter.
  Elle est révocable (ligne `tokens`).
- Le mot de passe se change dans la console : icône 🔑 en bas du menu
  (12 caractères minimum). Chaque connexion et chaque changement est
  inscrit au journal d'audit.

**Une session de l'app n'ouvre pas la console.** Les jetons de la console
portent `scope = "console"`, et toutes les routes d'administration
l'exigent. Un membre de l'équipe connecté à l'app par code SMS reçoit un
403 s'il appelle l'API d'administration avec ce jeton. Cela vaut aussi pour
les routes d'admin des modules (Honam, Assimé, Pokou certifié, catalogue
des modules), qui passent par `require_permission_claims`.

## 2. Le premier super-administrateur : créé au déploiement

À chaque démarrage de l'API, juste après les migrations,
`backend/docker-entrypoint.sh` lance `python -m scripts.seed`. Le seed est
idempotent : il ne crée que ce qui manque et ne modifie jamais un réglage
fait depuis la console.

1. **Catalogue des modules** : les 9 modules que l'app sait ouvrir
   (`mobile/lib/features/modules/presentation/module_routes.dart`). Un
   module fermé par l'équipe reste fermé.
2. **Super-administrateur de la console**, réglé par l'environnement de
   l'app `pokou-api` :

| Variable | Défaut | Rôle |
|---|---|---|
| `POKOU_SUPERADMIN_EMAIL` | `admin@pokou.app` | e-mail de connexion |
| `POKOU_SUPERADMIN_PASSWORD` | *(aléatoire)* | mot de passe initial ; sinon tiré au hasard |
| `POKOU_SUPERADMIN_NAME` | `Administrateur Pokou` | nom affiché |
| `POKOU_SUPERADMIN_PHONE` | *(vide)* | rattache un compte Pokou existant au lieu d'en créer un |

Le mot de passe aléatoire est écrit **une seule fois** dans les journaux du
déploiement qui crée le compte (Kubero → `pokou-api` → Logs) :

```
Console d'administration : https://apipokou.cabinet-p-et-associes.com/console/
Super-administrateur     : admin@pokou.app (créé)
Mot de passe             : ••••••••••••••••
→ affiché une seule fois : change-le dès la première connexion.
```

Les déploiements suivants affichent « inchangé » et ne le répètent plus.
Comme il est passé par les journaux, il faut le changer dès la première
connexion.

Un échec du seed n'empêche pas l'API de démarrer : il est signalé dans les
journaux (« Seed : échec »).

## 3. Les rôles

Le rôle est relu en base à chaque requête : retirer un rôle prend effet
immédiatement, sans attendre l'expiration d'un jeton.

| Permission | Super-admin | Admin | Support | Opérateur IA | Lecture seule |
|---|:-:|:-:|:-:|:-:|:-:|
| Tableau de bord | ✓ | ✓ | ✓ | ✓ | ✓ |
| Voir les utilisateurs | ✓ | ✓ | ✓ | | ✓ |
| Suspendre / réactiver | ✓ | ✓ | ✓ | | |
| Voir l'équipe | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Gérer l'équipe et les rôles** | ✓ | | | | |
| Voir / traiter les signalements | ✓ | ✓ | ✓ | voir | |
| Kory, Honam, Assimé, Pokou certifié (voir) | ✓ | ✓ | ✓ | Assimé, certifié | ✓ |
| Honam, Pokou certifié (gérer) | ✓ | ✓ | | | |
| Assimé (gérer) | ✓ | ✓ | | ✓ | |
| Ouvrir / fermer les modules | ✓ | ✓ | | | |
| Journal d'audit | ✓ | ✓ | | | |

La console affiche ce tableau (« Équipe et rôles »), lu depuis l'API : il ne
peut pas diverger du code. La console cache ce que le rôle ne permet pas,
mais c'est l'API qui refuse.

Garde-fous :

- Il reste toujours au moins un super-administrateur actif (HTTP 409).
- Seul un super-administrateur suspend un membre de l'équipe, y compris
  depuis un signalement.
- Personne ne peut se suspendre soi-même.

## 4. Gérer l'équipe

**Équipe et rôles → Ajouter** : nom, e-mail, rôle. Le compte de console est
créé avec un **mot de passe provisoire affiché une seule fois** ; le
transmettre à la personne par un canal sûr. Elle le change à sa première
connexion.

**Nouveau mot de passe** (sur la ligne d'un membre) : remplace le mot de
passe perdu par un provisoire, débloque le compte et ferme ses sessions
ouvertes.

**Retirer quelqu'un de l'équipe** : lui donner le rôle « Utilisateur ».

## 5. Ce que fait chaque page

| Page | Contenu | Actions |
|---|---|---|
| Tableau de bord | utilisateurs, messages, Kory, signalements, Honam, Assimé, certifiés, groupes ; activité sur 7/30/90 jours | — |
| Utilisateurs | recherche par nom ou numéro, filtres statut et rôle, fiche | suspendre (motif obligatoire), réactiver |
| Signalements | file « À traiter », sanctionnés, classés | classer, suspendre |
| Kory | cagnottes, montants confirmés, contributions à confirmer ou contestées | lecture seule |
| Honam | commandes (étape seulement), pharmacies, coursiers en attente | valider un coursier |
| Assimé | dossiers « vendeur vérifié », pièce d'identité | approuver, refuser avec motif |
| Pokou certifié | dossiers Pro, les plus proches de l'échéance d'abord | approuver, à corriger, refuser |
| Modules | catalogue | ouvrir, fermer, recommander |
| Équipe et rôles | membres, matrice des droits | ajouter, changer le rôle, nouveau mot de passe |
| Journal d'audit | toutes les actions de l'équipe | — |

**Ce que la console ne montre jamais** : le contenu des messages (chiffrés
de bout en bout, le serveur ne l'a pas) et, pour Honam, l'ordonnance ou les
produits d'une commande : seulement son étape.

**Suspendre** déconnecte la personne tout de suite : toutes ses sessions
sont révoquées, pas seulement la prochaine connexion. Sanctionner un
signalement règle aussi les autres signalements ouverts du même compte.

## 6. Modifier la console

```bash
cd admin
npm install
NEXT_PUBLIC_API_BASE=https://apipokou.cabinet-p-et-associes.com npm run dev   # http://localhost:3000/console/
npm run publish     # build + copie de l'export dans backend/app/console
```

La console est un export statique servi par l'API elle-même
(`backend/app/api/public/console.py`), sur la même origine que `/api/v1` :
ni CORS, ni second déploiement. Le build Kubero n'a pas Node : **le
résultat de `npm run publish` (`backend/app/console/`) doit être committé**
avec le code source, puis l'API redéployée.

Illustrations : `admin/public/illustrations/` (unDraw, licence libre sans
attribution, recolorées aux couleurs Pokou), les mêmes que
`mobile/assets/illustrations/`.

## 7. Tests

`backend/tests/test_admin_space.py` (15 tests) : refus d'un utilisateur
simple, permissions par rôle, suspension et révocation des sessions, règle
de l'équipe, file des signalements, seed et connexion par mot de passe,
verrouillage, refus d'une session de l'app, ajout d'un membre par e-mail.
`backend/tests/test_console_static.py` : la console est servie et on ne
sort pas de son dossier.
