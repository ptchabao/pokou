"""Génère le plan de test Pokou (Excel) pour les équipes de test.

    python3 generer_plan_de_test.py Pokou-plan-de-test-<version>.xlsx

Modifier la liste MODULES pour ajouter ou corriger un cas, et VERSION.
"""
import sys
from openpyxl import Workbook
from openpyxl.formatting.rule import CellIsRule, FormulaRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

OUT = sys.argv[1]
VERSION = "1.28.1 (50)"

# (préfixe, module) puis cas : (fonctionnalité, priorité, plateforme, préconditions, étapes, résultat attendu)
A, I, T, C = "Android", "iOS", "Android + iOS", "Console web"
MODULES = [
("INS", "Inscription et connexion", [
 ("Première inscription", "P1", T, "Numéro jamais utilisé sur Pokou. Carte SIM dans le téléphone.",
  "1. Ouvrir l'app.\n2. Saisir le numéro, cocher les conditions et l'âge.\n3. Demander le code.\n4. Saisir le code reçu par SMS.",
  "Le code arrive par SMS (et WhatsApp si disponible). Le compte est créé et l'écran de profil s'ouvre."),
 ("Code expiré", "P1", T, "Écran de saisie du code ouvert.",
  "1. Demander le code.\n2. Attendre plus d'une minute.\n3. Saisir le code.",
  "Le code est refusé avec un message clair. Un nouveau code peut être demandé."),
 ("Code faux", "P1", T, "Écran de saisie du code ouvert.",
  "1. Saisir un code faux.\n2. Recommencer plusieurs fois.",
  "Chaque code faux est refusé. Après trop d'essais, l'app demande d'attendre avant de réessayer."),
 ("Renvoi du code", "P2", T, "Code demandé mais non reçu.",
  "1. Attendre la fin du compte à rebours.\n2. Toucher « Renvoyer ».",
  "Un nouveau code arrive. L'ancien ne fonctionne plus."),
 ("Conditions non cochées", "P2", T, "Écran du numéro.",
  "1. Saisir le numéro sans cocher les conditions ni l'âge.\n2. Essayer de continuer.",
  "Impossible de continuer tant que les deux cases ne sont pas cochées."),
 ("Profil à l'inscription", "P1", T, "Compte tout juste créé.",
  "1. Saisir un nom.\n2. Ajouter une photo (galerie puis appareil photo).\n3. Continuer.",
  "Le nom et la photo sont enregistrés et visibles dans Plus → profil."),
 ("Accès aux contacts", "P1", T, "Étape contacts de l'inscription.",
  "1. Autoriser l'accès aux contacts.\n2. Recommencer sur un autre compte en refusant.",
  "Autorisé : les contacts déjà sur Pokou apparaissent. Refusé : l'app reste utilisable, sans plantage."),
 ("Reconnexion", "P1", T, "Compte existant, app désinstallée puis réinstallée.",
  "1. Saisir le numéro.\n2. Saisir le code.",
  "Le compte est retrouvé (nom, photo). Aucune seconde inscription n'est créée."),
 ("Vérification en deux étapes", "P1", T, "Code PIN activé dans Compte et sécurité.",
  "1. Se déconnecter puis se reconnecter.\n2. Saisir le code SMS.\n3. Saisir un PIN faux, puis le bon.",
  "Le PIN est demandé après le code SMS. PIN faux : refus. Bon PIN : connexion."),
 ("PIN oublié", "P2", T, "Code PIN activé.",
  "1. À l'écran du PIN, toucher « PIN oublié ».",
  "L'app explique le délai d'attente avant de pouvoir se reconnecter sans PIN."),
 ("Un seul téléphone par compte", "P1", T, "Deux téléphones A et B. Compte connecté sur A.",
  "1. Se connecter au même compte sur B.\n2. Revenir sur A et ouvrir une discussion.",
  "B est connecté. A est déconnecté et revient à l'écran de connexion. A ne reçoit plus de notifications."),
 ("Déconnexion", "P2", T, "Compte connecté.",
  "1. Plus → Compte et sécurité → se déconnecter.",
  "Retour à l'écran de connexion. Rouvrir l'app ne reconnecte pas tout seul."),
 ("Changement de numéro", "P2", T, "Compte connecté, second numéro disponible.",
  "1. Compte et sécurité → changer de numéro.\n2. Valider le nouveau numéro par code.",
  "Le compte passe au nouveau numéro, les discussions sont conservées."),
 ("Suppression du compte", "P2", T, "Compte de test jetable.",
  "1. Compte et sécurité → supprimer mon compte.\n2. Confirmer.",
  "Le compte est supprimé, l'app revient à l'écran de connexion. Les contacts ne le voient plus."),
]),
("NAV", "Accueil et navigation", [
 ("Écran d'accueil", "P1", T, "Compte connecté avec au moins une discussion.",
  "1. Ouvrir l'onglet Accueil.",
  "Salutation avec le prénom, nombre de messages non lus, recherche, bouton Baba, cartes Kory / Honam / Assimé, « En cours », dernières discussions."),
 ("Messages non lus dans l'en-tête", "P2", T, "Un contact envoie 2 messages non lus.",
  "1. Regarder l'en-tête de l'accueil.\n2. Lire les messages.\n3. Revenir à l'accueil.",
  "« 2 messages non lus » s'affiche, puis l'accroche habituelle une fois lus. La pastille de l'onglet Discussions suit."),
 ("Recherche globale", "P1", T, "Contacts et discussions existants.",
  "1. Toucher la barre de recherche.\n2. Chercher un contact, puis un mot.",
  "Les résultats s'affichent et ouvrent le bon écran."),
 ("Raccourci Baba", "P2", T, "—",
  "1. Toucher le carré à droite de la recherche.",
  "La discussion avec l'assistant Baba s'ouvre."),
 ("Cartes de services", "P1", T, "Kory, Honam et Assimé ouverts dans le pays.",
  "1. Toucher chaque carte.\n2. Toucher le bouton rond de chaque carte.",
  "La carte ouvre le service. Le bouton rond lance l'action directe (créer une cagnotte, envoyer une ordonnance, voir les annonces)."),
 ("Carte « En cours »", "P2", T, "Une cagnotte Kory ouverte avec objectif et échéance.",
  "1. Regarder la carte sur l'accueil.\n2. La toucher.",
  "Titre, jours restants, montant confirmé, anneau de progression et échéance sont justes. Le toucher ouvre la cagnotte."),
 ("Barre d'onglets", "P1", T, "—",
  "1. Passer sur chaque onglet.\n2. Faire défiler chaque écran jusqu'en bas.",
  "Chaque onglet s'ouvre sans délai. Aucun contenu ne dépasse sous la barre d'onglets."),
 ("Cloche des notifications", "P2", T, "Une notification de service non lue.",
  "1. Toucher la cloche.",
  "Le centre de notifications s'ouvre, la pastille disparaît après lecture."),
 ("Tirer pour actualiser", "P3", T, "—",
  "1. Tirer l'accueil vers le bas.",
  "Les discussions et les services se rechargent."),
]),
("MSG", "Discussions à deux", [
 ("Envoyer et recevoir un texte", "P1", T, "Deux comptes A et B, contacts l'un de l'autre.",
  "1. A écrit à B.\n2. B répond.",
  "Les messages arrivent en quelques secondes des deux côtés, dans l'ordre, avec l'heure."),
 ("Accusés de réception", "P1", T, "A et B en ligne.",
  "1. A envoie un message.\n2. B ouvre la discussion.",
  "Chez A : envoyé, puis remis, puis lu."),
 ("Messages lisibles (chiffrement)", "P1", T, "A et B sur la version à tester.",
  "1. Échanger 10 messages dans les deux sens.\n2. Fermer et rouvrir l'app des deux côtés.",
  "Aucun message ne reste sur « En attente de ce message… »."),
 ("Message hors ligne", "P1", T, "B en mode avion.",
  "1. A envoie 3 messages.\n2. B réactive le réseau.",
  "B reçoit les 3 messages et une notification. Rien n'est perdu ni dupliqué."),
 ("Envoi sans réseau", "P1", T, "A en mode avion.",
  "1. A écrit un message et l'envoie.\n2. A réactive le réseau.",
  "Le message reste en attente, puis part tout seul au retour du réseau."),
 ("Répondre à un message", "P2", T, "Discussion avec des messages.",
  "1. Glisser ou appuyer longuement sur un message → Répondre.\n2. Envoyer.",
  "La réponse cite le message d'origine. Toucher la citation y ramène."),
 ("Modifier un message", "P2", T, "Message envoyé il y a moins de quelques minutes.",
  "1. Appui long → Modifier.\n2. Corriger et valider.",
  "Le message est corrigé chez A et B, avec la mention « modifié »."),
 ("Supprimer un message", "P2", T, "Message envoyé.",
  "1. Appui long → Supprimer pour tous.",
  "Le message disparaît (ou est marqué supprimé) chez A et B."),
 ("Réactions", "P2", T, "Message reçu.",
  "1. Appui long → choisir un emoji.\n2. En choisir un autre.",
  "La réaction s'affiche chez les deux. La seconde remplace la première."),
 ("Clavier d'emojis", "P1", T, "Discussion ouverte.",
  "1. Toucher le bouton emoji.\n2. Choisir des emojis, changer de catégorie.\n3. Utiliser la recherche et la touche effacer.",
  "Le panneau prend toute la largeur, jusqu'au bas de l'écran. Il s'ouvre sur les visages. Textes en français. L'emoji s'insère au curseur."),
 ("Stickers", "P2", T, "Discussion ouverte.",
  "1. Onglet Stickers du panneau.\n2. Envoyer un sticker.",
  "Le sticker part et s'affiche chez les deux."),
 ("GIF", "P3", T, "Un fichier GIF sur le téléphone.",
  "1. Bouton GIF du panneau.\n2. Choisir le fichier.",
  "Le GIF est envoyé et s'anime chez le destinataire."),
 ("Photo depuis la galerie", "P1", T, "Autorisation photos.",
  "1. Trombone → Photo.\n2. Choisir une image, ajouter une légende, envoyer.",
  "La photo arrive avec sa légende et s'ouvre en plein écran."),
 ("Photo depuis l'appareil", "P1", T, "Autorisation appareil photo.",
  "1. Icône appareil photo.\n2. Prendre une photo et l'envoyer.",
  "La photo est envoyée. Refuser l'autorisation n'entraîne pas de plantage."),
 ("Vidéo", "P2", T, "Vidéo de moins d'une minute.",
  "1. Trombone → Vidéo.\n2. Envoyer.",
  "La vidéo arrive et se lit chez le destinataire."),
 ("Document", "P2", T, "Un PDF sur le téléphone.",
  "1. Trombone → Document.\n2. Envoyer.",
  "Le document arrive avec son nom et s'ouvre."),
 ("Note vocale", "P1", T, "Autorisation micro.",
  "1. Maintenir le micro, parler, relâcher.\n2. Recommencer en glissant pour verrouiller, puis en glissant pour annuler.",
  "La note part et s'écoute chez les deux. Verrouiller garde l'enregistrement. Annuler n'envoie rien."),
 ("Indicateur de saisie", "P3", T, "A et B dans la même discussion.",
  "1. B commence à écrire.",
  "A voit « écrit… » dans la discussion et dans la liste."),
 ("Recherche dans la discussion", "P3", T, "Discussion avec un historique.",
  "1. Loupe en haut.\n2. Chercher un mot.",
  "Les messages correspondants sont trouvés et mis en évidence."),
 ("Bandeau de chiffrement", "P2", T, "Discussion ouverte.",
  "1. Lire le bandeau en haut de la discussion.",
  "« Chiffré de bout en bout » s'affiche en clair et en sombre, lisible."),
 ("Changement de téléphone du contact", "P1", T, "B réinstalle l'app ou change de téléphone.",
  "1. B se reconnecte.\n2. A envoie un message à B.\n3. B répond.",
  "Les nouveaux messages sont lisibles des deux côtés. A est informé que la sécurité de B a changé."),
 ("Bloquer et signaler", "P2", T, "Discussion avec un contact de test.",
  "1. Menu ⋮ → Bloquer.\n2. Menu ⋮ → Signaler, avec un motif.",
  "Bloqué : plus de messages ni d'appels de ce contact. Le signalement arrive dans la console (Signalements)."),
 ("Mode preuve", "P2", T, "Compte Pokou certifié, mode preuve activé sur la discussion.",
  "1. Envoyer un message puis le supprimer.\n2. Exporter en PDF.",
  "Le message supprimé reste visible barré. Le PDF est généré sur le téléphone."),
]),
("LST", "Liste des discussions", [
 ("Titre et ordre", "P1", T, "Plusieurs discussions.",
  "1. Ouvrir l'onglet Discussions.",
  "L'écran s'intitule « Discussions ». La plus récente est en haut, avec aperçu, heure et compteur de non-lus."),
 ("Filtres", "P2", T, "Discussions lues, non lues, groupes, favoris.",
  "1. Toucher Toutes, Non lues, Favoris, Groupes.",
  "Chaque filtre montre les bonnes discussions et son compteur est juste."),
 ("Épingler, couper le son, archiver", "P2", T, "—",
  "1. Appui long sur une discussion.\n2. Épingler, puis couper le son, puis archiver.",
  "Épinglée : reste en haut. Son coupé : plus de notification. Archivée : passe dans « Discussions archivées »."),
 ("Nouvelle discussion", "P1", T, "Contacts sur Pokou.",
  "1. Bouton rond en bas à droite.\n2. Choisir un contact.",
  "La discussion s'ouvre, prête à écrire."),
 ("Carte Baba", "P3", T, "—",
  "1. Toucher Traduire puis Résumer sur la carte Baba.",
  "L'assistant s'ouvre avec l'action demandée."),
 ("Liste vide", "P3", T, "Compte neuf sans discussion.",
  "1. Ouvrir Discussions.",
  "Une illustration et une invitation à démarrer s'affichent, pas un écran blanc."),
 ("Inviter un contact", "P2", T, "Contact sans Pokou.",
  "1. Inviter depuis la liste vide ou les contacts.",
  "La feuille de partage du téléphone s'ouvre avec un lien d'invitation."),
]),
("GRP", "Groupes, communautés et diffusion", [
 ("Créer un groupe", "P1", T, "Au moins 2 contacts sur Pokou.",
  "1. Nouveau groupe, nom, photo.\n2. Ajouter 2 membres.",
  "Le groupe est créé. Les invités reçoivent une invitation à accepter."),
 ("Accepter une invitation", "P1", T, "Invitation reçue.",
  "1. Accepter l'invitation.",
  "Le groupe apparaît dans les discussions."),
 ("Messages de groupe lisibles", "P1", T, "Groupe de 3 membres sur la version à tester.",
  "1. Chaque membre envoie 3 messages.\n2. Un membre ferme et rouvre l'app.",
  "Tous lisent tous les messages. Aucun « En attente de ce message… »."),
 ("Nouveau membre", "P1", T, "Groupe actif.",
  "1. Ajouter un 4e membre.\n2. Les anciens envoient des messages.",
  "Le nouveau membre lit les messages envoyés après son arrivée."),
 ("Membre qui quitte", "P2", T, "Groupe actif.",
  "1. Un membre quitte le groupe.\n2. Les autres continuent d'écrire.",
  "Celui qui est parti ne reçoit plus rien. Les autres voient son départ."),
 ("Médias en groupe", "P1", T, "Groupe actif.",
  "1. Envoyer photo, vidéo, document, note vocale, sticker.",
  "Chaque média arrive et s'ouvre chez tous les membres."),
 ("Mentions", "P2", T, "Groupe actif.",
  "1. Écrire @ et choisir un membre.\n2. Envoyer.",
  "Le membre cité est mis en évidence et reçoit une notification."),
 ("Seuls les admins écrivent", "P2", T, "Admin du groupe.",
  "1. Réglages du groupe → seuls les admins écrivent.\n2. Un simple membre essaie d'écrire.",
  "Le simple membre voit un message d'explication à la place de la barre de saisie."),
 ("Rôles", "P2", T, "Admin du groupe.",
  "1. Nommer un membre admin.\n2. Retirer un membre.",
  "Le nouvel admin peut gérer le groupe. Le membre retiré perd l'accès."),
 ("Messages éphémères", "P3", T, "Admin du groupe.",
  "1. Activer la disparition des messages.\n2. Envoyer un message et attendre le délai.",
  "Le message disparaît chez tous après le délai."),
 ("Pas de sondage en groupe", "P2", T, "Groupe ouvert.",
  "1. Ouvrir le menu trombone.",
  "L'entrée « Sondage » n'est pas proposée (fonction fermée en attendant les sondages chiffrés)."),
 ("Cagnotte depuis un groupe", "P2", T, "Kory ouvert dans le pays.",
  "1. Trombone → Créer une cagnotte.",
  "L'écran de création Kory s'ouvre, rattaché au groupe."),
 ("Lien d'invitation", "P2", T, "Admin du groupe.",
  "1. Créer un lien d'invitation et l'ouvrir sur un autre téléphone.",
  "Le lien ouvre l'app sur l'écran d'adhésion au groupe."),
 ("Communauté", "P2", T, "—",
  "1. Créer une communauté avec un groupe.\n2. Un membre rejoint par lien.\n3. Écrire dans « Annonces » comme admin puis comme membre.",
  "Le membre rejoint « Annonces ». Seuls les admins y publient ; les membres lisent."),
 ("Chaînes", "P3", T, "—",
  "1. Chercher une chaîne et s'abonner.\n2. Lire une publication.",
  "L'abonnement est pris en compte et les publications s'affichent."),
 ("Liste de diffusion", "P3", T, "Plus → Listes de diffusion.",
  "1. Créer une liste avec 2 contacts.\n2. Envoyer un message.",
  "Chaque destinataire reçoit le message dans sa discussion à deux."),
]),
("APL", "Appels", [
 ("Appel audio à deux", "P1", T, "A et B sur deux téléphones réels.",
  "1. A appelle B.\n2. B décroche.\n3. Parler 1 minute.",
  "A entend la tonalité d'attente. B voit le nom et la photo de A. Le son passe dans LES DEUX sens."),
 ("Son sur Android 15 et 16", "P1", A, "Au moins un téléphone Android 15 ou 16.",
  "1. Appel audio dans chaque sens.",
  "Chacun entend l'autre dès le décroché, sans silence."),
 ("Appel vidéo à deux", "P1", T, "Autorisation caméra.",
  "1. A lance un appel vidéo.\n2. Changer de caméra, couper la caméra, la remettre.",
  "L'image et le son passent. Les boutons répondent."),
 ("Haut-parleur, micro", "P2", T, "Appel en cours.",
  "1. Activer le haut-parleur.\n2. Couper puis rouvrir le micro.",
  "Le son change de sortie. Micro coupé : l'autre n'entend plus."),
 ("Appel sur réseau mobile", "P1", T, "A en 4G, B en Wi-Fi.",
  "1. A appelle B.\n2. Parler 2 minutes.",
  "L'appel s'établit et le son passe (le relais du serveur d'appels sert ici)."),
 ("Changement de réseau en appel", "P1", T, "Appel en cours en Wi-Fi.",
  "1. Couper le Wi-Fi pour passer en 4G.",
  "Un bandeau « reconnexion » s'affiche, puis l'appel reprend sans raccrocher ni se relancer."),
 ("Refuser, ne pas répondre", "P2", T, "—",
  "1. B refuse l'appel.\n2. A rappelle, B ne répond pas.",
  "A est informé du refus. Sans réponse, l'appel s'arrête seul et apparaît en manqué chez B."),
 ("Appel app fermée", "P1", T, "App de B fermée, écran verrouillé.",
  "1. A appelle B.",
  "Le téléphone de B sonne et affiche l'appel entrant avec le nom de A."),
 ("Appel de groupe", "P2", T, "Groupe de 3 membres.",
  "1. Lancer un appel de groupe.\n2. Deux membres rejoignent.",
  "L'appel affiche le nom et la photo du groupe. Les trois s'entendent."),
 ("Journal d'appels", "P2", T, "Appels passés, reçus et manqués.",
  "1. Plus → Appels.\n2. Rappeler depuis le journal et depuis la discussion.",
  "Chaque appel a son sens, sa durée et son heure. Le rappel fonctionne."),
 ("Appel pendant un autre appel", "P3", T, "Appel Pokou en cours.",
  "1. Un troisième contact appelle.",
  "L'appel en attente est signalé. Accepter bascule proprement, sans double sonnerie."),
 ("Mode silencieux", "P3", T, "Téléphone de B en silencieux, puis en vibreur.",
  "1. A appelle B.",
  "Silencieux : pas de sonnerie. Vibreur : vibration seulement."),
]),
("STA", "Statuts", [
 ("Statut en texte", "P1", T, "Onglet Discussions → Mon statut.",
  "1. Écrire un texte.\n2. Changer le fond (pastilles ou bouton palette) et la police (Aa).\n3. Publier.",
  "On arrive directement sur l'écriture. Le texte publié garde le fond et la police choisis, chez l'auteur et chez ses contacts."),
 ("Lisibilité sur tous les fonds", "P2", T, "Écran de statut en texte.",
  "1. Essayer les 8 fonds avec un texte court puis long.",
  "Le texte et les boutons restent lisibles sur chaque fond, y compris l'or et le crème."),
 ("Limite de 700 caractères", "P3", T, "Écran de statut en texte.",
  "1. Coller un texte très long.",
  "La saisie s'arrête à 700 caractères, un compteur apparaît vers la fin."),
 ("Statut photo et vidéo", "P1", T, "Autorisations photos et caméra.",
  "1. Bouton photo, choisir une image, ajouter une légende, publier.\n2. Recommencer avec une vidéo.",
  "Le statut s'affiche avec sa légende. La croix ramène à l'écriture sans publier."),
 ("Voir les statuts des contacts", "P1", T, "Un contact a publié.",
  "1. Toucher son cercle dans la bande des statuts.",
  "Le statut s'ouvre, la barre de progression avance, le cercle passe en « vu »."),
 ("Répondre à un statut", "P2", T, "Statut d'un contact ouvert.",
  "1. Écrire une réponse.",
  "La réponse arrive en privé dans la discussion à deux."),
 ("Qui a vu", "P2", T, "Statut publié et vu par un contact.",
  "1. Ouvrir son propre statut.\n2. Ouvrir la liste des vues.",
  "Le contact qui a vu apparaît."),
 ("Confidentialité des statuts", "P2", T, "Plus → Confidentialité → Qui voit mes statuts.",
  "1. Exclure un contact.\n2. Publier un statut.",
  "Le contact exclu ne voit pas le statut."),
 ("Expiration", "P3", T, "Statut publié il y a plus de 24 h.",
  "1. Regarder la bande des statuts.",
  "Le statut a disparu."),
 ("Échec de publication", "P2", T, "Mode avion.",
  "1. Publier un statut.",
  "Un message dit que la publication a échoué. Le texte reste à l'écran pour réessayer."),
]),
("NOT", "Notifications", [
 ("Message, app fermée", "P1", T, "App de B fermée.",
  "1. A envoie un message.",
  "B reçoit une notification. La toucher ouvre la bonne discussion."),
 ("Message de groupe", "P1", T, "App fermée.",
  "1. Un membre écrit dans un groupe.",
  "La notification indique le groupe et ouvre le groupe."),
 ("Contenu protégé", "P2", T, "—",
  "1. Lire le texte de la notification sur l'écran verrouillé.",
  "Le texte affiché suit le réglage de confidentialité des notifications."),
 ("Son coupé", "P2", T, "Discussion en sourdine.",
  "1. Recevoir un message dans cette discussion.",
  "Aucune notification sonore."),
 ("Notifications iPhone", "P1", I, "Clé APNs configurée dans Firebase. Sinon : Bloqué.",
  "1. App fermée, recevoir un message puis un appel.",
  "Notification du message et sonnerie de l'appel."),
 ("Réglages de notification", "P3", T, "Plus → Notifications.",
  "1. Désactiver puis réactiver les notifications de messages.",
  "Le réglage est respecté."),
]),
("SAV", "Sauvegarde et restauration", [
 ("Choix de la destination", "P2", A, "Plus → sauvegarde.",
  "1. Choisir Google Drive, puis Pokou.",
  "Le choix est mémorisé. Google Drive demande le compte Google."),
 ("Sauvegarde sur Pokou", "P1", T, "Mot de passe de sauvegarde défini.",
  "1. Sauvegarder maintenant.",
  "La sauvegarde aboutit, avec la date et le nombre de discussions."),
 ("Sauvegarde Google Drive", "P1", A, "Identifiants Google configurés pour l'app. Sinon : Bloqué.",
  "1. Choisir un compte Google.\n2. Sauvegarder maintenant.",
  "La sauvegarde aboutit. Aucun fichier Pokou n'est visible dans Google Drive (dossier caché)."),
 ("Restauration sur un nouveau téléphone", "P1", T, "Sauvegarde existante. App installée sur un autre téléphone.",
  "1. Se connecter au compte.\n2. Accepter la restauration et saisir le mot de passe.",
  "Les discussions et leurs messages reviennent, lisibles."),
 ("Mauvais mot de passe", "P2", T, "Écran de restauration.",
  "1. Saisir un mot de passe faux.",
  "La restauration est refusée avec un message clair, sans rien effacer."),
 ("Supprimer la sauvegarde", "P3", T, "Sauvegarde existante.",
  "1. Supprimer la sauvegarde.",
  "Elle n'est plus proposée à la restauration."),
]),
("KOR", "Kory (cagnottes et tontines)", [
 ("Créer une cagnotte", "P1", T, "Onglet Kory.",
  "1. Créer une cagnotte avec titre, objectif et échéance.",
  "La cagnotte apparaît dans « Mes cagnottes » avec son code pour rejoindre."),
 ("Rejoindre par code", "P1", T, "Code d'une cagnotte d'un autre compte.",
  "1. Kory → Rejoindre.\n2. Saisir le code.",
  "La cagnotte s'ouvre, le participant y est rattaché."),
 ("Déclarer une contribution", "P1", T, "Participant d'une cagnotte.",
  "1. Déclarer un montant, avec la preuve si demandée.",
  "La contribution apparaît « à confirmer » chez l'organisateur."),
 ("Confirmer une contribution", "P1", T, "Organisateur, contribution déclarée.",
  "1. Confirmer la contribution.",
  "Le total confirmé et la progression augmentent, chez tous."),
 ("Contester une contribution", "P2", T, "Organisateur, contribution déclarée.",
  "1. Refuser la contribution.\n2. Le participant la redéclare.",
  "Elle est marquée contestée, puis peut être soumise de nouveau."),
 ("Promesse de don", "P2", T, "Cagnotte ouverte.",
  "1. Promettre un montant.",
  "La promesse apparaît dans le suivi, distincte de l'argent confirmé."),
 ("Inviter par SMS", "P2", T, "Contact sans Pokou.",
  "1. Ajouter ce contact à la création de la cagnotte.",
  "Il reçoit une invitation par SMS et retrouve la cagnotte en s'inscrivant."),
 ("Prolonger l'échéance", "P3", T, "Organisateur, cagnotte proche de l'échéance.",
  "1. Prolonger la cagnotte.",
  "La nouvelle échéance s'affiche chez tous."),
 ("Tontine en rotation", "P2", T, "Kory Plus ouvert dans le pays.",
  "1. Créer une tontine avec montant par membre et période.",
  "Les tours s'affichent avec le bénéficiaire de chaque tour."),
 ("Journal", "P3", T, "Cagnotte avec de l'activité.",
  "1. Ouvrir le journal.",
  "Chaque action est listée avec sa date et son auteur."),
 ("Message « Pokou ne touche pas l'argent »", "P2", T, "Écran Kory.",
  "1. Lire les mentions de l'écran.",
  "Il est écrit clairement que l'argent passe de wallet à wallet, sans Pokou."),
 ("Clôturer", "P2", T, "Organisateur.",
  "1. Clôturer la cagnotte.",
  "Elle passe en clôturée, plus de contribution possible."),
]),
("HON", "Honam (pharmacie)", [
 ("Ouverture sans demande de position", "P1", T, "Autorisation de position jamais accordée.",
  "1. Ouvrir l'onglet Honam.",
  "Aucune fenêtre de demande de position ne s'ouvre à ce moment."),
 ("Envoyer une ordonnance", "P1", T, "Au moins une pharmacie partenaire. Sinon : Bloqué.",
  "1. Photographier l'ordonnance.\n2. Choisir la pharmacie et l'adresse.\n3. Envoyer.",
  "La position est demandée à cette étape. La commande est créée et suivie."),
 ("Devis et paiement", "P1", T, "Commande envoyée, devis reçu.",
  "1. Ouvrir le devis.\n2. Payer.",
  "Le montant est clair (produits, livraison). Le paiement fait avancer la commande."),
 ("Suivi de livraison", "P2", T, "Commande confiée à un coursier.",
  "1. Ouvrir la commande pendant la course.",
  "L'étape et la position du coursier sont visibles."),
 ("Numéros d'urgence", "P1", T, "—",
  "1. Toucher Police, Pompiers, SAMU.",
  "Le composeur du téléphone s'ouvre avec le bon numéro du pays."),
 ("Aucune pharmacie", "P3", T, "Pays sans pharmacie partenaire.",
  "1. Ouvrir Honam.",
  "« Aucune pharmacie partenaire pour l'instant » s'affiche, sans erreur."),
 ("Devenir coursier", "P2", T, "Plus → Devenir coursier Honam.",
  "1. Remplir la candidature.",
  "La candidature part. Elle apparaît dans la console (Honam → coursiers à valider)."),
 ("Mode sombre", "P3", T, "Thème sombre.",
  "1. Ouvrir Honam.",
  "L'en-tête est sombre et le bouton « Photographier l'ordonnance » est lisible."),
]),
("ASS", "Assimé (annonces)", [
 ("Publier une annonce simple", "P1", T, "Plus → Assimé.",
  "1. Publier une annonce.\n2. Saisir nom et prix SANS toucher à Devise ni à Catégorie.\n3. Enregistrer.",
  "L'annonce est publiée et apparaît dans « Mes annonces » et dans le marché."),
 ("Publier avec photos", "P1", T, "—",
  "1. Ajouter une photo principale et 3 autres photos.\n2. Enregistrer.",
  "Les photos s'envoient. L'annonce s'affiche avec sa photo principale et sa galerie."),
 ("Catégorie", "P1", T, "—",
  "1. Publier une annonce dans « Téléphones ».\n2. Filtrer le marché sur « Téléphones ».",
  "L'annonce apparaît sous ce filtre."),
 ("Prix écrit librement", "P2", T, "Formulaire d'annonce.",
  "1. Saisir « 5 000 », puis « 2,5 », puis « abc ».",
  "Les deux premiers sont acceptés. « abc » est refusé avec un message clair."),
 ("Publication sans GPS", "P1", T, "Position désactivée ou sans signal.",
  "1. Enregistrer une annonce.",
  "L'annonce part en quelques secondes, sans rester bloquée."),
 ("Échec réseau à la publication", "P1", T, "Formulaire rempli, puis mode avion.",
  "1. Enregistrer.\n2. Réactiver le réseau et réenregistrer.",
  "Un message dit que rien n'est perdu. Le formulaire reste ouvert avec la saisie. Le second essai publie."),
 ("Médicament refusé", "P2", T, "—",
  "1. Publier une annonce dans une catégorie de médicaments.",
  "Refus avec renvoi vers Honam."),
 ("Modifier et supprimer", "P2", T, "Annonce publiée.",
  "1. Modifier le prix.\n2. Supprimer l'annonce.",
  "Le prix change. L'annonce supprimée disparaît du marché et de « Mes annonces »."),
 ("Recherche et filtres", "P2", T, "Plusieurs annonces.",
  "1. Chercher un mot.\n2. Filtrer par catégorie et par zone.",
  "Les résultats correspondent."),
 ("Contacter le vendeur", "P1", T, "Annonce d'un autre compte.",
  "1. Ouvrir l'annonce.\n2. Écrire au vendeur.",
  "La discussion s'ouvre avec la fiche du produit épinglée."),
 ("Marquer comme vendu et noter", "P2", T, "Annonce avec un acheteur en discussion.",
  "1. Le vendeur marque l'annonce vendue et désigne l'acheteur.\n2. L'acheteur note le vendeur.",
  "L'annonce passe en vendue. Seul l'acheteur désigné peut noter."),
 ("Favoris et alertes", "P3", T, "—",
  "1. Mettre une annonce en favori.\n2. Créer une alerte, puis publier une annonce qui y répond depuis un autre compte.",
  "Le favori est retrouvé. L'alerte déclenche une notification."),
 ("Vendeur vérifié", "P2", T, "—",
  "1. Demander le badge vendeur vérifié avec une pièce d'identité.\n2. Choisir la formule.",
  "Les formules affichent 3 000 FCFA (mensuel) et 30 000 FCFA (annuel). Le dossier apparaît dans la console (Assimé)."),
 ("Ancienne version de l'app", "P2", A, "Un téléphone resté en version 1.28.0 ou antérieure.",
  "1. Publier une annonce.",
  "La publication aboutit aussi (le serveur accepte l'ancien format)."),
]),
("CER", "Pokou certifié", [
 ("Essai d'un mois", "P2", T, "Compte jamais certifié.",
  "1. Plus → Pokou certifié → démarrer l'essai.",
  "L'essai démarre, le badge apparaît à côté du nom."),
 ("Dossier Pro", "P2", T, "Compte certifié.",
  "1. Déposer un dossier Pro avec justificatif.",
  "Le dossier part. Il apparaît dans la console (Pokou certifié)."),
 ("Correction demandée", "P3", T, "Dossier renvoyé « à corriger » depuis la console.",
  "1. Ouvrir Pokou certifié.",
  "Le motif de correction s'affiche, le dossier peut être redéposé."),
 ("Fin d'abonnement", "P3", T, "Abonnement expiré depuis plus de 7 jours.",
  "1. Regarder le profil.",
  "Le badge est en pause."),
]),
("MOD", "Modules et Baba", [
 ("Catalogue des modules", "P2", T, "Plus → Modules.",
  "1. Ouvrir le catalogue.",
  "Les modules ouverts s'affichent, avec les recommandés."),
 ("Activer et désactiver", "P2", T, "—",
  "1. Activer un module.\n2. L'ouvrir.\n3. Le désactiver.",
  "Le module activé s'ouvre. Désactivé, il sort de « Mes modules »."),
 ("Module fermé par l'équipe", "P2", T, "Un module fermé depuis la console.",
  "1. Rouvrir le catalogue.",
  "Le module fermé n'apparaît plus."),
 ("Chaque module s'ouvre", "P2", T, "Tous les modules activés.",
  "1. Ouvrir Ligue des cœurs, Série de flammes, Marché de la vérité, Taxe sociale, Salon VIP, Hype Train, Spark, Versets.",
  "Chaque écran s'ouvre sans erreur. Sans données : une illustration et un texte d'explication."),
 ("Spark réservé aux adultes", "P2", T, "—",
  "1. Ouvrir Spark sans position, puis avec.",
  "Spark demande l'âge et la position, et explique pourquoi."),
 ("Assistant Baba", "P2", T, "Compte assistant rattaché si demandé.",
  "1. Poser une question à Baba.\n2. Demander un résumé et une traduction.",
  "Baba répond. Sans compte rattaché, l'app propose de le rattacher."),
]),
("REG", "Réglages, affichage et accessibilité", [
 ("Thème sombre au lancement", "P1", T, "Téléphone en sombre.",
  "1. Ouvrir l'app et parcourir Accueil, Discussions, une discussion, Kory, Honam, Plus, Assimé.",
  "Tout est en sombre et lisible. Aucune carte blanche au texte invisible."),
 ("Changer de thème en cours d'utilisation", "P1", T, "App ouverte sur l'onglet Plus.",
  "1. Passer le téléphone de clair à sombre (ou Plus → Apparence).\n2. Revenir dans l'app sans la fermer.",
  "Tous les écrans changent tout de suite, y compris Plus et Honam."),
 ("Très grande taille de texte", "P1", T, "Taille de police du téléphone au maximum.",
  "1. Parcourir Accueil, Discussions, une discussion, Plus.",
  "Le texte grossit sans se chevaucher ni être coupé. Aucune bande jaune et noire."),
 ("Langue", "P2", T, "Plus → Langue.",
  "1. Passer en anglais, puis en arabe.",
  "L'interface change de langue. En arabe, elle s'affiche de droite à gauche."),
 ("Lecteur d'écran", "P2", T, "TalkBack (Android) ou VoiceOver (iPhone) activé.",
  "1. Parcourir l'accueil et envoyer un message au lecteur d'écran.",
  "Chaque bouton est annoncé par un nom compréhensible."),
 ("Verrouillage de l'app", "P2", T, "Code de verrouillage activé.",
  "1. Quitter l'app et y revenir.",
  "Le code est demandé avant d'afficher quoi que ce soit."),
 ("Confidentialité", "P2", T, "Plus → Confidentialité.",
  "1. Masquer « vu à » et la photo de profil aux inconnus.",
  "Les autres comptes voient ce que le réglage autorise."),
 ("Stockage et données", "P3", T, "Plus → Stockage et données.",
  "1. Regarder l'espace par discussion.\n2. Désactiver le téléchargement automatique en données mobiles.",
  "L'espace s'affiche. En 4G, les médias ne se téléchargent plus tout seuls."),
 ("Profil", "P2", T, "Plus → Modifier.",
  "1. Changer le nom, la photo, la phrase d'état.",
  "Les contacts voient le changement sans relancer l'app."),
 ("À propos", "P3", T, "Plus → À propos de Pokou.",
  "1. Lire la version.",
  "La version affichée est celle du fichier installé."),
]),
("ROB", "Robustesse et performances", [
 ("Téléphone d'entrée de gamme", "P1", A, "Android avec 2 à 3 Go de mémoire.",
  "1. Démarrer l'app.\n2. Faire défiler une longue discussion et la liste des discussions.",
  "Démarrage en quelques secondes. Défilement fluide, sans saccades marquées."),
 ("Réseau faible", "P1", T, "2G/3G ou réseau instable.",
  "1. Envoyer des textes, une photo, une note vocale.",
  "Les textes passent. Les médias attendent puis partent, sans doublon."),
 ("Coupure réseau", "P1", T, "App ouverte.",
  "1. Passer en mode avion 1 minute.\n2. Revenir.",
  "L'app indique l'absence de réseau, puis se resynchronise seule."),
 ("App en arrière-plan", "P2", T, "Discussion ouverte.",
  "1. Passer sur une autre app 10 minutes.\n2. Revenir.",
  "La discussion est à jour, sans écran blanc ni reconnexion manuelle."),
 ("Rotation et petits écrans", "P3", T, "Petit téléphone (5 pouces) ou tablette.",
  "1. Parcourir les écrans principaux.",
  "Rien n'est coupé ni superposé."),
 ("Mise à jour par-dessus", "P1", A, "Version précédente installée avec des discussions.",
  "1. Installer le fichier « testeurs-mise-a-jour » par-dessus.",
  "L'installation réussit sans désinstaller. Les discussions sont là et lisibles."),
 ("Autonomie", "P3", T, "Téléphone chargé à 100 %.",
  "1. Utilisation normale pendant 1 heure, dont 10 minutes d'appel.",
  "Pas de chauffe ni de décharge anormale."),
]),
("CON", "Console d'administration", [
 ("Connexion par e-mail", "P1", C, "Compte d'équipe avec e-mail et mot de passe.",
  "1. Ouvrir /console/.\n2. Saisir e-mail et mot de passe.",
  "Le tableau de bord s'ouvre. Aucun champ numéro de téléphone n'est proposé."),
 ("Mot de passe faux et blocage", "P1", C, "—",
  "1. Saisir 5 mots de passe faux.\n2. Saisir le bon.",
  "Chaque essai faux est refusé. Après le 5e, le compte est bloqué 15 minutes, même avec le bon mot de passe."),
 ("Changer son mot de passe", "P1", C, "Connecté.",
  "1. Icône clé en bas du menu.\n2. Saisir l'actuel et un nouveau de 12 caractères.",
  "Le nouveau mot de passe fonctionne, l'ancien non."),
 ("Compte sans rôle", "P1", C, "Un compte utilisateur ordinaire.",
  "1. Essayer de se connecter à la console.",
  "Accès refusé."),
 ("Tableau de bord", "P2", C, "Connecté.",
  "1. Lire les cartes.\n2. Passer l'activité sur 7 jours, 30 jours, 3 mois.",
  "Les chiffres s'affichent et le graphique suit la période."),
 ("Rechercher un utilisateur", "P2", C, "Droit « voir les utilisateurs ».",
  "1. Chercher par nom puis par numéro.\n2. Filtrer par statut et par rôle.\n3. Ouvrir une fiche.",
  "Les résultats correspondent. La fiche montre l'activité, jamais le contenu des messages."),
 ("Suspendre et réactiver", "P1", C, "Droit de suspension. Un compte de test connecté sur un téléphone.",
  "1. Suspendre le compte avec un motif.\n2. Regarder le téléphone.\n3. Réactiver.",
  "Le téléphone est déconnecté tout de suite. Réactivé, le compte peut se reconnecter. Les deux actions sont au journal d'audit."),
 ("Signalements", "P1", C, "Un signalement fait depuis l'app.",
  "1. Ouvrir Signalements.\n2. Classer un signalement.\n3. En sanctionner un autre.",
  "Le signalement apparaît avec son motif. Sanctionner suspend le compte et règle ses autres signalements ouverts."),
 ("Ajouter un membre", "P1", C, "Super-administrateur.",
  "1. Équipe et rôles → Ajouter : nom, e-mail, rôle.\n2. Noter le mot de passe provisoire.\n3. Se connecter avec ce compte.",
  "Le mot de passe provisoire s'affiche une seule fois. Le nouveau membre se connecte avec."),
 ("Nouveau mot de passe d'un membre", "P2", C, "Super-administrateur.",
  "1. Toucher « Nouveau mot de passe » sur un membre.",
  "Un nouveau mot de passe provisoire s'affiche. L'ancien ne fonctionne plus."),
 ("Droits par rôle", "P1", C, "Un compte par rôle : Admin, Support, Opérateur IA, Lecture seule.",
  "1. Se connecter avec chaque rôle.\n2. Comparer le menu avec le tableau « Ce que chaque rôle permet ».",
  "Chaque rôle ne voit que ses pages. Une page interdite ouverte par son adresse affiche « Accès refusé »."),
 ("Dernier super-administrateur", "P2", C, "Un seul super-administrateur.",
  "1. Essayer de changer son propre rôle.",
  "Refus : il faut garder au moins un super-administrateur."),
 ("Modules", "P2", C, "Droit modules.",
  "1. Fermer un module.\n2. Le rouvrir.\n3. Le recommander.",
  "L'app suit : le module disparaît du catalogue, puis revient."),
 ("Dossiers Assimé", "P2", C, "Un dossier vendeur vérifié en attente.",
  "1. Ouvrir la pièce d'identité.\n2. Refuser avec un motif, puis approuver un autre dossier.",
  "Le vendeur reçoit le motif ou le badge."),
 ("Dossiers Pokou certifié", "P2", C, "Un dossier Pro en attente.",
  "1. Approuver, demander une correction, refuser.",
  "Une correction ou un refus exige un message. Le dossier quitte la file."),
 ("Coursiers Honam", "P2", C, "Une candidature de coursier.",
  "1. Honam → Coursiers à valider → Valider.",
  "Le coursier est validé et sort de la liste."),
 ("Journal d'audit", "P2", C, "Droit audit.",
  "1. Faire une suspension, puis ouvrir le journal.",
  "L'action apparaît avec son auteur, sa date et le motif."),
 ("Session de 8 heures", "P3", C, "Connecté depuis plus de 8 heures.",
  "1. Cliquer sur une page.",
  "La console renvoie à l'écran de connexion."),
 ("Affichage téléphone et sombre", "P3", C, "Navigateur de téléphone, puis thème sombre.",
  "1. Parcourir les pages.",
  "Le menu se replie, les tableaux restent lisibles."),
]),
]

