# Conformité au cahier des charges v3.2

Vérification de l'application (code actuel) face à `POKOU_Cahier_des_charges_v3.2.pdf`
(121 pages, 31 octobre 2026). Ce document ne reprend pas tout l'état déjà
suivi dans [`etat-cahier-des-charges.md`](etat-cahier-des-charges.md) : il
traite **ce que v3.2 change** par rapport aux versions précédentes, c'est-à-dire
la section 8 (inscription et connexion), et liste les écarts réels.

Les versions 3.0 et 3.1 ne touchent que le **modèle économique** (packs,
rémunération des associés, rentabilité — sections 4, 5.2, 17) : rien à
implémenter dans l'application. Le seul delta applicatif de v3.x est la
**section 8**, introduite par v3.2.

## Section 8 — Inscription et connexion

| Exigence v3.2 | État | Détail |
|---|---|---|
| **AUTH-08** Entrée unique : même écran pour créer un compte et se reconnecter ; le serveur ne révèle pas si le numéro est inscrit avant la vérification du code | **Conforme** | Un seul bouton « Commencer » ; `request-otp` ne renvoie que `expires_in`, jamais l'existence du compte ; la distinction création/reconnexion se fait après le code (`routeAfterSignIn`, `needs_onboarding`) |
| **AUTH-02** Jeton d'accès court + rafraîchissement rotatif dans Keystore/Keychain ; déconnexion à distance | **Conforme** | `SecureTokenStorage` (flutter_secure_storage) ; `DELETE /devices/{id}` |
| **AUTH-04 / CNX-1** Code PIN de vérification en deux étapes, demandé à la réinscription | **Conforme** | `TwoStepRequired` → `TwoStepPinScreen` à la reconnexion ; `DELETE /account/two-step` |
| **AUTH-06** Suppression du compte depuis l'application **et depuis une page web** | **Partiel** | `DELETE /account` + entrée dans l'écran Confidentialité : **côté application fait**. **Page web de suppression : pas faite** (exigée par Google Play / App Store) |
| **AUTH-09** Conditions et âge acceptés par « Accepter et continuer » **sur INS-1** ; consentements facultatifs (statistiques, nouveautés) désactivés par défaut **sur le profil** | **Partiel / écart** | Les consentements facultatifs sont bien désactivés par défaut et horodatés. **Mais** l'acceptation des conditions et de l'âge a été déplacée **après le code** (étape profil), au lieu d'être portée par le bouton d'INS-1. À rapprocher de v3.2 : porter l'acceptation sur INS-1 (bouton = acceptation, documents lisibles en lien), ne garder sur le profil que statistiques et nouveautés |
| **3 écrans avant l'application** (INS-1 bienvenue+numéro+conditions, INS-2 code, INS-3 profil) | **Écart** | L'application a encore **Bienvenue** et **Numéro** en **deux écrans séparés** (`/welcome` puis `/phone`), soit 4 écrans avant l'app. v3.2 veut INS-1 = bienvenue + numéro + conditions réunis |
| **INS-2** Code **rempli automatiquement** (SMS Retriever / User Consent sur Android, `oneTimeCode` sur iOS), collage accepté | **Pas fait** | Saisie manuelle ; collage possible, mais pas de remplissage automatique |
| **INS-2** « Recevoir le code par appel » si le SMS échoue | **Pas fait** | Aucun fournisseur d'appel vocal configuré |
| **CNX-2 / CNX-3 / AUTH-03** Sauvegarde et **restauration** du compte et des discussions sur un nouveau téléphone | **Pas fait** | Pas de sauvegarde cloud des discussions ni d'écran de restauration. `database_recovery.dart` ne gère que la clé locale SQLCipher, pas une sauvegarde restaurable |
| **AUTH-01** Attestation d'intégrité (Play Integrity / App Attest) et protection anti-SMS-pumping | **Pas fait** | Limitation par numéro, appareil et blocage après 5 essais : fait. Attestation d'intégrité et listes de préfixes : pas faites |
| **AUTH-05** Découverte des contacts sous forme protégée, mécanisme documenté | **À vérifier** | La synchronisation des contacts existe ; le caractère « protégé » (au-delà d'un simple hachage) et sa documentation restent à confirmer |
| **AUTH-07** Reprise du parcours après abandon, pendant 24 h | **Pas fait** | — |
| **AUTH-10 / INS-4 / MSG-22** Baba (assistant IA) propose la découverte des contacts après l'inscription ; discussion de Baba **épinglée par défaut**, signalée « IA » | **Partiel** | L'étape « Baba propose les contacts » existe à l'inscription (onboarding). L'**épinglage permanent** de la discussion de Baba en tête des Discussions (MSG-22) n'est pas confirmé dans la liste |
| Baba (ex-Aoussi) comme nom de l'assistant | **Conforme** | Renommé partout, 6 langues |

## Section 7 — Charte graphique et design system

| Élément | État |
|---|---|
| Couleurs d'état (section 7.2) | Reprises dans `AppColors` |
| **`pokou-design-tokens.json`** (référencé par v3.2 comme accompagnant le document) | **Absent du dépôt** : impossible de vérifier la conformité complète des tokens (typographie, espacements, rayons, ombres). Le fournir permettrait d'aligner précisément le design system |

## Modules métier (sections 9 à 12)

v3.2 consolide les **maquettes du 31 octobre** déjà suivies dans
`etat-cahier-des-charges.md`. L'implémentation correspondante est en place :

- **Discussions, Pokou certifié, mode preuve** (groupes et à deux), **Pokou
  certifié Pro** : faits (voir le détail et les limites — mode preuve à deux
  porté par les téléphones, etc. — dans `etat-cahier-des-charges.md`).
- **Kory** + **Kory Plus** (tontine en rotation) : faits.
- **HONAM** : annuaire, ordonnance, devis, paiement à l'officine, coursier,
  **suivi de course**, **liste d'attente**, **parrainage**, **« Vos
  coursiers »** : faits.
- **Assimé** : favoris, alertes, statut sponsorisé modéré, « Pourquoi je vois
  ça », bilan : faits.

Les écarts de ces modules restent ceux déjà listés dans
`etat-cahier-des-charges.md` (notifications push HONAM, page web de certains
flux, etc.).

## Priorités de mise en conformité v3.2 (section 8)

Par ordre d'impact :

1. **Réunir INS-1** (bienvenue + numéro + conditions) en un écran, avec
   acceptation des conditions et de l'âge portée par « Accepter et
   continuer » (AUTH-09, 3 écrans avant l'app).
2. **Page web de suppression de compte** (AUTH-06) — exigée par les stores,
   bloquante pour la publication.
3. **Remplissage automatique du code** SMS (INS-2) — fort gain d'usage.
4. **Sauvegarde et restauration** sur nouveau téléphone (CNX-2/CNX-3,
   AUTH-03) — chantier conséquent.
5. **Attestation d'intégrité** et anti-SMS-pumping (AUTH-01).
6. Fournir **`pokou-design-tokens.json`** pour aligner le design system.
