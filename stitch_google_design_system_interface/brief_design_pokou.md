Brief pour le design · Pokou 1.25

# Pokou, expliqué à un designer

Ce que l'application montre aujourd'hui, les règles qui tiennent l'ensemble, et les endroits où un regard de designer ferait le plus de différence. Tout ce qui suit est implémenté dans l'app Flutter et vérifiable sur un téléphone.

Android et iOS (Flutter) 6 langues dont l'arabe Mode clair et sombre Togo et Côte d'Ivoire d'abord

[Le produit](#produit) [Principes](#principes) [Couleurs](#couleurs) [Typographie](#typo) [Formes et profondeur](#formes) [Composants](#composants) [Écrans](#ecrans) [États](#etats) [Contraintes](#contraintes) [À améliorer](#ameliorer) [Sources](#sources)

1 · Le produit

## Une messagerie qui porte des services du quotidien

Pokou est d'abord une messagerie chiffrée de bout en bout (discussions, groupes, statuts, appels). Autour d'elle, trois services portent des noms africains :

### Kory

Le cauris. Cagnottes et tontines entre proches. Pokou ne touche jamais l'argent : chacun verse depuis son wallet et l'organisateur confirme.

### Honam

« Aide-moi » en éwé. On photographie une ordonnance, les pharmacies proches envoient un devis, un coursier livre.

### Assimé

« Au marché ». Petites annonces près de chez soi. Contacter un vendeur ouvre une discussion, sans panier ni paiement en ligne.

S'y ajoutent **Baba**, un assistant IA épinglé en tête des discussions, et **Pokou certifié**, un badge pour les comptes vérifiés avec un « mode preuve » qui garde les messages supprimés visibles.

**Pour qui :** des familles, des collègues, des associations et des commerçants en Afrique de l'Ouest, souvent sur un Android d'entrée de gamme (2 Go de mémoire), avec un réseau irrégulier et une lumière vive en extérieur.

**Selon le pays,** l'app prend deux formes : complète (onglets Accueil · Discussions · Kory · Honam · Plus) ou « discussions d'abord » (Discussions · Statuts · Appels · Réglages) là où les services ne sont pas encore ouverts.

2 · Principes

## Six règles qui arbitrent les choix

### La confiance d'abord

Le chiffrement, le badge certifié et le mode preuve sont toujours visibles et expliqués en une phrase. Partout où il y a un montant, on rappelle que Pokou ne touche pas l'argent.

### Chaleur africaine, sans folklore

Terre cuite, crème et or. Pas de motifs wax plaqués : la chaleur vient de la palette, des noms et du ton.

### Fluide sur un petit téléphone

Pas de flou d'arrière-plan, ombres légères, transitions courtes. Les listes s'affichent depuis le cache local avant le réseau.

### Accès direct

Une bulle de discussion ouvre la discussion, une notification ouvre la conversation, un lien ouvre le bon écran. Aucun écran intermédiaire inutile.

### Rien ne reste muet

Chargement, vide, erreur, hors ligne, message en attente, message illisible : chaque état a une phrase, et si possible une action.

### On tutoie

Phrases courtes, mots du quotidien (wallet, cagnotte, coursier), jamais de jargon technique. Seul l'espace web des pharmacies vouvoie.

3 · Couleurs

## Palette « Terre de Confiance », version affinée

Répartition visée : environ 60 % de crème et de blanc, 30 % d'encre et de beige, 10 % de terre cuite. Le rouge, le vert, le bleu et l'ambre ne servent qu'à dire quelque chose.

### Surfaces et encres

**Fond crème**#FBF7F2

**Surface (cartes)**#FFFFFF

**Beige (tuiles, filtres)**#F3EAE1

**Filet**#EADED2

**Encre**#1A1615

**Encre secondaire**#6B5E57

**Encre discrète**#8C7D73

### Marque

**Terre cuite (action)**#A4512A

**Terre cuite foncée**#7F3D1E

**Terre cuite claire**#F7E2D4

**Or (certifié, Baba)**#D4AF37

**Dégradé marque**#AD5A31 → #8B4221

**Dégradé accueil**#F8E8DD → #F3E9DF

**Dégradé certifié**#3D3025 → #211B17

### Couleurs de sens

**Succès, confirmé**#1E7A46

**Attention, en attente**#8A5A00

**Erreur, irréversible**#B3261E

**Information, Assimé**#245C9E

**Double coche « lu »**#53BDEB

Le violet est interdit pour l'IA : Baba utilise l'ambre (#D97706). Le bleu des coches ne sert qu'à « lu ». En mode sombre, le fond devient ébène #1A1615, les surfaces #2A2320 et l'action passe à #E8A57C avec un texte ébène.

4 · Typographie

## Une seule famille : Inter

Inter est embarquée dans l'app. Elle couvre les lettres éwé, mina et kabiyè (ɖ ɛ ƒ ɣ ŋ ɔ ʋ) et l'espace fine des montants. L'arabe passe par Noto Sans Arabic. La taille de texte du téléphone est toujours respectée.

Display 32 / 700Parrain

Section 20 / 700Que veux-tu faire ?

Titre 17 / 600Famille Koffi

Corps 16 / 400On se voit dimanche chez Maman ?

Aperçu 14 / 400Toi : Merci Yao, je note pour lundi.

Légende 12 / 40017:35 · 2 non lus

Surtitre 11 / 700BONJOUR · SAM. 7 NOV.

Montant75 000 FCFA

- Les montants et les durées utilisent des chiffres tabulaires.
- Un message fait seulement de 1 à 3 emoji s'affiche en grand (48, 40 puis 32 pt), comme sur WhatsApp.
- Les textes longs passent à la ligne au lieu d'être coupés ; un bouton trop long devient une icône avec une info-bulle.

5 · Formes et profondeur

## Des cartes douces, des actions en pastille

| Élément | Rayon |
| --- | --- |
| Carte | 18 pt |
| Carte d'accueil (salutation) | 22 pt |
| Tuile dans une carte | 13 pt |
| Bulle de message (coin d'attache 4) | 15–16 pt |
| Bouton, filtre, recherche, champ | pastille |
| Volet du bas | 24 pt en haut |
| Avatar, rond d'icône, bouton flottant | cercle |

| Ombre | Valeur |
| --- | --- |
| Carte | 0 8 22 rgba(73,50,36,.055) + 0 1 2 rgba(44,31,24,.045) |
| Carte de marque | 0 12 26 rgba(127,61,30,.2) |
| Bouton flottant | 0 10 24 rgba(127,61,30,.3) |
| Bulle | 0 3 10 rgba(44,31,24,.055) |

Grille de 4/8 pt (4, 8, 12, 16, 24, 32). Marges d'écran de 16 pt. Cibles tactiles de 44 × 44 pt minimum. Écran de référence de 375 à 390 pt de large ; tout doit tenir à 320 pt. Les actions principales vivent dans le tiers bas de l'écran.

6 · Composants

## Les pièces qui reviennent partout

Reconstitutions fidèles, en mode clair, des composants tels qu'ils sont codés.

Accueil

BONJOUR •*SAM. 7 NOV.*

Afi

Tout ce qui compte, au même endroit.

Discussions Tout voir ›

FK

**Famille Koffi**Maman : On se voit dimanche ?

2

AS

**Ama S.**Merci pour les photos !

Que veux-tu faire ?

**Kory *· Cagnottes & tontines***

Collecte à plusieurs pour un projet, un événement ou une tontine.

⊕ Créer une cagnotte

Accueil

Discussions

Kory

Honam

Plus

Accueil : salutation, Discussions, services, barre basse

Famille Koffi

Chiffré de bout en bout : personne d'autre, pas même Pokou, ne peut lire ces messages.

On se voit dimanche chez Maman ?17:32

Oui, j'apporte le gâteau.17:35 ✓✓

Parfait, merci !17:36

ToutesNon lues 3FavorisGroupes

Conversation, filtres, boutons principal et secondaire

**Équipe POKOU**Appel de Kanle

**Pokou certifié**Le badge d'identité vérifiée et le mode preuve.

Appel de groupe entrant, carte « certifié »

### Barre du haut

Fond crème, sans ombre. Logo ou retour à gauche, titre 22/600, actions à droite, puis la photo de profil qui ouvre le profil.

### Barre basse

Blanche, filet d'un point. L'onglet actif a une pastille terre cuite claire derrière l'icône, un trait de 2 pt au-dessus et un libellé gras : il se voit au soleil, pas seulement à la couleur.

### Avatars

32 (barre du haut), 44 (accueil), 48 (listes), 72 à 96 (profil, appel). Sans photo : initiales sur fond teinté, jamais une silhouette générique. Un anneau cuivre signale un statut non vu.

### Encadrés

Fond clair, icône, une phrase. Ambre pour l'attention, rouge pour l'irréversible, vert pour le succès, bleu pour l'information, beige pour le neutre.

7 · Écrans

## Ce que contient chaque écran principal

### Accueil

1. Barre du haut avec la photo de profil.
2. Carte de salutation : « BONJOUR • », prénom, date, phrase d'accroche, recherche et notifications.
3. Carte Discussions (terre cuite) : les deux derniers fils ; toucher ouvre la discussion.
4. « En cours » : la cagnotte ouverte et la commande Honam active, seulement s'il y en a.
5. « Que veux-tu faire ? » : une carte par service, avec une action directe.

### Discussions

1. Recherche en pastille blanche.
2. Bande des statuts (« Mon statut » puis les statuts non vus).
3. Filtres : Toutes, Non lues, Favoris, Groupes.
4. Invitations de groupe, puis « Archivées ».
5. Liste continue des fils, séparés par un filet ; bouton flottant « Nouvelle discussion ».

### Conversation

Bandeau de chiffrement, repères de date, mes bulles en dégradé pêche à droite, les reçues blanches à gauche. Texte, photos, vidéos, documents, notes vocales, position, contact, sondage, autocollants. Barre de saisie : joindre, champ, emoji, micro qui devient Envoyer. En groupe : nom de l'auteur, mentions, bannière du mode preuve.

### Appels

Entrant : photo et nom de l'appelant (ou du groupe avec l'appelant en médaillon), Refuser / Accepter. Décrocher ouvre tout de suite l'écran « Connexion… ». En cours : grille des participants, micro, caméra, haut-parleur, ajout, raccrocher ; on peut sortir de l'écran, un bandeau « Appel en cours » permet d'y revenir.

### Kory

Résumé des contributions confirmées (montant en grand, « FCFA » en terre cuite), Créer une cagnotte, Rejoindre, Journal, puis une carte par cagnotte avec progression. Dans une cagnotte : journal des contributions (déclarée, confirmée, refusée) et bouton flottant « Déclarer une contribution ».

### Honam, Assimé, Plus

Honam : ordonnance, devis, paiement de wallet à wallet, suivi de livraison. Assimé : recherche, catégories, fiches, Publier. Plus : carte profil, carte certifiée, services, puis les réglages (compte et sécurité, confidentialité, notifications, apparence, langue, aide).

8 · États

## Ce que voit l'utilisateur quand rien n'est « normal »

| Situation | Ce qui s'affiche |
| --- | --- |
| Première ouverture | Un rond de chargement, seulement si le cache est vide |
| Ouvertures suivantes | Le cache local tout de suite, mis à jour ensuite par le réseau |
| Hors ligne | Bandeau « Tu verras ce qui est déjà sur ce téléphone… » ; les envois attendent le réseau |
| Message en cours d'envoi | Petite horloge dans la bulle ; en cas d'échec, une icône et « Réessayer » |
| Message pas encore lisible | « En attente de ce message… » jusqu'à ce que l'expéditeur le renvoie |
| Liste vide | Une phrase et une action (« Commence une discussion », « Créer une cagnotte ») |
| Erreur réseau | « Vérifie ta connexion et réessaie. » |
| Clé d'un contact changée | « La clé de sécurité de {nom} a changé… En cas de doute, vérifie avec {nom}. » |

9 · Contraintes

## Ce que toute proposition doit respecter

### Technique

- Pas de flou d'arrière-plan ni d'ombre lourde : les téléphones d'entrée de gamme perdent en fluidité.
- Transitions courtes : glissement d'un dixième de largeur et fondu, sans zoom.
- Les emoji décoratifs dans l'interface sont à éviter : leur rendu varie selon les appareils. Préférer des icônes.
- Icônes Material, en contour ; la version pleine marque l'état actif.

### Contenu et accessibilité

- Six langues : français, anglais, espagnol, italien, russe, arabe (écriture de droite à gauche). Prévoir des libellés 30 % plus longs qu'en français.
- Contraste AA (4,5:1) pour le texte courant, vérifié par des tests, y compris sur les deux bulles.
- Un état n'est jamais porté par la couleur seule.
- Les noms Pokou, Kory, Honam, Assimé et Baba ne se traduisent pas.
- Aucun nom de médicament sur l'Accueil ni dans les notifications.

10 · À améliorer

## Où un designer ferait la plus grande différence

Points faibles constatés sur l'app actuelle, du plus visible au plus discret. Chacun est une question ouverte, pas une commande.

### Illustrations des services

Les cartes Kory, Honam et Assimé utilisent une icône Material dans un carré teinté. Une petite famille d'illustrations propres à Pokou (cauris, ordonnance, étal de marché) donnerait de la personnalité à l'Accueil.

### Hiérarchie de l'Accueil

Salutation, Discussions, « En cours » et services s'empilent. Que voir en premier quand on a trois messages non lus, une cotisation à confirmer et une commande en livraison ?

### Logo et icône d'app

Le logo actuel (deux bulles entrelacées) est détaillé et peu lisible à 24 pt. Il faut une version simplifiée pour la barre du haut, l'icône d'app et les notifications.

### Écran d'appel

Fonctionnel mais austère (fond terre cuite uni, deux ronds). Il faut un état « Connexion… » plus rassurant, un retour visuel quand l'autre parle et une mise en page de groupe au-delà de quatre personnes.

### États vides et premiers pas

Les écrans vides ont une phrase et un bouton, sans image. Un nouvel inscrit sans contacts sur Pokou voit beaucoup de vide.

### Mode sombre

Il reprend les mêmes jetons avec des valeurs sombres, sans travail dédié. Les dégradés et la carte terre cuite méritent une version pensée pour le sombre.

### Kory : lisibilité de l'argent

Déclarée, confirmée, refusée : trois états proches visuellement. Ce qui est sûr (confirmé) doit se distinguer d'un coup d'œil de ce qui est seulement déclaré.

### Écrans restants

Le parcours patient d'Honam, le mode preuve et le suivi de livraison sur carte n'ont pas encore été repris dans le style actuel.

Pour proposer : maquettes Figma en 375 pt de large, en clair et en sombre, avec au moins une version en arabe pour vérifier la mise en page de droite à gauche. Les nouvelles couleurs ou tailles s'expriment en jetons (nom + valeur), pour être reprises telles quelles dans `mobile/lib/core/theme/`.

11 · Sources

## Où trouver le reste

| Source | Contenu |
| --- | --- |
| `docs/design-ui-ux.md` | Description complète, écran par écran, de l'app telle qu'elle est codée |
| `mobile/lib/core/theme/` | Les jetons dans le code : couleurs, dégradés, rayons, ombres, thème |
| `pokou-design-tokens.json` | Les jetons d'origine du cahier des charges |
| `Pokou_vues_cahier_v3.4.md` | Le cahier des charges et la liste des écrans (APP-1, DIS-26, REG-4…) |
| `stitch_maquettes_compl_tes_d_interface/` | Les maquettes Stitch « Terre de Confiance » |
| Figma Make « Design professionnel complet » | La maquette dont viennent la palette affinée, les dégradés et les cartes |