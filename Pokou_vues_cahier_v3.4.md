# Pokou — Vues du cahier des charges : widgets et textes

Version 3.4 du cahier des charges · maquette « Pokou – Maquettes d’écrans », version 42 · 5 novembre 2026

Ce fichier reprend chaque vue décrite dans le cahier des charges, dans le même ordre, avec la disposition de ses widgets de haut en bas et ses textes exacts, tels qu’ils figurent dans la maquette. Les fiches du cahier (rôle, contenu, actions, règles) restent la référence fonctionnelle ; ce fichier sert au développement et à la recette des textes.

## Comment lire ce fichier

- Chaque écran mesure 390 × 844 points. Il se lit de haut en bas : **En-tête**, **Contenu** (zone qui défile), **Pied d’écran** (actions fixes en bas), **Barre d’onglets**. Un **Volet du bas** s’ouvre par-dessus l’écran, sur un fond assombri.
- Les retraits montrent l’imbrication : un widget en retrait se trouve à l’intérieur du précédent.
- `|` sépare les textes d’un même widget, dans leur ordre d’affichage (par exemple le nom, puis l’aperçu, puis l’heure d’une ligne de discussion).
- `→ CODE` indique l’écran ouvert par le widget. « (lot 1) » désigne la version allégée de l’écran (section 6.3 du cahier).
- Entre crochets : les éléments non textuels. `[avatar FK]` : initiales dans un cercle ; `[pastille 2]` : compteur ; `[icône : Épinglée]` : icône avec son libellé pour le lecteur d’écran ; `[image : honam-icone]` : image du jeu de visuels ; `[barre 75%]` : barre de progression ; `[interrupteur activé]`.
- `☑` / `☐` : case cochée ou non ; `◉` / `○` : choix sélectionné ou non. `~~texte~~` : message barré, visible en mode preuve.
- **Bouton principal** : terracotta, plein ; **Bouton secondaire** : contour ; **Bouton vert** / **Bouton rouge** : accepter / refuser ; **Lien** : texte terracotta ; **Puce** et **Filtre** : pastilles arrondies, « (sélectionnée) » pour l’état actif ; **Encadré ambre / vert / rouge / bleu / beige** : message d’attention, de succès, d’alerte, d’information ou neutre.
- Les noms, montants et numéros sont fictifs. Aucun numéro complet n’est affiché. Ton : tutoiement pour les utilisateurs et les coursiers, vouvoiement pour les officines.

## Sommaire

- 6.2 Accueil et entrée des modules (7 vues)
- 6.3 Interface du lot 1 : Discussions d’abord (4 vues)
- 8.2 Écrans corrigés (9 vues)
- 9.1 Badge Pokou certifié (1 vue)
- 9.5 Écrans (16 vues)
- 9.6 Écrans des discussions et des appels (27 vues)
- 9.7 Statuts (7 vues)
- 9.8 Pokou certifié Pro : parcours et profil (6 vues)
- 9.9 Réglages, sécurité et changement de téléphone (13 vues)
- 10.3 Écrans de Kory (16 vues)
- 11.1 Parcours de commande (8 vues)
- 11.4 Écrans de l’espace officine (24 vues)
- 11.11 Coursiers : recrutement, mode coursier et packs (29 vues)
- 11.12 Suivi de la course sur une carte (3 vues)
- 12.1 Écrans d’Assimé (24 vues)
- 16.1 Notifications (1 vue)
- 16.2 États vides (4 vues)
- Écrans du lot 1 : différences avec l’application complète (59 écrans)
- Annexe : écrans de la maquette sans fiche dans le cahier

## 6.2 Accueil et entrée des modules

### APP-1 · Accueil

Maquette : `App-1-Accueil` · « Pokou · 1. Accueil »

*Rôle* : page d’arrivée après la connexion ou l’inscription : l’essentiel de chaque service en un coup d’œil.

**Disposition et textes**

- **En-tête**
  - **Image** : pokou-app-icon
  - **Texte** : Bonjour
  - **Titre** : Afi
  - **Bouton icône** : Rechercher → DIS-22
  - **Bouton icône** : Notifications, 2 nouvelles → NOT-1
- **Contenu**
  - **Carte terracotta**
    - **Rangée**
      - **Titre de section** : Discussions
      - **Ligne** : Tout voir → APP-2
    - **Liste**
      - **Élément** : [avatar FK] | Famille Koffi | Maman : On se voit dimanche ? | 17:35 | [pastille 2]
      - **Élément** : [avatar AS] | Ama S. | Merci pour les photos ! | 16:02
  - **Carte**
    - **Rangée**
      - **Titre de section** : Kory · Cagnottes
      - **Ligne** : Tout voir → APP-3
    - **Texte** : Anniversaire de Papa
    - **Texte** : Famille Koffi · clôture le 2 nov.
    - **Indicateur** : [barre 75%]
    - **Texte** : Total confirmé : | 75 000 FCFA | sur 100 000
  - **Carte**
    - **Rangée**
      - **Image** : honam-icone
      - **Titre de section** : Honam · Pharmacies
      - **Ligne** : Tout voir → APP-4
    - **Encadré ambre** : Devis reçu de Pharmacie Démo | 5 600 FCFA, course comprise · à payer avant demain 9 h 46
    - **Bouton secondaire** : Envoyer une ordonnance → PAT-1
  - **Ligne** : Assimé · Petites annonces | Achète et vends près de chez toi → APP-5
- **Barre d’onglets** : Accueil (actif) / Discussions / Kory / Honam / Plus

*Règles* : NAV-08 et NAV-09 ; cartes affichées selon les modules actifs du pays (NAV-01) ; montants Kory en « Total confirmé », jamais en solde (BM-01) ; aucun nom de médicament (HON-04).

### APP-2 · Discussions

Maquette : `App-2-Discussions` · « Pokou · 2. Discussions »

*Rôle* : liste des conversations, porte d’entrée de la messagerie.

**Disposition et textes**

- **En-tête**
  - **Rangée**
    - **Texte** : [image : pokou-bulles] | [image : Pokou]
    - **Bouton icône** : Rechercher un contact, un groupe ou un message → DIS-22
    - **Bouton icône** : Nouvelle discussion → DIS-5
  - **Titre** : Discussions
- **Bande horizontale**
  - **Tuile** : [avatar AK] | Mon statut → STA-3
  - **Ligne** : [avatar MD] | Mensah D. → STA-2
  - **Ligne** : [avatar EK] | Edem K. → STA-1
  - **Ligne** : [avatar AS] | Ama S. → STA-1
  - **Ligne** : [avatar KK] | Kafui K. → STA-1
- **Rangée**
  - **Filtre (sélectionné)** : Toutes
  - **Filtre** : Non lues · 3
  - **Filtre** : Favoris
  - **Filtre** : Groupes
- **Contenu**
  - **Liste**
    - **Ligne** : Archivées | 2 → DIS-12
    - **Ligne** : Baba | [intelligence artificielle] | Pose-moi une question sur Pokou, Kory ou Honam. | [icône : Épinglée] → INS-4
    - **Ligne** : [avatar FK] | Famille Koffi | Maman : On se voit dimanche ? | Cagnotte en cours | 17:35 | [icône : Épinglée] | [pastille 2] → DIS-1
    - **Ligne** : [avatar AS] | Ama S. | On se retrouve samedi ? | 16:05 | [pastille 1] → APP-2b
    - **Ligne** : [avatar CB] | Collègues du bureau | Toi : Merci Yao, je note pour lundi. | Mode preuve | 14:36 → PRV-5
    - **Ligne** : [avatar KA] | Kodjo A. | Toi : Je vois encore ton message. On en reparle ce soir. | Mode preuve | 10:23 → PRV-5b
    - **Ligne** : Pharmacie Démo · Honam | Ton devis est prêt : 5 600 FCFA | Hier → APP-4
    - **Élément** : [avatar AB] | Les Amis de Bè | Réunion samedi à 16 h | 24/10
- **Barre d’onglets** : Accueil / Discussions (actif) / Kory / Honam / Plus

*Règles* : section 9 ; icône et logotype selon la section 7.1 ; données fictives, aucun numéro visible (annexe A, n° 19).

### APP-2b · Discussion à deux

Maquette : `App-2b-Discussion` · « Pokou · 2b. Discussion à deux »

*Rôle* : conversation entre deux personnes ; sa structure vaut pour toutes les conversations, à deux ou en groupe (DIS-1, PRV-4 à PRV-6, PRV-4b, PRV-5b).

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : AS
  - **Titre** : Ama S.
  - **Texte** : en ligne
  - **Bouton icône** : Appel audio → DIS-9
  - **Bouton icône** : Appel vidéo → DIS-10
  - **Bouton icône** : Options de la discussion
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : [icône : Photo] | Coucou ! Tu as bien reçu les photos ? | 16:02
  - **Bulle envoyée** : Ama S. | Photo · Coucou ! Tu as bien reçu les photos ? | Oui, merci ! Elles sont magnifiques. | 16:04 · Lu
  - **Bulle reçue** : On se retrouve samedi ? | 16:05
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier → DIS-2
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale → DIS-4
  - **Bouton icône** : Envoyer

*Règles* : MSG-01 à MSG-03 ; dans une bulle envoyée, texte, heure et accusé en blanc à 100 % (DS-05) ; libellé accessible sur chaque bouton à icône.

### APP-3 · Kory

Maquette : `App-3-Kory` · « Pokou · 3. Kory »

*Rôle* : entrée du module de cagnottes et de tontines.

**Disposition et textes**

- **En-tête**
  - **Titre** : Kory
  - **Texte** : Cagnottes & tontines
- **Contenu**
  - **Carte**
    - **Texte** : Tes contributions confirmées en octobre
    - **Texte** : 15 000 FCFA
    - **Texte** : Pokou ne touche pas l’argent : chacun verse depuis son wallet.
  - **Bouton principal** : Créer une cagnotte → KOR-6
  - **Grille de 2**
    - **Bouton secondaire** : Rejoindre → KOR-10
    - **Bouton secondaire** : Journal → KOR-9
  - **Titre de section** : Mes cagnottes
  - **Carte**
    - **Texte** : Anniversaire de Papa | clôture le 2 nov.
    - **Texte** : Cagnotte · Famille Koffi · 8 contributions confirmées
    - **Indicateur** : [barre 75%]
    - **Texte** : Total confirmé : | 75 000 FCFA | sur 100 000 (75 %)
    - **Puce** : Ta part est confirmée
  - **Carte**
    - **Texte** : Tontine des collègues | Kory Plus · tour 4 sur 10
    - **Texte** : Tontine · Collègues du bureau · bénéficiaire du mois : Yao
    - **Rangée**
      - **Puce** : 10 000 FCFA attendus aujourd’hui
      - **Ligne** : Contribuer → KOR-2
- **Barre d’onglets** : Accueil / Discussions / Kory (actif) / Honam / Plus

*Règles* : section 10 et BM-01 : jamais « Ma cagnotte », « Ajouter de l’argent » ni « Wallet » (annexe A, n° 10 à 12).

### APP-4 · Honam (patient)

Maquette : `App-4-Honam` · « Pokou · 4. Honam »

*Rôle* : entrée du module côté patient.

**Disposition et textes**

- **En-tête**
  - **Image** : honam-icone
  - **Titre** : Honam
  - **Texte** : Pharmacies & livraison
  - **Bouton icône** : Mes commandes → PAT-8
- **Contenu**
  - **Carte terracotta**
    - **Titre de section** : Envoyer une ordonnance
    - **Texte** : Une pharmacie proche t’envoie un devis. Tu la paies depuis ton wallet, un coursier te livre.
    - **Ligne** : Photographier l’ordonnance → PAT-1
  - **Carte**
    - **Texte** : Commande en cours | Devis à payer
    - **Texte** : Pharmacie Démo · 5 600 FCFA, course comprise
    - **Étapes**
      - **Élément** : [barre] | Envoyée (fait)
      - **Élément** : [barre] | Devis (en cours)
      - **Élément** : [barre] | Payée (à venir)
      - **Élément** : [barre] | En route (à venir)
      - **Élément** : [barre] | Livrée (à venir)
    - **Ligne** : Voir le devis et payer → PAT-3
  - **Titre de section** : Pharmacies près de chez toi
  - **Liste**
    - **Élément** : Pharmacie Démo | Ouverte · Tokoin · 1,2 km
    - **Élément** : Pharmacie du Marché | De garde cette nuit · Bè · 2,4 km
  - **Bouton secondaire** : Urgence : appeler les secours | Pokou n’est pas un service d’urgence → APP-4
- **Barre d’onglets** : Accueil / Discussions / Kory / Honam (actif) / Plus

*Règles* : section 11 ; pas de catalogue ni de bouton « + » (annexe A, n° 13) ; urgence en rouge danger (HON-10, DS-06) ; « Aide & Secours » remplacé par « Pharmacies & livraison ».

### APP-5 · Assimé (lot 3)

Maquette : `App-5-Assime` · « Pokou · 5. Assimé (lot 3) »

*Rôle* : entrée des petites annonces, à partir du lot 3.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Assimé
  - **Texte** : Petites annonces
  - **Bouton icône** : Mes annonces → ANN-9
- **Contenu**
  - **Champ** : [champ : « Rechercher une annonce »]
  - **Fond** : voile sombre sur l’écran
  - **Grille de 4**
    - **Bouton secondaire** : Mode → ANN-1
    - **Bouton secondaire** : Beauté
    - **Bouton secondaire** : Maison
    - **Bouton secondaire** : Électronique
  - **Titre de section** : Près de chez toi
  - **Liste**
    - **Carte**
      - **Fond** : voile sombre sur l’écran
      - **Texte** : Sac en pagne tissé
      - **Texte** : 25 000 FCFA
      - **Texte** : Bè · aujourd’hui
    - **Carte**
      - **Fond** : voile sombre sur l’écran
      - **Texte** : Beurre de karité, 1 kg
      - **Texte** : 3 500 FCFA
      - **Texte** : Adidogomé · hier
    - **Carte**
      - **Fond** : voile sombre sur l’écran
      - **Texte** : Téléphone reconditionné
      - **Texte** : 45 000 FCFA
      - **Texte** : Tokoin · hier
    - **Carte**
      - **Fond** : voile sombre sur l’écran
      - **Texte** : Chaise en rotin
      - **Texte** : 18 000 FCFA
      - **Texte** : Agoè · 22/10
  - **Bouton principal** : Publier une annonce → ANN-5
- **Barre d’onglets** : Accueil / Discussions / Kory / Honam / Plus (actif)

*Règles* : section 12 : contact par Discussions, sans panier ni paiement en ligne ; les visuels d’annonce sont des emplacements, remplacés par les photos des vendeurs ; la recherche ouvre ANN-1, une annonce ANN-3, « Publier une annonce » ANN-5, « Mes annonces » ANN-9.

### APP-6 · Plus

Maquette : `App-6-Plus` · « Pokou · 6. Plus »

*Rôle* : profil, services secondaires et réglages.

**Disposition et textes**

- **En-tête**
  - **Titre** : Plus
- **Contenu**
  - **Carte**
    - **Avatar** : AK
    - **Titre de section** : Afi K.
    - **Texte** : +228 90 •• •• 00
    - **Bouton secondaire** : Modifier → INS-3
  - **Ligne** : Pokou certifié | Nom vérifié et mode preuve · essai d’un mois → CRT-1
  - **Bouton secondaire** : Devenir coursier Honam | 1 000 FCFA par course, près de chez toi → COU-1
  - **Liste**
    - **Ligne** : Assimé | Petites annonces → APP-5
    - **Ligne** : Appels → DIS-21
  - **Liste**
    - **Ligne** : Compte et sécurité → REG-3
    - **Ligne** : Notifications → REG-8
    - **Ligne** : Confidentialité → REG-1
    - **Ligne** : Langue | Français → REG-9
  - **Liste**
    - **Ligne** : Aide et support → REG-10
    - **Ligne** : [image : pokou-app-icon] | À propos de Pokou → REG-11
- **Barre d’onglets** : Accueil / Discussions / Kory / Honam / Plus (actif)

*Règles* : pas de compteur d’abonnés (annexe A, n° 18) ; suppression du compte accessible depuis « Compte et sécurité » (AUTH-06).

## 6.3 Interface du lot 1 : Discussions d’abord

### LOT-1 · Discussions (lot 1)

Maquette : `Lot1-1-Discussions` · « Lot 1 · 1. Discussions »

*Rôle* : liste des conversations au lancement, quand seule la messagerie est ouverte dans le pays.

**Disposition et textes**

- **En-tête**
  - **Rangée**
    - **Texte** : [image : pokou-bulles] | [image : Pokou]
    - **Bouton icône** : Statut photo → STA-5 (lot 1)
    - **Bouton icône** : Nouvelle discussion → DIS-5 (lot 1)
- **Ligne** : Rechercher → DIS-22 (lot 1)
- **Rangée**
  - **Filtre (sélectionné)** : Toutes
  - **Filtre** : Non lues · 3
  - **Filtre** : Favoris
  - **Filtre** : Groupes
- **Contenu**
  - **Liste**
    - **Ligne** : Archivées | 2 → DIS-12 (lot 1)
    - **Ligne** : Baba | [intelligence artificielle] | Pose-moi une question sur Pokou. | [icône : Épinglée] → INS-4 (lot 1)
    - **Ligne** : [avatar FK] | Famille Koffi | Maman : On se voit dimanche ? | 17:35 | [pastille 2] → DIS-1 (lot 1)
    - **Ligne** : [avatar AS] | Ama S. | On se retrouve samedi ? | 16:05 | [pastille 1] → APP-2b (lot 1)
    - **Ligne** : [avatar CB] | Collègues du bureau | Toi : Merci Yao, je note pour lundi. | Mode preuve | 14:36 → PRV-5 (lot 1)
    - **Ligne** : [avatar KA] | Kodjo A. | Toi : Je vois encore ton message. | Mode preuve | 10:23 → PRV-5b (lot 1)
    - **Ligne** : [avatar EK] | Edem K. | Photo | Hier → STA-7 (lot 1)
- **Barre d’onglets** : Discussions [pastille 3] (actif) / Statuts / Appels [pastille 1] / Réglages

*Règles* : NAV-10 et NAV-11 ; MSG-13 et MSG-22 ; mêmes composants que APP-2, éléments de module masqués par feature flag (NAV-01).

### LOT-2 · Statuts (lot 1)

Maquette : `Lot1-2-Statuts` · « Lot 1 · 2. Statuts »

*Rôle* : les statuts dans leur propre onglet, comme sur WhatsApp.

**Disposition et textes**

- **En-tête**
  - **Titre** : Statuts
  - **Bouton icône** : Rechercher un statut
- **Contenu**
  - **Ligne** : [avatar AK] | Mon statut | Touche pour ajouter un statut, visible 24 h → STA-3 (lot 1)
  - **Titre de section** : Récents
  - **Liste**
    - **Ligne** : [avatar MD] | Mensah D. | Il y a 12 minutes → STA-2 (lot 1)
    - **Ligne** : [avatar EK] | Edem K. | Il y a 1 heure → STA-7 (lot 1)
    - **Ligne** : [avatar AS] | Ama S. | Aujourd’hui, 08:10 → LOT-2
  - **Titre de section** : Vus
  - **Liste**
    - **Ligne** : [avatar KK] | Kafui K. | Hier, 21:40 → LOT-2
  - **Ligne** : Qui voit mes statuts : Mes contacts → STA-4 (lot 1)
  - **Bouton icône** : Statut texte → STA-3 (lot 1)
  - **Bouton icône** : Statut photo → STA-5 (lot 1)
- **Barre d’onglets** : Discussions [pastille 3] / Statuts (actif) / Appels [pastille 1] / Réglages

*Règles* : MSG-15 et MSG-29 ; ni statut sponsorisé ni lien vers une annonce au lot 1 (ASM-14 s’applique au lot 3).

### LOT-3 · Appels (lot 1)

Maquette : `Lot1-3-Appels` · « Lot 1 · 3. Journal d’appels »

*Rôle* : le journal d’appels, en onglet.

**Disposition et textes**

- **En-tête**
  - **Titre** : Appels
  - **Bouton icône** : Rechercher un appel
- **Rangée**
  - **Filtre (sélectionné)** : Tous
  - **Filtre** : Manqués · 1
- **Ligne** : Nouvel appel | Audio ou vidéo, à deux ou en groupe → DIS-5 (lot 1)
- **Contenu**
  - **Titre de section** : Aujourd’hui
  - **Liste**
    - **Élément**
      - **Avatar** : AS
      - **Texte** : Ama S.
      - **Texte** : Sortant · 4 min 12
      - **Texte** : 16:10
      - **Bouton icône** : Rappeler Ama S. → DIS-9 (lot 1)
    - **Élément**
      - **Avatar** : KK
      - **Texte** : Kafui K. (2)
      - **Texte** : Manqué
      - **Texte** : 15:40
      - **Bouton icône** : Rappeler Kafui K. (2) → DIS-9 (lot 1)
    - **Élément**
      - **Avatar** : FK
      - **Texte** : Famille Koffi
      - **Texte** : Vidéo de groupe · 5 personnes · 18 min
      - **Texte** : 12:05
      - **Bouton icône** : Rappeler en vidéo Famille Koffi → DIS-10 (lot 1)
    - **Élément**
      - **Texte** : +228 9• •• •• 41
      - **Texte** : Inconnu, appel coupé
      - **Texte** : 09:12
      - **Bouton icône** : Rappeler +228 9• •• •• 41 → REG-1 (lot 1)
  - **Titre de section** : Hier
  - **Liste**
    - **Élément**
      - **Avatar** : EK
      - **Texte** : Edem K.
      - **Texte** : Entrant · 12 min
      - **Texte** : 19:22
      - **Bouton icône** : Rappeler Edem K. → DIS-9 (lot 1)
    - **Élément**
      - **Avatar** : KA
      - **Texte** : Kodjo A.
      - **Texte** : Vidéo sortant · 2 min
      - **Texte** : 08:47
      - **Bouton icône** : Rappeler en vidéo Kodjo A. → DIS-10 (lot 1)
- **Barre d’onglets** : Discussions [pastille 3] / Statuts / Appels (actif) / Réglages

*Règles* : MSG-21 et MSG-23 ; même contenu que DIS-21, qui reste dans Plus › Appels dans l’application complète.

### LOT-4 · Réglages (lot 1)

Maquette : `Lot1-4-Reglages` · « Lot 1 · 4. Réglages »

*Rôle* : profil et réglages, à la place de Plus.

**Disposition et textes**

- **En-tête**
  - **Titre** : Réglages
- **Contenu**
  - **Carte**
    - **Avatar** : AK
    - **Titre de section** : Afi K.
    - **Texte** : +228 90 •• •• 00
    - **Bouton secondaire** : Modifier → INS-3 (lot 1)
  - **Ligne** : [icône : Pokou certifié] | Pokou certifié | Nom vérifié et mode preuve · essai d’un mois → CRT-1 (lot 1)
  - **Carte**
    - **Ligne** : Compte et sécurité → REG-3 (lot 1)
    - **Ligne** : Confidentialité → REG-1 (lot 1)
    - **Ligne** : Notifications → REG-8 (lot 1)
    - **Ligne** : Stockage et données | 1,8 Go → REG-2 (lot 1)
    - **Ligne** : Langue | Français → REG-9 (lot 1)
  - **Carte**
    - **Ligne** : Aide et support → REG-10 (lot 1)
    - **Ligne** : [image : pokou-app-icon] | À propos de Pokou → REG-11 (lot 1)
  - **Encadré beige**
    - **Texte** : Bientôt : Kory, Honam, Assimé
    - **Texte** : Cagnottes, pharmacie et petites annonces arrivent ville par ville.
    - **Bouton secondaire** : Me prévenir
- **Barre d’onglets** : Discussions [pastille 3] / Statuts / Appels [pastille 1] / Réglages (actif)

*Règles* : NAV-12 ; seul endroit du lot 1 où les modules sont nommés ; pas de carte « Devenir coursier Honam » avant l’ouverture de Honam dans la ville (HON-40).

## Écrans du lot 1 : différences avec l’application complète

Au lot 1, ces écrans sont les mêmes que dans l’application complète, avec les éléments des modules masqués (NAV-10 et NAV-11). Pour chacun, la liste donne ce qui disparaît (−) et ce qui apparaît (+) par rapport à l’écran d’origine, décrit plus loin dans ce fichier. Les liens restent dans le lot 1 et ramènent aux quatre onglets ; ce changement n’est pas répété.

### INS-1 (lot 1) · Inscription · 1. Bienvenue et numéro

Maquette : `Lot1-Inscription-1-Numero`

- − **Élément** : Cotise en groupe avec Kory
- − **Élément** : Commande à ta pharmacie avec Honam
- + **Élément** : Partage tes statuts, visibles 24 h
- + **Élément** : Garde la preuve de tes échanges

### INS-2 (lot 1) · Inscription · 2. Code

Maquette : `Lot1-Inscription-2-Code`

Identique à INS-2.

### INS-3 (lot 1) · Inscription · 3. Profil, avec Baba

Maquette : `Lot1-Inscription-3-Profil`

Identique à INS-3.

### INS-4 (lot 1) · Inscription · 4. Baba propose les contacts

Maquette : `Lot1-Inscription-4-Baba`

Identique à INS-4.

### INS-5 (lot 1) · Inscription · 5. Contacts retrouvés

Maquette : `Lot1-Inscription-5-Contacts`

Identique à INS-5.

### APP-2b (lot 1) · Pokou · 2b. Discussion à deux

Maquette : `Lot1-App-2b-Discussion`

Identique à APP-2b.

### DIS-1 (lot 1) · Discussions · 1. Discussion de groupe

Maquette : `Lot1-Discussion-1-Groupe`

- − **Ligne** : Cagnotte en cours · Anniversaire de Papa | 75 000 sur 100 000 FCFA · clôture le 2 nov. → KOR-1
- − **Texte** : Edem K.
- − **Texte** : Il manque 25 000 FCFA pour samedi !
- − **Vignette** : Cagnotte Kory | Anniversaire de Papa | [barre 75%] | 75 000 sur 100 000 FCFA confirmés | Contribuer → KOR-1
- − **Texte** : 15:10
- + **Bulle reçue** : Edem K. | Qui s’occupe du gâteau pour samedi ? | 15:10

### DIS-2 (lot 1) · Discussions · 2. Joindre un fichier

Maquette : `Lot1-Discussion-2-Pieces-jointes`

- − **Ligne** : Cagnotte en cours · Anniversaire de Papa | 75 000 sur 100 000 FCFA · clôture le 2 nov. → KOR-1
- − **Tuile** : Cagnotte Kory → KOR-6
- − **Texte** : Photos et vidéos sont compressées avant l’envoi. La cagnotte Kory se crée seulement dans un groupe.
- + **Tuile** : Sondage
- + **Texte** : Photos et vidéos sont compressées avant l’envoi pour économiser tes données.

### DIS-4 (lot 1) · Discussions · 4. Note vocale

Maquette : `Lot1-Discussion-4-Note-vocale`

Identique à DIS-4.

### DIS-5 (lot 1) · Discussions · 5. Nouvelle discussion

Maquette : `Lot1-Discussion-5-Nouvelle`

Identique à DIS-5.

### DIS-6 (lot 1) · Discussions · 6. Nouveau groupe

Maquette : `Lot1-Discussion-6-Nouveau-groupe`

Identique à DIS-6.

### DIS-7 (lot 1) · Discussions · 7. Infos du contact

Maquette : `Lot1-Discussion-7-Infos-contact`

Identique à DIS-7.

### DIS-8 (lot 1) · Discussions · 8. Infos du groupe

Maquette : `Lot1-Discussion-8-Infos-groupe`

- − **Ligne** : Cagnotte en cours · Anniversaire de Papa | 75 000 sur 100 000 FCFA · clôture le 2 nov. → KOR-1

### DIS-9 (lot 1) · Discussions · 9. Appel audio

Maquette : `Lot1-Discussion-9-Appel-audio`

Identique à DIS-9.

### DIS-10 (lot 1) · Discussions · 10. Appel vidéo

Maquette : `Lot1-Discussion-10-Appel-video`

Identique à DIS-10.

### DIS-12 (lot 1) · Discussions · 12. Discussions archivées

Maquette : `Lot1-Discussion-12-Archivees`

Identique à DIS-12.

### DIS-18 (lot 1) · Discussions · 18. Appel de groupe

Maquette : `Lot1-Discussion-18-Appel-groupe`

Identique à DIS-18.

### DIS-22 (lot 1) · Discussions · 22. Rechercher

Maquette : `Lot1-Discussion-22-Recherche`

Identique à DIS-22.

### DIS-24 (lot 1) · Discussions · 24. Aperçu avant envoi

Maquette : `Lot1-Discussion-24-Apercu-photo`

Identique à DIS-24.

### DIS-26 (lot 1) · Discussions · 26. Gérer le groupe

Maquette : `Lot1-Discussion-26-Gerer-groupe`

- − **Texte** : Quitter le groupe ne supprime pas la cagnotte en cours : tes contributions restent dans le journal Kory.
- + **Texte** : En quittant le groupe, tes messages restent chez les autres membres. Les administrateurs sont prévenus.

### DIS-27 (lot 1) · Discussions · 27. Contacts bloqués

Maquette : `Lot1-Discussion-27-Bloques`

Identique à DIS-27.

### STA-2 (lot 1) · Statuts · 2. Voir un statut

Maquette : `Lot1-Statuts-2-Voir`

- − **Puce** : Voir l’annonce · 12 000 FCFA → ANN-3

### STA-3 (lot 1) · Statuts · 3. Créer un statut

Maquette : `Lot1-Statuts-3-Creer`

Identique à STA-3.

### STA-4 (lot 1) · Statuts · 4. Qui voit mes statuts

Maquette : `Lot1-Statuts-4-Confidentialite`

Identique à STA-4.

### STA-5 (lot 1) · Statuts · 5. Statut photo

Maquette : `Lot1-Statuts-5-Photo`

Identique à STA-5.

### STA-7 (lot 1) · Statuts · 7. Réponse privée

Maquette : `Lot1-Statuts-7-Reponse`

Identique à STA-7.

### CRT-1 (lot 1) · Pokou certifié · 1. Offre

Maquette : `Lot1-Badge-1-Offre`

Identique à CRT-1.

### CRT-2 (lot 1) · Pokou certifié · 2. Vérifier et payer

Maquette : `Lot1-Badge-2-Paiement`

Identique à CRT-2.

### CRT-3 (lot 1) · Pokou certifié · 3. Badge actif

Maquette : `Lot1-Badge-3-Actif`

Identique à CRT-3.

### PRV-3b (lot 1) · Mode preuve · 3b. Choisir une discussion

Maquette : `Lot1-Preuve-3b-Choisir`

Identique à PRV-3b.

### PRV-4 (lot 1) · Mode preuve · 4. Activer dans un groupe

Maquette : `Lot1-Preuve-4-Activer`

Identique à PRV-4.

### PRV-4b (lot 1) · Mode preuve · 4b. Activer dans une discussion à deux

Maquette : `Lot1-Preuve-4b-Activer-a-deux`

Identique à PRV-4b.

### PRV-5 (lot 1) · Mode preuve · 5. Conversation

Maquette : `Lot1-Preuve-5-Conversation`

Identique à PRV-5.

### PRV-5b (lot 1) · Mode preuve · 5b. Discussion à deux

Maquette : `Lot1-Preuve-5b-Conversation-a-deux`

Identique à PRV-5b.

### PRV-6 (lot 1) · Mode preuve · 6. Supprimer son message

Maquette : `Lot1-Preuve-6-Supprimer`

Identique à PRV-6.

### PRV-8 (lot 1) · Mode preuve · 8. Exporter la discussion

Maquette : `Lot1-Preuve-8-Exporter`

Identique à PRV-8.

### PRV-9 (lot 1) · Mode preuve · 9. PDF prêt

Maquette : `Lot1-Preuve-9-PDF-pret`

Identique à PRV-9.

### PRV-10 (lot 1) · Mode preuve · 10. Désactiver

Maquette : `Lot1-Preuve-10-Desactiver`

Identique à PRV-10.

### PRO-1 (lot 1) · Pokou certifié Pro · 1. Offre

Maquette : `Lot1-Pro-1-Offre`

- − **Élément** : Le badge Pro sur tes statuts, puis sur tes annonces Assimé
- + **Élément** : Le badge Pro sur ton profil et sur tes statuts

### PRO-2 (lot 1) · Pokou certifié Pro · 2. Ton activité

Maquette : `Lot1-Pro-2-Justificatif`

Identique à PRO-2.

### PRO-3 (lot 1) · Pokou certifié Pro · 3. Vérification en cours

Maquette : `Lot1-Pro-3-Verification`

Identique à PRO-3.

### PRO-5 (lot 1) · Pokou certifié Pro · 5. Profil Pro

Maquette : `Lot1-Pro-5-Profil`

- − **Ligne** : 4,8 | · 37 ventes notées → ANN-20
- − **Ligne** : [icône : Photo de l’annonce] | [icône : Photo de l’annonce] | [icône : Photo de l’annonce] | 12 annonces sur Assimé | Pagnes, sacs, tissus → ANN-3

### REG-1 (lot 1) · Réglages · 1. Confidentialité

Maquette : `Lot1-Reglages-1-Confidentialite`

Identique à REG-1.

### REG-2 (lot 1) · Réglages · 2. Stockage et données

Maquette : `Lot1-Reglages-2-Stockage`

Identique à REG-2.

### REG-3 (lot 1) · Réglages · 3. Compte et sécurité

Maquette : `Lot1-Reglages-3-Compte-securite`

Identique à REG-3.

### REG-4 (lot 1) · Réglages · 4. Changer de numéro

Maquette : `Lot1-Reglages-4-Changer-numero`

- − **Carte** : Ton compte, tes discussions, ton badge Pokou certifié et tes cagnottes Kory te suivent. Un code est envoyé au nouveau numéro.
- − **Encadré ambre** : Si tu es collecteur d’une cagnotte, ton numéro de collecte ne change pas tout seul : modifie-le dans Kory, les membres en seront prévenus.
- + **Carte** : Ton compte, tes discussions et ton badge Pokou certifié te suivent. Un code est envoyé au nouveau numéro.

### REG-5 (lot 1) · Réglages · 5. Activer le code PIN

Maquette : `Lot1-Reglages-5-Code-PIN`

Identique à REG-5.

### REG-7 (lot 1) · Réglages · 7. Supprimer mon compte

Maquette : `Lot1-Reglages-7-Supprimer-compte`

- − **Texte** : Le journal des cagnottes Kory, qui ne s’efface pas

### REG-8 (lot 1) · Réglages · 8. Notifications

Maquette : `Lot1-Reglages-8-Notifications`

- − **Titre de section** : Modules
- − **Interrupteur** : Kory | Engagements, rappels de versement, clôtures | [interrupteur activé]
- − **Interrupteur** : Honam | Devis, livraison, code de remise | [interrupteur activé]
- − **Interrupteur** : Assimé | Alertes de recherche, au plus une par jour | [interrupteur activé]

### REG-9 (lot 1) · Réglages · 9. Langue

Maquette : `Lot1-Reglages-9-Langue`

- − **Texte** : La langue de l’application ne change pas celle de tes messages. Les noms Pokou, Kory, Honam et Assimé restent les mêmes dans toutes les langues.
- + **Texte** : La langue de l’application ne change pas celle de tes messages. Le nom Pokou reste le même dans toutes les langues.