wb = Workbook()
ARIAL = "Arial"
thin = Side(style="thin", color="D9CFC5")
BORDER = Border(left=thin, right=thin, top=thin, bottom=thin)
HEAD_FILL = PatternFill("solid", fgColor="7F3D1E")
FILL_IN = PatternFill("solid", fgColor="FFF2CC")
BAND = PatternFill("solid", fgColor="FBF7F2")
WRAP = Alignment(wrap_text=True, vertical="top")
CENTER = Alignment(horizontal="center", vertical="center", wrap_text=True)


def head(ws, row, labels, fill=HEAD_FILL, color="FFFFFF"):
    for col, label in enumerate(labels, 1):
        c = ws.cell(row=row, column=col, value=label)
        c.font = Font(name=ARIAL, bold=True, color=color, size=10)
        c.fill = fill
        c.alignment = CENTER
        c.border = BORDER


# ── Cas de test ─────────────────────────────────────────────────────────
cases = wb.active
cases.title = "Cas de test"
COLS = ["ID", "Module", "Fonctionnalité", "Priorité", "Plateforme", "Préconditions", "Étapes",
        "Résultat attendu", "Statut", "Testeur", "Date du test", "Appareil et version", "N° anomalie", "Commentaire"]
head(cases, 1, COLS)
for col in range(9, 15):  # colonnes à remplir
    c = cases.cell(row=1, column=col)
    c.fill = FILL_IN
    c.font = Font(name=ARIAL, bold=True, color="7F3D1E", size=10)
