# Pokou — Design, UI et UX

Description complète de l'apparence et du comportement de l'application mobile Pokou (Android / iOS, Flutter), telle qu'elle est implémentée en version **1.24.3** (novembre 2026).

Les références sont :

- le cahier des charges **v3.4** et sa description d'écrans (`Pokou_vues_cahier_v3.4.md`) ;
- les maquettes Stitch **« Terre de Confiance »** (`stitch_maquettes_compl_tes_d_interface/`) ;
- les jetons de design (`pokou-design-tokens.json`).

Dans le code, tout part de `mobile/lib/core/theme/` : `app_colors.dart`, `app_text_styles.dart`, `app_radius.dart`, `app_elevation.dart`, `app_theme.dart`.

---

## 1. Principes

| Principe | Ce que ça veut dire dans l'app |
|---|---|
| **La confiance d'abord** | Le chiffrement, le badge certifié et le mode preuve sont toujours visibles et expliqués en une phrase. Pokou ne touche jamais l'argent : c'est rappelé partout où il y a un montant. |
| **Chaleur africaine, pas folklore** | Palette terre cuite, crème et or ; noms de services en langues africaines (Kory = le cauris, Honam = « aide-moi » en éwé, Assimé = « au marché »). |
| **Fluide sur un téléphone d'entrée de gamme** | Pas de flou ni d'ombre lourde ; transitions courtes ; listes rendues depuis le cache local avant le réseau. |
| **Accès direct au contenu** | Une bulle de discussion ouvre la discussion, une notification ouvre la conversation, un lien ouvre le bon écran. Jamais d'écran intermédiaire inutile. |
| **Rien ne reste muet** | Chaque état (chargement, vide, erreur, hors ligne, message en attente, message illisible) a un texte et, si possible, une action. |
| **Tutoiement** | L'utilisateur et les coursiers sont tutoyés. Seul l'espace officine (web) vouvoie les pharmacies. |

---

## 2. Identité visuelle

### 2.1 Couleurs

Palette « Terre de Confiance ». Chaque jeton a une valeur claire et une valeur sombre, choisies par `AppColors._pick(clair, sombre)` selon le thème actif.

**Surfaces et encres**

| Jeton | Clair | Sombre | Usage |
|---|---|---|---|
| `background` | `#FFF7EC` crème | `#1A1615` ébène | Fond de tous les écrans |
| `surface` | `#FFFFFF` | `#2A2320` | Cartes, barre basse, bulles reçues |
| `surfaceElevated` | `#F2E5D5` beige | `#352C28` | Tuiles internes, pastilles inactives, ronds d'action |
| `border` | `#E4D3BF` sable | `#3D332E` | Filets fins (séparateurs) |
| `textPrimary` | `#1A1615` | `#FFF7EC` | Titres, texte courant |
| `textSecondary` | `#6B5E57` taupe | `#B8AAA0` | Aperçus, sous-titres |
| `textMuted` | `#8C7D73` | `#8C7D73` | Indications, icônes discrètes |

**Marque et actions**

| Jeton | Valeur | Usage |
|---|---|---|
| `accentPrimary` | `#A65527` terre cuite | Action principale, onglet actif, pastilles de non-lus, heure d'un fil non lu |
| `accentPressed` / `accentPrimaryDark` | `#8A4520` | Texte d'action sur fond clair, état appuyé |
| `terracottaTint` | `#F5DCCB` (sombre `#4A2E20`) | Pastille active, rond d'icône, avatar teinté |
| `onTerracottaTint` | `#8A4520` | Texte posé sur la teinte terre cuite |
| `brandOr` | `#D4AF37` | Badge vérifié de Baba, éléments « premium » |
| `brandCuivre` | `#B86D3B` | Accents secondaires |

**Couleurs de sens** (jamais décoratives)