### REG-10 (lot 1) · Réglages · 10. Aide et support

Maquette : `Lot1-Reglages-10-Aide`

- − **Texte** : Pokou touche-t-il mon argent ?
- − **Texte** : Comment devenir coursier Honam ?
- + **Texte** : Comment payer Pokou certifié ?
- + **Texte** : Comment bloquer un inconnu ?

### REG-11 (lot 1) · Réglages · 11. À propos

Maquette : `Lot1-Reglages-11-A-propos`

- − **Texte** : Le sens de nos noms
- − **Texte** : Kory | le cauris
- − **Texte** : Honam | « aide-moi », en éwé
- − **Texte** : Assimé | « au marché », en éwé
- − **Texte** : Wétri | « mois », en éwé
- − **Texte** : ÉPÉ | « année », en éwé
- + **Texte** : Le sens de notre nom
- + **Texte** : Nos prochains services porteront eux aussi des noms venus de langues africaines.

### REG-12 (lot 1) · Réglages · 12. Conditions d’utilisation

Maquette : `Lot1-Reglages-12-Conditions`

- − **Texte** : Pokou ne touche jamais l’argent : cagnottes, pharmacies et coursiers se paient de wallet à wallet.
- − **Texte** : Honam n’est pas un service d’urgence.
- − **Texte** : 3. Kory
- − **Texte** : 4. Honam
- − **Texte** : 5. Assimé
- − **Texte** : 6. Badges payants
- + **Texte** : Pokou est une messagerie : chacun reste responsable de ce qu’il envoie.
- + **Texte** : 3. Badges payants

### REG-13 (lot 1) · Réglages · 13. Politique de confidentialité

Maquette : `Lot1-Reglages-13-Confidentialite-texte`

- − **Texte** : Ton numéro n’est jamais montré à un vendeur ni à un coursier.
- − **Texte** : La position du coursier n’est pas conservée après la livraison.
- − **Texte** : Les annonces sponsorisées sont ciblées par ville, jamais à partir de tes messages.
- + **Texte** : Aucun numéro de téléphone n’est affiché dans les discussions de groupe.
- + **Texte** : Une demande de code secret est repérée sur ton téléphone, sans que Pokou lise le message.

### CNX-1 (lot 1) · Connexion · 1. Code PIN, si activé

Maquette : `Lot1-Connexion-1-PIN`

Identique à CNX-1.

### CNX-2 (lot 1) · Connexion · 2. Bon retour et sauvegarde

Maquette : `Lot1-Connexion-2-Bon-retour`

- − **Texte** : Baba | [intelligence artificielle] | Bon retour, Afi ! J’ai retrouvé ton compte et ta sauvegarde. Tes groupes, tes cagnottes Kory et ton badge te suivent.
- + **Texte** : Baba | [intelligence artificielle] | Bon retour, Afi ! J’ai retrouvé ton compte et ta sauvegarde. Tes groupes, tes discussions et ton badge te suivent.

### CNX-3 (lot 1) · Connexion · 3. Restauration en cours

Maquette : `Lot1-Connexion-3-Restauration`

- − **Bouton icône** : Rechercher un contact, un groupe ou un message → DIS-22
- − **Titre** : Discussions
- − **Barre d’onglets** : Accueil / Discussions (actif) / Kory / Honam / Plus
- + **Bouton icône** : Statut photo → STA-5
- + **Ligne** : Rechercher → DIS-22
- + **Barre d’onglets** : Discussions [pastille 3] (actif) / Statuts / Appels [pastille 1] / Réglages

### DIS-11 (lot 1) · Discussions · 11. Épingler, favoris, archiver

Maquette : `Lot1-Discussion-11-Actions-discussion`

- − **Bouton icône** : Rechercher un contact, un groupe ou un message → DIS-22
- − **Titre** : Discussions
- − **Bande horizontale**
- − **Tuile** : [avatar AK] | Mon statut → STA-3
- − **Ligne** : [avatar MD] | Mensah D. → STA-2
- − **Ligne** : [avatar EK] | Edem K. → STA-1
- − **Ligne** : [avatar AS] | Ama S. → STA-1
- − **Ligne** : [avatar KK] | Kafui K. → STA-1
- − **Ligne** : Baba | [intelligence artificielle] | Pose-moi une question sur Pokou, Kory ou Honam. | [icône : Épinglée] → INS-4
- − **Ligne** : [avatar FK] | Famille Koffi | Maman : On se voit dimanche ? | Cagnotte en cours | 17:35 | [icône : Épinglée] | [pastille 2] → DIS-1
- − **Ligne** : [avatar KA] | Kodjo A. | Toi : Je vois encore ton message. On en reparle ce soir. | Mode preuve | 10:23 → PRV-5b
- − **Ligne** : Pharmacie Démo · Honam | Ton devis est prêt : 5 600 FCFA | Hier → APP-4
- − **Élément** : [avatar AB] | Les Amis de Bè | Réunion samedi à 16 h | 24/10
- − **Barre d’onglets** : Accueil / Discussions (actif) / Kory / Honam / Plus
- + **Bouton icône** : Statut photo → STA-5
- + **Ligne** : Rechercher → DIS-22
- + **Ligne** : Baba | [intelligence artificielle] | Pose-moi une question sur Pokou. | [icône : Épinglée] → INS-4
- + **Ligne** : [avatar FK] | Famille Koffi | Maman : On se voit dimanche ? | 17:35 | [pastille 2] → DIS-1
- + **Ligne** : [avatar KA] | Kodjo A. | Toi : Je vois encore ton message. | Mode preuve | 10:23 → PRV-5b
- + **Ligne** : [avatar EK] | Edem K. | Photo | Hier → STA-7
- + **Barre d’onglets** : Discussions [pastille 3] (actif) / Statuts / Appels [pastille 1] / Réglages

### REG-6 (lot 1) · Réglages · 6. Code PIN oublié

Maquette : `Lot1-Reglages-6-PIN-oublie`

Identique à REG-6.

## 8.2 Écrans corrigés

### INS-1 · Bienvenue et numéro

Maquette : `Inscription-1-Numero` · « Inscription · 1. Bienvenue et numéro »

*Rôle* : première ouverture ; une seule entrée pour créer un compte ou se reconnecter (étape 1 sur 3).

**Disposition et textes**

- **Puce** : Français
- **Contenu**
  - **Titre** : [image : Pokou]
  - **Texte** : Plus qu’une messagerie, une communauté.
  - **Liste**
    - **Élément** : Discute et appelle tes proches
    - **Élément** : Cotise en groupe avec Kory
    - **Élément** : Commande à ta pharmacie avec Honam
  - **Champ** : Ton numéro de mobile
  - **Rangée**
    - **Bouton secondaire** : TG +228
    - **Champ** : [champ : 90 00 00 00]
  - **Texte** : Nouveau ou déjà inscrit, c’est le même chemin : tu reçois un code par SMS.
  - **Carte** : Les personnes qui ont déjà ton numéro dans leurs contacts pourront te trouver sur Pokou.
- **Pied d’écran**
  - **Bouton principal** : Accepter et continuer → INS-2
  - **Lien** : Conditions d’utilisation → REG-12
  - **Lien** : Politique de confidentialité → REG-13

*Règles* : AUTH-01, AUTH-08 et AUTH-09 ; format E.164, validation libphonenumber, erreur sous le champ ; réunit les anciens écrans Bienvenue, Numéro et Conditions ; plus de bouton « Se connecter » : le serveur distingue création et reconnexion après le code ; déclaration d’âge par le bouton, à valider par le juriste (annexe B, n° 4).

### INS-2 · Code

Maquette : `Inscription-2-Code` · « Inscription · 2. Code »

*Rôle* : vérifier le numéro (étape 2 sur 3).

**Disposition et textes**

- **En-tête**
  - **Rangée**
    - **Bouton icône** : Retour → INS-1
    - **Texte** : Étape 2 sur 3
- **Contenu**
  - **Titre** : Saisis le code
  - **Texte** : Envoyé par SMS au | +228 90 00 00 00
  - **Lien** : Modifier le numéro → INS-1
  - **Texte** : Code à 6 chiffres
  - **Grille de 6**
    - **Champ** : [champ : 4]
    - **Champ** : [champ : 8]
    - **Champ** : [champ : 1]
    - **Champ** : [champ : 9]
    - **Champ** : [champ : 2]
    - **Champ** : [champ : 7]
  - **Puce** : Code rempli automatiquement
  - **Texte** : Renvoyer le code dans 0:42
  - **Texte** : Dès les 6 chiffres saisis, la vérification part toute seule.
- **Pied d’écran**
  - **Bouton principal** : Vérifier → INS-3
  - **Bouton désactivé** : Recevoir le code par appel (dans 0:42)

*Règles* : AUTH-01 ; code de 6 chiffres valable 5 min, renvoi après 60 s, 5 essais puis blocage de 15 min Recommandation ; ensuite, nouveau compte : INS-3 ; compte connu : CNX-1 ou CNX-2.

### INS-2b · Code incorrect

Maquette : `Inscription-2b-Code-incorrect` · « Inscription · 2b. Code incorrect »

*Rôle* : état d’erreur d’INS-2.

**Disposition et textes**

- **En-tête**
  - **Rangée**
    - **Bouton icône** : Retour → INS-1
    - **Texte** : Étape 2 sur 3
- **Contenu**
  - **Titre** : Saisis le code
  - **Texte** : Envoyé par SMS au | +228 90 00 00 00
  - **Lien** : Modifier le numéro → INS-1
  - **Texte** : Code à 6 chiffres
  - **Grille de 6**
    - **Champ** : [champ : 4]
    - **Champ** : [champ : 8]
    - **Champ** : [champ : 1]
    - **Champ** : [champ : 9]
    - **Champ** : [champ : 2]
    - **Champ** : [champ : 0]
  - **Texte** : Code incorrect. Il te reste 3 essais.
  - **Texte** : Renvoyer le code dans 0:42
  - **Texte** : Vérifie le dernier SMS reçu. Au 5e échec, la saisie est bloquée 15 minutes.
- **Pied d’écran**
  - **Bouton principal** : Vérifier → INS-3
  - **Bouton désactivé** : Recevoir le code par appel (dans 0:42)

*Règles* : message annoncé aux lecteurs d’écran ; au 5e échec : « Trop d’essais. Réessaie dans 15 minutes. » et saisie bloquée.

### INS-3 · Profil, avec Baba

Maquette : `Inscription-3-Profil` · « Inscription · 3. Profil, avec Baba »

*Rôle* : se présenter à ses proches (étape 3 sur 3) ; première apparition de Baba.

**Disposition et textes**

- **En-tête**
  - **Rangée**
    - **Bouton icône** : Retour → INS-2
    - **Texte** : Étape 3 sur 3
- **Contenu**
  - **Texte** : Baba | [intelligence artificielle] | Bienvenue sur Pokou ! Moi, c’est Baba, l’assistant de l’application. Comment veux-tu que tes proches t’appellent ?
  - **Rangée**
    - **Bouton icône** : Ajouter une photo (facultatif)
    - **Champ** : Nom affiché
    - **Champ** : [champ : Afi]
  - **Texte** : Ton prénom ou un surnom, 25 caractères au plus. La photo est facultative.
  - **Carte**
    - **Texte** : Facultatif
    - **Texte** : Statistiques d’utilisation | Anonymes, pour améliorer l’application | [interrupteur désactivé]
    - **Texte** : Nouveautés de Pokou | Par notification ou par SMS | [interrupteur désactivé]
- **Pied d’écran**
  - **Bouton principal** : C’est parti → INS-4

*Règles* : AUTH-09 et MSG-22 ; pas de date de naissance ; prénom, nom et pseudo se complètent ensuite dans le profil (Plus) ; consentements horodatés, modifiables dans Confidentialité.

### INS-4 · Baba propose les contacts

Maquette : `Inscription-4-Baba` · « Inscription · 4. Baba propose les contacts »

*Rôle* : accueillir le nouvel utilisateur et lui faire gagner l’ajout de ses proches.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Texte** : Baba | [intelligence artificielle] | Assistant de Pokou
  - **Bouton icône** : Options de la discussion avec Baba
- **Contenu**
  - **Encadré ambre** : Baba est une intelligence artificielle. Il ne lit pas tes autres discussions et ne te demandera jamais un code reçu par SMS.
  - **Bulle reçue** : Ton compte est prêt, Afi ! 🎉 Je suis là pour t’aider à prendre Pokou en main. | 17:02
  - **Bulle reçue** : Retrouve tes proches | Je peux chercher lesquels de tes contacts sont déjà sur Pokou. Leurs numéros sont comparés sous une forme protégée, et ton carnet d’adresses n’est pas conservé. Tu pourras changer d’avis dans Confidentialité. | 17:02
  - **Groupe de puces**
    - **Puce (sélectionnée)** : Oui, retrouve-les → INS-5
    - **Puce** : Plus tard → APP-2
- **Pied d’écran**
  - **Champ** : [champ : « Écrire à Baba… »]
  - **Bouton icône** : Poser ta question à voix haute
  - **Bouton icône** : Envoyer

*Règles* : AUTH-05, AUTH-10 et MSG-22 ; remplace l’écran « Compte créé » ; un refus n’empêche rien : l’accès est reproposé plus tard par Baba et depuis la nouvelle discussion.

### INS-5 · Contacts retrouvés

Maquette : `Inscription-5-Contacts` · « Inscription · 5. Contacts retrouvés »

*Rôle* : montrer ce que la découverte apporte et lancer la première conversation.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Texte** : Baba | [intelligence artificielle] | Assistant de Pokou
  - **Bouton icône** : Options de la discussion avec Baba
- **Contenu**
  - **Bulle reçue** : Ton compte est prêt, Afi ! 🎉 Je suis là pour t’aider à prendre Pokou en main. | 17:02
  - **Bulle envoyée** : Oui, retrouve-les | 17:03 · Lu
  - **Bulle reçue**
    - **Texte** : C’est fait ! 12 de tes contacts sont déjà sur Pokou :
    - **Liste**
      - **Élément**
        - **Avatar** : AS
        - **Texte** : Ama S.
        - **Texte** : Sur Pokou depuis août
        - **Puce** : Écrire → APP-2b
      - **Élément**
        - **Avatar** : EK
        - **Texte** : Edem K.
        - **Texte** : Groupe Famille Koffi
        - **Puce** : Écrire → APP-2b
      - **Élément**
        - **Avatar** : MD
        - **Texte** : Mensah D.
        - **Texte** : Sur Pokou depuis juin
        - **Puce** : Écrire → APP-2b
    - **Lien** : Voir les 12 contacts → DIS-5
    - **Texte** : 17:03
  - **Bulle reçue** : Pour les autres, je prépare une invitation à envoyer par SMS ou WhatsApp, si tu veux. | 17:03
  - **Groupe de puces**
    - **Puce** : Inviter mes proches → DIS-5
    - **Puce (sélectionnée)** : Aller à mes discussions → APP-2
- **Pied d’écran**
  - **Champ** : [champ : « Écrire à Baba… »]
  - **Bouton icône** : Poser ta question à voix haute
  - **Bouton icône** : Envoyer

*Règles* : AUTH-05 ; seuls les contacts inscrits apparaissent ; aucune invitation ne part sans geste de l’utilisateur.

### CNX-1 · Code PIN, si activé

Maquette : `Connexion-1-PIN` · « Connexion · 1. Code PIN, si activé »

*Rôle* : protéger la reconnexion d’un compte qui a activé la vérification en deux étapes.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → INS-2
- **Contenu**
  - **Titre** : Ton code PIN
  - **Texte** : Ton compte est protégé par la vérification en deux étapes. Saisis ton code PIN pour te reconnecter.
  - **Texte** : Code PIN à 6 chiffres
  - **Grille de 6**
    - **Champ** : [champ : ●]
    - **Champ** : [champ : ●]
    - **Champ** : [champ : ●]
    - **Champ** : [champ : ●]
    - **Champ** : [champ : Chiffre 5 sur 6]
    - **Champ** : [champ : Chiffre 6 sur 6]
  - **Lien** : Code PIN oublié ? → REG-6
  - **Carte** : Sans ton code PIN, la reconnexion reste possible au bout de 7 jours. Ce délai bloque une personne qui aurait récupéré ton numéro.
- **Pied d’écran**
  - **Bouton principal** : Continuer → CNX-2

*Règles* : AUTH-04 ; écran absent si le code PIN n’est pas activé ; délai de 7 jours sans code PIN Recommandation, contre le vol de numéro (échange de carte SIM).

### CNX-2 · Bon retour et sauvegarde

Maquette : `Connexion-2-Bon-retour` · « Connexion · 2. Bon retour et sauvegarde »

*Rôle* : retrouver son compte et ses discussions sur un nouveau téléphone, en un écran.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → INS-2
- **Contenu**
  - **Texte** : Baba | [intelligence artificielle] | Bon retour, Afi ! J’ai retrouvé ton compte et ta sauvegarde. Tes groupes, tes cagnottes Kory et ton badge te suivent.
  - **Carte** : [avatar AF] | Afi | +228 •• •• 00 00 · badge Pokou certifié actif
  - **Carte**
    - **Texte** : Sauvegarde | Google Drive
    - **Texte** : Dernière sauvegarde | 30 oct. 2026, 02:14
    - **Texte** : Contenu | 248 discussions · 1,2 Go
  - **Carte** : Discussions et état du mode preuve d’abord ; photos et vidéos ensuite, en Wi-Fi.
  - **Encadré ambre** : Ton ancien téléphone sera déconnecté.
- **Pied d’écran**
  - **Bouton principal** : Restaurer → CNX-3
  - **Ligne** : Continuer sans restaurer → APP-2

*Règles* : AUTH-03, MSG-12 et MSG-20 ; remplace REG-3 ; pas d’étape profil : nom, photo, badge, groupes et cagnottes Kory suivent le compte ; contacts prévenus selon le réglage.

### CNX-3 · Restauration en cours

Maquette : `Connexion-3-Restauration` · « Connexion · 3. Restauration en cours »

*Rôle* : rendre la main tout de suite pendant la restauration.

**Disposition et textes**

- **En-tête**
  - **Rangée**
    - **Texte** : [image : pokou-bulles] | [image : Pokou]
    - **Bouton icône** : Rechercher un contact, un groupe ou un message → DIS-22
    - **Bouton icône** : Nouvelle discussion → DIS-5
  - **Titre** : Discussions
- **Carte** : Restauration de tes discussions | 64 % | [barre 64%] | 160 discussions sur 248. Photos et vidéos ensuite, en Wi‑Fi.
- **Contenu**
  - **Liste**
    - **Ligne** : Baba | [intelligence artificielle] | Bon retour, Afi ! Tes discussions reviennent. | 17:20 | [icône : Épinglée] | [pastille 1] → INS-4
    - **Ligne** : [avatar FK] | Famille Koffi | Maman : On se voit dimanche ? | Hier → DIS-1
    - **Ligne** : [avatar AS] | Ama S. | On se retrouve samedi ? | Hier → APP-2b
    - **Ligne** : [avatar CB] | Collègues du bureau | Toi : Merci Yao, je note pour lundi. | 29/10 → APP-2
    - **Élément**
    - **Élément**
    - **Élément**
- **Barre d’onglets** : Accueil / Discussions (actif) / Kory / Honam / Plus

*Règles* : MSG-12 ; photos et vidéos ensuite, en Wi-Fi ; si la découverte des contacts était autorisée, seule l’autorisation du système est redemandée.

## 9.1 Badge Pokou certifié

### Figure · Les deux badges

Maquette : `Badge-0-Deux-badges` · « Pokou certifié · Les deux badges »

**Disposition et textes**

- **Contenu**
  - **Titre** : Deux badges, deux formes
  - **Texte** : Même vérification d’identité, mêmes droits sur le mode preuve. La forme dit qui est derrière le nom.
  - **Carte**
    - **Texte** : Pokou certifié
    - **Texte** : Particuliers
    - **Texte** : Rosette terracotta, coche blanche
    - **Texte** : 590 FCFA TTC par mois
  - **Carte**
    - **Texte** : Pokou certifié Pro
    - **Texte** : Commerçants, entreprises, associations, officines Honam
    - **Texte** : Hexagone ébène, coche or
    - **Texte** : 2 950 FCFA TTC par mois
  - **Titre de section** : Dans l’application
  - **Liste**
    - **Élément** : [avatar EK] | Edem K. | Particulier
    - **Élément** : [avatar MD] | Mensah D. | Commerçante · Marché de Bè
    - **Élément** : [avatar PD] | Pharmacie Démo | Officine Honam
  - **Titre de section** : Tailles, sur fond clair et sombre
  - **Carte** : 14 | 16 | 24 | 14 | 16 | 24
  - **Carte** : 14 | 16 | 24 | 14 | 16 | 24
  - **Encadré ambre** : Jamais la couleur seule : la forme change, et le lecteur d’écran annonce « Pokou certifié » ou « Pokou certifié Pro ». Sur fond sombre, l’hexagone prend un contour or.

## 9.5 Écrans

### CRT-1 · Offre Pokou certifié

Maquette : `Badge-1-Offre` · « Pokou certifié · 1. Offre »

*Rôle* : présenter le badge et lancer l’essai.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Pokou certifié
- **Contenu**
  - **Texte** : Ton nom vérifié, et la trace de ce qu’on t’écrit.
  - **Carte** : Un nom vérifié | Ton badge montre que tu es bien toi, grâce au wallet mobile money qui paie. | Le mode preuve | Dans une conversation, les messages supprimés restent visibles, barrés, pour tous. | L’export daté | Garde une conversation en PDF, avec les dates et les heures.
  - **Texte** : Formule
  - **Grille de 2**
    - **Choix** : ◉ | Au mois | 500 FCFA HT | 590 FCFA TTC par mois
    - **Choix** : ○ | À l’année | 5 000 FCFA HT | 5 900 FCFA TTC par an | Deux mois offerts
  - **Lien** : Professionnel ? Voir Pokou certifié Pro → PRO-1
- **Pied d’écran**
  - **Texte** : Pendant l’essai, le mode preuve est disponible. Le badge s’affiche au premier paiement, qui vérifie ton nom.
  - **Bouton principal** : Commencer l’essai d’un mois → PRV-3b
  - **Ligne** : Payer maintenant et afficher mon badge → CRT-2

*Règles* : prix HT et TTC (BM-10) ; texte sur l’essai conforme à CERT-11 ; formule au mois présélectionnée.

### CRT-2 · Vérifier et payer

Maquette : `Badge-2-Paiement` · « Pokou certifié · 2. Vérifier et payer »

*Rôle* : vérifier le nom et encaisser le premier paiement.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → CRT-1
  - **Titre** : Vérifier et payer
  - **Texte** : Pokou certifié · au mois
- **Contenu**
  - **Champ** : Nom et prénom, comme sur ta pièce d’identité
  - **Champ** : [champ : Afi Koffi]
  - **Texte** : Pokou le compare au nom du titulaire du wallet, déjà vérifié par ton opérateur. Ce nom s’affichera avec ton badge.
  - **Carte**
    - **Texte** : Payer avec
    - **Choix** : ◉ | Mixx by Yas | · Yas | +228 90 •• •• 00
    - **Choix** : ○ | Flooz | · Moov Africa | +228 99 •• •• 12
  - **Carte** : Pokou certifié, 1 mois | 500 FCFA HT | TVA 18 % | 90 FCFA | Total | 590 FCFA TTC
- **Pied d’écran**
  - **Texte** : Paiement par CashPay. Facture disponible dans ton compte.
  - **Bouton principal** : Vérifier et payer 590 FCFA → CRT-3
  - **Ligne** : Annuler → CRT-1

*Règles* : section 9.2 ; le nom saisi devient le nom vérifié affiché avec le badge (CERT-02).

### CRT-2b · Noms différents

Maquette : `Badge-2b-Noms-differents` · « Pokou certifié · 2b. Noms différents »

*Rôle* : état d’erreur de CRT-2.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → CRT-1
  - **Titre** : Vérifier et payer
  - **Texte** : Pokou certifié · au mois
- **Contenu**
  - **Carte** : Les noms ne correspondent pas | Le nom du titulaire de ce wallet ne correspond pas à ton nom. Corrige ton nom ou paie depuis ton propre wallet.
  - **Champ** : Nom et prénom, comme sur ta pièce d’identité
  - **Champ** : [champ : Afi K.]
  - **Carte**
    - **Texte** : Payer avec
    - **Choix** : ◉ | Mixx by Yas | · Yas | +228 90 •• •• 00
    - **Choix** : ○ | Flooz | · Moov Africa | +228 99 •• •• 12
  - **Texte** : Le nom du titulaire n’est jamais affiché. Ton essai et le mode preuve continuent en attendant.
- **Pied d’écran**
  - **Bouton principal** : Vérifier à nouveau → CRT-3
  - **Ligne** : Annuler → CRT-1

*Règles* : section 9.2 ; texte de la section 16 (« Noms différents ») ; aucun nom de titulaire montré à l’utilisateur.

### CRT-3 · Badge actif

Maquette : `Badge-3-Actif` · « Pokou certifié · 3. Badge actif »

*Rôle* : confirmer l’activation du badge.

**Disposition et textes**

- **Contenu**
  - **Titre** : Ton badge est actif
  - **Texte** : Tes contacts voient désormais ton nom vérifié.
  - **Carte**
    - **Texte** : [avatar AK] | Afi Koffi | Nom vérifié par Mixx by Yas
    - **Texte** : Formule
    - **Texte** : Au mois
    - **Texte** : Prochain paiement
    - **Texte** : 27/11/2026 · 590 FCFA TTC
    - **Ligne** : Télécharger la facture → CRT-3
- **Pied d’écran**
  - **Texte** : Le mode preuve s’active dans toutes tes discussions, à deux ou en groupe.
  - **Bouton principal** : Activer le mode preuve → PRV-3b
  - **Ligne** : Terminé → APP-6

*Règles* : CERT-01 et CERT-03 ; la facture affiche HT, TVA et TTC (BM-10).

### CRT-4 · Fin de l’essai

Maquette : `Badge-4-Fin-essai` · « Pokou certifié · 4. Fin de l’essai »

*Rôle* : prévenir trois jours avant la fin de l’essai et montrer ce que change le paiement.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Pokou certifié
- **Contenu**
  - **Texte** : Ton essai se termine dans 3 jours, le 27 nov.
  - **Carte**
    - **Texte** : Si tu paies
    - **Texte** : Ton badge s’affiche, ton nom est vérifié par ton wallet
    - **Texte** : Le mode preuve et l’export daté continuent
  - **Carte**
    - **Texte** : Sans paiement
    - **Texte** : Tu ne peux plus activer le mode preuve dans une nouvelle discussion
    - **Texte** : Ce qui a déjà été enregistré reste visible de tous
  - **Choix** : ◉ | À l’année · 5 900 FCFA TTC | Deux mois offerts
  - **Choix** : ○ | Au mois · 590 FCFA TTC
- **Pied d’écran**
  - **Bouton principal** : Payer et afficher mon badge → CRT-2
  - **Ligne** : Plus tard → APP-6

*Règles* : CERT-03, CERT-11 et CERT-18 ; ouvert aussi par la notification « Ton essai se termine dans 3 jours » (NOT-1).

### CRT-5 · Badge en pause

Maquette : `Badge-5-Expire` · « Pokou certifié · 5. Badge en pause »

*Rôle* : expliquer un badge masqué après un paiement manqué, sans inquiéter.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Badge en pause
- **Contenu**
  - **Texte** : Le paiement du 27 nov. n’a pas abouti. Ton badge est masqué depuis le 4 déc., après 7 jours de grâce.
  - **Carte**
    - **Texte** : Ce qui reste
    - **Texte** : Tes discussions et tes contacts
    - **Texte** : Les traces déjà enregistrées par le mode preuve
  - **Carte**
    - **Texte** : Ce qui est en pause
    - **Texte** : Le badge et le nom vérifié
    - **Texte** : Le mode preuve des nouveaux messages et l’export daté
  - **Carte** : Le paiement se fait par ton wallet. Si ton solde était insuffisant, recharge-le puis réessaie.
- **Pied d’écran**
  - **Bouton principal** : Payer 590 FCFA et réafficher mon badge → CRT-2
  - **Ligne** : Changer de formule → CRT-1

*Règles* : CERT-04, CERT-15 et CERT-18 ; les traces déjà enregistrées ne disparaissent jamais.

### PRV-3b · Choisir une discussion

Maquette : `Preuve-3b-Choisir` · « Mode preuve · 3b. Choisir une discussion »

*Rôle* : choisir la discussion où activer le mode preuve.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → CRT-3
  - **Titre** : Activer le mode preuve
  - **Texte** : Choisis une discussion
- **Contenu**
  - **Encadré ambre** : Avec ton badge, le mode preuve s’active dans n’importe quelle discussion : à deux ou en groupe, que tu en sois administrateur ou non.
  - **Champ** : [champ : « Rechercher une discussion »]
  - **Titre de section** : Tes discussions
  - **Liste**
    - **Ligne** : [avatar KA] | Kodjo A. | Discussion à deux → PRV-4b
    - **Ligne** : [avatar AS] | Ama S. | Discussion à deux → PRV-4b
    - **Ligne** : [avatar CB] | Collègues du bureau | Groupe · 8 membres → PRV-4
    - **Ligne** : [avatar FK] | Famille Koffi | Groupe → PRV-4
    - **Ligne** : [avatar AB] | Les Amis de Bè | Groupe → PRV-4
- **Pied d’écran**
  - **Texte** : Les participants sont toujours prévenus : un message dans la discussion et un bandeau permanent.
  - **Ligne** : Plus tard → APP-6

*Règles* : section 9.3 ; on y arrive depuis CRT-1 (« Commencer l’essai d’un mois ») et CRT-3 ; depuis une discussion, « Options » mène directement à la confirmation.

### PRV-4 · Activer le mode preuve

Maquette : `Preuve-4-Activer` · « Mode preuve · 4. Activer dans un groupe »

*Rôle* : confirmer l’activation dans une conversation (ici un groupe, depuis le menu « Options du groupe »).

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : CB
  - **Titre** : Collègues du bureau
  - **Texte** : 8 membres
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Options du groupe → PRV-4
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Yao A. | Le tour de novembre est à moi, on l’a décidé à la réunion. | 14:20
  - **Bulle reçue** : Mensah D. | Qui tient le registre des versements cette année ? | 14:22
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Texte** : Activer le mode preuve ?
  - **Texte** : Dans « Collègues du bureau », un message supprimé par son auteur restera visible, barré, pour les 8 membres, avec l’heure de la suppression.
  - **Liste**
    - **Élément** : Tous les membres sont prévenus : un message dans le groupe et un bandeau permanent.
    - **Élément** : Seuls les messages envoyés à partir de maintenant sont concernés.
    - **Élément** : Tu pourras le désactiver ; les messages envoyés pendant le mode gardent la règle.
  - **Bouton principal** : Activer le mode preuve → PRV-5
  - **Ligne** : Annuler → APP-2

*Règles* : section 9.3 ; ouvert à tout membre titulaire du badge ou en essai, administrateur ou non ; feuille modale accessible (focus piégé, fermeture par « Annuler » et par le geste retour).

### PRV-4b · Activer dans une discussion à deux

Maquette : `Preuve-4b-Activer-a-deux` · « Mode preuve · 4b. Activer dans une discussion à deux »

*Rôle* : confirmer l’activation dans une discussion à deux, depuis « Options de la discussion » ou depuis PRV-3b.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : KA
  - **Titre** : Kodjo A.
  - **Texte** : Discussion à deux
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Appel vidéo
  - **Bouton icône** : Options de la discussion → PRV-4b
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Pour la moto, je te rends les 15 000 FCFA vendredi. | 10:12
  - **Bulle envoyée** : D’accord, vendredi alors. | 10:14 · Lu
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Texte** : Activer le mode preuve ?
  - **Texte** : Dans ta discussion avec Kodjo A., un message supprimé par son auteur restera visible, barré, pour vous deux, avec l’heure de la suppression.
  - **Liste**
    - **Élément** : Kodjo est prévenu : un message dans la discussion et un bandeau permanent.
    - **Élément** : Seuls les messages envoyés à partir de maintenant sont concernés.
    - **Élément** : Tu pourras le désactiver ; les messages envoyés pendant le mode gardent la règle.
  - **Bouton principal** : Activer le mode preuve → PRV-5b
  - **Ligne** : Annuler → PRV-3b

*Règles* : section 9.3 ; mêmes règles d’accessibilité que PRV-4.

### PRV-5 · Conversation en mode preuve

Maquette : `Preuve-5-Conversation` · « Mode preuve · 5. Conversation »

*Rôle* : montrer à tous les participants une conversation en mode preuve.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : CB
  - **Titre** : Collègues du bureau
  - **Texte** : 8 membres · mode preuve actif
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Options du groupe → PRV-4
- **Encadré ambre**
  - **Texte** : Mode preuve activé par Afi.
  - **Lien** : En savoir plus → CRT-1
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Yao A. | Le tour de novembre est à moi, on l’a décidé à la réunion. | 14:20
  - **Message système** : Afi a activé le mode preuve à 14 h 25. Les messages supprimés resteront visibles, barrés, pour tous.
  - **Bulle reçue** : Yao A. | Message supprimé, resté visible : | ~~Je verse ma part lundi sans faute.~~ | Supprimé par son auteur à 14 h 32 | 14:31
  - **Bulle reçue** : Mensah D. | Avec le mode preuve, chacun garde la trace. C’est plus simple pour tout le monde. | 14:35
  - **Rangée**
    - **Bouton icône** : Options du message → PRV-6
    - **Bulle envoyée** : Merci Yao, je note pour lundi. | 14:36 · Lu
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer

*Règles* : CERT-05 et CERT-06 ; le message supprimé est lu « Message supprimé, resté visible » par les lecteurs d’écran ; le barré n’est jamais le seul signal (DS, section 15.1).

### PRV-5b · Discussion à deux en mode preuve

Maquette : `Preuve-5b-Conversation-a-deux` · « Mode preuve · 5b. Discussion à deux »

*Rôle* : montrer le mode preuve dans une discussion à deux.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : KA
  - **Titre** : Kodjo A.
  - **Texte** : Discussion à deux · mode preuve actif
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Appel vidéo
  - **Bouton icône** : Infos du contact → DIS-7
- **Encadré ambre**
  - **Texte** : Mode preuve activé par Afi.
  - **Lien** : En savoir plus → CRT-1
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Pour la moto, je te rends les 15 000 FCFA vendredi. | 10:12
  - **Bulle envoyée** : D’accord, vendredi alors. | 10:14 · Lu
  - **Message système** : Afi a activé le mode preuve à 10 h 15. Les messages supprimés resteront visibles, barrés, pour vous deux.
  - **Bulle reçue** : Message supprimé, resté visible : | ~~Finalement, ce sera à la fin du mois.~~ | Supprimé par son auteur à 10 h 21 | 10:20
  - **Bulle envoyée** : Je vois encore ton message. On en reparle ce soir. | 10:23 · Lu
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer

*Règles* : CERT-05 et CERT-06 ; seule la personne qui l’a activé peut le désactiver, depuis les infos du contact (DIS-7 ; section 9.3).

### PRV-6 · Supprimer son message