row = 2
for prefix, module, items in MODULES:
    for n, (feature, prio, platform, pre, steps, expected) in enumerate(items, 1):
        values = [f"{prefix}-{n:02d}", module, feature, prio, platform, pre, steps, expected, "Non testé", "", "", "", "", ""]
        for col, value in enumerate(values, 1):
            c = cases.cell(row=row, column=col, value=value)
            c.font = Font(name=ARIAL, size=10, bold=(col == 1))
            c.alignment = CENTER if col in (1, 4, 5, 9, 11) else WRAP
            c.border = BORDER
        row += 1
LAST = row - 1
for col, width in enumerate([9, 22, 26, 8, 13, 34, 48, 48, 12, 14, 12, 22, 12, 30], 1):
    cases.column_dimensions[get_column_letter(col)].width = width
cases.freeze_panes = "D2"
cases.auto_filter.ref = f"A1:N{LAST}"
cases.row_dimensions[1].height = 30
status_dv = DataValidation(type="list", formula1='"Non testé,OK,KO,Bloqué,Sans objet"', allow_blank=False)
status_dv.error = "Choisir : Non testé, OK, KO, Bloqué ou Sans objet"
cases.add_data_validation(status_dv)
status_dv.add(f"I2:I{LAST}")
prio_dv = DataValidation(type="list", formula1='"P1,P2,P3"', allow_blank=False)
cases.add_data_validation(prio_dv)
prio_dv.add(f"D2:D{LAST}")
rng = f"I2:I{LAST}"
for value, color in (("OK", "C6EFCE"), ("KO", "FFC7CE"), ("Bloqué", "FFE699"), ("Sans objet", "E7E6E6")):
    cases.conditional_formatting.add(rng, CellIsRule(operator="equal", formula=[f'"{value}"'], fill=PatternFill("solid", bgColor=color, fgColor=color)))
