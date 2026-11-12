// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LFr extends L {
  LFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Pokou';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionConfirm => 'Confirmer';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionContinue => 'Continuer';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionShare => 'Partager';

  @override
  String get actionSearch => 'Rechercher';

  @override
  String get actionAdd => 'Ajouter';

  @override
  String get actionRemove => 'Retirer';

  @override
  String get actionSend => 'Envoyer';

  @override
  String get actionJoin => 'Rejoindre';

  @override
  String get actionCreate => 'Créer';

  @override
  String get navChats => 'Discussions';

  @override
  String get navStatus => 'Actus';

  @override
  String get navCalls => 'Appels';

  @override
  String get navMarket => 'Marché';

  @override
  String get chatsEmptyTitle => 'Aucune discussion';

  @override
  String get chatsEmptyBody => 'Tes discussions apparaîtront ici.';

  @override
  String get chatsSearchHint => 'Rechercher';

  @override
  String get chatsTyping => 'écrit…';

  @override
  String chatsTypingNamed(String name) {
    return '$name écrit…';
  }

  @override
  String get chatsUnknownContact => 'pas dans tes contacts';

  @override
  String get chatsNoMessageYet => 'Aucun message pour l\'instant';

  @override
  String chatsYouPrefix(String message) {
    return 'Toi : $message';
  }

  @override
  String chatsGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes',
      one: '1 groupe',
      zero: 'Aucun groupe',
    );
    return '$_temp0';
  }

  @override
  String get newChatTitle => 'Nouvelle discussion';

  @override
  String get newChatSearchHint => 'Rechercher un contact';

  @override
  String get newChatNewGroup => 'Nouveau groupe';

  @override
  String get newChatNewCommunity => 'Nouvelle communauté';

  @override
  String get newChatJoinByLink => 'Rejoindre par lien';

  @override
  String get newChatOnPokou => 'Sur Pokou Messenger';

  @override
  String get newChatInvite => 'Inviter sur Pokou Messenger';

  @override
  String get newChatNoMatch => 'Aucun contact ne correspond.';

  @override
  String get newChatNoRegisteredContact =>
      'Aucun de tes contacts n\'utilise encore Pokou.';

  @override
  String conversationSayHello(String name) {
    return 'Dites bonjour à $name.';
  }

  @override
  String get conversationMessageHint => 'Message';

  @override
  String get conversationEdit => 'Modifier';

  @override
  String get conversationForward => 'Transférer';

  @override
  String get conversationReply => 'Répondre';

  @override
  String get conversationEditWindowOver =>
      'Ce message ne peut plus être modifié.';

  @override
  String get mediaPhoto => 'Photo';

  @override
  String get mediaVideo => 'Vidéo';

  @override
  String get mediaVoice => 'Message vocal';

  @override
  String get mediaDocument => 'Document';

  @override
  String get mediaLocation => 'Position';

  @override
  String get offlineTitle => 'Hors ligne';

  @override
  String get offlineBody =>
      'Tu verras ce qui est déjà sur ce téléphone. Le reste arrivera au retour du réseau.';

  @override
  String get offlineNothingCached =>
      'Rien n\'est encore enregistré sur cet appareil.';

  @override
  String get offlineSending => 'En attente d\'envoi';

  @override
  String get errorNetwork => 'Connexion impossible. Vérifie ton réseau.';

  @override
  String get twoStepTitle => 'Vérification en deux étapes';

  @override
  String get twoStepBody =>
      'Ton compte est protégé par la vérification en deux étapes. Saisis ton code PIN pour te reconnecter.';

  @override
  String get twoStepHint => 'Code du compte';

  @override
  String get errorGeneric => 'Quelque chose n\'a pas fonctionné.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileLanguage => 'Langue';

  @override
  String get profileLanguageSystem => 'Langue du téléphone';

  @override
  String get profileLanguageSubtitle => 'Choisis la langue de l\'application';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageRussian => 'Russe';

  @override
  String get languageArabic => 'Arabe';

  @override
  String get languageItalian => 'Italien';

  @override
  String get sparkTitle => 'Spark';

  @override
  String get sparkSubtitle => 'Le rendez-vous d\'aujourd\'hui';

  @override
  String get sparkTabDiscover => 'Découvrir';

  @override
  String get sparkTabMatches => 'Matchs';

  @override
  String get sparkTabDates => 'Sorties';

  @override
  String get sparkTabMe => 'Moi';

  @override
  String get sparkAddPhoto => 'Ajouter une photo';

  @override
  String get sparkNoPhotoWarning =>
      'Ajoute une photo — sans elle, presque personne ne like';

  @override
  String sparkPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get sparkLike => 'Liker';

  @override
  String get sparkPass => 'Passer';

  @override
  String get sparkAgeRestricted => 'Spark est réservé aux 18 ans et plus.';

  @override
  String get navProfile => 'Profil';

  @override
  String get authWelcome => 'Bienvenue sur Pokou';

  @override
  String get authSubtitle =>
      'Nouveau ou déjà inscrit, c’est le même chemin : tu reçois un code par SMS.';

  @override
  String get authPhoneHint => 'Ton numéro de mobile';

  @override
  String get authPrivacyNote =>
      'Connexion sécurisée. Ton numéro sert uniquement à vérifier ton identité.';

  @override
  String get authVerifyTitle => 'Vérification';

  @override
  String authCodeSentTo(String phone) {
    return 'Envoyé par SMS au $phone';
  }

  @override
  String get authChangeNumber => 'Modifier le numéro';

  @override
  String authResendIn(String time) {
    return 'Renvoyer le code dans $time';
  }

  @override
  String get authResendSms => 'Renvoyer par SMS';

  @override
  String get authResendWhatsapp => 'Renvoyer via WhatsApp';

  @override
  String get authCodeSentSms => 'Nouveau code envoyé par SMS.';

  @override
  String get authCodeSentWhatsapp => 'Nouveau code envoyé sur WhatsApp.';

  @override
  String get chatsPin => 'Épingler';

  @override
  String get chatsUnpin => 'Désépingler';

  @override
  String get chatsArchive => 'Archiver';

  @override
  String get chatsUnarchive => 'Désarchiver';

  @override
  String get chatsMute => 'Mettre en sourdine';

  @override
  String get chatsUnmute => 'Réactiver le son';

  @override
  String get chatsTag => 'Étiqueter';

  @override
  String chatsTagNamed(String name) {
    return 'Étiqueter $name';
  }

  @override
  String get chatsBlock => 'Bloquer';

  @override
  String chatsBlockTitle(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get chatsBlockBody =>
      'Cette personne ne pourra plus t\'écrire ni t\'appeler. Elle ne sera pas prévenue.';

  @override
  String get chatsPinLimit => 'Trois discussions épinglées au maximum.';

  @override
  String get chatsMute8h => '8 heures';

  @override
  String get chatsMute1w => '1 semaine';

  @override
  String get chatsMuteAlways => 'Toujours';

  @override
  String get chatsAddContact => 'Ajouter à mes contacts';

  @override
  String get chatsActionFailed => 'Action impossible pour le moment.';

  @override
  String get chatsNoResult => 'Aucun résultat.';

  @override
  String get chatsConnectFailed => 'Connexion impossible.';

  @override
  String get navModules => 'Modules';

  @override
  String get navBroadcasts => 'Listes de diffusion';

  @override
  String get navYou => 'Toi';

  @override
  String get convProductFallback => 'Produit';

  @override
  String get convOrderUpdated => 'Commande mise à jour';

  @override
  String get convReactionFailed => 'Réaction impossible.';

  @override
  String get convPermissionDenied => 'Permission refusée.';

  @override
  String get convAttachDocument => 'Document';

  @override
  String get convAttachGallery => 'Photo (galerie)';

  @override
  String get convAttachVideo => 'Vidéo (galerie)';

  @override
  String get convAttachCamera => 'Appareil photo';

  @override
  String get convEditTitle => 'Modifier le message';

  @override
  String get convEditHint => 'Ton message';

  @override
  String convForwarded(String name) {
    return 'Message transféré à $name.';
  }

  @override
  String get convForwardFailed => 'Transfert impossible.';

  @override
  String get convRecordVoice => 'Enregistrer une note vocale';

  @override
  String get mediaVoiceNote => 'Note vocale';

  @override
  String get mediaMessage => 'Message';

  @override
  String get newChatInviteAction => 'Inviter';

  @override
  String get profileGallery => 'Galerie';

  @override
  String get profileCamera => 'Appareil photo';

  @override
  String get profileEdit => 'Modifier le profil';

  @override
  String get profileFullName => 'Nom complet';

  @override
  String get profileAbout => 'À propos';

  @override
  String get profileUpdateFailed => 'Mise à jour impossible.';

  @override
  String get profileVerifiedPhone => 'Identité vérifiée par téléphone';

  @override
  String get profilePrivacySecurity => 'Confidentialité & Sécurité';

  @override
  String get profileShieldMode => 'Mode Bouclier';

  @override
  String get profileShieldOn => 'Mode Bouclier activé';

  @override
  String get profileShieldOff => 'Mode Bouclier désactivé';

  @override
  String get profileConnection => 'Connexion';

  @override
  String get profileEncryptedTls => 'Chiffrée (TLS)';

  @override
  String get profileStatusVisibility => 'Visibilité des statuts';

  @override
  String get commonEnabled => 'Activé';

  @override
  String get commonDisabled => 'Désactivé';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get profileDevices => 'Appareils connectés';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileStorage => 'Stockage et données';

  @override
  String get profileDataSaver => 'Économie de données';

  @override
  String get profileSystemPrefs => 'Préférences système';

  @override
  String get profileSignOut => 'Se déconnecter';

  @override
  String modulesActivated(String name) {
    return '$name est activé.';
  }

  @override
  String get modulesUnavailable => 'Modules indisponibles';

  @override
  String get modulesCheckNetwork => 'Vérifie ta connexion et réessaie.';

  @override
  String get modulesEmptyTitle => 'Rien à ajouter pour l\'instant';

  @override
  String get modulesEmptyBody =>
      'De nouveaux modules arriveront ici. Tu n\'as rien à faire en attendant.';

  @override
  String get modulesMine => 'Mes apps';

  @override
  String get modulesRecommended => 'Recommandés';

  @override
  String get modulesRecommendedBy => 'Choisis par notre équipe';

  @override
  String get modulesPopular => 'Populaires';

  @override
  String get modulesPopularSub => 'Les plus activés en ce moment';

  @override
  String get modulesEnable => 'Activer';

  @override
  String get modulesDisable => 'Désactiver';

  @override
  String get modulesEnableFailed => 'L\'activation n\'a pas pu aboutir.';

  @override
  String modulesComingSoon(String name) {
    return '$name arrive bientôt. Mets l\'application à jour pour en profiter dès sa sortie.';
  }

  @override
  String modulesUserCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes l\'utilisent',
      one: '1 personne l\'utilise',
    );
    return '$_temp0';
  }

  @override
  String get sparkEnableLocation => 'Active la localisation sur ton téléphone.';

  @override
  String get sparkLocationNeeded =>
      'Sans position, Spark ne peut pas savoir qui est autour de toi.';

  @override
  String get sparkLocationFailed => 'La position n\'a pas pu être relevée.';

  @override
  String get sparkFeedUnavailable => 'Flux indisponible';

  @override
  String get sparkPickIntentTitle => 'Choisis ta carte du moment';

  @override
  String get sparkPickIntentBody =>
      'Dis ce que tu cherches aujourd\'hui pour voir qui cherche la même chose.';

  @override
  String get sparkLocationStale => 'Ta position n\'est pas à jour';

  @override
  String get sparkLocationStaleBody =>
      'Spark ne montre que des gens à moins de 5 km. Sans position fraîche, il ne peut rien afficher.';

  @override
  String get sparkShareLocation => 'Partager ma position';

  @override
  String get sparkQuotaTitle => 'Tu as vu tes profils du jour';

  @override
  String get sparkQuotaBody =>
      'Reviens demain, ou prends Spark+ pour voir sans compter.';

  @override
  String get sparkNobodyTitle => 'Personne pour l\'instant';

  @override
  String get sparkNobodyBody =>
      'Peu de monde cherche la même chose que toi, ici et maintenant. Réessaie plus tard — ou change de carte.';

  @override
  String get sparkPickCard => 'Choisis ta carte';

  @override
  String get sparkTodayLooking => 'Ce que tu cherches aujourd\'hui';

  @override
  String get sparkCardExpired => 'Ta carte a expiré';

  @override
  String sparkHoursLeft(int hours) {
    return 'Encore $hours h';
  }

  @override
  String sparkMinutesLeft(int minutes) {
    return 'Encore $minutes min';
  }

  @override
  String get sparkIntentSheetTitle => 'Aujourd\'hui, je cherche';

  @override
  String get sparkIntentSheetBody =>
      'Ta carte expire dans 24 h. Tu ne verras que des gens qui ont choisi la même chose.';

  @override
  String get sparkLikesExhausted =>
      'Tes likes du jour sont épuisés. Prends un pack dans « Moi ».';

  @override
  String get sparkMatchesUnavailable => 'Matchs indisponibles';

  @override
  String get sparkNoMatchTitle => 'Aucun match pour l\'instant';

  @override
  String get sparkNoMatchBody =>
      'Quand vous vous likez tous les deux, une salle de dix minutes s\'ouvre. C\'est là que ça se joue.';

  @override
  String get sparkOpenRooms => 'Salles ouvertes';

  @override
  String get sparkRoomsClose => 'Elles se referment toutes seules';

  @override
  String get sparkMyMatches => 'Mes matchs';

  @override
  String get sparkNext => 'Suite';

  @override
  String get sparkPhotoFailed => 'La photo n\'a pas pu être ajoutée.';

  @override
  String get sparkGoFaster => 'Aller plus vite';

  @override
  String get sparkNoExpiry => 'Sans expiration';

  @override
  String get sparkPlusActive => 'Actif — prolonge ton abonnement';

  @override
  String get sparkPlusPitch => 'Profils illimités, un mois';

  @override
  String get sparkBoost => 'Top Profil';

  @override
  String get sparkBoostPitch => 'En tête du flux pendant une heure';

  @override
  String get sparkAroundMe => 'Autour de moi';

  @override
  String get sparkSafety => 'Sécurité';

  @override
  String get sparkSafetyPitch => 'Alerte discrète et cercle de confiance';

  @override
  String get sparkWingman => 'Avis de mes potes';

  @override
  String get sparkWingmanPitch =>
      'Les profils sur lesquels on te demande un avis';

  @override
  String get sparkUploading => 'Envoi…';

  @override
  String get sparkKarma => 'Street Cred';

  @override
  String get sparkCanInvite => 'Tu peux inviter';

  @override
  String get sparkCannotInvite =>
      'Trop bas pour inviter. Honore tes rendez-vous.';

  @override
  String sparkLikersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes t\'ont liké',
      one: 'Une personne t\'a liké',
    );
    return '$_temp0';
  }

  @override
  String get sparkSeeWho => 'Voir qui';

  @override
  String get sparkFindInDiscover => 'Retrouve-les dans Découvrir.';

  @override
  String get sparkPaymentPendingLikers =>
      'La liste s\'ouvrira dès la confirmation du paiement.';

  @override
  String get sparkPaymentPendingLikes =>
      'Tes likes arriveront dès la confirmation du paiement.';

  @override
  String get sparkPaymentPendingPlus =>
      'Spark+ s\'activera dès la confirmation du paiement.';

  @override
  String get sparkPaymentPendingBoost =>
      'Ton profil remontera dès la confirmation du paiement.';

  @override
  String get sparkBirthDateLabel => 'Ta date de naissance';

  @override
  String get sparkNameAndBirthNeeded =>
      'Un prénom et une date de naissance, au minimum.';

  @override
  String get sparkProfileFailed => 'La fiche n\'a pas pu être créée.';

  @override
  String get sparkCreateProfile => 'Crée ta fiche';

  @override
  String get sparkStep1Title => 'Tu dis ce que tu cherches, aujourd\'hui';

  @override
  String get sparkStep1Body =>
      'Ta carte expire en 24 h. Tu ne vois que des gens qui cherchent la même chose, à moins de 5 km.';

  @override
  String get sparkStep2Title => 'Dix minutes de vocal avant d\'écrire';

  @override
  String get sparkStep2Body =>
      'Après un match, une salle s\'ouvre : vocaux et stickers seulement. Les faux profils ne passent pas cette étape.';

  @override
  String get sparkStep3Title => 'Tes proches savent où tu es';

  @override
  String get sparkStep3Body =>
      'Un geste discret prévient ton cercle avec ta position. On te demande aussi si tout va bien pendant le rendez-vous.';

  @override
  String get sparkSeparateTitle => 'Ta fiche est séparée de Pokou';

  @override
  String get sparkSeparateBody =>
      'Ton nom et ton numéro Pokou ne sont jamais montrés ici. Choisis ce que tu veux afficher.';

  @override
  String get sparkDisplayName => 'Prénom affiché';

  @override
  String get sparkNameExample => 'Ex : Ama';

  @override
  String get sparkBirthDate => 'Date de naissance';

  @override
  String get sparkBirthDateLocked =>
      'Elle ne pourra plus être modifiée ensuite.';

  @override
  String get sparkChoose => 'Choisir';

  @override
  String get sparkYouAre => 'Tu es';

  @override
  String get sparkWoman => 'Une femme';

  @override
  String get sparkMan => 'Un homme';

  @override
  String get sparkOther => 'Autre';

  @override
  String get sparkBioLabel => 'Deux mots sur toi (facultatif)';

  @override
  String get sparkBioHint => 'Ce qu\'il faut savoir avant de te rencontrer';

  @override
  String get sparkCreateAction => 'Créer ma fiche';

  @override
  String get truthSubtitle => 'Une question payée, une réponse libre';

  @override
  String get truthAsk => 'Poser une question';

  @override
  String get truthForMe => 'Pour moi';

  @override
  String get truthMine => 'Mes questions';

  @override
  String get truthUnavailable => 'Questions indisponibles';

  @override
  String get truthEmptyTitle => 'Aucune question pour le moment';

  @override
  String get truthEmptyBody =>
      'Quand quelqu\'un paiera pour te poser une question, elle apparaîtra ici. Tu resteras libre de refuser.';

  @override
  String get truthYourAnswer => 'Ta réponse';

  @override
  String get truthAnswerPrivacy =>
      'Elle ne va qu\'à la personne qui a payé. Pokou ne la republie nulle part.';

  @override
  String get truthWhatToSay => 'Ce que tu veux dire';

  @override
  String get truthSendAnswer => 'Envoyer ma réponse';

  @override
  String get truthAskedAnon => 'Demandé anonymement';

  @override
  String get truthDecline => 'Refuser';

  @override
  String get truthAnswer => 'Répondre';

  @override
  String get truthDeclineFree =>
      'Refuser ne te coûte rien. Tu n\'es payé qu\'en répondant.';

  @override
  String get truthHistoryUnavailable => 'Historique indisponible';

  @override
  String get truthNothingAsked => 'Tu n\'as encore rien demandé';

  @override
  String get truthNothingAskedBody =>
      'Pose une question à quelqu\'un : il verra le montant et la question, jamais ton nom.';

  @override
  String get truthAnswered => 'Répondu';

  @override
  String get truthDeclined => 'Refusé';

  @override
  String get truthPending => 'En attente';

  @override
  String truthToSomeone(String name) {
    return 'À $name';
  }

  @override
  String get truthSomeone => 'quelqu\'un';

  @override
  String get truthPreferredNot => 'Cette personne a préféré ne pas répondre.';

  @override
  String get truthAwaitingAnswer => 'En attente d\'une réponse.';

  @override
  String get truthToWhom => 'À qui ?';

  @override
  String truthQuestionTo(String name) {
    return 'Une question à $name';
  }

  @override
  String get truthAnonTitle => 'Ton nom n\'est pas montré';

  @override
  String get truthAnonBody =>
      'La personne voit le montant et la question, jamais qui les a envoyés.';

  @override
  String get truthFreeTitle => 'Elle reste libre de refuser';

  @override
  String get truthFreeBody =>
      'Refuser ne lui rapporte rien : elle n\'est payée qu\'en répondant.';

  @override
  String get truthPrivateTitle => 'La réponse ne va qu\'à toi';

  @override
  String get truthPrivateBody =>
      'Pokou ne la republie nulle part, et elle expire au bout de sept jours sans réponse.';

  @override
  String get truthYourQuestion => 'Ta question';

  @override
  String get truthQuestionHint => 'Ce que tu aimerais vraiment savoir';

  @override
  String get truthHowMuch => 'Combien tu proposes';

  @override
  String truthAskForAmount(int amount) {
    return 'Poser la question — $amount FCFA';
  }

  @override
  String get truthWriteFirst => 'Écris d\'abord ta question.';

  @override
  String get truthPaymentPending =>
      'Ta question partira dès la confirmation du paiement.';

  @override
  String get hypeFinished => 'Terminé';

  @override
  String get hypeSubtitle => 'Un objectif, toute la salle';

  @override
  String get hypeLaunch => 'Lancer un objectif';

  @override
  String get hypeOngoing => 'En cours';

  @override
  String get hypeMine => 'Les miens';

  @override
  String get hypeNoneTitle => 'Aucun objectif en cours';

  @override
  String get hypeNoneBody =>
      'Quand un créateur lance un objectif, il apparaît ici jusqu\'à ce que le palier tombe.';

  @override
  String get hypeMineEmpty => 'Rien pour le moment';

  @override
  String get hypeMineEmptyBody =>
      'Tes objectifs et ceux que tu as soutenus apparaîtront ici.';

  @override
  String get hypeUnavailable => 'Objectifs indisponibles';

  @override
  String get hypeCreator => 'Créateur';

  @override
  String get hypeTierReached => 'Palier atteint';

  @override
  String get hypeGoal => 'Objectif';

  @override
  String get hypeNotFound => 'Objectif introuvable';

  @override
  String get hypeMaybeRemoved => 'Il a peut-être été retiré.';

  @override
  String get hypeUnlocked => 'Le palier est tombé. La promesse est débloquée.';

  @override
  String get hypeContribute => 'Faire avancer la barre';

  @override
  String get hypePushers => 'Ceux qui poussent';

  @override
  String get hypeBeFirst => 'Personne encore. Sois le premier.';

  @override
  String get hypeContributor => 'Contributeur';

  @override
  String commonDueToYou(int amount) {
    return 'Te revient : $amount FCFA';
  }

  @override
  String get commonManualPayout =>
      'Le versement se fait par l\'équipe Pokou, sur demande.';

  @override
  String get hypeStepTogetherTitle => 'Tout le monde pousse ensemble';

  @override
  String get hypeStepTogetherBody =>
      'Chaque participation fait monter la barre, et tout le monde voit le palier tomber en même temps.';

  @override
  String get hypeStepPromiseTitle => 'Ce que tu promets';

  @override
  String get hypeStepPromiseBody =>
      'Visible avant que quiconque ne paie. C\'est ton engagement si l\'objectif est atteint.';

  @override
  String get hypeStepOneTitle => 'Un seul objectif à la fois';

  @override
  String get hypeStepOneBody =>
      'Deux objectifs simultanés mettraient tes contributeurs en concurrence avec eux-mêmes.';

  @override
  String get commonTitle => 'Titre';

  @override
  String get hypeTitleExample => 'Ex : 100 000 et je chante';

  @override
  String get hypePromiseLabel => 'Ce que tu débloques si l\'objectif tombe';

  @override
  String get hypePromiseHint =>
      'Sois précis : c\'est ce que tes contributeurs achètent.';

  @override
  String get hypeGoalAmount => 'Objectif en FCFA';

  @override
  String get commonDuration => 'Durée';

  @override
  String get hypeLaunchAction => 'Lancer';

  @override
  String get hypeFieldsNeeded =>
      'Titre, promesse et objectif sont nécessaires.';

  @override
  String get hypeAlreadyRunning => 'Tu as déjà un objectif en cours.';

  @override
  String get hypeContributeNote =>
      'Ta participation fait avancer la barre et débloque un contenu. Elle n\'est pas remboursable.';

  @override
  String get commonAmount => 'Montant';

  @override
  String hypeJoinForAmount(int amount) {
    return 'Participer — $amount FCFA';
  }

  @override
  String get hypePaymentPending =>
      'La barre avancera dès la confirmation du paiement.';

  @override
  String get ceremonyWedding => 'Mariage';

  @override
  String get ceremonyBaptism => 'Baptême';

  @override
  String get ceremonyFuneral => 'Deuil';

  @override
  String get ceremonyOther => 'Autre';

  @override
  String get ceremonyTitle => 'Cagnottes';

  @override
  String get ceremonySubtitle => 'Les cotisations, sans les relances';

  @override
  String get ceremonyNew => 'Nouvelle cagnotte';

  @override
  String get ceremonyUnavailable => 'Cagnottes indisponibles';

  @override
  String get ceremonyNone => 'Aucune cagnotte';

  @override
  String get ceremonyNoneBody =>
      'Mariage, baptême, deuil : crée la cagnotte, invite, et chacun contribue comme il peut.';

  @override
  String ceremonyGoalHint(int amount) {
    return 'Objectif indicatif : $amount FCFA';
  }

  @override
  String get ceremonyOne => 'Cagnotte';

  @override
  String get ceremonyNotFound => 'Cagnotte introuvable';

  @override
  String get ceremonyMaybeClosed => 'Elle a peut-être été clôturée.';

  @override
  String get ceremonyJoin => 'Participer';

  @override
  String get ceremonyClose => 'Clôturer la cagnotte';

  @override
  String get ceremonyContributions => 'Participations';

  @override
  String get ceremonyNobodyYet => 'Personne n\'a encore participé.';

  @override
  String get ceremonyAnonGift => 'Participation anonyme';

  @override
  String get ceremonyContributor => 'Contributeur';

  @override
  String get ceremonyCollected => 'collectés';

  @override
  String get ceremonyYouOrganize => 'tu organises';

  @override
  String get ceremonyNewSubtitle =>
      'Tu suis les participations. Pokou n\'envoie aucune relance à ceux qui n\'ont pas donné.';

  @override
  String get ceremonyOccasion => 'Occasion';

  @override
  String get ceremonyTitleExample => 'Ex : Mariage de Kossi et Ama';

  @override
  String get ceremonyFewWords => 'Quelques mots (facultatif)';

  @override
  String get ceremonyFewWordsHint =>
      'La date, le lieu, à quoi servira l\'argent.';

  @override
  String get ceremonyGoalOptional => 'Objectif en FCFA (facultatif)';

  @override
  String get ceremonyGoalNote =>
      'Indicatif : la cagnotte continue d\'accepter au-delà.';

  @override
  String get ceremonyCreate => 'Créer la cagnotte';

  @override
  String get ceremonyNeedTitle => 'Donne un titre à la cagnotte.';

  @override
  String ceremonyJoinTo(String title) {
    return 'Participer — $title';
  }

  @override
  String get ceremonyOtherAmount => 'Ou un autre montant';

  @override
  String get ceremonyWordOptional => 'Un mot (facultatif)';

  @override
  String get ceremonyWordHint => 'Ce que tu veux leur dire';

  @override
  String get ceremonyAnonToggle => 'Participer anonymement';

  @override
  String get ceremonyAnonNote =>
      'Ton nom sera masqué. Le montant reste dans le total.';

  @override
  String ceremonyJoinAmount(int amount) {
    return 'Participer — $amount FCFA';
  }

  @override
  String get ceremonyMinimum => 'Le minimum est de 100 FCFA.';

  @override
  String get ceremonyPaymentPending =>
      'Ta participation apparaîtra dès la confirmation du paiement.';

  @override
  String get vipSubtitle => 'Tes abonnés, ton espace';

  @override
  String get vipDiscover => 'Découvrir';

  @override
  String get vipMySubs => 'Mes abonnements';

  @override
  String get vipMyRoom => 'Mon salon';

  @override
  String get vipNoRoomOpen => 'Aucun salon ouvert';

  @override
  String get vipNoRoomOpenBody =>
      'Les salons que des créateurs ouvrent apparaîtront ici.';

  @override
  String get vipNoSub => 'Aucun abonnement';

  @override
  String get vipNoSubBody =>
      'Abonne-toi à un salon pour retrouver ici tout ce que son créateur publie.';

  @override
  String get vipUnavailable => 'Salons indisponibles';

  @override
  String get vipCreator => 'Créateur';

  @override
  String vipUntil(String date) {
    return 'Jusqu\'au $date';
  }

  @override
  String get vipPaymentPending =>
      'Le salon s\'ouvrira dès la confirmation du paiement.';

  @override
  String get vipRoom => 'Salon';

  @override
  String get vipNotFound => 'Salon introuvable';

  @override
  String get vipMaybeClosed => 'Il a peut-être été fermé.';

  @override
  String get vipStepAllTitle => 'Tout ce qui est publié ici';

  @override
  String get vipStepAllBody =>
      'Tu vois immédiatement les publications déjà en ligne, et celles qui suivront.';

  @override
  String get vipStepDaysTitle => 'Trente jours';

  @override
  String get vipStepDaysBody =>
      'L\'accès s\'arrête tout seul au terme. Rien ne continue sans que tu le décides.';

  @override
  String get vipStepNoRenewTitle => 'Aucune reconduction automatique';

  @override
  String get vipStepNoRenewBody =>
      'Pokou ne conserve pas ton moyen de paiement. Pour continuer, tu repaies, une fois.';

  @override
  String vipSubscribeFor(int amount) {
    return 'S\'abonner — $amount FCFA';
  }

  @override
  String get vipLockedTitle => 'Contenu réservé aux abonnés';

  @override
  String get vipLockedBody =>
      'Le reste du salon s\'ouvre dès la confirmation du paiement.';

  @override
  String get vipNothingYet => 'Rien encore';

  @override
  String get vipNothingYetBody => 'Ce salon n\'a pas encore de publication.';

  @override
  String get vipPosts => 'Publications';

  @override
  String get vipRoomUnavailable => 'Salon indisponible';

  @override
  String get vipOpenYourRoom => 'Ouvre ton salon';

  @override
  String get vipOpenYourRoomBody =>
      'Tes abonnés paient une fois pour trente jours et voient tout ce que tu publies ici. Tu fixes le prix.';

  @override
  String get vipOpenAction => 'Ouvrir mon salon';

  @override
  String get vipPublish => 'Publier';

  @override
  String get vipSeeMyRoom => 'Voir mon salon';

  @override
  String get vipOpen => 'Ouvert';

  @override
  String get vipClosed => 'Fermé';

  @override
  String get vipEarnings => 'Tes revenus';

  @override
  String vipCollected(int amount) {
    return '$amount FCFA collectés';
  }

  @override
  String get vipDueNote =>
      'Montant qui te revient. Le versement se fait par l\'équipe Pokou, sur demande.';

  @override
  String get vipEditRoom => 'Modifier mon salon';

  @override
  String get vipPriceNote =>
      'Un nouveau prix ne s\'applique qu\'aux abonnements suivants : chacun a payé le sien d\'avance.';

  @override
  String get vipRoomName => 'Nom du salon';

  @override
  String get vipRoomNameHint => 'Ex : Les coulisses';

  @override
  String get vipPitchLabel => 'Ce que tes abonnés y trouveront';

  @override
  String get vipPitchNote =>
      'Visible avant de payer — c\'est ce qui donne envie de s\'abonner.';

  @override
  String get vipPitchHint => 'Des photos, des annonces, des messages vocaux…';

  @override
  String get vipMonthlyPrice => 'Prix mensuel en FCFA';

  @override
  String get vipAcceptNew => 'Accepter de nouveaux abonnés';

  @override
  String get vipAcceptNewNote =>
      'Tes abonnés actuels gardent leur accès jusqu\'au terme.';

  @override
  String get vipFieldsNeeded => 'Nom, description et prix sont nécessaires.';

  @override
  String get vipPublishTitle => 'Publier dans mon salon';

  @override
  String get vipPublishNote => 'Visible uniquement par tes abonnés en cours.';

  @override
  String get vipYourMessage => 'Ton message';

  @override
  String get vipShareHint => 'Ce que tu veux partager';

  @override
  String vipEarningsSummary(int count, int amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abonnements',
      one: '1 abonnement',
    );
    return '$_temp0 • $amount FCFA collectés';
  }

  @override
  String get datesUnavailable => 'Sorties indisponibles';

  @override
  String get datesNone => 'Aucune sortie prévue';

  @override
  String get datesNoneBody =>
      'Une fois la salle passée, propose un endroit. Tu paies d\'avance, et l\'argent n\'est versé qu\'une fois que vous confirmez tous les deux.';

  @override
  String get datesNotNow => 'Ce n\'est pas le moment pour ce geste.';

  @override
  String get datesCancelTitle => 'Annuler la sortie ?';

  @override
  String get datesCancelFree =>
      'Tu es à plus de 24 h : tu seras intégralement remboursé.';

  @override
  String get datesCancelLate =>
      'Il reste moins de 24 h. L\'établissement a déjà réservé, ton paiement lui reste acquis.';

  @override
  String get datesKeep => 'Garder';

  @override
  String get datesCancelAction => 'Annuler la sortie';

  @override
  String get datesAwaitingPayment => 'En attente de paiement';

  @override
  String get datesPaidToConfirm => 'Payé — à confirmer';

  @override
  String get datesDone => 'Terminé';

  @override
  String get datesRefunded => 'Remboursé';

  @override
  String get datesNoShow => 'Lapin signalé';

  @override
  String get datesCancelled => 'Annulé';

  @override
  String get datesOne => 'Sortie';

  @override
  String datesWithPeer(String venue, String name) {
    return '$venue • avec $name';
  }

  @override
  String get datesYourMatch => 'ton match';

  @override
  String get datesWentWell => 'Ça s\'est bien passé';

  @override
  String get datesYouConfirmed =>
      'Tu as confirmé. On attend la confirmation de l\'autre.';

  @override
  String get datesNoShowAction => 'Il n\'est pas venu';

  @override
  String get datesVoucher => 'Ton bon, à donner sur place';

  @override
  String get datesPickBoth => 'Choisis une formule et un moment.';

  @override
  String get datesVoucherPending =>
      'Ton bon sera émis dès la confirmation du paiement.';

  @override
  String get datesBookingFailed => 'La réservation n\'a pas abouti.';

  @override
  String get datesWhereTo => 'Où allez-vous ?';

  @override
  String get datesStepPayTitle => 'Tu paies d\'avance, rien n\'est versé';

  @override
  String get datesStepPayBody =>
      'L\'argent est bloqué. Il ne part chez l\'établissement que si vous confirmez tous les deux.';

  @override
  String get datesStepCancelTitle => 'Annulation libre à plus de 24 h';

  @override
  String get datesStepCancelBody =>
      'Remboursement intégral. En deçà, l\'établissement a déjà réservé et garde ton paiement.';

  @override
  String get datesStepNoShowTitle => 'Si l\'autre ne vient pas';

  @override
  String get datesStepNoShowBody =>
      'La moitié te revient. L\'application ne prend rien sur un rendez-vous manqué.';

  @override
  String get datesThePackage => 'La formule';

  @override
  String get datesPacksUnavailable =>
      'Les formules ne sont pas disponibles pour le moment.';

  @override
  String get datesNoPackNearby =>
      'Aucune formule n\'est proposée près de chez toi pour l\'instant.';

  @override
  String get datesWhen => 'Quand ?';

  @override
  String get datesPickWhen => 'Choisir la date et l\'heure';

  @override
  String get datesBook => 'Réserver';

  @override
  String datesBookAmount(int amount) {
    return 'Réserver — $amount FCFA';
  }

  @override
  String get roomNeedMic =>
      'Sans micro, il n\'y a que les stickers — la salle est vocale.';

  @override
  String get roomVoiceFailed => 'Le vocal n\'est pas parti.';

  @override
  String get roomBothYes =>
      'C\'est parti. Tu peux maintenant proposer une sortie.';

  @override
  String get roomWaitingOther =>
      'C\'est noté. On attend sa réponse avant la fin du compte à rebours.';

  @override
  String get roomExtendPending =>
      'Dix minutes de plus dès la confirmation du paiement.';

  @override
  String get roomTitle => 'Salle d\'entrée';

  @override
  String get roomNotFound => 'Salle introuvable';

  @override
  String get roomMaybeClosed => 'Elle s\'est peut-être refermée.';

  @override
  String get roomVoiceOnly => 'Vocaux et stickers seulement';

  @override
  String get roomTimeUp => 'Le temps est écoulé.';

  @override
  String roomTimeLeft(String clock) {
    return 'Il reste $clock pour décider ensemble';
  }

  @override
  String get roomSaySomething => 'Dites quelque chose';

  @override
  String get roomNoTextBody =>
      'Pas de texte ici : un vocal ou un sticker. C\'est ce qui fait la différence entre une vraie personne et un message recopié.';

  @override
  String get roomVoice => 'Vocal';

  @override
  String get roomWaitingReply => 'En attente de sa réponse';

  @override
  String roomExtendFor(int amount) {
    return 'Dix minutes de plus — $amount FCFA';
  }

  @override
  String get roomBothSaidYes => 'Vous avez tous les deux dit oui.';

  @override
  String get roomSaved => 'Le match est sauvé. Tu peux proposer une sortie.';

  @override
  String get roomClosedNoAnswer => 'La salle s\'est refermée sans réponse.';

  @override
  String get roomSuggestDate => 'Proposer une sortie';

  @override
  String get safetyCheckin => 'Tout va bien ?';

  @override
  String get safetyCheckinBody =>
      'Sans réponse de ta part dans les cinq minutes, ton cercle de sécurité sera prévenu avec ta position.';

  @override
  String get safetyAllGood => 'Oui, tout va bien';

  @override
  String get safetyCircleAlerted => 'Ton cercle a été prévenu.';

  @override
  String get safetyNoCircle =>
      'Alerte enregistrée. Ajoute des proches pour qu\'ils soient prévenus la prochaine fois.';

  @override
  String get safetyWhoToAlert => 'Qui prévenir ?';

  @override
  String get safetyWhoToAlertBody =>
      'Ces personnes recevront ta position en direct si tu déclenches une alerte.';

  @override
  String get safetyTitle => 'Sécurité';

  @override
  String get safetySubtitle => 'Qui est prévenu si ça tourne mal';

  @override
  String get safetyQuietAlert => 'Alerte discrète';

  @override
  String get safetyQuietAlertBody =>
      'Prévient ton cercle avec ta position. Rien ne s\'affiche à l\'écran de ton téléphone.';

  @override
  String get safetyTrigger => 'Déclencher une alerte';

  @override
  String get safetyMyCircle => 'Mon cercle';

  @override
  String get safetyThreeEnough => 'Trois personnes suffisent';

  @override
  String get safetyNobodyYet =>
      'Personne pour l\'instant. Sans cercle, une alerte est enregistrée mais ne prévient personne.';

  @override
  String get safetyAddSomeone => 'Ajouter quelqu\'un';

  @override
  String get wingmanTitle => 'Avis de potes';

  @override
  String get wingmanAnon => 'Ton avis reste anonyme';

  @override
  String get wingmanUnavailable => 'Demandes indisponibles';

  @override
  String get wingmanNothing => 'Rien à valider';

  @override
  String get wingmanNothingBody =>
      'Quand un ami te demandera ce que tu penses d\'un profil, il apparaîtra ici.';

  @override
  String wingmanAsksYou(String name) {
    return '$name demande ton avis';
  }

  @override
  String get wingmanMeh => 'Bof';

  @override
  String get wingmanWorthIt => 'Ça vaut le coup';

  @override
  String get wingmanPrivacy =>
      'Ton ami verra seulement si le groupe valide, jamais qui a répondu quoi.';

  @override
  String get marketLocationOff => 'Service de localisation désactivé.';

  @override
  String get marketGpsDenied => 'Permission GPS refusée.';

  @override
  String get marketGpsApplied => 'Localisation GPS appliquée.';

  @override
  String get marketGpsFailed => 'Impossible de récupérer ta position.';

  @override
  String get marketYourArea => 'Ta zone';

  @override
  String get marketCityOrArea => 'Ville et quartier';

  @override
  String get marketLocationCleared => 'Localisation désactivée.';

  @override
  String get marketUseGps => 'Utiliser ma position GPS';

  @override
  String get marketApply => 'Appliquer';

  @override
  String marketRemoveProduct(String name) {
    return 'Retirer « $name » ?';
  }

  @override
  String get marketProductUnavailable => 'Produit indisponible.';

  @override
  String get marketPaymentUnavailable => 'Paiement Mobile Money indisponible.';

  @override
  String get marketCheckoutUnreachable => 'Checkout Mobile Money inaccessible.';

  @override
  String get marketBoostDone => 'Paiement effectué : annonce sponsorisée.';

  @override
  String get marketBoostPending => 'Paiement du boost en attente.';

  @override
  String get marketBoostFailed => 'Boost impossible pour le moment.';

  @override
  String get marketTitle => 'Assimé';

  @override
  String get marketBecomeSeller => 'Devenir vendeur vérifié';

  @override
  String get marketAddProduct => 'Ajouter un produit';

  @override
  String get marketAroundYou => 'Près de chez toi';

  @override
  String get marketMyGps => 'Ma position GPS';

  @override
  String get marketPickArea => 'Choisir une zone';

  @override
  String get marketNearYou => 'Près de chez toi';

  @override
  String get marketUnavailable => 'Marketplace indisponible.';

  @override
  String get marketNoProduct => 'Aucun produit publié.';

  @override
  String get marketNoMatch => 'Aucun produit ne correspond à cette recherche.';

  @override
  String get marketAllShown => 'Tous les produits sont affichés';

  @override
  String get marketMyCatalogue => 'Mon catalogue';

  @override
  String get marketSwipeCatalogue => 'Glisse pour voir toutes tes annonces';

  @override
  String get marketCatalogueEmpty => 'Tu n\'as pas encore d\'annonce';

  @override
  String get marketCatalogueEmptyBody =>
      'Publie ta première annonce pour commencer à vendre !';

  @override
  String get marketBoosted => 'Sponsorisé';

  @override
  String get vitrineSeeProduct => 'Voir l\'article';

  @override
  String get vitrineHint => 'Touche l\'article pour l\'ouvrir';

  @override
  String get vitrineTitle => 'Vitrine du Marché';

  @override
  String get versesMorning => 'Verset du matin';

  @override
  String get versesEvening => 'Verset du soir';

  @override
  String get versesChannel => 'Versets du jour';

  @override
  String get versesChannelDesc => 'Les versets de 6 h et de 18 h';

  @override
  String get versesSchedule => 'Chaque jour à 6 h et à 18 h';

  @override
  String get versesThisMorning => 'Ce matin';

  @override
  String get versesThisEvening => 'Ce soir';

  @override
  String get versesBibleTitle => 'Versets bibliques';

  @override
  String get versesQuranTitle => 'Versets coraniques';

  @override
  String get versesShare => 'Partager';

  @override
  String get versesOfflineHint =>
      'Les versets arrivent même sans connexion : ils sont déjà sur ton téléphone.';

  @override
  String get marketBoosted48h => 'Sponsorisé';

  @override
  String get marketBoost => 'Mettre en avant';

  @override
  String get marketRemove => 'Retirer';

  @override
  String get marketGpsSaved => 'Position GPS enregistrée.';

  @override
  String get marketNameAndPrice => 'Un nom et un prix sont nécessaires.';

  @override
  String get marketEditProduct => 'Modifier le produit';

  @override
  String get marketMainPhoto => 'Photo principale';

  @override
  String get marketOtherPhotos => 'Autres photos';

  @override
  String get marketDescription => 'Description';

  @override
  String get marketCurrency => 'Devise';

  @override
  String get marketCategory => 'Catégorie';

  @override
  String get marketPickCategory => 'Choisir une catégorie';

  @override
  String get marketSpecifyCategory => 'Préciser la catégorie';

  @override
  String marketGpsCoords(String lat, String lon) {
    return 'Coordonnées GPS : $lat, $lon';
  }

  @override
  String get marketUploadingPhoto => 'Envoi de la photo…';

  @override
  String get marketAddPhoto => 'Ajouter une photo';

  @override
  String get groupEditName => 'Modifier le nom';

  @override
  String get groupAddPhoto => 'Ajouter une photo';

  @override
  String get groupChangePhoto => 'Changer la photo';

  @override
  String get groupRemovePhoto => 'Retirer la photo';

  @override
  String get groupNoLink => 'Aucun lien actif';

  @override
  String get groupLinkActive => 'Un lien est actif';

  @override
  String get groupCreator => 'Créateur';

  @override
  String get groupAdmin => 'Administrateur';

  @override
  String get groupAddMembers => 'Ajouter des participants';

  @override
  String get groupLeave => 'Quitter le groupe';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String get groupCopyLink => 'Copier le lien';

  @override
  String get groupRegenLink => 'Régénérer le lien';

  @override
  String get groupDisableLink => 'Désactiver le lien';

  @override
  String get groupLinkCopied => 'Lien copié.';

  @override
  String get groupLinkDisabled => 'Lien désactivé.';

  @override
  String get groupAllContactsIn =>
      'Tous tes contacts Pokou sont déjà dans ce groupe.';

  @override
  String get groupAddToGroup => 'Ajouter au groupe';

  @override
  String groupMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants ajoutés.',
      one: 'Participant ajouté.',
    );
    return '$_temp0';
  }

  @override
  String get groupLeaveTitle => 'Quitter le groupe ?';

  @override
  String groupLeaveBody(String name) {
    return 'Tu ne recevras plus les messages de « $name ». Tes messages restent chez les autres membres, et les administrateurs sont prévenus.';
  }

  @override
  String get groupLeaveAction => 'Quitter';

  @override
  String get groupNoMessage => 'Aucun message. Lance la discussion.';

  @override
  String get groupNotEncryptedNotice =>
      'Chiffré de bout en bout : seuls les membres peuvent lire ces messages.';

  @override
  String get botLabel => 'Bot';

  @override
  String get botConversationNotice =>
      'Tu écris au bot d\'une entreprise. Ces messages ne sont pas chiffrés de bout en bout : l\'entreprise lit ce que tu lui envoies.';

  @override
  String get groupAdminsOnly => 'Réservé aux administrateurs';

  @override
  String get groupCallOngoing => 'Appel en cours';

  @override
  String get communityEdit => 'Modifier la communauté';

  @override
  String get commonName => 'Nom';

  @override
  String get communityEditFailed => 'Modification impossible.';

  @override
  String get communityAddGroup => 'Ajouter un groupe';

  @override
  String get communityNewGroup => 'Créer un nouveau groupe';

  @override
  String get communityAttachGroup => 'Rattacher un groupe existant';

  @override
  String communityDetachTitle(String name) {
    return 'Détacher « $name » ?';
  }

  @override
  String get communityDetachBody =>
      'Le groupe quitte la communauté mais continue d\'exister : sa conversation et ses participants ne changent pas.';

  @override
  String get communityDetach => 'Détacher';

  @override
  String get communityDetachFailed => 'Impossible de détacher ce groupe.';

  @override
  String get communityLinkNote =>
      'Qui a ce lien rejoint la communauté et son groupe Annonces — pas les autres groupes, qui restent à rejoindre un par un.';

  @override
  String get communityActionFailed => 'Action impossible.';

  @override
  String get communityLeaveTitle => 'Quitter la communauté ?';

  @override
  String get communityLeaveBody =>
      'Tu ne recevras plus ses annonces. Les groupes que tu as rejoints restent les tiens.';

  @override
  String get communityLeave => 'Quitter la communauté';

  @override
  String get communityLeaveFailed => 'Impossible de quitter la communauté.';

  @override
  String get communityOne => 'Communauté';

  @override
  String get communityUnavailable =>
      'Communauté indisponible — vérifie ta connexion.';

  @override
  String get communityGroups => 'GROUPES';

  @override
  String get communityAnnouncements => 'Annonces · réservé aux administrateurs';

  @override
  String get communityOnlyAdminGroups =>
      'Seuls les groupes que tu administres peuvent rejoindre une communauté.';

  @override
  String get channelPostsUnavailable => 'Publications indisponibles.';

  @override
  String get channelReactionFailed => 'Réaction non enregistrée.';

  @override
  String get channelPostFailed => 'Publication impossible.';

  @override
  String get channelEditPost => 'Modifier la publication';

  @override
  String get channelEditTooOld =>
      'Modification impossible — publication trop ancienne.';

  @override
  String get channelDeletePost => 'Supprimer la publication ?';

  @override
  String get channelDeleteBody => 'Elle disparaîtra pour tous les abonnés.';

  @override
  String get channelDeleteFailed => 'Suppression impossible.';

  @override
  String get channelLinkCopied => 'Lien de la chaîne copié.';

  @override
  String get channelLinkUnavailable => 'Lien indisponible.';

  @override
  String get channelEdit => 'Modifier la chaîne';

  @override
  String get channelPublish => 'Publier';

  @override
  String channelFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abonnés',
      one: '1 abonné',
    );
    return '$_temp0';
  }

  @override
  String get channelFollowing => 'Abonné';

  @override
  String get channelEdited => '· modifié';

  @override
  String get channelImageFailed => 'Image non envoyée.';

  @override
  String get channelNewPost => 'Nouvelle publication';

  @override
  String get channelPostHint => 'Ton annonce…';

  @override
  String pollAnswerN(int index) {
    return 'Réponse $index';
  }

  @override
  String get pollAddAnswer => 'Ajouter une réponse';

  @override
  String get pollMultiple => 'Plusieurs réponses possibles';

  @override
  String get pollAddImage => 'Ajouter une image';

  @override
  String get pollRemove => 'Retirer le sondage';

  @override
  String get pollOne => 'Sondage';

  @override
  String get pollQuestion => 'Ta question';

  @override
  String get commonSending => 'Envoi…';

  @override
  String channelPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count publications',
      one: '1 publication',
    );
    return '$_temp0';
  }

  @override
  String get lockChooseCode => 'Choisir un code';

  @override
  String get lockCodeRule =>
      '4 à 8 chiffres. Le code ne quitte jamais ce téléphone et ne peut pas être retrouvé — en cas d\'oubli, le verrou se lève en vérifiant ton numéro de téléphone.';

  @override
  String get lockCode => 'Code';

  @override
  String get lockConfirmCode => 'Confirmer le code';

  @override
  String get lockTooShort => 'Le code doit faire au moins 4 chiffres.';

  @override
  String get lockMismatch => 'Les deux codes ne correspondent pas.';

  @override
  String get lockCurrentCode => 'Code actuel';

  @override
  String get lockValidate => 'Valider';

  @override
  String get lockEnabledToast => 'Verrouillage activé.';

  @override
  String get lockSaveFailed => 'Impossible d\'enregistrer le code.';

  @override
  String get lockEnterCurrent => 'Saisir le code actuel';

  @override
  String get lockWrongCode => 'Code incorrect.';

  @override
  String get lockCodeChanged => 'Code modifié.';

  @override
  String get lockEnterToDisable => 'Saisir le code pour désactiver';

  @override
  String get lockDisabledToast => 'Verrouillage désactivé.';

  @override
  String get lockTitle => 'Verrouillage de l\'application';

  @override
  String get lockByCode => 'Verrouiller par code';

  @override
  String get lockOn => 'Activé';

  @override
  String get lockOff => 'Désactivé';

  @override
  String get lockChangeCode => 'Changer le code';

  @override
  String get lockFootnoteKeystore =>
      'Pokou demande le code à chaque retour au premier plan. Le code est gardé dans le coffre sécurisé du système (Keystore), pas envoyé au serveur : il protège l\'écran, pas les données de l\'appareil lui-même.';

  @override
  String get lockFootnoteBiometrics =>
      'L\'empreinte digitale n\'est pas encore proposée — elle demande un changement de configuration Android (FlutterFragmentActivity et la permission USE_BIOMETRIC).';

  @override
  String get lockScreenTitle => 'Pokou est verrouillé';

  @override
  String get lockEnterToContinue => 'Saisis ton code pour continuer.';

  @override
  String get lockUnlock => 'Déverrouiller';

  @override
  String get lockForgotQuestion => 'Code oublié ?';

  @override
  String get lockSendFailed => 'Envoi impossible — vérifie ta connexion.';

  @override
  String get lockRemovedToast =>
      'Verrouillage retiré. Tu peux choisir un nouveau code dans Profil.';

  @override
  String get lockVerifyFailed =>
      'Vérification impossible — vérifie ta connexion.';

  @override
  String get lockLogoutQuestion => 'Se déconnecter ?';

  @override
  String get lockLogoutBody =>
      'À utiliser si tu n\'as plus accès à ce numéro. Tes discussions restent sur le serveur, mais il faudra un numéro joignable pour te reconnecter.';

  @override
  String get lockLogout => 'Se déconnecter';

  @override
  String get lockForgotTitle => 'Code oublié';

  @override
  String get lockNoPhoneOnDevice =>
      'Impossible de retrouver ton numéro sur ce téléphone.';

  @override
  String lockEnterSentCode(String phone) {
    return 'Saisis le code envoyé au $phone par SMS et WhatsApp.';
  }

  @override
  String lockForgotExplain(String phone) {
    return 'Le code de verrouillage n\'est stocké que sur ce téléphone et ne peut pas être retrouvé. Pour lever le verrou, vérifie ton numéro $phone.';
  }

  @override
  String get lockLift => 'Lever le verrouillage';

  @override
  String get lockSendCode => 'Envoyer un code';

  @override
  String get lockResendCode => 'Renvoyer le code';

  @override
  String get lockNoAccessToNumber => 'Je n\'ai plus accès à ce numéro';

  @override
  String get notifInApp => 'Dans l\'application';

  @override
  String get notifMessages => 'Messages';

  @override
  String get notifMessagesSub => 'Conversations individuelles';

  @override
  String get notifMessagesSemantic => 'Notifications de messages';

  @override
  String get notifGroups => 'Groupes';

  @override
  String get notifGroupsSub => 'Conversations de groupe';

  @override
  String get notifGroupsSemantic => 'Notifications de groupes';

  @override
  String get notifCallsSub => 'Appels audio et vidéo entrants';

  @override
  String get notifCallsSemantic => 'Notifications d\'appels';

  @override
  String get notifSound => 'Son et vibration';

  @override
  String get notifSoundSemantic => 'Son des notifications';

  @override
  String get notifCallsFootnote =>
      'Couper les appels ici ne supprime que la bannière affichée quand Pokou est ouvert : un appel entrant continue de sonner en plein écran, sinon tu manquerais des appels sans le savoir.';

  @override
  String get notifSystem => 'Système';

  @override
  String get notifWebEnable => 'Activer les notifications Web';

  @override
  String get notifWebEnableSub =>
      'Autoriser ce navigateur à recevoir les notifications Pokou.';

  @override
  String get notifWebEnabled => 'Notifications du navigateur activées.';

  @override
  String get notifWebEnableFailed =>
      'Impossible d\'activer les notifications. Vérifie les réglages de ce site dans le navigateur.';

  @override
  String get notifAndroidSettings => 'Réglages Android';

  @override
  String get notifAndroidSettingsSub => 'Autorisation, canaux, son par canal';

  @override
  String get notifSystemFootnote =>
      'Quand Pokou est fermé, c\'est Android qui affiche les notifications reçues, sans passer par l\'application : seuls les réglages système ci-dessus peuvent les modifier.';

  @override
  String get devicesRemoveTitle => 'Retirer cet appareil ?';

  @override
  String get devicesRemoveCurrentBody =>
      'Ce téléphone ne recevra plus de notifications tant que tu n\'ouvriras pas Pokou à nouveau.';

  @override
  String get devicesRemoveOtherBody =>
      'Cet appareil ne recevra plus de notifications. Il reste connecté jusqu\'à sa prochaine déconnexion.';

  @override
  String get devicesRemove => 'Retirer';

  @override
  String get devicesRemoveFailed => 'Impossible de retirer cet appareil.';

  @override
  String get devicesTitle => 'Appareils connectés';

  @override
  String get devicesUnavailable =>
      'Liste indisponible — vérifie ta connexion, puis tire pour rafraîchir.';

  @override
  String get devicesEmpty =>
      'Aucun appareil enregistré pour les notifications. Elles s\'activent à la première ouverture de Pokou sur un appareil.';

  @override
  String get devicesThisDevice => ' · cet appareil';

  @override
  String devicesLastSeen(String date, String hint) {
    return 'Actif le $date · …$hint';
  }

  @override
  String get devicesFootnote =>
      'Un appareil apparaît ici dès qu\'il s\'enregistre pour les notifications push. Le retirer coupe ses notifications ; cela ne ferme pas sa session, qui expire d\'elle-même.';

  @override
  String get devicesBrowser => 'Navigateur';

  @override
  String devicesTodayAt(String time) {
    return 'aujourd\'hui à $time';
  }

  @override
  String get storageNoCachedMedia => 'Aucun média en cache.';

  @override
  String storageFilesCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers supprimés du cache.',
      one: '1 fichier supprimé du cache.',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Stockage et données';

  @override
  String get storageCachedMedia => 'Médias en cache';

  @override
  String get storageMediaLabel => 'Photos, vidéos et notes vocales';

  @override
  String get storageComputing => 'Calcul en cours…';

  @override
  String get storageNoFile => 'Aucun fichier';

  @override
  String storageFileCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return '$_temp0 · $size';
  }

  @override
  String get storageClearCache => 'Vider le cache';

  @override
  String get storageClearFootnote =>
      'Les fichiers vidés sont retéléchargés à la demande quand tu rouvres la discussion : rien n\'est perdu, seulement libéré.';

  @override
  String get storageMobileData => 'En données mobiles';

  @override
  String get storageDataSaver => 'Économie de données';

  @override
  String get storageDataSaverSub =>
      'Ne pas télécharger les médias automatiquement';

  @override
  String get storageDataSaverFootnote =>
      'Activée, les photos et vidéos reçues attendent que tu les touches pour se télécharger, et les photos que tu envoies sont compressées davantage.';

  @override
  String get profileAvatarFailed =>
      'Impossible de mettre à jour la photo de profil.';

  @override
  String get profileChooseMonitor => 'Choisir un moniteur';

  @override
  String get profileBabaMessaging => 'Messagerie Baba';

  @override
  String profileMonitorAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alertes de $count moniteurs',
      one: 'Alertes de 1 moniteur',
    );
    return '$_temp0';
  }

  @override
  String get profileBabaAssistant => 'Assistant Baba';

  @override
  String get profileShieldModeBody =>
      'Met en attente les appels et met en veilleuse les discussions non prioritaires pendant que tu es concentré. Tes contacts étiquetés Business, Client, Fournisseur ou Boss passent toujours.';

  @override
  String get contactConnectFailed => 'Connexion impossible.';

  @override
  String get contactCallFailed => 'Appel impossible pour l\'instant.';

  @override
  String contactBlockTitle(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get contactBlockBody =>
      'Cette personne ne pourra plus t\'écrire ni t\'appeler. Elle n\'en sera pas informée.';

  @override
  String get contactActionFailed => 'Action impossible pour le moment.';

  @override
  String get contactSavedToast => 'Contact enregistré';

  @override
  String get contactCall => 'Appel';

  @override
  String get contactSharedTitle => 'Éléments échangés';

  @override
  String get contactSharedMedia => 'Médias';

  @override
  String get contactSharedDocuments => 'Documents';

  @override
  String get contactSharedLinks => 'Liens';

  @override
  String get contactNoMedia => 'Aucune photo ni vidéo échangée.';

  @override
  String get contactNoDocuments => 'Aucun document échangé.';

  @override
  String get contactNoLinks => 'Aucun lien échangé.';

  @override
  String contactCommonGroups(int count) {
    return 'Groupes en commun ($count)';
  }

  @override
  String contactCatalog(int count) {
    return 'Catalogue ($count)';
  }

  @override
  String contactUnblockName(String name) {
    return 'Débloquer $name';
  }

  @override
  String contactBlockName(String name) {
    return 'Bloquer $name';
  }

  @override
  String get contactUnblockHint =>
      'Cette personne peut à nouveau t\'écrire et t\'appeler.';

  @override
  String get contactBlockHint =>
      'Elle ne pourra plus t\'écrire ni t\'appeler, sans en être informée.';

  @override
  String get adNeedTitleBody => 'Donne un titre et un message à ta publicité.';

  @override
  String get adSendFailed => 'La demande n\'a pas pu être envoyée.';

  @override
  String get adCreateTitle => 'Créer une publicité';

  @override
  String get adWhoSeesTitle => 'Qui la verra';

  @override
  String get adWhoSeesBody =>
      'Tous les utilisateurs de Pokou dans Assimé, ou entre deux statuts — à toi de choisir.';

  @override
  String get adReviewTitle => 'Une relecture avant diffusion';

  @override
  String get adReviewBody =>
      'Notre équipe lit chaque campagne avant qu\'elle ne parte. Compte quelques heures.';

  @override
  String get adCountdownTitle => 'Le décompte part de la validation';

  @override
  String get adCountdownBody =>
      'Tes jours de diffusion commencent une fois la campagne acceptée, pas au paiement.';

  @override
  String get adRefundTitle => 'Refusée ? Tu es remboursé';

  @override
  String get adRefundBody =>
      'Si la campagne ne peut pas être diffusée, contacte-nous : la somme t\'est rendue.';

  @override
  String get adTitleHint => 'Ex : Ciment CIMTOGO en promotion';

  @override
  String get adBodyHint => 'Ce que tu proposes, et comment te joindre.';

  @override
  String get adMediaLabel => 'Photo ou vidéo (facultatif)';

  @override
  String get adMediaHint =>
      'Une vidéo de 30 secondes au maximum. Sans image, seul le texte est diffusé.';

  @override
  String get adVideo30s => 'Vidéo 30 s';

  @override
  String get adPlacement => 'Emplacement';

  @override
  String get adPlacementMarket => 'Onglet Marché';

  @override
  String get adPlacementStatus => 'Entre les statuts';

  @override
  String get adDuration => 'Durée';

  @override
  String get adOneWeek => '1 semaine';

  @override
  String get adTwoWeeks => '2 semaines';

  @override
  String get adOneMonth => '1 mois';

  @override
  String get adPayCaption => 'Paiement Mobile Money';

  @override
  String get adPayAction => 'Payer et envoyer';

  @override
  String productInterestedMessage(String name, String price, String currency) {
    return 'Bonjour, je suis intéressé par ton annonce « $name » à $price $currency. Est-elle toujours disponible ?';
  }

  @override
  String get productWriteFailed =>
      'Impossible d\'écrire au vendeur pour l\'instant.';

  @override
  String get productCallFirstWrite => 'Appel impossible — écris-lui d\'abord.';

  @override
  String get productRateSeller => 'Noter ce vendeur';

  @override
  String get productEditReview => 'Modifier mon avis';

  @override
  String get productReviewScope =>
      'L\'avis porte sur le VENDEUR, pas sur un produit : c\'est la confiance dans la personne qui compte, et elle reste même si l\'article quitte le catalogue.';

  @override
  String get productReviewHint => 'Ton commentaire (facultatif)';

  @override
  String get productDeleteReview => 'Supprimer mon avis';

  @override
  String get productReviewFailed => 'Avis non enregistré.';

  @override
  String get productTitle => 'Produit';

  @override
  String get productOpening => 'Ouverture…';

  @override
  String get productDiscuss => 'Discuter';

  @override
  String get productCallAction => 'Appeler';

  @override
  String get productReviews => 'Avis';

  @override
  String get productNoReviewYet => 'Pas encore d\'avis';

  @override
  String productRatingSummary(String rating, int reviews) {
    String _temp0 = intl.Intl.pluralLogic(
      reviews,
      locale: localeName,
      other: '$reviews avis',
      one: '1 avis',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String productCountSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '1 produit',
    );
    return ' · $_temp0';
  }

  @override
  String get productCertified => 'Compte vérifié par l\'équipe Pokou.';

  @override
  String get productReviewMine => 'Toi';

  @override
  String get verifNeedDocument => 'Ajoute une photo de ta pièce d\'identité.';

  @override
  String get verifTitle => 'Devenir vendeur vérifié';

  @override
  String get verifBadgeTitle => 'Un badge bleu sur tes annonces';

  @override
  String get verifBadgeBody =>
      'Les acheteurs voient que ton identité a été vérifiée par notre équipe.';

  @override
  String get verifWhyTitle => 'Pourquoi ça change tout';

  @override
  String get verifWhyBody =>
      'Un acheteur envoie plus facilement de l\'argent Mobile Money à quelqu\'un dont l\'identité est confirmée qu\'à un inconnu.';

  @override
  String get verifNeedTitle => 'Ce qu\'il faut fournir';

  @override
  String get verifNeedBody =>
      'Une photo nette de ta carte d\'identité, passeport ou permis. Le nom doit être lisible.';

  @override
  String get verifUseTitle => 'Ce que nous en faisons';

  @override
  String get verifUseBody =>
      'Elle est lue par notre équipe pour la seule vérification, n\'apparaît jamais sur ton profil, et n\'est montrée à aucun acheteur.';

  @override
  String get verifOneYearTitle => 'Valable un an';

  @override
  String get verifOneYearBody =>
      'Le badge dure douze mois. Compte quelques jours pour l\'examen du dossier.';

  @override
  String get verifDocumentLabel => 'Ta pièce d\'identité';

  @override
  String get verifPayCaption => 'Paiement Mobile Money · 1 an';

  @override
  String get verifChoosePhoto => 'Choisir une photo';

  @override
  String get verifChange => 'Changer';

  @override
  String get marketRemoveBody =>
      'L\'annonce disparaît d\'Assimé. Tes discussions à son sujet restent lisibles, et les acheteurs qui l\'ont déjà reçue gardent leur historique.';

  @override
  String get marketRemoveFailed => 'L\'annonce n\'a pas pu être retirée.';

  @override
  String get marketImageFailed => 'Image non envoyée — réessaie.';

  @override
  String get marketMainPhotoHint =>
      'C\'est elle qui illustre le produit dans la liste.';

  @override
  String get marketName => 'Nom';

  @override
  String get marketPrice => 'Prix';

  @override
  String get marketNoReviewYet => 'pas encore d\'avis';

  @override
  String get marketSearchHint => 'Rechercher un produit…';

  @override
  String get callLogEmpty => 'Aucun appel pour l\'instant.';

  @override
  String get callLogUnknownUser => 'Utilisateur';

  @override
  String get callStatusMissed => 'Manqué';

  @override
  String get callStatusNoAnswer => 'Sans réponse';

  @override
  String get callStatusDeclined => 'Refusé';

  @override
  String get callStatusReceived => 'Reçu';

  @override
  String get callStatusEnded => 'Terminé';

  @override
  String get callStatusOngoing => 'En cours';

  @override
  String get callStatusOutgoing => 'Appelé';

  @override
  String get callVideoTitle => 'Appel vidéo';

  @override
  String get callAudioTitle => 'Appel audio';

  @override
  String callRedialQuestion(String name) {
    return 'Rappeler $name ?';
  }

  @override
  String get callJoinFailed => 'Connexion à l\'appel impossible.';

  @override
  String get callNobodyToAdd => 'Personne d\'autre à ajouter.';

  @override
  String get callAddToCall => 'Ajouter à l\'appel';

  @override
  String get callAdd => 'Ajouter';

  @override
  String get callAddFailed => 'Impossible d\'ajouter ce participant.';

  @override
  String get callReactionFailed => 'Impossible d\'envoyer cette réaction.';

  @override
  String get callLeaveConfirmTitle => 'Quitter l\'appel ?';

  @override
  String get callLeaveConfirmBody =>
      'Les autres participants peuvent encore parler. Pour revenir à l\'appel, tu peux fermer cet écran sans raccrocher.';

  @override
  String get callYou => 'Toi';

  @override
  String get callContact => 'Contact';

  @override
  String get callConnecting => 'Connexion à l\'appel…';

  @override
  String get callPreparing => 'L\'appel est en cours de préparation';

  @override
  String get callWaiting => 'En attente…';

  @override
  String get callJoinImpossible => 'Impossible de rejoindre l\'appel.';

  @override
  String get callEncryptedJoinFailed =>
      'Cet appel chiffré n\'a pas pu être ouvert sur ce téléphone. L\'appelant en est averti.';

  @override
  String get callIncoming => 'Appel entrant';

  @override
  String callIncomingFrom(String name) {
    return '$name t\'appelle';
  }

  @override
  String get callIncomingGroup => 'Appel de groupe entrant';

  @override
  String get streakSubtitle =>
      'Un jour manqué, quelques minutes pour le rattraper';

  @override
  String get streakUnavailable => 'Chaînes indisponibles';

  @override
  String get streakCheckConnection => 'Vérifie ta connexion et réessaie.';

  @override
  String get streakEmptyTitle => 'Aucune chaîne pour le moment';

  @override
  String get streakEmptyBody =>
      'Échange un message chaque jour avec la même personne : la chaîne démarre au premier aller-retour.';

  @override
  String get streakToRescue => 'À sauver maintenant';

  @override
  String get streakToRescueSub => 'Passé le délai, la chaîne repart de zéro';

  @override
  String get streakMine => 'Mes chaînes';

  @override
  String get streakRunning => 'En cours';

  @override
  String streakRecord(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'Record : $_temp0';
  }

  @override
  String get streakLongest => 'Ta plus longue chaîne';

  @override
  String get streakRestorePending =>
      'Ta chaîne repartira dès la confirmation du paiement.';

  @override
  String get streakDeadlinePassed => 'Le délai est peut-être passé.';

  @override
  String streakBroken(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Chaîne de $days jours rompue',
      one: 'Chaîne de 1 jour rompue',
    );
    return '$_temp0';
  }

  @override
  String get streakExpired => 'Le délai est passé. La chaîne repart de zéro.';

  @override
  String streakCountdown(String time) {
    return 'Encore $time pour la sauver';
  }

  @override
  String streakRescueAction(int amount) {
    return 'Sauver la chaîne — $amount FCFA';
  }

  @override
  String get leagueSubtitle => 'Ta ligue monte avec ce que tu reçois';

  @override
  String get leagueUnavailable => 'Classement indisponible';

  @override
  String get leagueRanking => 'Classement';

  @override
  String get leagueProtectPending =>
      'Ta protection sera active dès la confirmation du paiement.';

  @override
  String get leaguePaymentFailed => 'Le paiement n\'a pas pu être lancé.';

  @override
  String get leagueAtTop => 'Tu es au sommet du classement.';

  @override
  String leaguePointsNeeded(int points, String label) {
    return 'Encore $points points pour $label.';
  }

  @override
  String get leagueProtected =>
      'Tes points sont protégés. Rien ne baisse cette semaine.';

  @override
  String get leagueDecayNow => 'Tes points baissent au prochain passage.';

  @override
  String leagueDecayIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Tes points baissent dans $days jours sans activité.',
      one: 'Tes points baissent dans 1 jour sans activité.',
    );
    return '$_temp0';
  }

  @override
  String get leagueProtectAction => 'Protéger mes points — 500 FCFA';

  @override
  String get leagueNobodyRanked =>
      'Personne n\'est encore classé. Sois le premier.';

  @override
  String leagueMyRank(int rank, int points) {
    return 'Tu es $rankᵉ avec $points points.';
  }

  @override
  String get reactWith => 'Réagir avec…';

  @override
  String get reactPickEmoji => 'Choisir un émoji sur le clavier';

  @override
  String get reactAction => 'Réagir';

  @override
  String get mediaPoll => 'Sondage';

  @override
  String get mediaContact => 'Contact';

  @override
  String get mediaSharedContact => 'Contact partagé';

  @override
  String get convEdited => '· modifié';

  @override
  String get convFallbackName => 'Conversation';

  @override
  String get convSomeone => 'Quelqu\'un';

  @override
  String get contactsTagFailed => 'Impossible de mettre à jour l\'étiquette.';

  @override
  String get contactsTag => 'Étiqueter';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactsTyping => 'écrit…';

  @override
  String contactsTypingNamed(String name) {
    return '$name écrit…';
  }

  @override
  String contactsPreviewMine(String preview) {
    return 'Toi : $preview';
  }

  @override
  String contactsPreviewSender(String name, String preview) {
    return '$name : $preview';
  }

  @override
  String contactsNotInContacts(String preview) {
    return '$preview · pas dans tes contacts';
  }

  @override
  String get contactsAssistantSub => 'Pose-moi une question sur Pokou.';

  @override
  String get addContactTitle => 'Ajouter un contact';

  @override
  String get addContactName => 'Nom';

  @override
  String get addContactAction => 'Ajouter';

  @override
  String get joinLinkTitle => 'Rejoindre par lien';

  @override
  String get joinLinkBody =>
      'Colle le lien qu\'on t\'a envoyé. Groupe ou communauté, on reconnaît lequel.';

  @override
  String get joinLinkContinue => 'Continuer';

  @override
  String get joinLinkUnreadable => 'Lien d\'invitation illisible.';

  @override
  String joinAlreadyMember(String name) {
    return 'Tu es déjà dans « $name ».';
  }

  @override
  String joinGroupQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0. Rejoindre ce groupe ?';
  }

  @override
  String get joinAction => 'Rejoindre';

  @override
  String get joinGroupFailed => 'Impossible de rejoindre ce groupe.';

  @override
  String joinCommunityCounts(int members, int groups) {
    String _temp0 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members membres',
      one: '1 membre',
    );
    String _temp1 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groupes',
      one: '1 groupe',
    );
    return '$_temp0 · $_temp1.';
  }

  @override
  String get joinCommunityBody =>
      'Tu recevras ses annonces. Les autres groupes restent à rejoindre un par un.';

  @override
  String get joinCommunityFailed => 'Impossible de rejoindre cette communauté.';

  @override
  String get newChatOwnNumber => 'C\'est ton propre numéro.';

  @override
  String get phoneLookupFailed => 'Numéro invalide ou vérification impossible.';

  @override
  String get phoneNotOnPokou => 'Ce numéro n\'utilise pas encore Pokou.';

  @override
  String get phoneInviteWhatsApp => 'Inviter par WhatsApp';

  @override
  String get phoneInviteText =>
      'Salut ! Je t\'invite à essayer Pokou, une messagerie privée — télécharge l\'app et ajoute-moi.';

  @override
  String get contactCardTitle => 'Carte de visite';

  @override
  String get viewOnceSeen => 'Consultée';

  @override
  String get viewOnceTapToSee => 'Vue unique — toucher pour voir';

  @override
  String get audioPlayFailed => 'Lecture impossible';

  @override
  String mediaPhotoSize(Object size) {
    return 'Photo · $size';
  }

  @override
  String get mediaTapToDownload => 'Toucher pour télécharger';

  @override
  String get mediaVideoUnavailable => 'Vidéo indisponible';

  @override
  String get mediaOpenDocFailed => 'Impossible d\'ouvrir ce document.';

  @override
  String get mediaOpenRetry => 'Échec de l\'ouverture — toucher pour réessayer';

  @override
  String get dayToday => 'Aujourd\'hui';

  @override
  String get dayYesterday => 'Hier';

  @override
  String get weekdayMonday => 'lundi';

  @override
  String get weekdayTuesday => 'mardi';

  @override
  String get weekdayWednesday => 'mercredi';

  @override
  String get weekdayThursday => 'jeudi';

  @override
  String get weekdayFriday => 'vendredi';

  @override
  String get weekdaySaturday => 'samedi';

  @override
  String get weekdaySunday => 'dimanche';

  @override
  String liveHoursLeft(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours h restantes',
      one: '1 h restante',
    );
    return '$_temp0';
  }

  @override
  String liveMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min restantes',
      one: '1 min restante',
    );
    return '$_temp0';
  }

  @override
  String get liveAlmostOver => 'bientôt terminé';

  @override
  String liveLocation(String remaining) {
    return 'En direct · $remaining';
  }

  @override
  String get openInMaps => 'Ouvrir dans Maps';

  @override
  String get composerEditPhoto => 'Modifier la photo';

  @override
  String get composerEditorFailed => 'L\'éditeur n\'a pas pu s\'ouvrir.';

  @override
  String get composerCropRotate => 'Rogner ou pivoter';

  @override
  String get composerCaptionHint => 'Ajouter une légende…';

  @override
  String composerTo(String name) {
    return 'à $name';
  }

  @override
  String get composerSend => 'Envoyer';

  @override
  String get convOfflineNotCached =>
      'Hors ligne — cette conversation n\'est pas encore en mémoire.';

  @override
  String get convLoadFailed => 'Impossible de charger la conversation.';

  @override
  String get convEmptyEdit => 'Un message vide ne peut pas remplacer un texte.';

  @override
  String get convEditFailed =>
      'Modification impossible — vérifie ta connexion.';

  @override
  String get convOrderUpdateFailed =>
      'Impossible de mettre à jour la commande.';

  @override
  String get convDeleteFailed => 'Impossible de supprimer le message.';

  @override
  String get convForwardFailedMsg => 'Impossible de transférer le message.';

  @override
  String get convOfflineAttachment =>
      'Hors ligne — les pièces jointes exigent une connexion.';

  @override
  String get convAttachmentFailed => 'Pièce jointe non envoyée — réessaie.';

  @override
  String get groupOfflineNotCached =>
      'Hors ligne — ce groupe n\'est pas encore en mémoire.';

  @override
  String get groupLoadFailed => 'Impossible de charger le groupe.';

  @override
  String get groupRenameFailed => 'Impossible de renommer le groupe.';

  @override
  String get groupPhotoFailed => 'Photo du groupe non enregistrée.';

  @override
  String get groupClearPhotoFailed => 'Impossible de retirer la photo.';

  @override
  String get groupRoleFailed => 'Impossible de changer ce rôle.';

  @override
  String get groupInviteCreateFailed =>
      'Impossible de créer le lien d\'invitation.';

  @override
  String get groupInviteRevokeFailed => 'Impossible de désactiver le lien.';

  @override
  String get groupLeaveFailed => 'Impossible de quitter le groupe.';

  @override
  String get groupRemoveMemberFailed => 'Impossible de retirer ce membre.';

  @override
  String get apiNetworkSilent => 'Le réseau ne répond pas';

  @override
  String apiError(int code) {
    return 'Erreur ($code)';
  }

  @override
  String get orderProductDiscussed => 'Article discuté';

  @override
  String get orderValidate => 'Valider la commande';

  @override
  String get orderMarkShipped => 'Marquer comme expédié';

  @override
  String get orderMarkDelivered => 'Marquer comme livré';

  @override
  String get orderBuyerWaiting => 'Cet acheteur attend ta réponse.';

  @override
  String get orderNextStep => 'Étape suivante de la commande.';

  @override
  String get msgNotSentRetry => 'Non envoyé — toucher pour réessayer';

  @override
  String get msgPendingSend => 'En attente d\'envoi';

  @override
  String convSearchHint(String name) {
    return 'Rechercher dans $name…';
  }

  @override
  String get convSearchPrompt =>
      'Tape un mot pour retrouver un message de cette discussion.';

  @override
  String get convSearchEmpty => 'Aucun message trouvé.';

  @override
  String get commonUnknownName => 'Inconnu';

  @override
  String get groupInviteLink => 'Lien d\'invitation';

  @override
  String get groupDemoteAdmin => 'Retirer l\'administration';

  @override
  String get groupPromoteAdmin => 'Nommer administrateur';

  @override
  String get groupInviteLinkBody =>
      'Toute personne qui ouvre ce lien rejoint le groupe directement, sans autre étape. Régénère-le pour invalider celui déjà partagé.';

  @override
  String get groupNewLinkCreated =>
      'Nouveau lien créé — l\'ancien ne fonctionne plus.';

  @override
  String get groupAddFailed => 'Ajout impossible.';

  @override
  String get groupCreateFailed => 'Création du groupe impossible.';

  @override
  String get groupNewTitle => 'Nouveau groupe';

  @override
  String get groupCreateAction => 'Créer';

  @override
  String get groupNameHint => 'Nom du groupe';

  @override
  String get groupPickParticipants => 'Choisis les participants';

  @override
  String groupSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants sélectionnés',
      one: '1 participant sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get pushIncomingVideoCall => 'Appel vidéo entrant';

  @override
  String get pushIncomingAudioCall => 'Appel audio entrant';

  @override
  String get pushAnswer => 'Répondre';

  @override
  String get pushDecline => 'Refuser';

  @override
  String get pushMessagesChannel => 'Messages';

  @override
  String get pushMessagesChannelDesc =>
      'Notifications pour les nouveaux messages Pokou';

  @override
  String get pushCallsChannel => 'Appels';

  @override
  String get pushCallsChannelDesc =>
      'Notifications pour les appels entrants Pokou';

  @override
  String get pushGroupFallback => 'Groupe';

  @override
  String get notifNewMessage => 'Nouveau message';

  @override
  String get notifPhoto => '📷 Photo';

  @override
  String get notifVideo => '🎥 Vidéo';

  @override
  String get notifVoice => '🎤 Message vocal';

  @override
  String get notifDocument => '📄 Document';

  @override
  String get notifSticker => 'Autocollant';

  @override
  String get notifLocation => '📍 Position';

  @override
  String get notifContact => '👤 Contact';

  @override
  String get notifPoll => '📊 Sondage';

  @override
  String get notifMe => 'Moi';

  @override
  String get notifReply => 'Répondre';

  @override
  String get notifReplyHint => 'Ton message';

  @override
  String get notifMarkRead => 'Marquer comme lu';

  @override
  String get notifReplyQueued => 'envoi à l\'ouverture de Pokou';

  @override
  String get notifReplyFailed =>
      'Réponse non envoyée — ouvre Pokou pour réessayer';

  @override
  String notifSummary(int count, int conversations) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    String _temp1 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations conversations',
      one: '1 conversation',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get audienceContacts => 'Mes contacts';

  @override
  String get audienceNobody => 'Personne';

  @override
  String get audienceExcept => 'Mes contacts sauf…';

  @override
  String get audienceOnly => 'Uniquement…';

  @override
  String get audienceContactsDesc => 'Toutes les personnes de ton carnet Pokou';

  @override
  String get audienceNobodyDesc => 'Tes statuts ne seront visibles que par toi';

  @override
  String get audienceExceptDesc =>
      'Tes contacts, à l\'exception de ceux que tu choisis';

  @override
  String get audienceOnlyDesc => 'Seules les personnes que tu choisis';

  @override
  String get statusViewerFallback => 'Utilisateur';

  @override
  String get statusPrivacySaved => 'Visibilité enregistrée.';

  @override
  String get statusPrivacySaveFailed =>
      'Enregistrement impossible — vérifie ta connexion.';

  @override
  String get statusPrivacyTitle => 'Qui voit mes statuts';

  @override
  String get statusExcludePeople => 'Personnes à exclure';

  @override
  String get statusAllowedPeople => 'Personnes autorisées';

  @override
  String get statusNoContactToOffer =>
      'Aucun contact Pokou à proposer pour le moment.';

  @override
  String get statusExceptFootnote =>
      'Ces personnes ne verront pas tes statuts, même si elles sont dans tes contacts.';

  @override
  String get statusOnlyFootnote =>
      'Seules ces personnes verront tes statuts. Elles n\'ont pas besoin de t\'avoir en contact.';

  @override
  String get status24hFootnote =>
      'Un statut disparaît de toute façon au bout de 24 heures, pour tout le monde.';

  @override
  String get statusGallery => 'Galerie';

  @override
  String get statusCamera => 'Appareil photo';

  @override
  String get statusNewTitle => 'Nouveau statut';

  @override
  String get statusText => 'Texte';

  @override
  String get statusTypeHint => 'Tape ton statut…';

  @override
  String get statusPublish => 'Publier';

  @override
  String get statusFeedTitle => 'Actualités';

  @override
  String get statusFeedUnavailable => 'Statuts indisponibles — réessayer';

  @override
  String get statusSection => 'Statuts';

  @override
  String get statusMine => 'Moi';

  @override
  String get channelsSection => 'Chaînes';

  @override
  String get bcastNeedName => 'Donne un nom à cette liste.';

  @override
  String get bcastNeedRecipient => 'Choisis au moins un destinataire.';

  @override
  String get bcastSaveFailed => 'Enregistrement impossible.';

  @override
  String get bcastNewTitle => 'Nouvelle diffusion';

  @override
  String get bcastEditTitle => 'Modifier la liste';

  @override
  String get bcastNameHint => 'Nom de la liste (visible par toi seul)';

  @override
  String get bcastNoRecipient => 'Aucun destinataire';

  @override
  String bcastRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destinataires',
      one: '1 destinataire',
    );
    return '$_temp0';
  }

  @override
  String get bcastContactsUnavailable => 'Contacts indisponibles.';

  @override
  String get bcastNobodyOnPokou =>
      'Aucun de tes contacts n\'est encore sur Pokou.';

  @override
  String get bcastNewList => 'Nouvelle liste';

  @override
  String get bcastListsTitle => 'Listes de diffusion';

  @override
  String get bcastListsUnavailable => 'Listes indisponibles.';

  @override
  String bcastDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get bcastDeleteBody =>
      'Les messages déjà envoyés restent chez leurs destinataires. Seule la liste disparaît.';

  @override
  String get bcastEmptyTitle => 'Annonce une fois, à plusieurs';

  @override
  String get bcastEmptyBody =>
      'Chaque destinataire reçoit le message dans sa discussion privée. Il ne voit pas les autres, et ne répond qu\'à toi — contrairement à un groupe, où tout le monde se voit.';

  @override
  String bcastSentTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Envoyé à $count destinataires.',
      one: 'Envoyé à 1 destinataire.',
    );
    return '$_temp0';
  }

  @override
  String bcastSentPartly(int sent, int total, int skipped) {
    return 'Envoyé à $sent sur $total — $skipped ne reçoit plus tes messages.';
  }

  @override
  String get bcastSendFailed => 'L\'envoi a échoué.';

  @override
  String get bcastEditRecipients => 'Modifier les destinataires';

  @override
  String get bcastHistoryUnavailable => 'Historique indisponible.';

  @override
  String get bcastNothingSent => 'Rien n\'a encore été diffusé.';

  @override
  String get bcastMessageHint => 'Message à diffuser';

  @override
  String get bcastPrivacyNotice =>
      'Chaque destinataire reçoit ce message en privé. Il ne voit pas les autres, et sa réponse t\'arrive dans ta discussion avec lui.';

  @override
  String get channelNameRequired => 'Le nom de la chaîne est obligatoire.';

  @override
  String get channelSaveFailed => 'Impossible d\'enregistrer la chaîne.';

  @override
  String get channelEditTitle => 'Modifier la chaîne';

  @override
  String get channelNewTitle => 'Nouvelle chaîne';

  @override
  String get channelAddImage => 'Ajouter une image';

  @override
  String get channelChangeImage => 'Changer l\'image';

  @override
  String get channelRemoveImage => 'Retirer l\'image';

  @override
  String get channelNameLabel => 'Nom de la chaîne';

  @override
  String get channelNameHint => 'Ex. Actualités de mon entreprise';

  @override
  String get channelDescriptionLabel => 'Description';

  @override
  String get channelDescriptionHint => 'Présente ta chaîne';

  @override
  String get channelSaveChanges => 'Enregistrer les modifications';

  @override
  String get channelCreateAction => 'Créer la chaîne';

  @override
  String get channelLinkCopiedClipboard => 'Lien copié dans le presse-papiers.';

  @override
  String get channelLinkUnavailableShort => 'Lien indisponible.';

  @override
  String get channelSearchTooltip => 'Rechercher une chaîne';

  @override
  String get channelCreateTooltip => 'Créer une chaîne';

  @override
  String get channelEmptyHint =>
      'Crée une chaîne pour partager tes actualités.';

  @override
  String get channelGenerateLink => 'Générer un lien';

  @override
  String get channelEditTooltip => 'Modifier';

  @override
  String get channelSearchHint => 'Rechercher une chaîne…';

  @override
  String get channelSearchPrompt =>
      'Cherche par nom ou par description. Les chaînes certifiées apparaissent en premier.';

  @override
  String get channelSearchEmpty => 'Aucune chaîne trouvée.';

  @override
  String get channelNothingPublishedAdmin =>
      'Rien de publié pour l\'instant — touche + pour ta première publication.';

  @override
  String get channelNothingPublished => 'Cette chaîne n\'a encore rien publié.';

  @override
  String get channelFollow => 'S\'abonner';

  @override
  String get channelFallbackName => 'Chaîne';

  @override
  String get communityNewTitle => 'Nouvelle communauté';

  @override
  String get communityNewBody =>
      'Une communauté regroupe plusieurs groupes autour des mêmes personnes. Un groupe « Annonces » est créé avec elle : toi seul y écris, tous ses membres y lisent.';

  @override
  String get communityNameHint => 'Nom de la communauté';

  @override
  String get communityDescriptionHint => 'Description (facultatif)';

  @override
  String get communityCreateAction => 'Créer';

  @override
  String get communityCreateFailed => 'Création impossible.';

  @override
  String get communityNoGroupToAttach =>
      'Tu n\'as pas d\'autre groupe à rattacher. Seuls les groupes que tu administres peuvent rejoindre une communauté.';

  @override
  String get communityAddGroupFailed => 'Impossible d\'ajouter ce groupe.';

  @override
  String get communityLinkFailed => 'Impossible de créer le lien.';

  @override
  String get communityCreateLink => 'Créer un lien';

  @override
  String get sparkOpenRoomsSub => 'Elles se referment toutes seules';

  @override
  String get sparkMore => 'Suite';

  @override
  String sparkRoomOpen(String time) {
    return 'Salle ouverte — $time';
  }

  @override
  String get sparkBothYes => 'Vous avez dit oui tous les deux';

  @override
  String get sparkMatchSaved => 'Match sauvé';

  @override
  String get sparkRoomClosed => 'Salle fermée';

  @override
  String get sparkMatch => 'Match';

  @override
  String get sparkUnavailable => 'Spark est indisponible';

  @override
  String get sparkTodaysDate => 'Le rendez-vous d\'aujourd\'hui';

  @override
  String get sparkTabOutings => 'Sorties';

  @override
  String sparkPersonAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String get aiSuggestSummary => 'Résumé';

  @override
  String get aiSuggestSummarySub => 'Vue d\'ensemble rapide';

  @override
  String get aiSuggestSummaryPrompt =>
      'Fais-moi un résumé de la situation actuelle.';

  @override
  String get aiSuggestTrend => 'Tendance';

  @override
  String get aiSuggestTrendSub => 'Analyser une évolution';

  @override
  String get aiSuggestTrendPrompt =>
      'Quelle est la tendance sur les 7 derniers jours ?';

  @override
  String get aiSuggestAlerts => 'Alertes';

  @override
  String get aiSuggestAlertsSub => 'Derniers signaux';

  @override
  String get aiSuggestAlertsPrompt =>
      'Y a-t-il des alertes récentes à connaître ?';

  @override
  String get aiSuggestAdvice => 'Conseil';

  @override
  String get aiSuggestAdviceSub => 'Demander une idée';

  @override
  String get aiSuggestAdvicePrompt =>
      'Donne-moi un conseil pour organiser ma journée.';

  @override
  String get aiSuggestWrite => 'Rédiger';

  @override
  String get aiSuggestWriteSub => 'Écrire un texte';

  @override
  String get aiSuggestWritePrompt => 'Aide-moi à rédiger un message.';

  @override
  String get aiSuggestQuestion => 'Question';

  @override
  String get aiSuggestQuestionSub => 'N\'importe quoi';

  @override
  String get aiSuggestQuestionPrompt => 'J\'ai une question à te poser.';

  @override
  String get aiMessageHint => 'Message…';

  @override
  String get aiHowCanIHelp => 'Comment puis-je t\'aider ?';

  @override
  String get aiAskAnything => 'Pose-moi n\'importe quelle question.';

  @override
  String get aiAskAboutData => 'Pose une question sur tes données connectées.';

  @override
  String get aiThinking => 'Baba réfléchit';

  @override
  String aiHelloIm(String name) {
    return 'Bonjour, je suis $name';
  }

  @override
  String get aiPartner => 'Ton partenaire numérique';

  @override
  String get aiGreetMorning => 'Bonjour';

  @override
  String get aiGreetAfternoon => 'Bon après-midi';

  @override
  String get aiGreetEvening => 'Bonsoir';

  @override
  String get aiNewChat => 'Nouvelle discussion';

  @override
  String get aiCopy => 'Copier';

  @override
  String get aiCopied => 'Copié';

  @override
  String get aiGenerated => 'Généré par l\'IA';

  @override
  String get aiVoiceListening => 'Je t\'écoute…';

  @override
  String get aiVoiceTranscribing => 'Transcription…';

  @override
  String get aiVoiceFailed => 'Je n\'ai pas pu t\'entendre. Réessaie.';

  @override
  String get aiVoiceSpeak => 'Parler à l\'assistant';

  @override
  String get aiVoiceRestart => 'Recommencer';

  @override
  String get aiVoiceSend => 'Envoyer';

  @override
  String get aiVoiceStop => 'Terminer';

  @override
  String get aiSendFailed => 'Message non envoyé — réessaie.';

  @override
  String get digestTitle => 'Récap du jour';

  @override
  String get digestUnread => 'Messages non lus :';

  @override
  String get digestMissedCalls => 'Appels manqués :';

  @override
  String get digestVideoSuffix => ' (vidéo)';

  @override
  String digestShieldDeferred(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages mis en attente par le Mode Bouclier.',
      one: '1 message mis en attente par le Mode Bouclier.',
    );
    return '$_temp0';
  }

  @override
  String digestMonitorSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signaux de tes moniteurs à consulter.',
      one: '1 signal de tes moniteurs à consulter.',
    );
    return '$_temp0';
  }

  @override
  String get digestNothing => 'Rien à signaler aujourd\'hui — bonne soirée !';

  @override
  String get shieldUnknownNumber => 'Numéro inconnu';

  @override
  String shieldFlushSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages mis en attente pendant ta réunion.',
      one: '1 message mis en attente pendant ta réunion.',
    );
    return '$_temp0';
  }

  @override
  String get shieldPendingMessages => 'Messages en attente';

  @override
  String shieldHandleSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count messages mis en attente par le Mode Bouclier — glisser vers le bas pour les afficher',
      one:
          '1 message mis en attente par le Mode Bouclier — glisser vers le bas pour l\'afficher',
    );
    return '$_temp0';
  }

  @override
  String shieldCallFrom(Object name) {
    return 'Appel de $name';
  }

  @override
  String get shieldCallHeld => 'En attente — Mode Bouclier';

  @override
  String get statusViewersUnavailable => 'Liste des vues indisponible.';

  @override
  String statusSeenBy(int count) {
    return 'Vu par $count';
  }

  @override
  String get statusNobodySeen => 'Personne ne l\'a encore vu.';

  @override
  String get statusBoostFailed => 'Boost du statut impossible.';

  @override
  String get statusDeleteTitle => 'Supprimer ce statut ?';

  @override
  String get statusDeleteBody =>
      'Il disparaîtra pour tous ceux qui peuvent le voir.';

  @override
  String get statusDeleteFailed =>
      'Suppression impossible — vérifie ta connexion.';

  @override
  String get statusPublishFailed =>
      'Publication impossible — vérifie ta connexion et réessaie.';

  @override
  String get statusBoostAction => 'Booster ce statut · 1 000 FCFA';

  @override
  String get modulesSubtitle => 'Ajoute ce qui te sert, laisse le reste';

  @override
  String get modulePaymentFailed => 'Le paiement n\'a pas pu être lancé.';

  @override
  String deeplinkFollowedChannel(String name) {
    return 'Abonné à la chaîne « $name »';
  }

  @override
  String get deeplinkOpenFailed =>
      'Ce lien d\'invitation n\'a pas pu être ouvert pour l\'instant.';

  @override
  String get cropTitle => 'Recadrer';

  @override
  String get cropHint => 'Pince pour zoomer, glisse pour cadrer';

  @override
  String get cropConfirm => 'Valider';

  @override
  String get inviteJoinMe => 'Rejoins-moi sur Pokou Messenger';

  @override
  String inviteJoinMeNamed(String name) {
    return '$name, rejoins-moi sur Pokou Messenger';
  }

  @override
  String get otpNoCodeReceived => 'Tu n\'as pas reçu de code ?';

  @override
  String get countryDialCode => 'Indicatif du pays';

  @override
  String get countrySearchHint => 'Pays ou indicatif (ex. Bénin, 229)';

  @override
  String get countryNoneFound => 'Aucun pays trouvé.';

  @override
  String get presenceSomeone => 'Quelqu\'un';

  @override
  String atTime(String time) {
    return 'à $time';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date à $time';
  }

  @override
  String truthAskedTo(String name) {
    return 'À $name';
  }

  @override
  String get devicesNoPushHere =>
      'Cet appareil ne reçoit pas les notifications.';

  @override
  String get devicesNoPushHereBody =>
      'Il n\'a pas pu s\'enregistrer auprès du service de notifications. Touche pour réessayer.';

  @override
  String get devicesRetryDone =>
      'Cet appareil reçoit désormais les notifications.';

  @override
  String get devicesRetryFailed =>
      'Toujours pas d\'enregistrement possible — réessaie plus tard.';

  @override
  String get chatsProfileMissing =>
      'Profil indisponible — vérifie ta connexion, puis réessaie.';

  @override
  String get recSlideToCancel => 'Glisse pour annuler';

  @override
  String get recReleaseToCancel => 'Relâcher pour annuler';

  @override
  String get recLocked => 'Verrouillé';

  @override
  String get recSlideUpToLock => 'Glisser vers le haut pour verrouiller';

  @override
  String get recDelete => 'Supprimer l\'enregistrement';

  @override
  String get recHoldToRecord => 'Maintenir pour enregistrer';

  @override
  String get composerViewOnce => 'Vue unique';

  @override
  String get composerViewOnceOn =>
      'Vue unique activée — la photo disparaîtra après avoir été ouverte.';

  @override
  String get composerViewOnceOff => 'Vue unique désactivée.';

  @override
  String get channelSuggestedTitle => 'Des chaînes à suivre';

  @override
  String get channelSuggestedBody =>
      'Tu n\'en suis aucune pour l\'instant. En voici quelques-unes.';

  @override
  String get channelSuggestedNone => 'Aucune chaîne à proposer pour le moment.';

  @override
  String channelFollowed(String name) {
    return 'Abonné à « $name »';
  }

  @override
  String get channelFollowFailed =>
      'Abonnement impossible — vérifie ta connexion.';

  @override
  String get certifyTitle => 'Chaîne certifiée';

  @override
  String get certifyWhyTitle => 'Un badge, et la tête des suggestions';

  @override
  String get certifyWhyBody =>
      'Les chaînes certifiées apparaissent en premier à qui cherche quoi suivre, et le badge se voit sur chacune de tes publications.';

  @override
  String get certifyReviewTitle => 'Un examen, pas un achat';

  @override
  String get certifyReviewBody =>
      'Notre équipe lit ta chaîne avant d\'accorder le badge. Un badge qui s\'achète sans regard ne vaudrait rien — c\'est ce qui fait sa valeur.';

  @override
  String get certifyRefundTitle => 'Refusée ? Tu es remboursé';

  @override
  String get certifyRefundBody =>
      'Si le badge ne peut pas être accordé, contacte-nous : la somme t\'est rendue.';

  @override
  String get certifyRenewTitle => 'Un abonnement, pas un acquis';

  @override
  String get certifyRenewBody =>
      'Le badge dure le temps de la formule choisie. Renouveler avant l\'échéance prolonge sans rien perdre.';

  @override
  String get certifyPlanMonthly => 'Mensuel — 3 000 FCFA';

  @override
  String get certifyPlanAnnual => 'Annuel — 30 000 FCFA (deux mois offerts)';

  @override
  String get certifyAction => 'Payer et envoyer la demande';

  @override
  String get certifyPending =>
      'Ta demande part à l\'équipe dès la confirmation du paiement.';

  @override
  String get certifyFailed => 'Demande impossible — réessaie.';

  @override
  String get certifyAlready => 'Cette chaîne est certifiée';

  @override
  String get certifyTooltip => 'Faire certifier cette chaîne';

  @override
  String get chatsStartTitle => 'Commence une discussion';

  @override
  String get chatsStartBody =>
      'Tes contacts sont déjà sur Pokou. Touche un nom pour lui écrire.';

  @override
  String get chatsSeeAllContacts => 'Voir tous mes contacts';

  @override
  String get chatsNoNetworkTitle => 'Tes proches ne sont pas encore sur Pokou';

  @override
  String get chatsNoNetworkBody =>
      'Invite quelqu\'un, ou suis une chaîne en attendant qu\'on te réponde.';

  @override
  String get chatsInviteContacts => 'Inviter des contacts';

  @override
  String get chatsDiscoverChannels => 'Découvrir des chaînes';

  @override
  String get e2eeEncrypted => 'Chiffré de bout en bout';

  @override
  String get e2eeNotEncrypted => 'Non chiffré';

  @override
  String get e2eeNotEncryptedBody =>
      'Cette personne doit mettre Pokou à jour pour le chiffrement.';

  @override
  String get e2eeIdentityChangedTitle =>
      'Les informations de sécurité de ce contact ont changé';

  @override
  String e2eeIdentityChangedBody(String name) {
    return 'La clé de sécurité de $name a changé (nouveau téléphone ou réinstallation). En cas de doute, vérifie avec $name.';
  }

  @override
  String get e2eeIdentityAccept => 'J\'ai vérifié, continuer';

  @override
  String get e2eeBlockedTitle => 'Message non envoyé';

  @override
  String get e2eeBlockedLookup =>
      'Impossible de récupérer la clé de chiffrement. Le message n\'a pas été envoyé — Pokou ne l\'enverra jamais en clair à ton insu.';

  @override
  String get e2eeBlockedInvalid =>
      'La clé reçue est inexploitable. Le message n\'a pas été envoyé, par précaution.';

  @override
  String get e2eeBlockedIdentity =>
      'La clé de ce contact a changé. Vérifie son identité avant d\'envoyer.';

  @override
  String get e2eeBlockedCrypto =>
      'Le chiffrement a échoué. Le message n\'a pas été envoyé.';

  @override
  String get e2eeRetry => 'Réessayer';

  @override
  String get profileTheme => 'Apparence';

  @override
  String get themeSystem => 'Comme le téléphone';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeHint =>
      'Le mode sombre repose les yeux le soir et économise la batterie sur les écrans OLED.';

  @override
  String get a11yBack => 'Retour';

  @override
  String get a11yRefresh => 'Actualiser';

  @override
  String get a11yMoreOptions => 'Plus d\'options';

  @override
  String get a11yVoiceCall => 'Appel audio';

  @override
  String get a11yVideoCall => 'Appel vidéo';

  @override
  String get a11yAttach => 'Joindre un fichier';

  @override
  String get a11yRate => 'Noter';

  @override
  String get a11yAudioLevel => 'Niveau sonore';

  @override
  String get marketCreateAd => 'Créer une publicité';

  @override
  String get adSponsored => 'Sponsorisé';

  @override
  String get adYours => 'Ta publicité';

  @override
  String get adContact => 'Contacter';

  @override
  String get adContactFailed => 'Impossible de contacter l\'annonceur.';

  @override
  String get mediaSaveToPhone => 'Enregistrer sur le téléphone';

  @override
  String get mediaUndecryptable =>
      'Pièce jointe chiffrée illisible sur ce téléphone.';

  @override
  String get mediaSaved => 'Enregistré dans ta galerie';

  @override
  String get mediaExported => 'Choisis où l\'enregistrer';

  @override
  String get mediaSavePermission =>
      'Pokou a besoin d\'accéder à tes photos pour enregistrer ce fichier.';

  @override
  String get mediaSaveNoSpace => 'Pas assez d\'espace sur le téléphone.';

  @override
  String get mediaSaveFailed => 'Enregistrement impossible.';

  @override
  String get composerEmoji => 'Emojis';

  @override
  String get convAttachGif => 'GIF';

  @override
  String get stickerTabEmoji => 'Emoji';

  @override
  String get stickerTabStickers => 'Stickers';

  @override
  String get stickerSearchHint => 'Rechercher un sticker';

  @override
  String get stickerRecents => 'Récents';

  @override
  String get stickerFavorites => 'Favoris';

  @override
  String get stickerNoResult => 'Aucun sticker trouvé';

  @override
  String get stickerEmptyPanel => 'Aucun sticker pour l\'instant';

  @override
  String get stickerBrowsePacks => 'Parcourir les packs';

  @override
  String get stickerManagePacks => 'Gérer les packs';

  @override
  String get stickerPacksTitle => 'Packs de stickers';

  @override
  String get stickerPackAdd => 'Ajouter';

  @override
  String get stickerPackAdded => 'Ajouté';

  @override
  String get stickerPackRemove => 'Retirer';

  @override
  String get stickerPackDelete => 'Supprimer le pack';

  @override
  String get stickerPackDeleteConfirm =>
      'Supprimer ce pack et tous ses stickers ?';

  @override
  String get stickerMyPackName => 'Mes stickers';

  @override
  String get stickerCreateFromPhoto => 'Créer depuis une photo';

  @override
  String get stickerCreated => 'Sticker ajouté à tes stickers';

  @override
  String get stickerLimitReached => 'Ton pack personnel est plein';

  @override
  String get stickerSendFailed => 'Sticker non envoyé — réessaie';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get stickerFavoriteAdded => 'Ajouté aux favoris';

  @override
  String get stickerFavoriteRemoved => 'Retiré des favoris';

  @override
  String get stickerStoreEmpty => 'Aucun pack disponible pour l\'instant';

  @override
  String get stickerSaveToMine => 'Ajouter à mes stickers';

  @override
  String get stickerSaved => 'Sticker ajouté à tes stickers';

  @override
  String get navBaba => 'Baba';

  @override
  String get appBarOnline => 'En ligne';

  @override
  String get appBarOffline => 'Hors ligne';

  @override
  String get marketNegotiate => 'Négocier';

  @override
  String get callsCallBack => 'Rappeler';

  @override
  String get callsFilterMissed => 'Manqués';

  @override
  String get callsFilterAll => 'Tous';

  @override
  String get chatsFilterAll => 'Toutes';

  @override
  String get chatsFilterUnread => 'Non lues';

  @override
  String get chatsFilterGroups => 'Groupes';

  @override
  String get chatsSearchOrAsk => 'Rechercher ou demander à Baba…';

  @override
  String get convEncryptedHint => 'Message chiffré…';

  @override
  String get chatsArchivedSection => 'Discussions archivées';

  @override
  String get statusMineTitle => 'Mon Actu';

  @override
  String get statusMineBody => 'Touche pour ajouter un statut';

  @override
  String get statusMineVisibility => 'Visible par : Mes contacts';

  @override
  String get callLeaveConference => 'Quitter la conférence';

  @override
  String get callQualityExcellent => 'Excellent';

  @override
  String get callQualityGood => 'Correct';

  @override
  String get callQualityPoor => 'Faible';

  @override
  String get callYouShort => 'Toi';

  @override
  String get callMutedShort => 'Coupé';

  @override
  String get callMuteLabel => 'Micro';

  @override
  String get callCameraLabel => 'Caméra';

  @override
  String get callSpeakerLabel => 'Haut-parleur';

  @override
  String get callFlipCamera => 'Retourner la caméra';

  @override
  String get callFlipCameraFailed => 'Impossible de changer de caméra.';

  @override
  String get callNoAnswer => 'Pas de réponse.';

  @override
  String callOngoingBanner(String duration) {
    return 'Appel en cours · $duration — toucher pour revenir';
  }

  @override
  String get callOngoingBannerRinging =>
      'Appel en cours — toucher pour revenir';

  @override
  String get callHangUp => 'Raccrocher';

  @override
  String get callInviteLabel => 'Inviter';

  @override
  String get e2eeReassurance =>
      'Chiffré de bout en bout : personne d’autre, pas même Pokou, ne peut lire ces messages.';

  @override
  String get chatsEncryptionFooter =>
      'Tes discussions sont chiffrées de bout en bout.';

  @override
  String get callsRecentSection => 'RÉCENTS';

  @override
  String get callsGroupChip => 'Groupe';

  @override
  String get callGroupNotEncrypted =>
      'Appel de groupe standard — non chiffré de bout en bout';

  @override
  String get marketCatalogueSeeAll => 'Tout voir';

  @override
  String get marketCatalogueOpen => 'Ouvrir mon catalogue';

  @override
  String get marketCatalogueTotal => 'Annonces';

  @override
  String get marketCatalogueOnline => 'En ligne';

  @override
  String get marketCatalogueBoostedLabel => 'Boostées';

  @override
  String get marketCatalogueWithdrawn => 'Retirées';

  @override
  String get marketFilterAll => 'Toutes';

  @override
  String get marketCertifiedSellers => 'Vendeurs certifiés';

  @override
  String get marketCatalogueNoneInFilter => 'Aucune annonce dans ce filtre.';

  @override
  String get marketStatusModerated => 'Retirée du marché';

  @override
  String get marketStatusModeratedBody =>
      'Elle n\'est plus visible par les acheteurs. Écris au support si tu penses que c\'est une erreur.';

  @override
  String get callsFilterDirect => 'En tête-à-tête';

  @override
  String get profileMyAccount => 'Mon compte';

  @override
  String get profileVerifyAccount => 'Vérifier mon compte';

  @override
  String get profileVerifyAccountBody =>
      'Obtiens le badge vendeur vérifié d\'Assimé';

  @override
  String get profileCertificationPending => 'Certification en cours';

  @override
  String get profileCertificationPendingBody =>
      'Ta demande est en cours d\'examen.';

  @override
  String get profileCertificationActive => 'Compte certifié';

  @override
  String get profileCertificationActiveBody =>
      'Le badge de certification apparaît à côté de votre nom.';

  @override
  String get profileSellerCertified => 'Vendeur vérifié';

  @override
  String profileSellerCertifiedUntil(String date) {
    return 'Badge vendeur actif jusqu\'au $date.';
  }

  @override
  String get verifPlanLabel => 'Choisis ta formule';

  @override
  String get callEventAudio => 'Appel audio';

  @override
  String get callEventVideo => 'Appel vidéo';

  @override
  String get callEventGroup => 'Appel de groupe';

  @override
  String get callEventMissed => 'Appel manqué';

  @override
  String get callEventNoAnswer => 'Sans réponse';

  @override
  String get callEventDeclined => 'Refusé';

  @override
  String get callEventYouDeclined => 'Tu as refusé';

  @override
  String get callEventEnded => 'Terminé';

  @override
  String callEventSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count s',
      one: '1 s',
    );
    return '$_temp0';
  }

  @override
  String callEventMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String callEventHours(Object hours, Object minutes) {
    return '$hours h $minutes';
  }

  @override
  String callEventParticipants(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String get mediaCall => 'Appel';

  @override
  String get mediaSticker => 'Sticker';

  @override
  String get identityVerifiedAccount => 'Compte certifié';

  @override
  String get privacyTitle => 'Confidentialité';

  @override
  String get privacyIntro =>
      'Ces réglages sont appliqués par le serveur : ce que tu masques n\'est pas envoyé aux autres, pas seulement caché dans l\'application.';

  @override
  String get privacySectionWhoSees => 'Qui peut voir mes informations';

  @override
  String get privacySectionMessages => 'Messages';

  @override
  String get privacySectionGroups => 'Groupes';

  @override
  String get privacyLastSeen => 'Dernière activité';

  @override
  String get privacyLastSeenBody =>
      'À quelle heure tu étais connecté pour la dernière fois.';

  @override
  String get privacyOnline => 'Présence en ligne';

  @override
  String get privacyOnlineBody =>
      'Le point vert qui dit que tu es joignable maintenant. Indépendant de la dernière activité.';

  @override
  String get privacyProfilePhoto => 'Photo de profil';

  @override
  String get privacyProfilePhotoBody => 'Ta photo, partout où elle apparaît.';

  @override
  String get privacyProfileInfo => 'Informations du profil';

  @override
  String get privacyProfileInfoBody =>
      'Ta description et ce que tu as renseigné sur toi.';

  @override
  String get privacyReadReceipts => 'Confirmations de lecture';

  @override
  String get privacyReadReceiptsBody =>
      'Les désactiver te prive aussi de celles des autres. Les accusés de réception (une coche) restent visibles.';

  @override
  String get privacyGroupInvites => 'Qui peut m\'inviter dans un groupe';

  @override
  String get privacyGroupInvitesBody =>
      'Les autres t’envoient une invitation : tu gardes le dernier mot sur chacune.';

  @override
  String get privacyGroupMembership =>
      'Visibilité de mon appartenance aux groupes';

  @override
  String get privacyGroupMembershipBody =>
      'Qui peut voir dans quels groupes tu es. Les membres d\'un groupe continuent de se connaître entre eux.';

  @override
  String get privacyEveryone => 'Tout le monde';

  @override
  String get privacyMyContacts => 'Mes contacts';

  @override
  String get privacyNobody => 'Personne';

  @override
  String get privacySaveFailed => 'Réglage non enregistré — réessaie.';

  @override
  String get privacyUnavailable => 'Réglages de confidentialité indisponibles.';

  @override
  String get privacyStatusesNote =>
      'La confidentialité des statuts se règle depuis l\'onglet Statuts, où tu peux aussi exclure des personnes précises.';

  @override
  String groupInvitesSent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations envoyées',
      one: 'Invitation envoyée',
      zero: 'Aucune invitation envoyée',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationTitle => 'Invitation à un groupe';

  @override
  String groupInvitationFrom(Object name) {
    return '$name t\'invite';
  }

  @override
  String groupInvitationMembers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationAccept => 'Rejoindre';

  @override
  String get groupInvitationReject => 'Refuser';

  @override
  String groupInvitationExpires(Object hours) {
    return 'Expire dans $hours h';
  }

  @override
  String get groupInvitationExpiresSoon => 'Expire bientôt';

  @override
  String groupInvitationsHeader(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations',
      one: '1 invitation',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationFailed =>
      'Action impossible — l\'invitation n\'est peut-être plus valable.';

  @override
  String get mediaStatePreparing => 'Préparation…';

  @override
  String get mediaStateSending => 'Envoi…';

  @override
  String mediaStateSendingPercent(Object percent) {
    return 'Envoi · $percent %';
  }

  @override
  String get mediaStateWaitingNetwork => 'En attente de connexion';

  @override
  String get mediaStateFailed => 'Envoi impossible';

  @override
  String get mediaStateFileGone => 'Fichier introuvable sur cet appareil';

  @override
  String get channelPrivateLabel => 'Chaîne privée';

  @override
  String get channelPrivateBody =>
      'Introuvable par la recherche. Seules les personnes à qui tu donnes le lien peuvent la rejoindre et lire ses publications. Ce choix ne pourra pas être modifié ensuite.';

  @override
  String get channelPrivateBadge => 'Privée';

  @override
  String get mahizuConnectTitle => 'Connecte ton compte Mahizu';

  @override
  String mahizuConnectBody(String phone) {
    return 'L\'assistant est un service Mahizu, distinct de Pokou. Pour l\'utiliser, rattache ton compte Mahizu : un code sera envoyé au $phone.';
  }

  @override
  String get mahizuSendCode => 'Recevoir le code';

  @override
  String get mahizuCodeLabel => 'Code reçu';

  @override
  String get mahizuPinLabel => 'Code de ton compte Mahizu';

  @override
  String get mahizuConfirm => 'Connecter';

  @override
  String get mahizuRestart => 'Recommencer';

  @override
  String get navHome => 'Accueil';

  @override
  String get navKory => 'Kory';

  @override
  String get navMore => 'Plus';

  @override
  String homeGreeting(String name) {
    return 'Bonjour $name';
  }

  @override
  String get homeSeeAll => 'Tout voir';

  @override
  String get homeNoChats => 'Aucune discussion pour l\'instant';

  @override
  String get homeKoryEmpty => 'Aucune cagnotte en cours';

  @override
  String get homeSearchHint => 'Rechercher une discussion';

  @override
  String get moreCertifiedTitle => 'Pokou certifié';

  @override
  String get moreCertifiedBody =>
      'Identité vérifiée et mode preuve : bientôt disponible.';

  @override
  String get moreSectionServices => 'Services';

  @override
  String get moreSectionSettings => 'Réglages';

  @override
  String get moreAccount => 'Compte et sécurité';

  @override
  String get moreEdit => 'Modifier';

  @override
  String get koryTitle => 'Kory';

  @override
  String get korySubtitle => 'Cagnottes & tontines';

  @override
  String get koryMyPots => 'Mes cagnottes';

  @override
  String get koryMonthTotal => 'Mes contributions confirmées ce mois-ci';

  @override
  String get koryNoMoney =>
      'Pokou ne touche pas l\'argent : il va directement de ton wallet à celui du collecteur.';

  @override
  String get koryCreate => 'Créer une cagnotte';

  @override
  String get koryJoin => 'Rejoindre';

  @override
  String get koryJournalTab => 'Journal';

  @override
  String get koryJoinTitle => 'Rejoindre avec un code';

  @override
  String get koryJoinHint => 'Code de la cagnotte';

  @override
  String get koryJoinUnknown => 'Code inconnu ou cagnotte clôturée.';

  @override
  String get koryNone => 'Aucune cagnotte en cours';

  @override
  String get koryNoneBody =>
      'Crée une cagnotte pour un mariage, un baptême ou une cotisation, ou rejoins-en une avec son code.';

  @override
  String get koryUnavailable => 'Kory est indisponible';

  @override
  String get koryKindCagnotte => 'Cagnotte';

  @override
  String get koryKindCotisation => 'Cotisation';

  @override
  String get koryTotalConfirmed => 'Total confirmé';

  @override
  String koryGoal(String amount) {
    return 'Objectif : $amount';
  }

  @override
  String koryDue(String date) {
    return 'Échéance : $date';
  }

  @override
  String koryMyShare(String amount) {
    return 'Ma part confirmée : $amount';
  }

  @override
  String koryToReview(String count) {
    return 'À confirmer : $count';
  }

  @override
  String get koryClosed => 'Clôturée';

  @override
  String get koryOpen => 'Ouverte';

  @override
  String koryCollector(String name) {
    return 'Collecteur : $name';
  }

  @override
  String koryPayTo(String phone) {
    return 'Envoie ta contribution depuis ton wallet au $phone, puis déclare-la ici.';
  }

  @override
  String koryPerMember(String amount, String period) {
    return '$amount par membre, $period';
  }

  @override
  String get koryDeclare => 'J\'ai contribué';

  @override
  String get koryDeclareTitle => 'Déclarer ma contribution';

  @override
  String get koryAmount => 'Montant (FCFA)';

  @override
  String get koryWalletRef => 'Référence de la transaction (facultatif)';

  @override
  String get koryWalletRefHelp =>
      'Elle figure dans le SMS de ton opérateur. Seuls toi et le collecteur la voyez.';

  @override
  String get koryNote => 'Message (facultatif)';

  @override
  String get koryPeriodLabel => 'Période couverte (ex. 2026-11)';

  @override
  String get koryJournal => 'Journal des contributions';

  @override
  String get koryJournalEmpty =>
      'Aucune contribution déclarée pour l\'instant.';

  @override
  String get koryStatusDeclared => 'En attente du collecteur';

  @override
  String get koryStatusConfirmed => 'Confirmée';

  @override
  String get koryStatusRejected => 'Contestée';

  @override
  String get koryConfirm => 'Reçu';

  @override
  String get koryReject => 'Pas reçu';

  @override
  String get koryCloseAction => 'Clôturer';

  @override
  String get koryCloseConfirm =>
      'Clôturer la cagnotte ? Plus personne ne pourra déclarer de contribution.';

  @override
  String koryShareCode(String code) {
    return 'Code : $code';
  }

  @override
  String koryShareText(String title, String code) {
    return 'Rejoins la cagnotte « $title » sur Pokou avec le code $code.';
  }

  @override
  String get koryCreateTitle => 'Nouvelle collecte';

  @override
  String get koryFieldTitle => 'Titre';

  @override
  String get koryFieldDescription => 'Description (facultatif)';

  @override
  String get koryFieldGoal => 'Objectif en FCFA (facultatif)';

  @override
  String get koryFieldPerMember => 'Montant par membre (FCFA)';

  @override
  String get koryPeriodMonthly => 'chaque mois';

  @override
  String get koryPeriodWeekly => 'chaque semaine';

  @override
  String get koryFieldDue => 'Échéance (facultatif)';

  @override
  String get koryNeedTitle => 'Donne un titre (3 caractères au moins).';

  @override
  String get koryNeedAmount => 'Indique un montant d\'au moins 100 FCFA.';

  @override
  String get koryCollectorIsYou =>
      'Tu es le collecteur : les contributions arrivent sur ton wallet, et c\'est toi qui les confirmes.';

  @override
  String get koryYou => 'Toi';

  @override
  String get koryTontinePlus => 'Tontine en rotation : bientôt avec Kory Plus';

  @override
  String get koryDeclared =>
      'Contribution déclarée. Le collecteur va la confirmer.';

  @override
  String get koryCopyPhone => 'Copier le numéro';

  @override
  String get koryCopied => 'Copié';

  @override
  String get koryActionFailed => 'L\'opération n\'a pas abouti. Réessaie.';

  @override
  String get welcomePromise => 'Plus qu\'une messagerie, une communauté.';

  @override
  String get welcomeSignature => 'Ensemble, plus forts.';

  @override
  String get welcomeServiceChats => 'Discussions, groupes et appels';

  @override
  String get welcomeServiceKory => 'Cagnottes & tontines';

  @override
  String get legalPrivacy => 'Confidentialité';

  @override
  String get legalTerms => 'Conditions d\'utilisation';

  @override
  String get legalUnavailable => 'Document indisponible pour l\'instant.';

  @override
  String onbStep(String step) {
    return 'Étape $step sur 3';
  }

  @override
  String get onbProfileTitle => 'Ton profil';

  @override
  String get onbProfileBody => 'C\'est le nom que verront tes contacts.';

  @override
  String get onbDisplayName => 'Nom affiché';

  @override
  String get onbNameRequired => 'Indique un nom (2 caractères au moins).';

  @override
  String get onbPhotoLater =>
      'Tu pourras ajouter une photo plus tard, depuis ton profil.';

  @override
  String get onbContinue => 'Continuer';

  @override
  String get onbTermsTitle => 'Avant de commencer';

  @override
  String get onbAcceptTerms =>
      'J\'ai lu et j\'accepte les conditions d\'utilisation et la politique de confidentialité.';

  @override
  String get onbAge => 'J\'ai l\'âge requis pour utiliser Pokou.';

  @override
  String get onbOptional =>
      'Facultatif, modifiable à tout moment dans les réglages';

  @override
  String get onbAnalytics =>
      'Partager des statistiques d\'usage pour améliorer Pokou';

  @override
  String get onbMarketing => 'Recevoir les nouvelles et offres de Pokou';

  @override
  String get onbFinish => 'Terminer';

  @override
  String get onbFailed => 'L\'enregistrement n\'a pas abouti. Réessaie.';

  @override
  String get moreConsents => 'Statistiques et communications';

  @override
  String get navHonam => 'Honam';

  @override
  String get honamSubtitle => 'Pharmacies & livraison';

  @override
  String get honamIntro =>
      'Une pharmacie proche t\'envoie un devis. Tu la paies depuis ton wallet, puis un coursier te la livre.';

  @override
  String get honamSend => 'Envoyer une ordonnance';

  @override
  String get honamPhotograph => 'Photographier l\'ordonnance';

  @override
  String get honamFromGallery => 'Choisir une photo';

  @override
  String get honamUrgent => 'Urgence';

  @override
  String get honamNotEmergency => 'Pokou n\'est pas un service d\'urgence.';

  @override
  String get honamNearby => 'Pharmacies proches';

  @override
  String get honamOnDuty => 'De garde';

  @override
  String get honamNoPharmacy => 'Aucune pharmacie partenaire pour l\'instant.';

  @override
  String get honamCurrentOrder => 'Commande en cours';

  @override
  String get honamMyOrders => 'Mes commandes';

  @override
  String get honamChoosePharmacy => 'Choisir la pharmacie';

  @override
  String get honamAddress => 'Adresse de livraison';

  @override
  String get honamNote => 'Note pour le pharmacien (facultatif)';

  @override
  String get honamSubmit => 'Envoyer à la pharmacie';

  @override
  String get honamNeedPhoto => 'Ajoute la photo de l\'ordonnance.';

  @override
  String get honamNeedAddress => 'Indique l\'adresse de livraison.';

  @override
  String get honamFailed => 'L\'opération n\'a pas abouti. Réessaie.';

  @override
  String honamOrderTitle(String id) {
    return 'Commande n° $id';
  }

  @override
  String get honamStSubmitted => 'Envoyée, en attente du pharmacien';

  @override
  String get honamStQuoted => 'Devis reçu';

  @override
  String get honamStAccepted => 'Devis accepté, à payer';

  @override
  String get honamStPaid => 'Payée, en préparation';

  @override
  String get honamStReady => 'Prête, coursier attendu';

  @override
  String get honamStInDelivery => 'En livraison';

  @override
  String get honamStDelivered => 'Livrée';

  @override
  String get honamStRejected => 'Ordonnance refusée';

  @override
  String get honamStExpired => 'Devis expiré';

  @override
  String get honamStCancelled => 'Annulée';

  @override
  String get honamQuote => 'Devis';

  @override
  String get honamUnavailableItem => 'Indisponible';

  @override
  String get honamMedicines => 'Médicaments';

  @override
  String get honamDelivery => 'Livraison';

  @override
  String get honamTotal => 'Total à payer';

  @override
  String get honamAcceptQuote => 'Accepter le devis';

  @override
  String honamPayTo(String amount, String phone) {
    return 'Envoie $amount depuis ton wallet au $phone (la pharmacie), puis confirme.';
  }

  @override
  String get honamDeclarePaid => 'J\'ai payé la pharmacie';

  @override
  String get honamPaidDeclared =>
      'Paiement signalé : la pharmacie va le confirmer.';

  @override
  String get honamPaymentNotReceived =>
      'La pharmacie n\'a pas reçu ton paiement. Vérifie le numéro et le montant.';

  @override
  String get honamCode => 'Ton code de remise';

  @override
  String get honamCodeHelp =>
      'Donne ce code au coursier, seulement quand tu as le colis en main.';

  @override
  String get honamOriginal => 'Le coursier récupérera l\'ordonnance originale.';

  @override
  String honamRefundDue(String amount, String reason) {
    return 'La pharmacie te doit $amount : $reason';
  }

  @override
  String get honamRefundReceived => 'J\'ai reçu le remboursement';

  @override
  String get honamCancel => 'Annuler la commande';

  @override
  String get honamResend => 'Envoyer à une autre pharmacie';

  @override
  String honamReason(String reason) {
    return 'Motif : $reason';
  }

  @override
  String get honamTimeline => 'Suivi';

  @override
  String get honamOrderMessages => 'Messages de la commande';

  @override
  String get honamWriteMessage => 'Écrire un message';

  @override
  String get honamCourierMode => 'Mode coursier';

  @override
  String get honamCourierJoin => 'Devenir coursier Win Pokou';

  @override
  String get honamCourierJoinBody =>
      '5 courses d\'essai sans commission pendant un mois. Ensuite : adhésion Win Pokou et pack de courses payé d\'avance.';

  @override
  String honamRidesLeft(String count) {
    return 'Courses restantes : $count';
  }

  @override
  String get honamUnlimited => 'Courses illimitées';

  @override
  String honamMembership(String amount) {
    return 'Adhésion Win Pokou : $amount HT / mois';
  }

  @override
  String get honamPayMembership => 'Payer l\'adhésion';

  @override
  String get honamPacks => 'Packs de courses';

  @override
  String honamPackPrice(String amount) {
    return '$amount HT';
  }

  @override
  String get honamAvailableRides => 'Courses disponibles';

  @override
  String get honamMyRides => 'Mes courses';

  @override
  String get honamNoRides => 'Aucune course pour l\'instant.';

  @override
  String get honamAcceptRide => 'Accepter la course';

  @override
  String get honamPickup => 'Colis récupéré';

  @override
  String get honamDeliver => 'Valider la remise';

  @override
  String get honamEnterCode => 'Code donné par le patient';

  @override
  String get honamCoursePaid => 'J\'ai reçu le prix de la course';

  @override
  String get honamPaymentLinkOpened =>
      'Termine le paiement dans la page qui s\'ouvre.';

  @override
  String get honamCourierSuspended =>
      'Compte coursier suspendu après 3 défauts de livraison. Contacte le support pour un recours.';

  @override
  String get honamPriceNote => 'Prix hors taxes, TVA du pays en sus.';

  @override
  String get certTitle => 'Pokou certifié';

  @override
  String get certPitch => 'Nom vérifié et mode preuve · essai d’un mois';

  @override
  String get certHowItWorks =>
      'Ton identité est vérifiée par le nom du titulaire du wallet qui paie.';

  @override
  String certStartTrial(String days) {
    return 'Essayer $days jours';
  }

  @override
  String get certTrialNote =>
      'Pendant l\'essai, le mode preuve est disponible ; le badge s\'affiche au premier paiement.';

  @override
  String certPlanPrice(String ht, String ttc) {
    return '$ht HT · $ttc TTC';
  }

  @override
  String get certSubscribe => 'Choisir';

  @override
  String get certActive => 'Badge actif';

  @override
  String certTrialUntil(String date) {
    return 'Essai jusqu\'au $date';
  }

  @override
  String certActiveUntil(String date) {
    return 'Actif jusqu\'au $date';
  }

  @override
  String get certExpired => 'Abonnement expiré';

  @override
  String get certMismatchTitle => 'Les noms ne correspondent pas';

  @override
  String get certMismatchBody =>
      'Le nom saisi ne correspond pas à celui du titulaire du wallet qui a payé. Corrige-le tel qu\'il figure sur sa pièce d\'identité.';

  @override
  String get proofModeTitle => 'Mode preuve';

  @override
  String get proofModeOnBanner =>
      'Mode preuve actif : un message supprimé reste visible, barré, pour tous.';

  @override
  String get proofModeEnable => 'Activer le mode preuve';

  @override
  String get proofModeDisable => 'Désactiver le mode preuve';

  @override
  String get proofModeNeedsCert =>
      'Le mode preuve demande Pokou certifié (essai gratuit disponible).';

  @override
  String get deleteForAll => 'Supprimer pour tous';

  @override
  String get deleteProofWarning =>
      'Le mode preuve est actif. Ton message restera visible, barré, pour tous les participants, avec l’heure de la suppression.';

  @override
  String get deletedKept => 'Message supprimé, conservé par le mode preuve';

  @override
  String get certCorrectName => 'Nom complet du titulaire';

  @override
  String get certRetryName => 'Vérifier ce nom';

  @override
  String get certStillMismatch => 'Ce nom ne correspond toujours pas.';

  @override
  String get proofExport => 'Exporter la discussion en PDF';

  @override
  String proofModeOn(String name) {
    return '$name a activé le mode preuve';
  }

  @override
  String proofModeOff(String name) {
    return '$name a désactivé le mode preuve';
  }

  @override
  String proofOriginal(String text) {
    return 'Version d\'origine : $text';
  }

  @override
  String get proofDisableReserved =>
      'Seule la personne qui l\'a activé, ou un administrateur au badge payant, peut le désactiver.';

  @override
  String get marketBoost3 => '3 jours · 600 FCFA';

  @override
  String get marketBoost7 => '7 jours · 1 300 FCFA';

  @override
  String get marketUseHonam =>
      'Les médicaments ne se vendent pas sur Assimé : passe par Honam.';

  @override
  String get honamMissingTitle => 'Un produit manque';

  @override
  String honamMissingBody(String amount, String reason) {
    return '$amount manquent : $reason. Que préfères-tu ?';
  }

  @override
  String get honamKeepRest => 'Recevoir le reste';

  @override
  String get honamCancelAll => 'Tout annuler';

  @override
  String get honamRefundDelay =>
      'La pharmacie te rembourse sous 2 h, sur le numéro qui a payé.';

  @override
  String get honamZones => 'Zones et créneaux (ex. Bè, Tokoin — soirs)';

  @override
  String get honamWallet => 'Numéro du wallet qui reçoit le prix des courses';

  @override
  String get honamRules =>
      'J\'accepte les règles d\'or : je remets le colis seulement contre le code, je ne regarde pas les ordonnances, je reste courtois.';

  @override
  String get honamApply => 'Envoyer ma candidature';

  @override
  String get honamPending =>
      'Candidature envoyée : l\'équipe Pokou la vérifie.';

  @override
  String get honamLaunch =>
      'Période de lancement : tu livres sans adhésion ni pack.';

  @override
  String get honamQueenLocked =>
      'Queen Pokou se débloque après un mois sans défaut de livraison.';

  @override
  String koryDeclaredTotal(String amount) {
    return 'Total déclaré : $amount';
  }

  @override
  String koryRemaining(String amount) {
    return 'Reste à collecter : $amount';
  }

  @override
  String get onbBabaWelcome =>
      'Je suis Baba, l\'assistant de Pokou. Comment veux-tu qu\'on t\'appelle ?';

  @override
  String get onbContactsTitle => 'Retrouver tes proches';

  @override
  String get onbContactsBody =>
      'Baba peut retrouver ceux de tes contacts qui sont déjà sur Pokou. Tu peux refuser : on te le redemandera plus tard.';

  @override
  String get onbContactsAllow => 'Autoriser';

  @override
  String get onbLater => 'Plus tard';

  @override
  String get proofModeDirectHint =>
      'Tout ce qui s\'écrit reste prouvable : un message supprimé reste barré, une modification garde l\'original. Seule toi pourras le couper.';

  @override
  String get proofDisableReservedDirect =>
      'Seule la personne qui a activé le mode preuve peut le désactiver.';

  @override
  String get proofExportMe => 'Moi';

  @override
  String get proofExportTitle => 'Pokou — export du mode preuve';

  @override
  String proofExportBetween(String me, String contact) {
    return 'Discussion entre $me et $contact';
  }

  @override
  String proofExportPeriod(String since, String now) {
    return 'Mode preuve actif depuis le $since · exporté le $now depuis ce téléphone';
  }

  @override
  String proofExportFooter(String page, String pages) {
    return 'Page $page sur $pages — produit sur l\'appareil : le serveur Pokou n\'a pas accès aux messages chiffrés.';
  }

  @override
  String get proofExportAttachment => '[pièce jointe]';

  @override
  String proofExportEdited(String at) {
    return 'Modifié le $at';
  }

  @override
  String proofExportDeleted(String at) {
    return 'Supprimé le $at, conservé par le mode preuve';
  }

  @override
  String get proTitle => 'Pokou certifié Pro';

  @override
  String get proTeaser => 'Pour une activité : nom commercial et « Géré par »';

  @override
  String get proPitch =>
      'Ton nom commercial s\'affiche en premier, avec « Géré par » et ton nom vérifié. Le profil Pro accueillera tes annonces Assimé.';

  @override
  String proSteps(String hours) {
    return '1. Tu envoies ton justificatif. 2. Le support le vérifie sous $hours h. 3. Tu ne paies qu\'après la validation.';
  }

  @override
  String proPending(String due) {
    return 'Vérification en cours. Réponse au plus tard le $due.';
  }

  @override
  String get proApproved =>
      'Justificatif validé : tu peux activer Pokou certifié Pro.';

  @override
  String get proPay => 'Payer Pokou certifié Pro';

  @override
  String get proCorrection => 'Justificatif à corriger';

  @override
  String get proRejected => 'Dossier refusé';

  @override
  String get proActivity => 'Ton activité';

  @override
  String get proBusinessName => 'Nom commercial';

  @override
  String get proActivityField => 'Activité (couture, boutique, transport…)';

  @override
  String get proDocument => 'Ajouter le justificatif';

  @override
  String get proDocumentChosen => 'Justificatif ajouté — toucher pour changer';

  @override
  String get proDocumentNote =>
      'Registre de commerce, carte professionnelle ou patente. Vu par le support seulement, jamais affiché.';

  @override
  String get proSend => 'Envoyer pour vérification';

  @override
  String proManagedBy(String name) {
    return 'Géré par $name';
  }

  @override
  String get proProfileNote =>
      'C\'est ainsi que les autres voient ton profil Pro.';

  @override
  String get honamCity => 'Ville';

  @override
  String get honamOtherCity => 'Une autre ville';

  @override
  String get honamYourCity => 'Ta ville';

  @override
  String get honamNotServed =>
      'Honam ne livre pas encore dans cette ville. Inscris-toi : on te prévient à l\'ouverture.';

  @override
  String get honamJoinWaitlist => 'M\'inscrire sur la liste d\'attente';

  @override
  String honamWaitlistDone(String city) {
    return 'Inscrit·e pour $city';
  }

  @override
  String get honamWaitlistBody =>
      'On te prévient dès que Honam livre dans ta ville. Rien d\'autre.';

  @override
  String get honamReferralCodeField => 'Code de parrainage (facultatif)';

  @override
  String get honamReferralTitle => 'Invite un coursier';

  @override
  String honamReferralBody(String rides) {
    return '$rides courses offertes à la première livraison de ton filleul.';
  }

  @override
  String get honamReferralShare => 'Partager mon code';

  @override
  String honamReferralMessage(String code) {
    return 'Livre pour Honam avec Pokou : utilise mon code de parrainage $code dans le mode coursier.';
  }

  @override
  String honamReferralCount(String count) {
    return 'Filleuls : $count';
  }

  @override
  String get honamTrialEnded => 'Ton essai est terminé';

  @override
  String honamRecommendedPack(String pack) {
    return 'D\'après tes courses du mois, le pack $pack te suffit.';
  }

  @override
  String get honamNavigate => 'Itinéraire dans mon appli de cartes';

  @override
  String get honamLocationShared =>
      'Ta position est partagée toutes les 15 s pendant la course, jamais après.';

  @override
  String get honamLocationDenied =>
      'Autorise la localisation pour que le patient suive sa livraison.';

  @override
  String get honamCourier => 'le coursier';

  @override
  String honamTrackingTitle(String name) {
    return '$name est en route';
  }

  @override
  String get honamTrackingWaiting => 'Position pas encore reçue.';

  @override
  String honamTrackingDistance(String km) {
    return 'À $km km de chez toi';
  }

  @override
  String honamTrackingUpdated(String minutes) {
    return 'Mise à jour il y a $minutes min';
  }

  @override
  String get honamTrackingStale => 'Position non à jour';

  @override
  String get honamTrackingShowMap => 'Afficher la carte';

  @override
  String get honamTrackingMapDataSaver =>
      'Voir sur la carte (consomme des données)';

  @override
  String get assimeFavoritesAlerts => 'Favoris et alertes';

  @override
  String get assimeFavorites => 'Favoris';

  @override
  String get assimeAlerts => 'Alertes';

  @override
  String get assimeNoFavorites => 'Aucun favori';

  @override
  String get assimeFavoritesHint =>
      'Touche le cœur d\'une annonce pour la garder ici.';

  @override
  String get assimeAddFavorite => 'Ajouter aux favoris';

  @override
  String get assimeRemoveFavorite => 'Retirer des favoris';

  @override
  String get assimeNewAlert => 'Nouvelle alerte';

  @override
  String get assimeAlertQuery => 'Ce que tu cherches';

  @override
  String get assimeAlertMaxPrice => 'Prix maximum (facultatif)';

  @override
  String get assimeAlertNote =>
      'On te prévient quand une annonce correspond. L\'alerte ne lit que les annonces, jamais tes messages.';

  @override
  String get assimeNoAlerts => 'Aucune alerte pour l\'instant.';

  @override
  String assimeAlertUpTo(String price) {
    return 'jusqu\'à $price FCFA';
  }

  @override
  String assimeAlertMatches(String count) {
    return '$count annonce(s) trouvée(s)';
  }

  @override
  String get assimeSponsored => 'Sponsorisé';

  @override
  String get assimeWhyTitle => 'Pourquoi je vois cette annonce ?';

  @override
  String get assimeWhyNotSponsored =>
      'Cette annonce n\'est plus mise en avant.';

  @override
  String get assimeReportTitle => 'Bilan de la mise en avant';

  @override
  String get assimeReportEmpty =>
      'Pas encore de mise en avant pour cette annonce.';

  @override
  String assimeReportPeriod(String days, String start, String end) {
    return '$days jours · du $start au $end';
  }

  @override
  String assimeReportImpressions(String count) {
    return 'Vue en tête des résultats : $count fois';
  }

  @override
  String assimeReportStatusViews(String count) {
    return 'Vue dans les statuts : $count fois';
  }

  @override
  String assimeReportContacts(String count) {
    return 'Personnes qui t\'ont contacté : $count';
  }

  @override
  String get assimeStatusPending =>
      'Place dans les statuts : en relecture par la modération';

  @override
  String get assimeStatusRejected =>
      'Place dans les statuts refusée par la modération';

  @override
  String get koryKindTontine => 'Tontine';

  @override
  String get koryFieldStake => 'Mise de chacun par tour (FCFA)';

  @override
  String get koryRotation => 'Ordre des tours';

  @override
  String get koryRotationHint =>
      'Glisse pour ordonner. L\'ordre est fixé à l\'ouverture et ne change plus.';

  @override
  String get koryRemoveFromRotation => 'Retirer de la tontine';

  @override
  String get koryNeedRotation =>
      'Une tontine demande au moins deux participants.';

  @override
  String get koryTontineNote =>
      'Chaque tour, chacun envoie sa mise au wallet du bénéficiaire, qui confirme ce qu\'il a reçu. Pokou ne touche jamais l\'argent.';

  @override
  String get koryRounds => 'Les tours';

  @override
  String koryRoundNumber(String number) {
    return 'Tour $number';
  }

  @override
  String koryRoundConfirmed(String confirmed, String expected) {
    return '$confirmed confirmés sur $expected';
  }

  @override
  String get koryNextRound => 'Passer au tour suivant';

  @override
  String get koryNextRoundBody =>
      'Le tour en cours se termine. Les contributions déjà déclarées restent à confirmer par son bénéficiaire.';

  @override
  String get koryLastRoundBody =>
      'C\'était le dernier tour : la tontine sera clôturée. Le journal reste consultable.';

  @override
  String get welcomeStart => 'Commencer';

  @override
  String get authAcceptAndContinue => 'Accepter et continuer';

  @override
  String get authAcceptNotice =>
      'En touchant « Accepter et continuer », tu acceptes les conditions d\'utilisation et la politique de confidentialité, et tu déclares avoir l\'âge requis.';

  @override
  String get deleteAccountTitle => 'Supprimer mon compte';

  @override
  String get deleteAccountWarning => 'Cette action est définitive.';

  @override
  String get deleteAccountRemovedTitle => 'Ce qui est supprimé';

  @override
  String get deleteAccountRemovedProfile =>
      'Ton profil, ta photo et ta sauvegarde';

  @override
  String get deleteAccountRemovedChats => 'Tes discussions sur ce téléphone';

  @override
  String get deleteAccountRemovedBadge =>
      'Ton badge, sans remboursement du mois en cours';

  @override
  String get deleteAccountKeptTitle => 'Ce qui reste';

  @override
  String get deleteAccountKeptMessages =>
      'Les messages déjà reçus par tes contacts';

  @override
  String get deleteAccountKeptProof =>
      'Les traces du mode preuve chez les autres participants';

  @override
  String get deleteAccountKeptKory =>
      'Le journal des cagnottes Kory, qui ne s’efface pas';

  @override
  String get deleteAccountConfirmLabel => 'Confirme ton numéro';

  @override
  String get deleteAccountMismatch =>
      'Ce numéro ne correspond pas à ton compte.';

  @override
  String get deleteAccountFailed => 'La suppression a échoué. Réessaie.';

  @override
  String get helpTitle => 'Aide et support';

  @override
  String get helpSearchHint => 'Rechercher dans l’aide';

  @override
  String get helpAskBaba => 'Demander à Baba';

  @override
  String get helpAskBabaSub => 'L’assistant IA répond tout de suite';

  @override
  String get helpFaqTitle => 'Questions fréquentes';

  @override
  String get helpQMoney => 'Pokou touche-t-il mon argent ?';

  @override
  String get helpAMoney =>
      'Non. Cagnottes, pharmacies et coursiers se paient de wallet à wallet. Pokou ne garde jamais ton argent.';

  @override
  String get helpQProof => 'Comment marche le mode preuve ?';

  @override
  String get helpAProof =>
      'Activé par un titulaire de Pokou certifié, il garde visibles, barrés, les messages supprimés ou modifiés. C’est toujours affiché en tête de la discussion.';

  @override
  String get helpQSms => 'Je ne reçois pas le code SMS';

  @override
  String get helpASms =>
      'Vérifie le numéro et le réseau, puis attends la fin du compte à rebours pour redemander un code. Pokou ne te demandera jamais ce code, ni par message ni par appel.';

  @override
  String get helpQCourier => 'Comment devenir coursier Honam ?';

  @override
  String get helpACourier =>
      'Dans Plus, touche « Devenir coursier Honam » : identité, zones, wallet et règles d’or. Honam ouvre ville par ville.';

  @override
  String get helpQScam => 'Comment repérer une arnaque ?';

  @override
  String get helpAScam =>
      'Méfie-toi de qui demande un code reçu par SMS, ton code PIN ou un paiement urgent. Pokou ne le fait jamais. Bloque et signale le contact.';

  @override
  String get helpSupport => 'Écrire au support';

  @override
  String get helpSupportSub => 'Réponse dans l’application';

  @override
  String get helpReport => 'Signaler un problème';

  @override
  String get helpNoResult => 'Aucune question ne correspond. Demande à Baba.';

  @override
  String get aboutTitle => 'À propos de Pokou';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutNamesTitle => 'Le sens de nos noms';

  @override
  String get aboutPokou => 'un nom baoulé';

  @override
  String get aboutKory => 'le cauris';

  @override
  String get aboutHonam => '« aide-moi », en éwé';

  @override
  String get aboutAssime => '« au marché », en éwé';

  @override
  String get aboutWetri => '« mois », en éwé';

  @override
  String get aboutEpe => '« année », en éwé';

  @override
  String get aboutNextNames =>
      'Nos prochains services porteront eux aussi des noms venus de langues africaines.';

  @override
  String get aboutLicenses => 'Licences des logiciels libres';

  @override
  String get legalEssentials => 'L’essentiel';

  @override
  String get legalFullText => 'Texte complet';

  @override
  String get termsE1 =>
      'Pokou ne touche jamais l’argent : cagnottes, pharmacies et coursiers se paient de wallet à wallet.';

  @override
  String get termsE2 =>
      'Le mode preuve garde la trace des messages supprimés, et c’est toujours affiché.';

  @override
  String get termsE3 => 'Honam n’est pas un service d’urgence.';

  @override
  String get termsE4 => 'Les badges payants se résilient à tout moment.';

  @override
  String get privacyE1 =>
      'Ton numéro n’est jamais montré à un vendeur ni à un coursier.';

  @override
  String get privacyE2 =>
      'Pokou ne lit pas tes messages. Un signalement n’envoie que les 5 derniers au support.';

  @override
  String get privacyE3 =>
      'La position du coursier n’est pas conservée après la livraison.';

  @override
  String get privacyE4 =>
      'Les annonces sponsorisées sont ciblées par ville, jamais à partir de tes messages.';

  @override
  String get languageNote =>
      'La langue de l’application ne change pas celle de tes messages. Les noms Pokou, Kory, Honam et Assimé restent les mêmes dans toutes les langues.';

  @override
  String get securityPinWarning =>
      'Pokou ne te demandera jamais ton code PIN ni le code reçu par SMS, ni par message ni par appel.';

  @override
  String get statusReplyPrivate =>
      'Ta réponse arrive en privé, dans votre discussion à deux.';

  @override
  String get statusViewersNote =>
      'Toi seul vois cette liste. Les réponses arrivent en privé, dans vos discussions.';

  @override
  String get statusWhoSees => 'Qui voit mes statuts';

  @override
  String get attachCompressNote =>
      'Photos et vidéos sont compressées avant l’envoi pour économiser tes données.';

  @override
  String get otpTitle => 'Saisis le code';

  @override
  String get pinForgot => 'Code PIN oublié ?';

  @override
  String get pinTitle => 'Ton code PIN';

  @override
  String statusReplyHint(String name) {
    return 'Répondre à $name…';
  }

  @override
  String get statusReplyQuote => '↩ En réponse à ton statut';

  @override
  String get statusReplySent => 'Réponse envoyée en privé.';

  @override
  String get changeNumberTitle => 'Changer de numéro';

  @override
  String get changeNumberOld => 'Ancien numéro';

  @override
  String get changeNumberNew => 'Nouveau numéro';

  @override
  String get changeNumberNotify => 'Prévenir mes contacts';

  @override
  String get changeNumberNotifyAll => 'Tous mes contacts';

  @override
  String get changeNumberNotifyChatted => 'Ceux avec qui j’ai discuté';

  @override
  String get changeNumberNotifyNone => 'Personne';

  @override
  String get changeNumberNotifyNoneSub => 'Tes groupes sont toujours prévenus';

  @override
  String get changeNumberInfo =>
      'Ton compte, tes discussions, ton badge Pokou certifié et tes cagnottes Kory te suivent. Un code est envoyé au nouveau numéro.';

  @override
  String get changeNumberKoryWarning =>
      'Si tu es collecteur d’une cagnotte, ton numéro de collecte ne change pas tout seul : modifie-le dans Kory, les membres en seront prévenus.';

  @override
  String get changeNumberSendCode => 'Envoyer le code';

  @override
  String get changeNumberCodeLabel => 'Code reçu par SMS';

  @override
  String get changeNumberConfirm => 'Confirmer le changement';

  @override
  String get changeNumberDone => 'Ton numéro est changé.';

  @override
  String get pinForgotIntro => 'Deux façons de retrouver ton compte :';

  @override
  String get pinForgotEmail => 'Par e-mail';

  @override
  String get pinForgotEmailSub =>
      'Si tu as ajouté une adresse : un lien de réinitialisation t’est envoyé';

  @override
  String get pinForgotWait => 'Attendre 7 jours';

  @override
  String get pinForgotWaitSub =>
      'Ensuite, tu te connectes sans code PIN avec le code SMS, à condition de garder ton numéro';

  @override
  String get pinForgotWarning =>
      'Le délai de 7 jours empêche quelqu’un qui aurait volé ta carte SIM de prendre ton compte tout de suite.';

  @override
  String get pinForgotMeanwhile =>
      'Pendant l’attente, tes contacts continuent de te voir et tes messages t’attendent.';

  @override
  String get pinForgotContinue => 'Continuer';

  @override
  String pinForgotScheduled(String date) {
    return 'C’est noté. À partir du $date, le code SMS suffira pour te connecter.';
  }

  @override
  String get groupDelete => 'Supprimer le groupe';

  @override
  String groupDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get groupDeleteBody =>
      'Le groupe disparaît pour tous ses membres, avec ses messages. Cette action est définitive.';

  @override
  String get groupDeleteFailed => 'Suppression impossible — réessaie.';

  @override
  String get groupManageTitle => 'Gérer le groupe';

  @override
  String get groupManageSubtitle =>
      'Autorisations, nouveaux membres, messages éphémères';

  @override
  String get groupPermissions => 'Autorisations';

  @override
  String get groupEditInfoSetting => 'Modifier le nom et la photo';

  @override
  String get groupSendSetting => 'Envoyer des messages';

  @override
  String get groupApproveSetting => 'Approuver les nouveaux membres';

  @override
  String get groupApproveSettingSub =>
      'Un administrateur valide chaque entrée par lien';

  @override
  String get groupAllMembers => 'Tous les membres';

  @override
  String get groupDisappearing => 'Messages éphémères';

  @override
  String get groupDisappearingOff => 'Désactivés';

  @override
  String get groupDisappearing24h => '24 heures';

  @override
  String get groupDisappearing7d => '7 jours';

  @override
  String get groupDisappearing90d => '90 jours';

  @override
  String get groupJoinRequests => 'Demandes d’entrée';

  @override
  String get groupNoJoinRequest => 'Aucune demande en attente.';

  @override
  String get groupApprove => 'Accepter';

  @override
  String get groupReject => 'Refuser';

  @override
  String get groupJoinPending =>
      'Demande envoyée : un administrateur doit valider ton entrée.';

  @override
  String get groupSettingsSaveFailed => 'Réglage non enregistré — réessaie.';

  @override
  String get groupLeaveKoryNote =>
      'Quitter le groupe ne supprime pas la cagnotte en cours : tes contributions restent dans le journal Kory.';

  @override
  String get messageWaiting => 'En attente de ce message…';

  @override
  String get callWaitingNotice =>
      'Tu es déjà en appel. Refuser le garde ; accepter le termine.';

  @override
  String get callEndAndAccept => 'Terminer et accepter';

  @override
  String get homeHelloOverline => 'Bonjour';

  @override
  String get koryOverline => 'Épargne solidaire';

  @override
  String koryActiveCount(String count) {
    return '$count actives';
  }

  @override
  String get searchIntro =>
      'Cherche dans tes messages, les chaînes et les annonces d’Assimé.';

  @override
  String get searchRecent => 'Recherches récentes';

  @override
  String get homeTagline => 'Tout ce qui compte, au même endroit.';

  @override
  String get homeWhatToDo => 'Que veux-tu faire ?';

  @override
  String get homeInProgress => 'En cours';

  @override
  String get homeKoryPitch =>
      'Collecte à plusieurs pour un projet, un événement ou une tontine.';

  @override
  String get homeHonamPitch =>
      'Envoie ton ordonnance et reçois les devis des pharmacies proches.';

  @override
  String get homeAssimeTitle => 'Assimé';

  @override
  String get homeAssimeSubtitle => 'Petites annonces';

  @override
  String get homeAssimePitch =>
      'Achète et vends près de chez toi, en toute confiance.';

  @override
  String get homeAssimeCta => 'Voir les annonces';

  @override
  String get koryPledgeTitle => 'Je m’engage';

  @override
  String koryPledgeSubtitleDue(Object date, Object title) {
    return '$title · clôture le $date';
  }

  @override
  String get koryPledgeStart => 'Montant de départ';

  @override
  String get koryPledgeDailyToggle => 'Ajouter un montant journalier';

  @override
  String get koryPledgeDailyToggleSub =>
      'Ajouté chaque jour à ton engagement, jusqu’à la clôture';

  @override
  String get koryPledgePerDay => 'Montant par jour';

  @override
  String get koryPledgeStartRow => 'Départ';

  @override
  String koryPledgeDailyRow(Object amount, Object days) {
    return '$amount × $days jours';
  }

  @override
  String koryPledgeTotalAt(Object date) {
    return 'Total engagé au $date';
  }

  @override
  String get koryPledgeEditableNotice =>
      'Tu peux modifier ton engagement pendant 8 h. Ensuite il devient ferme : il s’inscrit au journal et le collecteur le voit.';

  @override
  String get koryPledgeConfirm => 'Confirmer mon engagement';

  @override
  String get koryPledgeNeedDue =>
      'Un montant journalier demande une date de fin.';

  @override
  String get koryMyPledgeTitle => 'Mon engagement';

  @override
  String koryEditableFor(Object duration) {
    return 'Modifiable encore $duration';
  }

  @override
  String koryFirmToday(Object time) {
    return 'Devient ferme aujourd’hui à $time';
  }

  @override
  String koryFirmOn(Object date, Object time) {
    return 'Devient ferme le $date à $time';
  }

  @override
  String get koryDailyRow => 'Montant journalier';

  @override
  String koryPerDay(Object amount) {
    return '$amount par jour';
  }

  @override
  String get koryPledgeEdit => 'Modifier mon engagement';

  @override
  String get koryTimelineSaved => 'Engagement enregistré';

  @override
  String get koryTimelineEditable => 'Modifiable pendant 8 h';

  @override
  String koryTimelineUntil(Object time) {
    return 'Jusqu’à $time · le collecteur ne le voit pas encore';
  }

  @override
  String get koryTimelineFirm => 'Engagement ferme';

  @override
  String get koryTimelineFirmSub => 'Inscrit au journal, visible du collecteur';

  @override
  String get koryPayNowOrLater =>
      'Tu peux verser dès maintenant, ou attendre la clôture : Pokou te rappellera ce qu’il reste à verser.';

  @override
  String get koryPayNow => 'Verser maintenant';

  @override
  String koryFirmSince(Object date) {
    return 'Ferme depuis le $date';
  }

  @override
  String get koryPaidConfirmed => 'Versé et confirmé';

  @override
  String get koryRemainingToPay => 'Reste à verser';

  @override
  String koryNextDailyAdd(Object amount) {
    return 'Prochain ajout journalier : demain, +$amount';
  }

  @override
  String get koryFirmNotice =>
      'Un engagement ferme ne se modifie plus. En cas d’imprévu, écris au collecteur : lui seul peut l’annuler, et c’est noté au journal.';

  @override
  String koryPayAmount(Object amount) {
    return 'Verser $amount';
  }

  @override
  String koryWriteTo(Object name) {
    return 'Écrire à $name';
  }

  @override
  String koryMyPledgeTotal(Object amount) {
    return 'Engagé : $amount';
  }

  @override
  String get koryContestedTitle => 'Contribution contestée';

  @override
  String koryContestedHead(Object name) {
    return '$name n’a pas constaté ton envoi';
  }

  @override
  String koryContestedDeclared(Object amount, Object time) {
    return '$amount déclarés à $time';
  }

  @override
  String koryContestedReason(Object reason) {
    return 'Motif : « $reason »';
  }

  @override
  String get koryCheckReference => 'Vérifier la référence';

  @override
  String get koryAddSmsCapture => 'Ajouter une capture du SMS';

  @override
  String get koryContestedOperatorNotice =>
      'Si tu as envoyé sur un autre numéro, seul ton opérateur peut récupérer l’argent : il ne passe jamais par Pokou.';

  @override
  String get koryResubmitted =>
      'Renvoyé au collecteur pour une nouvelle vérification.';

  @override
  String get koryRejectReasonTitle => 'Pourquoi ne l’as-tu pas reçu ?';

  @override
  String get koryRejectReasonHint =>
      'Ex. Rien reçu sur mon wallet à cette heure-là.';

  @override
  String get koryFinishTitle => 'Fin de la collecte';

  @override
  String koryFinishSubtitle(Object title) {
    return '$title · vue du collecteur';
  }

  @override
  String get koryFinishDueNotice =>
      'La date de fin est atteinte : à toi de clôturer ou de prolonger.';

  @override
  String get koryEngaged => 'Engagé';

  @override
  String koryParticipantsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String get koryConfirmedLabel => 'Confirmé';

  @override
  String koryOnGoal(Object amount) {
    return 'sur $amount';
  }

  @override
  String get koryToConfirmLabel => 'À confirmer';

  @override
  String koryDeclarationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count déclarations',
      one: '1 déclaration',
    );
    return '$_temp0';
  }

  @override
  String get koryWhatDoYouDo => 'Que fais-tu ?';

  @override
  String get koryCloseCollect => 'Clôturer la collecte';

  @override
  String get koryCloseCollectSub =>
      'Chacun reçoit ce qu’il lui reste à verser, et le lien vers son wallet';

  @override
  String get koryExtend => 'Prolonger';

  @override
  String koryExtendSub(Object date) {
    return 'Nouvelle date de fin : $date · les engagements restent fermes';
  }

  @override
  String get koryFinishJournalNote =>
      'Les participants sont prévenus par une notification. Le journal garde la date et ton choix.';

  @override
  String koryCloseAndNotify(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Clôturer et prévenir les $count participants',
      one: 'Clôturer et prévenir le participant',
    );
    return '$_temp0';
  }

  @override
  String koryExtendTo(Object date) {
    return 'Prolonger jusqu’au $date';
  }

  @override
  String get koryFinishCta => 'Clôturer ou prolonger';

  @override
  String get koryClosedTitle => 'Collecte clôturée';

  @override
  String koryClosedSubtitle(Object title) {
    return '$title · vue du participant';
  }

  @override
  String koryClosedBody(Object date, Object name) {
    return '$name a clôturé la collecte le $date. Il te reste à verser la fin de ton engagement.';
  }

  @override
  String get koryAlreadyConfirmed => 'Déjà confirmé';

  @override
  String get koryToPay => 'À verser';

  @override
  String get korySendTo => 'Envoie à';

  @override
  String koryReferenceToGive(Object reference) {
    return 'Référence à indiquer $reference';
  }

  @override
  String get koryCopyReference => 'Copier la référence';

  @override
  String koryPayFromWallet(Object amount) {
    return 'Verser $amount depuis mon wallet';
  }

  @override
  String get koryAlreadySent => 'J’ai déjà envoyé';

  @override
  String get notifCenterTitle => 'Notifications';

  @override
  String get notifReadAll => 'Tout lire';

  @override
  String get notifToday => 'Aujourd’hui';

  @override
  String get notifYesterday => 'Hier';

  @override
  String get notifEarlier => 'Plus tôt';

  @override
  String get notifMessagesElsewhere =>
      'Les messages n’apparaissent pas ici : ils restent dans Discussions.';

  @override
  String get notifEmpty => 'Aucune notification pour l’instant.';

  @override
  String get notifServiceCertified => 'Pokou certifié';

  @override
  String get notifSettings => 'Réglages des notifications';

  @override
  String get certPausedTitle => 'Badge en pause';

  @override
  String certPausedBody(Object days, Object due, Object since) {
    return 'Le paiement du $due n’a pas abouti. Ton badge est masqué depuis le $since, après $days jours de grâce.';
  }

  @override
  String get certWhatRemains => 'Ce qui reste';

  @override
  String get certRemainsChats => 'Tes discussions et tes contacts';

  @override
  String get certRemainsTraces =>
      'Les traces déjà enregistrées par le mode preuve';

  @override
  String get certWhatPaused => 'Ce qui est en pause';

  @override
  String get certPausedBadge => 'Le badge et le nom vérifié';

  @override
  String get certPausedProof =>
      'Le mode preuve des nouveaux messages et l’export daté';

  @override
  String get certPausedWallet =>
      'Le paiement se fait par ton wallet. Si ton solde était insuffisant, recharge-le puis réessaie.';

  @override
  String certPausedPay(Object amount) {
    return 'Payer $amount et réafficher mon badge';
  }

  @override
  String get certChangePlan => 'Changer de formule';

  @override
  String get annSoldTitle => 'Marquer comme vendue';

  @override
  String get annSoldWho =>
      'À qui l’as-tu vendue ? Cette personne pourra noter la transaction.';

  @override
  String annSoldDiscussionOf(Object date) {
    return 'Discussion du $date';
  }

  @override
  String get annSoldOutside => 'Quelqu’un hors de Pokou';

  @override
  String get annSoldOutsideSub => 'Pas de note possible pour cette vente';

  @override
  String get annSoldFinalPrice => 'Prix final';

  @override
  String get annSoldPriceHelp => 'Visible seulement de toi et de l’acheteur';

  @override
  String get annSoldConfirm => 'Confirmer la vente';

  @override
  String get annSoldBadge => 'Vendue';

  @override
  String get annSoldDone => 'Vente enregistrée.';

  @override
  String get annRateTitle => 'Noter la transaction';

  @override
  String get annRateHow => 'Comment s’est passée ta transaction ?';

  @override
  String get annRate1 => 'Décevant';

  @override
  String get annRate2 => 'Moyen';

  @override
  String get annRate3 => 'Correct';

  @override
  String get annRate4 => 'Très bien';

  @override
  String get annRate5 => 'Excellent';

  @override
  String annRateStars(Object count) {
    return '$count étoiles sur 5';
  }

  @override
  String get annRateWentWell => 'Ce qui s’est bien passé';

  @override
  String get annTagAsDescribed => 'Conforme à l’annonce';

  @override
  String get annTagPunctual => 'Ponctuel·le';

  @override
  String get annTagFairPrice => 'Prix respecté';

  @override
  String get annTagFriendly => 'Aimable';

  @override
  String get annTagCommunication => 'Bonne communication';

  @override
  String get annRateComment => 'Ton avis (facultatif)';

  @override
  String get annRateNotice =>
      'Ton avis s’affiche avec ton prénom et l’initiale de ton nom. Seule une vente confirmée par le vendeur peut être notée, une seule fois.';

  @override
  String get annRatePublish => 'Publier mon avis';

  @override
  String get annRatePublished => 'Merci, ton avis est publié.';

  @override
  String get annRateAlready => 'Tu as déjà noté cette vente.';

  @override
  String annRateSubtitle(Object product, Object seller) {
    return '$seller · $product';
  }

  @override
  String get backupTitle => 'Sauvegarde';

  @override
  String get backupWhere => 'Pokou, chiffrée sur ton téléphone';

  @override
  String get backupLast => 'Dernière sauvegarde';

  @override
  String get backupContent => 'Contenu';

  @override
  String backupContentValue(num count, Object size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count discussions',
      one: '1 discussion',
    );
    return '$_temp0 · $size';
  }

  @override
  String get backupNever => 'Jamais';

  @override
  String get backupExplain =>
      'Tes discussions sont chiffrées sur ce téléphone avec ton mot de passe avant d’être envoyées. Sans lui, personne ne peut les lire, pas même Pokou : garde-le précieusement.';

  @override
  String get backupSetPassword => 'Choisir un mot de passe';

  @override
  String get backupChangePassword => 'Changer le mot de passe';

  @override
  String get backupPasswordLabel => 'Mot de passe de sauvegarde';

  @override
  String get backupPasswordConfirm => 'Confirme le mot de passe';

  @override
  String get backupPasswordTooShort => '8 caractères au moins.';

  @override
  String get backupPasswordMismatch =>
      'Les deux mots de passe ne correspondent pas.';

  @override
  String get backupNow => 'Sauvegarder maintenant';

  @override
  String get backupDone => 'Sauvegarde terminée.';

  @override
  String get backupDaily =>
      'Une sauvegarde est faite chaque jour, à l’ouverture de Pokou.';

  @override
  String get backupDelete => 'Supprimer la sauvegarde';

  @override
  String get backupFailed => 'La sauvegarde n’a pas abouti. Réessaie.';

  @override
  String welcomeBackBaba(Object name) {
    return 'Bon retour, $name ! J’ai retrouvé ton compte et ta sauvegarde. Tes groupes, tes cagnottes Kory et ton badge te suivent.';
  }

  @override
  String get welcomeBackOrder =>
      'Discussions et état du mode preuve d’abord ; photos et vidéos ensuite, à l’ouverture de chaque discussion.';

  @override
  String get welcomeBackOldPhone => 'Ton ancien téléphone sera déconnecté.';

  @override
  String get welcomeBackRestore => 'Restaurer';

  @override
  String get welcomeBackSkip => 'Continuer sans restaurer';

  @override
  String get restoreWrongPassword =>
      'Ce mot de passe ne correspond pas à la sauvegarde.';

  @override
  String get restoreCardTitle => 'Restauration de tes discussions';

  @override
  String restoreCardBody(Object done, Object total) {
    return '$done discussions sur $total. Photos et vidéos ensuite, à l’ouverture.';
  }

  @override
  String get restoreDone => 'Tes discussions sont de retour.';

  @override
  String get koryParticipantsTitle => 'Participants';

  @override
  String koryStepOf(Object step, Object title, Object total) {
    return '$title · étape $step sur $total';
  }

  @override
  String get koryLastName => 'Nom';

  @override
  String get koryFirstName => 'Prénom';

  @override
  String get koryPhoneField => 'Numéro';

  @override
  String get koryAddParticipant => 'Ajouter';

  @override
  String koryAddedCount(Object count) {
    return 'Ajoutés · $count';
  }

  @override
  String get koryFromContacts => 'Depuis mes contacts';

  @override
  String get koryOnPokou => 'Sur Pokou';

  @override
  String get koryInvitedChip => 'Invité·e';

  @override
  String get koryCollectorChip => 'Collecteur';

  @override
  String koryRemoveParticipant(Object name) {
    return 'Retirer $name';
  }

  @override
  String get koryInviteNote =>
      'Sans Pokou, la personne reçoit un SMS d’invitation. Elle reste « Invitée » jusqu’à son inscription, puis s’engage comme les autres.';

  @override
  String koryContinueWith(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Continuer avec $count participants',
      one: 'Continuer avec 1 participant',
      zero: 'Continuer sans participant',
    );
    return '$_temp0';
  }

  @override
  String get koryInvalidPhone => 'Ce numéro n’est pas valide.';

  @override
  String get storageManage => 'Gérer le stockage';

  @override
  String get storageBigFiles => 'Fichiers de plus de 5 Mo';

  @override
  String get storageAutoDownload => 'Téléchargement automatique';

  @override
  String get storageOnWifi => 'En Wi-Fi';

  @override
  String get autoDownloadNone => 'Rien';

  @override
  String get autoDownloadPhotos => 'Photos';

  @override
  String get autoDownloadPhotosVideos => 'Photos et vidéos';

  @override
  String get autoDownloadAll => 'Tout';

  @override
  String get storageCallSaver => 'Économiser les données pendant les appels';

  @override
  String get storageCallSaverSub => 'Qualité réduite, appel plus stable';

  @override
  String storagePokouUses(Object size) {
    return 'Pokou · $size';
  }

  @override
  String get storageOtherDiscussion => 'Autres fichiers';

  @override
  String get callReconnecting => 'Reconnexion…';

  @override
  String get homeSearchEverything =>
      'Rechercher un contact, un service, une annonce';

  @override
  String get homeBabaTitle => 'Besoin d’un coup de main ?';

  @override
  String get homeBabaSub => 'Pose ta question à Baba, il s’occupe du reste.';

  @override
  String homeAlertsActive(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alertes actives',
      one: '1 alerte active',
    );
    return '$_temp0';
  }

  @override
  String homeSeeAllUnread(Object count) {
    return 'Tout voir ($count non lus)';
  }

  @override
  String get homeServicesSub =>
      'Des services simples, pensés pour ton quotidien.';

  @override
  String get homeKoryOverline => 'CAGNOTTES & TONTINES';

  @override
  String get homeHonamOverline => '« AIDE-MOI »';

  @override
  String get homeAssimeOverline => '« AU MARCHÉ »';

  @override
  String get homeTrustOverline => 'CONFIANCE ABSOLUE';

  @override
  String get homeTrustBody =>
      'Tes données et échanges sont chiffrés de bout en bout.';

  @override
  String get homeKoryInProgress => 'KORY • CAGNOTTE';

  @override
  String get homeHonamInProgress => 'HONAM • SANTÉ';

  @override
  String get homeKoryNoMoney => 'Pokou ne touche pas l’argent';

  @override
  String get discussionsStatusesNews => 'STATUTS & NOUVELLES';

  @override
  String get statusMyStatus => 'Mon statut';

  @override
  String get babaAssistantChip => 'ASSISTANT IA';

  @override
  String get babaTranslate => 'Traduire';

  @override
  String get babaSummarize => 'Résumer';

  @override
  String get babaAlwaysThere =>
      'Toujours là pour traduire, résumer ou répondre à tes questions.';

  @override
  String get koryHeadline => 'Kory · Le cauris';

  @override
  String get koryWalletChip => 'WALLET À WALLET';

  @override
  String get koryNeverTouches =>
      'Pokou ne touche jamais ton argent. Les contributions passent directement de wallet à wallet, sans intermédiaire.';

  @override
  String get koryMonthActivity => 'ACTIVITÉ DU MOIS';

  @override
  String get backupDestTitle => 'Où sauvegarder';

  @override
  String get backupDestDrive => 'Google Drive';

  @override
  String get backupDestDriveSub =>
      'Sur ton compte Google, dans un dossier caché que seul Pokou peut lire';

  @override
  String get backupDestPokou => 'Pokou';

  @override
  String get backupGoogleAccount => 'Compte Google';

  @override
  String get backupChangeAccount => 'Changer de compte';

  @override
  String get backupNoAccount => 'Aucun compte choisi';

  @override
  String backupWhereDrive(Object email) {
    return 'Google Drive · $email';
  }

  @override
  String get restoreFindDrive => 'Retrouver ma sauvegarde Google Drive';

  @override
  String get restoreNoDrive => 'Aucune sauvegarde Pokou sur ce compte Google.';

  @override
  String get restoreWelcomeNoBackup =>
      'Bon retour ! Si tu avais sauvegardé tes discussions sur Google Drive, retrouve-les ici.';

  @override
  String get marketPriceInvalid =>
      'Ce prix n\'est pas valide. Écris seulement le montant, par exemple 5000.';

  @override
  String get marketPublishFailed =>
      'L\'annonce n\'a pas pu être publiée. Rien n\'est perdu : vérifie ta connexion et réessaie.';

  @override
  String get statusChangeFont => 'Changer la police';

  @override
  String get statusChangeBackground => 'Changer le fond';

  @override
  String statusBackgroundNumber(String number) {
    return 'Fond $number';
  }

  @override
  String get statusVisible24h =>
      'Visible 24 h, par les contacts que tu as choisis.';

  @override
  String homeUnreadSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '1 message non lu',
    );
    return '$_temp0';
  }

  @override
  String get homeServicesTitle => 'Services';

  @override
  String get homeKoryShort => 'Cagnottes et tontines à plusieurs';

  @override
  String get homeHonamShort => 'Tes médicaments livrés';

  @override
  String get homeAssimeShort => 'Acheter et vendre près de chez toi';

  @override
  String homeDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
      zero: 'Dernier jour',
    );
    return '$_temp0';
  }

  @override
  String get emojiNoRecents => 'Tes emojis récents apparaîtront ici.';

  @override
  String get emojiSearchHint => 'Rechercher un emoji';

  @override
  String get composerBackspace => 'Effacer';

  @override
  String get messageCopy => 'Copier';

  @override
  String get messageCopied => 'Message copié';

  @override
  String get messageSelectText => 'Sélectionner le texte';

  @override
  String get messageSelectHint =>
      'Appui long sur un mot pour le sélectionner, puis étends la sélection.';

  @override
  String get messageCopyAll => 'Tout copier';

  @override
  String get honamUiFilterToReceive => 'À recevoir';

  @override
  String get honamUiFilterCompleted => 'Terminées';

  @override
  String get honamUiFilterCancelled => 'Annulées';

  @override
  String honamUiInProgressCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes en cours',
      one: '1 commande en cours',
    );
    return '$_temp0';
  }

  @override
  String honamUiOrderNo(String id) {
    return 'N° $id';
  }

  @override
  String get honamUiPrescription => 'Ordonnance';

  @override
  String get honamUiQuotePending => 'Devis en attente';

  @override
  String get honamUiQuotePendingBody =>
      'Le pharmacien n\'a pas encore envoyé son devis.';

  @override
  String honamUiItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String get honamUiSeeMore => 'Voir plus';

  @override
  String get honamUiSeeLess => 'Voir moins';

  @override
  String get honamUiSeeOrder => 'Voir la commande';

  @override
  String honamUiDateAt(String date, String time) {
    return '$date à $time';
  }

  @override
  String honamUiSubmittedOn(String date) {
    return 'Envoyée le $date';
  }

  @override
  String honamUiQuotedOn(String date) {
    return 'Devis reçu le $date';
  }

  @override
  String honamUiDeliveredOn(String date) {
    return 'Livrée le $date';
  }

  @override
  String honamUiRejectedOn(String date) {
    return 'Refusée le $date';
  }

  @override
  String honamUiExpiredOn(String date) {
    return 'Devis expiré le $date';
  }

  @override
  String honamUiCancelledOn(String date) {
    return 'Annulée le $date';
  }

  @override
  String honamUiStepOf(int step, int total) {
    return 'Étape $step sur $total';
  }

  @override
  String get honamUiEmptyTitle => 'Aucune commande en cours';

  @override
  String get honamUiEmptyBody =>
      'Photographie ton ordonnance : une pharmacie proche t\'envoie son devis.';

  @override
  String get honamUiEmptyCompleted =>
      'Aucune commande terminée pour l\'instant.';

  @override
  String get honamUiEmptyCancelled => 'Aucune commande annulée.';

  @override
  String get honamUiOrdersError => 'Impossible de charger tes commandes';

  @override
  String get honamUiPharmaciesError => 'Impossible de charger les pharmacies';

  @override
  String honamUiKm(String km) {
    return '$km km';
  }

  @override
  String honamUiCall(String name) {
    return 'Appeler $name';
  }

  @override
  String get honamUiSamu => 'SAMU';

  @override
  String get honamUiFire => 'Pompiers';

  @override
  String get honamUiPolice => 'Police';

  @override
  String get honamUiHeadSubmitted => 'Ordonnance envoyée';

  @override
  String get honamUiHelpSubmitted =>
      'Le pharmacien prépare ton devis. On te prévient dès qu\'il arrive.';

  @override
  String get honamUiHeadQuoted => 'Ton devis est arrivé';

  @override
  String get honamUiHelpQuoted =>
      'Vérifie les articles et le total, puis accepte le devis.';

  @override
  String get honamUiHeadAccepted => 'Paie la pharmacie';

  @override
  String get honamUiHelpAccepted =>
      'Envoie le montant depuis ton wallet, puis confirme ton paiement.';

  @override
  String get honamUiHeadPaid => 'Commande en préparation';

  @override
  String get honamUiHelpPaid =>
      'La pharmacie prépare ton colis. Garde ton code de remise sous la main.';

  @override
  String get honamUiHeadReady => 'Ton colis est prêt';

  @override
  String get honamUiHelpReady =>
      'Un coursier vient le chercher à la pharmacie.';

  @override
  String get honamUiHeadInDelivery => 'Ta commande est en route';

  @override
  String get honamUiHelpInDelivery =>
      'Donne ton code au coursier seulement quand tu as le colis en main.';

  @override
  String get honamUiHeadDelivered => 'Commande livrée !';

  @override
  String get honamUiHelpDelivered =>
      'Merci d\'avoir commandé avec Honam. Prends soin de toi.';

  @override
  String get honamUiHeadRejected => 'Ordonnance refusée';

  @override
  String get honamUiHelpRejected => 'Tu peux l\'envoyer à une autre pharmacie.';

  @override
  String get honamUiHeadExpired => 'Devis expiré';

  @override
  String get honamUiHelpExpired =>
      'Le devis n\'a pas été accepté à temps. Tu peux renvoyer ton ordonnance.';

  @override
  String get honamUiHeadCancelled => 'Commande annulée';

  @override
  String get honamUiHelpCancelled => 'Cette commande n\'ira pas plus loin.';

  @override
  String get honamUiDeliveryInfo => 'Suivi de livraison';

  @override
  String get honamUiNoSteps => 'Aucune étape enregistrée pour l\'instant.';

  @override
  String get honamUiItemsTitle => 'Articles de la commande';

  @override
  String get honamUiOrderId => 'N° de commande';

  @override
  String get honamUiCopy => 'Copier';

  @override
  String get honamUiOrderIdCopied => 'Numéro de commande copié';

  @override
  String get honamUiOrderTime => 'Commande passée';

  @override
  String get honamUiQuoteTime => 'Devis reçu';

  @override
  String get honamUiPaymentTime => 'Paiement confirmé';

  @override
  String get honamUiShipTime => 'Départ du coursier';

  @override
  String get honamUiDeliveredTime => 'Remise du colis';

  @override
  String get honamUiClosedTime => 'Fin de la commande';

  @override
  String get honamUiPharmacy => 'Pharmacie';

  @override
  String get honamUiCourier => 'Coursier';

  @override
  String get honamUiNoMessages => 'Aucun message pour l\'instant.';

  @override
  String get honamUiTrack => 'Suivre ma commande';

  @override
  String get honamUiRefundTitle => 'Remboursement';

  @override
  String honamUiUnitPrice(String price) {
    return '$price l\'unité';
  }

  @override
  String get koryHomeNewPot => 'Nouvelle cagnotte';

  @override
  String koryHomeActivePots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cagnottes actives',
      one: '1 cagnotte active',
      zero: 'Aucune cagnotte active',
    );
    return '$_temp0';
  }

  @override
  String koryHomeCollected(String amount) {
    return '$amount réunis';
  }

  @override
  String get koryHomeSearchHint => 'Trouver une cagnotte';

  @override
  String get koryHomeSearchClear => 'Effacer la recherche';

  @override
  String get koryHomeFilterAll => 'Toutes';

  @override
  String get koryHomeFilterCagnottes => 'Cagnottes';

  @override
  String get koryHomeFilterCotisations => 'Cotisations';

  @override
  String get koryHomeFilterTontines => 'Tontines';

  @override
  String get koryHomeFilterOpen => 'En cours';

  @override
  String get koryHomeFilterClosed => 'Clôturées';

  @override
  String get koryHomeFeatured => 'À la une';

  @override
  String koryHomeDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours restants',
      one: '1 jour restant',
      zero: 'Dernier jour aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String get koryHomeOverdue => 'Échéance dépassée';

  @override
  String get koryHomeContribute => 'Contribuer';

  @override
  String get koryHomeView => 'Consulter';

  @override
  String koryHomeRoundOf(String current, String total) {
    return 'Tour $current sur $total';
  }

  @override
  String koryHomeBeneficiary(String name) {
    return 'Bénéficiaire : $name';
  }

  @override
  String get koryHomeNoMatch => 'Aucune cagnotte ne correspond';

  @override
  String get koryHomeNoMatchBody => 'Essaie un autre nom, ou retire le filtre.';

  @override
  String get koryHomeShowAll => 'Tout afficher';

  @override
  String koryHomePercent(String percent) {
    return '$percent %';
  }

  @override
  String get groupClosedDeleted => 'Ce groupe a été supprimé.';

  @override
  String get groupClosedRemoved => 'Tu ne fais plus partie de ce groupe.';

  @override
  String get statusVideoTooLong =>
      'Vidéo trop longue : 60 secondes au plus pour un statut.';

  @override
  String get statusVideoLimitHint => 'Vidéo de 60 secondes au plus';

  @override
  String get homeAdLabel => 'Sponsorisé';

  @override
  String get homeAdCta => 'Découvrir';

  @override
  String get homeBabaHello => 'Moi, c’est Baba.';

  @override
  String get homeBabaOffer => 'Dis-moi ce qu’il te faut, je m’en occupe.';

  @override
  String get homeBabaCta => 'Parler à Baba';

  @override
  String get koryXAcceptInvite => 'Accepter l’invitation';

  @override
  String get koryXAcceptSwap => 'Accepter l’échange';

  @override
  String get koryXAccepted => 'Accepté';

  @override
  String koryXAcceptedOf(String accepted, String total) {
    return 'Ont accepté : $accepted sur $total';
  }

  @override
  String get koryXAcceptedToast => 'C’est noté : tu fais partie de la tontine.';

  @override
  String get koryXAddMemberHint =>
      'Ajouter un membre : il cotise dès l’échéance suivante';

  @override
  String koryXAdminOnly(String title) {
    return '$title · réservé à l’administrateur';
  }

  @override
  String koryXAdminWithDeputy(String admin, String deputy) {
    return '$admin · suppléant $deputy';
  }

  @override
  String get koryXAdministrator => 'Administrateur';

  @override
  String koryXAllAccepted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count membres ont accepté. La tontine est ouverte.',
      one: 'Le membre a accepté. La tontine est ouverte.',
    );
    return '$_temp0';
  }

  @override
  String get koryXAllGroupMembers => 'Tous les membres de la discussion';

  @override
  String get koryXAllPaid =>
      'Tu es à jour : aucune échéance à régler pour l’instant.';

  @override
  String get koryXAmount => 'Montant';

  @override
  String get koryXAmountHidden => 'un montant masqué';

  @override
  String get koryXAmountLabel => 'Montant';

  @override
  String koryXAmountPer(String amount, String period) {
    return '$amount, $period';
  }

  @override
  String koryXAmountTo(String amount, String name) {
    return '$amount à $name';
  }

  @override
  String get koryXAmountsLabel => 'Montants individuels';

  @override
  String get koryXApproveSwap => 'Valider l’échange';

  @override
  String get koryXBeneficiary => 'Bénéficiaire';

  @override
  String get koryXBeneficiaryField => 'Bénéficiaire (facultatif)';

  @override
  String get koryXCalendar => 'Calendrier des tours';

  @override
  String koryXCalendarDay(String day) {
    return 'Calendrier des tours · levée le $day';
  }

  @override
  String get koryXCalendarUpdated =>
      'Échange validé : le calendrier est à jour.';

  @override
  String get koryXCancelled => 'Annulé';

  @override
  String get koryXCancelledRounds => 'Tours annulés';

  @override
  String get koryXCaptureAdded => 'Capture du SMS ajoutée';

  @override
  String get koryXChangeAmount => 'Changer le montant';

  @override
  String get koryXChangeCollector => 'Changer de collecteur';

  @override
  String get koryXChangeCollectorSub =>
      'Un membre de la cotisation ; tous sont prévenus';

  @override
  String get koryXCheckAndCreate => 'Vérifier et créer';

  @override
  String get koryXCheckWallet =>
      'Vérifie dans ton application de wallet ou dans le SMS de l’opérateur. Chaque réponse est horodatée dans le journal.';

  @override
  String get koryXCheckWalletShort => 'Vérifie ton wallet, puis réponds';

  @override
  String get koryXChoose => 'Choisir';

  @override
  String get koryXChooseMembers => 'Choisir les membres';

  @override
  String get koryXChooseMembersSub =>
      'Par exemple, seulement les adultes du groupe';

  @override
  String koryXClosesOn(String date) {
    return 'clôture le $date';
  }

  @override
  String get koryXClosing => 'Clôture';

  @override
  String get koryXCoOrganizer => 'Co-organisateur · confirme';

  @override
  String get koryXCollectType => 'Type de collecte';

  @override
  String get koryXCollectorLabel => 'Collecteur';

  @override
  String koryXCollectorWallet(String wallet) {
    return 'Collecteur · $wallet';
  }

  @override
  String koryXConcernedMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Membres concernés · $count',
      one: 'Membre concerné · 1',
    );
    return '$_temp0';
  }

  @override
  String get koryXConfirmReceipts => 'Confirment les réceptions';

  @override
  String koryXConfirmedOf(String done, String total) {
    return 'Confirmées : $done sur $total';
  }

  @override
  String koryXConfirmedOnExpected(String expected) {
    return 'confirmés sur $expected attendus';
  }

  @override
  String koryXConfirmedOnPlanned(String planned) {
    return 'confirmés sur $planned prévus';
  }

  @override
  String koryXContestedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contestées',
      one: '1 contestée',
    );
    return '$_temp0';
  }

  @override
  String get koryXContestedThenConfirmed => 'contestée, puis confirmée';

  @override
  String get koryXContinue => 'Continuer';

  @override
  String koryXContinueWithMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Continuer avec $count membres',
      one: 'Continuer avec 1 membre',
    );
    return '$_temp0';
  }

  @override
  String koryXContributeAmount(String amount) {
    return 'Contribuer $amount';
  }

  @override
  String koryXContributionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributions',
      one: '1 contribution',
      zero: 'Aucune contribution',
    );
    return '$_temp0';
  }

  @override
  String get koryXCotisationJournal => 'Journal de la cotisation';

  @override
  String get koryXCotisationStopped =>
      'Cette cotisation est arrêtée. Le journal reste consultable.';

  @override
  String get koryXCreateCagnotte => 'Créer la cagnotte';

  @override
  String get koryXCreateCotisation => 'Créer la cotisation';

  @override
  String get koryXCsvAmount => 'Montant (FCFA)';

  @override
  String get koryXCsvDate => 'Date';

  @override
  String get koryXCsvEvent => 'Évènement';

  @override
  String get koryXCsvPerson => 'Personne';

  @override
  String get koryXCsvReference => 'Référence';

  @override
  String get koryXCsvStatus => 'Statut';

  @override
  String get koryXDeclared => 'Déclarée';

  @override
  String get koryXDeclaredLabel => 'Total déclaré';

  @override
  String koryXDeclaredUntil(String name) {
    return 'Ta contribution reste « Déclarée » jusqu’à ce que $name confirme l’avoir reçue. Tu es prévenu dès qu’il confirme ou conteste.';
  }

  @override
  String get koryXDeclineConfirm =>
      'Tu ne feras pas partie de la tontine. L’administrateur est prévenu.';

  @override
  String get koryXDeclineInvite => 'Refuser l’invitation';

  @override
  String get koryXDeclinedInvite => 'A refusé';

  @override
  String get koryXDeputy => 'Suppléant';

  @override
  String koryXDeputyIs(String name) {
    return 'Suppléant de l’administrateur : $name';
  }

  @override
  String koryXDeputyNotice(String name) {
    return '$name a les mêmes droits que toi sur la tontine : relancer, valider un échange de mois, passer au tour suivant, dissoudre.';
  }

  @override
  String koryXDialUssd(String operator) {
    return 'Composer le code USSD $operator';
  }

  @override
  String get koryXDissolve => 'Dissoudre la tontine';

  @override
  String get koryXDissolveFinal =>
      'Dissoudre arrête la tontine pour tous. C’est définitif.';

  @override
  String get koryXDissolveNoMoreRounds => 'Plus aucun tour n’est appelé.';

  @override
  String koryXDissolveNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count membres sont prévenus, avec le motif.',
      one: 'Le membre est prévenu, avec le motif.',
    );
    return '$_temp0';
  }

  @override
  String get koryXDissolveSettle =>
      'Ce qui a été versé entre membres se règle entre vous : Pokou n’a jamais touché l’argent.';

  @override
  String get koryXDissolved => 'Dissoute';

  @override
  String koryXDissolvedReason(String reason) {
    return 'Motif : « $reason ». Le journal et le rapport restent consultables.';
  }

  @override
  String get koryXDissolvedTitle => 'Tontine dissoute';

  @override
  String koryXDrawAt(String date, String time) {
    return 'Tirage au sort · $date, $time';
  }

  @override
  String get koryXDrawAtStart => 'Tirage au sort au démarrage';

  @override
  String get koryXDrawAtStartSub => 'Fait par Pokou, journalisé, non rejouable';

  @override
  String get koryXDrawLogged => 'Tirage au sort journalisé';

  @override
  String koryXDrawnOn(String date) {
    return 'Ordre tiré au sort le $date, journalisé.';
  }

  @override
  String get koryXDue => 'À venir';

  @override
  String koryXDueOn(String month, String day) {
    return '$month · échéance le $day';
  }

  @override
  String koryXEach(String amount) {
    return '$amount chacun';
  }

  @override
  String get koryXEditCotisation => 'Modifier ou arrêter la cotisation';

  @override
  String get koryXEditCotisationTitle => 'Modifier la cotisation';

  @override
  String koryXEditNotice(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ce qui est dû pour $month reste dû, et les mois passés restent au journal. Les $count membres sont prévenus.',
      one:
          'Ce qui est dû pour $month reste dû, et les mois passés restent au journal. Le membre est prévenu.',
    );
    return '$_temp0';
  }

  @override
  String koryXEditableRemaining(String amount) {
    return 'Modifiable · reste $amount à verser';
  }

  @override
  String get koryXEnd => 'Fin';

  @override
  String get koryXEveryFortnight => 'Chaque quinzaine';

  @override
  String get koryXEveryMonth => 'Chaque mois';

  @override
  String get koryXEveryQuarter => 'Chaque trimestre';

  @override
  String get koryXEveryWeek => 'Chaque semaine';

  @override
  String get koryXEvtClosed => 'La collecte est clôturée.';

  @override
  String koryXEvtConfirmed(String reviewer, String amount, String who) {
    return '$reviewer a confirmé $amount de $who';
  }

  @override
  String koryXEvtContested(String reviewer, String amount, String who) {
    return '$reviewer a contesté $amount de $who';
  }

  @override
  String koryXEvtContestedReason(
    String reviewer,
    String amount,
    String who,
    String reason,
  ) {
    return '$reviewer a contesté $amount de $who : « $reason »';
  }

  @override
  String koryXEvtCreated(String name, String kind) {
    return '$name a créé la collecte ($kind)';
  }

  @override
  String koryXEvtDeclared(String who, String amount) {
    return '$who a déclaré $amount';
  }

  @override
  String koryXEvtDeclaredRef(String who, String amount, String ref) {
    return '$who a déclaré $amount · réf. $ref';
  }

  @override
  String koryXEvtDissolved(String reason) {
    return 'La tontine est dissoute : « $reason »';
  }

  @override
  String koryXEvtDrawn(String seal) {
    return 'Pokou a tiré l’ordre des tours au sort · empreinte $seal';
  }

  @override
  String koryXEvtExtended(String date) {
    return 'La collecte est prolongée jusqu’au $date';
  }

  @override
  String get koryXEvtOrderFixed =>
      'L’ordre des tours est fixé ; la tontine démarre';

  @override
  String koryXEvtSwap(String a, String b) {
    return '$a et $b ont échangé leurs mois';
  }

  @override
  String get koryXExportCsv => 'Exporter en CSV';

  @override
  String get koryXExportPdf => 'Exporter en PDF';

  @override
  String get koryXFilterAll => 'Tout';

  @override
  String get koryXFilterConfirmed => 'Confirmées';

  @override
  String get koryXFilterContested => 'Contestées';

  @override
  String koryXFirmRemaining(String amount) {
    return 'Ferme · reste $amount à verser';
  }

  @override
  String get koryXFirstDue => 'Première échéance';

  @override
  String get koryXFirstRound => 'Premier tour';

  @override
  String get koryXFixOrder => 'Je fixe l’ordre moi-même';

  @override
  String get koryXFixOrderSub => 'Chacun voit son mois dès l’ouverture';

  @override
  String koryXFixedAt(String date) {
    return 'Ordre fixé par l’administrateur · $date';
  }

  @override
  String koryXFixedOn(String date) {
    return 'Ordre fixé par l’administrateur le $date, journalisé.';
  }

  @override
  String get koryXFixedOrder => 'Ordre fixé par l’administrateur';

  @override
  String get koryXFreeNotice =>
      'Sans frais. Pokou ne touche pas l’argent : chacun verse depuis son wallet au collecteur.';

  @override
  String koryXFromDueOf(String date) {
    return 'À partir de l’échéance du $date';
  }

  @override
  String get koryXGoalLabel => 'Objectif';

  @override
  String koryXGroupPeople(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name · $count personnes',
      one: '$name · 1 personne',
    );
    return '$_temp0';
  }

  @override
  String koryXHaveContributed(String done, String total) {
    return 'Ont cotisé : $done sur $total';
  }

  @override
  String koryXHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
      one: 'il y a 1 h',
    );
    return '$_temp0';
  }

  @override
  String get koryXISent => 'J’ai envoyé';

  @override
  String get koryXInProgress => 'en cours';

  @override
  String koryXIncludingYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count, dont toi',
      one: 'Toi seul',
    );
    return '$_temp0';
  }

  @override
  String get koryXIndividualAmounts => 'Montants individuels';

  @override
  String get koryXInvitation => 'Invitation';

  @override
  String get koryXJoinAndPledge => 'Rejoindre et m’engager';

  @override
  String get koryXJoinNotice =>
      'Pokou ne touche pas l’argent. Tu t’engages sur un montant, puis tu verses depuis ton wallet au collecteur et tu déclares ton versement.';

  @override
  String get koryXJournalLocked =>
      'Chaque action est horodatée et ne peut pas être effacée, même par l’organisateur.';

  @override
  String get koryXKoryPlus => 'Kory Plus';

  @override
  String get koryXLastDue => 'Dernière échéance';

  @override
  String koryXLastDueOn(String date) {
    return 'Dernière échéance : $date';
  }

  @override
  String get koryXLate => 'En retard';

  @override
  String koryXLateCount(String count) {
    return 'En retard · $count';
  }

  @override
  String koryXLeveeCaption(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres × $amount',
      one: '1 membre × $amount',
    );
    return '$_temp0';
  }

  @override
  String get koryXLeveePerRound => 'Levée de chaque tour';

  @override
  String koryXLinkFrom(String name) {
    return 'Organisée par $name';
  }

  @override
  String get koryXLinkedChat => 'Discussion liée';

  @override
  String get koryXMakeCoOrganizer => 'Désigner co-organisateur';

  @override
  String get koryXMakeDeputy => 'Désigner suppléant';

  @override
  String get koryXMembersAndOrder => 'Membres et ordre';

  @override
  String get koryXMembersAndRounds => 'Membres et tours';

  @override
  String koryXMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Membres · $count',
      one: 'Membres · 1',
    );
    return '$_temp0';
  }

  @override
  String get koryXMembersLabel => 'Membres';

  @override
  String get koryXMembersNoticeAlone =>
      'Tu confirmes les réceptions. Un membre qui rejoint le groupe plus tard ne cotise pas d’office : tu l’ajoutes depuis la cotisation, et il cotise dès l’échéance suivante.';

  @override
  String koryXMembersNoticeWith(String name) {
    return 'Toi et $name confirmez les réceptions. Un membre qui rejoint le groupe plus tard ne cotise pas d’office : tu l’ajoutes depuis la cotisation, et il cotise dès l’échéance suivante.';
  }

  @override
  String koryXMembersTimes(int count, String amount, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres × $amount, $period',
      one: '1 membre × $amount, $period',
    );
    return '$_temp0';
  }

  @override
  String get koryXMembersTitle => 'Membres';

  @override
  String get koryXMessageOptional => 'Message (facultatif)';

  @override
  String koryXMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
      one: 'il y a 1 min',
    );
    return '$_temp0';
  }

  @override
  String get koryXMoreActions => 'Plus d’actions';

  @override
  String get koryXMyDues => 'Mes échéances';

  @override
  String get koryXMyLevee => 'Ma levée';

  @override
  String koryXMyLeveeOf(String month) {
    return 'Ta levée de $month';
  }

  @override
  String koryXMyPledgeAmount(String amount) {
    return 'Mon engagement · $amount';
  }

  @override
  String get koryXName => 'Nom';

  @override
  String get koryXNeedFirstDue => 'Choisis la date de la première échéance.';

  @override
  String get koryXNeedGroup =>
      'Une tontine s’ouvre depuis une discussion de groupe : choisis-la.';

  @override
  String get koryXNewAmountPerMember => 'Nouveau montant par membre';

  @override
  String get koryXNewCotisation => 'Nouvelle cotisation';

  @override
  String get koryXNewTontine => 'Nouvelle tontine';

  @override
  String koryXNextDueIn(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Prochaine échéance · $date, dans $days jours',
      one: 'Prochaine échéance · $date, demain',
      zero: 'Prochaine échéance · $date, aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String get koryXNextDues => 'Prochaines échéances';

  @override
  String get koryXNextRounds => 'Prochains tours';

  @override
  String get koryXNoDeputyNotice =>
      'Sans suppléant, toi seul administres la tontine : relances, échanges de mois, tour suivant, dissolution.';

  @override
  String get koryXNoDueYet =>
      'Pas encore d’échéance : le calendrier commence à la première date choisie.';

  @override
  String get koryXNoEnd => 'Sans date de fin';

  @override
  String get koryXNoGroups => 'Aucune discussion de groupe pour l’instant.';

  @override
  String get koryXNoLinkedChat => 'Aucune discussion';

  @override
  String get koryXNoSwapPossible => 'Aucun mois à venir ne peut être échangé.';

  @override
  String get koryXNoTransferNotice =>
      'Pokou ne transfère pas l’argent. Vérifie le nom du destinataire affiché par ton opérateur avant de valider. Les frais de ton opérateur s’appliquent.';

  @override
  String get koryXNotNow => 'Pas maintenant';

  @override
  String get koryXNothingToConfirm => 'Rien à confirmer pour l’instant.';

  @override
  String koryXOfWhichToConfirm(String amount) {
    return 'dont $amount à confirmer';
  }

  @override
  String koryXOnDay(String date) {
    return 'le $date';
  }

  @override
  String koryXOnGoalOf(String amount) {
    return 'sur un objectif de $amount';
  }

  @override
  String get koryXOnlyYouConfirm =>
      'Vérifie dans ton application de wallet ou dans le SMS de l’opérateur. Tu es le seul à confirmer ce que tu as reçu ; chaque réponse est horodatée au journal.';

  @override
  String get koryXOnlyYouConfirmShort => 'C’est ta levée : toi seul confirmes';

  @override
  String koryXOpenAndInvite(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ouvrir et inviter $count membres',
      one: 'Ouvrir et inviter 1 membre',
    );
    return '$_temp0';
  }

  @override
  String get koryXOpenPot => 'Voir la collecte';

  @override
  String get koryXOrganizerCollector => 'Organisateur · collecteur';

  @override
  String get koryXOrganizerSide => 'vue de l’organisateur';

  @override
  String koryXOrganizerView(String title) {
    return '$title · vue de l’organisateur';
  }

  @override
  String koryXOutOf(String done, String total) {
    return '$done sur $total';
  }

  @override
  String koryXOverdueSince(String date) {
    return 'Échéance du $date dépassée';
  }

  @override
  String koryXPaidOf(String paid, String total) {
    return 'À jour : $paid sur $total';
  }

  @override
  String get koryXParticipants => 'Participants';

  @override
  String get koryXPastRounds => 'Tours passés';

  @override
  String get koryXPause => 'Mettre en pause';

  @override
  String koryXPauseSub(String date) {
    return 'Pas d’échéance le $date ; reprise à la suivante';
  }

  @override
  String koryXPendingSubtitle(String group) {
    return 'Kory Plus · $group · en attente des membres';
  }

  @override
  String koryXPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '1 personne',
    );
    return '$_temp0';
  }

  @override
  String get koryXPeriodBiweekly => 'chaque quinzaine';

  @override
  String koryXPeriodCounts(String up, String pending, String late) {
    return 'À jour : $up · à confirmer : $pending · en retard : $late';
  }

  @override
  String get koryXPeriodQuarterly => 'chaque trimestre';

  @override
  String get koryXPeriodicity => 'Périodicité';

  @override
  String get koryXPickCollector => 'Choisis le nouveau collecteur.';

  @override
  String get koryXPlannedPerDue => 'Total prévu à chaque échéance';

  @override
  String koryXPlannedTo(String name) {
    return 'Prévue · à verser à $name';
  }

  @override
  String get koryXPreviousDues => 'Échéances précédentes';

  @override
  String get koryXReasonRequired => 'Motif (obligatoire)';

  @override
  String koryXRecapNotice(int count, String group) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count membres sont prévenus par une notification de « $group ».',
      one: 'Le membre est prévenu par une notification de « $group ».',
    );
    return '$_temp0';
  }

  @override
  String get koryXRecapNoticeAlone =>
      'Ensuite, ajoute les membres par leur numéro, ou partage le lien de la cotisation.';

  @override
  String koryXRefShort(String ref) {
    return 'réf. $ref';
  }

  @override
  String get koryXReferenceLabel => 'Référence à indiquer';

  @override
  String get koryXRefuse => 'Refuser';

  @override
  String get koryXRejectNeedsReason =>
      '« Pas reçu » demande un motif ; la contribution passe en « Contestée » et la personne est prévenue.';

  @override
  String get koryXRemainingLabel => 'Reste à collecter';

  @override
  String get koryXRemindHint => 'Relance-les : chacun reçoit une notification.';

  @override
  String get koryXRemindLate => 'Relancer les retardataires';

  @override
  String koryXRemindMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Relancer les $count membres',
      one: 'Relancer 1 membre',
      zero: 'Tout le monde a répondu',
    );
    return '$_temp0';
  }

  @override
  String get koryXRemindTooSoon =>
      'Une relance a déjà été envoyée il y a moins de 12 h.';

  @override
  String koryXReminded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes relancées.',
      one: '1 personne relancée.',
      zero: 'Personne à relancer.',
    );
    return '$_temp0';
  }

  @override
  String koryXRemindedAt(String date, String time) {
    return 'Relancés le $date à $time ; chacun peut couper ses notifications.';
  }

  @override
  String get koryXRemoveCapture => 'Retirer la capture';

  @override
  String get koryXReport => 'Rapport';

  @override
  String get koryXReportKept =>
      'Le rapport et le journal restent consultables et exportables par chacun, même si la tontine est dissoute.';

  @override
  String get koryXReportMeaning =>
      '« A cotisé » veut dire « confirmé par le bénéficiaire du tour » : Pokou ne voit jamais l’argent.';

  @override
  String get koryXReportTitle => 'Rapport de la tontine';

  @override
  String get koryXRequestSent => 'Demande envoyée.';

  @override
  String koryXRoundCounts(String confirmed, String declared, String late) {
    return 'Confirmées : $confirmed · déclarées : $declared · en retard : $late';
  }

  @override
  String koryXRoundOfMonth(String number, String total, String month) {
    return 'Tour $number sur $total · $month';
  }

  @override
  String koryXRoundsSpan(int count, String from, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count · de $from à $to',
      one: '1 · en $from',
    );
    return '$_temp0';
  }

  @override
  String koryXSaveAndNotify(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enregistrer et prévenir les $count membres',
      one: 'Enregistrer et prévenir le membre',
    );
    return '$_temp0';
  }

  @override
  String get koryXSavedAndNotified => 'Enregistré. Les membres sont prévenus.';

  @override
  String koryXSeal(String seal) {
    return 'Fait par Pokou, journalisé, non rejouable · empreinte $seal';
  }

  @override
  String get koryXSeeJournal => 'Voir tout le journal';

  @override
  String get koryXSeeReport => 'Voir le rapport de la tontine';

  @override
  String get koryXSendRequest => 'Envoyer la demande';

  @override
  String koryXSendRequestTo(String name) {
    return 'Envoyer la demande à $name';
  }

  @override
  String get koryXSentAt => 'Envoyé';

  @override
  String get koryXShareLink => 'Partager le lien';

  @override
  String get koryXSmsCaptureAttached => 'Capture du SMS jointe';

  @override
  String get koryXSomeoneDeclined =>
      'Quelqu’un a refusé : quand tous les autres auront accepté, tu pourras démarrer sans lui, ou dissoudre.';

  @override
  String koryXStakeDue(String amount, String date) {
    return '$amount par membre · échéance le $date';
  }

  @override
  String get koryXStakeLabel => 'Cotisation par membre';

  @override
  String get koryXStakePerMember => 'Cotisation par membre';

  @override
  String koryXStartWithout(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Démarrer sans les $count personnes qui ont refusé',
      one: 'Démarrer sans la personne qui a refusé',
    );
    return '$_temp0';
  }

  @override
  String get koryXStartsWhenAllAccept =>
      'La tontine démarre quand tous les membres ont accepté l’invitation. Chacun est prévenu, et l’ordre des tours est alors fixé.';

  @override
  String get koryXStatusAfter => 'Statut après déclaration';

  @override
  String get koryXStepParams => 'Étape 1 sur 3 · paramètres';

  @override
  String get koryXStopConfirm =>
      'Plus aucune échéance après celle en cours. Ce qui est dû reste dû, et le journal reste consultable.';

  @override
  String get koryXStopCotisation => 'Arrêter la cotisation';

  @override
  String get koryXSwapCalendarNotice =>
      'Le calendrier change pour tous ; c’est noté au journal.';

  @override
  String get koryXSwapMyMonth => 'Échanger mon mois';

  @override
  String get koryXSwapNotice =>
      'Chacun voit ce calendrier. Un échange de mois se fait entre deux membres, avec l’accord de l’administrateur.';

  @override
  String koryXSwapRequest(String a, String b) {
    return 'Échange de mois entre $a et $b';
  }

  @override
  String koryXSwapRounds(String a, String b) {
    return 'Tour $a contre tour $b';
  }

  @override
  String get koryXSwapStep1 => 'Tu envoies la demande';

  @override
  String koryXSwapStep2(String name) {
    return '$name accepte';
  }

  @override
  String koryXSwapStep3(String name) {
    return '$name, l’administrateur, valide';
  }

  @override
  String get koryXSwapWaitingAdmin =>
      'Accepté · en attente de l’administrateur';

  @override
  String koryXSwapWaitingMember(String name) {
    return 'En attente de la réponse de $name';
  }

  @override
  String get koryXThisRound => 'Ce tour';

  @override
  String koryXToConfirmCount(String count) {
    return 'À confirmer · $count';
  }

  @override
  String koryXTodayAt(String time) {
    return 'Aujourd’hui, $time';
  }

  @override
  String get koryXTontineDone =>
      'La tontine est terminée : tous les tours ont eu lieu.';

  @override
  String koryXTontineInviteFrom(String name) {
    return 'Tontine Kory Plus · invitation de $name';
  }

  @override
  String get koryXTontinePlus => 'Tontine Plus';

  @override
  String get koryXTontineStarts => 'La tontine démarre';

  @override
  String koryXTontineStep(String step) {
    return 'Kory Plus · étape $step sur 3';
  }

  @override
  String koryXTontineStepOf(String title, String step) {
    return '$title · étape $step sur 3';
  }

  @override
  String get koryXTransactionRef => 'Référence de transaction';

  @override
  String get koryXTransactionRefHelp =>
      'Elle figure dans le SMS de confirmation de ton opérateur.';

  @override
  String get koryXUpcoming => 'À venir';

  @override
  String get koryXVisibleToAll => 'Visibles de tous';

  @override
  String koryXVisibleToAllMembers(String title) {
    return '$title · visible de tous les membres';
  }

  @override
  String get koryXVisibleToCollector => 'Visibles du collecteur seulement';

  @override
  String get koryXWaiting => 'En attente';

  @override
  String get koryXWhatHappensNext => 'Ce qui se passe ensuite';

  @override
  String get koryXWhatToChange => 'Que veux-tu changer ?';

  @override
  String get koryXWhichJournal => 'Quel journal ouvrir ?';

  @override
  String get koryXWithAnotherMember => 'avec un autre membre';

  @override
  String get koryXWithWhom => 'Avec qui ?';

  @override
  String get koryXWithdrawRequest => 'Retirer ma demande';

  @override
  String get koryXYouAccepted =>
      'Tu as accepté. La tontine démarre dès que tous auront répondu.';

  @override
  String koryXYouAnd(String name) {
    return 'Toi et $name';
  }

  @override
  String get koryXYouDeclined => 'Tu as refusé cette invitation.';

  @override
  String get koryXYouReceive => 'Tu reçois la levée de ce tour';

  @override
  String get koryXYourContributions => 'Tes cotisations';

  @override
  String get koryXYourMonth => 'Ton mois';

  @override
  String get koryXUpToDate => 'À jour';
}