Maquette : `Preuve-6-Supprimer` · « Mode preuve · 6. Supprimer son message »

*Rôle* : prévenir l’auteur avant une suppression en mode preuve.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : CB
  - **Titre** : Collègues du bureau
  - **Texte** : 8 membres · mode preuve actif
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Options du groupe → PRV-4
- **Encadré ambre**
  - **Texte** : Mode preuve activé par Afi.
  - **Lien** : En savoir plus → CRT-1
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Yao A. | Le tour de novembre est à moi, on l’a décidé à la réunion. | 14:20
  - **Message système** : Afi a activé le mode preuve à 14 h 25. Les messages supprimés resteront visibles, barrés, pour tous.
  - **Bulle reçue** : Yao A. | Message supprimé, resté visible : | ~~Je verse ma part lundi sans faute.~~ | Supprimé par son auteur à 14 h 32 | 14:31
  - **Bulle reçue** : Mensah D. | Avec le mode preuve, chacun garde la trace. C’est plus simple pour tout le monde. | 14:35
  - **Rangée**
    - **Bouton icône** : Options du message → PRV-6
    - **Bulle envoyée** : Merci Yao, je note pour lundi. | 14:36 · Lu
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Titre de section** : Supprimer ce message ?
  - **Texte** : Merci Yao, je note pour lundi.
  - **Encadré ambre** : Le mode preuve est actif. Ton message restera visible, barré, pour tous les participants, avec l’heure de la suppression.
  - **Bouton principal** : Supprimer pour tous → PRV-5
  - **Bouton secondaire** : Supprimer pour moi seulement → PRV-5
  - **Ligne** : Annuler → PRV-5

*Règles* : CERT-06 ; hors mode preuve, la même action efface le message chez tous (MSG-01).

### PRV-7 · Désactivation réservée

Maquette : `Preuve-7-Desactivation` · « Mode preuve · 7. Désactivation réservée »

*Rôle* : expliquer à un administrateur en essai pourquoi la désactivation est refusée et lui proposer de payer le badge.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : TM
  - **Titre** : Tontine du marché
  - **Texte** : 12 membres · mode preuve actif
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Options du groupe
- **Encadré ambre** : Mode preuve activé par Mensah D. Les messages supprimés restent visibles, barrés, pour tous.
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Mensah D. | Rappel : les parts de novembre sont à verser avant le 5. | 09:02
- **Pied d’écran**
  - **Champ** : [champ : « Écrire un message… »]
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Texte** : Désactiver le mode preuve
  - **Texte** : Mensah D. l’a activé. Dans un groupe, il se désactive par la personne qui l’a activé ou par un administrateur qui a un badge payant, Pokou certifié ou Pro. L’essai ne suffit pas.
  - **Carte** : Ton badge | Essai, jusqu’au 28 nov. | Niveau requis | Badge payant
  - **Encadré terracotta clair**
    - **Texte** : Pokou certifié
    - **Texte** : 500 FCFA HT par mois · 590 FCFA TTC
    - **Texte** : Le paiement vérifie ton nom et affiche ton badge ; tu peux alors désactiver le mode preuve. Les commerçants et associations peuvent choisir Pokou certifié Pro.
  - **Bouton principal** : Payer et afficher mon badge → CRT-2
  - **Ligne** : Garder le mode preuve

*Règles* : section 9.3 et CERT-13 ; sans badge, la même feuille ouvre l’offre (CRT-1) ; jamais de proposition de passer à Pro pour obtenir ce droit, Pro donnant les mêmes droits que Pokou certifié ; le mode preuve reste actif jusqu’au paiement.

### PRV-8 · Exporter la discussion

Maquette : `Preuve-8-Exporter` · « Mode preuve · 8. Exporter la discussion »

*Rôle* : choisir ce que contient l’export daté, réservé au titulaire du badge.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → DIS-7
  - **Titre** : Exporter la discussion
  - **Texte** : Kodjo A. · mode preuve actif
- **Contenu**
  - **Titre de section** : Période
  - **Carte**
    - **Choix** : ◉ | Depuis l’activation du mode preuve | Aujourd’hui, 10 h 15
    - **Choix** : ○ | Toute la discussion
    - **Choix** : ○ | Choisir des dates
  - **Carte**
    - **Interrupteur** : Inclure les photos et les documents | Le PDF sera plus lourd | [interrupteur activé]
  - **Titre de section** : Le PDF contient
  - **Carte**
    - **Élément** : Date et heure de chaque message
    - **Élément** : Messages supprimés ou modifiés, avec leur version d’origine
    - **Élément** : Empreinte d’intégrité du fichier (SHA-256)
  - **Carte** : Le PDF est créé sur ton téléphone ; Pokou n’en garde aucune copie. Sa valeur juridique est appréciée par le juge.
- **Pied d’écran**
  - **Bouton principal** : Créer le PDF → PRV-9

*Règles* : CERT-08 ; aucune copie sur les serveurs de Pokou ; on y entre par les infos du contact ou du groupe (DIS-7, DIS-8).

### PRV-9 · PDF prêt

Maquette : `Preuve-9-PDF-pret` · « Mode preuve · 9. PDF prêt »

*Rôle* : remettre le PDF et son empreinte.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → PRV-8
  - **Titre** : PDF prêt
  - **Texte** : Kodjo A. · 3 pages · 412 Ko
- **Contenu**
  - **Repère** : [Aperçu de la première page du PDF]
  - **Carte** : Empreinte d’intégrité (SHA-256) | 9f2c7a1e 5b0d93c2 77e1a4f0 c3d2b819 e5a6f4d1 0b2c8e73 a91f6d24 5c7e41ab
  - **Encadré ambre** : Garde le fichier tel quel : la moindre modification change l’empreinte.
- **Pied d’écran**
  - **Bouton secondaire** : Enregistrer
  - **Bouton principal** : Partager

*Règles* : CERT-08 ; l’empreinte est aussi imprimée en pied de chaque page.

### PRV-10 · Désactiver le mode preuve

Maquette : `Preuve-10-Desactiver` · « Mode preuve · 10. Désactiver »

*Rôle* : confirmer la désactivation, pour la personne qui l’a activé.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : KA
  - **Titre** : Kodjo A.
  - **Texte** : mode preuve actif
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Appel vidéo
  - **Bouton icône** : Infos du contact → DIS-7
- **Encadré ambre** : Mode preuve activé par Afi. Messages supprimés ou modifiés : la version d’origine reste visible pour vous deux.
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Je te rembourse vendredi, promis. | 10:30
  - **Bulle envoyée** : On en reparle ce soir, à 19 h. | Modifié · 10:44 · Lu
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Texte** : Désactiver le mode preuve ?
  - **Liste**
    - **Élément** : Kodjo est prévenu par un message dans la discussion.
    - **Élément** : Les messages envoyés pendant le mode gardent la règle : leur version d’origine reste visible.
    - **Élément** : Tu pourras le réactiver quand tu veux.
  - **Bouton principal** : Désactiver → PRV-5b
  - **Ligne** : Garder le mode preuve → DIS-7

*Règles* : section 9.3 ; en groupe, même feuille pour un administrateur titulaire d’un badge payant ; un message système horodaté suit la désactivation.

## 9.6 Écrans des discussions et des appels

### DIS-1 · Discussion de groupe

Maquette : `Discussion-1-Groupe` · « Discussions · 1. Discussion de groupe »

*Rôle* : conversation à plusieurs, ici la famille qui organise une cagnotte.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Ligne** : [avatar FK] | Famille Koffi | 9 membres → DIS-8
  - **Bouton icône** : Appel vidéo de groupe
  - **Bouton icône** : Appel audio de groupe → DIS-18
  - **Bouton icône** : Infos du groupe → DIS-8
- **Ligne** : Cagnotte en cours · Anniversaire de Papa | 75 000 sur 100 000 FCFA · clôture le 2 nov. → KOR-1
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue**
    - **Texte** : Edem K.
    - **Texte** : Il manque 25 000 FCFA pour samedi !
    - **Vignette** : Cagnotte Kory | Anniversaire de Papa | [barre 75%] | 75 000 sur 100 000 FCFA confirmés | Contribuer → KOR-1
    - **Texte** : 15:10
  - **Bulle reçue** : Kafui K. | La salle est réservée pour samedi. | 16:48
  - **Bulle envoyée** : Kafui K. | La salle est réservée pour samedi. | Parfait ! Je m’occupe des boissons. | 16:52 · Lu
  - **Bulle reçue**
    - **Texte** : Séna K.
    - **Rangée**
      - **Bouton icône** : Écouter la note vocale
      - **Texte** : 0:24
    - **Texte** : 17:20
  - **Bulle reçue** : Maman | On se voit dimanche ? | 17:35
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier → DIS-2
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale → DIS-4
  - **Bouton icône** : Envoyer

*Règles* : MSG-01, MSG-07 et NAV-03 ; couleurs des noms contrastées à 4,5:1 au moins sur blanc ; montants en « confirmé », jamais en solde (BM-01).

### DIS-2 · Joindre un fichier

Maquette : `Discussion-2-Pieces-jointes` · « Discussions · 2. Joindre un fichier »

*Rôle* : choisir ce qu’on joint à un message.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Ligne** : [avatar FK] | Famille Koffi | 9 membres → DIS-8
  - **Bouton icône** : Appel vidéo de groupe
  - **Bouton icône** : Appel audio de groupe → DIS-18
  - **Bouton icône** : Infos du groupe → DIS-8
- **Ligne** : Cagnotte en cours · Anniversaire de Papa | 75 000 sur 100 000 FCFA · clôture le 2 nov. → KOR-1
- **Contenu**
  - **Bulle reçue** : Kafui K. | La salle est réservée pour samedi. | 16:48
  - **Bulle envoyée** : Kafui K. | La salle est réservée pour samedi. | Parfait ! Je m’occupe des boissons. | 16:52 · Lu
  - **Bulle reçue**
    - **Texte** : Séna K.
    - **Rangée**
      - **Bouton icône** : Écouter la note vocale
      - **Texte** : 0:24
    - **Texte** : 17:20
  - **Bulle reçue** : Maman | On se voit dimanche ? | 17:35
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Rangée**
    - **Titre de section** : Joindre à Famille Koffi
    - **Bouton icône** : Fermer → DIS-1
  - **Grille de 4**
    - **Tuile** : Galerie → DIS-24
    - **Tuile** : Caméra
    - **Tuile** : Document
    - **Tuile** : Cagnotte Kory → KOR-6
  - **Texte** : Photos et vidéos sont compressées avant l’envoi. La cagnotte Kory se crée seulement dans un groupe.

*Règles* : MSG-01 et MSG-05 ; la tuile Cagnotte Kory n’apparaît que dans un groupe (MSG-07) ; tuiles de 56 px avec libellé.

### DIS-3 · Actions sur un message

Maquette : `Discussion-3-Options-message` · « Discussions · 3. Options du message »

*Rôle* : réagir à un message ou agir dessus, par un appui long.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : AS
  - **Titre** : Ama S.
  - **Texte** : en ligne
  - **Bouton icône** : Appel audio → DIS-9
  - **Bouton icône** : Appel vidéo → DIS-10
  - **Bouton icône** : Options de la discussion
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : [icône : Photo] | Coucou ! Tu as bien reçu les photos ? | 16:02
  - **Bulle envoyée** : Ama S. | Photo · Coucou ! Tu as bien reçu les photos ? | Oui, merci ! Elles sont magnifiques. | 16:04 · Lu
  - **Carte**
    - **Puce** : 👍
    - **Puce** : ❤️
    - **Puce** : 😂
    - **Puce** : 😮
    - **Puce** : 🙏
    - **Bouton icône** : Plus de réactions
  - **Ligne** : Répondre
  - **Ligne** : Transférer → DIS-23
  - **Ligne** : Copier
  - **Ligne** : Modifier | Pendant 15 minutes après l’envoi
  - **Ligne** : Infos du message | Distribué 16:04 · Lu 16:04
  - **Ligne** : Supprimer
  - **Bulle reçue** : On se retrouve samedi ? | 16:05
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer
- **Fond** : voile sombre sur l’écran

*Règles* : MSG-01, MSG-02 et MSG-08 (transferts limités) ; menu aussi accessible sans appui long, par l’action « Plus d’options » du lecteur d’écran ; réactions proposées, à valider avant le lot 1.

### DIS-4 · Note vocale

Maquette : `Discussion-4-Note-vocale` · « Discussions · 4. Note vocale »

*Rôle* : écouter et enregistrer des notes vocales.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : AS
  - **Titre** : Ama S.
  - **Texte** : en ligne
  - **Bouton icône** : Appel audio → DIS-9
  - **Bouton icône** : Appel vidéo → DIS-10
  - **Bouton icône** : Options de la discussion
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle envoyée** : Ama S. | Photo · Coucou ! Tu as bien reçu les photos ? | Oui, merci ! Elles sont magnifiques. | 16:04 · Lu
  - **Bulle reçue** : On se retrouve samedi ? | 16:05
  - **Bulle reçue**
    - **Rangée**
      - **Bouton icône** : Mettre en pause
      - **Texte** : 0:11
      - **Puce** : ×1,5
    - **Texte** : 16:06
- **Pied d’écran**
  - **Texte** : 0:07
  - **Texte** : Glisse pour annuler
  - **Bouton icône** : Relâcher pour envoyer la note vocale
  - **Bouton icône** : Verrouiller l’enregistrement

*Règles* : MSG-06 ; sans geste, pour l’accessibilité : un toucher démarre l’enregistrement, un second l’arrête.

### DIS-5 · Nouvelle discussion

Maquette : `Discussion-5-Nouvelle` · « Discussions · 5. Nouvelle discussion »

*Rôle* : démarrer une discussion ou un groupe.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Titre** : Nouvelle discussion
  - **Texte** : 46 contacts sur Pokou
- **Champ** : [champ : « Rechercher un nom »]
- **Contenu**
  - **Liste**
    - **Ligne** : Nouveau groupe | Réunis tes proches dans une discussion → DIS-6
    - **Élément** : Inviter sur Pokou | Partager un lien d’invitation
  - **Titre de section** : Contacts sur Pokou
  - **Liste**
    - **Ligne** : [avatar AS] | Ama S. | Disponible → APP-2b
    - **Élément** : [avatar EK] | Edem K. | Au travail jusqu’à 18 h
    - **Ligne** : [avatar KA] | Kodjo A. | Salut, je suis sur Pokou ! → PRV-5b
    - **Élément** : [avatar MD] | Mensah D. | Marché de Bè, allée 4
    - **Élément** : [avatar YA] | Yao A. | Disponible
  - **Titre de section** : Inviter sur Pokou
  - **Liste**
    - **Élément** : [avatar DT] | Délali T. | Pas encore sur Pokou | Inviter

*Règles* : aucun numéro affiché (annexe A, n° 19) ; carnet d’adresses lu seulement avec l’accord de l’utilisateur (section 14).

### DIS-6 · Nouveau groupe

Maquette : `Discussion-6-Nouveau-groupe` · « Discussions · 6. Nouveau groupe »

*Rôle* : nommer le groupe et régler ses droits.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → DIS-5
  - **Titre** : Nouveau groupe
  - **Texte** : 4 membres choisis
- **Contenu**
  - **Rangée**
    - **Bouton icône** : Ajouter une photo du groupe
    - **Champ** : Nom du groupe = [champ : Voisins de Bè]
  - **Titre de section** : Membres · 4
  - **Groupe de puces**
    - **Carte**
      - **Avatar** : AS
      - **Bouton icône** : Retirer Ama S.
    - **Carte**
      - **Avatar** : EK
      - **Bouton icône** : Retirer Edem K.
    - **Carte**
      - **Avatar** : KA
      - **Bouton icône** : Retirer Kodjo A.
    - **Carte**
      - **Avatar** : YA
      - **Bouton icône** : Retirer Yao A.
    - **Puce** : Ajouter → DIS-5
  - **Carte**
    - **Interrupteur** : Seuls les administrateurs modifient le groupe | Nom, photo et description | [interrupteur activé]
    - **Interrupteur** : Lien d’invitation | Révocable à tout moment | [interrupteur désactivé]
  - **Texte** : Tu gères le groupe et peux nommer d’autres administrateurs. Chaque membre est prévenu de son ajout.
- **Pied d’écran**
  - **Bouton principal** : Créer le groupe → APP-2

*Règles* : MSG-07 (rôles, lien révocable, taille maximale paramétrable) ; chaque membre ajouté est prévenu par un message système.

### DIS-7 · Infos du contact

Maquette : `Discussion-7-Infos-contact` · « Discussions · 7. Infos du contact »

*Rôle* : profil d’un contact et réglages de la discussion à deux.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour à la discussion → PRV-5b
  - **Titre** : Infos du contact
- **Contenu**
  - **Avatar** : KA
  - **Texte** : Kodjo A.
  - **Texte** : Disponible
  - **Rangée**
    - **Bouton secondaire** : Message → PRV-5b
    - **Bouton secondaire** : Audio
    - **Bouton secondaire** : Vidéo
    - **Bouton secondaire** : Rechercher
  - **Encadré ambre**
    - **Texte** : Mode preuve actif
    - **Texte** : Activé par toi aujourd’hui à 10 h 15. Dans une discussion à deux, seule la personne qui l’a activé peut le désactiver.
    - **Puce** : Désactiver le mode preuve → PRV-10
  - **Liste**
    - **Élément** : Médias, liens et documents | 12 éléments
    - **Élément**
      - **Fond** : voile sombre sur l’écran
      - **Texte** : Exporter la discussion en PDF
      - **Texte** : Daté, avec les messages supprimés signalés
    - **Élément** : Notifications | Aperçu masqué sur écran verrouillé
  - **Liste**
    - **Élément** : Bloquer Kodjo A.
    - **Élément** : Signaler Kodjo A.

*Règles* : section 9.3 et CERT-13 ; MSG-11 (blocage, signalement, recherche).

### DIS-8 · Infos du groupe

Maquette : `Discussion-8-Infos-groupe` · « Discussions · 8. Infos du groupe »

*Rôle* : membres et réglages d’un groupe.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour à la discussion → DIS-1
  - **Titre** : Infos du groupe
- **Contenu**
  - **Avatar** : FK
  - **Texte** : Famille Koffi
  - **Texte** : Groupe · 9 membres
  - **Rangée**
    - **Bouton secondaire** : Audio
    - **Bouton secondaire** : Vidéo
    - **Bouton secondaire** : Ajouter
    - **Bouton secondaire** : Rechercher
  - **Ligne** : Cagnotte en cours · Anniversaire de Papa | 75 000 sur 100 000 FCFA · clôture le 2 nov. → KOR-1
  - **Liste**
    - **Ligne** : Mode preuve : désactivé | Tout membre titulaire du badge peut l’activer | Activer → PRV-4
    - **Ligne** : Lien d’invitation | Révocable à tout moment, réservé aux administrateurs → DIS-26
  - **Titre de section** : 9 membres
  - **Liste**
    - **Élément** : [avatar AK] | Toi | Afi Koffi | Admin
    - **Élément** : [avatar EK] | Edem K. | Au travail jusqu’à 18 h | Admin
    - **Élément** : [avatar MA] | Maman | Disponible
    - **Élément** : [avatar KK] | Kafui K. | Disponible

*Règles* : MSG-07 ; NAV-03 ; section 9.3.

### DIS-9 · Appel audio

Maquette : `Discussion-9-Appel-audio` · « Discussions · 9. Appel audio »

*Rôle* : appel audio en cours.

**Disposition et textes**

- **Fond** : dégradé sombre plein écran
- **En-tête**
  - **Bouton icône** : Réduire l’appel → APP-2b
  - **Texte** : Appel audio
- **Avatar** : AS
- **Titre** : Ama S.
- **Texte** : 02:14
- **Grille de 4**
  - **Bouton icône** : Haut-parleur
  - **Texte** : Haut-parleur
  - **Bouton icône** : Micro
  - **Texte** : Micro
  - **Bouton icône** : Vidéo
  - **Texte** : Vidéo
  - **Bouton icône** : Raccrocher
  - **Texte** : Raccrocher

*Règles* : MSG-09, avec CallKit (iOS) et ConnectionService (Android) pour l’écran verrouillé ; boutons de 64 px ; aucune mention de chiffrement tant que le protocole n’est pas documenté (section 9).

### DIS-10 · Appel vidéo sur réseau faible

Maquette : `Discussion-10-Appel-video` · « Discussions · 10. Appel vidéo »

*Rôle* : appel vidéo, ici quand le réseau faiblit.

**Disposition et textes**

- **Fond** : dégradé sombre plein écran
- **En-tête**
  - **Bouton icône** : Réduire l’appel → APP-2b
  - **Titre** : Ama S.
  - **Texte** : 05:42
- **Encadré ambre** : Réseau faible. La vidéo d’Ama est en pause, l’appel continue en audio.
- **Avatar** : AK
- **Texte** : Toi
- **Avatar** : AS
- **Texte** : Vidéo en pause
- **Grille de 4**
  - **Bouton icône** : Retourner
  - **Texte** : Retourner
  - **Bouton icône** : Caméra
  - **Texte** : Caméra
  - **Bouton icône** : Micro
  - **Texte** : Micro
  - **Bouton icône** : Raccrocher
  - **Texte** : Raccrocher

*Règles* : MSG-09 (débit adaptatif, bascule en audio seul sur réseau faible) ; bandeau annoncé aux lecteurs d’écran.

### DIS-11 · Épingler, favoris, archiver

Maquette : `Discussion-11-Actions-discussion` · « Discussions · 11. Épingler, favoris, archiver »

*Rôle* : organiser sa liste de discussions, par un appui long sur une discussion.

**Disposition et textes**

- **En-tête**
  - **Rangée**
    - **Texte** : [image : pokou-bulles] | [image : Pokou]
    - **Bouton icône** : Rechercher un contact, un groupe ou un message → DIS-22
    - **Bouton icône** : Nouvelle discussion → DIS-5
  - **Titre** : Discussions
- **Bande horizontale**
  - **Tuile** : [avatar AK] | Mon statut → STA-3
  - **Ligne** : [avatar MD] | Mensah D. → STA-2
  - **Ligne** : [avatar EK] | Edem K. → STA-1
  - **Ligne** : [avatar AS] | Ama S. → STA-1
  - **Ligne** : [avatar KK] | Kafui K. → STA-1
- **Rangée**
  - **Filtre (sélectionné)** : Toutes
  - **Filtre** : Non lues · 3
  - **Filtre** : Favoris
  - **Filtre** : Groupes
- **Contenu**
  - **Liste**
    - **Ligne** : Archivées | 2 → DIS-12
    - **Ligne** : Baba | [intelligence artificielle] | Pose-moi une question sur Pokou, Kory ou Honam. | [icône : Épinglée] → INS-4
    - **Ligne** : [avatar FK] | Famille Koffi | Maman : On se voit dimanche ? | Cagnotte en cours | 17:35 | [icône : Épinglée] | [pastille 2] → DIS-1
    - **Ligne** : [avatar AS] | Ama S. | On se retrouve samedi ? | 16:05 | [pastille 1] → APP-2b
    - **Ligne** : [avatar CB] | Collègues du bureau | Toi : Merci Yao, je note pour lundi. | Mode preuve | 14:36 → PRV-5
    - **Ligne** : [avatar KA] | Kodjo A. | Toi : Je vois encore ton message. On en reparle ce soir. | Mode preuve | 10:23 → PRV-5b
    - **Ligne** : Pharmacie Démo · Honam | Ton devis est prêt : 5 600 FCFA | Hier → APP-4
    - **Élément** : [avatar AB] | Les Amis de Bè | Réunion samedi à 16 h | 24/10
- **Barre d’onglets** : Accueil / Discussions (actif) / Kory / Honam / Plus
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Texte** : [avatar AS] | Ama S. | Discussion à deux
  - **Ligne** : Épingler en haut de la liste | Trois discussions épinglées au maximum
  - **Ligne** : Ajouter aux favoris | Retrouve-la dans le filtre « Favoris »
  - **Ligne** : Archiver | Elle quitte la liste sans être supprimée
  - **Ligne** : Annuler → APP-2

*Règles* : MSG-13 ; rien n’est visible des autres participants ; chaque action affiche une confirmation brève avec « Annuler ».

### DIS-12 · Discussions archivées

Maquette : `Discussion-12-Archivees` · « Discussions · 12. Discussions archivées »

*Rôle* : retrouver les discussions archivées.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Titre** : Archivées
  - **Texte** : 2 discussions
- **Carte** : Une discussion archivée reste ici quand un message arrive. Son contenu et le mode preuve ne changent pas.
- **Contenu**
  - **Liste**
    - **Élément** : [avatar TM] | Tontine du marché | Mensah D. : Rappel : les parts de novembre… | Mode preuve | 09:02
    - **Élément** : [avatar KM] | Kossi M. | Merci pour hier ! | 12/10
  - **Carte**
    - **Texte** : Appui long sur une discussion
    - **Texte** : Désarchiver
    - **Texte** : Ajouter aux favoris

*Règles* : MSG-13 ; on y entre par la ligne « Archivées » en tête de la liste (APP-2).

### DIS-13 · Modifier un message

Maquette : `Discussion-13-Modifier` · « Discussions · 13. Modifier un message »

*Rôle* : corriger un message déjà envoyé.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : AS
  - **Titre** : Ama S.
  - **Texte** : en ligne
  - **Bouton icône** : Appel audio → DIS-9
  - **Bouton icône** : Appel vidéo → DIS-10
  - **Bouton icône** : Options de la discussion
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle envoyée** : Ama S. | Photo · Coucou ! Tu as bien reçu les photos ? | Oui, merci ! Elles sont magnifiques. | 16:04 · Lu
  - **Bulle reçue** : On se retrouve samedi ? | 16:05
  - **Bulle envoyée** : Oui, à la plage de Lomé ! | Modifié · 16:07 · Lu
  - **Bulle envoyée** : Je passe te prendre à 15 h. | 16:08 · Lu
- **Pied d’écran**
  - **Rangée**
    - **Texte** : Modifier le message
    - **Texte** : Je passe te prendre à 15 h.
    - **Bouton icône** : Annuler la modification
  - **Rangée**
    - **Champ** : [champ : Je passe te prendre à 16 h.]
    - **Bouton icône** : Enregistrer la modification

*Règles* : MSG-14 ; ses propres messages texte seulement, pendant 15 minutes ; la mention « Modifié » est lue par le lecteur d’écran.

### DIS-14 · Modifier en mode preuve

Maquette : `Discussion-14-Modifier-mode-preuve` · « Discussions · 14. Modifier en mode preuve »

*Rôle* : garder la trace d’une modification quand le mode preuve est actif.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : KA
  - **Titre** : Kodjo A.
  - **Texte** : mode preuve actif
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Appel vidéo
  - **Bouton icône** : Infos du contact → DIS-7
- **Encadré ambre** : Mode preuve activé par Afi. Messages supprimés ou modifiés : la version d’origine reste visible pour vous deux.
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Je te rembourse vendredi, promis. | Version d’origine · 10 h 30 | Je te rembourse les 15 000 FCFA vendredi, promis. | 10:30 · modifié à 10 h 41
  - **Bulle envoyée** : On en reparle ce soir. | 10:44 · Lu
- **Encadré ambre** : Le mode preuve est actif. La version d’origine de ton message restera visible pour vous deux, avec l’heure de la modification.
- **Pied d’écran**
  - **Rangée**
    - **Texte** : Modifier le message
    - **Texte** : On en reparle ce soir.
    - **Bouton icône** : Annuler la modification
  - **Rangée**
    - **Champ** : [champ : On en reparle ce soir, à 19 h.]
    - **Bouton icône** : Enregistrer la modification

*Règles* : section 9.3, CERT-14 et AC-CERT-05 ; seuls les messages envoyés après l’activation sont concernés ; la version d’origine est aussi dans l’export daté.

### DIS-15 · Message d’un inconnu

Maquette : `Discussion-15-Inconnu` · « Discussions · 15. Message d’un inconnu »

*Rôle* : protéger contre les arnaques au premier message d’un numéro absent des contacts.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Titre** : ~ Agent Mobile Money
  - **Texte** : Pas dans tes contacts
  - **Bouton icône** : Options
- **Contenu**
  - **Carte**
    - **Texte** : Ce numéro n’est pas dans tes contacts
    - **Texte** : Le nom affiché est choisi par l’expéditeur : il n’est pas vérifié. Pokou ne te demandera jamais ton code secret ni de l’argent.
    - **Grille de 3**
      - **Puce** : Bloquer
      - **Puce** : Signaler → DIS-16
      - **Puce** : Ajouter
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : Bonjour, votre compte sera bloqué ce soir. Envoyez votre code secret pour le réactiver. | 11:52
  - **Encadré rouge** : Ce message demande un code secret. Ne le donne jamais, même à un agent.
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer

*Règles* : MSG-17 ; la demande de code secret est repérée sur le téléphone, sans lecture par Pokou ; médias d’un inconnu jamais téléchargés automatiquement.

### DIS-16 · Signaler

Maquette : `Discussion-16-Signaler` · « Discussions · 16. Signaler »

*Rôle* : signaler une discussion au support.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Titre** : ~ Agent Mobile Money
  - **Texte** : Pas dans tes contacts
  - **Bouton icône** : Options
- **Contenu**
  - **Carte**
    - **Texte** : Ce numéro n’est pas dans tes contacts
    - **Texte** : Le nom affiché est choisi par l’expéditeur : il n’est pas vérifié. Pokou ne te demandera jamais ton code secret ni de l’argent.
    - **Grille de 3**
      - **Puce** : Bloquer
      - **Puce** : Signaler → DIS-16
      - **Puce** : Ajouter
  - **Bulle reçue** : Bonjour, votre compte sera bloqué ce soir. Envoyez votre code secret pour le réactiver. | 11:52
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Titre de section** : Signaler ~ Agent Mobile Money
  - **Carte**
    - **Choix** : ◉ | Arnaque ou demande d’argent
    - **Choix** : ○ | Se fait passer pour quelqu’un
    - **Choix** : ○ | Spam ou publicité
    - **Choix** : ○ | Contenu choquant
    - **Choix** : ○ | Autre
  - **Carte** : Les 5 derniers messages de cette discussion sont envoyés au support de Pokou avec ton signalement. Il ne voit rien d’autre.
  - **Case à cocher** : ☑ | Bloquer aussi ce numéro
  - **Bouton rouge** : Envoyer le signalement
  - **Ligne** : Annuler → DIS-15

*Règles* : MSG-11 ; le signalé n’est pas prévenu ; accusé de réception dans l’application.

### DIS-17 · Appel entrant

Maquette : `Discussion-17-Appel-entrant` · « Discussions · 17. Appel entrant »

*Rôle* : recevoir un appel quand l’application est ouverte.

**Disposition et textes**

- **Fond** : dégradé sombre plein écran
- **Texte** : Appel audio entrant
- **Avatar** : AS
- **Titre** : Ama S.
- **Texte** : Pokou · appel audio
- **Texte** : Répondre par message
- **Groupe de puces**
  - **Puce** : Je te rappelle
  - **Puce** : Je ne peux pas parler
  - **Puce** : Écris-moi
- **Rangée**
  - **Tuile** : Refuser
  - **Tuile** : Accepter → DIS-9

*Règles* : MSG-21 et MSG-09 ; écran verrouillé : écran d’appel du système (CallKit, ConnectionService) ; « Couper les appels d’inconnus » (REG-1) s’applique.

### DIS-18 · Appel de groupe

Maquette : `Discussion-18-Appel-groupe` · « Discussions · 18. Appel de groupe »

*Rôle* : appel audio à plusieurs depuis un groupe.

**Disposition et textes**

- **Fond** : dégradé sombre plein écran
- **En-tête**
  - **Bouton icône** : Réduire l’appel → DIS-1
  - **Titre** : Famille Koffi
  - **Texte** : Appel audio · 4 participants · 08:12
  - **Bouton icône** : Ajouter un participant
- **Avatar** : EK
- **Texte** : Edem K.
- **Avatar** : MA
- **Texte** : Maman
- **Avatar** : KK
- **Texte** : Kafui K.
- **Avatar** : AK
- **Texte** : Toi
- **Texte** : Edem parle
- **Grille de 4**
  - **Bouton icône** : Haut-parleur
  - **Texte** : Haut-parleur
  - **Bouton icône** : Micro
  - **Texte** : Micro
  - **Bouton icône** : Vidéo
  - **Texte** : Vidéo
  - **Bouton icône** : Quitter
  - **Texte** : Quitter

*Règles* : MSG-21 ; taille maximale paramétrable ; « Edem parle » annoncé aux lecteurs d’écran.

### DIS-19 · Hors ligne et appel manqué

Maquette : `Discussion-19-Hors-ligne` · « Discussions · 19. Hors ligne et appel manqué »

*Rôle* : montrer l’état des messages quand le réseau manque.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : AS
  - **Titre** : Ama S.
  - **Texte** : en ligne
  - **Bouton icône** : Appel audio → DIS-9
  - **Bouton icône** : Appel vidéo → DIS-10
  - **Bouton icône** : Options de la discussion
- **Encadré beige** : Pas de connexion. Tes messages partiront dès le retour du réseau.
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue** : On se retrouve samedi ? | 16:05
  - **Carte**
    - **Texte** : Appel audio manqué
    - **Texte** : 15:40
    - **Puce** : Rappeler → DIS-9
  - **Bulle envoyée** : Désolée, j’étais au marché. | 16:12 · Lu
  - **Bulle envoyée** : J’arrive dans 10 minutes. | 16:20 | En attente
  - **Bulle envoyée** : Tu peux prendre du pain en passant ? | 16:21
  - **Puce** : Non envoyé · Réessayer
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer

*Règles* : MSG-02, MSG-03 et MSG-21 ; l’envoi reprend seul au retour du réseau ; « Réessayer » seulement après échec définitif.

### DIS-20 · Sondage et mentions

Maquette : `Discussion-20-Sondage-mentions` · « Discussions · 20. Sondage et mentions »

*Rôle* : décider ensemble dans un groupe et interpeller quelqu’un.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Ligne** : [avatar FK] | Famille Koffi | 9 membres → DIS-8
  - **Bouton icône** : Appel vidéo de groupe
  - **Bouton icône** : Appel audio de groupe
  - **Bouton icône** : Infos du groupe → DIS-8
- **Contenu**
  - **Bulle reçue** : Edem K. | Sondage · un seul choix | Quel jour pour la fête de Papa ? | Samedi 2 novembre | 5 | [barre 62%] | Dimanche 3 novembre | 3 | [barre 38%] | 8 votes · Voir les votes | 16:30
  - **Bulle reçue** : Kafui K. | @Afi | tu t’occupes des boissons ? | 17:02
- **Pied d’écran**
  - **Carte** : Mentionner | [avatar KK] | Kafui K.
  - **Rangée**
    - **Bouton icône** : Joindre un fichier → DIS-2
    - **Champ** : [champ : Oui, je m’en occupe @Ka]
    - **Bouton icône** : Envoyer

*Règles* : MSG-16 ; une mention notifie même si le groupe est en sourdine ; sondages créés depuis « Joindre » (DIS-2).

### DIS-21 · Journal d’appels

Maquette : `Discussion-21-Journal-appels` · « Discussions · 21. Journal d’appels »

*Rôle* : retrouver ses appels et rappeler en un geste, dans l’application complète.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Appels
  - **Bouton icône** : Rechercher un appel