cases.conditional_formatting.add(f"D2:D{LAST}", CellIsRule(operator="equal", formula=['"P1"'], font=Font(name=ARIAL, bold=True, color="B3261E")))

# ── Synthèse ────────────────────────────────────────────────────────────
syn = wb.create_sheet("Synthèse", 0)
syn["A1"] = "Plan de test Pokou — synthèse"
syn["A1"].font = Font(name=ARIAL, bold=True, size=16, color="7F3D1E")
syn["A2"] = f"Version à tester : {VERSION}. Cette feuille se calcule seule à partir de « Cas de test »."
syn["A2"].font = Font(name=ARIAL, size=10, color="6B5E57")
SH = ["Module", "Cas", "dont P1", "OK", "KO", "Bloqué", "Sans objet", "Non testé", "Avancement", "Réussite"]
head(syn, 4, SH)
ref = "'Cas de test'"
r = 5
for _, module, _items in MODULES:
    syn.cell(row=r, column=1, value=module)
    syn.cell(row=r, column=2, value=f'=COUNTIF({ref}!$B$2:$B${LAST},$A{r})')
    syn.cell(row=r, column=3, value=f'=COUNTIFS({ref}!$B$2:$B${LAST},$A{r},{ref}!$D$2:$D${LAST},"P1")')
    for col, status in ((4, "OK"), (5, "KO"), (6, "Bloqué"), (7, "Sans objet"), (8, "Non testé")):
        syn.cell(row=r, column=col, value=f'=COUNTIFS({ref}!$B$2:$B${LAST},$A{r},{ref}!$I$2:$I${LAST},"{status}")')
    syn.cell(row=r, column=9, value=f'=IF(B{r}=0,0,(B{r}-H{r})/B{r})')
    syn.cell(row=r, column=10, value=f'=IF((D{r}+E{r})=0,0,D{r}/(D{r}+E{r}))')
    r += 1
