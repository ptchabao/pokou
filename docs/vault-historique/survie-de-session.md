# Vault — ce qui peut déconnecter quelqu'un

**Pour** : le fondateur, pour arbitrer avant qu'on touche à l'authentification.
**Méthode** : lecture du code, pas des intentions. Aucun comportement n'a été modifié pour écrire ce document.
**Date** : 28/09/2026.

---

## La règle produit

> Une évolution technique de Vault ne doit jamais être interprétée comme une
> raison de déconnecter l'utilisateur.

Elle ne dit pas « ne jamais déconnecter ». Une révocation de sécurité doit
rester une révocation. Tout ce document sert à séparer les deux :

| | |
|---|---|
| **Migration technique** | nouvelle version d'application, nouvelle route, schéma de session qui change, serveur redémarré, clé de configuration remplacée → **jamais de déconnexion** |
| **Révocation de sécurité** | jeton révoqué depuis un autre appareil, compte désactivé, déconnexion demandée → **déconnexion, immédiate et définitive** |

---

## Le verdict en une phrase

**Aucune évolution technique ne déconnecte.** C'était vrai de quatorze cas
sur quinze au moment de l'audit ; le quinzième — sept jours sans ouvrir
l'application — a été corrigé le 28/09 (voir §5).

---

## 1. Ce qui existe aujourd'hui

```
identité du compte      User (id, phone)                 — permanente
    ↓
session d'appareil      Token (jti, expires_at)          — 7 jours, glissante
    ↓
jeton d'accès           JWT type=access                  — 30 minutes
jeton de rafraîchissement JWT type=refresh, même jti     — 7 jours
```

Trois propriétés importantes, et elles sont bonnes :

- **la rotation PROLONGE.** Chaque rafraîchissement émet une nouvelle paire
  avec `expires_at = maintenant + 7 jours`. Une application ouverte au moins
  une fois par semaine repousse donc son échéance indéfiniment : il n'y a
  pas de plafond absolu au bout duquel il faudrait se reconnecter ;
- **une fenêtre de grâce de 60 s** couvre la réponse perdue au mauvais
  moment — l'ancien jeton reste utilisable une fois si le nouveau n'est
  jamais arrivé (ajoutée le 25/09) ;
- **`verify_token` ne vérifie que la signature et le TYPE.** Ni numéro de
  version, ni schéma strict, ni champ obligatoire nouveau. C'est ce qui rend
  les cas 5 à 9 ci-dessous inoffensifs, et c'est une qualité qu'il faut
  protéger explicitement : ajouter demain un `if payload["v"] != 2` y
  mettrait fin sans que personne ne le remarque avant le déploiement.

Côté application, **un seul chemin mène à la déconnexion** :
`_loadProfile()` reçoit un 401 sur `GET /me` → efface les jetons. Tout le
reste — réseau coupé, serveur muet, rafraîchissement injoignable —
conserve la session et réessaie.

---

## 2. Les quinze cas

Lecture : **État actuel → cause de déconnexion → comportement souhaité →
ce qu'il faut changer.**

### 1. Jeton d'accès expiré (30 min)

Le client reçoit 401, rafraîchit en silence, rejoue la requête. L'utilisateur
ne voit rien.
→ **Aucune déconnexion. Rien à changer.**

### 2. Jeton de rafraîchissement expiré

**CORRIGÉ le 28/09.** C'était le seul vrai écart : sept jours sans ouvrir
Vault — un voyage, un second téléphone, une hospitalisation — et il fallait
refaire un SMS.

La session ne périme plus d'elle-même. Voir §5 pour ce que cela a exigé.

### 3. Jeton de rafraîchissement révoqué

`_reject_if_revoked` refuse ; le client se déconnecte.
→ **C'est le comportement voulu.** Une révocation est une décision de
sécurité, pas un accident technique. Rien à changer.

### 4. Rotation du jeton

Nouvelle paire émise, ancien jeton marqué `rotated_at`, fenêtre de grâce de
60 s pour la réponse perdue.
→ **Aucune déconnexion. Rien à changer.**

### 5. Ancienne version de l'application