- **Rangée**
  - **Filtre (sélectionné)** : Tous
  - **Filtre** : Manqués · 1
- **Contenu**
  - **Titre de section** : Aujourd’hui
  - **Liste**
    - **Élément**
      - **Avatar** : AS
      - **Texte** : Ama S.
      - **Texte** : Sortant · 4 min 12
      - **Texte** : 16:10
      - **Bouton icône** : Rappeler Ama S. → DIS-9
    - **Élément**
      - **Avatar** : KK
      - **Texte** : Kafui K. (2)
      - **Texte** : Manqué
      - **Texte** : 15:40
      - **Bouton icône** : Rappeler Kafui K. (2) → DIS-9
    - **Élément**
      - **Avatar** : FK
      - **Texte** : Famille Koffi
      - **Texte** : Vidéo de groupe · 5 personnes · 18 min
      - **Texte** : 12:05
      - **Bouton icône** : Rappeler en vidéo Famille Koffi → DIS-10
    - **Élément**
      - **Texte** : +228 9• •• •• 41
      - **Texte** : Inconnu, appel coupé
      - **Texte** : 09:12
      - **Bouton icône** : Rappeler +228 9• •• •• 41 → REG-1
  - **Titre de section** : Hier
  - **Liste**
    - **Élément**
      - **Avatar** : EK
      - **Texte** : Edem K.
      - **Texte** : Entrant · 12 min
      - **Texte** : 19:22
      - **Bouton icône** : Rappeler Edem K. → DIS-9
    - **Élément**
      - **Avatar** : KA
      - **Texte** : Kodjo A.
      - **Texte** : Vidéo sortant · 2 min
      - **Texte** : 08:47
      - **Bouton icône** : Rappeler en vidéo Kodjo A. → DIS-10
  - **Texte** : Les appels d’inconnus coupés restent dans la liste. Tu peux les rappeler ou les bloquer.
- **Bouton principal** : Nouvel appel → DIS-5

*Règles* : MSG-21 et MSG-23 ; ouvert depuis Plus › Appels ; au lot 1, c’est l’onglet Appels (LOT-3).

### DIS-22 · Rechercher

Maquette : `Discussion-22-Recherche` · « Discussions · 22. Rechercher »

*Rôle* : retrouver une discussion, un message, une photo ou un lien.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Carte** : sam
- **Texte** : Tout | Discussions | Messages | Photos | Liens
- **Contenu**
  - **Titre de section** : Discussions
  - **Liste**
    - **Ligne** : [avatar SK] | Séna K. | Lun. | Dernier message : Samedi, c’est noté → APP-2b
  - **Titre de section** : Messages · 4
  - **Liste**
    - **Ligne** : [avatar AS] | Ama S. | 16:05 | On se retrouve samedi ? → APP-2b
    - **Ligne** : [avatar FK] | Famille Koffi | Hier | Maman : Rendez-vous samedi à 10 h chez Papa. → DIS-1
    - **Ligne** : [avatar CB] | Collègues du bureau | 28/10 | Yao A. : Réunion déplacée à samedi matin. → PRV-5
    - **Ligne** : [avatar EK] | Edem K. | 21/10 | Samuel arrive par le car de 14 h. → STA-7

*Règles* : MSG-11, MSG-24 et NAV-07 ; la recherche porte sur les messages enregistrés sur le téléphone.

### DIS-23 · Transférer

Maquette : `Discussion-23-Transferer` · « Discussions · 23. Transférer »

*Rôle* : envoyer un message reçu vers d’autres discussions.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → DIS-3
  - **Titre** : Transférer à…
  - **Texte** : Jusqu’à 5 discussions
- **Encadré beige** : Rechercher
- **Carte** : « Oui, merci ! Elles sont magnifiques. »
- **Contenu**
  - **Titre de section** : Récentes
  - **Liste**
    - **Case à cocher** : [avatar FK] | Famille Koffi | Groupe · 9 membres | ☑
    - **Case à cocher** : [avatar EK] | Edem K. | Disponible | ☑
    - **Case à cocher** : [avatar CB] | Collègues du bureau | Groupe · mode preuve | ☐
    - **Case à cocher** : [avatar KK] | Kafui K. | Disponible | ☐
    - **Case à cocher** : [avatar KA] | Kodjo A. | Salut, je suis sur Pokou ! | ☐
  - **Texte** : Le message porte la mention « Transféré ». Envoyé plus de 5 fois, il devient « Transféré plusieurs fois ».
- **Pied d’écran**
  - **Bouton principal** : Envoyer à 2 discussions → APP-2b

*Règles* : MSG-08 et MSG-25.

### DIS-24 · Aperçu avant l’envoi

Maquette : `Discussion-24-Apercu-photo` · « Discussions · 24. Aperçu avant envoi »

*Rôle* : vérifier les photos choisies et ajouter une légende.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Fermer → DIS-2
  - **Texte** : Envoyer à Famille Koffi
  - **Bouton icône** : Ajouter du texte
  - **Bouton icône** : Dessiner
- **Contenu**
  - **Illustration** : Photo choisie : coucher de soleil sur la lagune
- **Texte** : [icône : Photo 1] | [icône : Photo 2]
- **Rangée**
  - **Texte** : Ajouter une légende…
  - **Filtre** : HD
  - **Bouton icône** : Envoyer 2 photos → DIS-1
- **Texte** : Photos compressées pour économiser tes données. « HD » envoie la qualité d’origine.

*Règles* : MSG-05 et MSG-26 ; « HD » désactivé par défaut, surtout en économie de données (MSG-19).

### DIS-25 · Visionneuse

Maquette : `Discussion-25-Visionneuse` · « Discussions · 25. Voir une photo »

*Rôle* : voir une photo reçue en plein écran.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour à la discussion → DIS-1
  - **Texte** : Séna K.
  - **Texte** : Famille Koffi · aujourd’hui, 15:10
  - **Bouton icône** : Partager
- **Contenu**
  - **Illustration** : Photo : coucher de soleil sur la lagune
  - **Texte** : Le coucher de soleil depuis la maison de Papa.
- **Grille de 4**
  - **Tuile** : Répondre
  - **Tuile** : Transférer
  - **Tuile** : Enregistrer
  - **Tuile** : Réagir

*Règles* : MSG-26 ; « Enregistrer » copie la photo dans la galerie du téléphone, jamais automatiquement (MSG-19).

### DIS-26 · Gérer le groupe

Maquette : `Discussion-26-Gerer-groupe` · « Discussions · 26. Gérer le groupe »

*Rôle* : pour les administrateurs, régler le fonctionnement du groupe.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → DIS-8
  - **Titre** : Gérer le groupe
  - **Texte** : Famille Koffi · 9 membres
- **Contenu**
  - **Titre de section** : Autorisations
  - **Carte**
    - **Interrupteur** : Modifier le nom et la photo | Réservé aux administrateurs | [interrupteur désactivé]
    - **Interrupteur** : Envoyer des messages | Tous les membres | [interrupteur activé]
    - **Interrupteur** : Approuver les nouveaux membres | Un administrateur valide chaque entrée | [interrupteur activé]
  - **Titre de section** : Membres
  - **Carte**
    - **Texte** : Administrateurs | Edem K., toi
    - **Texte** : Lien d’invitation | Valable 7 jours, à révoquer à tout moment
    - **Ligne** : Mode preuve | Désactivé → PRV-4
  - **Carte** : Quitter le groupe | Signaler le groupe
  - **Texte** : Quitter le groupe ne supprime pas la cagnotte en cours : tes contributions restent dans le journal Kory.

*Règles* : MSG-07 et MSG-27 ; la trace du mode preuve reste après un départ (CERT-15).

### DIS-27 · Contacts bloqués

Maquette : `Discussion-27-Bloques` · « Discussions · 27. Contacts bloqués »

*Rôle* : voir et lever ses blocages.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → REG-1
  - **Titre** : Contacts bloqués
  - **Texte** : 3 personnes
- **Contenu**
  - **Liste**
    - **Élément**
      - **Texte** : +228 9• •• •• 41
      - **Texte** : Bloqué le 28 oct. · après un signalement
      - **Bouton secondaire** : Débloquer
    - **Élément**
      - **Avatar** : KA
      - **Texte** : Koku A.
      - **Texte** : Bloqué le 12 oct.
      - **Bouton secondaire** : Débloquer
    - **Élément**
      - **Texte** : +225 07 •• •• 18
      - **Texte** : Bloqué le 2 sept.
      - **Bouton secondaire** : Débloquer
  - **Carte** : Une personne bloquée ne peut ni t’appeler ni t’écrire. Elle ne voit plus ta photo, ton « Vu à » ni tes statuts. Elle n’est pas prévenue.
  - **Texte** : Le blocage vaut aussi dans les groupes en commun : tu ne reçois plus ses appels de groupe.
- **Pied d’écran**
  - **Bouton secondaire** : Bloquer un contact

*Règles* : MSG-11, MSG-18 et MSG-28 ; la personne bloquée n’est pas prévenue.

## 9.7 Statuts

### STA-1 · Statuts

Maquette : `Statuts-1-Liste` · « Statuts · 1. Statuts »

*Rôle* : voir les statuts de ses contacts et publier le sien.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-2
  - **Titre** : Statuts
  - **Texte** : Visibles 24 h, puis ils disparaissent
  - **Bouton icône** : Statut photo → STA-5
  - **Bouton icône** : Statut texte → STA-3
- **Contenu**
  - **Ligne** : [avatar AK] | Mon statut | Touche pour ajouter un statut → STA-3
  - **Titre de section** : Récents
  - **Ligne** : [avatar MD] | Mensah D. | Il y a 12 minutes → STA-2
  - **Texte** : [avatar EK] | Edem K. | Il y a 1 heure
  - **Texte** : [avatar AS] | Ama S. | Il y a 3 heures
  - **Titre de section** : Vus
  - **Texte** : [avatar KK] | Kafui K. | Hier, 21:40
  - **Carte**
    - **Ligne** : Qui voit mes statuts | Mes contacts → STA-4

*Règles* : MSG-15 ; aucun compteur public ; badge Pokou certifié ou Pro selon le titulaire.

### STA-2 · Voir un statut

Maquette : `Statuts-2-Voir` · « Statuts · 2. Voir un statut »

*Rôle* : regarder un statut, ici celui d’une commerçante Pro.

**Disposition et textes**

- **Fond** : voile sombre sur l’écran
- **Illustration** : Photo : pile de pagnes wax colorés
- **Rangée**
  - **Bouton icône** : Fermer → STA-1
  - **Avatar** : MD
  - **Ligne** : Boutique Mensah → PRO-5
  - **Texte** : Il y a 12 minutes
  - **Bouton icône** : Options du statut
- **Puce** : Voir l’annonce · 12 000 FCFA → ANN-3
- **Texte** : Arrivage de pagnes wax ce matin. 6 yards à 12 000 FCFA, allée 4 du marché de Bè.
- **Rangée**
  - **Champ** : [champ : « Répondre à Mensah… »]
  - **Bouton icône** : Aimer le statut
- **Texte** : Ta réponse arrive en privé, dans votre discussion à deux.

*Règles* : MSG-15 ; pause automatique pendant la saisie ; légende lue par le lecteur d’écran.

### STA-3 · Créer un statut

Maquette : `Statuts-3-Creer` · « Statuts · 3. Créer un statut »

*Rôle* : publier un statut texte, photo ou vidéo.

**Disposition et textes**

- **Fond** : voile sombre sur l’écran
- **En-tête**
  - **Bouton icône** : Fermer → STA-1
  - **Lien** : Aa
  - **Bouton icône** : Changer la couleur du fond
- **Texte** : Réunion des parents samedi à 16 h, école de Bè.
- **Puces** : Texte | Photo | Vidéo
- **Rangée**
  - **Puce** : Mes contacts → STA-4
  - **Bouton icône** : Publier le statut → STA-1

*Règles* : MSG-15 ; contrastes du texte vérifiés sur chaque fond proposé ; vidéo courte, compressée avant envoi (MSG-05).

### STA-4 · Qui voit mes statuts

Maquette : `Statuts-4-Confidentialite` · « Statuts · 4. Qui voit mes statuts »

*Rôle* : choisir l’audience des statuts.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → STA-1
  - **Titre** : Qui voit mes statuts
- **Contenu**
  - **Carte**
    - **Choix** : ◉ | Mes contacts | Tous les contacts enregistrés sur ton téléphone
    - **Choix** : ○ | Mes contacts sauf… | 2 contacts exclus
    - **Choix** : ○ | Seulement avec…
  - **Carte**
    - **Élément** : Un statut disparaît après 24 h
    - **Élément** : Toi seul vois qui a vu tes statuts | Personne d’autre ne voit ce nombre
    - **Élément** : Une réponse arrive en privé | Dans votre discussion à deux
    - **Élément** : Tout statut peut être signalé
  - **Carte** : Les statuts ne sont pas des messages d’une discussion : le mode preuve ne les concerne pas.

*Règles* : MSG-15 et MSG-18 ; le réglage vaut pour les statuts suivants.

### STA-5 · Statut photo

Maquette : `Statuts-5-Photo` · « Statuts · 5. Statut photo »

*Rôle* : publier une photo en statut.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Fermer → STA-1
  - **Bouton icône** : Ajouter du texte
  - **Bouton icône** : Dessiner
- **Contenu**
  - **Illustration** : Photo du statut : coucher de soleil
  - **Texte** : Arrivée à Kpalimé ce matin
- **Rangée**
  - **Ligne** : Visible par : Mes contacts → STA-4
  - **Bouton icône** : Publier le statut → STA-1

*Règles* : MSG-15 et MSG-29 ; photo compressée comme dans les discussions (MSG-05).

### STA-6 · Vu par

Maquette : `Statuts-6-Vu-par` · « Statuts · 6. Vu par »

*Rôle* : pour l’auteur, savoir qui a vu son statut.

**Disposition et textes**

- **Illustration** : Mon statut photo
- **En-tête**
  - **Avatar** : AK
  - **Texte** : Mon statut
  - **Texte** : Il y a 2 heures
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Rangée**
    - **Titre de section** : Vu par 14
    - **Bouton icône** : Fermer → STA-1
  - **Liste**
    - **Élément** : [avatar MA] | Maman | Aujourd’hui, 10:58
    - **Élément** : [avatar AS] | Ama S. | Aujourd’hui, 10:42
    - **Élément** : [avatar EK] | Edem K. | Aujourd’hui, 10:30
    - **Élément** : [avatar KK] | Kafui K. | Aujourd’hui, 09:58
  - **Texte** : Toi seul vois cette liste. Les réponses arrivent en privé, dans vos discussions.
  - **Grille de 2**
    - **Bouton secondaire** : Transférer
    - **Bouton secondaire** : Supprimer

*Règles* : MSG-15 et MSG-29 ; liste invisible des autres contacts.

### STA-7 · Réponse à un statut

Maquette : `Statuts-7-Reponse` · « Statuts · 7. Réponse privée »

*Rôle* : montrer où arrive une réponse à un statut.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : EK
  - **Titre** : Edem K.
  - **Texte** : vu à 10:31
  - **Bouton icône** : Appel audio → DIS-9
  - **Bouton icône** : Appel vidéo → DIS-10
  - **Bouton icône** : Options de la discussion
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Message système** : Ta réponse au statut d’Edem est arrivée ici, en privé. Les autres contacts ne la voient pas.
  - **Bulle envoyée** : [icône : Statut d’Edem] | Edem K. · Statut | Vue sur le mont Agou | Superbe vue ! C’est où exactement ? | 10:34 · Lu
  - **Bulle reçue** : Au mont Agou, on est montés ce matin avec Kafui. | 10:36
  - **Bulle reçue** : Je t’envoie les autres photos ce soir. | 10:36
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier → DIS-2
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale → DIS-4
  - **Bouton icône** : Envoyer

*Règles* : MSG-15 et MSG-29 ; les autres contacts ne voient pas la réponse.

## 9.8 Pokou certifié Pro : parcours et profil

### PRO-1 · Offre Pro

Maquette : `Pro-1-Offre` · « Pokou certifié Pro · 1. Offre »

*Rôle* : présenter Pokou certifié Pro, depuis l’offre Pokou certifié (CRT-1).

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → CRT-1
  - **Titre** : Pokou certifié Pro
- **Contenu**
  - **Texte** : Pour les commerçants et les organisations | Commerçants, vendeurs, entreprises, associations
  - **Liste**
    - **Élément** : Ton nom commercial vérifié, avec le badge Pro
    - **Élément** : Un profil Pro : adresse, horaires, activité
    - **Élément** : Le badge Pro sur tes statuts, puis sur tes annonces Assimé
    - **Élément** : Le mode preuve et l’export daté, comme Pokou certifié
  - **Carte** : 2 500 FCFA HT | par mois | 2 950 FCFA TTC · résiliable à tout moment
  - **Titre de section** : Comment ça marche
  - **Étapes**
    - **Élément** : 1 | Envoie ton justificatif | RCCM, NIF ou récépissé d’association (à venir)
    - **Élément** : 2 | Pokou vérifie sous 48 h | Tu es prévenu dès la décision (à venir)
    - **Élément** : 3 | Tu paies et ton badge s’affiche | Aucun paiement avant la validation (à venir)
- **Pied d’écran**
  - **Bouton principal** : Commencer → PRO-2

*Règles* : section 9.1 ; prix HT et TTC (BM-10).

### PRO-2 · Ton activité

Maquette : `Pro-2-Justificatif` · « Pokou certifié Pro · 2. Ton activité »

*Rôle* : déclarer l’activité et envoyer le justificatif.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → PRO-1
  - **Titre** : Ton activité
  - **Texte** : Pokou certifié Pro · étape 1 sur 3
- **Contenu**
  - **Champ** : Nom commercial = Boutique Mensah
  - **Champ** : Activité = Commerce · tissus et pagnes
  - **Champ** : Adresse ou repère = Marché de Bè, allée 4, Lomé
  - **Texte** : Justificatif
  - **Texte** : RCCM
  - **Carte** : NIF
  - **Carte** : Récépissé
  - **Carte**
    - **Rangée**
      - **Texte** : RCCM_Boutique_Mensah.jpg
      - **Texte** : Photo lisible · 1,1 Mo
      - **Puce** : Changer
  - **Carte** : Le nom commercial doit figurer sur le justificatif. Ton nom vérifié reste visible sous le nom commercial : « Géré par Mensah D. ».
- **Pied d’écran**
  - **Bouton principal** : Envoyer pour vérification → PRO-3

*Règles* : section 9.2 ; photo prise par l’application ou choisie dans la galerie ; document chiffré, supprimé 30 jours après la décision (durée à confirmer).

### PRO-3 · Vérification en cours

Maquette : `Pro-3-Verification` · « Pokou certifié Pro · 3. Vérification en cours »

*Rôle* : faire patienter pendant la vérification.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Vérification en cours
  - **Texte** : Pokou certifié Pro · étape 2 sur 3
- **Contenu**
  - **Texte** : Le support de Pokou vérifie ton justificatif sous 48 h. Tu reçois une notification dès la décision.
  - **Carte** : Justificatif envoyé | Aujourd’hui, 09:12 | Vérification par le support | Au plus tard le 2 nov. à 09:12 | 3 | Paiement et badge Pro | Après la validation
  - **Carte** : En attendant, tu gardes ton badge Pokou certifié, tes discussions et le mode preuve.
- **Pied d’écran**
  - **Bouton principal** : Terminé → APP-6

*Règles* : CERT-17 ; notification à la décision.

### PRO-4 · Justificatif à corriger

Maquette : `Pro-4-A-corriger` · « Pokou certifié Pro · 4. Justificatif à corriger »

*Rôle* : expliquer un refus et permettre de corriger.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Justificatif à corriger
  - **Texte** : Pokou certifié Pro
- **Contenu**
  - **Encadré rouge** : Le nom ne correspond pas | « Boutique Mensah » ne figure pas sur le RCCM envoyé. Le document indique « Ets Mensah et Fils ».
  - **Titre de section** : Que veux-tu faire ?
  - **Carte**
    - **Choix** : ◉ | Utiliser « Ets Mensah et Fils » | Le nom inscrit sur ton RCCM
    - **Choix** : ○ | Envoyer un autre justificatif
  - **Carte** : Aucun paiement n’a été pris. Tu peux renvoyer autant de fois que nécessaire.
- **Pied d’écran**
  - **Bouton principal** : Corriger et renvoyer → PRO-3
  - **Ligne** : Contacter le support

*Règles* : CERT-17 ; renvois illimités.

### PRO-6 · Validation et paiement

Maquette : `Pro-6-Validation-paiement` · « Pokou certifié Pro · 6. Validé : payer »

*Rôle* : annoncer la validation et faire payer le badge Pro, seulement à ce moment.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Pokou certifié Pro
  - **Texte** : Étape 3 sur 3
- **Contenu**
  - **Texte** : Bonne nouvelle : Boutique Mensah est vérifiée.
  - **Carte** : Justificatif envoyé | 30 oct., 09:12 | RCCM vérifié par le support | 1er nov., 15:40 | Paiement et badge Pro | Ton nom commercial s’affiche dès le paiement
  - **Carte**
    - **Texte** : Pokou certifié Pro | résiliable à tout moment
    - **Texte** : par mois
    - **Texte** : 2 950 FCFA TTC
  - **Carte** : Ton badge Pokou certifié s’arrête : le badge Pro le remplace, sans double paiement.
- **Pied d’écran**
  - **Bouton principal** : Payer 2 950 FCFA TTC → PRO-5

*Règles* : CERT-17 et CERT-19 ; prix HT et TTC affichés (BM-10).

### PRO-5 · Profil Pro

Maquette : `Pro-5-Profil` · « Pokou certifié Pro · 5. Profil Pro »

*Rôle* : présenter un professionnel à ses clients.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour à la discussion → STA-2
  - **Titre** : Profil
- **Contenu**
  - **Avatar** : BM
  - **Texte** : Boutique Mensah
  - **Texte** : Géré par Mensah D. · nom vérifié
  - **Ligne** : 4,8 | · 37 ventes notées → ANN-20
  - **Puce** : Tissus et pagnes
  - **Rangée**
    - **Bouton secondaire** : Message
    - **Bouton secondaire** : Audio
    - **Bouton secondaire** : Partager
  - **Carte**
    - **Élément** : Marché de Bè, allée 4, Lomé | Adresse déclarée
    - **Élément** : Lun. au sam., 7 h à 18 h | Ouvert
    - **Élément** : Pokou certifié Pro depuis octobre 2026 | RCCM vérifié par le support
  - **Ligne** : Statut récent | Arrivage de pagnes wax ce matin → STA-2
  - **Ligne** : [icône : Photo de l’annonce] | [icône : Photo de l’annonce] | [icône : Photo de l’annonce] | 12 annonces sur Assimé | Pagnes, sacs, tissus → ANN-3
  - **Carte** : Signaler Boutique Mensah

*Règles* : CERT-17 ; adresse et horaires déclarés par le titulaire, non vérifiés ; aucun numéro affiché.

## 9.9 Réglages, sécurité et changement de téléphone

### REG-1 · Confidentialité

Maquette : `Reglages-1-Confidentialite` · « Réglages · 1. Confidentialité »

*Rôle* : régler qui voit quoi et se protéger des inconnus.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Confidentialité
- **Contenu**
  - **Titre de section** : Qui peut voir
  - **Carte**
    - **Texte** : Vu à | Mes contacts
    - **Texte** : Photo de profil | Mes contacts
    - **Ligne** : Statuts | Mes contacts → STA-4
  - **Carte**
    - **Interrupteur** : Accusés de lecture | Désactivés, tu ne vois plus ceux des autres | [interrupteur activé]
  - **Titre de section** : Groupes et inconnus
  - **Carte**
    - **Texte** : Qui peut m’ajouter aux groupes | Les autres t’envoient une invitation | Mes contacts
    - **Interrupteur** : Couper les appels d’inconnus | Ils restent dans la liste des appels | [interrupteur activé]
    - **Ligne** : Bloqués | 3 → DIS-27
  - **Carte**
    - **Ligne** : Stockage et données | 1,8 Go → REG-2

*Règles* : MSG-18 ; sans droit d’ajout, l’autre envoie une invitation.

### REG-2 · Stockage et données

Maquette : `Reglages-2-Stockage` · « Réglages · 2. Stockage et données »

*Rôle* : garder de la place sur les téléphones d’entrée de gamme et maîtriser les données mobiles.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → REG-1
  - **Titre** : Stockage et données
- **Contenu**
  - **Carte** : Téléphone · 32 Go | 3,1 Go libres | Pokou 1,8 Go | Autres | Libre
  - **Titre de section** : Gérer le stockage
  - **Carte**
    - **Texte** : [avatar FK] | Famille Koffi | 640 Mo
    - **Texte** : [avatar CB] | Collègues du bureau | 410 Mo
    - **Texte** : [avatar AS] | Ama S. | 220 Mo
    - **Texte** : Fichiers de plus de 5 Mo | 38
  - **Titre de section** : Téléchargement automatique
  - **Carte**
    - **Texte** : En données mobiles | Rien
    - **Texte** : En Wi-Fi | Photos
    - **Interrupteur** : Économiser les données pendant les appels | Qualité réduite, appel plus stable | [interrupteur activé]

*Règles* : MSG-05 et MSG-19 ; en mode preuve, supprimer un média chez soi ne change rien chez les autres.

### REG-3 · Compte et sécurité

Maquette : `Reglages-3-Compte-securite` · « Réglages · 3. Compte et sécurité »

*Rôle* : regrouper ce qui protège le compte.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Compte et sécurité
- **Contenu**
  - **Carte**
    - **Ligne** : Code PIN | Demandé sur un nouveau téléphone | Désactivé → REG-5
    - **Ligne** : Sauvegarde | Google Drive · 30 oct., 02:14 → REG-2
    - **Ligne** : Changer de numéro → REG-4
    - **Texte** : Appareils connectés | 1
  - **Carte** : Télécharger mes données | Profil, contacts et réglages, en fichier
  - **Carte**
    - **Ligne** : Supprimer mon compte → REG-7
  - **Encadré ambre** : Pokou ne te demandera jamais ton code PIN ni le code reçu par SMS, ni par message ni par appel.

*Règles* : AUTH-02, AUTH-04, AUTH-06, MSG-12 et MSG-20.

### REG-4 · Changer de numéro

Maquette : `Reglages-4-Changer-numero` · « Réglages · 4. Changer de numéro »

*Rôle* : garder son compte avec une nouvelle puce.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Changer de numéro
- **Contenu**
  - **Carte**
    - **Texte** : Ancien numéro | +228 •• •• •• 47
    - **Champ** : Nouveau numéro = +228 | [champ : « Numéro »]
  - **Titre de section** : Prévenir mes contacts
  - **Carte**
    - **Choix** : ○ | Tous mes contacts
    - **Choix** : ◉ | Ceux avec qui j’ai discuté
    - **Choix** : ○ | Personne | Tes groupes sont toujours prévenus
  - **Carte** : Ton compte, tes discussions, ton badge Pokou certifié et tes cagnottes Kory te suivent. Un code est envoyé au nouveau numéro.
  - **Encadré ambre** : Si tu es collecteur d’une cagnotte, ton numéro de collecte ne change pas tout seul : modifie-le dans Kory, les membres en seront prévenus.
- **Pied d’écran**
  - **Bouton principal** : Envoyer le code

*Règles* : MSG-20 ; le numéro de collecte Kory ne change pas tout seul (KORY-06).

### REG-5 · Code PIN

Maquette : `Reglages-5-Code-PIN` · « Réglages · 5. Activer le code PIN »

*Rôle* : activer la vérification en deux étapes.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → REG-3
  - **Titre** : Code PIN
- **Contenu**
  - **Texte** : Choisis un code à 6 chiffres. Il est demandé quand ton numéro se connecte sur un nouveau téléphone.
  - **Texte** : Confirme ton code
  - **Texte** : [4 chiffres saisis sur 6]
  - **Carte**
    - **Interrupteur** : Me le redemander de temps en temps | Pour ne pas l’oublier | [interrupteur activé]
  - **Carte** : Ton code PIN protège ton compte si quelqu’un récupère ta carte SIM. Ne le note pas dans ton téléphone.
- **Pied d’écran**
  - **Bouton principal** : Activer le code PIN → REG-3

*Règles* : AUTH-04 et AUTH-11.

### REG-6 · Code PIN oublié

Maquette : `Reglages-6-PIN-oublie` · « Réglages · 6. Code PIN oublié »

*Rôle* : retrouver son compte sans code PIN, sans le livrer à un voleur de carte SIM.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → CNX-1
  - **Titre** : Code PIN oublié
- **Contenu**
  - **Texte** : Deux façons de retrouver ton compte :
  - **Choix** : ○ | Par e-mail | Si tu as ajouté une adresse : un lien de réinitialisation t’est envoyé
  - **Choix** : ◉ | Attendre 7 jours | Ensuite, tu te connectes sans code PIN avec le code SMS, à condition de garder ton numéro
  - **Encadré ambre** : Le délai de 7 jours empêche quelqu’un qui aurait volé ta carte SIM de prendre ton compte tout de suite.
  - **Texte** : Pendant l’attente, tes contacts continuent de te voir et tes messages t’attendent.
- **Pied d’écran**
  - **Bouton principal** : Continuer → CNX-1

*Règles* : AUTH-11.

### REG-7 · Supprimer mon compte

Maquette : `Reglages-7-Supprimer-compte` · « Réglages · 7. Supprimer mon compte »

*Rôle* : supprimer son compte en sachant ce qui reste.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → REG-3
  - **Titre** : Supprimer mon compte
- **Contenu**
  - **Encadré rouge** : Cette action est définitive.
  - **Carte**
    - **Texte** : Ce qui est supprimé
    - **Texte** : Ton profil, ta photo et ta sauvegarde
    - **Texte** : Tes discussions sur ce téléphone
    - **Texte** : Ton badge, sans remboursement du mois en cours
  - **Carte**
    - **Texte** : Ce qui reste
    - **Texte** : Les messages déjà reçus par tes contacts
    - **Texte** : Les traces du mode preuve chez les autres participants
    - **Texte** : Le journal des cagnottes Kory, qui ne s’efface pas
  - **Champ** : Confirme ton numéro = +228 90 00 00 00
- **Pied d’écran**
  - **Bouton rouge** : Supprimer mon compte
  - **Ligne** : Annuler → REG-3

*Règles* : AUTH-06, AUTH-12 et CERT-15 ; remboursement du mois en cours à arbitrer (annexe B, n° 35).

### REG-8 · Notifications

Maquette : `Reglages-8-Notifications` · « Réglages · 8. Notifications »

*Rôle* : régler les notifications par type.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Notifications
- **Contenu**
  - **Titre de section** : Messages
  - **Carte**
    - **Interrupteur** : Discussions à deux | [interrupteur activé]
    - **Interrupteur** : Groupes | [interrupteur activé]
    - **Interrupteur** : Aperçu du message | Le texte n’apparaît pas sur l’écran verrouillé | [interrupteur désactivé]
    - **Interrupteur** : Réactions | [interrupteur activé]
  - **Titre de section** : Appels
  - **Carte**
    - **Texte** : Sonnerie | Pokou
    - **Interrupteur** : Vibreur | [interrupteur activé]
  - **Titre de section** : Modules
  - **Carte**
    - **Interrupteur** : Kory | Engagements, rappels de versement, clôtures | [interrupteur activé]
    - **Interrupteur** : Honam | Devis, livraison, code de remise | [interrupteur activé]
    - **Interrupteur** : Assimé | Alertes de recherche, au plus une par jour | [interrupteur activé]

*Règles* : MSG-10 et section 16.1 ; aperçu masqué par défaut ; les notifications de commande Honam restent transactionnelles : l’interrupteur Honam ne coupe que le son et la vibration Recommandation ; la partie Modules n’apparaît que pour les modules ouverts.

### REG-9 · Langue

Maquette : `Reglages-9-Langue` · « Réglages · 9. Langue »

*Rôle* : choisir la langue de l’application.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Langue
- **Contenu**
  - **Choix** : ◉ | Français | Langue du téléphone
  - **Choix** : ○ | English
  - **Texte** : La langue de l’application ne change pas celle de tes messages. Les noms Pokou, Kory, Honam et Assimé restent les mêmes dans toutes les langues.

*Règles* : section 15.2.

### REG-10 · Aide et support

Maquette : `Reglages-10-Aide` · « Réglages · 10. Aide et support »

*Rôle* : trouver une réponse ou écrire au support.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Aide et support
- **Contenu**
  - **Encadré beige** : Rechercher dans l’aide
  - **Ligne** : Demander à Baba | L’assistant IA répond tout de suite → INS-4
  - **Titre de section** : Questions fréquentes
  - **Carte**
    - **Texte** : Pokou touche-t-il mon argent ?
    - **Texte** : Comment marche le mode preuve ?
    - **Texte** : Je ne reçois pas le code SMS
    - **Texte** : Comment devenir coursier Honam ?
    - **Texte** : Comment repérer une arnaque ?
  - **Carte** : Écrire au support | Réponse dans l’application | Signaler un problème

*Règles* : MSG-22 ; questions limitées aux modules ouverts dans le pays.

### REG-11 · À propos de Pokou

Maquette : `Reglages-11-A-propos` · « Réglages · 11. À propos »

*Rôle* : version, sens des noms et documents légaux.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : À propos de Pokou
- **Contenu**
  - **Image** : Pokou
  - **Texte** : Version [n°]
  - **Carte**
    - **Texte** : Le sens de nos noms
    - **Texte** : Pokou | un nom baoulé
    - **Texte** : Kory | le cauris
    - **Texte** : Honam | « aide-moi », en éwé
    - **Texte** : Assimé | « au marché », en éwé
    - **Texte** : Wétri | « mois », en éwé
    - **Texte** : ÉPÉ | « année », en éwé
  - **Carte**
    - **Ligne** : Conditions d’utilisation → REG-12
    - **Ligne** : Politique de confidentialité → REG-13
    - **Texte** : Licences des logiciels libres

*Règles* : au lot 1, seul le nom Pokou est expliqué (section 6.3).

### REG-12 · Conditions d’utilisation

Maquette : `Reglages-12-Conditions` · « Réglages · 12. Conditions d’utilisation »

*Rôle* : lire les conditions dans l’application.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → INS-1
  - **Titre** : Conditions d’utilisation
  - **Texte** : Mise à jour : [date]
- **Contenu**
  - **Titre de section** : L’essentiel
  - **Carte**
    - **Texte** : Pokou ne touche jamais l’argent : cagnottes, pharmacies et coursiers se paient de wallet à wallet.
    - **Texte** : Le mode preuve garde la trace des messages supprimés, et c’est toujours affiché.
    - **Texte** : Honam n’est pas un service d’urgence.
    - **Texte** : Les badges payants se résilient à tout moment.
  - **Titre de section** : Texte complet
  - **Carte**
    - **Texte** : 1. Ton compte
    - **Texte** : 2. Discussions et appels
    - **Texte** : 3. Kory
    - **Texte** : 4. Honam
    - **Texte** : 5. Assimé
    - **Texte** : 6. Badges payants
  - **Texte** : [Texte juridique à fournir et à faire valider par un juriste]
- **Pied d’écran**
  - **Bouton secondaire** : Télécharger en PDF