FIRST, END = 5, r - 1
syn.cell(row=r, column=1, value="Total")
for col in range(2, 9):
    L = get_column_letter(col)
    syn.cell(row=r, column=col, value=f"=SUM({L}{FIRST}:{L}{END})")
syn.cell(row=r, column=9, value=f'=IF(B{r}=0,0,(B{r}-H{r})/B{r})')
syn.cell(row=r, column=10, value=f'=IF((D{r}+E{r})=0,0,D{r}/(D{r}+E{r}))')
TOTAL = r
for rr in range(FIRST, TOTAL + 1):
    for col in range(1, 11):
        c = syn.cell(row=rr, column=col)
        c.font = Font(name=ARIAL, size=10, bold=(rr == TOTAL))
        c.border = BORDER
        c.alignment = Alignment(horizontal="left" if col == 1 else "center", vertical="center")
        if rr == TOTAL:
            c.fill = BAND
    syn.cell(row=rr, column=9).number_format = "0%"
    syn.cell(row=rr, column=10).number_format = "0%"
r = TOTAL + 2
syn.cell(row=r, column=1, value="Cas P1 en échec (KO)").font = Font(name=ARIAL, bold=True, size=10)
syn.cell(row=r, column=2, value=f'=COUNTIFS({ref}!$D$2:$D${LAST},"P1",{ref}!$I$2:$I${LAST},"KO")').font = Font(name=ARIAL, bold=True, size=10)
syn.cell(row=r + 1, column=1, value="Cas P1 non testés").font = Font(name=ARIAL, bold=True, size=10)
syn.cell(row=r + 1, column=2, value=f'=COUNTIFS({ref}!$D$2:$D${LAST},"P1",{ref}!$I$2:$I${LAST},"Non testé")').font = Font(name=ARIAL, bold=True, size=10)
syn.cell(row=r + 2, column=1, value="Anomalies ouvertes").font = Font(name=ARIAL, bold=True, size=10)
syn.cell(row=r + 2, column=2, value='=COUNTIFS(Anomalies!$M$2:$M$500,"Ouverte",Anomalies!$A$2:$A$500,"<>ANO-000")+COUNTIFS(Anomalies!$M$2:$M$500,"En cours",Anomalies!$A$2:$A$500,"<>ANO-000")').font = Font(name=ARIAL, bold=True, size=10)
syn.cell(row=r + 4, column=1, value="Critère de sortie proposé : aucun cas P1 en KO ni non testé, et aucune anomalie bloquante ou majeure ouverte.").font = Font(name=ARIAL, italic=True, size=10, color="6B5E57")
syn.column_dimensions["A"].width = 40
for col in range(2, 11):
    syn.column_dimensions[get_column_letter(col)].width = 13
