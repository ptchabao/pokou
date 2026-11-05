# Conformité au cahier des charges v3.4

Document de référence : `POKOU_Cahier_des_charges_v3.4.pdf` (164 pages, 4 novembre 2026).
Ce document fait la synthèse complète des vérifications, des écarts traités et de l'état de conformité de l'application Pokou face aux versions **v3.3** (72 nouvelles fiches d'écrans, lot 1 à 4 onglets) et **v3.4** (mode coursier plein écran, intégration dans Plus, essai 5 courses, etc.), ainsi que de l'alignement strict du **mode sombre**.

---

## 1. Synthèse des nouveautés v3.3 et v3.4

| Version | Date | Apports majeurs |
|---|---|---|
| **v3.3** | 04/11/2026 | • **Lot 1 « Discussions d’abord »** (section 6.3) : interface à 4 onglets (`Discussions`, `Statuts`, `Appels`, `Réglages`) tant qu'aucun service n'est actif dans le pays.<br>• **72 nouvelles fiches d'écrans** : messagerie (`DIS-*`), statuts (`STA-*`), engagement Kory 8 h (`KOR-12` à `KOR-14`), Honam patient (`PAT-*`), officine (`OFF-*`), coursiers (`COU-*`), avis acheteur Assimé (`ANN-19`, `ANN-24`), réglages (`REG-*`), centre de notifications (`NOT-1`), états vides (`VID-*`). |
| **v3.4** | 04/11/2026 | • **Mode coursier dans Plus** (`COU-26`) et affichage plein écran des courses entrantes (`COU-27`, `HON-58`).<br>• **Essai de 5 courses** pour les coursiers inscrits après le lancement (`HON-39`).<br>• Premières courses plafonnées et photo vérifiée à la remise (`HON-56`, `HON-57`).<br>• Question n° 36 de l'annexe B (colis perdu). |

---

## 2. Audit et mise à jour du Mode Sombre (Section 7.8, page 29)

### Spécification du cahier des charges (v3.4, section 7.8)
> **Mode sombre** : jetons proposés, contrastes vérifiés :
> - Fond : `#1A1615` (brand.ebene-900)
> - Surface : `#2A2320`
> - Texte principal : `#FFF7EC` (14,54:1 sur surface)
> - Texte secondaire : `#B8AAA0` (6,84:1 sur surface)
> - Action : `#E8A57C` avec libellé ébène `#1A1615` (8,64:1)
> - Or : `#D4AF37` (7,34:1 sur surface)

### Corrections et alignements effectués dans le code
1. **Palette `AppColors` (`mobile/lib/core/theme/app_colors.dart`)** :
   - Remplacement des teintes sombres bleutées/ardoise (`#131B2E`, `#1B2438`, `#283044`) par la palette chaude terracotta/ébène spécifiée :
     - `background` : `#1A1615` en sombre (`#F8FAFC` en clair).
     - `surface` : `#2A2320` en sombre (`#FFFFFF` en clair).
     - `surfaceElevated` : `#352C28` en sombre.
     - `border` & `skeletonFill` : `#3D332E` en sombre.
     - `textPrimary` : `#FFF7EC` en sombre (`#1A1615` en clair).
     - `textSecondary` : `#B8AAA0` en sombre (`#6B5E57` en clair).
     - `textMuted` : `#8C7D73` (taupe-500).
   - Verbes et actions :
     - `actionButtonBackground` : `#E8A57C` en sombre (`#7A3A18` en clair).
     - `actionButtonForeground` : `#1A1615` (ébène) en sombre (`#FFFFFF` en clair), respectant le contraste strict de 8,64:1.
   - Discussion (`chatBackground`, bulles, cadre média) :
     - `chatBackground` : `#1A1615` en sombre.
     - `chatBubbleReceived` : `#2A2320` avec bordure `#3D332E` et texte `#FFF7EC`.
     - `chatBubbleSent` : `#5C2E14` avec bordure `#7A3A18` et horodatage `#F6E3D6`.
     - `chatComposerBg` : `#2A2320` avec bordure `#3D332E`.
2. **Thème Flutter `AppTheme` (`mobile/lib/core/theme/app_theme.dart`)** :
   - Mise à jour du `colorScheme` en mode sombre (`surface`, `onSurface`, `primary`, `onPrimary`).
   - `ElevatedButtonTheme` adapté avec fond `#E8A57C` et texte ébène `#1A1615` en sombre.
   - `ModuleActionButton` (`module_ui.dart`) basculant automatiquement vers `actionButtonBackground` et `actionButtonForeground`.

---

## 3. Matrice de vérification des écrans (191 fiches du cahier v3.4)

### A. Lot 1 — « Discussions d’abord » (Section 6.3)
| Écran | Rôle & Spécification v3.4 | Implémentation | État |
|---|---|---|---|
| **LOT-1** | Discussions (lot 1) : pas d'accueil, fil sans bandeau Kory ni mention des cagnottes. | `ContactsScreen` via `pokouTabsFor(modules)` | **Conforme** |
| **LOT-2** | Statuts (lot 1) : statuts en onglet principal, sans annonces Assimé sponsorisées. | `StatusListScreen` via `PokouTab.statuses` | **Conforme** |
| **LOT-3** | Appels (lot 1) : journal d'appels en onglet principal (`Tous` et `Manqués`). | `CallLogScreen` via `PokouTab.calls` | **Conforme** |
| **LOT-4** | Réglages (lot 1) : remplace Plus au lot 1. Profil, Pokou certifié (1 mois offert), réglages REG-1 à REG-11, et **encart « Bientôt : Kory, Honam, Assimé »** avec bouton **« Me prévenir »**. | Mis à jour dans `MoreScreen(lot1: true)` | **Conforme (mis à jour)** |

### B. Inscription et Connexion (Section 8)
| Écran | Rôle & Spécification v3.4 | État |
|---|---|---|
| **INS-1** | Bienvenue + numéro + acceptation des conditions via « Accepter et continuer » (AUTH-09, entrée unique). | **Conforme** |
| **INS-2 / 2b** | Saisie OTP 6 cases, autoremplissage iOS `oneTimeCode`, renvoi 60 s, blocage après 5 échecs, état d'erreur explicite. | **Conforme** |
| **INS-3** | Profil avec bulle de Baba signalée « IA », seul champ obligatoire « Nom affiché », consentements facultatifs désactivés par défaut. | **Conforme** |
| **INS-4** | Baba propose les contacts, discussion épinglée par défaut. | **Conforme** |
| **INS-5** | Contacts retrouvés et comparaison protégée. | **Conforme** |
| **CNX-1** | Code PIN si activé (vérification en deux étapes). | **Conforme** |
| **CNX-2 / CNX-3** | Écrans de bon retour et statut de restauration du compte. | **Conforme** |

### C. Mode coursier Win Pokou (Section 11.10 & 11.11)
| Écran | Rôle & Spécification v3.4 | Implémentation | État |
|---|---|---|---|
| **COU-26** | **Plus, pour un coursier** : carte « Mode coursier » avec état (« Disponible » en vert) et phase (ex. « 3 courses d’essai restantes »), ouvrant `COU-8`. | Intégré dans `MoreScreen` via `courierStatusProvider` | **Conforme (mis à jour)** |
| **COU-27** | **Course reçue pendant une discussion** : proposition plein écran type appel entrant, compte à rebours 30 s, gain, retrait/livraison, rappel de retour à l'écran précédent. | Composant `CourierIncomingRideScreen` ajouté dans `courier_screen.dart` | **Conforme (mis à jour)** |
| **COU-8** | Mode coursier : accueil du coursier, interrupteur de disponibilité, gains, compteur de courses et de défauts. | `CourierScreen` | **Conforme** |
| **COU-9** | Proposition de course avec adresses, distances et gains. | `_RideCard` | **Conforme** |
| **COU-10 / 11** | Livraison, navigation externe Maps et saisie du code de remise à 6 chiffres. | `act('deliver')` + dialogue code | **Conforme** |
| **COU-12 à 14** | Fin d'essai (HON-39 : 5 courses), choix du pack Win Pokou (Ablavi, Pokou Vi, Oseï Tutu, Queen Pokou). | `_Offer` dans `courier_screen.dart` | **Conforme** |
| **COU-15 / 23-25** | Parrainage coursier : code de parrainage, 2 courses offertes au parrain. | `_Referral` | **Conforme** |
| **COU-20 / 21** | Défaut signalé et suspension automatique au 3e défaut. | `status == 'SUSPENDED'` | **Conforme** |

### D. Kory — Cagnottes et Tontines (Section 10)
| Écran | Rôle & Spécification v3.4 | Implémentation | État |
|---|---|---|---|
| **KOR-1 / KOR-6** | Consultation et création d'une cagnotte (titre, motif, collecteur, échéance). | `KoryScreen`, `KoryCreateScreen` | **Conforme** |
| **KOR-2 / KOR-3** | Déclaration de contribution (BM-01 : aucun flux financier via Pokou, portefeuille à portefeuille). | `_DeclareSheet` | **Conforme** |
| **KOR-4 / KOR-5** | Confirmation ou rejet par le collecteur. | `_review()` dans `_EntryTile` | **Conforme** |
| **KOR-7 / KOR-8** | Tontine en rotation (Kory Plus) : 1 000 FCFA HT payés à l'ouverture, tours fixes. | `KoryRound` | **Conforme** |
| **KOR-12** | **« Je m'engage »** : promesse de montant avant de verser, rappel des 8 h modifiables. | Note explicative ajoutée dans le formulaire de déclaration | **Conforme (mis à jour)** |
| **KOR-13** | **« Engagement modifiable »** : statut modifiable pendant 8 h avant de devenir ferme. | Badge dynamique `Modifiable (Xh)` dans `_EntryTile` | **Conforme (mis à jour)** |
| **KOR-14** | **« Engagement ferme »** : après 8 h, l'engagement est ferme et suivi au journal. | Badge `Engagement ferme` dans `_EntryTile` | **Conforme (mis à jour)** |

### E. Honam Patient & Espace Officine (Section 11)
| Écran | Rôle & Spécification v3.4 | État |
|---|---|---|
| **PAT-1 à PAT-8** | Patient : photo d'ordonnance, réception devis, paiement officine direct, suivi livraison, produit manquant/remboursement, historique. | **Conforme** (`HonamScreen`, `HonamOrderScreen`, `HonamSendScreen`) |
| **OFF-1 à OFF-16** | Officine : réception ordonnances, émission devis, confirmation paiement, appel coursier (`OFF-8`), suivi livraison (`OFF-7`), abonnement Wétri/ÉPÉ (`OFF-5`), crédit officine 100 FCFA HT. | **Conforme** (application web officine `/officine/` et API backend) |
| **SUI-1 / SUI-2** | Suivi coursier avec carte ou balise de position toutes les 15 s. | **Conforme** (`_LocationBeacon`, `CourierTracking`) |

### F. Pokou certifié, Mode preuve et Assimé
| Écran | Rôle & Spécification v3.4 | État |
|---|---|---|
| **CRT-1 à CRT-5** | Offre badge certifié (500 FCFA/mois particulier, 2 500 FCFA/mois pro), vérification du wallet CashPay, pause et fin d'essai. | **Conforme** (`CertifiedScreen`) |
| **PRV-3b à PRV-10**| Mode preuve : activation groupe ou à deux, messages barrés/horodatés à la suppression, export PDF certifié. | **Conforme** (`proof_widgets.dart`, `proof_export.dart`) |
| **ANN-1 à ANN-24**| Assimé : recherche, filtres, annonce, publication, mises en avant 600/1 300 FCFA, statut sponsorisé modéré, avis transaction (`ANN-19`/`ANN-24`). | **Conforme** (`MarketplaceScreen`, backend `assime.py`) |

### G. Réglages, Notifications et États Vides
| Écran | Rôle & Spécification v3.4 | Implémentation | État |
|---|---|---|---|
| **REG-1 à REG-13**| Confidentialité (`REG-1`), Stockage (`REG-2`), Sécurité (`REG-3`), PIN (`REG-5`), Notifications (`REG-8`), Langue (`REG-9`), Aide Baba (`REG-10`), À propos (`REG-11`), Conditions & RGPD (`REG-12`/`REG-13`). | Raccordés dans `MoreScreen` et `StorageSettingsScreen` | **Conforme (mis à jour)** |
| **NOT-1** | Centre de notifications système et transactionnelles. | **Conforme** |
| **VID-1 à VID-4** | États vides contextualisés pour chaque module (Discussions, Kory, Honam, Assimé). | Composants `ModuleEmptyState` | **Conforme** |

---

## 4. Vérification de non-régression et cohérence

- **Thème clair & sombre** : tous les jetons basculent de manière unifiée via `AppColors._pick()`. Les contrastes WCAG 2.2 dépassent les exigences minimales (14,54:1 pour le texte sur surface sombre, 8,64:1 pour les boutons d'action ébène sur terracotta claire).
- **Navigation adaptative** :
  - En **Lot 1** (`isLot1` = vrai) : barre basse à 4 onglets (`Discussions`, `Statuts`, `Appels`, `Réglages`), Plus remplacé par `MoreScreen(lot1: true)`, services masqués avec encart « Bientôt » (`NAV-12`).
  - En **Application complète** : barre à 5 onglets, entrée mode coursier dans Plus (`COU-26`), accès complet Kory, Honam et Assimé.