*Règles* : AUTH-09 ; texte juridique à fournir et à faire valider (section 14.2) ; ouvert depuis INS-1 et REG-11.

### REG-13 · Politique de confidentialité

Maquette : `Reglages-13-Confidentialite-texte` · « Réglages · 13. Politique de confidentialité »

*Rôle* : lire la politique de confidentialité dans l’application.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → INS-1
  - **Titre** : Confidentialité
  - **Texte** : Mise à jour : [date]
- **Contenu**
  - **Titre de section** : L’essentiel
  - **Carte**
    - **Texte** : Ton numéro n’est jamais montré à un vendeur ni à un coursier.
    - **Texte** : Pokou ne lit pas tes messages. Un signalement n’envoie que les 5 derniers au support.
    - **Texte** : La position du coursier n’est pas conservée après la livraison.
    - **Texte** : Les annonces sponsorisées sont ciblées par ville, jamais à partir de tes messages.
  - **Titre de section** : Texte complet
  - **Carte**
    - **Texte** : 1. Données collectées
    - **Texte** : 2. Utilisation
    - **Texte** : 3. Durées de conservation
    - **Texte** : 4. Tes droits
    - **Texte** : 5. Contact
  - **Texte** : [Texte juridique à fournir et à faire valider par un juriste]
- **Pied d’écran**
  - **Bouton secondaire** : Télécharger en PDF

*Règles* : section 14 ; aucune formule absolue (section 14.3, « Mentions à corriger »).

## 10.3 Écrans de Kory

### KOR-1 · Cagnotte

Maquette : `Kory-1-Cagnotte` · « Kory · 1. Cagnotte »

*Rôle* : suivre une cagnotte.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → DIS-1
  - **Titre** : Anniversaire de Papa
  - **Texte** : Cagnotte · Famille Koffi
  - **Bouton icône** : Partager le lien de la cagnotte
- **Contenu**
  - **Encadré ambre**
    - **Texte** : Total confirmé
    - **Texte** : 75 000 FCFA
    - **Texte** : sur un objectif de 100 000 FCFA · clôture le 2 nov.
    - **Indicateur** : [barre 75%]
  - **Texte** : Total déclaré | 85 000 FCFA | dont 10 000 à confirmer | Reste à collecter | 25 000 FCFA
  - **Texte** : Collecteur : Edem K. · Flooz •• 12 · vérifié par code
  - **Ligne** : Mon engagement · 18 000 FCFA | Ferme · reste 8 000 FCFA à verser → KOR-14
  - **Grille de 2**
    - **Bouton principal** : Contribuer → KOR-2
    - **Bouton secondaire** : Journal → KOR-9
  - **Titre de section** : 8 contributions
  - **Carte**
    - **Texte** : [avatar AK] | Toi | 10 000 FCFA | Confirmée
    - **Texte** : [avatar KK] | Kafui K. | il y a 2 h | 10 000 FCFA | Déclarée
    - **Texte** : [avatar SK] | Séna K. | 5 000 FCFA | Contestée
    - **Texte** : [avatar MA] | Maman | 20 000 FCFA | Confirmée

*Règles* : KORY-01, KORY-03 et KORY-09.

### KOR-2 · Contribuer

Maquette : `Kory-2-Contribuer` · « Kory · 2. Contribuer »

*Rôle* : envoyer sa contribution au collecteur, hors de Pokou.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : Contribuer
  - **Texte** : Anniversaire de Papa
- **Contenu**
  - **Champ** : Montant = 10 000 | FCFA
  - **Puces** : 5 000 | 10 000 (sélectionnée) | 20 000
  - **Carte**
    - **Texte** : Envoie à
    - **Texte** : [avatar EK] | Edem K. | Flooz · 96 •• •• 12
    - **Rangée**
      - **Texte** : Référence à indiquer KRY-4F7Q
      - **Bouton icône** : Copier la référence
  - **Encadré ambre** : Pokou ne transfère pas l’argent. Vérifie le nom du destinataire affiché par ton opérateur avant de valider. Les frais de ton opérateur s’appliquent.
  - **Carte**
    - **Texte** : Ouvrir l’application Flooz
    - **Texte** : Composer le code USSD | prérempli
    - **Texte** : Copier le numéro
- **Pied d’écran**
  - **Bouton principal** : J’ai envoyé → KOR-3

*Règles* : section 10.2 ; KORY-08 pour les liens et les codes USSD.

### KOR-3 · J’ai envoyé

Maquette : `Kory-3-Declarer` · « Kory · 3. J’ai envoyé »

*Rôle* : déclarer sa contribution.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-2
  - **Titre** : J’ai envoyé
  - **Texte** : 10 000 FCFA à Edem K. · Flooz
- **Contenu**
  - **Champ** : Référence de transaction = TG2610311611C3
  - **Texte** : Elle figure dans le SMS de confirmation de ton opérateur.
  - **Bouton secondaire** : Ajouter une capture du SMS
  - **Carte** : Envoyé | Aujourd’hui, 16:11 | Statut après déclaration | Déclarée
  - **Carte** : Ta contribution reste « Déclarée » jusqu’à ce qu’Edem confirme l’avoir reçue. Tu es prévenu dès qu’il confirme ou conteste.
- **Pied d’écran**
  - **Bouton principal** : Déclarer ma contribution → KOR-1

*Règles* : section 10.2 ; notification à la confirmation ou à la contestation.

### KOR-4 · Confirmer les réceptions

Maquette : `Kory-4-Confirmer` · « Kory · 4. Confirmer les réceptions »

*Rôle* : pour le collecteur, confirmer ce qu’il a reçu.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : À confirmer · 2
  - **Texte** : Anniversaire de Papa · vue de l’organisateur
- **Contenu**
  - **Carte** : Vérifie dans ton application Flooz ou dans le SMS de l’opérateur. Chaque réponse est horodatée dans le journal.
  - **Carte**
    - **Texte** : [avatar KK] | Kafui K. | Flooz · réf. TG2610311402A7 · 14:02 | 10 000 FCFA
    - **Grille de 2**
      - **Bouton principal** : Reçu
      - **Bouton secondaire** : Pas reçu
  - **Carte**
    - **Texte** : [avatar YK] | Yawa K. | Mixx by Yas · 13:47 | 5 000 FCFA
    - **Texte** : Capture du SMS jointe
    - **Grille de 2**
      - **Bouton principal** : Reçu
      - **Bouton secondaire** : Pas reçu
  - **Texte** : « Pas reçu » demande un motif ; la contribution passe en « Contestée » et la personne est prévenue.

*Règles* : KORY-02 ; chaque réponse est horodatée dans le journal.

### KOR-5 · Contribution contestée

Maquette : `Kory-5-Contestee` · « Kory · 5. Contribution contestée »

*Rôle* : aider le contributeur quand le collecteur ne constate pas l’envoi.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : Contribution contestée
  - **Texte** : Anniversaire de Papa
- **Contenu**
  - **Encadré rouge**
    - **Texte** : Edem n’a pas constaté ton envoi
    - **Texte** : 5 000 FCFA déclarés à 13:20 · Flooz · réf. TG2610311320B2
    - **Texte** : Motif : « Rien reçu sur Flooz •• 12 à cette heure-là. »
  - **Carte**
    - **Texte** : Vérifier la référence
    - **Texte** : Ajouter une capture du SMS
    - **Ligne** : Écrire à Edem → DIS-1
  - **Encadré ambre** : Si tu as envoyé sur un autre numéro, seul ton opérateur peut récupérer l’argent : il ne passe jamais par Pokou.

*Règles* : section 10.2 ; la contribution n’entre dans aucun total tant qu’elle est contestée.

### KOR-6 · Nouvelle collecte

Maquette : `Kory-6-Creer` · « Kory · 6. Nouvelle collecte »

*Rôle* : créer une cagnotte, une cotisation ou une tontine Kory Plus.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-3
  - **Titre** : Nouvelle collecte
- **Contenu**
  - **Texte** : Cagnotte
  - **Carte** : Cotisation
  - **Carte** : Tontine Plus
  - **Champ** : Titre = Mariage d’Akossiwa
  - **Champ** : Bénéficiaire = Akossiwa K.
  - **Grille de 2**
    - **Champ** : Objectif (facultatif) = 300 000
    - **Champ** : Clôture = 15 déc. 2026
  - **Carte**
    - **Texte** : Collecteur | Toi · Mixx by Yas •• 47 | vérifié
    - **Texte** : Montants individuels | Visibles de tous
    - **Texte** : Discussion liée | Famille Koffi
  - **Carte** : Sans frais. Pokou ne touche pas l’argent : chacun verse depuis son wallet au collecteur.
- **Pied d’écran**
  - **Bouton principal** : Créer la cagnotte → KOR-1

*Règles* : section 10.1 ; KORY-03 et KORY-06.

### KOR-7 · Tontine

Maquette : `Kory-7-Tontine` · « Kory · 7. Tontine »

*Rôle* : suivre une tontine en rotation.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-3
  - **Titre** : Tontine des collègues
  - **Texte** : Kory Plus · Collègues du bureau
- **Contenu**
  - **Encadré ambre**
    - **Texte** : Tour 4 sur 10 · octobre
    - **Texte** : Bénéficiaire : Yao A.
    - **Texte** : 10 000 FCFA par membre · échéance aujourd’hui
    - **Indicateur** : [barre 60%]
    - **Texte** : 6 confirmées · 2 déclarées · 2 en retard
  - **Grille de 2**
    - **Bouton principal** : Contribuer → KOR-2
    - **Bouton secondaire** : Rapport (PDF)
  - **Titre de section** : Ce tour
  - **Carte**
    - **Texte** : [avatar AK] | Toi | 10 000 FCFA | Confirmée
    - **Texte** : [avatar MD] | Mensah D. | 10 000 FCFA | Déclarée
    - **Texte** : [avatar KT] | Komi T. | relancé ce matin | 10 000 FCFA | En retard
  - **Titre de section** : Prochains tours
  - **Carte**
    - **Texte** : Novembre | Komi T.
    - **Texte** : Décembre | Toi
    - **Texte** : Janvier | Abla G.
  - **Texte** : Ordre tiré au sort le 4 juillet, journalisé. Suppléant de l’administrateur : Yao A.

*Règles* : KORY-02, KORY-04, KORY-05, KORY-11 et KORY-12.

### KOR-8 · Ouvrir une tontine

Maquette : `Kory-8-Ouvrir-tontine` · « Kory · 8. Ouvrir une tontine »

*Rôle* : réunir les frais Kory Plus avant le démarrage.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-6
  - **Titre** : Nouvelle tontine
  - **Texte** : Kory Plus · Voisins de Bè · étape 3 sur 3
- **Contenu**
  - **Carte**
    - **Texte** : Cotisation | 5 000 FCFA par mois
    - **Texte** : Membres et tours | 8 · de décembre à juillet
    - **Texte** : Ordre des tours | Tirage au sort journalisé
  - **Encadré ambre**
    - **Texte** : Frais d’ouverture Kory Plus
    - **Texte** : 1 000 FCFA HT (1 180 FCFA TTC) par membre, une fois, par CashPay.
    - **Indicateur** : [barre 62%]
    - **Texte** : 5 membres sur 8 ont payé
  - **Carte**
    - **Texte** : [avatar AK] | Toi | 1 180 FCFA | Payé
    - **Texte** : [avatar AS] | Ama S. | 1 180 FCFA | Payé
    - **Texte** : [avatar YA] | Yao A. | 1 180 FCFA | En attente
  - **Carte** : La tontine démarre quand tous ont payé, au plus tard le 7 nov. Sinon, les sommes payées deviennent un avoir. Frais non remboursables une fois la tontine ouverte.
- **Pied d’écran**
  - **Bouton principal** : Payer pour les 3 restants · 3 540 FCFA TTC
  - **Ligne** : Relancer les 3 membres

*Règles* : KORY-10 ; paiement par CashPay.

### KOR-9 · Journal des contributions

Maquette : `Kory-9-Journal` · « Kory · 9. Journal des contributions »

*Rôle* : garder la trace de chaque action.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : Journal des contributions
  - **Texte** : Anniversaire de Papa
- **Contenu**
  - **Puces** : Tout (sélectionnée) | Confirmées | Contestées
  - **Liste**
    - **Élément** : Edem a confirmé 10 000 FCFA de Toi | 31 oct. · 14:05
    - **Élément** : Kafui K. a déclaré 10 000 FCFA · réf. TG2610311402A7 | 31 oct. · 14:02
    - **Élément** : Edem a contesté 5 000 FCFA de Séna K. : « Rien reçu » | 31 oct. · 13:40
    - **Élément** : Edem a confirmé 20 000 FCFA de Maman | 30 oct. · 18:10
    - **Élément** : Edem a créé la cagnotte · collecteur vérifié par code | 28 oct. · 09:00
  - **Carte** : Chaque action est horodatée et ne peut pas être effacée, même par l’organisateur.
- **Pied d’écran**
  - **Bouton secondaire** : Exporter en CSV
  - **Bouton principal** : Exporter en PDF

*Règles* : KORY-01 et KORY-07 ; journal en écriture seule (AuditEvent).

### KOR-10 · Rejoindre une cagnotte

Maquette : `Kory-10-Rejoindre` · « Kory · 10. Rejoindre une cagnotte »

*Rôle* : décider de rejoindre une cagnotte reçue par lien.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-3
  - **Titre** : Invitation
  - **Texte** : Lien reçu de Ama S.
- **Contenu**
  - **Carte**
    - **Texte** : Mariage d’Akossiwa | Cagnotte · Les Amis de Bè
    - **Texte** : Bénéficiaire | Akossiwa K.
    - **Texte** : Objectif | 300 000 FCFA
    - **Texte** : Clôture | 15 déc. 2026
    - **Texte** : Participants | 12, dont toi
    - **Texte** : Montants | Visibles de tous
  - **Carte** : Collecteur | [avatar AS] | Ama S. | Flooz · 96 •• •• 21 · vérifié par code
  - **Carte** : Pokou ne touche pas l’argent. Tu t’engages sur un montant, puis tu verses depuis ton wallet au collecteur et tu déclares ton versement.
  - **Encadré beige** : En rejoignant, tu entres aussi dans la discussion « Les Amis de Bè ».
- **Pied d’écran**
  - **Bouton principal** : Rejoindre et m’engager → KOR-12
  - **Ligne** : Pas maintenant → APP-3

*Règles* : KORY-03, KORY-06, KORY-09 et KORY-15 ; BM-01.

### KOR-11 · Participants

Maquette : `Kory-11-Participants` · « Kory · 11. Ajouter des participants »

*Rôle* : ajouter les participants à la création d’une cagnotte (étape 2 sur 3).

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-6
  - **Titre** : Participants
  - **Texte** : Mariage d’Akossiwa · étape 2 sur 3
- **Contenu**
  - **Carte**
    - **Grille de 2**
      - **Champ** : Nom = Mensah
      - **Champ** : Prénom = Yawa
    - **Champ** : Numéro = +228 91 00 00 07
    - **Bouton secondaire** : Ajouter
  - **Rangée**
    - **Titre de section** : Ajoutés · 4
    - **Lien** : Depuis mes contacts → DIS-5
  - **Liste**
    - **Élément**
      - **Avatar** : AS
      - **Texte** : Ama S.
      - **Texte** : Sur Pokou
      - **Puce** : Collectrice
      - **Bouton icône** : Retirer Ama S.
    - **Élément**
      - **Avatar** : EK
      - **Texte** : Edem K.
      - **Texte** : Sur Pokou
      - **Bouton icône** : Retirer Edem K.
    - **Élément**
      - **Avatar** : YM
      - **Texte** : Mensah Yawa
      - **Texte** : +228 91 •• •• 07
      - **Puce** : Invitée
      - **Bouton icône** : Retirer Mensah Yawa
    - **Élément**
      - **Avatar** : KT
      - **Texte** : Tetteh Komi
      - **Texte** : +228 99 •• •• 52
      - **Puce** : Invité
      - **Bouton icône** : Retirer Tetteh Komi
  - **Texte** : Sans Pokou, la personne reçoit un SMS d’invitation. Elle reste « Invitée » jusqu’à son inscription, puis s’engage comme les autres.
- **Pied d’écran**
  - **Bouton principal** : Continuer avec 4 participants → KOR-1

*Règles* : KORY-15 ; numéros masqués dans la liste dès l’ajout.

### KOR-12 · Je m’engage

Maquette : `Kory-12-Engagement` · « Kory · 12. Je m’engage »

*Rôle* : promettre un montant avant de verser.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : Je m’engage
  - **Texte** : Anniversaire de Papa · clôture le 2 nov.
- **Contenu**
  - **Champ** : Montant de départ = 15 000 | FCFA
  - **Puces** : 5 000 | 10 000 | 15 000 (sélectionnée) | 20 000
  - **Carte**
    - **Interrupteur** : Ajouter un montant journalier | Ajouté chaque jour à ton engagement, jusqu’à la clôture | [interrupteur activé]
  - **Champ** : Montant par jour = 500 | FCFA
  - **Carte**
    - **Texte** : Départ | 15 000 FCFA
    - **Texte** : 500 FCFA × 6 jours | 3 000 FCFA
    - **Texte** : Total engagé au 2 nov. | 18 000 FCFA
  - **Encadré ambre** : Tu peux modifier ton engagement pendant 8 h. Ensuite il devient ferme : il s’inscrit au journal et le collecteur le voit.
- **Pied d’écran**
  - **Bouton principal** : Confirmer mon engagement → KOR-13

*Règles* : KORY-13 ; le total se recalcule à chaque saisie.

### KOR-13 · Engagement modifiable

Maquette : `Kory-13-Engagement-modifiable` · « Kory · 13. Engagement modifiable 8 h »

*Rôle* : laisser 8 h pour corriger son engagement.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : Mon engagement
  - **Texte** : Anniversaire de Papa
- **Contenu**
  - **Carte**
    - **Texte** : Mon engagement | Modifiable encore 7 h 42
    - **Texte** : 18 000 FCFA
    - **Indicateur** : [barre 4%]
    - **Texte** : Devient ferme aujourd’hui à 21 h 18
    - **Texte** : Départ | 15 000 FCFA
    - **Texte** : Montant journalier | 500 FCFA par jour
  - **Bouton secondaire** : Modifier mon engagement → KOR-12
  - **Carte** : Engagement enregistré | Aujourd’hui, 13:18 | Modifiable pendant 8 h | Jusqu’à 21:18 · le collecteur ne le voit pas encore | 3 | Engagement ferme | Inscrit au journal, visible du collecteur
  - **Carte** : Tu peux verser dès maintenant, ou attendre la clôture : Pokou te rappellera ce qu’il reste à verser.
- **Pied d’écran**
  - **Bouton principal** : Verser maintenant → KOR-2

*Règles* : KORY-13 ; le délai est compté par le serveur, pas par l’horloge du téléphone.

### KOR-14 · Engagement ferme

Maquette : `Kory-14-Engagement-ferme` · « Kory · 14. Engagement ferme »

*Rôle* : suivre ce qu’on a promis et ce qu’il reste à verser.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : Mon engagement
  - **Texte** : Anniversaire de Papa
- **Contenu**
  - **Carte**
    - **Texte** : Mon engagement | Ferme depuis le 27 oct.
    - **Texte** : 18 000 FCFA
    - **Texte** : Départ | 15 000 FCFA
    - **Texte** : Montant journalier | 500 FCFA par jour
  - **Carte**
    - **Texte** : Versé et confirmé | 10 000 FCFA
    - **Indicateur** : [barre 56%]
    - **Texte** : Reste à verser | 8 000 FCFA
    - **Texte** : Prochain ajout journalier : demain, +500 FCFA
  - **Encadré beige** : Un engagement ferme ne se modifie plus. En cas d’imprévu, écris au collecteur : lui seul peut l’annuler, et c’est noté au journal.
- **Pied d’écran**
  - **Bouton principal** : Verser 8 000 FCFA → KOR-2
  - **Ligne** : Écrire à Edem → DIS-1

*Règles* : KORY-01 et KORY-13 ; reste à verser = engagé − confirmé.

### KOR-15 · Fin de la collecte

Maquette : `Kory-15-Cloturer-prolonger` · « Kory · 15. Clôturer ou prolonger »

*Rôle* : pour le collecteur, clôturer ou prolonger à la date de fin.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : Fin de la collecte
  - **Texte** : Anniversaire de Papa · vue du collecteur
- **Contenu**
  - **Encadré ambre** : La date de fin est atteinte : à toi de clôturer ou de prolonger.
  - **Carte** : Engagé | 104 000 FCFA | 8 participants | Confirmé | 75 000 FCFA | sur 100 000 | À confirmer | 10 000 FCFA | 1 déclaration | Reste à verser | 19 000 FCFA | 4 participants
  - **Texte** : Que fais-tu ?
  - **Choix** : ◉ | Clôturer la collecte | Chacun reçoit ce qu’il lui reste à verser, et le lien vers son wallet
  - **Choix** : ○ | Prolonger | Nouvelle date de fin : 9 nov. · les engagements restent fermes
  - **Texte** : Les participants sont prévenus dans la discussion Famille Koffi. Le journal garde la date et ton choix.
- **Pied d’écran**
  - **Bouton principal** : Clôturer et prévenir les 8 participants → KOR-16

*Règles* : KORY-02 et KORY-14.

### KOR-16 · Collecte clôturée

Maquette : `Kory-16-Cloture-verser` · « Kory · 16. Clôture : verser le reste »

*Rôle* : pour le participant, verser la fin de son engagement.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → KOR-1
  - **Titre** : Collecte clôturée
  - **Texte** : Anniversaire de Papa · vue du participant
- **Contenu**
  - **Texte** : Edem K. a clôturé la collecte le 2 nov. Il te reste à verser la fin de ton engagement.
  - **Carte**
    - **Texte** : Engagé | 18 000 FCFA
    - **Texte** : Déjà confirmé | 10 000 FCFA
    - **Texte** : À verser | 8 000 FCFA
  - **Carte**
    - **Texte** : Envoie à
    - **Texte** : [avatar EK] | Edem K. | Flooz · 96 •• •• 12
    - **Rangée**
      - **Texte** : Référence à indiquer KRY-4F7Q
      - **Bouton icône** : Copier la référence
- **Pied d’écran**
  - **Bouton principal** : Verser 8 000 FCFA depuis mon wallet → KOR-2
  - **Ligne** : J’ai déjà envoyé → KOR-3

*Règles* : KORY-14 ; Pokou ne transfère rien (BM-01).

## 11.1 Parcours de commande

*Écrans du patient*

### PAT-1 · Envoyer une ordonnance

Maquette : `Honam-P1-Envoyer` · « Honam patient · 1. Envoyer l’ordonnance »

*Rôle* : photographier l’ordonnance et choisir la pharmacie.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-4
  - **Titre** : Envoyer une ordonnance
- **Contenu**
  - **Carte**
    - **Rangée**
      - **Illustration** : Photo de l’ordonnance
      - **Puce** : Photo nette
      - **Texte** : Toute la page est visible, nom du médecin compris.
      - **Bouton secondaire** : Reprendre
  - **Titre de section** : Pharmacie
  - **Choix** : ◉ | Pharmacie Démo | Ouverte · Tokoin · 1,2 km
  - **Choix** : ○ | Pharmacie du Marché | De garde cette nuit · Bè · 2,4 km
  - **Carte** : Livrer à Bè-Kpota, rue des Cocotiers | Repère : portail bleu face au kiosque
  - **Champ** : Message à la pharmacie = À livrer avant 13 h, merci
  - **Encadré vert** : Seule la pharmacie choisie voit ta photo. Le coursier ne voit ni l’ordonnance ni les produits.
- **Pied d’écran**
  - **Bouton principal** : Envoyer à Pharmacie Démo → PAT-2

*Règles* : HON-02, HON-06 et HON-51 ; liste au format annuaire, triée par distance (BM-12).

### PAT-2 · En attente du devis

Maquette : `Honam-P2-Attente-devis` · « Honam patient · 2. En attente du devis »

*Rôle* : rassurer pendant que l’officine prépare le devis.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-4
  - **Titre** : Ma commande
  - **Texte** : Pharmacie Démo · envoyée à 9 h 42
- **Contenu**
  - **Étapes**
    - **Élément** : [barre] | Envoyée (fait)
    - **Élément** : [barre] | Devis (en cours)
    - **Élément** : [barre] | Payée (à venir)
    - **Élément** : [barre] | En route (à venir)
    - **Élément** : [barre] | Livrée (à venir)
  - **Texte** : Pharmacie Démo lit ton ordonnance et prépare le devis. Tu reçois une notification dès qu’il arrive.
  - **Carte** : [icône : Ordonnance envoyée] | Ordonnance envoyée | « À livrer avant 13 h, merci »
  - **Carte**
    - **Ligne** : Écrire à la pharmacie → APP-2
    - **Texte** : Livrer à Bè-Kpota | Repère : portail bleu
  - **Encadré beige** : Honam n’est pas un service d’urgence. En cas d’urgence, appelle les secours.
- **Pied d’écran**
  - **Ligne** : Annuler la commande

*Règles* : HON-10 ; annulation libre avant le paiement (section 11.1).

### PAT-3 · Devis

Maquette : `Honam-P3-Devis` · « Honam patient · 3. Devis reçu »

*Rôle* : voir le devis et décider.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-4
  - **Titre** : Devis de Pharmacie Démo
  - **Texte** : Reçu à 9 h 46 · valable jusqu’à demain 9 h 46
- **Contenu**
  - **Étapes**
    - **Élément** : [barre] | Envoyée (fait)
    - **Élément** : [barre] | Devis (en cours)
    - **Élément** : [barre] | Payée (à venir)
    - **Élément** : [barre] | En route (à venir)
    - **Élément** : [barre] | Livrée (à venir)
  - **Liste**
    - **Élément** : Amoxicilline 500 mg | 12 gélules | 1 800 FCFA
    - **Élément** : Paracétamol 1 g | 8 comprimés | 600 FCFA
    - **Élément** : Sirop antitussif | Flacon 125 ml | Générique | 2 200 FCFA
  - **Carte**
    - **Texte** : Médicaments | 4 600 FCFA
    - **Texte** : Course, ajoutée par Honam | 1 000 FCFA
    - **Texte** : Total à payer | 5 600 FCFA
  - **Carte** : Tu paies la pharmacie directement depuis ton wallet. Pokou ne touche pas l’argent et ne prend rien sur les médicaments.
  - **Encadré beige** : Un générique t’est proposé pour le sirop. Une question ? Écris à la pharmacie avant de payer.
- **Pied d’écran**
  - **Bouton principal** : Payer 5 600 FCFA → PAT-4
  - **Ligne** : Refuser le devis

*Règles* : HON-51 et BM-01 ; prix de la course selon le pays (section 4).

### PAT-4 · Payer la pharmacie

Maquette : `Honam-P4-Payer` · « Honam patient · 4. Payer la pharmacie »

*Rôle* : payer de wallet à wallet, hors de Pokou.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → PAT-3
  - **Titre** : Payer la pharmacie
  - **Texte** : Commande de Pharmacie Démo
- **Contenu**
  - **Carte**
    - **Texte** : Montant à envoyer
    - **Texte** : 5 600 FCFA
    - **Texte** : À Pharmacie Démo · Flooz 96 •• •• 12
  - **Carte**
    - **Texte** : Ouvrir l’application Flooz
    - **Texte** : Composer le code USSD | prérempli
    - **Texte** : Copier le numéro
  - **Champ** : Référence de la transaction = 7KX4-2190 | Dans le SMS de confirmation de Flooz
  - **Encadré ambre** : Vérifie que ton opérateur affiche bien « Pharmacie Démo » avant de valider. Les frais de ton opérateur s’appliquent.
- **Pied d’écran**
  - **Bouton principal** : J’ai payé → PAT-5

*Règles* : HON-51 ; liens et codes USSD en configuration distante, comme pour Kory (KORY-08).

### PAT-5 · Paiement signalé

Maquette : `Honam-P5-Paiement-signale` · « Honam patient · 5. Paiement signalé »

*Rôle* : attendre la vérification du paiement par l’officine.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-4
  - **Titre** : Ma commande
  - **Texte** : Pharmacie Démo
- **Contenu**
  - **Étapes**
    - **Élément** : [barre] | Envoyée (fait)
    - **Élément** : [barre] | Devis (fait)
    - **Élément** : [barre] | Payée (en cours)
    - **Élément** : [barre] | En route (à venir)
    - **Élément** : [barre] | Livrée (à venir)
  - **Carte** : Paiement signalé | Aujourd’hui, 9:58 · réf. 7KX4-2190 | La pharmacie vérifie la réception | Sur son application Flooz | 3 | Préparation, puis départ du coursier | Tu suis la livraison et reçois ton code
  - **Encadré vert** : Ton code de remise s’affiche quand le coursier est en route. Ne le donne qu’à lui, au moment où il te remet le colis.
  - **Carte**
    - **Ligne** : Écrire à la pharmacie → APP-2
- **Pied d’écran**
  - **Bouton principal** : Suivre ma commande → SUI-1

*Règles* : HON-01 ; paiement non reçu : section 11.7.

### PAT-6 · Un produit manque

Maquette : `Honam-P6-Produit-manquant` · « Honam patient · 6. Produit manquant »

*Rôle* : laisser le patient choisir quand un produit manque après le paiement.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-4
  - **Titre** : Un produit manque
  - **Texte** : Pharmacie Démo · commande payée
- **Contenu**
  - **Texte** : Pharmacie Démo n’a plus de sirop antitussif. Que préfères-tu ?
  - **Choix** : ◉ | Recevoir le reste | Amoxicilline et paracétamol livrés. La pharmacie te rembourse 2 200 FCFA.
  - **Choix** : ○ | Tout annuler | Rien n’est livré. La pharmacie te rembourse 5 600 FCFA.
  - **Carte** : Le remboursement arrive sous 2 h, uniquement sur le numéro qui a payé : Flooz 96 •• •• 58.
  - **Texte** : Sans réponse de ta part sous 15 minutes, tout est annulé et remboursé.
- **Pied d’écran**
  - **Bouton principal** : Valider mon choix → PAT-5

*Règles* : HON-33 à HON-35 ; miroir de OFF-A1.

### PAT-7 · Ordonnance refusée

Maquette : `Honam-P7-Refusee` · « Honam patient · 7. Ordonnance refusée »

*Rôle* : expliquer un refus et proposer une autre officine sans tout refaire.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-4
  - **Titre** : Ordonnance refusée
  - **Texte** : Pharmacie Démo · rien n’a été payé
- **Contenu**
  - **Carte**
    - **Texte** : Motif
    - **Texte** : Produits indisponibles
    - **Texte** : « Bonjour Afi, nous n’avons plus d’amoxicilline 500 mg aujourd’hui. Honam vous propose des officines proches qui peuvent vous servir. »
  - **Titre de section** : Envoyer à une autre pharmacie
  - **Choix** : ◉ | Pharmacie du Marché | De garde cette nuit · Bè · 2,4 km
  - **Choix** : ○ | Pharmacie Bè-Kpota | Ouverte · 0,9 km
  - **Texte** : La même photo est envoyée : tu n’as rien à refaire.
- **Pied d’écran**
  - **Bouton principal** : Envoyer à Pharmacie du Marché → PAT-2
  - **Ligne** : Plus tard → APP-4

*Règles* : HON-20 et HON-51 ; miroir de OFF-R2.

### PAT-8 · Mes commandes

Maquette : `Honam-P8-Mes-commandes` · « Honam patient · 8. Mes commandes »

*Rôle* : suivre la commande en cours et retrouver les anciennes.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-4
  - **Titre** : Mes commandes
- **Contenu**
  - **Titre de section** : En cours
  - **Vignette** : [image : honam-icone] | Pharmacie Démo | Aujourd’hui · Kodjo arrive dans 6 min | 5 600 FCFA | En route → SUI-1
  - **Titre de section** : Passées
  - **Carte** : [image : honam-icone] | Pharmacie du Marché | 21 oct. · 2 produits | 3 200 FCFA | Livrée
  - **Carte** : [image : honam-icone] | Pharmacie Démo | 9 oct. · annulée, produit manquant | 2 900 FCFA | Remboursée
  - **Carte** : [image : honam-icone] | Pharmacie Démo | 24 sept. · 4 produits | 7 400 FCFA | Livrée
  - **Texte** : Une question sur une commande passée ? La discussion avec la pharmacie reste dans tes Discussions.
- **Pied d’écran**
  - **Bouton principal** : Envoyer une ordonnance → PAT-1

*Règles* : NAV-04 et HON-51 ; jamais de nom de médicament dans la liste.

## 11.4 Écrans de l’espace officine

*Parcours principal*

### OFF-1 · Commandes

Maquette : `Officine-1-Commandes` · « Officine · 1. Commandes »

*Rôle* : accueil de l’espace officine : la file des commandes à traiter.

**Disposition et textes**

- **En-tête**
  - **Image** : honam-icone
  - **Texte** : Pharmacie Démo
  - **Texte** : Tokoin, Lomé
  - **Filtre (sélectionné)** : Ouverte
  - **Bouton icône** : Notifications
- **Contenu**
  - **Titre** : Commandes
  - **Encadré beige**
    - **Filtre (sélectionné)** : À traiter · 3
    - **Filtre** : En cours · 4
    - **Filtre** : Livrées · 9
  - **Liste**
    - **Carte**
      - **Texte** : Nouvelle ordonnance | il y a 2 min
      - **Texte** : Afi K. | Bè-Kpota · 2,1 km | « À livrer avant 13 h, merci »
      - **Bouton principal** : Établir le devis → OFF-2
    - **Carte**
      - **Texte** : Paiement à confirmer | il y a 9 min
      - **Texte** : Ama S. | 6 400 FCFA attendus sur votre Flooz | Nyékonakpoè · 1,6 km
      - **Bouton secondaire** : Vérifier le paiement → OFF-3
    - **Carte**
      - **Texte** : Prête à partir | il y a 14 min
      - **Texte** : Yao M. | Payée 3 200 FCFA à 9 h 31 | Adidogomé · 5,8 km
      - **Bouton secondaire** : Demander un coursier → OFF-8
- **Barre d’onglets** : Commandes (actif) / Historique / Abonnement / Compte

*Règles* : tri de la plus ancienne à la plus récente ; temps réel ; HON-12 pour l’alerte et l’interrupteur ; une commande en retard sur un délai (devis, remboursement, retour de l’original) remonte en tête avec un badge Recommandation.

### OFF-2 · Devis

Maquette : `Officine-2-Devis` · « Officine · 2. Devis »

*Rôle* : chiffrer l’ordonnance reçue.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Devis pour Afi K.
  - **Texte** : Bè-Kpota · 2,1 km · reçue à 9 h 42
- **Contenu**
  - **Carte**
    - **Titre de section** : Ordonnance d’Afi
    - **Texte** : « À livrer avant 13 h, merci »
    - **Bouton secondaire** : Agrandir
  - **Case à cocher** : ☐ | Ordonnance originale à récupérer
  - **Titre de section** : Produits
  - **Liste**
    - **Élément**
      - **Champ** : Amoxicilline 500 mg
      - **Texte** : 12 gélules | Disponible
      - **Rangée**
        - **Champ** : [champ : 1 800]
        - **Texte** : FCFA
    - **Élément**
      - **Champ** : Paracétamol 1 g
      - **Texte** : 8 comprimés | Disponible
      - **Rangée**
        - **Champ** : [champ : 600]
        - **Texte** : FCFA
    - **Élément**
      - **Champ** : Sirop antitussif
      - **Texte** : Flacon 125 ml | Générique
      - **Rangée**
        - **Champ** : [champ : 2 200]
        - **Texte** : FCFA
  - **Ligne** : Ajouter un produit
  - **Carte**
    - **Texte** : Médicaments | 4 600 FCFA
    - **Texte** : Course, ajoutée par Honam | 1 000 FCFA
    - **Texte** : Total à payer | 5 600 FCFA
