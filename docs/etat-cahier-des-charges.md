# État du code face au cahier des charges (v2.8)

Ce tableau dit, exigence par exigence, ce que le code fait. Il couvre les
sections 1 à 8.2 du cahier, reçues en entier, et les règles des sections
suivantes visibles dans les parties reçues (BM-01 à BM-14, historique des
versions, écrans APP), complétées par le texte des **maquettes d'écrans du
31 octobre 2026** (125 écrans). Les images des maquettes n'ont pas été
reçues, seulement leurs légendes : ce qui n'y est pas dit reste marqué
**Hypothèse**.

L'assistant IA s'appelle désormais **Baba** (anciennement Aoussi).

## Activer un module dans un pays

Les modules s'ouvrent par pays, sans nouvelle version de l'application
(NAV-01), avec un réglage système `country.<CC>` (JSON partiel) :

```sql
INSERT INTO system_settings (key, value, updated_at)
VALUES ('country.TG', '{"modules": ["discussions", "kory", "certified", "honam"]}', now());
```

Valeurs par défaut (`backend/app/core/countries.py`) : HONAM et les discussions
sont actifs dans tous les pays ; Kory et Pokou certifié restent ouverts selon
le pays. Un réglage `country.<CC>` contenant une liste `modules` explicite
remplace ces valeurs par défaut et peut donc désactiver HONAM pour ce pays.

## Ce que l'équipe traite à la main

Ces files n'ont pas encore d'écran d'administration ; elles se lisent et se
traitent par l'API, avec un compte `ADMIN` :

| File | Lire | Décider |
|---|---|---|
| Dossiers Pokou certifié Pro (réponse promise sous 48 h) | `GET /api/v1/admin/certified/pro/pending` | `POST /api/v1/admin/certified/pro/{id}/review` `{decision: APPROVE\|CORRECTION\|REJECT, note}` |
| Candidatures coursiers | `GET /api/v1/admin/honam/couriers/pending` | `POST /api/v1/admin/honam/couriers/{user_id}/validate` |
| Statuts sponsorisés Assimé | `GET /api/v1/admin/marketplace/sponsored-statuses` | `PUT /api/v1/admin/marketplace/sponsored-statuses/{boost_id}` `{approve}` |
| Liste d'attente Honam, par ville | `GET /api/v1/admin/honam/waitlist` | ouvrir la ville dans `honam_cities` du pays |

## Modèle économique

| Règle | État | Où |
|---|---|---|
| BM-01 Kory ne touche aucun fonds | Fait : journal de déclarations et de confirmations, aucun solde | `api/v1/kory/kory.py` |
| BM-02 Officine visible si abonnée et wallet vérifié | Fait ; délai de grâce de 7 jours (**Hypothèse**) | `services/honam/rules.py` |
| BM-03 Coursier : essai, ou adhésion et course restante ; pack supérieur à la différence | Fait | `rules.courier_can_accept`, `upgrade_price` |
| BM-04 Course décomptée à la remise seulement | Fait | `rules.record_ride` |
| BM-05 Suspension au 3e défaut | Fait ; un défaut = signalement de l'officine (**Hypothèse**) | `report_courier_default` |
| BM-06 Encaissement CashPay (Semoa), activation au webhook | Fait pour l'abonnement officine, le crédit, l'adhésion, les packs, le badge. Relances push J-7 et J-1 : faites, une fois par échéance | `honam.apply_confirmed_payment`, `services/honam/subscription_reminders.py` |
| BM-07 Registre des courses en écriture seule | Fait, solde recalculé | `CourierLedgerEntry` |
| BM-08 Espace officine web installable, mode coursier dans l'app | Fait | `/officine/`, `CourierScreen` |
| BM-09 Prix de la course par pays, ajouté au devis | Fait (1 000 / 1 500 FCFA) | `send_quote` |
| BM-10 Prix HT, TVA du pays en sus, HT et TTC affichés | Fait sur les écrans de paiement. Factures PDF : **pas faites** | |
| BM-11 Crédit officine 100 FCFA HT par commande payée, alerte à 10, 7 jours puis pause | Fait | `rules.charge_order_credit` |
| BM-12 Format annuaire, tri par distance, aucune mise en avant | Fait | `GET /honam/pharmacies` |
| BM-13 Kory Plus (tontine en rotation) | Fait, fermé tant que le pays n'a pas le module `kory_plus` (mois 13) : ordre des tours fixé à l'ouverture, bénéficiaire du tour qui confirme, passage au tour suivant par l'organisateur | `kory.create_pot`, `KoryRound` |
| Mise en avant Assimé (maquettes) : 600 FCFA TTC / 3 jours ou 1 300 FCFA TTC / 7 jours, « Sponsorisé », 2 au plus par écran | Fait, avec la place dans la bande des statuts (7 jours), le bilan et « Pourquoi je vois ça » | `marketplace.boost_product`, `marketplace/assime.py` |

