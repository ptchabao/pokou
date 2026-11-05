# Vault — Stickers et GIF

Ce document dit ce qui existe, ce qui reste à faire côté exploitation, et
surtout **pourquoi** certaines décisions ont été prises plutôt que leurs
alternatives évidentes.

---

## 1. Un sticker n'est pas une image

C'est la distinction qui structure tout le reste. Un sticker :

- s'affiche **sans cadre ni fond** — sa transparence fait partie du dessin ;
- ne s'ouvre pas en plein écran ;
- ne se télécharge pas dans la galerie ;
- ne compte pas dans les « photos » d'une conversation.

D'où un `MessageType.STICKER` à part entière, et non un drapeau posé sur
`IMAGE`. Un drapeau aurait obligé chaque écran à redécouvrir ces quatre
règles, et l'un d'eux aurait fini par en oublier une.

---

## 2. L'exception qui rend les stickers possibles

Partout ailleurs dans Vault, une pièce jointe **doit avoir été téléversée
par celui qui l'envoie**. C'est ce qui empêche de voler le média d'autrui en
devinant son identifiant.

Un sticker casse cette hypothèse : son image appartient au **pack**, donc à
son auteur ou au compte officiel. Sans exception explicite,
`POST /messages` aurait répondu « Pièce jointe introuvable » à chaque
sticker, et la fonctionnalité entière serait morte à l'envoi.

L'exception est écrite **une seule fois**, dans
`api/app/services/sticker_service.py` :

| Fonction | Question à laquelle elle répond | Appelée par |
|---|---|---|
| `sender_may_attach` | ai-je le droit d'**envoyer** ce média comme sticker ? | `routes/messages.py`, `routes/groups.py` |
| `is_public_sticker_media` | ce média est-il **visible** hors de tout message ? | `routes/media.py::_can_access` |

Elle n'est **pas recopiée** dans les deux routes d'envoi. La règle « qui
puis-je joindre » avait été écrite à quatre endroits dans ce dépôt ; trois
avaient divergé, et c'est ce qui a produit un 403 en production. On ne
recommence pas.

`is_public_sticker_media` existe parce que le panneau montre le catalogue
**avant tout envoi** : il n'existe encore aucun message pour justifier
l'accès. Seuls les packs **publics** s'ouvrent ainsi ; un sticker de pack
personnel reste accessible par le message qui le porte, pas par le
catalogue.

---

## 3. Normalisation des emojis — les deux côtés parlent la même forme

`suggest_for_emoji` cherche la **forme de base** (`normalize_emoji` retire
les modificateurs de teint, les sélecteurs de variante et les joncteurs de
largeur nulle), par un `LIKE`.

Les étiquettes sont donc **normalisées à l'écriture aussi**. Les ranger
brutes rendait certains stickers définitivement introuvables : une étiquette
`👨‍👩‍👧` porte des joncteurs que la recherche avait justement retirés du
terme cherché, donc la sous-chaîne ne correspondait jamais.

Côté Flutter, `trailingEmoji` ne fait **que** détecter l'emoji terminal. Le
repliage reste côté serveur, une seule fois : le refaire dans l'application
créerait deux règles à tenir d'accord, et elles finiraient par diverger.

---

## 4. Favoris ≠ récents

| | Comment ça se remplit | Comment ça se vide |
|---|---|---|
| **Récents** | tout seul, à chaque envoi | chassés par les suivants (`MAX_RECENTS = 32`) |
| **Favoris** | choisis, par appui long | seulement si on les retire |

Les fondre ferait disparaître un sticker qu'on avait explicitement mis de
côté, le jour où on en envoie trente autres. Ce sont deux tables, deux
onglets, et deux tests qui le vérifient.

Les deux **suivent le compte**, pas l'appareil : les garder localement
aurait donné un panneau vide après un changement de téléphone, alors qu'on
envoie les mêmes cinq stickers depuis des mois.

---

## 5. Les GIF : natifs, pas GIPHY

**Décision : GIPHY ❌, GIF natifs Vault ✅.**

Les conditions actuelles de GIPHY imposent :

- une clé de production obtenue après candidature et discussion tarifaire ;
- une mention « Powered by GIPHY » obligatoire ;
- **aucune mise en cache** sans approbation ;
- **aucun proxy** — les requêtes doivent partir du client.

Ces deux dernières contraintes sont rédhibitoires pour Vault : un GIF
transitant par leur intermédiaire voyagerait **en clair**, et le
fournisseur apprendrait qui regarde quoi et quand — exactement la fuite de
métadonnées que le chiffrement de bout en bout cherche à fermer.