- **Pied d’écran**
  - **Bouton principal** : Envoyer le devis à Afi → OFF-3
  - **Ligne** : Refuser l’ordonnance → OFF-R1

*Règles* : HON-13, HON-14, HON-15 ; un générique est signalé comme tel au patient ; les lignes ajoutées par l’officine sont libres (pas de catalogue imposé).

*Statut* : ENVOYÉE → DEVIS_ENVOYÉ.

### OFF-3 · Paiement

Maquette : `Officine-3-Paiement` · « Officine · 3. Paiement »

*Rôle* : vérifier le paiement signalé par le patient avant de préparer.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Paiement d’Afi K.
  - **Texte** : Devis envoyé à 9 h 46
- **Contenu**
  - **Étapes**
    - **Élément** : [barre] | Reçue (fait)
    - **Élément** : [barre] | Devis (fait)
    - **Élément** : [barre] | Payée (en cours)
    - **Élément** : [barre] | Prête (à venir)
    - **Élément** : [barre] | Livrée (à venir)
  - **Carte**
    - **Texte** : Montant attendu
    - **Texte** : 5 600 FCFA
    - **Texte** : Sur votre Flooz · 96 •• •• 12
  - **Carte** : Afi a signalé son paiement à 9 h 58 | Référence indiquée : 7KX4-2190
  - **Encadré beige** : Vérifiez la réception dans votre application Flooz ou dans le SMS de l’opérateur avant de valider. L’argent ne passe pas par Pokou.
  - **Carte** : Commande | Amoxicilline 500 mg | 1 800 FCFA | Paracétamol 1 g | 600 FCFA | Sirop antitussif | 2 200 FCFA | Course | 1 000 FCFA
- **Pied d’écran**
  - **Bouton principal** : Paiement reçu, je prépare → OFF-4
  - **Ligne** : Pas encore reçu → OFF-P1

*Règles* : HON-16 ; la confirmation est une déclaration de l’officine, horodatée et journalisée (SEC-04) ; le nom du wallet (Flooz, Mixx by Yas…) suit celui de l’officine.

*Statut* : PAIEMENT_DÉCLARÉ → PAIEMENT_CONFIRMÉ.

### OFF-8 · Demander un coursier

Maquette : `Officine-8-Demander-coursier` · « Officine · 8. Demander un coursier »

*Rôle* : suivre la recherche d’un coursier pour une commande prête.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Demander un coursier
  - **Texte** : Commande de Yao M. · Adidogomé · 5,8 km
- **Contenu**
  - **Carte** : Recherche en cours… | Depuis 1 min 10
  - **Carte** : Proposée à vos coursiers rattachés | Kodjo A. n’a pas répondu en 30 s | Proposée aux coursiers de la zone | 4 disponibles autour de Tokoin | 3 | Un coursier accepte | Vous voyez son nom et son heure d’arrivée
  - **Carte** : Course payée au coursier | 1 000 FCFA | Par | Votre officine, sur son wallet
  - **Encadré beige** : Le colis reste fermé, au nom de Yao M. Le coursier ne voit ni l’ordonnance ni les produits.
- **Pied d’écran**
  - **Ligne** : Annuler la demande

*Règles* : HON-02, HON-42, HON-45 et HON-47.

*Statut* : PRÊTE → COURSIER_ASSIGNÉ.

### OFF-9 · Aucun coursier disponible

Maquette : `Officine-9-Aucun-coursier` · « Officine · 9. Aucun coursier disponible »

*Rôle* : proposer une issue quand personne n’accepte la course.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Aucun coursier disponible
  - **Texte** : Commande de Yao M. · Adidogomé
- **Contenu**
  - **Texte** : Aucun coursier n’a accepté la course depuis 10 minutes.
  - **Bouton secondaire** : Relancer la recherche → OFF-8
  - **Bouton secondaire** : Élargir la zone à 8 km
  - **Carte**
    - **Texte** : Proposer le retrait à l’officine
    - **Texte** : Yao M. est prévenu. S’il accepte, vous lui remboursez la course de 1 000 FCFA.
    - **Bouton secondaire** : Proposer le retrait
  - **Ligne** : Inviter vos livreurs habituels → OFF-6
- **Pied d’écran**
  - **Bouton principal** : Retour aux commandes → OFF-1

*Règles* : HON-47 ; rayon élargi Recommandation.

### OFF-4 · Livraison

Maquette : `Officine-4-Livraison` · « Officine · 4. Livraison »

*Rôle* : remettre le colis au coursier qui a accepté la course.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Livraison d’Afi K.
  - **Texte** : Payée 5 600 FCFA à 9 h 58
- **Contenu**
  - **Étapes**
    - **Élément** : [barre] | Reçue (fait)
    - **Élément** : [barre] | Devis (fait)
    - **Élément** : [barre] | Payée (fait)
    - **Élément** : [barre] | Prête (fait)
    - **Élément** : [barre] | Livrée (en cours)
  - **Carte**
    - **Texte** : [Photo vérifiée de Kodjo A.] | Kodjo A. | Coursier vérifié · photo de son selfie
    - **Texte** : A accepté la course à 10 h 02. Arrivée dans 6 min environ.
    - **Grille de 2**
      - **Bouton secondaire** : Appeler
      - **Bouton secondaire** : Écrire → OFF-10
  - **Carte**
    - **Titre de section** : Remise du colis
    - **Case à cocher** : ☑ | Sachet fermé, au nom d’Afi K.
    - **Case à cocher** : ☑ | Posologie notée sur chaque boîte
    - **Case à cocher** : ☑ | La personne au comptoir est celle de la photo
  - **Carte**
    - **Titre de section** : Après la livraison
    - **Texte** : Afi donne son code à Kodjo, qui le saisit dans Honam : la commande se clôt.
    - **Texte** : Course à payer à Kodjo | 1 000 FCFA
    - **Texte** : Sur son Flooz ou son Mixx by Yas
    - **Bouton désactivé** : Course payée
- **Pied d’écran**
  - **Bouton principal** : Colis remis à Kodjo → OFF-4b

*Règles* : HON-02 (aucune donnée de santé côté coursier) et HON-57 ; bouton principal actif seulement quand les trois cases de remise sont cochées Recommandation.

*Statut* : COURSIER_ASSIGNÉ → EN_LIVRAISON.

### OFF-10 · Écrire au coursier

Maquette : `Officine-10-Ecrire-coursier` · « Officine · 10. Écrire au coursier »

*Rôle* : échanger avec le coursier pendant la course.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour à la livraison → OFF-4
  - **Avatar** : KA
  - **Titre** : Kodjo A.
  - **Texte** : Coursier vérifié · course d’Afi K.
  - **Bouton icône** : Appeler Kodjo, numéro masqué
- **Contenu**
  - **Message système** : Discussion liée à la course d’Afi K. Elle se ferme 24 h après la livraison. Les numéros restent masqués.
  - **Repère** : Aujourd’hui
  - **Bulle envoyée** : Bonjour Kodjo, le colis d’Afi est prêt au comptoir. Demandez Mme Abalo. | 10:03 · Lu
  - **Bulle reçue** : Bien reçu, j’arrive dans 5 minutes. | 10:04
  - **Bulle envoyée** : Merci. Pensez à rapporter l’original de l’ordonnance à votre prochain passage. | 10:20 · Lu
  - **Bulle reçue** : D’accord, c’est noté. | 10:21
- **Rangée**
  - **Puce** : Le colis est prêt
  - **Puce** : Où êtes-vous ?
  - **Puce** : Merci
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire à Kodjo… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer

*Règles* : HON-48 ; vouvoiement côté officine ; aucune donnée de santé (HON-02).

### OFF-4b · Livrée, course à payer

Maquette : `Officine-4b-Livree` · « Officine · 4b. Livrée, course à payer »

*Rôle* : après la saisie du code, régler la course au coursier.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Livrée à Afi K.
  - **Texte** : Code saisi par Kodjo à 10 h 31
- **Contenu**
  - **Carte**
    - **Texte** : Course à payer à Kodjo | À régler
    - **Texte** : 1 000 FCFA
    - **Texte** : Payer Kodjo sur
    - **Choix** : ◉ | Flooz · 96 •• •• 03 | Même réseau que votre wallet
    - **Choix** : ○ | Mixx by Yas · 90 •• •• 47
    - **Grille de 2**
      - **Bouton secondaire** : Ouvrir Flooz
      - **Bouton secondaire** : Copier le numéro
    - **Texte** : Pokou ne prélève rien sur ce paiement.
  - **Carte**
    - **Texte** : Encaissé auprès d’Afi | 5 600 FCFA
    - **Texte** : Course reversée à Kodjo | −1 000 FCFA
    - **Texte** : Reste pour l’officine | 4 600 FCFA
  - **Carte**
    - **Texte** : Ordonnance originale | Récupérée et photographiée par Kodjo à 10 h 31 | Retour à son prochain passage, au plus tard le 29 oct. à 10 h 31
    - **Grille de 2**
      - **Bouton secondaire** : Voir la photo
      - **Bouton secondaire** : Original reçu
- **Pied d’écran**
  - **Bouton principal** : J’ai payé Kodjo → OFF-4c

*Règles* : HON-09 ; ouverture de l’application opérateur par lien profond quand il existe, sinon copie du numéro et code USSD (annexe B, n° 8).

*Statut* : LIVRÉE (course à régler).

### OFF-4c · Commande close

Maquette : `Officine-4c-Reglee` · « Officine · 4c. Course réglée »

*Rôle* : clore la commande et suivre ce qui reste dû.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Commande close
  - **Texte** : Afi K. · livrée à 10 h 31
- **Contenu**
  - **Carte** : Course réglée | 1 000 FCFA payés à Kodjo à 10 h 36, sur son Flooz | Kodjo a confirmé la réception
  - **Carte**
    - **Texte** : Encaissé auprès d’Afi | 5 600 FCFA
    - **Texte** : Course reversée à Kodjo | −1 000 FCFA
    - **Texte** : Reste pour l’officine | 4 600 FCFA
  - **Carte**
    - **Texte** : Ordonnance originale | En attente
    - **Texte** : Chez Kodjo, à rapporter au plus tard le 29 oct. à 10 h 31.
    - **Texte** : Votre prochaine course lui est proposée en premier.
    - **Bouton secondaire** : Original reçu
  - **Ligne** : Signaler un défaut de livraison → OFF-11
- **Pied d’écran**
  - **Bouton principal** : Retour aux commandes → OFF-1

*Règles* : le coursier confirme dans son mode coursier ; sans confirmation ni contestation sous 48 h, le paiement est réputé reçu Recommandation ; un signalement de défaut ouvre un dossier support (BM-05).

*Statut* : COURSE_RÉGLÉE → CLOSE ; drapeau « original attendu » jusqu’à « Original reçu ».

### OFF-11 · Signaler un défaut

Maquette : `Officine-11-Signaler-defaut` · « Officine · 11. Signaler un défaut »

*Rôle* : signaler un défaut de livraison après la course.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour à la commande → OFF-4c
  - **Titre** : Signaler un défaut
  - **Texte** : Course de Kodjo A. · 28 oct.
- **Contenu**
  - **Titre de section** : Que s’est-il passé ?
  - **Choix** : ◉ | Retard important, sans prévenir
  - **Choix** : ○ | Colis ouvert ou abîmé
  - **Choix** : ○ | Original de l’ordonnance non rapporté
  - **Choix** : ○ | Comportement inapproprié
  - **Champ** : Précisions = Livré à 12 h 40 au lieu de 10 h 30, sans appel au patient.
  - **Encadré ambre** : Kodjo est prévenu et peut contester sous 48 h. Au 3e défaut confirmé, son compte coursier est suspendu.
- **Pied d’écran**
  - **Bouton principal** : Envoyer le signalement → OFF-1
  - **Ligne** : Annuler → OFF-4c

*Règles* : BM-05, HON-05 et HON-49 ; définition d’un défaut : annexe B, n° 10.

### OFF-5 · Abonnement

Maquette : `Officine-5-Abonnement` · « Officine · 5. Abonnement »

*Rôle* : gérer l’abonnement HONAM de l’officine.

**Disposition et textes**

- **En-tête**
  - **Image** : honam-icone
  - **Texte** : Pharmacie Démo
  - **Texte** : Tokoin, Lomé
  - **Filtre (sélectionné)** : Ouverte
  - **Bouton icône** : Notifications
- **Contenu**
  - **Titre** : Abonnement
  - **Carte**
    - **Texte** : Wétri HONAM | Actif
    - **Texte** : 5 000 FCFA HT par mois
    - **Texte** : Soit 5 900 FCFA TTC avec la TVA de 18 %
    - **Texte** : Prochain paiement le 27 novembre 2026
    - **Bouton principal** : Renouveler maintenant
    - **Texte** : Paiement par CashPay : mobile money ou carte
  - **Carte**
    - **Texte** : ÉPÉ HONAM | 2 mois offerts
    - **Texte** : 50 000 FCFA HT par an au lieu de 60 000, soit 59 000 FCFA TTC
    - **Bouton secondaire** : Passer à l’annuel
  - **Titre de section** : Factures
  - **Carte**
    - **Texte** : 27 octobre 2026
    - **Texte** : Wétri HONAM · 5 900 FCFA TTC · payée
    - **Bouton icône** : Télécharger la facture du 27 octobre 2026
  - **Carte**
    - **Titre de section** : Affiche QR
    - **Texte** : Pour votre comptoir
    - **Bouton secondaire** : Télécharger
- **Barre d’onglets** : Commandes / Historique / Abonnement (actif) / Compte

*Règles* : BM-02, BM-06 et BM-10 ; montants du Togo, en Côte d’Ivoire 7 500 FCFA HT par mois (8 850 TTC) et 75 000 FCFA HT par an (88 500 TTC) ; solde du crédit officine (HON-39) ; à expiration, l’officine disparaît des recherches (AC-HON-04) mais garde son historique.

### OFF-12 · Historique

Maquette : `Officine-12-Historique` · « Officine · 12. Historique »

*Rôle* : retrouver les commandes du mois et ce qui a été encaissé.

**Disposition et textes**

- **En-tête**
  - **Image** : honam-icone
  - **Texte** : Pharmacie Démo
  - **Texte** : Tokoin, Lomé
  - **Filtre (sélectionné)** : Ouverte
- **Contenu**
  - **Texte** : Historique | Octobre 2026
  - **Texte** : Livrées | 41 | Encaissé | 238 400 | FCFA, médicaments et courses | Annulées | 3
  - **Encadré beige**
    - **Filtre (sélectionné)** : Toutes
    - **Filtre** : Livrées
    - **Filtre** : Annulées
  - **Liste**
    - **Élément** : Afi K. | 28 oct. · livrée à 10 h 31 · Kodjo A. | 5 600 FCFA | Livrée
    - **Élément** : Yao M. | 27 oct. · retrait à l’officine | 3 200 FCFA | Livrée
    - **Élément** : Kossi A. | 27 oct. · produit manquant | 4 100 FCFA | Remboursée
    - **Élément** : Ama S. | 26 oct. · livrée à 17 h 02 · Yao A. | 6 400 FCFA | Livrée
    - **Élément** : Akossiwa K. | 25 oct. · ordonnance illisible | — | Refusée
  - **Lien** : Exporter le mois en CSV
- **Barre d’onglets** : Commandes / Historique (actif) / Abonnement / Compte

*Règles* : HON-54 ; montants déclarés dans Honam, Pokou ne voyant pas l’argent (BM-01) ; aucun nom de médicament dans la liste.

### OFF-13 · Compte

Maquette : `Officine-13-Compte` · « Officine · 13. Compte de l’officine »

*Rôle* : régler la fiche et le fonctionnement de l’officine.

**Disposition et textes**

- **En-tête**
  - **Image** : honam-icone
  - **Texte** : Pharmacie Démo
  - **Texte** : Tokoin, Lomé
  - **Filtre (sélectionné)** : Ouverte
- **Contenu**
  - **Titre** : Compte
  - **Carte**
    - **Texte** : Pharmacie Démo | Tokoin, rue 254 · Lomé
    - **Texte** : Horaires | Lun.–sam., 8 h–21 h
    - **Texte** : Prochaine garde | 9 nov.
    - **Texte** : Wallet de réception | Flooz 96 •• •• 12 · au nom de l’officine
  - **Carte**
    - **Ligne** : Vos coursiers | 1 rattaché → OFF-6
    - **Texte** : Téléphones du comptoir | 2
  - **Carte**
    - **Interrupteur** : Sonnerie à chaque ordonnance | [interrupteur activé]
    - **Interrupteur** : Fermer temporairement | Les patients ne vous voient plus | [interrupteur désactivé]
  - **Carte** : Se déconnecter de ce téléphone
- **Barre d’onglets** : Commandes / Historique / Abonnement / Compte (actif)

*Règles* : BM-02, BM-12, HON-07 et HON-54 ; fermée temporairement, l’officine n’apparaît plus aux patients.

*Variante et cas particuliers*

### OFF-2b · Devis, original à récupérer

Maquette : `Officine-2b-Devis-original` · « Officine · 2b. Devis, original à récupérer »

*Rôle* : variante d’OFF-2 quand l’officine coche « Ordonnance originale à récupérer ».

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Devis pour Afi K.
  - **Texte** : Bè-Kpota · 2,1 km · reçue à 9 h 42
- **Contenu**
  - **Case à cocher** : ☑ | Ordonnance originale à récupérer
  - **Carte**
    - **Texte** : Retour de l’original à l’officine
    - **Choix** : ◉ | Au prochain passage du coursier | Sans frais, au plus tard sous 48 h
    - **Choix** : ○ | Retour immédiat | Une course de plus, payée par Afi : 1 000 FCFA
  - **Encadré beige** : Afi sera prévenue : « Prépare l’original de ton ordonnance pour le coursier. »
  - **Carte** : Produits | 3 produits chiffrés | 4 600 FCFA
  - **Carte**
    - **Texte** : Médicaments | 4 600 FCFA
    - **Texte** : Course, ajoutée par Honam | 1 000 FCFA
    - **Texte** : Retour de l’original | 0 FCFA
    - **Texte** : Total à payer | 5 600 FCFA
- **Pied d’écran**
  - **Bouton principal** : Envoyer le devis à Afi → OFF-3
  - **Ligne** : Refuser l’ordonnance → OFF-R1

*Règles* : 11.5.

### OFF-R1 · Refuser l’ordonnance

Maquette : `Officine-R1-Refus` · « Officine · R1. Refuser l'ordonnance »

*Rôle* : refuser une ordonnance avec un motif clair pour le patient.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour au devis → OFF-2
  - **Titre** : Refuser l’ordonnance
  - **Texte** : Afi K. · reçue à 9 h 42
- **Contenu**
  - **Carte**
    - **Texte** : Motif
    - **Choix** : ◉ | Produits indisponibles | Afi verra d’autres officines proches
    - **Choix** : ○ | Ordonnance illisible ou incomplète | Une nouvelle photo suffit souvent
    - **Choix** : ○ | Délivrance en personne obligatoire | Afi pourra la retirer à l’officine
    - **Choix** : ○ | Ordonnance périmée ou douteuse | À présenter en personne à un pharmacien
    - **Choix** : ○ | Hors de votre zone de livraison | Afi verra des officines plus proches
    - **Choix** : ○ | Autre motif | Expliquez-le dans le message
  - **Champ** : Message pour Afi
  - **Carte** : Bonjour Afi, nous n’avons plus d’amoxicilline 500 mg aujourd’hui. Honam vous propose des officines proches qui peuvent vous servir.
  - **Ligne** : Plutôt demander une nouvelle photo
- **Pied d’écran**
  - **Bouton principal** : Refuser et prévenir Afi → OFF-R2
  - **Ligne** : Annuler → OFF-2

*Règles* : 11.6.

### OFF-R2 · Ordonnance refusée

Maquette : `Officine-R2-Refusee` · « Officine · R2. Ordonnance refusée »

*Rôle* : confirmer le refus et dire ce qui se passe ensuite.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Ordonnance refusée
  - **Texte** : Afi K. · prévenue à 9 h 47
- **Contenu**
  - **Carte** : Motif : produits indisponibles | Afi n’a rien payé : il n’y a rien à rembourser.
  - **Carte** : Message envoyé à Afi | Bonjour Afi, nous n’avons plus d’amoxicilline 500 mg aujourd’hui. Honam vous propose des officines proches qui peuvent vous servir.
  - **Carte** : Ce qui se passe ensuite | [pastille 1] | Afi reçoit votre message et le motif. | [pastille 2] | Honam lui propose les officines ouvertes les plus proches : elle y renvoie son ordonnance d’un geste. | [pastille 3] | La commande passe dans votre historique, avec son motif. | [pastille 4] | Les produits qu’on vous demande et que vous n’avez pas s’ajoutent à vos statistiques de demandes non servies.
  - **Ligne** : Annuler le refus (encore 4 min) → OFF-2
- **Pied d’écran**
  - **Bouton principal** : Retour aux commandes → OFF-1

*Règles* : 11.6.

*Statut* : REFUSÉE.

### OFF-P1 · Paiement non reçu

Maquette : `Officine-P1-Paiement-non-recu` · « Officine · P1. Paiement non reçu »

*Rôle* : signaler qu’un paiement déclaré n’apparaît pas sur le wallet de l’officine.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour au paiement → OFF-3
  - **Titre** : Paiement non reçu
  - **Texte** : Afi K. · 5 600 FCFA attendus
- **Contenu**
  - **Carte**
    - **Titre de section** : Ce qu’Afi a signalé
    - **Texte** : Heure | 9 h 58
    - **Texte** : Référence | 7KX4-2190
    - **Texte** : Envoyé depuis | Flooz · 96 •• •• 58
  - **Carte**
    - **Texte** : Ce que vous constatez
    - **Choix** : ◉ | Rien reçu | Afi doit vérifier le numéro et le montant
    - **Choix** : ○ | Montant différent reçu | Indiquez-le : Afi devra payer le reste
  - **Encadré ambre** : Ne préparez rien tant que l’argent n’apparaît pas sur votre compte Flooz. Une capture d’écran ou un SMS transféré ne prouvent pas un paiement.
  - **Texte** : Sans paiement, le devis expire demain à 9 h 46 et la commande est annulée.
- **Pied d’écran**
  - **Bouton principal** : Prévenir Afi → OFF-P2
  - **Ligne** : Attendre encore 15 min → OFF-1

*Règles* : 11.7.

*Statut* : PAIEMENT_DÉCLARÉ → PAIEMENT_NON_REÇU.

### OFF-P2 · Paiement en attente

Maquette : `Officine-P2-Relance` · « Officine · P2. Paiement en attente »

*Rôle* : suivre un paiement relancé jusqu’à réception ou expiration.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Paiement en attente
  - **Texte** : Afi K. · relancée à 10 h 10
- **Contenu**
  - **Carte**
    - **Puce** : En attente
    - **Texte** : 5 600 FCFA
    - **Texte** : Sur votre Flooz · 96 •• •• 12
    - **Texte** : Devis valable jusqu’à demain 9 h 46
  - **Carte** : Suivi | 9 h 46 | Devis envoyé à Afi | 9 h 58 | Afi signale son paiement, réf. 7KX4-2190 | 10 h 10 | Vous signalez : rien reçu | 10 h 10 | Honam relance Afi | Demain | À 9 h 46, le devis expire sans paiement
  - **Carte** : Message envoyé à Afi | « L’officine n’a pas reçu tes 5 600 FCFA sur Flooz 96 •• •• 12. Vérifie le numéro et le montant, puis renvoie la référence. »
  - **Texte** : Si Afi a payé sur un autre numéro, seul son opérateur peut récupérer l’argent : il ne passe jamais par Pokou.
- **Pied d’écran**
  - **Bouton principal** : Paiement reçu finalement → OFF-4
  - **Ligne** : Annuler la commande → OFF-1

*Règles* : 11.7.

### OFF-A1 · Préparation, produit manquant

Maquette : `Officine-A1-Produit-manquant` · « Officine · A1. Produit manquant »

*Rôle* : préparer la commande produit par produit et signaler un manque.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Préparation d’Afi K.
  - **Texte** : Payée 5 600 FCFA à 9 h 58
- **Contenu**
  - **Étapes**
    - **Élément** : [barre] | Reçue (fait)
    - **Élément** : [barre] | Devis (fait)
    - **Élément** : [barre] | Payée (fait)
    - **Élément** : [barre] | Prête (en cours)
    - **Élément** : [barre] | Livrée (à venir)
  - **Titre de section** : Produits à préparer
  - **Liste**
    - **Encadré terracotta clair**
      - **Champ** : ☐
      - **Champ** : Amoxicilline 500 mg
      - **Texte** : 12 gélules · 1 800 FCFA
      - **Filtre (sélectionné)** : Manquant
    - **Élément**
      - **Champ** : ☑
      - **Champ** : Paracétamol 1 g
      - **Texte** : 8 comprimés · 600 FCFA
      - **Filtre** : Manquant
    - **Élément**
      - **Champ** : ☑
      - **Champ** : Sirop antitussif
      - **Texte** : Flacon 125 ml · 2 200 FCFA
      - **Filtre** : Manquant
  - **Carte**
    - **Titre de section** : Honam propose à Afi
    - **Carte** : Recevoir le reste | Paracétamol et sirop livrés | 1 800 FCFA | remboursés
    - **Carte** : Tout annuler | Et commander ailleurs | 5 600 FCFA | remboursés
  - **Encadré beige** : Sans réponse d’Afi sous 15 min, la commande est annulée et remboursée en totalité. | Aucun coursier n’a encore été appelé : il ne l’est qu’une fois la commande prête.
- **Pied d’écran**
  - **Bouton principal** : Prévenir Afi → OFF-A2
  - **Lien** : Annuler toute la commande

*Règles* : 11.8.

*Statut* : EN_PRÉPARATION → PRODUIT_MANQUANT.

### OFF-A2 · Rembourser le patient

Maquette : `Officine-A2-Rembourser` · « Officine · A2. Rembourser Afi »

*Rôle* : rembourser le patient après une annulation ou un produit manquant.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Rembourser Afi
  - **Texte** : Commande annulée à 10 h 09
- **Contenu**
  - **Carte** : Afi préfère tout annuler | Réponse reçue à 10 h 09. Honam lui propose d’autres officines proches.
  - **Carte**
    - **Texte** : À rembourser
    - **Texte** : 5 600 FCFA
    - **Texte** : Médicaments 4 600 + course non effectuée 1 000
    - **Texte** : Sur son Flooz · 96 •• •• 58
    - **Texte** : Le numéro qui vous a payé à 9 h 58
    - **Grille de 2**
      - **Bouton secondaire** : Ouvrir Flooz
      - **Bouton secondaire** : Copier le numéro
  - **Encadré ambre** : Remboursez uniquement ce numéro, même si quelqu’un vous en donne un autre.
  - **Champ** : Référence du transfert
  - **Champ** : [champ : 9QB2-6635]
  - **Texte** : Elle figure dans le SMS de confirmation de Flooz.
  - **Texte** : À faire avant 12 h 09. Afi doit recevoir 5 600 FCFA : si des frais s’appliquent, ils sont pour vous.
- **Pied d’écran**
  - **Bouton principal** : J’ai remboursé Afi → OFF-A3

*Règles* : 11.8.

*Statut* : ANNULÉE_À_REMBOURSER → REMBOURSEMENT_DÉCLARÉ.

### OFF-A3 · Commande annulée

Maquette : `Officine-A3-Annulee` · « Officine · A3. Commande annulée »

*Rôle* : clore une commande annulée et remboursée.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Commande annulée
  - **Texte** : Afi K. · remboursée à 10 h 14
- **Contenu**
  - **Carte** : Remboursement confirmé | 5 600 FCFA envoyés à Afi à 10 h 14, réf. 9QB2-6635 | Afi a confirmé la réception à 10 h 16
  - **Carte**
    - **Texte** : Encaissé auprès d’Afi | 5 600 FCFA
    - **Texte** : Remboursé à Afi | −5 600 FCFA
    - **Texte** : Course, aucun coursier appelé | 0 FCFA
    - **Texte** : Reste pour l’officine | 0 FCFA
  - **Carte** : Ce que retient Honam | La commande reste dans votre historique avec son motif : amoxicilline 500 mg manquante. | Amoxicilline 500 mg : 3 demandes non servies cette semaine.
- **Pied d’écran**
  - **Bouton principal** : Retour aux commandes → OFF-1

*Statut* : REMBOURSEMENT_DÉCLARÉ → ANNULÉE_REMBOURSÉE.

*Référencement de l’officine*

### OFF-14 · Référencer votre officine

Maquette : `Officine-14-Inscription` · « Officine · 14. Référencer votre officine »

*Rôle* : déposer le dossier de l’officine (étape 1 sur 3).

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Référencer votre officine
  - **Texte** : Étape 1 sur 3
- **Contenu**
  - **Champ** : Nom de l’officine = Pharmacie Démo
  - **Champ** : Adresse = Tokoin, rue 254, Lomé
  - **Champ** : N° d’autorisation d’exercice = Tel qu’il figure sur l’arrêté
  - **Champ** : Wallet de réception = Flooz · 96 00 00 12 | Les patients vous paient sur ce numéro. Il doit être au nom de l’officine.
  - **Carte** : Autorisation d’ouverture | Photo ou PDF | Ajoutée
  - **Encadré beige** : Honam est réservé aux pharmacies qui acceptent le paiement mobile.
- **Pied d’écran**
  - **Bouton principal** : Continuer → OFF-15

*Règles* : HON-52 ; pièces de la section 11.3.

### OFF-15 · Choisir la formule

Maquette : `Officine-15-Formule` · « Officine · 15. Choisir la formule »

*Rôle* : choisir Wétri HONAM ou ÉPÉ HONAM (étape 2 sur 3).

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → OFF-14
  - **Titre** : Choisissez votre formule
  - **Texte** : Étape 2 sur 3
- **Contenu**
  - **Choix** : ○ | Wétri HONAM | au mois | 5 000 FCFA HT | 5 900 FCFA TTC par mois, TVA de 18 %
  - **Choix** : ◉ | ÉPÉ HONAM | 2 mois offerts | 50 000 FCFA HT | au lieu de 60 000, soit 59 000 FCFA TTC par an
  - **Carte**
    - **Texte** : Votre officine visible des patients proches
    - **Texte** : Ordonnances et devis sur téléphone
    - **Texte** : Les coursiers Honam de votre zone
    - **Texte** : Factures CashPay pour votre comptabilité
  - **Carte** : Aucun paiement avant la vérification de votre officine. Vous payez ensuite par CashPay : mobile money ou carte.
- **Pied d’écran**
  - **Bouton principal** : Envoyer pour vérification → OFF-16

*Règles* : BM-06, BM-10 et HON-52 ; montants du Togo (Côte d’Ivoire : section 4.1).

### OFF-16 · Vérification en cours

Maquette : `Officine-16-Verification` · « Officine · 16. Vérification en cours »

*Rôle* : faire patienter pendant la vérification (étape 3 sur 3).

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Vérification en cours
  - **Texte** : Étape 3 sur 3
- **Contenu**
  - **Texte** : Le support de Pokou vérifie votre autorisation et votre wallet sous 48 h. Vous recevez une notification dès la décision.
  - **Carte** : Dossier envoyé | Aujourd’hui, 10:05 | Vérification par le support | Au plus tard le 5 nov. à 10:05 | 3 | Paiement ÉPÉ HONAM, puis ouverture | 59 000 FCFA TTC par CashPay
  - **Carte** : En attendant, préparez votre comptoir : l’affiche QR et la liste de vos livreurs habituels.
- **Pied d’écran**
  - **Bouton principal** : Terminé → APP-6

*Règles* : HON-52 ; annexe B, n° 34.

## 11.11 Coursiers : recrutement, mode coursier et packs

### COU-0 · Où l’offre coursier apparaît

Maquette : `Coursier-0-Points-entree` · « Coursiers · 0. Où l’offre apparaît »

*Rôle* : planche des points d’entrée de l’offre.

**Disposition et textes**

- **Contenu**
  - **Titre** : Où l’offre coursier apparaît
  - **Texte** : Seulement dans les villes où Honam a des officines. Une proposition par mois au plus, jamais aux mineurs ni aux officines.
  - **Texte** : Plus · toujours
  - **Ligne** : Devenir coursier Honam | 1 000 FCFA par course, près de chez toi → COU-1
  - **Texte** : Écran Honam · bandeau
  - **Carte**
    - **Texte** : Gagne de l’argent en livrant près de chez toi.
    - **Lien** : Découvrir → COU-1
  - **Texte** : Après une livraison reçue
  - **Encadré vert**
    - **Texte** : Livrée par Kodjo à 10 h 31. Toi aussi, tu peux livrer pour Honam quand tu veux.
    - **Rangée**
      - **Lien** : En savoir plus → COU-1
      - **Texte** : Ne plus me proposer
  - **Texte** : Accueil · zone en manque de coursiers
  - **Encadré ambre**
    - **Texte** : 12 courses sans coursier à Bè cette semaine
    - **Texte** : Selon le quartier que tu as indiqué, jamais ta position.
    - **Puce (sélectionnée)** : Devenir coursier → COU-1
  - **Texte** : Hors de l’application
  - **Texte** : Lien de parrainage d’un coursier | QR code d’officine ou de commercial

*Règles* : HON-40 ; une proposition par mois au plus ; jamais aux moins de 18 ans ni aux officines.

### COU-1 · Livre pour Honam

Maquette : `Coursier-1-Offre` · « Coursiers · 1. Livre pour Honam »

*Rôle* : présenter l’offre et ce qu’elle rapporte.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Livre pour Honam
  - **Texte** : Lomé · Honam est ouvert
- **Contenu**
  - **Encadré vert**
    - **Texte** : Tu gagnes
    - **Texte** : 1 000 FCFA par course
    - **Texte** : versés par l’officine sur ton wallet, quand tu veux, près de chez toi
  - **Carte**
    - **Texte** : Combien je peux gagner ? | 20 courses par mois
    - **Indicateur** : [barre 45%]
    - **Texte** : Courses | 20 000 FCFA
    - **Texte** : Adhésion et pack Oseï Tutu, TTC | −3 068 FCFA
    - **Texte** : Net pour toi | 16 932 FCFA
  - **Titre de section** : Ce que ça coûte
  - **Carte**
    - **Texte** : Essai | Dès la validation, sur un mois | 5 courses offertes
    - **Texte** : Ensuite, Win Pokou | Plus un pack de courses, au choix | 1 180 FCFA TTC par mois
    - **Encadré terracotta clair** : Si Honam vient d’ouvrir dans ta ville | 2 mois sans adhésion ni pack, puis Win Pokou | Gratuit
  - **Titre de section** : Il te faut
  - **Liste**
    - **Élément** : 18 ans ou plus, une pièce d’identité
    - **Élément** : Une moto, un vélo, ou tes pieds pour les courses proches
    - **Élément** : Un smartphone et un wallet mobile money