## Navigation et accueil

| Règle | État |
|---|---|
| Barre Accueil, Discussions, Kory, Honam, Plus | Fait ; Kory et Honam selon le pays |
| NAV-01 Onglets pilotés par pays | Fait (`/config/country`) |
| NAV-03 Cagnotte créée depuis un groupe | Fait (menu des pièces jointes du groupe) |
| NAV-04 Fil de suivi d'une commande | Fait : états, notes, notifications push des changements d'état et messages patient/officine/coursier (texte, participants uniquement) |
| NAV-05/06 Liens profonds `/kory/{id}`, `/honam/order/{id}` | Fait : Android, iOS et pages web d'atterrissage ; les anciennes formes restent acceptées |
| NAV-07 Recherche globale segmentée | Fait côté application : messages accessibles, chaînes publiques et annonces, groupés par module. Les messages chiffrés restent exclus de la recherche serveur |
| NAV-08/09 Accueil avec une carte par module, action de départ si vide | Fait (APP-1) |
| APP-6 Plus | Fait |

## Inscription (section 8)

| Règle | État |
|---|---|
| Maquettes : 3 écrans (numéro et conditions, code, profil avec Baba), puis Baba propose les contacts | Fait |
| INS-1 Bienvenue : une promesse, une signature, langue, confidentialité | Fait |
| Code 6 chiffres, 5 min, renvoi après 60 s, 5 essais puis 15 min de blocage | Fait (serveur et écran) |
| Essais restants affichés | Fait |
| Modifier le numéro | Existait |
| Code par appel vocal | **Pas fait** (aucun fournisseur d'appel configuré) |
| Profil : « Nom affiché » seul obligatoire | Fait |
| Photo facultative | Renvoyée au profil (« plus tard ») |
| Conditions non cochées, documents lisibles dans l'app, consentements distincts | Fait ; textes = **projets à faire valider par un juriste** (`backend/app/legal/`) |
| Âge : case « J'ai l'âge requis » | Fait |
| Centres d'intérêt | Absents (aucune fonction du lot 1 ne les utilise) |

## Pokou certifié et mode preuve

| Règle | État |
|---|---|
| Badge vérifié par le nom du titulaire du wallet, **jamais montré** | Fait, comparaison sans accents, casse ni ordre. Nom du champ renvoyé par CashPay = **Hypothèse** (`payer_name`, `customer_name` ou `account_holder_name`) |
| Écran « noms différents » | Fait : la personne corrige son nom ; le serveur dit seulement s'il correspond |
| Prix Particulier 500/mois, 5 000/an, Pro 2 500/mois HT | Fait |
| Inclus pour les officines | Fait : le titulaire d'une officine abonnée a le profil Pro, au nom de l'officine |
| CERT-11 Essai d'un mois : mode preuve oui, badge au premier paiement | Fait |
| Activation par tout titulaire du badge, admin ou non ; message système ; bandeau permanent | Fait (groupes) |
| Désactivation : la personne qui l'a activé, ou un admin au badge payant (pas l'essai) | Fait (groupes) |
| Supprimé : visible, barré, pour tous ; modifié : version d'origine visible avec l'heure | Fait (groupes) |
| Export PDF daté | Fait (groupes) ; police sans lettres éwé/kabiyè (limite notée dans le code) |
| Mode preuve à deux (maquettes 4b, 5b, 10) | Fait. Le serveur tient le mode (le même pour les deux côtés, coupé par la seule personne qui l'a activé) et ne supprime plus un message envoyé en mode preuve : il le marque. Le texte d'un message chiffré, lui, n'existe que sur les téléphones : c'est chaque appareil qui garde la version d'origine d'une modification et le texte d'un message supprimé. L'export PDF est produit sur le téléphone | `messages.set_proof_mode`, `PokouMessageStore._keepProofTrace`, `proof_export.dart` |
| La trace reste chez les autres même si quelqu'un quitte, bloque ou supprime son compte | Groupes : conservée sur le serveur. À deux : conservée sur le téléphone de l'autre (un rechargement de l'historique ne l'efface pas). **Limite** : un changement de téléphone sans sauvegarde perd la trace à deux — elle ne vit que sur l'appareil |
| Pokou certifié Pro (maquettes Pro 1 à 5) | Fait : justificatif (vu du seul support), vérification sous 48 h (`/admin/certified/pro/pending`), « justificatif à corriger » avec motif, paiement seulement après validation, profil « nom commercial · Géré par … » sur la fiche contact | `certified.pro_apply`, `public_badge` |

## HONAM

Fait : annuaire, ordonnance (photo visible de la seule officine
destinataire), devis avec produits indisponibles et ordonnance originale à
récupérer, acceptation, paiement au wallet de l'officine, « paiement non
reçu », code de remise (patient seulement), coursier (accepter, récupérer,
remettre avec le code, confirmer le paiement de la course), refus puis
renvoi à une autre officine, numéros d'urgence par pays, statistiques pour
toutes les officines, exclusion par l'équipe.

Selon les maquettes : produit manquant signalé **pendant la préparation**,
avant le coursier ; la patiente choisit « recevoir le reste » ou « tout
annuler » ; l'officine rembourse **sous 2 h**, uniquement sur le numéro qui a
payé, sinon elle est suspendue. Coursiers : candidature (zones, wallet,
règles d'or) validée par l'équipe, 5 courses d'essai à la validation,
**période de lancement** sans adhésion ni pack (`honam_launch_until` dans la
configuration du pays), Queen Pokou débloqué sans défaut le mois précédent,
une adhésion expirée ne coupe jamais une course en cours.

Fait aussi : **suivi de la course** (position envoyée toutes les 15 s par le
téléphone du coursier, une seule position gardée, effacée à la remise ;
suivi sans carte par défaut, carte OpenStreetMap chargée à la demande ;
l'officine suit aussi ; le coursier navigue avec son application de cartes),
**villes desservies** (`honam_cities` dans la configuration du pays) et
**liste d'attente** ailleurs, **parrainage** (code donné à la validation ;
2 courses offertes au parrain à la première livraison du filleul —
**Hypothèse** sur le nombre), **récapitulatif de fin d'essai** avec le pack
qui couvre l'activité réelle, **« Vos coursiers »** dans l'espace officine
(rattacher un coursier validé par son numéro ; il voit les courses de
l'officine 5 minutes avant les autres — **Hypothèse** sur le délai).

Fait : notifications push des changements d'état, adressées au patient, à
l'équipe de l'officine et au coursier affecté ; l'acteur du changement est
exclu et les données de santé/adresse ne sont pas incluses dans le payload.
Les relances push d'abonnement à J-7 et J-1 sont également faites, une fois
par échéance.

**Pas fait** : « une fois par mois au plus » pour l'offre coursier (l'offre
est dans le mode coursier, pas encore poussée), validation réglementaire (à
faire par un juriste). Une course impayée au coursier suspend l'officine
après 72 h (**Hypothèse**).

## Assimé

Le Marché existant tient lieu d'Assimé : annonces, contact par Discussions.
Corrigé : le nom du vendeur ne retombe plus sur son numéro de téléphone.
Selon les maquettes : les médicaments sont refusés à la publication et
renvoient vers Honam.

Fait aussi : **favoris et alertes** (une alerte est une recherche
enregistrée, déclenchée à la publication d'une annonce qui y répond, avec
une notification par personne), **statut sponsorisé** (une seule place dans
la bande, après 4 statuts de proches au moins, réservée aux vendeurs au
badge payant, relue par la modération — `/admin/marketplace/sponsored-statuses`
— et ciblée par ville), **« Pourquoi je vois ça »**, **bilan** (affichages en
tête, vues dans les statuts, contacts), filtre « Vendeurs certifiés » côté
serveur (`certified_only=true`).

Fait : filtre « Vendeurs certifiés » dans l'écran et badge Pro distinct sur
les annonces.

**Pas fait** : partage d'une annonce en statut ; ouverture au mois 13 par
pays (le Marché reste ouvert partout, comme avant). Le partage en statut
attend une évolution du modèle des statuts, actuellement texte/média
uniquement. Le calendrier du Marché par pays reste à confirmer avant
d'ajouter un contrôle d'accès.

## Kory

Selon les maquettes : « Total confirmé », « Total déclaré », « Reste à
collecter », contribution « Contestée ». La tontine (Kory Plus) est faite :
elle s'ouvre depuis un groupe, chaque membre mise au wallet du bénéficiaire
du tour, et c'est ce bénéficiaire qui confirme — y compris après le passage
au tour suivant. Elle ne se rejoint pas par code. Pour l'ouvrir dans un
pays, ajoutez `kory_plus` à ses modules.

## Hors périmètre de ces travaux

Charte graphique complète (fichier `pokou-design-tokens.json` non fourni :
seules les couleurs d'état de la section 7.2 sont reprises), mode sombre aux
valeurs du cahier, langues locales, instrumentation de la section 17,
annexes A et B.