Les jetons restent valables : `verify_token` ne lit aucun numéro de version.
Une route disparue renverrait 404, jamais 401 — et un 404 ne déconnecte pas.
→ **Aucune déconnexion.** À protéger par un test (§3, décision 3).

### 6. Nouvelle version de l'application

Les jetons sont dans `flutter_secure_storage`, qui survit à une mise à jour.
→ **Aucune déconnexion. Rien à changer.**

### 7. Changement de version d'API

Le préfixe `/api/v1` est aujourd'hui le seul. Une `/api/v2` cohabiterait ;
un client v1 continuerait de fonctionner tant que v1 répond.
→ **Aucune déconnexion aujourd'hui.** Le risque est futur : retirer v1
donnerait des 404. **Règle à écrire** : une version d'API ne se retire que
lorsque plus personne ne l'appelle, et jamais en même temps qu'un changement
d'authentification.

### 8. Migration du backend

Les jetons sont des JWT signés : ils ne dépendent de la base que pour la
révocation. Une migration qui préserve la table `tokens` ne déconnecte
personne.
→ **Aucune déconnexion**, à une condition : **ne jamais vider `tokens`
pendant une migration.** Une migration qui recrée la table déconnecterait
tout le monde en silence. À écrire dans les règles de migration.

### 9. Changement de schéma de session

Les colonnes ajoutées le 25/09 (`rotated_at`, `replaced_by_jti`,
`grace_used_at`) sont nullables : les lignes antérieures restent valables.
→ **Aucune déconnexion**, à condition de garder cette discipline — toute
colonne nouvelle sur `tokens` doit être nullable ou avoir un défaut.

### 10. Désinstallation / réinstallation

Le stockage sécurisé part avec l'application. Il FAUT se reconnecter.
→ **Comportement attendu.** Rien à changer.

### 11. Changement de réseau

Le rafraîchissement échoue en `unreachable`, jamais en `rejected` : la
session est conservée, le client recule (2 s → 60 s) et réessaie.
→ **Aucune déconnexion. Rien à changer.** C'est exactement ce qui a été
corrigé le 25/09.

### 12. Serveur temporairement indisponible

Identique au cas 11 : une absence de réponse n'est pas un refus.
→ **Aucune déconnexion. Rien à changer.**

### 13. Changement de clé ou de configuration d'authentification

**`SECRET_KEY` remplacée = toutes les signatures invalides = tout le monde
déconnecté, instantanément et sans recours.**
→ C'est une évolution TECHNIQUE qui produit l'effet d'une révocation de
masse. Aujourd'hui rien n'empêche que ça arrive par accident — une variable
d'environnement absente au redéploiement suffirait.
→ **À changer** : voir §3, décision 2.

### 14. Plusieurs appareils connectés

Chaque connexion crée sa propre ligne `Token` avec son `jti`. Les sessions
sont indépendantes : rafraîchir sur un appareil ne touche pas les autres.
→ **Aucune déconnexion. Rien à changer.**

### 15. Connexion d'un nouvel appareil

Une ligne de plus. Aucune session existante n'est révoquée.
→ **Aucune déconnexion. Rien à changer.**

---

## 3. Les trois décisions à prendre

### Décision 1 — La durée de vie du rafraîchissement (cas 2)

C'est la seule qui sépare l'existant de « rester connecté pendant des
années ». Vous aviez retenu 7 jours le 25/09, en connaissance de cause ; la
nouvelle exigence le remet en question.

| | Effet | Coût |
|---|---|---|
| **Garder 7 jours** | rien à faire | une semaine sans ouvrir Vault = un SMS de reconnexion |
| **Passer à 90 jours** | couvre un voyage, un second téléphone | un jeton volé reste utilisable 90 jours s'il n'est pas révoqué |
| **Pas d'échéance absolue, seulement la révocation** | le modèle WhatsApp | il faut alors une liste d'appareils avec un bouton « déconnecter », sinon plus rien ne reprend un jeton perdu |

La troisième est celle qui correspond à ce que vous décrivez. Elle **exige**
l'écran « Mes appareils » — sans lui, un jeton qui ne périme jamais et qu'on
ne peut pas révoquer serait un recul de sécurité, pas un progrès.
`DevicesScreen` existe déjà côté application ; il reste à vérifier qu'il
révoque bien la ligne `Token` et pas seulement le jeton de notification.

