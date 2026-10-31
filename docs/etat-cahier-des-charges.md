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

Valeurs par défaut (`backend/app/core/countries.py`) : Togo = discussions,
Kory, Pokou certifié ; Côte d'Ivoire = discussions seulement. **HONAM est
fermé par défaut** : il s'ouvre au pilote de Lomé (mois 4).

## Modèle économique

| Règle | État | Où |
|---|---|---|
| BM-01 Kory ne touche aucun fonds | Fait : journal de déclarations et de confirmations, aucun solde | `api/v1/kory/kory.py` |
| BM-02 Officine visible si abonnée et wallet vérifié | Fait ; délai de grâce de 7 jours (**Hypothèse**) | `services/honam/rules.py` |
| BM-03 Coursier : essai, ou adhésion et course restante ; pack supérieur à la différence | Fait | `rules.courier_can_accept`, `upgrade_price` |
| BM-04 Course décomptée à la remise seulement | Fait | `rules.record_ride` |
| BM-05 Suspension au 3e défaut | Fait ; un défaut = signalement de l'officine (**Hypothèse**) | `report_courier_default` |
| BM-06 Encaissement CashPay (Semoa), activation au webhook | Fait pour l'abonnement officine, le crédit, l'adhésion, les packs, le badge. Relances J-7 et J-1 : **pas faites** | `honam.apply_confirmed_payment` |
| BM-07 Registre des courses en écriture seule | Fait, solde recalculé | `CourierLedgerEntry` |
| BM-08 Espace officine web installable, mode coursier dans l'app | Fait | `/officine/`, `CourierScreen` |
| BM-09 Prix de la course par pays, ajouté au devis | Fait (1 000 / 1 500 FCFA) | `send_quote` |
| BM-10 Prix HT, TVA du pays en sus, HT et TTC affichés | Fait sur les écrans de paiement. Factures PDF : **pas faites** | |
| BM-11 Crédit officine 100 FCFA HT par commande payée, alerte à 10, 7 jours puis pause | Fait | `rules.charge_order_credit` |
| BM-12 Format annuaire, tri par distance, aucune mise en avant | Fait | `GET /honam/pharmacies` |
| BM-13 Kory Plus (tontine en rotation) | **Pas fait** : refusé tant que Kory Plus n'est pas ouvert (mois 13) | |
| Mise en avant Assimé (maquettes) : 600 FCFA TTC / 3 jours ou 1 300 FCFA TTC / 7 jours, « Sponsorisé », 2 au plus par écran | Fait. Place dans la bande des statuts (7 jours), bilan, « Pourquoi je vois ça » : **pas faits** | `marketplace.boost_product` |

## Navigation et accueil

| Règle | État |
|---|---|
| Barre Accueil, Discussions, Kory, Honam, Plus | Fait ; Kory et Honam selon le pays |
| NAV-01 Onglets pilotés par pays | Fait (`/config/country`) |
| NAV-03 Cagnotte créée depuis un groupe | Fait (menu des pièces jointes du groupe) |
| NAV-04 Fil de suivi d'une commande | Fait (états et notes). Messages patient/officine/coursier dans le fil : **pas faits** |
| NAV-05/06 Liens profonds `/kory/{id}`, `/honam/order/{id}` | **Pas faits** (le routeur existant gère les invitations) |
| NAV-07 Recherche globale segmentée | **Pas faite** |
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
| Inclus pour les officines | **Pas encore relié** à l'abonnement officine |
| CERT-11 Essai d'un mois : mode preuve oui, badge au premier paiement | Fait |
| Activation par tout titulaire du badge, admin ou non ; message système ; bandeau permanent | Fait (groupes) |
| Désactivation : la personne qui l'a activé, ou un admin au badge payant (pas l'essai) | Fait (groupes) |
| Supprimé : visible, barré, pour tous ; modifié : version d'origine visible avec l'heure | Fait (groupes) |
| Export PDF daté | Fait (groupes) ; police sans lettres éwé/kabiyè (limite notée dans le code) |
| Mode preuve à deux | **Pas fait** : les messages à deux sont chiffrés de bout en bout, la trace doit être gardée par les téléphones eux-mêmes — chantier à part |
| La trace reste chez les autres même si quelqu'un quitte, bloque ou supprime son compte | Vrai pour les groupes (conservée sur le serveur) |
| Pokou certifié Pro (justificatif, vérification sous 48 h, profil « Géré par ») | **Pas fait** |

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

**Pas fait** : suivi sur carte (position du coursier toutes les 15 s),
liste d'attente des villes non desservies, parrainage, récapitulatif de fin
d'essai, « Vos coursiers » de l'officine, notifications push des changements
d'état, validation réglementaire (à faire par un juriste). Une course
impayée au coursier suspend l'officine après 72 h (**Hypothèse**).

## Assimé

Le Marché existant tient lieu d'Assimé : annonces, contact par Discussions.
Corrigé : le nom du vendeur ne retombe plus sur son numéro de téléphone.
Selon les maquettes : les médicaments sont refusés à la publication et
renvoient vers Honam.

**Pas fait** : badge Pro et filtre « Vendeurs certifiés », statuts
sponsorisés, favoris et alertes, partage en statut, ouverture au mois 13 par
pays (le Marché reste ouvert partout, comme avant).

## Kory

Selon les maquettes : « Total confirmé », « Total déclaré », « Reste à
collecter », contribution « Contestée ». **Pas faits** : la tontine (Kory
Plus, mois 13) et la confirmation par le bénéficiaire du tour.

## Hors périmètre de ces travaux

Charte graphique complète (fichier `pokou-design-tokens.json` non fourni :
seules les couleurs d'état de la section 7.2 sont reprises), mode sombre aux
valeurs du cahier, langues locales, instrumentation de la section 17,
annexes A et B.