Le GIF fourni par l'utilisateur suit donc le chemin de **tous** les médias
Vault : chiffré, déposé sur notre stockage, déchiffré chez le destinataire.

Le chemin est **séparé de la galerie**, et c'est nécessaire :
`ImagePicker` ré-encode ce qu'il rend (`imageQuality`), et un GIF ré-encodé
devient une image **fixe** — l'animation disparaît en silence. Le sélecteur
de fichiers rend l'original, octet pour octet. Il ne passe pas non plus par
l'écran de préparation, qui l'aplatirait de la même façon.

Tenor reste une piste distincte, **non intégrée** : la même vérification
(cache, proxy, chiffrement, traçage) reste à faire.

---

## 6. Où ça vit

### Serveur

| Fichier | Rôle |
|---|---|
| `api/app/models/orm.py` | `MessageType.STICKER` + 5 tables |
| `api/app/services/sticker_service.py` | toute la logique, y compris les deux règles d'accès |
| `api/app/routes/stickers.py` | 14 routes sous `/api/v1/stickers` |
| `api/alembic/versions/20260923_stickers.py` | migration, entièrement conditionnelle |
| `api/tests/test_stickers.py` | 31 tests |

Les tables : `sticker_packs`, `stickers`, `user_sticker_packs`,
`sticker_favorites`, `sticker_recents`.

### Application

| Fichier | Rôle |
|---|---|
| `features/stickers/data/sticker_models.dart` | `Sticker`, `StickerPack` |
| `features/stickers/data/sticker_repository.dart` | accès aux 14 routes |
| `features/stickers/presentation/sticker_providers.dart` | l'état du panneau, en **un seul** objet |
| `features/stickers/presentation/sticker_panel.dart` | la grille, les onglets, la recherche |
| `features/stickers/presentation/sticker_image.dart` | le rendu sans cadre |
| `features/stickers/presentation/sticker_suggestion_bar.dart` | la bande sous la barre de saisie |
| `features/stickers/presentation/sticker_packs_screen.dart` | gestion des packs, création depuis une photo |
| `features/stickers/presentation/trailing_emoji.dart` | détection de l'emoji terminal |
| `features/messaging/presentation/composer/composer_panel.dart` | les deux onglets Emoji / Stickers |

Le panneau est branché dans **les deux** écrans de conversation, directe et
de groupe. Les groupes n'avaient jusqu'ici aucun panneau emoji ; ils l'ont
maintenant, par le même composant.

L'ordre des packs se change au doigt, dans l'écran de gestion. Ce n'est pas
décoratif : c'est cet ordre qui décide de celui des onglets du panneau, donc
de ce qu'on a sous le pouce. La poignée est **explicite** — avec le
glissement long par défaut de `ReorderableListView`, un appui un peu appuyé
sur une ligne la déplacerait sans qu'on l'ait voulu.

---

## 7. Choix d'interface, et ce qu'ils évitent

**Un seul conteneur, deux onglets.** Deux panneaux qui s'ouvrent et se
ferment l'un l'autre auraient fait sauter la conversation à chaque bascule :
chaque passage aurait refermé puis rouvert un conteneur de la hauteur du
clavier.

**L'onglet actif survit à la fermeture.** Quelqu'un qui envoie trois
stickers de suite referme le panneau entre chaque envoi. Le rouvrir sur
l'onglet emoji lui ferait refaire le même geste à chaque fois.

**Le sticker part au toucher.** Pas d'aperçu, pas de confirmation. Une
étape de plus le rendrait plus lent que d'écrire « 👍 ». L'appui long, lui,
met en favori — geste secondaire pour action secondaire.

**La bande de suggestions n'occupe rien quand elle est vide**, y compris
pendant le chargement. Réserver sa hauteur « au cas où » ferait remonter le
fil de 64 points en permanence, pour une bande visible quelques secondes
par heure.

---

## 8. Ce qui reste à faire, côté exploitation

1. **Aucun pack officiel n'est semé.** La migration crée les tables, pas
   leur contenu — il faut de vraies images. Tant qu'aucun pack public
   n'existe, l'onglet Stickers propose d'aller au catalogue, qui est vide.
   La création depuis une photo, elle, fonctionne dès le premier jour : un
   pack personnel se crée tout seul au premier sticker.
2. **L'API doit être redéployée** pour que les 14 routes existent.
3. Un pack personnel est borné à **30 stickers** (`MAX_PERSONAL_STICKERS`)
   et les récents à **32** (`MAX_RECENTS`) — à relever si l'usage le
   demande, les deux sont des constantes isolées.