syn.conditional_formatting.add(f"E{FIRST}:E{TOTAL}", CellIsRule(operator="greaterThan", formula=["0"], font=Font(name=ARIAL, bold=True, color="B3261E")))
syn.freeze_panes = "A5"

# ── Lisez-moi ───────────────────────────────────────────────────────────
info = wb.create_sheet("Lisez-moi", 0)
lines = [
    ("Plan de test Pokou", "title"),
    (f"Version à tester : {VERSION} — plan établi le 11 novembre 2026.", "sub"),
    ("", None),
    ("À quoi sert ce classeur", "h"),
    ("Il liste ce qu'il faut vérifier avant de publier Pokou : l'app Android et iPhone, et la console d'administration. Chaque ligne de « Cas de test » est une vérification à faire sur un vrai téléphone.", None),
    ("", None),
    ("Ce qu'il faut pour tester", "h"),
    ("Application Android : le fichier pokou-v1.28.1+50-testeurs-mise-a-jour.apk (se met à jour par-dessus une version déjà installée) ou pokou-v1.28.1+50-universal-release.apk (nouvelle installation).", None),
    ("Serveur : https://apipokou.cabinet-p-et-associes.com — console : https://apipokou.cabinet-p-et-associes.com/console/", None),
    ("Au moins deux téléphones et deux comptes (A et B) ; trois pour les groupes et les appels de groupe. Un compte = un numéro de téléphone qui reçoit les SMS.", None),
    ("Pour la console : un compte d'équipe par rôle, créé par un super-administrateur (Équipe et rôles → Ajouter).", None),
    ("", None),
    ("Comment remplir « Cas de test »", "h"),
    ("Ne remplir que les colonnes à en-tête jaune : Statut, Testeur, Date du test, Appareil et version, N° anomalie, Commentaire. Ne pas modifier les autres colonnes.", None),
    ("Statut — OK : le résultat attendu est obtenu. KO : il ne l'est pas (ouvrir une ligne dans « Anomalies » et reporter son numéro). Bloqué : le test ne peut pas être fait (dire pourquoi en commentaire). Sans objet : ne s'applique pas à cet appareil.", None),
    ("Exemple de ligne remplie — Statut : KO · Testeur : Afi · Date : 12/11/2026 · Appareil : Tecno Spark 10, Android 13 · N° anomalie : ANO-001 · Commentaire : le son ne passe que dans un sens.", None),
    ("La feuille « Synthèse » se met à jour toute seule. Les filtres de la première ligne permettent de n'afficher qu'un module, une priorité ou un statut.", None),
    ("", None),
    ("Priorités", "h"),
    ("P1 : indispensable. Un échec empêche la publication. À tester en premier, sur chaque appareil.", None),
    ("P2 : important. À tester sur au moins un Android et un iPhone.", None),
    ("P3 : confort. À tester une fois.", None),
    ("", None),
    ("Gravité d'une anomalie", "h"),
    ("Bloquante : l'app plante, perd des données ou une fonction P1 est inutilisable. Majeure : une fonction marche mal, sans contournement simple. Mineure : gêne avec contournement. Cosmétique : défaut d'affichage sans effet sur l'usage.", None),
    ("", None),
    ("Points d'attention de cette version", "h"),
    ("Messages lisibles : aucun message ne doit rester sur « En attente de ce message… » (cas MSG-03, GRP-03, INS-11).", None),
    ("Son des appels dans les deux sens, surtout sur Android 15 et 16 (cas APL-01, APL-02, APL-05).", None),
    ("Publication d'une annonce Assimé (cas ASS-01 à ASS-06).", None),
    ("Nouvel accueil, statut en texte, clavier d'emojis (cas NAV-01, STA-01, MSG-10).", None),
    ("", None),
    ("Limites connues, à ne pas signaler comme anomalies", "h"),
    ("Sondages dans les groupes : fermés pour l'instant. Sauvegarde Google Drive et notifications iPhone : dépendent de réglages Google et Apple à faire ; tant qu'ils ne le sont pas, marquer ces cas « Bloqué ».", None),
    ("Passer d'un fichier « testeurs » au fichier « universal-release » (ou à la version du Play Store) oblige à désinstaller : la signature change.", None),
]
for i, (text, kind) in enumerate(lines, 1):
    c = info.cell(row=i, column=1, value=text)
    c.alignment = Alignment(wrap_text=True, vertical="top")
    if kind == "title":
        c.font = Font(name=ARIAL, bold=True, size=18, color="7F3D1E")
    elif kind == "sub":
        c.font = Font(name=ARIAL, size=11, color="6B5E57")
    elif kind == "h":
        c.font = Font(name=ARIAL, bold=True, size=12, color="1A1615")
        c.fill = BAND
    else:
        c.font = Font(name=ARIAL, size=10)