### Décision 2 — La clé de signature (cas 13)

Aujourd'hui une seule clé, et la remplacer déconnecte tout le monde.

La correction est petite et connue : un **identifiant de clé** (`kid`) dans
l'en-tête du JWT, et un trousseau côté serveur — la clé courante signe, les
anciennes vérifient encore pendant une période. Remplacer une clé devient
alors une opération sans effet visible, ce qu'elle devrait être.

À faire avant, et pas après, le premier remplacement de clé.

### Décision 3 — Protéger ce qui marche déjà

Les cas 5 à 9 sont sains **par omission** : personne n'a ajouté de
vérification de version. Rien ne garantit que ça dure, et le jour où
quelqu'un l'ajoutera, l'effet ne se verra qu'au déploiement, sur tout le
parc à la fois.

Trois tests à écrire, qui échouent si la propriété disparaît :

1. un jeton émis sans les colonnes du 25/09 reste accepté ;
2. un jeton ne portant aucun champ de version reste accepté ;
3. un rafraîchissement injoignable ne produit jamais `rejected`.

Et deux règles à écrire dans les procédures :

- **ne jamais vider ni recréer la table `tokens`** au cours d'une migration ;
- **ne jamais retirer une version d'API** en même temps qu'un changement
  d'authentification.

---

## 4. Ce qu'il ne faut pas faire

Ne pas confondre « ne jamais déconnecter » avec « ne jamais révoquer ». Les
cas 3 et 10 doivent continuer de déconnecter, et le jour où l'on ajoute la
désactivation d'un compte, elle devra le faire aussi. Le but n'est pas
qu'une session soit éternelle : c'est qu'elle ne meure que pour une raison
qu'on puisse expliquer à la personne concernée.


---

## 5. Ce qui a été corrigé le 28/09

### La session ne périme plus d'elle-même

`refresh_token_expire_days` passe de 7 à 3650, ce qui revient à « jusqu'à
révocation ».

Le réglage a aussi été **retiré de `.env` et `.env.example`**. C'est devenu
une décision produit, pas un bouton d'exploitation : une valeur
d'environnement l'emporte sur le défaut du code, et tant qu'elle y figurait,
personne ne savait lequel des deux décidait — les deux disaient 7, ce qui
masquait la question.

> ⚠️ **Action requise en production.** Si `REFRESH_TOKEN_EXPIRE_DAYS` est
> défini dans les variables d'environnement Dokploy, il continue de gagner
> et la correction n'a aucun effet. Il faut l'y supprimer.

### Le lien appareil → session suivait mal

C'est la correction qui rend la première acceptable, et elle réparait un
défaut réel.

`DeviceToken.session_jti` rattache un téléphone à sa session : c'est lui que
« révoquer cet appareil » utilise pour la couper. Il était posé une fois, à
l'enregistrement, et **jamais reporté à la rotation**. Au premier
rafraîchissement — donc au bout de trente minutes — il désignait un jeton
déjà révoqué, pendant que la vraie session continuait sous un autre `jti`.

Révoquer un téléphone perdu révoquait alors quelque chose de mort. La porte
restait ouverte, et l'écran affichait que l'appareil avait été retiré.

Le défaut était masqué : au bout de sept jours, l'expiration finissait par
tout nettoyer. Il ne l'est plus, puisqu'il n'y a plus d'expiration — d'où
l'ordre dans lequel les deux changements ont été faits.

### Ce qui reste ouvert

**Décision 2 — la clé de signature.** Inchangée : remplacer `SECRET_KEY`
déconnecte toujours tout le monde. La correction (`kid` + trousseau) est à
faire avant le premier remplacement, pas après.

**Décision 3 — protéger ce qui marche.** Trois tests écrits
(`tests/test_session_survie.py`) : un jeton sans champ de version reste
accepté, une ligne de session sans les colonnes du 25/09 reste valable, un
jeton échangé ne ressert pas hors fenêtre de grâce. Restent les deux règles
de procédure — ne jamais vider `tokens` pendant une migration, ne jamais
retirer une version d'API en même temps qu'un changement d'authentification.