- **Pied d’écran**
  - **Bouton principal** : Je deviens coursier → COU-2

*Règles* : section 4.2 ; montants du pays ; coûts annoncés dès le départ.

### COU-2 · Avant de commencer

Maquette : `Coursier-2-Conditions` · « Coursiers · 2. Avant de commencer »

*Rôle* : vérifier l’âge, la ville et le moyen de transport.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-1
  - **Titre** : Avant de commencer
  - **Texte** : Devenir coursier · étape 1 sur 6
- **Contenu**
  - **Indicateur** : [barre d’étapes 1/6]
  - **Champ** : Date de naissance = 12/03/1999
  - **Carte** : Ville | Lomé | Honam ouvert
  - **Texte** : Comment livres-tu ?
  - **Texte** : Moto | jusqu’à 8 km | Vélo | jusqu’à 4 km | À pied | jusqu’à 1,5 km
  - **Carte** : Les courses proposées tiennent compte de ton moyen de transport. Le mode coursier n’est pas accessible avant 18 ans.
- **Pied d’écran**
  - **Bouton principal** : Continuer → COU-3

*Règles* : HON-41 ; moins de 18 ans : accès refusé ; ville non desservie : liste d’attente (COU-16).

### COU-3 · Identité

Maquette : `Coursier-3-Identite` · « Coursiers · 3. Identité »

*Rôle* : vérifier l’identité du coursier.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-2
  - **Titre** : Ton identité
  - **Texte** : Devenir coursier · étape 2 sur 6
- **Contenu**
  - **Indicateur** : [barre d’étapes 2/6]
  - **Texte** : CNI
  - **Carte** : Passeport
  - **Carte** : Carte d’électeur
  - **Texte** : Recto · lisible
  - **Carte** : Photographier le verso
  - **Bouton secondaire** : Prendre un selfie
  - **Carte** : Le nom de ta pièce doit être celui du titulaire de ton wallet. Si tu as Pokou certifié, ton nom vérifié est repris : il ne reste que la pièce.
  - **Carte** : Ta pièce sert seulement à vérifier ton identité. Elle est chiffrée et supprimée 30 jours après la décision.
- **Pied d’écran**
  - **Bouton principal** : Continuer → COU-4

*Règles* : HON-41 ; nom vérifié repris de Pokou certifié s’il existe.

### COU-4 · Zones et créneaux

Maquette : `Coursier-4-Zones` · « Coursiers · 4. Zones et créneaux »

*Rôle* : choisir où et quand livrer.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-3
  - **Titre** : Tes zones et tes créneaux
  - **Texte** : Devenir coursier · étape 3 sur 6
- **Contenu**
  - **Indicateur** : [barre d’étapes 3/6]
  - **Titre de section** : Quartiers où tu livres
  - **Puces** : Bè (sélectionnée) | Tokoin (sélectionnée) | Amoutivé (sélectionnée) | Nyékonakpoè | Hédzranawoé | Adidogomé | Agoè
  - **Titre de section** : Quand es-tu souvent disponible ?
  - **Puces** : Lun. (sélectionnée) | Mar. (sélectionnée) | Mer. (sélectionnée) | Jeu. (sélectionnée) | Ven. (sélectionnée) | Sam. (sélectionnée) | Dim.
  - **Puces** : Matin (sélectionnée) | Midi | Après-midi | Soir (sélectionnée)
  - **Encadré terracotta clair** : [avatar PD] | Invité par Pharmacie Démo | Ses courses te sont proposées en premier, 30 secondes avant les autres.
  - **Carte** : Ces choix servent à te proposer des courses. Tu restes libre : seul le bouton « Disponible » compte.
- **Pied d’écran**
  - **Bouton principal** : Continuer → COU-5

*Règles* : HON-41 et HON-42 ; seul le bouton « Disponible » engage le coursier.

### COU-5 · Wallet

Maquette : `Coursier-5-Wallet` · « Coursiers · 5. Wallet »

*Rôle* : choisir le wallet où l’officine paie les courses.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-4
  - **Titre** : Où recevoir tes gains
  - **Texte** : Devenir coursier · étape 4 sur 6
- **Contenu**
  - **Indicateur** : [barre d’étapes 4/6]
  - **Carte**
    - **Choix** : ◉ | Flooz | Moov Africa
    - **Choix** : ○ | Mixx by Yas
  - **Champ** : Numéro du wallet = +228 96 •• •• 03
  - **Texte** : Code reçu par SMS
  - **Texte** : 4 | 7 | 1 | 9
  - **Encadré vert** : Titulaire : Kodjo A. | Correspond au nom de ta pièce d’identité.
  - **Carte** : Les officines te paient directement sur ce wallet après chaque livraison. Pokou ne touche jamais cet argent.
- **Pied d’écran**
  - **Bouton principal** : Continuer → COU-6

*Règles* : HON-41 ; Pokou ne touche jamais l’argent des courses.

### COU-6 · Règles d’or

Maquette : `Coursier-6-Regles` · « Coursiers · 6. Règles d’or »

*Rôle* : former le coursier en deux minutes.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-5
  - **Titre** : Les règles d’or
  - **Texte** : Devenir coursier · étape 5 sur 6
- **Contenu**
  - **Indicateur** : [barre d’étapes 5/6]
  - **Liste**
    - **Élément** : Le colis reste fermé | Tu ne vois ni l’ordonnance ni les produits.
    - **Élément** : Tu n’encaisses rien du patient | L’officine te paie la course sur ton wallet.
    - **Élément** : Le code vient du patient | Il s’affiche dans son application, à la remise.
    - **Élément** : 3 défauts, compte suspendu | Avec un recours possible auprès du support.
  - **Carte**
    - **Texte** : Question 1 sur 3
    - **Texte** : Le patient veut te payer la course en espèces. Que fais-tu ?
    - **Carte** : J’accepte, c’est plus simple
    - **Encadré vert** : Je refuse : l’officine me paie
- **Pied d’écran**
  - **Bouton principal** : J’accepte les conditions coursier → COU-7

*Règles* : HON-02 et BM-05 ; une mauvaise réponse affiche la bonne règle avant de continuer.

### COU-7 · Candidature envoyée

Maquette : `Coursier-7-Candidature` · « Coursiers · 7. Candidature envoyée »

*Rôle* : faire patienter pendant la vérification.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-6
  - **Titre** : Candidature envoyée
  - **Texte** : Devenir coursier · étape 6 sur 6
- **Contenu**
  - **Indicateur** : [barre d’étapes 6/6]
  - **Texte** : Le support vérifie ton identité sous 48 h. Tu reçois une notification dès que ton mode coursier est activé.
  - **Carte** : Inscription envoyée | Aujourd’hui, 09:40 | Vérification de l’identité | Au plus tard le 2 nov. à 09:40 | 3 | Mode coursier activé | Tu passes « Disponible » quand tu veux
  - **Encadré ambre** : Dès l’activation, 5 courses d’essai t’attendent, sans adhésion ni pack.
- **Pied d’écran**
  - **Bouton principal** : Terminé → APP-6

*Règles* : HON-39 et HON-41 ; notification à la décision.

### COU-17 · Candidature acceptée

Maquette : `Coursier-17-Acceptee` · « Coursiers · 17. Candidature acceptée »

*Rôle* : annoncer la validation et activer le mode coursier.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Bienvenue chez les coursiers
- **Contenu**
  - **Texte** : Ton identité est vérifiée, Kodjo. Ton mode coursier est activé.
  - **Encadré ambre** : 5 courses d’essai offertes | Sans adhésion ni pack, sur un mois. Tes 5 premières courses portent sur des commandes de moins de 15 000 FCFA.
  - **Carte**
    - **Texte** : Zones | Bè, Tokoin, Amoutivé
    - **Texte** : Créneaux | Lun.–sam., 8 h–14 h
    - **Texte** : Wallet | Flooz 96 •• •• 34
  - **Encadré beige** : Rappel : le colis reste fermé, tu n’encaisses rien du patient, et c’est le patient qui te donne le code de remise.
- **Pied d’écran**
  - **Bouton principal** : Passer en mode coursier → COU-8

*Règles* : HON-39, HON-41, HON-55 et HON-56.

### COU-18 · Candidature à compléter

Maquette : `Coursier-18-A-completer` · « Coursiers · 18. Candidature à compléter »

*Rôle* : dire précisément ce qu’il faut reprendre.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Candidature à compléter
- **Contenu**
  - **Texte** : Le support n’a pas pu vérifier ton identité.
  - **Carte**
    - **Texte** : À reprendre
    - **Texte** : Selfie flou
    - **Texte** : Ton visage doit être net, bien éclairé, sans lunettes de soleil.
  - **Titre de section** : Déjà validé
  - **Carte**
    - **Texte** : Pièce d’identité
    - **Texte** : Zones et créneaux
    - **Texte** : Wallet Flooz 96 •• •• 34
    - **Texte** : Règles d’or acceptées
  - **Texte** : Ta candidature reste ouverte 30 jours.
- **Pied d’écran**
  - **Bouton principal** : Reprendre le selfie → COU-3
  - **Ligne** : Contacter le support → REG-10

*Règles* : HON-41 et HON-55 ; refus toujours motivé, comme pour PRO-4.

### COU-16 · Liste d’attente

Maquette : `Coursier-16-Liste-attente` · « Coursiers · 16. Liste d’attente »

*Rôle* : garder le contact quand la ville n’est pas desservie.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Livre pour Honam
  - **Texte** : Kara
- **Contenu**
  - **Titre** : Honam n’est pas encore à Kara
  - **Texte** : Aucune officine de Kara n’a encore rejoint Honam : il n’y aurait pas de courses pour toi. On te prévient dès qu’elles arrivent.
  - **Carte** : 86 | personnes attendent Honam à Kara, coursiers et patients
  - **Carte** : Ces inscriptions aident Pokou à choisir les prochaines villes.
- **Pied d’écran**
  - **Bouton principal** : Me prévenir → APP-6

*Règles* : HON-40 ; ces inscriptions aident à choisir les prochaines villes.

### COU-15 · Parrainage

Maquette : `Coursier-15-Parrainage` · « Coursiers · 15. Parrainage »

*Rôle* : faire recruter des coursiers par les coursiers.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-8
  - **Titre** : Invite un coursier
- **Contenu**
  - **Carte** : [icône : QR code de parrainage] | Ton code | KODJO-7Q2 | À montrer, ou à partager en lien
  - **Bouton principal** : Partager mon lien → COU-23
  - **Encadré ambre** : Tu reçois 2 courses offertes quand ton filleul termine sa première livraison.
  - **Titre de section** : Tes filleuls
  - **Carte** : [avatar YA] | Yao A. | +2 courses | Première livraison faite | [avatar DT] | Délali T. | — | Inscription en cours

*Règles* : HON-43 ; courses offertes seulement après la première livraison du filleul.

### COU-23 · Proposer à un ami

Maquette : `Coursier-23-Proposer` · « Coursiers · 23. Proposer à un ami »

*Rôle* : inviter un ou plusieurs amis à devenir coursiers.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-15
  - **Titre** : Proposer à un ami
  - **Texte** : Ton code : KODJO-7Q2
- **Contenu**
  - **Encadré beige** : Rechercher un contact
  - **Liste**
    - **Case à cocher** : [avatar KA] | Komi A. | Sur Pokou · Bè | ☑
    - **Case à cocher** : [avatar YB] | Yawo B. | Sur Pokou · Tokoin | ☐
    - **Case à cocher** : [avatar SD] | Séna D. | Pas encore sur Pokou · invitation par SMS | ☐
  - **Carte**
    - **Texte** : Ton message, modifiable
    - **Texte** : Salut Komi ! Je livre pour Honam avec Pokou : 1 000 FCFA par course, près de chez toi, quand tu veux. Rejoins-moi avec mon code KODJO-7Q2.
    - **Texte** : La carte « Devenir coursier Honam » est ajoutée au message.
  - **Carte** : Tu reçois 2 courses offertes quand ton ami termine sa première livraison. L’invitation part seulement vers les 18 ans et plus, dans une ville où Honam est ouvert.
- **Pied d’écran**
  - **Bouton principal** : Envoyer à Komi → COU-24
  - **Ligne** : Copier mon lien

*Règles* : HON-40, HON-43 et HON-53.

### COU-24 · Invitation reçue

Maquette : `Coursier-24-Invitation-recue` · « Coursiers · 24. Invitation reçue par l’ami »

*Rôle* : l’invitation telle que l’ami la reçoit, dans la discussion à deux.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Avatar** : KA
  - **Titre** : Kodjo A.
  - **Texte** : en ligne
  - **Bouton icône** : Appel audio → DIS-9
  - **Bouton icône** : Appel vidéo → DIS-10
  - **Bouton icône** : Options de la discussion
- **Contenu**
  - **Repère** : Aujourd’hui
  - **Bulle reçue**
    - **Encadré ambre**
      - **Texte** : Invitation coursier Honam
      - **Texte** : Kodjo t’invite à livrer pour Honam
      - **Texte** : 1 000 FCFA par course · Lomé · code KODJO-7Q2
      - **Puce (sélectionnée)** : Voir l’offre → COU-25
    - **Texte** : Salut Komi ! Je livre pour Honam avec Pokou : 1 000 FCFA par course, près de chez toi, quand tu veux. Rejoins-moi avec mon code KODJO-7Q2.
    - **Texte** : 11:02
  - **Bulle envoyée** : C’est sérieux ? Il faut une moto ? | 11:05 · Lu
  - **Bulle reçue** : Une moto ou un vélo, ou à pied pour les courses proches. L’officine te paie chaque course sur ton wallet. | 11:06
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier → DIS-2
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale → DIS-4
  - **Bouton icône** : Envoyer

*Règles* : HON-53 ; hors de Pokou, le SMS mène à l’installation, puis à la même offre avec le code.

### COU-25 · Offre pour l’ami invité

Maquette : `Coursier-25-Offre-filleul` · « Coursiers · 25. Offre pour l’ami invité »

*Rôle* : présenter l’offre coursier à l’ami, code du parrain appliqué.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-24
  - **Titre** : Livre pour Honam
  - **Texte** : Lomé · Honam est ouvert
- **Contenu**
  - **Encadré vert** : [avatar KA] | Invité par Kodjo A. | Coursier vérifié · code KODJO-7Q2 appliqué
  - **Carte**
    - **Texte** : Tu gagnes
    - **Texte** : 1 000 FCFA par course
    - **Texte** : versés par l’officine sur ton wallet, quand tu veux, près de chez toi
  - **Carte**
    - **Texte** : 5 courses d’essai offertes | Dès la validation de ton inscription, sans adhésion ni pack
    - **Texte** : Des premières courses simples | Des commandes de moins de 15 000 FCFA, le temps de prendre tes repères
    - **Texte** : Kodjo t’a recommandé | Il reçoit 2 courses offertes quand tu termines ta première livraison
  - **Encadré beige** : Il te faut 18 ans ou plus, une pièce d’identité, un smartphone et un wallet mobile money. Une moto, un vélo, ou tes pieds pour les courses proches.
- **Pied d’écran**
  - **Bouton principal** : Je deviens coursier → COU-2
  - **Ligne** : Pas maintenant → APP-2

*Règles* : HON-39, HON-41, HON-43, HON-53 et HON-56 ; dans une ville où Honam vient d’ouvrir, l’offre montre le lancement à la place de l’essai.

### OFF-6 · Vos coursiers

Maquette : `Officine-6-Coursiers` · « Officine · 6. Vos coursiers »

*Rôle* : pour l’officine, inviter et suivre ses livreurs habituels.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-1
  - **Titre** : Vos coursiers
  - **Texte** : Pharmacie Démo · Tokoin
- **Contenu**
  - **Encadré terracotta clair** : Invitez vos livreurs habituels | Vos courses leur sont proposées en premier, pendant 30 secondes, avant les autres coursiers de la zone. Ils restent libres d’accepter d’autres officines.
  - **Carte** : [avatar KA] | Kodjo A. | Moto · 0 défaut ce mois-ci | 12 courses | Rattaché | [avatar YA] | Yao A. | Hier, 18:20 | — | Invitation envoyée
  - **Grille de 2**
    - **Bouton principal** : Partager le lien
    - **Bouton secondaire** : QR code
  - **Carte** : Sans coursier rattaché disponible, la course part aux coursiers de la zone, comme d’habitude.

*Règles* : HON-42 ; vouvoiement de l’officine.

### COU-26 · Plus, pour un coursier

Maquette : `Coursier-26-Plus-coursier` · « Coursiers · 26. Plus, pour un coursier »

*Rôle* : retrouver le mode coursier une fois la candidature acceptée.

**Disposition et textes**

- **En-tête**
  - **Titre** : Plus
- **Contenu**
  - **Carte**
    - **Avatar** : KA
    - **Titre de section** : Kodjo A.
    - **Texte** : +228 96 •• •• 34
    - **Bouton secondaire** : Modifier → INS-3
  - **Ligne** : Pokou certifié | Nom vérifié et mode preuve · essai d’un mois → CRT-1
  - **Ligne** : Mode coursier | Disponible · 3 courses d’essai restantes → COU-8
  - **Liste**
    - **Ligne** : Assimé | Petites annonces → APP-5
    - **Ligne** : Appels → DIS-21
  - **Liste**
    - **Ligne** : Compte et sécurité → REG-3
    - **Ligne** : Notifications → REG-8
    - **Ligne** : Confidentialité → REG-1
    - **Ligne** : Langue | Français → REG-9
  - **Liste**
    - **Ligne** : Aide et support → REG-10
    - **Ligne** : [image : pokou-app-icon] | À propos de Pokou → REG-11
- **Barre d’onglets** : Accueil / Discussions / Kory / Honam / Plus (actif)

*Règles* : HON-58 ; la carte reste tant que le compte coursier existe ; compte suspendu, elle mène à COU-21.

### COU-8 · Mode coursier

Maquette : `Coursier-8-Accueil` · « Coursiers · 8. Mode coursier »

*Rôle* : accueil du coursier.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-26
  - **Titre** : Mode coursier
  - **Texte** : Kodjo A. · moto · Bè, Tokoin, Amoutivé
  - **Bouton icône** : Passer indisponible et quitter le mode coursier → APP-1
- **Contenu**
  - **Encadré vert** : Disponible | Les courses t’arrivent, même quand tu discutes | [interrupteur activé]
  - **Encadré ambre** : Essai : 3 courses restantes sur 5 | jusqu’au 30 nov. | [barre 40%]
  - **Rangée**
    - **Vignette** : Gains de novembre | 2 000 FCFA | 2 courses payées → COU-22
    - **Texte** : Défauts
    - **Texte** : 0 sur 3
  - **Carte** : Original à rapporter | Pharmacie Démo · avant demain 10 h 31, à ton prochain passage
  - **Ligne** : Invite un coursier | 2 courses offertes après sa première livraison → COU-15
  - **Ligne** : Nouvelle course près de toi → COU-9

*Règles* : section 11.10 ; HON-44 et HON-58.

### COU-9 · Proposition de course

Maquette : `Coursier-9-Proposition` · « Coursiers · 9. Proposition de course »

*Rôle* : accepter ou passer une course.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-8
  - **Titre** : Nouvelle course
  - **Texte** : Réponds dans 30 secondes
- **Illustration** : Carte : retrait à la pharmacie, puis livraison à Bè-Kpota
- **Contenu**
  - **Texte** : 1 000 FCFA | 24
  - **Puce** : Proposée d’abord à toi : Pharmacie Démo t’a invité
  - **Carte** : Retrait : Pharmacie Démo | Tokoin · à 0,8 km de toi | Livraison : Bè-Kpota | 2,1 km après le retrait · Afi
  - **Texte** : Payée par l’officine sur ton Flooz. Il te restera 2 courses d’essai.
- **Pied d’écran**
  - **Bouton secondaire** : Passer → COU-8
  - **Bouton vert** : Accepter → COU-10

*Règles* : HON-45 et HON-58 ; hors de l’écran du mode coursier, la même proposition s’affiche en plein écran (COU-27).

### COU-27 · Course reçue pendant une discussion

Maquette : `Coursier-27-Course-en-discussion` · « Coursiers · 27. Course reçue pendant une discussion »

*Rôle* : proposer une course à un coursier disponible qui se sert d’une autre partie de l’application.

**Disposition et textes**

- **Fond** : dégradé sombre plein écran
- **Texte** : Nouvelle course · mode coursier
- **Carte** : [24 secondes pour répondre]
- **Titre** : 1 000 FCFA
- **Texte** : payés par l’officine sur ton Flooz
- **Carte** : Retrait : Pharmacie Démo | Tokoin · à 0,8 km de toi | Livraison : Bè-Kpota | 2,1 km après le retrait
- **Puce** : Il te restera 2 courses d’essai
- **Texte** : Tu étais dans une discussion : tu y reviens après ta réponse.
- **Rangée**
  - **Tuile** : Passer → APP-2
  - **Tuile** : Accepter → COU-10

*Règles* : HON-45 et HON-58 ; application fermée, la notification « Nouvelle course disponible près de toi » (section 16.1) ouvre COU-9.

### COU-10 · Livraison

Maquette : `Coursier-10-Livraison` · « Coursiers · 10. Livraison »

*Rôle* : livrer le patient.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-8
  - **Titre** : Livraison à Afi
  - **Texte** : Colis retiré à 10 h 20 · 1,2 km restants
- **Illustration** : Carte : trajet du coursier de la pharmacie jusqu’à toi
- **Contenu**
  - **Encadré vert** : Ta position est partagée avec Afi et l’officine jusqu’à la remise.
  - **Carte** : Bè-Kpota, rue des Cocotiers | Repère : portail bleu face au kiosque | Appeler Afi | Appel relayé par Pokou, numéro masqué
  - **Grille de 2**
    - **Bouton secondaire** : Itinéraire
    - **Bouton principal** : Saisir le code → COU-11
  - **Ligne** : Un problème pendant la course ? → COU-19

*Règles* : HON-02, HON-08 et HON-46.

### COU-19 · Un problème ?

Maquette : `Coursier-19-Incident` · « Coursiers · 19. Un problème pendant la course »

*Rôle* : aider le coursier quand la remise se passe mal.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-10
  - **Titre** : Un problème ?
  - **Texte** : Livraison à Afi · Bè-Kpota
- **Contenu**
  - **Choix** : ◉ | Afi ne répond pas | Pokou l’appelle et la prévient. Attends 10 minutes sur place.
  - **Choix** : ○ | Adresse introuvable | Afi reçoit ta position et peut te guider par message
  - **Choix** : ○ | Le code est refusé | Vérifie les 4 chiffres avec Afi, puis réessaie
  - **Choix** : ○ | Accident ou panne | L’officine est prévenue et la course est réattribuée
  - **Encadré ambre** : Attente sur place | 6 min sur 10 | [barre 60%] | Sans réponse à 10 min, tu rapportes le colis fermé à Pharmacie Démo. Ce n’est pas un défaut pour toi.
- **Pied d’écran**
  - **Bouton secondaire** : Rappeler Afi, numéro masqué
  - **Bouton principal** : Rapporter le colis à l’officine → COU-8

*Règles* : HON-50 ; ouvert depuis « Un problème pendant la course ? » sur COU-10.

### COU-11 · Code de remise

Maquette : `Coursier-11-Code` · « Coursiers · 11. Code de remise »

*Rôle* : clore la livraison.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-10
  - **Titre** : Code de remise
  - **Texte** : Livraison à Afi · Bè-Kpota
- **Contenu**
  - **Texte** : Demande le code à Afi : il s’affiche dans son application. Saisis-le quand tu lui remets le colis.
  - **Texte** : 4 | 8 | 2 | 7
  - **Texte** : 5 essais au maximum. Chaque essai est enregistré.
  - **Carte** : Après la remise : la course est décomptée de ton essai, et Pharmacie Démo te paie 1 000 FCFA sur ton Flooz. Tu confirmes la réception dans le mode coursier.
- **Pied d’écran**
  - **Bouton principal** : Valider la remise → COU-8

*Règles* : section 11.1 ; BM-07.

### COU-12 · Fin de l’essai

Maquette : `Coursier-12-Fin-essai` · « Coursiers · 12. Fin de l’essai »

*Rôle* : proposer le bon pack au bon moment.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-8
  - **Titre** : Ton essai est terminé
- **Contenu**
  - **Encadré vert**
    - **Texte** : Ce mois-ci avec Pokou
    - **Texte** : 5 000 FCFA gagnés
    - **Texte** : 5 courses livrées · 0 défaut
  - **Texte** : À ton rythme, environ 18 courses par mois. Le pack qui te convient :
  - **Encadré terracotta clair**
    - **Texte** : Oseï Tutu · 20 courses | Recommandé
    - **Texte** : Adhésion et pack : 3 068 FCFA TTC par mois
    - **Texte** : Net estimé : 14 932 FCFA pour 18 courses
  - **Carte** : Pokou Vi · 10 courses | Trop juste à ton rythme | 2 242 FCFA TTC | Queen Pokou · illimité | Débloqué : aucun défaut ce mois-ci | 4 720 FCFA TTC
- **Pied d’écran**
  - **Bouton principal** : Choisir Oseï Tutu → COU-13
  - **Ligne** : Voir tous les packs → COU-13

*Règles* : HON-44 ; sert aussi à la fin du lancement, pour les coursiers qui ont livré pendant celui-ci (HON-39).

### COU-13 · Adhésion et pack

Maquette : `Coursier-13-Payer` · « Coursiers · 13. Adhésion et pack »

*Rôle* : choisir et payer le mois.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-12
  - **Titre** : Win Pokou
  - **Texte** : Adhésion et pack de décembre
- **Contenu**
  - **Carte**
    - **Choix** : ○ | ABLAVI 1er | · 5 courses | Le prix exact de 10 % des courses | 500 HT | 590 TTC
    - **Choix** : ○ | Pokou Vi | · 10 courses | 1 course offerte | 900 HT | 1 062 TTC
    - **Choix** : ◉ | Oseï Tutu | · 20 courses | 4 courses offertes | 1 600 HT | 1 888 TTC
    - **Choix** : ○ | Queen Pokou | · illimité | Prix de 30 courses | Débloqué : aucun défaut le mois dernier | 3 000 HT | 3 540 TTC
  - **Carte**
    - **Texte** : Adhésion Win Pokou | 1 180 FCFA TTC
    - **Texte** : Pack Oseï Tutu | 1 888 FCFA TTC
    - **Texte** : Total à payer | 3 068 FCFA TTC
  - **Carte** : Les courses non utilisées sont perdues en fin de mois et les packs ne se cumulent pas. Tu peux passer au pack supérieur à tout moment en payant la différence.
- **Pied d’écran**
  - **Bouton principal** : Payer 3 068 FCFA par CashPay → COU-8

*Règles* : section 4.2 ; HON-44 ; BM-07.

### COU-14 · Pack épuisé

Maquette : `Coursier-14-Pack-epuise` · « Coursiers · 14. Pack épuisé »

*Rôle* : ne pas perdre une course faute de courses dans le pack.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-8
  - **Titre** : Nouvelle course
  - **Texte** : Réponds dans 30 secondes
- **Illustration** : Carte : trajet du coursier de la pharmacie jusqu’à toi
- **Contenu**
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Texte** : Ton pack Pokou Vi est épuisé
  - **Texte** : Cette course te rapporte 1 000 FCFA. Passe à Oseï Tutu en payant seulement la différence et accepte-la.
  - **Carte**
    - **Texte** : Différence Pokou Vi → Oseï Tutu | 700 FCFA HT
    - **Texte** : À payer | 826 FCFA TTC
    - **Texte** : Courses en plus ce mois-ci | 10
  - **Bouton principal** : Passer à Oseï Tutu · 826 FCFA → COU-10
  - **Ligne** : Laisser passer cette course → COU-8

*Règles* : HON-44 ; BM-07.

### COU-20 · Défaut signalé

Maquette : `Coursier-20-Defaut` · « Coursiers · 20. Défaut signalé »

*Rôle* : informer le coursier d’un défaut et lui permettre de le contester.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-8
  - **Titre** : Défaut signalé
- **Contenu**
  - **Texte** : Pharmacie Démo a signalé un retard important sur la course du 28 oct.
  - **Texte** : Défauts en cours | 1 sur 3 | Contestation | Jusqu’au 30 oct. | à 12 h 40
  - **Carte** : Ce qu’a écrit l’officine | « Livré à 12 h 40 au lieu de 10 h 30, sans appel au patient. »
  - **Carte** : Si tu contestes, le support compare l’heure de retrait, ta position pendant la course et les appels passés par Pokou.
  - **Encadré ambre** : Au 3e défaut confirmé, ton compte coursier est suspendu.
- **Pied d’écran**
  - **Bouton principal** : J’ai compris → COU-8
  - **Ligne** : Contester ce défaut

*Règles* : HON-05 et HON-49 ; contestation sous 48 h (annexe B, n° 10).

### COU-21 · Compte coursier suspendu

Maquette : `Coursier-21-Suspendu` · « Coursiers · 21. Compte coursier suspendu »

*Rôle* : expliquer la suspension et le recours.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-6
  - **Titre** : Compte coursier suspendu
- **Contenu**
  - **Texte** : Tu as reçu 3 défauts confirmés. Tu ne reçois plus de courses.
  - **Liste**
    - **Élément** : 4 nov. | Retard important · Pharmacie Démo
    - **Élément** : 12 nov. | Original non rapporté · Pharmacie du Marché
    - **Élément** : 19 nov. | Colis ouvert · Pharmacie Démo
  - **Carte** : Tu peux demander un réexamen au support. Pendant ce temps, tes discussions, Kory et tes commandes Honam restent accessibles.
  - **Texte** : La suspension ne touche que le mode coursier, pas ton compte Pokou.
- **Pied d’écran**
  - **Bouton principal** : Demander un réexamen
  - **Ligne** : Retour à Pokou → APP-1

*Règles* : BM-05 et HON-49 ; texte « Coursier suspendu » de la section 16.

### COU-22 · Mes courses et gains

Maquette : `Coursier-22-Historique-gains` · « Coursiers · 22. Courses et gains »

*Rôle* : suivre ses courses, ses gains et leur paiement.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → COU-8
  - **Titre** : Mes courses et gains
- **Contenu**
  - **Encadré beige**
    - **Filtre (sélectionné)** : Novembre
    - **Filtre** : Octobre
  - **Texte** : Courses | 12 | Gains | 12 000 | FCFA | Défauts | 0 sur 3
  - **Encadré ambre** : Pack Oseï Tutu | 8 courses restantes sur 20 | [barre 60%]
  - **Liste**
    - **Élément** : Pharmacie Démo › Bè-Kpota | Aujourd’hui, 10:31 | 1 000 FCFA | Payée
    - **Élément** : Pharmacie du Marché › Tokoin | Hier, 17:02 | 1 000 FCFA | En attente
    - **Élément** : Pharmacie Démo › Amoutivé | 2 nov., 11:48 | 1 000 FCFA | Payée
    - **Élément** : Pharmacie Démo › Bè | 2 nov., 09:15 | 1 000 FCFA | Payée
  - **Texte** : Chaque officine te paie la course sur ton wallet Flooz 96 •• •• 34. Un paiement en retard se signale depuis la course.

*Règles* : HON-09, HON-44 et HON-55 ; Pokou ne prélève rien sur les courses.

## 11.12 Suivi de la course sur une carte

### SUI-1 · Suivi sur la carte

Maquette : `Honam-Suivi-carte` · « Honam · Suivi sur la carte »

*Rôle* : pour le patient, voir arriver le coursier.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Titre** : Pharmacie Démo · Honam
  - **Texte** : Commande en livraison
  - **Bouton icône** : Détails de la commande → APP-4
- **Illustration** : Carte : trajet du coursier de la pharmacie jusqu’à toi
- **Contenu**
  - **Carte**
    - **Rangée**
      - **Avatar** : KA
      - **Texte** : Kodjo arrive dans 6 min
      - **Texte** : Coursier vérifié · moto · à 1,2 km
      - **Bouton icône** : Appeler Kodjo, numéro masqué
  - **Encadré ambre**
    - **Texte** : Ton code de remise
    - **Texte** : 4827
    - **Texte** : Donne-le seulement à Kodjo, quand il te remet le colis.
  - **Lien** : Suivre sans la carte → SUI-2

*Règles* : HON-08 et HON-46 ; carte masquée dès la saisie du code.

### SUI-2 · Suivi sans carte

Maquette : `Honam-Suivi-leger` · « Honam · Suivi sans carte »

*Rôle* : suivre presque sans données.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → APP-2
  - **Titre** : Pharmacie Démo · Honam
  - **Texte** : Commande en livraison
  - **Bouton icône** : Détails de la commande → APP-4
- **Contenu**
  - **Carte**
    - **Texte** : Kodjo arrive vers 10 h 31
    - **Texte** : À 1,2 km · mis à jour il y a 20 s
    - **Indicateur** : [barre]
    - **Indicateur** : [barre]
    - **Texte** : Pharmacie
    - **Texte** : Chez toi
  - **Carte**
    - **Rangée**
      - **Avatar** : KA
      - **Texte** : Kodjo A.
      - **Texte** : Coursier vérifié · moto · à 1,2 km
      - **Bouton icône** : Appeler Kodjo, numéro masqué
  - **Encadré ambre**
    - **Texte** : Ton code de remise
    - **Texte** : 4827
    - **Texte** : Donne-le seulement à Kodjo, quand il te remet le colis.
  - **Carte** : Suivi léger, presque sans données : la carte se charge seulement si tu la demandes. C’est le mode par défaut avec l’économie de données.
  - **Bouton secondaire** : Afficher la carte → SUI-1

*Règles* : HON-46 ; mode par défaut avec l’économie de données (MSG-19).

### OFF-7 · Suivi de la livraison

Maquette : `Officine-7-Suivi` · « Officine · 7. Suivi de la livraison »

*Rôle* : pour l’officine, suivre la course jusqu’à la remise.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux commandes → OFF-4
  - **Titre** : Livraison d’Afi K.
  - **Texte** : Colis remis à Kodjo à 10 h 20
- **Illustration** : Carte : position de Kodjo entre l’officine et l’adresse d’Afi
- **Contenu**
  - **Carte** : [avatar KA] | Kodjo A. · coursier vérifié | À 1,2 km d’Afi · arrivée vers 10 h 31 | Appeler | Écrire
  - **Carte** : Position mise à jour toutes les 15 secondes, visible jusqu’à la saisie du code. Elle n’est pas conservée après la livraison.

*Règles* : HON-08 ; accessible depuis la carte du coursier (OFF-4) ; vouvoiement de l’officine.

## 12.1 Écrans d’Assimé

### ANN-1 · Recherche

Maquette : `Annonce-1-Recherche` · « Assimé · 1. Recherche »

*Rôle* : trouver une annonce.

**Disposition et textes**

- **Rangée**
  - **Bouton icône** : Retour à Assimé → APP-5
  - **Champ** : [champ : pagne]
- **Rangée**
  - **Lien** : Filtres · 2 → ANN-2
  - **Puce** : Lomé · Bè
  - **Puce** : Vendeurs certifiés
  - **Puce** : Prix