info.column_dimensions["A"].width = 130

# ── Anomalies ───────────────────────────────────────────────────────────
bugs = wb.create_sheet("Anomalies")
BH = ["N°", "Date", "Cas de test", "Module", "Titre", "Étapes pour reproduire", "Résultat obtenu", "Résultat attendu",
      "Gravité", "Appareil et version d'Android / iOS", "Version de l'app", "Capture ou vidéo", "Statut", "Corrigée en version", "Commentaire"]
head(bugs, 1, BH)
example = ["ANO-000", "12/11/2026", "APL-01", "Appels", "EXEMPLE (à supprimer) — Le son ne passe que dans un sens",
           "1. A (Tecno) appelle B (Samsung).\n2. B décroche.", "B entend A, A n'entend pas B.", "Les deux s'entendent.",
           "Bloquante", "Tecno Spark 10, Android 13", "1.28.1 (50)", "video-apl01.mp4", "Ouverte", "", "Reproduit 3 fois sur 3."]
for col, value in enumerate(example, 1):
    c = bugs.cell(row=2, column=col, value=value)
    c.font = Font(name=ARIAL, size=10, italic=True, color="6B5E57")
    c.alignment = WRAP
    c.border = BORDER
for rr in range(3, 201):
    for col in range(1, 16):
        c = bugs.cell(row=rr, column=col)
        c.font = Font(name=ARIAL, size=10)
        c.alignment = WRAP
        c.border = BORDER