| Jeton | Valeur | Sens |
|---|---|---|
| `feedbackSuccess` | `#1E7A46` | Confirmé, réussi (« Ta part est confirmée ») |
| `feedbackWarning` | `#8A5A00` | À vérifier, en attente d'une action |
| `feedbackDanger` / `semanticError` | `#B3261E` / `#BA1A1A` | Erreur, suppression, action irréversible |
| `feedbackInfo` | `#245C9E` | Information, Assimé |
| `readReceiptBlue` | `#53BDEB` | **Uniquement** la double coche « lu » |

**Conversation**

| Jeton | Clair | Usage |
|---|---|---|
| `chatBackground` | `#FFF7EC` | Canevas des discussions |
| `chatBubbleSent` | `#FBEDE4` sable rosé | Mes messages (sombre `#5C2E14`) |
| `chatBubbleReceived` | `#FFFFFF` + filet | Messages reçus, délimités par leur bordure |
| `chatAiIconColor` / `chatAiLinkColor` | `#D97706` / `#B45309` | Baba (ambre ; **le violet est proscrit** pour l'IA) |

Règle 60 / 30 / 10 : environ 60 % de crème et de blanc, 30 % d'encre et de beige, 10 % de terre cuite. Un rouge ou un vert n'apparaît que pour dire quelque chose.

### 2.2 Typographie

Une seule famille : **Inter**, embarquée dans l'application. Elle couvre les lettres éwé, mina et kabiyè (ɖ ɛ ƒ ɣ ŋ ɔ ʋ) et l'espace fine des montants (« 25 000 FCFA »). L'arabe passe par une chaîne de repli (Roboto, Noto Sans Arabic, Noto Sans).

| Rôle (jeton) | Taille / interligne | Graisse | Usage |
|---|---|---|---|
| display-mobile | 28 / 36, −0,2 | 600 | Grand titre d'écran (« Afi », « Kory ») |
| headline-md | 20 / 28 | 600 | Titres de section (« Mes cagnottes ») |
| title | 17 / 24 | 600 | Nom d'un contact ou d'un groupe, titre de carte |
| body-lg | 16 / 24 | 400 | Texte des bulles, corps de texte |
| label-md | 15 / 20, +0,1 | 500 | Libellés de boutons |
| body-sm | 14 / 20 | 400 | Aperçus, sous-titres |
| caption | 12 / 16, +0,2 | 400 | Heures, métadonnées, pastilles |
| overline | 11 / 16, +0,6, MAJUSCULES | 500 | Surtitres (« BONJOUR », « ÉPARGNE SOLIDAIRE ») |

- Les montants et les durées utilisent les **chiffres tabulaires**, pour que les colonnes s'alignent.
- Un montant est plus gros que son libellé : « 15 000 » en 40 pt, « FCFA » en 20 pt terre cuite.
- Aucune taille de texte n'est figée : le réglage de taille de police du téléphone est respecté.
- **Emoji :** un message fait seulement de 1 à 3 emoji s'affiche en grand, comme sur WhatsApp : 48 pt pour un, 40 pour deux, 32 pour trois.

### 2.3 Formes

| Élément | Rayon |
|---|---|
| Carte (`AppRadius.card`) | **12** (`rounded-xl` des maquettes) |
| Tuile interne (dans une carte) | 8 |
| Bulle de message | 16 |
| Bouton, pastille, filtre, champ de recherche | **pastille** (rayon complet) |
| Volet du bas | 24 en haut |
| Avatars, ronds d'icône, boutons flottants | cercle |

### 2.4 Profondeur

Aucune ombre diffuse lourde : sur les téléphones d'entrée de gamme, elles font chuter la fluidité. On utilise trois niveaux seulement.

| Niveau | Valeur | Usage |
|---|---|---|
| `AppElevation.subtle` | 0 1 px 2 px, `#1A1615` à 8 % | Cartes, fils de discussion, recherche |
| Bouton principal | ombre chaude terre cuite à 25 % | Bouton plein d'action |
| `AppElevation.prominent` | 0 4 px 12 px à 10 % | Bouton flottant |

Les cartes **n'ont pas de filet** : c'est l'ombre d'un point qui les détache du fond crème. Seule la bulle reçue garde une bordure, parce qu'elle est blanche sur un fond presque blanc.

### 2.5 Iconographie

- Icônes Material, en version contour par défaut ; la version pleine marque l'état actif (onglet, épingle).
- Les icônes d'un module sont posées dans un rond terre cuite clair (`ModuleBadge`).
- Pour représenter une personne : sa photo, sinon ses initiales sur fond teinté, jamais une icône générique.

### 2.6 Mode sombre

Le mode sombre est implémenté : les mêmes jetons, avec leurs valeurs sombres, sur un fond ébène `#1A1615`. Il se règle dans Réglages → Apparence (Système / Clair / Sombre) ; par défaut, l'app suit le téléphone.

---

## 3. Grille et espacements

- La grille est en **4 / 8 pt** : 4, 8, 12, 16, 24, 32.
- Marges d'écran : **16**.
- Espacements internes :
  - fil de discussion : 14 ;
  - carte : 16 à 20 ;
  - section : 16 entre deux cartes de l'Accueil.
- Cibles tactiles : **44 × 44 pt minimum** (avatar de la barre du haut, ronds d'action, bouton « + »).
- L'écran de référence est un téléphone de 375 à 390 pt de large ; tout doit tenir à 320 pt.
- Les actions principales sont dans le tiers bas de l'écran (bouton flottant, pied d'écran, barre de saisie).

---

## 4. Composants

### 4.1 Boutons

| Composant | Aspect | Usage |
|---|---|---|
| **Principal** (`ModuleActionButton`, `FilledButton`) | Pastille terre cuite pleine, 52 pt, texte blanc 16/600, ombre chaude | L'action de l'écran : Envoyer, Créer une cagnotte, Contribuer |
| **Secondaire** (`ModuleQuietButton`, `OutlinedButton`) | Pastille blanche ou beige, sans filet, texte terre cuite | Rejoindre, Journal, Envoyer une ordonnance |
| **Texte** | Terre cuite 600 | « Tout voir › », liens |
| **Rouge** | Fond rouge, texte blanc | Supprimer mon compte, Supprimer le groupe |
| **Flottant** | Rond terre cuite 56 pt, icône blanche | Nouvelle discussion, Déclarer une contribution |
| **Rond d'action** | Rond beige 44 pt | Recherche et notifications sur l'Accueil |

Les libellés passent sur deux lignes plutôt que d'être coupés. Un bouton dont le texte ne tiendrait pas devient une icône avec une info-bulle.

### 4.2 Cartes et tuiles

- **Carte** (`ModuleCard`) : blanche, rayon 12, ombre d'un point, marge interne 16.
- **Carte de section de l'Accueil** :
  - l'en-tête est intégré : rond teinté de 32 pt, titre 17/600, « · sous-titre » 12 pt, puis « Tout voir › » ;
  - la carte Discussions est **entièrement terre cuite**, avec un texte crème.
- **Tuile interne** : beige (ou noire à 10 % sur la carte terre cuite), rayon 8, marge interne 12.

### 4.3 Pastilles et filtres

- **Filtre** : 32 pt de haut, en pastille, texte 12/500.
  - inactif : fond beige, texte taupe ;
  - actif : fond `#F5DCCB`, texte terre cuite foncé.
- **Statut** (« Cagnotte en cours », « Mode preuve », « Clôture le 2 nov. ») : petite pastille de couleur de sens sur un fond clair.
- **Compteur de non-lus** : rond terre cuite de 20 pt, chiffre blanc 11/700.

### 4.4 Champs

- **Recherche** : pastille blanche de 44 pt, ombre d'un point, loupe à gauche, sans bordure.
- **Champ de formulaire** : rempli de blanc, rayon 24, sans bordure, indication en `textMuted`.
- **Code (OTP, PIN)** : grands chiffres tabulaires espacés.

### 4.5 Avatars

- Tailles : 32 (barre du haut), 44 (Accueil), 48 (listes), 72 à 80 (profil).
- Sans photo, initiales 17/600 sur fond terre cuite clair.
- **Anneau de statut** : un anneau cuivre autour de l'avatar signale un statut non vu.
- Le point de présence (en ligne) apparaît selon la confidentialité choisie par la personne.
- **Badge** : le badge certifié se place après le nom et n'est jamais coupé, même si le nom est tronqué. Celui de Baba est **or**.

### 4.6 Barre du haut (`PokouAppBar`)

- Fond crème, sans ombre, titre Inter 22/600.
- À gauche : le logo Pokou (rond terre cuite clair) ou le retour.
- À droite : les actions de l'écran, puis la photo de profil, qui **ouvre le profil**.

### 4.7 Barre de navigation basse

- Pleine largeur et blanche, séparée par un filet d'un point, sans ombre.
- Onglet actif : icône pleine et libellé terre cuite, plus un **trait de 2 pt au-dessus** (visible au soleil, et pas seulement par la couleur).
- Les libellés font 11 pt quand l'onglet est actif, 10 pt sinon.

### 4.8 Volets, dialogues et messages courts

- Volet du bas : blanc, rayon 24 en haut, poignée visible.
- Dialogue : rayon 12, titre 20/600.
- Message court (snackbar) : flottant et arrondi.

### 4.9 Encadrés

Un encadré est un fond clair, une icône et une phrase :
- **ambre** pour une attention (« Pokou ne te demandera jamais ton code PIN… ») ;
- **rouge** pour une alerte (« Cette action est définitive. ») ;
- **vert** pour un succès ;
- **bleu** pour une information ;
- **beige** pour un contenu neutre (« Bientôt : Kory, Honam, Assimé »).

---

## 5. Architecture et navigation

### 5.1 Deux formes d'application selon le pays

La forme dépend des modules ouverts dans le pays de l'utilisateur, que le serveur renvoie (`/config/country`).

| Forme | Onglets |
|---|---|
| **Complète** (Togo, Côte d'Ivoire) | **Accueil · Discussions · Kory · Honam · Plus** |
| **Lot 1 « Discussions d'abord »** (seulement la messagerie) | **Discussions · Statuts · Appels · Réglages** |

- Les écrans sont les mêmes dans les deux formes ; seuls les éléments des modules fermés sont masqués.
- L'onglet actif est retenu par son identité, et chaque onglet garde sa position de défilement.

### 5.2 Plus / Réglages

On y trouve :
- la carte profil ;
- Pokou certifié ;
- « Devenir coursier Honam » ;
- les services (Statuts, Appels, Assimé, Modules, Diffusions) ;
- les réglages : Compte et sécurité, Confidentialité, Notifications, Stockage, Apparence, Langue, Aide et support, À propos.

### 5.3 Liens profonds

Toucher un lien Pokou ouvre directement l'application sur le bon écran. Sans l'application, une page web propose de l'installer.

| Lien | Ouvre |
|---|---|
| `/g/CODE` (ou `/invite/group/CODE`) | Rejoindre un groupe |
| `/c/CODE` | Une communauté |
| `/channel/…` | Une chaîne ou une publication |
| `/k/CODE` (ou `/kory/join/CODE`) | Rejoindre une cagnotte puis l'ouvrir |
| `/kory/{id}`, `/honam/order/{id}` | Une cagnotte, une commande |

Tant qu'aucun domaine court n'est choisi, l'hôte reste le domaine de l'API.

### 5.4 Transitions

- L'écran qui arrive glisse sur un dixième de la largeur en apparaissant en fondu, avec la courbe `fastOutSlowIn` : rapide au départ, il se pose doucement.
- Il n'y a ni zoom ni ombre ; l'animation reste fluide sur un téléphone de 2 Go de mémoire.

---

## 6. Écrans principaux

### 6.1 Accueil (APP-1)

1. **Barre du haut** : logo, « Accueil », photo de profil (qui ouvre le profil).
2. **Salutation** : surtitre « BONJOUR • » (point terre cuite), prénom en 28/600, ronds beiges Recherche et Notifications.
3. **Carte Discussions** (terre cuite) : les deux dernières discussions, en tuiles plus sombres (avatar, nom, aperçu, non-lus). **Toucher une tuile ouvre directement la discussion.**
4. **Carte Kory · Cagnottes & tontines** : la cagnotte active (barre de progression, « Total confirmé »), ou une incitation à en créer une.
5. **Carte Honam · Pharmacies & livraison** : la commande en cours, ou « Envoyer une ordonnance ».
6. **Ligne Assimé · Petites annonces** : rond bleu, texte, flèche ronde terre cuite. Elle ouvre Assimé, avec un bouton retour.

Tirer vers le bas rafraîchit l'écran. Les cartes ne s'affichent que pour les modules ouverts dans le pays.

### 6.2 Discussions (APP-2)

1. **Barre du haut** : titre, Modules, Diffusions, photo de profil.
2. **Recherche** en pastille blanche.
3. **Bande des statuts** : « Mon statut » avec un « + », puis les contacts qui ont un statut non vu.
4. **Filtres** : Toutes · Non lues (avec leur nombre) · Favoris · Groupes.
5. **Invitations de groupe** en tête (une invitation vit 72 heures), puis la ligne **Archivées**.
6. **Liste continue** des fils, séparés par un filet d'un point. Chaque fil affiche :
   - l'avatar (48) ;
   - le nom 17/600 et son badge ;
   - l'épingle terre cuite ;
   - l'heure, en terre cuite s'il y a des non-lus ;
   - l'aperçu 14 pt (« Toi : … », « Maman : … », « écrit… » en terre cuite) ;
   - les pastilles de contexte (Cagnotte en cours, Mode preuve) ;
   - le compteur de non-lus.
7. **Pied de liste** : « 🔒 Tes discussions sont chiffrées de bout en bout. »
8. **Bouton flottant** « Nouvelle discussion ».

Un appui long ouvre le menu : épingler, favori, archiver, sourdine, supprimer.

### 6.3 Conversation à deux (APP-2b)

- **En-tête** : avatar, nom et badge, présence ou « écrit… », appel audio, appel vidéo, menu.
- **Canevas crème** :
  - repères de date ;
  - messages système centrés ;
  - mes bulles en sable rosé à droite, les bulles reçues blanches à gauche ;
  - heure et coches dans la bulle (une coche grise = envoyé, deux = remis, deux bleues = lu).
- **Contenus** : texte (liens, numéros et mentions cliquables, aperçu de lien), photos, vidéos, documents, notes vocales (onde et durée), position, carte de contact, sondage, autocollants, emoji en grand.
- **Barre de saisie** :
  - joindre (document, galerie, vidéo, GIF, appareil photo, avec la note « Photos et vidéos sont compressées avant l'envoi ») ;
  - champ de texte ;
  - emoji / autocollants ;
  - micro, qui devient Envoyer quand le champ n'est plus vide.
- **Note vocale** : appui long pour enregistrer, glisser vers le haut pour verrouiller, vers la gauche pour annuler.
- **Panneau emoji / autocollants** : il prend exactement la place du clavier, avec trois onglets (Emoji · GIF · Autocollants), la recherche et les teintes de peau.
- **Bandeau de sécurité** : « 🔒 Chiffré de bout en bout : personne d'autre, pas même Pokou, ne peut lire ces messages. »

### 6.4 Conversation de groupe (DIS-1)

C'est la même conversation que la discussion à deux, avec en plus :
- le nom de l'auteur au-dessus de chaque bulle reçue ;
- les mentions @ ;
- la bannière du mode preuve quand il est actif.

**Menu du groupe** (selon le rôle) :
- mode preuve, export PDF de la preuve ;
- nom et photo : les administrateurs, ou tous les membres si le groupe l'autorise ;
- **Gérer le groupe** ;
- lien d'invitation ;
- liste des membres : rôle, promouvoir, retirer, et **toucher un membre pour lui écrire en privé** ;
- ajouter des membres, quitter le groupe ;
- supprimer le groupe (créateur seulement).

**Gérer le groupe (DIS-26)** :
- *Autorisations* :
  - Modifier le nom et la photo (tous les membres ou les administrateurs) ;
  - Envoyer des messages (tous ou les administrateurs) ;
  - Approuver les nouveaux membres.
- *Messages éphémères* : désactivés, 24 h, 7 jours ou 90 jours.
- *Demandes d'entrée* : Accepter ou Refuser.

### 6.5 Statuts (STA)

- **Liste** : « Mon statut » (« Touche pour ajouter un statut »), statuts récents et vus, accès à « Qui voit mes statuts ».
- **Lecture** :
  - plein écran noir avec barres de progression ;
  - toucher à droite ou à gauche pour passer au suivant ou au précédent ;
  - champ « Répondre à {nom}… » : la réponse arrive **en privé**, chiffrée, dans la discussion à deux, et la lecture se met en pause pendant la saisie ;
  - sur mes propres statuts : « Vu par N » et Mettre en avant.
- **Qui voit mes statuts** : Mes contacts, Mes contacts sauf…, Seulement…, Personne.

### 6.6 Appels

- **Appel sortant** :
  - écran plein ;
  - tonalité de retour ;
  - micro, caméra, retourner la caméra, haut-parleur, ajouter un participant, raccrocher ;
  - chronomètre dès que la communication est établie ;
  - indicateur « chiffré ».
- **Appel entrant** :
  - nom, photo et badge, sonnerie Pokou (sur le volume de sonnerie), vibration ;
  - Refuser ou Accepter ;
  - application fermée, c'est une notification d'appel plein écran qui sonne.
- **Quitter l'écran d'appel** : l'appel continue ; un **bandeau « Appel en cours »** en haut de l'application permet d'y revenir.
- **Appel vidéo et Accueil du téléphone** : l'appel se réduit en **fenêtre flottante** (Picture-in-Picture).
- **Double appel** :
  - pendant un appel, un nouvel appel **vibre sans sonner** ;
  - l'écran indique « Tu es déjà en appel. Refuser le garde ; accepter le termine. » ;
  - le bouton devient **« Terminer et accepter »**.
- **Appel téléphonique ou WhatsApp en cours** : décrocher un appel Pokou le **met en attente** (intégration au système d'appels d'Android).
- **Appel de groupe** :
  - grille des participants, avec mise en avant de celui qui parle et indicateurs micro et caméra ;
  - un membre qui ne peut pas recevoir la clé de chiffrement n'est pas appelé, mais n'empêche plus l'appel des autres.
- **Journal d'appels** : entrants, sortants et manqués, filtre « Manqués », rappel en un geste.

### 6.7 Kory

1. Surtitre « ÉPARGNE SOLIDAIRE », titre « Kory », pastille « Cagnottes & tontines ».
2. **Résumé** (carte beige) : « Tes contributions confirmées en … », montant en grand avec « FCFA » en terre cuite, rond tirelire, et la phrase « Pokou ne touche pas l'argent : chacun verse depuis son wallet. »
3. Le bouton principal **Créer une cagnotte**, puis Rejoindre et Journal.
4. « Mes cagnottes · N actives » : une carte par cagnotte (rond d'icône, titre, organisateur, échéance, progression, « Total confirmé »).
5. **Écran d'une cagnotte** :
   - progression, journal des contributions (déclarée, confirmée, refusée) ;
   - bouton flottant **Déclarer une contribution** (icône) ;
   - le collecteur confirme ou refuse ;
   - Partager envoie le texte, le code et le lien court `/k/CODE`.
6. **Tontine** : tour, bénéficiaire du mois, « Contribuer → ».

S'il n'y a aucune cagnotte, un état vide guide l'utilisateur, avec **Créer une cagnotte**.

### 6.8 Honam (pharmacie)

- **Parcours patient** :
  1. envoyer la photo de l'ordonnance ;
  2. attendre le devis ;
  3. recevoir le devis ;
  4. payer la pharmacie de wallet à wallet ;
  5. paiement signalé ;
  6. livraison suivie sur une carte, puis code de remise au coursier.
- Aucun nom de médicament n'est affiché sur l'Accueil ni dans les notifications.
- **Coursiers** : candidature, mode coursier, courses, packs.
- L'espace **officine** est un site web séparé, au vouvoiement.

### 6.9 Assimé (petites annonces)

- Recherche, catégories, annonces près de chez toi, fiche d'annonce, Publier.
- Contacter le vendeur ouvre une **discussion** : il n'y a ni panier ni paiement en ligne.
- Mes annonces, favoris, mise en avant, avis sur le vendeur.

### 6.10 Baba (assistant IA)

- Fil de discussion épinglé en tête des Discussions, avec un badge or « IA ».
- Il répond via les modèles de langage de l'API ; sans modèle disponible, il répond à partir de la FAQ.
- Baba ne lit pas les autres discussions et ne demande jamais un code.
- **Aide et support** (REG-10) : recherche dans l'aide, Demander à Baba, questions fréquentes dépliables, Écrire au support.

### 6.11 Compte et sécurité

Profil (photo, nom, « à propos »), puis :
- **Code PIN** (vérification en deux étapes) ;
- **Changer de numéro** (REG-4) : ancien numéro masqué, nouveau numéro, choix « Prévenir mes contacts », code envoyé au nouveau numéro ;
- **Appareils connectés** ;
- **Supprimer mon compte** (REG-7) : ce qui est supprimé, ce qui reste, puis confirmation en retapant son numéro ;
- l'encadré ambre « Pokou ne te demandera jamais ton code PIN… ».

**Confidentialité** : dernière connexion, en ligne, photo, infos, accusés de lecture, qui peut m'ajouter aux groupes, contacts bloqués.

**À propos** : version, sens des noms, conditions et confidentialité (avec un encadré « L'essentiel » en quatre phrases), licences.

### 6.12 Inscription et connexion

1. **Bienvenue et numéro** :
   - « Nouveau ou déjà inscrit, c'est le même chemin » ;
   - indicatif du pays, puis « Ton numéro de mobile » ;
   - conditions annoncées juste avant le bouton **Accepter et continuer**.
2. **Saisis le code** : « Envoyé par SMS au … », renvoi possible après un compte à rebours, nombre d'essais restants en cas d'erreur.
3. **Ton code PIN** (si activé), avec le lien **Code PIN oublié ?** : un délai de 7 jours, qu'une connexion avec le PIN annule (protection contre le vol de carte SIM).
4. **Profil** : nom (et photo plus tard).
5. **Contacts** : les contacts déjà sur Pokou sont retrouvés à partir du répertoire, même ceux enregistrés sans nom.

---

## 7. États, temps réel et hors ligne

| Situation | Ce que voit l'utilisateur |
|---|---|
| **Première ouverture** | Rond de chargement, seulement s'il n'y a rien en cache |
| **Ouvertures suivantes** | Le cache local s'affiche instantanément, le réseau le met à jour ensuite (pas d'écran d'attente) |
| **Hors ligne** | Bandeau « Tu verras ce qui est déjà sur ce téléphone… » ; les envois sont mis en file et partent au retour du réseau |
| **Message en cours d'envoi** | Horloge dans la bulle ; en cas d'échec, une icône d'erreur et « Réessayer » |
| **Message pas encore déchiffrable** | « ⏳ En attente de ce message… ». Le téléphone de l'expéditeur le renvoie automatiquement, puis la bulle se remplit |
| **Pièce jointe illisible** | « Pièce jointe chiffrée illisible sur ce téléphone. » |
| **Liste vide** | Un état vide qui guide, avec une action (« Commence une discussion », « Créer une cagnotte », recherches récentes) |
| **Erreur réseau** | Phrase courte (« Vérifie ta connexion et réessaie. »), sans jargon |

**Temps réel** : ces éléments se mettent à jour sans rafraîchir, via WebSocket :
- messages, réactions, modifications et suppressions ;
- invitations, membres et réglages de groupe, groupe supprimé ;
- statuts ;
- profils (nom, photo, « à propos ») ;
- contacts qui rejoignent Pokou ;
- cagnottes Kory, commandes Honam.

Après une coupure, les événements manqués sont rattrapés. Quand l'application est fermée, ce sont les notifications push qui prennent le relais.

---

## 8. Sécurité rendue visible

- **Chiffrement de bout en bout** :
  - messages à deux, groupes, statuts, pièces jointes, appels de groupe ;
  - appels à deux quand une session chiffrée existe ;
  - le serveur ne voit que du chiffré, et l'interface le dit en une phrase.
- **Changement de clé d'un contact** : « La clé de sécurité de {nom} a changé (nouveau téléphone ou réinstallation). En cas de doute, vérifie avec {nom}. »
- **Mode preuve** (Pokou certifié) :
  - bannière permanente en tête de la discussion ;
  - les messages supprimés ou modifiés restent visibles, barrés ;
  - export en PDF.
- **Badge certifié** : il s'affiche après le nom, partout. Un compte certifié est affiché sous **son** nom, même chez qui l'a enregistré autrement.
- **Anti-arnaque** :
  - Pokou ne demande jamais un code SMS, un PIN ou un paiement, et c'est rappelé dans Compte et sécurité, l'aide et Baba ;
  - un message d'un inconnu est signalé comme tel.

---

## 9. Notifications, sons et vibrations

- **Messages** : canal « messages » en priorité haute. Les notifications sont regroupées par conversation, avec réponse rapide depuis la notification ; le contenu est déchiffré sur le téléphone.
- **Appels** : canal « appels » en priorité maximale, avec la **sonnerie Pokou** sur le flux sonnerie (elle respecte le mode silencieux et « Ne pas déranger »), la vibration et une notification plein écran.
- **Retour haptique léger** : envoi d'un message, réception d'une réponse de Baba.
- **Appel en double** : vibration seule.

---

## 10. Accessibilité, langues et ton

- **Langues** : français (référence), anglais, espagnol, italien, russe, arabe. Toutes les chaînes passent par les fichiers de traduction ; les noms Pokou, Kory, Honam et Assimé ne se traduisent pas.
- **Contraste** : le texte courant respecte au moins le seuil AA (4,5:1), y compris sur les deux bulles, et des tests le vérifient.
- **Lecteurs d'écran** : chaque bouton-icône a une info-bulle ou une étiquette, et des tests le vérifient.
- **Taille de texte** : le réglage du téléphone est respecté. Les textes longs passent à la ligne au lieu d'être coupés.
- **Couleur et forme** : un état n'est jamais porté par la couleur seule (trait au-dessus de l'onglet actif, icônes d'état).
- **Ton** : tutoiement, phrases courtes, vocabulaire du quotidien (« wallet », « cagnotte », « coursier »), sans jargon technique.

---

## 11. Écarts connus et pistes

- **Liens** : il manque un domaine court pour les liens partagés. Les chemins sont déjà courts (`/k/`, `/g/`), mais l'hôte reste celui de l'API.
- **Écrans à aligner sur les maquettes** : les écrans Honam patient (PAT), mode preuve (PRV-5b) et suivi sur carte (SUI-1) n'ont pas encore été repris écran par écran.
- **Conformité textuelle au cahier v3.4** : environ 38 % des textes correspondent mot pour mot. Les lots 2 et 3 (Kory avancé, coursiers, officine) restent à reprendre.
- **Typographie** : réduire le nombre de tailles et de graisses encore codées en dur dans certains écrans anciens, pour se rapprocher de la règle « 4 tailles, 2 graisses ».
- **Recherches récentes** : elles ne sont gardées que pendant la session. Les conserver d'une ouverture à l'autre demanderait un petit stockage local.