- **Texte** : 48 annonces · Mode | Plus récentes
- **Contenu**
  - **Grille de 4**
    - **Vignette** : [icône : Photo de l’annonce] | Sponsorisé | 12 000 FCFA | Pagne wax 6 yards, motif calebasse | Bè · aujourd’hui | Boutique Mensah → ANN-3
    - **Vignette** : [icône : Photo de l’annonce] | Sponsorisé | 35 000 FCFA | Pagne kente tissé main | Tokoin · aujourd’hui | Couture Délali → ANN-3
    - **Vignette** : [icône : Photo de l’annonce] | 25 000 FCFA | Sac en pagne tissé | Bè · hier | Ama S. → ANN-3
    - **Vignette** : [icône : Photo de l’annonce] | 8 000 FCFA | Robe en pagne, taille M | Amoutivé · 28/10 | Kossi M. → ANN-3

*Règles* : ASM-02, ASM-08 et BM-14 ; au plus 2 annonces sponsorisées par écran de résultats.

### ANN-2 · Filtres

Maquette : `Annonce-2-Filtres` · « Assimé · 2. Filtres »

*Rôle* : affiner la recherche.

**Disposition et textes**

- **Rangée**
  - **Bouton icône** : Retour à Assimé → APP-5
  - **Champ** : [champ : pagne]
- **Contenu**
  - **Grille de 2**
    - **Vignette** : [icône : Photo de l’annonce] | 12 000 FCFA | Pagne wax 6 yards | Bè · aujourd’hui → ANN-3
    - **Vignette** : [icône : Photo de l’annonce] | 35 000 FCFA | Pagne kente | Tokoin → ANN-3
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Texte** : Filtres | Effacer
  - **Titre de section** : Catégorie
  - **Puces** : Mode (sélectionnée) | Beauté | Maison | Électronique | Véhicules | Services
  - **Titre de section** : Prix
  - **Grille de 2**
    - **Champ** : Minimum = —
    - **Champ** : Maximum = 15 000
  - **Titre de section** : État
  - **Puces** : Neuf (sélectionnée) | Très bon état (sélectionnée) | Bon état | À réparer
  - **Carte**
    - **Texte** : Ville et quartier | Lomé · Bè
    - **Texte** : Publiée | Moins de 7 jours
    - **Interrupteur** : Vendeurs certifiés seulement | Badge Pokou certifié ou Pro | [interrupteur activé]
  - **Bouton principal** : Voir 19 annonces → ANN-1

*Règles* : ASM-02 et ASM-08 ; le nombre de résultats se met à jour à chaque choix.

### ANN-3 · Annonce

Maquette : `Annonce-3-Fiche` · « Assimé · 3. Annonce »

*Rôle* : tout savoir sur l’article et le vendeur.

**Disposition et textes**

- **Illustration** : Photo 1 sur 4 : pagnes wax pliés
- **Rangée**
  - **Bouton icône** : Retour aux résultats → ANN-1
  - **Rangée**
    - **Bouton icône** : Partager l’annonce → ANN-13
    - **Bouton icône** : Ajouter aux favoris
    - **Bouton icône** : Signaler l’annonce → ANN-11
- **Contenu**
  - **Puce** : Sponsorisé
  - **Texte** : 12 000 FCFA
  - **Titre** : Pagne wax 6 yards, motif calebasse
  - **Texte** : Neuf · Marché de Bè, Lomé · aujourd’hui à 08:40
  - **Texte** : Arrivage du matin. Coton imprimé, 6 yards. Autres motifs sur place, allée 4.
  - **Ligne** : [avatar BM] | Boutique Mensah | Géré par Mensah D. · 12 annonces → PRO-5
  - **Carte** : Pokou n’encaisse aucun paiement sur Assimé. Vois l’article avant de payer, dans un lieu public.
- **Pied d’écran**
  - **Bouton icône** : Ajouter aux favoris
  - **Bouton principal** : Contacter le vendeur → ANN-4

*Règles* : ASM-03, ASM-04, ASM-06 et ASM-08 ; aucun numéro affiché.

### ANN-4 · Contacter le vendeur

Maquette : `Annonce-4-Contact` · « Assimé · 4. Contacter le vendeur »

*Rôle* : premier échange avec le vendeur, dans Discussions.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → ANN-3
  - **Avatar** : BM
  - **Titre** : Boutique Mensah
  - **Texte** : Vendeuse Pro
  - **Bouton icône** : Appel audio
  - **Bouton icône** : Options
- **Ligne** : [icône : Photo de l’annonce] | Pagne wax 6 yards, motif calebasse | 12 000 FCFA · Assimé | Voir → ANN-3
- **Contenu**
  - **Carte**
    - **Texte** : Avant d’acheter
    - **Texte** : Retrouve le vendeur dans un lieu public, en journée.
    - **Texte** : Ne paie jamais d’avance : vois l’article d’abord.
    - **Texte** : Pokou n’encaisse aucun paiement et ne te demandera jamais ton code secret.
  - **Texte** : Ton numéro n’est pas montré au vendeur.
- **Pied d’écran**
  - **Puce** : D’autres photos ?
  - **Puce** : Toujours disponible ?
  - **Puce** : Prix négociable ?
- **Carte**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer

*Règles* : ASM-03 et ASM-06 ; côté vendeur, raccourci « Envoyer des photos de l’article » ; les règles des messages d’inconnus s’appliquent aussi (MSG-17).

### ANN-5 · Publier : photos et catégorie

Maquette : `Annonce-5-Photos` · « Assimé · 5. Publier : photos »

*Rôle* : commencer une annonce.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-5
  - **Titre** : Photos et catégorie
  - **Texte** : Publier une annonce · étape 1 sur 3
- **Contenu**
  - **Indicateur** : [barre d’étapes 1/3]
  - **Illustration** : Photo de l’annonce
  - **Puce** : Couverture
  - **Illustration** : Photo de l’annonce
  - **Illustration** : Photo de l’annonce
  - **Carte** : Ajouter
  - **Texte** : 3 photos sur 5. La première sert de couverture. D’autres photos pourront être envoyées dans la discussion avec l’acheteur.
  - **Champ** : Titre = Pagne wax 6 yards, motif calebasse
  - **Carte** : Catégorie | Mode › Pagnes et tissus
  - **Carte** : Ton numéro n’est jamais affiché : les acheteurs t’écrivent sur Pokou.
- **Pied d’écran**
  - **Bouton principal** : Continuer → ANN-6

*Règles* : ASM-01 et ASM-09 ; photos compressées avant l’envoi (MSG-05).

### ANN-6 · Publier : prix, état et lieu

Maquette : `Annonce-6-Details` · « Assimé · 6. Publier : détails »

*Rôle* : décrire l’article.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-5
  - **Titre** : Prix, état et lieu
  - **Texte** : Publier une annonce · étape 2 sur 3
- **Contenu**
  - **Indicateur** : [barre d’étapes 2/3]
  - **Champ** : Prix = 12 000 | FCFA
  - **Carte**
    - **Interrupteur** : Prix à débattre | Le prix s’affiche avec « à débattre » | [interrupteur désactivé]
  - **Titre de section** : État
  - **Puces** : Neuf (sélectionnée) | Très bon état | Bon état | À réparer
  - **Champ** : Description = Arrivage du matin. Coton imprimé, 6 yards. Autres motifs sur place, allée 4.
  - **Carte** : Ville et quartier | Lomé · Bè
- **Pied d’écran**
  - **Bouton principal** : Voir l’aperçu → ANN-7

*Règles* : ASM-01.

### ANN-7 · Publier : aperçu

Maquette : `Annonce-7-Apercu` · « Assimé · 7. Publier : aperçu »

*Rôle* : vérifier avant de publier.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-6
  - **Titre** : Aperçu
  - **Texte** : Publier une annonce · étape 3 sur 3
- **Contenu**
  - **Indicateur** : [barre d’étapes 3/3]
  - **Grille de 2**
    - **Vignette** : [icône : Photo de l’annonce] | 12 000 FCFA | Pagne wax 6 yards, motif calebasse | Bè · maintenant | Boutique Mensah → ANN-3
    - **Texte** : Ce que verront les acheteurs, avec ton badge Pro.
    - **Texte** : En ligne 30 jours, puis l’annonce expire ; tu peux la renouveler.
  - **Carte**
    - **Case à cocher** : ☑ | Mon annonce ne contient ni médicament, ni arme, ni contrefaçon, ni animal protégé.
  - **Carte**
    - **Interrupteur** : Mettre en avant | Dès 600 FCFA pour 3 jours, en tête des résultats | [interrupteur désactivé]
- **Pied d’écran**
  - **Bouton principal** : Publier l’annonce → ANN-9

*Règles* : ASM-05, ASM-09, ASM-10 et BM-14.

### ANN-8 · Produit interdit

Maquette : `Annonce-8-Interdit` · « Assimé · 8. Produit interdit »

*Rôle* : arrêter une annonce interdite et orienter.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-5
  - **Titre** : Photos et catégorie
  - **Texte** : Publier une annonce · étape 1 sur 3
- **Contenu**
  - **Indicateur** : [barre d’étapes 1/3]
  - **Champ** : Titre = Paracétamol 500 mg, boîte de 16
  - **Encadré rouge** : Les médicaments ne se vendent pas sur Assimé | Pour un médicament, passe par Honam : une pharmacie te fait un devis et un coursier te livre.
  - **Bouton secondaire** : Aller sur Honam → APP-4
  - **Titre de section** : Aussi interdits sur Assimé
  - **Carte**
    - **Élément** : Armes et munitions
    - **Élément** : Contrefaçons
    - **Élément** : Animaux protégés
- **Pied d’écran**
  - **Bouton principal** : Changer d’article → ANN-5

*Règles* : ASM-05 et ASM-09.

### ANN-9 · Mes annonces

Maquette : `Annonce-9-Mes-annonces` · « Assimé · 9. Mes annonces »

*Rôle* : gérer ses annonces.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-5
  - **Titre** : Mes annonces
  - **Texte** : Boutique Mensah · 12 annonces
- **Puces** : En ligne · 10 (sélectionnée) | Vendues · 25 | Expirées · 2
- **Contenu**
  - **Carte**
    - **Texte** : [icône : Photo de l’annonce] | Pagne wax 6 yards, motif calebasse | 12 000 FCFA | 214 vues · 18 favoris · 6 messages | Sponsorisée · 5 j
    - **Groupe de puces**
      - **Puce** : Marquer vendue → ANN-18
      - **Puce** : Modifier → ANN-22
  - **Carte**
    - **Texte** : [icône : Photo de l’annonce] | Pagne kente tissé main | 35 000 FCFA | 96 vues · 7 favoris · 2 messages | Expire dans 3 jours
    - **Groupe de puces**
      - **Puce (sélectionnée)** : Renouveler
      - **Puce** : Mettre en avant → ANN-10
  - **Carte**
    - **Texte** : [icône : Photo de l’annonce] | Sac en pagne tissé | 25 000 FCFA | 51 vues · 4 favoris · 1 message | En ligne
    - **Groupe de puces**
      - **Puce** : Mettre en avant
      - **Puce** : Marquer vendue → ANN-18
  - **Texte** : Les vues et les favoris ne sont visibles que de toi.
- **Pied d’écran**
  - **Bouton principal** : Publier une annonce → ANN-5

*Règles* : ASM-04 et ASM-10 ; statistiques visibles du seul vendeur.

### ANN-10 · Mettre en avant

Maquette : `Annonce-10-Mise-en-avant` · « Assimé · 10. Mettre en avant : 3 ou 7 jours »

*Rôle* : acheter de la visibilité.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-9
  - **Titre** : Mettre en avant
  - **Texte** : Pagne kente tissé main · 35 000 FCFA
- **Contenu**
  - **Choix** : ○ | 3 jours | 600 FCFA | En tête des résultats de sa catégorie, dans sa ville
  - **Choix** : ◉ | 7 jours | 1 300 FCFA | En tête des résultats de sa catégorie, dans sa ville | Une place parmi les statuts des acheteurs de ta ville | Moins cher par jour · badge payant requis pour les statuts
  - **Texte** : Prix TTC. Ton annonce porte la mention « Sponsorisé ». Pas de renouvellement automatique.
  - **Carte**
    - **Texte** : Début | Dès la validation
    - **Texte** : Fin | Samedi 7 nov. à 10:12
    - **Texte** : Paiement | CashPay · mobile money
  - **Carte** : La place en statut est vérifiée par la modération avant la diffusion. Si elle est refusée, la mise en avant t’est remboursée. Une catégorie interdite ne peut jamais être mise en avant.
- **Pied d’écran**
  - **Bouton principal** : Payer 1 300 FCFA par CashPay → ANN-17

*Règles* : ASM-07, ASM-14 et BM-14 ; place en statut réservée aux titulaires d’un badge payant ; pas de renouvellement automatique.

### ANN-11 · Signaler une annonce

Maquette : `Annonce-11-Signaler` · « Assimé · 11. Signaler »

*Rôle* : alerter la modération.

**Disposition et textes**

- **Illustration** : Photo de l’annonce
- **Contenu**
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Titre de section** : Signaler l’annonce
  - **Carte**
    - **Choix** : ◉ | Arnaque ou paiement demandé d’avance
    - **Choix** : ○ | Produit interdit | Médicament, arme, animal protégé…
    - **Choix** : ○ | Contrefaçon
    - **Choix** : ○ | Annonce trompeuse ou déjà vendue
    - **Choix** : ○ | Autre
  - **Carte** : Le vendeur n’est pas prévenu de ton signalement. Une annonce signalée plusieurs fois est masquée en attendant la revue.
  - **Bouton rouge** : Envoyer le signalement
  - **Ligne** : Annuler → ANN-3

*Règles* : ASM-05 et ASM-12.

### ANN-12 · Favoris et alertes

Maquette : `Annonce-12-Favoris` · « Assimé · 12. Favoris et alertes »

*Rôle* : retrouver ses annonces et recherches.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-5
  - **Titre** : Favoris et alertes
- **Contenu**
  - **Titre de section** : Recherches enregistrées
  - **Carte** : « pagne wax » · Bè · moins de 15 000 FCFA | 3 nouvelles annonces depuis hier | [interrupteur activé] | « téléphone » · Lomé · vendeurs certifiés | Alerte coupée | [interrupteur désactivé]
  - **Titre de section** : Annonces favorites
  - **Grille de 2**
    - **Vignette** : [icône : Photo de l’annonce] | 12 000 FCFA | Pagne wax 6 yards, motif calebasse | Bè · aujourd’hui | Boutique Mensah → ANN-3
    - **Vignette** : [icône : Photo de l’annonce] | ~~45 000 FCFA~~ | Téléphone reconditionné | Tokoin · Vendu | Kossi M. → ANN-3
  - **Texte** : Une alerte t’envoie au plus une notification par jour.

*Règles* : ASM-04 et ASM-13.

### ANN-13 · Partager une annonce

Maquette : `Annonce-13-Partager` · « Assimé · 13. Partager »

*Rôle* : faire circuler une annonce, notamment en statut.

**Disposition et textes**

- **Illustration** : Photo de l’annonce
- **Contenu**
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Titre de section** : Partager l’annonce
  - **Grille de 4**
    - **Tuile** : Mon statut → STA-1
    - **Tuile** : Une discussion
    - **Tuile** : Copier le lien
    - **Tuile** : Autres applis
  - **Carte** : Aperçu en statut | [icône : Photo de l’annonce] | Pagne wax 6 yards · 12 000 FCFA | Voir l’annonce sur Assimé
  - **Carte** : Hors de Pokou, le lien ouvre un aperçu limité : photo, titre, prix et quartier. Pour écrire au vendeur, il faut Pokou.
  - **Ligne** : Fermer → ANN-3

*Règles* : ASM-11 ; le statut affiche « Voir l’annonce » (STA-2).

### ANN-14 · Statut sponsorisé dans la bande

Maquette : `Annonce-14-Statuts-sponsorises` · « Assimé · 14. Statut sponsorisé dans la bande »

*Rôle* : montrer à l’acheteur où apparaît une annonce sponsorisée parmi les statuts.

**Disposition et textes**

- **En-tête**
  - **Rangée**
    - **Texte** : [image : pokou-bulles] | [image : Pokou]
    - **Bouton icône** : Rechercher un contact, un groupe ou un message → DIS-22
    - **Bouton icône** : Nouvelle discussion → DIS-5
  - **Titre** : Discussions
- **Bande horizontale**
  - **Tuile** : [avatar AK] | Mon statut → STA-3
  - **Ligne** : [avatar MD] | Mensah D. → STA-2
  - **Ligne** : [avatar EK] | Edem K. → STA-1
  - **Tuile** : Sponsorisé → ANN-15
  - **Ligne** : [avatar KK] | Kafui K. → STA-1
- **Rangée**
  - **Filtre (sélectionné)** : Toutes
  - **Filtre** : Non lues · 3
  - **Filtre** : Favoris
  - **Filtre** : Groupes
- **Contenu**
  - **Liste**
    - **Ligne** : Archivées | 2 → DIS-12
    - **Ligne** : Baba | [intelligence artificielle] | Pose-moi une question sur Pokou, Kory ou Honam. | [icône : Épinglée] → INS-4
    - **Ligne** : [avatar FK] | Famille Koffi | Maman : On se voit dimanche ? | Cagnotte en cours | 17:35 | [icône : Épinglée] | [pastille 2] → DIS-1
    - **Ligne** : [avatar AS] | Ama S. | On se retrouve samedi ? | 16:05 | [pastille 1] → APP-2b
    - **Ligne** : [avatar CB] | Collègues du bureau | Toi : Merci Yao, je note pour lundi. | Mode preuve | 14:36 → PRV-5
    - **Ligne** : [avatar KA] | Kodjo A. | Toi : Je vois encore ton message. On en reparle ce soir. | Mode preuve | 10:23 → PRV-5b
    - **Ligne** : Pharmacie Démo · Honam | Ton devis est prêt : 5 600 FCFA | Hier → APP-4
    - **Élément** : [avatar AB] | Les Amis de Bè | Réunion samedi à 16 h | 24/10
- **Barre d’onglets** : Accueil / Discussions (actif) / Kory / Honam / Plus

*Règles* : ASM-14 ; jamais en première position ; jamais dans une discussion.

### ANN-15 · Voir un statut sponsorisé

Maquette : `Annonce-15-Statut-sponsorise` · « Assimé · 15. Voir un statut sponsorisé »

*Rôle* : découvrir l’annonce comme un statut.

**Disposition et textes**

- **Fond** : voile sombre sur l’écran
- **Illustration** : Photo : pagne kente tissé main
- **Rangée**
  - **Bouton icône** : Fermer → ANN-14
  - **Avatar** : CD
  - **Texte** : Couture Délali
  - **Puce** : Sponsorisé
  - **Bouton icône** : Pourquoi je vois ça et options → ANN-16
- **Texte** : Pagne kente tissé main · 35 000 FCFA
- **Texte** : Tokoin, Lomé · annonce Assimé
- **Grille de 2**
  - **Ligne** : Voir l’annonce → ANN-3
  - **Bouton secondaire** : Écrire → ANN-4
- **Texte** : Passe au statut suivant en touchant à droite.

*Règles* : ASM-14 ; au plus un statut sponsorisé tous les 5 statuts.

### ANN-16 · Pourquoi je vois cette annonce ?

Maquette : `Annonce-16-Pourquoi` · « Assimé · 16. Pourquoi je vois ça »

*Rôle* : expliquer et laisser le contrôle à l’acheteur.

**Disposition et textes**

- **Fond** : voile sombre sur l’écran
- **Illustration** : Photo : pagne kente tissé main
- **Rangée**
  - **Bouton icône** : Fermer → ANN-14
  - **Avatar** : CD
  - **Texte** : Couture Délali
  - **Puce** : Sponsorisé
  - **Bouton icône** : Pourquoi je vois ça et options → ANN-16
- **Texte** : Pagne kente tissé main · 35 000 FCFA
- **Texte** : Tokoin, Lomé · annonce Assimé
- **Grille de 2**
  - **Ligne** : Voir l’annonce → ANN-3
  - **Bouton secondaire** : Écrire → ANN-4
- **Texte** : Passe au statut suivant en touchant à droite.
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Titre de section** : Pourquoi je vois cette annonce ?
  - **Texte** : Couture Délali, vendeuse Pokou certifié Pro, a payé pour la montrer aux acheteurs de Lomé. Tu la vois parce que tu es à Lomé.
  - **Carte** : Pokou ne lit jamais tes messages ni tes statuts pour choisir les annonces. Au plus un statut sponsorisé tous les 5 statuts.
  - **Carte**
    - **Élément** : Masquer cette annonce
    - **Élément** : Ne plus voir les annonces de ce vendeur
    - **Élément** : Signaler l’annonce
  - **Ligne** : Fermer → ANN-15

*Règles* : ASM-12 et ASM-14.

### ANN-17 · Bilan de la mise en avant

Maquette : `Annonce-17-Bilan` · « Assimé · 17. Bilan de la mise en avant »

*Rôle* : montrer au vendeur ce que lui rapporte la mise en avant.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-9
  - **Titre** : Mise en avant en cours
  - **Texte** : Pagne kente tissé main · 7 jours
- **Contenu**
  - **Encadré ambre** : Jour 3 sur 7 | fin samedi 7 nov. à 10:12 | [barre 43%]
  - **Texte** : Vues dans les résultats
  - **Texte** : 1 240
  - **Texte** : Vues en statut
  - **Texte** : 860
  - **Texte** : « Voir l’annonce »
  - **Texte** : 96
  - **Texte** : Messages reçus
  - **Texte** : 14
  - **Texte** : contre 2 avant
  - **Carte**
    - **Texte** : Vues par jour
    - **Texte** : Dim. | Lun. | Mar. | Mer. | Jeu.
    - **Texte** : Résultats | Statuts
  - **Texte** : Ces chiffres ne sont visibles que de toi. Pas de renouvellement automatique : tu choisiras à la fin.
- **Pied d’écran**
  - **Bouton principal** : Voir l’annonce → ANN-3

*Règles* : ASM-10 et BM-14 ; chiffres visibles du seul vendeur ; pas de renouvellement automatique.

*Vente conclue, note de l’acheteur et avis*

### ANN-18 · Marquer comme vendue

Maquette : `Annonce-18-Marquer-vendue` · « Assimé · 18. Marquer comme vendue »

*Rôle* : clore une vente et désigner l’acheteur.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-9
  - **Titre** : Marquer comme vendue
  - **Texte** : Pagne wax 6 yards, motif calebasse
- **Contenu**
  - **Texte** : À qui l’as-tu vendue ? Cette personne pourra noter la transaction.
  - **Choix** : ◉ | Afi K. | Discussion du 3 nov. · « Je passe à 11 h »
  - **Choix** : ○ | Kossi M. | Discussion du 1er nov.
  - **Choix** : ○ | Yawa K. | Discussion du 30 oct.
  - **Choix** : ○ | Quelqu’un hors de Pokou | Pas de note possible pour cette vente
  - **Champ** : Prix final = 11 500 | FCFA | Visible seulement de toi et de l’acheteur
- **Pied d’écran**
  - **Bouton principal** : Confirmer la vente → ANN-9

*Règles* : ASM-04 et ASM-15.

### ANN-24 · Invitation à noter

Maquette : `Annonce-24-Invitation-noter` · « Assimé · 19. Invitation à noter »

*Rôle* : inviter l’acheteur à noter, dans la discussion liée à l’annonce.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour aux discussions → ANN-3
  - **Avatar** : BM
  - **Titre** : Boutique Mensah
  - **Texte** : Vendeuse Pro
  - **Bouton icône** : Appel audio
- **Ligne** : [icône : Pagne wax] | Pagne wax 6 yards, motif calebasse | 12 000 FCFA · Assimé | Voir → ANN-3
- **Contenu**
  - **Repère** : 3 nov.
  - **Bulle envoyée** : Bonjour, il est toujours disponible ? Je peux passer demain. | 18:02 · Lu
  - **Bulle reçue** : Oui, je vous le garde. Allée 4, à partir de 8 h. | 18:05
  - **Bulle envoyée** : Je passe à 11 h. Vous me faites 11 500 ? | 18:06 · Lu
  - **Bulle reçue** : D’accord pour 11 500. | 18:07
  - **Repère** : Aujourd’hui
  - **Encadré ambre**
    - **Texte** : Boutique Mensah a indiqué que tu as acheté cet article pour 11 500 FCFA.
    - **Bouton principal** : Noter la transaction → ANN-19
- **Pied d’écran**
  - **Bouton icône** : Joindre un fichier
  - **Champ** : [champ : « Écrire un message… »]
  - **Bouton icône** : Enregistrer une note vocale
  - **Bouton icône** : Envoyer

*Règles* : ASM-03 et ASM-16.

### ANN-19 · Noter la transaction

Maquette : `Annonce-19-Noter` · « Assimé · 20. Noter la transaction »

*Rôle* : noter le vendeur après une vente confirmée.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-24
  - **Titre** : Noter la transaction
  - **Texte** : Boutique Mensah · pagne wax
- **Contenu**
  - **Carte** : Comment s’est passée ta transaction ? | [4 étoiles sur 5] | Très bien
  - **Titre de section** : Ce qui s’est bien passé
  - **Puces** : Conforme à l’annonce (sélectionnée) | Ponctuelle (sélectionnée) | Prix respecté (sélectionnée) | Aimable | Bonne communication
  - **Champ** : Ton avis (facultatif) = Tissu de belle qualité, rendez-vous respecté.
  - **Carte** : Ton avis s’affiche avec ton prénom et l’initiale de ton nom. Seule une vente confirmée par le vendeur peut être notée, une seule fois.
- **Pied d’écran**
  - **Bouton principal** : Publier mon avis → ANN-20

*Règles* : ASM-16 ; le lecteur d’écran annonce la note (« 5 étoiles sur 5 »).

### ANN-20 · Avis sur le vendeur

Maquette : `Annonce-20-Avis` · « Assimé · 21. Avis sur le vendeur »

*Rôle* : voir les avis d’un vendeur.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → PRO-5
  - **Titre** : Avis sur Boutique Mensah
  - **Texte** : Vendeuse Pro · 37 ventes notées
- **Contenu**
  - **Carte** : 4,8 | 5 | [barre 81%] | 30 | 4 | [barre 14%] | 5 | 3 | [barre 3%] | 1 | 2 | [barre 3%] | 1 | 1 | [barre 0%] | 0 | Conforme à l’annonce · 31 | Ponctuelle · 24
  - **Liste**
    - **Élément** : [avatar AK] | Afi K. | Aujourd’hui | [4 étoiles sur 5] | Tissu de belle qualité, rendez-vous respecté.
    - **Élément** : [avatar EK] | Edem K. | 28 oct. | [5 étoiles sur 5] | Très bon accueil au marché, je recommande.
    - **Élément** : [avatar YK] | Yawa K. | 21 oct. | [3 étoiles sur 5] | Un peu d’attente, mais l’article était conforme. | Réponse de Boutique Mensah : Merci Yawa, c’était un jour d’arrivage. À bientôt !
  - **Lien** : Signaler un avis → ANN-11

*Règles* : ASM-17.

### ANN-21 · Profil d’un particulier

Maquette : `Annonce-21-Profil-vendeur` · « Assimé · 22. Profil d’un vendeur particulier »

*Rôle* : présenter un vendeur particulier.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-1
  - **Titre** : Profil
- **Contenu**
  - **Avatar** : KM
  - **Texte** : Kossi M.
  - **Texte** : Particulier · sur Pokou depuis août 2026
  - **Texte** : 4,6 | · 8 ventes notées · Amoutivé
  - **Grille de 2**
    - **Bouton secondaire** : Message → ANN-4
    - **Bouton secondaire** : Signaler → ANN-11
  - **Titre de section** : Annonces de Kossi · 2
  - **Grille de 2**
    - **Vignette** : [icône : Robe en pagne, taille M] | 8 000 FCFA | Robe en pagne, taille M | Amoutivé · 28/10 → ANN-3
    - **Vignette** : [icône : Téléphone reconditionné] | Vendu | 45 000 FCFA | Téléphone reconditionné | Tokoin · 15/10 → ANN-3
  - **Texte** : Le badge montre un nom vérifié par Pokou certifié. Un particulier n’a pas de badge Pro.

*Règles* : ASM-08 et ASM-17 ; aucun numéro affiché (ASM-03).

### ANN-22 · Modifier l’annonce

Maquette : `Annonce-22-Modifier` · « Assimé · 23. Modifier l’annonce »

*Rôle* : modifier une annonce en ligne.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → ANN-9
  - **Titre** : Modifier l’annonce
- **Contenu**
  - **Texte** : [icône : Photo de l’annonce] | [icône : Photo de l’annonce] | [icône : Photo de l’annonce] | 3 / 5
  - **Champ** : Titre = Pagne kente tissé main
  - **Grille de 2**
    - **Champ** : Prix = 35 000 | FCFA
    - **Champ** : Catégorie = Mode
  - **Case à cocher** : ☑ | Prix négociable
  - **Texte** : État
  - **Puces** : Neuf (sélectionnée) | Très bon état | Bon état
  - **Champ** : Quartier = Tokoin, Lomé
- **Pied d’écran**
  - **Bouton principal** : Enregistrer les modifications → ANN-9
  - **Ligne** : Supprimer l’annonce → ANN-23

*Règles* : ASM-01, ASM-09 (produits interdits contrôlés à chaque modification) et ASM-18.

### ANN-23 · Supprimer l’annonce

Maquette : `Annonce-23-Supprimer` · « Assimé · 24. Supprimer l’annonce »

*Rôle* : supprimer une annonce en disant pourquoi.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-5
  - **Titre** : Mes annonces
  - **Texte** : Boutique Mensah · 12 annonces
- **Contenu**
  - **Carte** : [icône : Pagne kente] | Pagne kente tissé main | 35 000 FCFA | 96 vues · 7 favoris · 2 messages
- **Fond** : voile sombre sur l’écran
- **Volet du bas**
  - **Rangée**
    - **Titre de section** : Supprimer l’annonce ?
    - **Bouton icône** : Fermer → ANN-22
  - **Choix** : ◉ | Je ne la vends plus
  - **Choix** : ○ | Vendue sur Pokou | Choisis l’acheteur pour qu’il puisse noter
  - **Choix** : ○ | Vendue ailleurs
  - **Texte** : Les discussions liées restent dans tes Discussions. Cette action est définitive.
  - **Bouton rouge** : Supprimer l’annonce → ANN-9
  - **Ligne** : Annuler → ANN-22

*Règles* : ASM-15 et ASM-18 ; « Vendue sur Pokou » mène à ANN-18.

## 16.1 Notifications

### NOT-1 · Centre de notifications

Maquette : `Notifications-1-Centre` · « Notifications · Centre de notifications »

*Rôle* : retrouver les notifications des services, hors messages.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-1
  - **Titre** : Notifications
  - **Lien** : Tout lire
- **Contenu**
  - **Titre de section** : Aujourd’hui
  - **Liste**
    - **Ligne** : Honam · 9:46 | Ton devis est prêt : 5 600 FCFA, course comprise → PAT-3
    - **Ligne** : Kory · 9:02 | Kafui K. a déclaré 10 000 FCFA. À confirmer. → KOR-4
    - **Ligne** : Pokou certifié · 8:00 | Ton essai se termine dans 3 jours → CRT-4
  - **Titre de section** : Hier
  - **Liste**
    - **Ligne** : Kory · 21:18 | Ton engagement est ferme : 18 000 FCFA → KOR-14
    - **Ligne** : Assimé · 18:30 | 3 nouvelles annonces pour « pagne wax » à Bè → ANN-12
    - **Ligne** : Discussions · 14:05 | Edem K. t’a ajoutée au groupe Les Amis de Bè → DIS-8
  - **Texte** : Les messages n’apparaissent pas ici : ils restent dans Discussions.
- **Barre d’onglets** : Accueil (actif) / Discussions / Kory / Honam / Plus

*Règles* : NAV-13 et section 16.1 ; ouvert par la cloche de l’Accueil (APP-1), donc absent au lot 1.

## 16.2 États vides

### VID-1 · Discussions, premier lancement

Maquette : `Vide-1-Discussions` · « États vides · 1. Discussions, premier lancement »

*Rôle* : premier écran des discussions, au lot 1.

**Disposition et textes**

- **En-tête**
  - **Texte** : [image : pokou-bulles] | [image : Pokou]
- **Contenu**
  - **Liste**
    - **Ligne** : Baba | [intelligence artificielle] | Bienvenue, Afi ! Je t’aide à retrouver tes proches. | 17:20 | [pastille 1] | [icône : Épinglée] → INS-4 (lot 1)
  - **Texte** : Tes discussions arrivent ici
  - **Texte** : Retrouve les proches qui ont déjà Pokou, ou invite les autres par SMS.
  - **Bouton principal** : Retrouver mes proches → INS-5 (lot 1)
  - **Bouton secondaire** : Inviter par SMS
- **Barre d’onglets** : Discussions [pastille 1] (actif) / Statuts / Appels / Réglages

*Règles* : AUTH-10, MSG-22 et NAV-09.

### VID-2 · Kory, aucune cagnotte

Maquette : `Vide-2-Kory` · « États vides · 2. Kory, aucune cagnotte »

*Rôle* : présenter Kory à qui n’a encore aucune cagnotte.

**Disposition et textes**

- **En-tête**
  - **Titre** : Kory
  - **Texte** : Cagnottes et tontines
- **Contenu**
  - **Texte** : Aucune cagnotte pour l’instant
  - **Texte** : Un anniversaire, un mariage, une tontine entre collègues : chacun s’engage, puis verse depuis son wallet.
  - **Bouton principal** : Créer une cagnotte → KOR-6
  - **Bouton secondaire** : Rejoindre avec un lien → KOR-10
  - **Carte** : Pokou ne touche jamais l’argent et ne prend aucune commission sur les cagnottes.
- **Barre d’onglets** : Accueil / Discussions / Kory (actif) / Honam / Plus

*Règles* : NAV-09 et BM-01.

### VID-3 · Honam, aucune commande

Maquette : `Vide-3-Honam` · « États vides · 3. Honam, aucune commande »

*Rôle* : expliquer Honam avant la première commande.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour → APP-4
  - **Titre** : Mes commandes
- **Contenu**
  - **Texte** : Aucune commande
  - **Texte** : Photographie ton ordonnance : une pharmacie proche t’envoie un devis, et un coursier te livre.
  - **Bouton principal** : Envoyer une ordonnance → PAT-1
  - **Encadré beige** : Honam n’est pas un service d’urgence. En cas d’urgence, appelle les secours.

*Règles* : NAV-09 et HON-10.

### VID-4 · Assimé, aucun résultat

Maquette : `Vide-4-Assime` · « États vides · 4. Assimé, aucun résultat »

*Rôle* : répondre à une recherche sans résultat.

**Disposition et textes**

- **En-tête**
  - **Bouton icône** : Retour à Assimé → APP-5
  - **Carte** : machine à coudre
- **Contenu**
  - **Texte** : Aucune annonce à Lomé
  - **Texte** : Personne ne vend de machine à coudre près de chez toi pour l’instant.
  - **Bouton principal** : Créer une alerte → ANN-12
  - **Bouton secondaire** : Chercher dans tout le Togo
  - **Texte** : L’alerte t’envoie au plus une notification par jour.

*Règles* : ASM-13.

## Annexe : écrans de la maquette sans fiche dans le cahier

Aucun : chaque écran de la maquette est décrit plus haut.