for col, width in enumerate([10, 12, 12, 18, 34, 40, 34, 34, 12, 26, 14, 20, 12, 14, 30], 1):
    bugs.column_dimensions[get_column_letter(col)].width = width
bugs.freeze_panes = "E2"
bugs.auto_filter.ref = "A1:O200"
sev = DataValidation(type="list", formula1='"Bloquante,Majeure,Mineure,Cosmétique"', allow_blank=True)
st = DataValidation(type="list", formula1='"Ouverte,En cours,Corrigée,Vérifiée,Rejetée"', allow_blank=True)
bugs.add_data_validation(sev)
bugs.add_data_validation(st)
sev.add("I2:I200")
st.add("M2:M200")
bugs.conditional_formatting.add("I2:I200", CellIsRule(operator="equal", formula=['"Bloquante"'], fill=PatternFill("solid", bgColor="FFC7CE", fgColor="FFC7CE")))
bugs.conditional_formatting.add("I2:I200", CellIsRule(operator="equal", formula=['"Majeure"'], fill=PatternFill("solid", bgColor="FFE699", fgColor="FFE699")))
bugs.conditional_formatting.add("A2:O200", FormulaRule(formula=['$M2="Vérifiée"'], font=Font(name=ARIAL, color="808080")))

# ── Appareils ───────────────────────────────────────────────────────────
dev = wb.create_sheet("Appareils")
DH = ["Profil à couvrir", "Pourquoi", "Appareil utilisé (marque, modèle)", "Système", "Réseau testé", "Testeur", "Cas P1 passés (date)"]
head(dev, 1, DH)
for col in range(3, 8):
    c = dev.cell(row=1, column=col)
    c.fill = FILL_IN
    c.font = Font(name=ARIAL, bold=True, color="7F3D1E", size=10)
profiles = [
    ("Android d'entrée de gamme (2 à 3 Go de mémoire)", "Le téléphone le plus courant chez les utilisateurs : fluidité et démarrage."),
    ("Android milieu de gamme récent", "Référence de comportement normal."),
    ("Android 15 ou 16", "Les appels y étaient muets avant la 1.28.0."),
    ("Android ancien (version 9 à 11)", "Compatibilité des notifications et des autorisations."),
    ("iPhone récent", "Version iOS : appels, notifications, affichage."),
    ("iPhone plus ancien ou petit écran", "Mise en page sur petit écran."),
    ("Réseau mobile 4G", "Appels et médias hors Wi-Fi."),
    ("Réseau faible (2G / 3G)", "Envoi différé, reprise après coupure."),
    ("Navigateur d'ordinateur (Chrome ou Edge)", "Console d'administration."),
    ("Navigateur de téléphone", "Console d'administration sur petit écran."),
]
for rr, (profile, why) in enumerate(profiles, 2):
    for col, value in enumerate([profile, why, "", "", "", "", ""], 1):
        c = dev.cell(row=rr, column=col, value=value)
        c.font = Font(name=ARIAL, size=10)
        c.alignment = WRAP
        c.border = BORDER
for col, width in enumerate([40, 52, 32, 16, 18, 16, 22], 1):
    dev.column_dimensions[get_column_letter(col)].width = width
dev.freeze_panes = "A2"

wb.active = 0
# Excel recalcule tout à l'ouverture : le fichier est écrit sans valeurs en cache.
wb.calculation.fullCalcOnLoad = True
wb.save(OUT)
print("cas:", LAST - 1, "modules:", len(MODULES))
