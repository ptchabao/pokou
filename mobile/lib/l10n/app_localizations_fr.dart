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
  String get chatsEmptyBody => 'Vos conversations apparaîtront ici.';

  @override
  String get chatsSearchHint => 'Rechercher';

  @override
  String get chatsTyping => 'écrit…';

  @override
  String chatsTypingNamed(String name) {
    return '$name écrit…';
  }

  @override
  String get chatsUnknownContact => 'pas dans vos contacts';

  @override
  String get chatsNoMessageYet => 'Aucun message pour l\'instant';

  @override
  String chatsYouPrefix(String message) {
    return 'Vous : $message';
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
      'Aucun de vos contacts n\'utilise encore Pokou.';

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
      'Vous verrez ce qui est déjà sur cet appareil. Le reste arrivera au retour du réseau.';

  @override
  String get offlineNothingCached =>
      'Rien n\'est encore enregistré sur cet appareil.';

  @override
  String get offlineSending => 'En attente d\'envoi';

  @override
  String get errorNetwork => 'Connexion impossible. Vérifiez votre réseau.';

  @override
  String get twoStepTitle => 'Vérification en deux étapes';

  @override
  String get twoStepBody =>
      'Ce compte est protégé par un code. Saisissez-le pour terminer la connexion.';

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
  String get profileLanguageSubtitle =>
      'Choisissez la langue de l\'application';

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
      'Ajoutez une photo — sans elle, presque personne ne like';

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
      'Connectez-vous de manière sécurisée avec votre numéro.';

  @override
  String get authPhoneHint => 'Votre numéro';

  @override
  String get authPrivacyNote =>
      'Connexion sécurisée. Votre numéro sert uniquement à vérifier votre identité.';

  @override
  String get authVerifyTitle => 'Vérification';

  @override
  String authCodeSentTo(String phone) {
    return 'Saisissez le code à 6 chiffres envoyé au $phone';
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
      'Cette personne ne pourra plus vous écrire ni vous appeler. Elle ne sera pas prévenue.';

  @override
  String get chatsPinLimit => 'Trois discussions déjà épinglées au maximum.';

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
  String get navYou => 'Vous';

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
  String get convEditHint => 'Votre message';

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
  String get modulesCheckNetwork => 'Vérifiez votre connexion et réessayez.';

  @override
  String get modulesEmptyTitle => 'Rien à ajouter pour l\'instant';

  @override
  String get modulesEmptyBody =>
      'De nouveaux modules arriveront ici. Vous n\'avez rien à faire en attendant.';

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
    return '$name arrive bientôt. Mettez l\'application à jour pour en profiter dès sa sortie.';
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
  String get sparkEnableLocation =>
      'Activez la localisation sur votre téléphone.';

  @override
  String get sparkLocationNeeded =>
      'Sans position, Spark ne peut pas savoir qui est autour de vous.';

  @override
  String get sparkLocationFailed => 'La position n\'a pas pu être relevée.';

  @override
  String get sparkFeedUnavailable => 'Flux indisponible';

  @override
  String get sparkPickIntentTitle => 'Choisissez votre carte du moment';

  @override
  String get sparkPickIntentBody =>
      'Dites ce que vous cherchez aujourd\'hui pour voir qui cherche la même chose.';

  @override
  String get sparkLocationStale => 'Votre position n\'est pas à jour';

  @override
  String get sparkLocationStaleBody =>
      'Spark ne montre que des gens à moins de 5 km. Sans position fraîche, il ne peut rien afficher.';

  @override
  String get sparkShareLocation => 'Partager ma position';

  @override
  String get sparkQuotaTitle => 'Vous avez vu vos profils du jour';

  @override
  String get sparkQuotaBody =>
      'Revenez demain, ou prenez Spark+ pour voir sans compter.';

  @override
  String get sparkNobodyTitle => 'Personne pour l\'instant';

  @override
  String get sparkNobodyBody =>
      'Peu de monde cherche la même chose que vous, ici et maintenant. Réessayez plus tard — ou changez de carte.';

  @override
  String get sparkPickCard => 'Choisissez votre carte';

  @override
  String get sparkTodayLooking => 'Ce que vous cherchez aujourd\'hui';

  @override
  String get sparkCardExpired => 'Votre carte a expiré';

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
      'Votre carte expire dans 24 h. Vous ne verrez que des gens qui ont choisi la même chose.';

  @override
  String get sparkLikesExhausted =>
      'Vos likes du jour sont épuisés. Prenez un pack dans « Moi ».';

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
  String get sparkPlusActive => 'Actif — prolonge votre abonnement';

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
      'Les profils sur lesquels on vous demande un avis';

  @override
  String get sparkUploading => 'Envoi…';

  @override
  String get sparkKarma => 'Street Cred';

  @override
  String get sparkCanInvite => 'Vous pouvez inviter';

  @override
  String get sparkCannotInvite =>
      'Trop bas pour inviter. Honorez vos rendez-vous.';

  @override
  String sparkLikersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes vous ont liké',
      one: 'Une personne vous a liké',
    );
    return '$_temp0';
  }

  @override
  String get sparkSeeWho => 'Voir qui';

  @override
  String get sparkFindInDiscover => 'Retrouvez-les dans Découvrir.';

  @override
  String get sparkPaymentPendingLikers =>
      'La liste s\'ouvrira dès la confirmation du paiement.';

  @override
  String get sparkPaymentPendingLikes =>
      'Vos likes arriveront dès la confirmation du paiement.';

  @override
  String get sparkPaymentPendingPlus =>
      'Spark+ s\'activera dès la confirmation du paiement.';

  @override
  String get sparkPaymentPendingBoost =>
      'Votre profil remontera dès la confirmation du paiement.';

  @override
  String get sparkBirthDateLabel => 'Votre date de naissance';

  @override
  String get sparkNameAndBirthNeeded =>
      'Un prénom et une date de naissance, au minimum.';

  @override
  String get sparkProfileFailed => 'La fiche n\'a pas pu être créée.';

  @override
  String get sparkCreateProfile => 'Créez votre fiche';

  @override
  String get sparkStep1Title => 'Vous dites ce que vous cherchez, aujourd\'hui';

  @override
  String get sparkStep1Body =>
      'Votre carte expire en 24 h. Vous ne voyez que des gens qui cherchent la même chose, à moins de 5 km.';

  @override
  String get sparkStep2Title => 'Dix minutes de vocal avant d\'écrire';

  @override
  String get sparkStep2Body =>
      'Après un match, une salle s\'ouvre : vocaux et stickers seulement. Les faux profils ne passent pas cette étape.';

  @override
  String get sparkStep3Title => 'Vos proches savent où vous êtes';

  @override
  String get sparkStep3Body =>
      'Un geste discret prévient votre cercle avec votre position. On vous demande aussi si tout va bien pendant le rendez-vous.';

  @override
  String get sparkSeparateTitle => 'Votre fiche est séparée de Pokou';

  @override
  String get sparkSeparateBody =>
      'Votre nom et votre numéro Pokou ne sont jamais montrés ici. Choisissez ce que vous voulez afficher.';

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
  String get sparkYouAre => 'Vous êtes';

  @override
  String get sparkWoman => 'Une femme';

  @override
  String get sparkMan => 'Un homme';

  @override
  String get sparkOther => 'Autre';

  @override
  String get sparkBioLabel => 'Deux mots sur vous (facultatif)';

  @override
  String get sparkBioHint => 'Ce qu\'il faut savoir avant de vous rencontrer';

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
      'Quand quelqu\'un paiera pour vous poser une question, elle apparaîtra ici. Vous resterez libre de refuser.';

  @override
  String get truthYourAnswer => 'Votre réponse';

  @override
  String get truthAnswerPrivacy =>
      'Elle ne va qu\'à la personne qui a payé. Pokou ne la republie nulle part.';

  @override
  String get truthWhatToSay => 'Ce que vous voulez dire';

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
      'Refuser ne vous coûte rien. Vous n\'êtes payé qu\'en répondant.';

  @override
  String get truthHistoryUnavailable => 'Historique indisponible';

  @override
  String get truthNothingAsked => 'Vous n\'avez encore rien demandé';

  @override
  String get truthNothingAskedBody =>
      'Posez une question à quelqu\'un : il verra le montant et la question, jamais votre nom.';

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
  String get truthAnonTitle => 'Votre nom n\'est pas montré';

  @override
  String get truthAnonBody =>
      'La personne voit le montant et la question, jamais qui les a envoyés.';

  @override
  String get truthFreeTitle => 'Elle reste libre de refuser';

  @override
  String get truthFreeBody =>
      'Refuser ne lui rapporte rien : elle n\'est payée qu\'en répondant.';

  @override
  String get truthPrivateTitle => 'La réponse ne va qu\'à vous';

  @override
  String get truthPrivateBody =>
      'Pokou ne la republie nulle part, et elle expire au bout de sept jours sans réponse.';

  @override
  String get truthYourQuestion => 'Votre question';

  @override
  String get truthQuestionHint => 'Ce que vous aimeriez vraiment savoir';

  @override
  String get truthHowMuch => 'Combien vous proposez';

  @override
  String truthAskForAmount(int amount) {
    return 'Poser la question — $amount FCFA';
  }

  @override
  String get truthWriteFirst => 'Écrivez d\'abord votre question.';

  @override
  String get truthPaymentPending =>
      'Votre question partira dès la confirmation du paiement.';

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
      'Vos objectifs et ceux que vous avez soutenus apparaîtront ici.';

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
  String get hypeBeFirst => 'Personne encore. Soyez le premier.';

  @override
  String get hypeContributor => 'Contributeur';

  @override
  String commonDueToYou(int amount) {
    return 'Vous revient : $amount FCFA';
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
  String get hypeStepPromiseTitle => 'Ce que vous promettez';

  @override
  String get hypeStepPromiseBody =>
      'Visible avant que quiconque ne paie. C\'est votre engagement si l\'objectif est atteint.';

  @override
  String get hypeStepOneTitle => 'Un seul objectif à la fois';

  @override
  String get hypeStepOneBody =>
      'Deux objectifs simultanés mettraient vos contributeurs en concurrence avec eux-mêmes.';

  @override
  String get commonTitle => 'Titre';

  @override
  String get hypeTitleExample => 'Ex : 100 000 et je chante';

  @override
  String get hypePromiseLabel => 'Ce que vous débloquez si l\'objectif tombe';

  @override
  String get hypePromiseHint =>
      'Soyez précis : c\'est ce que vos contributeurs achètent.';

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
  String get hypeAlreadyRunning => 'Vous avez déjà un objectif en cours.';

  @override
  String get hypeContributeNote =>
      'Votre participation fait avancer la barre et débloque un contenu. Elle n\'est pas remboursable.';

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
      'Mariage, baptême, deuil : créez la cagnotte, invitez, et chacun contribue comme il peut.';

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
  String get ceremonyYouOrganize => 'vous organisez';

  @override
  String get ceremonyNewSubtitle =>
      'Vous suivez les participations. Pokou n\'envoie aucune relance à ceux qui n\'ont pas donné.';

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
  String get ceremonyNeedTitle => 'Donnez un titre à la cagnotte.';

  @override
  String ceremonyJoinTo(String title) {
    return 'Participer — $title';
  }

  @override
  String get ceremonyOtherAmount => 'Ou un autre montant';

  @override
  String get ceremonyWordOptional => 'Un mot (facultatif)';

  @override
  String get ceremonyWordHint => 'Ce que vous voulez leur dire';

  @override
  String get ceremonyAnonToggle => 'Participer anonymement';

  @override
  String get ceremonyAnonNote =>
      'Votre nom sera masqué. Le montant reste dans le total.';

  @override
  String ceremonyJoinAmount(int amount) {
    return 'Participer — $amount FCFA';
  }

  @override
  String get ceremonyMinimum => 'Le minimum est de 100 FCFA.';

  @override
  String get ceremonyPaymentPending =>
      'Votre participation apparaîtra dès la confirmation du paiement.';

  @override
  String get vipSubtitle => 'Vos abonnés, votre espace';

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
      'Abonnez-vous à un salon pour retrouver ici tout ce que son créateur publie.';

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
      'Vous voyez immédiatement les publications déjà en ligne, et celles qui suivront.';

  @override
  String get vipStepDaysTitle => 'Trente jours';

  @override
  String get vipStepDaysBody =>
      'L\'accès s\'arrête tout seul au terme. Rien ne continue sans que vous le décidiez.';

  @override
  String get vipStepNoRenewTitle => 'Aucune reconduction automatique';

  @override
  String get vipStepNoRenewBody =>
      'Pokou ne conserve pas votre moyen de paiement. Pour continuer, vous repayez, une fois.';

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
  String get vipOpenYourRoom => 'Ouvrez votre salon';

  @override
  String get vipOpenYourRoomBody =>
      'Vos abonnés paient une fois pour trente jours et voient tout ce que vous publiez ici. Vous fixez le prix.';

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
  String get vipEarnings => 'Vos revenus';

  @override
  String vipCollected(int amount) {
    return '$amount FCFA collectés';
  }

  @override
  String get vipDueNote =>
      'Montant qui vous revient. Le versement se fait par l\'équipe Pokou, sur demande.';

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
  String get vipPitchLabel => 'Ce que vos abonnés y trouveront';

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
      'Vos abonnés actuels gardent leur accès jusqu\'au terme.';

  @override
  String get vipFieldsNeeded => 'Nom, description et prix sont nécessaires.';

  @override
  String get vipPublishTitle => 'Publier dans mon salon';

  @override
  String get vipPublishNote => 'Visible uniquement par vos abonnés en cours.';

  @override
  String get vipYourMessage => 'Votre message';

  @override
  String get vipShareHint => 'Ce que vous voulez partager';

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
      'Une fois la salle passée, proposez un endroit. Vous payez d\'avance, et l\'argent n\'est versé qu\'une fois que vous confirmez tous les deux.';

  @override
  String get datesNotNow => 'Ce n\'est pas le moment pour ce geste.';

  @override
  String get datesCancelTitle => 'Annuler la sortie ?';

  @override
  String get datesCancelFree =>
      'Vous êtes à plus de 24 h : vous serez intégralement remboursé.';

  @override
  String get datesCancelLate =>
      'Il reste moins de 24 h. L\'établissement a déjà réservé, votre paiement lui reste acquis.';

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
  String get datesYourMatch => 'votre match';

  @override
  String get datesWentWell => 'Ça s\'est bien passé';

  @override
  String get datesYouConfirmed =>
      'Vous avez confirmé. On attend la confirmation de l\'autre.';

  @override
  String get datesNoShowAction => 'Il n\'est pas venu';

  @override
  String get datesVoucher => 'Votre bon, à donner sur place';

  @override
  String get datesPickBoth => 'Choisissez une formule et un moment.';

  @override
  String get datesVoucherPending =>
      'Votre bon sera émis dès la confirmation du paiement.';

  @override
  String get datesBookingFailed => 'La réservation n\'a pas abouti.';

  @override
  String get datesWhereTo => 'Où allez-vous ?';

  @override
  String get datesStepPayTitle => 'Vous payez d\'avance, rien n\'est versé';

  @override
  String get datesStepPayBody =>
      'L\'argent est bloqué. Il ne part chez l\'établissement que si vous confirmez tous les deux.';

  @override
  String get datesStepCancelTitle => 'Annulation libre à plus de 24 h';

  @override
  String get datesStepCancelBody =>
      'Remboursement intégral. En deçà, l\'établissement a déjà réservé et garde votre paiement.';

  @override
  String get datesStepNoShowTitle => 'Si l\'autre ne vient pas';

  @override
  String get datesStepNoShowBody =>
      'La moitié vous revient. L\'application ne prend rien sur un rendez-vous manqué.';

  @override
  String get datesThePackage => 'La formule';

  @override
  String get datesPacksUnavailable =>
      'Les formules ne sont pas disponibles pour le moment.';

  @override
  String get datesNoPackNearby =>
      'Aucune formule n\'est proposée près de chez vous pour l\'instant.';

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
      'C\'est parti. Vous pouvez maintenant proposer une sortie.';

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
  String get roomSaved =>
      'Le match est sauvé. Vous pouvez proposer une sortie.';

  @override
  String get roomClosedNoAnswer => 'La salle s\'est refermée sans réponse.';

  @override
  String get roomSuggestDate => 'Proposer une sortie';

  @override
  String get safetyCheckin => 'Tout va bien ?';

  @override
  String get safetyCheckinBody =>
      'Sans réponse de votre part dans les cinq minutes, votre cercle de sécurité sera prévenu avec votre position.';

  @override
  String get safetyAllGood => 'Oui, tout va bien';

  @override
  String get safetyCircleAlerted => 'Votre cercle a été prévenu.';

  @override
  String get safetyNoCircle =>
      'Alerte enregistrée. Ajoutez des proches pour qu\'ils soient prévenus la prochaine fois.';

  @override
  String get safetyWhoToAlert => 'Qui prévenir ?';

  @override
  String get safetyWhoToAlertBody =>
      'Ces personnes recevront votre position en direct si vous déclenchez une alerte.';

  @override
  String get safetyTitle => 'Sécurité';

  @override
  String get safetySubtitle => 'Qui est prévenu si ça tourne mal';

  @override
  String get safetyQuietAlert => 'Alerte discrète';

  @override
  String get safetyQuietAlertBody =>
      'Prévient votre cercle avec votre position. Rien ne s\'affiche à l\'écran de votre téléphone.';

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
  String get wingmanAnon => 'Votre avis reste anonyme';

  @override
  String get wingmanUnavailable => 'Demandes indisponibles';

  @override
  String get wingmanNothing => 'Rien à valider';

  @override
  String get wingmanNothingBody =>
      'Quand un ami vous demandera ce que vous pensez d\'un profil, il apparaîtra ici.';

  @override
  String wingmanAsksYou(String name) {
    return '$name demande votre avis';
  }

  @override
  String get wingmanMeh => 'Bof';

  @override
  String get wingmanWorthIt => 'Ça vaut le coup';

  @override
  String get wingmanPrivacy =>
      'Votre ami verra seulement si le groupe valide, jamais qui a répondu quoi.';

  @override
  String get marketLocationOff => 'Service de localisation désactivé.';

  @override
  String get marketGpsDenied => 'Permission GPS refusée.';

  @override
  String get marketGpsApplied => 'Localisation GPS appliquée.';

  @override
  String get marketGpsFailed => 'Impossible de récupérer votre position.';

  @override
  String get marketYourArea => 'Votre zone';

  @override
  String get marketCityOrArea => 'Ville ou quartier';

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
  String get marketTitle => 'Marketplace';

  @override
  String get marketBecomeSeller => 'Devenir vendeur vérifié';

  @override
  String get marketAddProduct => 'Ajouter un produit';

  @override
  String get marketAroundYou => 'Autour de vous';

  @override
  String get marketMyGps => 'Ma position GPS';

  @override
  String get marketPickArea => 'Choisir une zone';

  @override
  String get marketNearYou => 'Produits près de vous';

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
  String get marketSwipeCatalogue => 'Glissez pour voir tous vos produits';

  @override
  String get marketCatalogueEmpty => 'Votre catalogue est vide';

  @override
  String get marketCatalogueEmptyBody =>
      'Ajoutez votre premier produit pour commencer à vendre !';

  @override
  String get marketBoosted => 'Sponsorisé';

  @override
  String get vitrineSeeProduct => 'Voir l\'article';

  @override
  String get vitrineHint => 'Touchez l\'article pour l\'ouvrir';

  @override
  String get vitrineTitle => 'Vitrine du Marché';

  @override
  String get versesMorning => '☀️ Verset du matin';

  @override
  String get versesEvening => '🌙 Verset du soir';

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
      'Les versets arrivent même sans connexion : ils sont déjà sur votre téléphone.';

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
      'Tous vos contacts Pokou sont déjà dans ce groupe.';

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
    return 'Vous ne recevrez plus les messages de « $name ».';
  }

  @override
  String get groupLeaveAction => 'Quitter';

  @override
  String get groupNoMessage => 'Aucun message. Lancez la discussion.';

  @override
  String get groupNotEncryptedNotice =>
      'Les messages de ce groupe ne sont pas chiffrés de bout en bout : ils sont protégés pendant leur transport, mais le serveur Pokou peut les lire. Pour un échange confidentiel, écrivez en privé.';

  @override
  String get botLabel => 'Bot';

  @override
  String get botConversationNotice =>
      'Vous écrivez au bot d\'une entreprise. Ces messages ne sont pas chiffrés de bout en bout : l\'entreprise lit ce que vous lui envoyez.';

  @override
  String get groupAdminsOnly =>
      'Seuls les administrateurs peuvent publier dans les annonces.';

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
      'Vous ne recevrez plus ses annonces. Les groupes que vous avez rejoints restent les vôtres.';

  @override
  String get communityLeave => 'Quitter la communauté';

  @override
  String get communityLeaveFailed => 'Impossible de quitter la communauté.';

  @override
  String get communityOne => 'Communauté';

  @override
  String get communityUnavailable =>
      'Communauté indisponible — vérifiez votre connexion.';

  @override
  String get communityGroups => 'GROUPES';

  @override
  String get communityAnnouncements => 'Annonces · réservé aux administrateurs';

  @override
  String get communityOnlyAdminGroups =>
      'Seuls les groupes que vous administrez peuvent rejoindre une communauté.';

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
  String get channelPostHint => 'Votre annonce…';

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
  String get pollQuestion => 'Votre question';

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
      '4 à 8 chiffres. Le code ne quitte jamais cet appareil et ne peut pas être retrouvé — en cas d\'oubli, le verrou se lève en vérifiant votre numéro de téléphone.';

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
  String get lockEnterToContinue => 'Saisissez votre code pour continuer.';

  @override
  String get lockUnlock => 'Déverrouiller';

  @override
  String get lockForgotQuestion => 'Code oublié ?';

  @override
  String get lockSendFailed => 'Envoi impossible — vérifiez votre connexion.';

  @override
  String get lockRemovedToast =>
      'Verrouillage retiré. Vous pouvez choisir un nouveau code dans Profil.';

  @override
  String get lockVerifyFailed =>
      'Vérification impossible — vérifiez votre connexion.';

  @override
  String get lockLogoutQuestion => 'Se déconnecter ?';

  @override
  String get lockLogoutBody =>
      'À utiliser si vous n\'avez plus accès à ce numéro. Vos conversations restent sur le serveur, mais il faudra un numéro joignable pour vous reconnecter.';

  @override
  String get lockLogout => 'Se déconnecter';

  @override
  String get lockForgotTitle => 'Code oublié';

  @override
  String get lockNoPhoneOnDevice =>
      'Impossible de retrouver votre numéro sur cet appareil.';

  @override
  String lockEnterSentCode(String phone) {
    return 'Saisissez le code envoyé au $phone par SMS et WhatsApp.';
  }

  @override
  String lockForgotExplain(String phone) {
    return 'Le code de verrouillage n\'est stocké que sur cet appareil et ne peut pas être retrouvé. Pour lever le verrou, vérifiez votre numéro $phone.';
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
      'Couper les appels ici ne supprime que la bannière affichée quand Pokou est ouvert : un appel entrant continue de sonner en plein écran, sinon vous manqueriez des appels sans le savoir.';

  @override
  String get notifSystem => 'Système';

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
      'Cet appareil ne recevra plus de notifications tant que vous n\'ouvrirez pas Pokou à nouveau.';

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
      'Liste indisponible — vérifiez votre connexion, puis tirez pour rafraîchir.';

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
      'Les fichiers vidés sont retéléchargés à la demande quand vous rouvrez la conversation : rien n\'est perdu, seulement libéré.';

  @override
  String get storageMobileData => 'Données mobiles';

  @override
  String get storageDataSaver => 'Économie de données';

  @override
  String get storageDataSaverSub =>
      'Ne pas télécharger les médias automatiquement';

  @override
  String get storageDataSaverFootnote =>
      'Activée, les photos et vidéos reçues attendent que vous les touchiez pour se télécharger, et les photos que vous envoyez sont compressées davantage.';

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
      'Met en attente les appels et met en veilleuse les conversations non prioritaires pendant que vous êtes concentré. Vos contacts étiquetés Business, Client, Fournisseur ou Boss passent toujours.';

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
      'Cette personne ne pourra plus vous écrire ni vous appeler. Elle n\'en sera pas informée.';

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
      'Cette personne peut à nouveau vous écrire et vous appeler.';

  @override
  String get contactBlockHint =>
      'Elle ne pourra plus vous écrire ni vous appeler, sans en être informée.';

  @override
  String get adNeedTitleBody =>
      'Donnez un titre et un message à votre publicité.';

  @override
  String get adSendFailed => 'La demande n\'a pas pu être envoyée.';

  @override
  String get adCreateTitle => 'Créer une publicité';

  @override
  String get adWhoSeesTitle => 'Qui la verra';

  @override
  String get adWhoSeesBody =>
      'Tous les utilisateurs de Pokou Messenger dans l\'onglet Marché, ou entre deux statuts — à vous de choisir.';

  @override
  String get adReviewTitle => 'Une relecture avant diffusion';

  @override
  String get adReviewBody =>
      'Notre équipe lit chaque campagne avant qu\'elle ne parte. Comptez quelques heures.';

  @override
  String get adCountdownTitle => 'Le décompte part de la validation';

  @override
  String get adCountdownBody =>
      'Vos jours de diffusion commencent une fois la campagne acceptée, pas au paiement.';

  @override
  String get adRefundTitle => 'Refusée ? Vous êtes remboursé';

  @override
  String get adRefundBody =>
      'Si la campagne ne peut pas être diffusée, contactez-nous : la somme vous est rendue.';

  @override
  String get adTitleHint => 'Ex : Ciment CIMTOGO en promotion';

  @override
  String get adBodyHint => 'Ce que vous proposez, et comment vous joindre.';

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
    return 'Bonjour, je suis intéressé par votre $name à $price $currency. Est-il disponible ?';
  }

  @override
  String get productWriteFailed =>
      'Impossible d\'écrire au vendeur pour l\'instant.';

  @override
  String get productCallFirstWrite =>
      'Appel impossible — écrivez-lui d\'abord.';

  @override
  String get productRateSeller => 'Noter ce vendeur';

  @override
  String get productEditReview => 'Modifier mon avis';

  @override
  String get productReviewScope =>
      'L\'avis porte sur le VENDEUR, pas sur un produit : c\'est la confiance dans la personne qui compte, et elle reste même si l\'article quitte le catalogue.';

  @override
  String get productReviewHint => 'Votre commentaire (facultatif)';

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
  String get productReviewMine => 'Vous';

  @override
  String get verifNeedDocument =>
      'Ajoutez une photo de votre pièce d\'identité.';

  @override
  String get verifTitle => 'Devenir vendeur vérifié';

  @override
  String get verifBadgeTitle => 'Un badge bleu sur vos annonces';

  @override
  String get verifBadgeBody =>
      'Les acheteurs voient que votre identité a été vérifiée par notre équipe.';

  @override
  String get verifWhyTitle => 'Pourquoi ça change tout';

  @override
  String get verifWhyBody =>
      'Un acheteur envoie plus facilement de l\'argent Mobile Money à quelqu\'un dont l\'identité est confirmée qu\'à un inconnu.';

  @override
  String get verifNeedTitle => 'Ce qu\'il faut fournir';

  @override
  String get verifNeedBody =>
      'Une photo nette de votre carte d\'identité, passeport ou permis. Le nom doit être lisible.';

  @override
  String get verifUseTitle => 'Ce que nous en faisons';

  @override
  String get verifUseBody =>
      'Elle est lue par notre équipe pour la seule vérification, n\'apparaît jamais sur votre profil, et n\'est montrée à aucun acheteur.';

  @override
  String get verifOneYearTitle => 'Valable un an';

  @override
  String get verifOneYearBody =>
      'Le badge dure douze mois. Comptez quelques jours pour l\'examen du dossier.';

  @override
  String get verifDocumentLabel => 'Votre pièce d\'identité';

  @override
  String get verifPayCaption => 'Paiement Mobile Money · 1 an';

  @override
  String get verifChoosePhoto => 'Choisir une photo';

  @override
  String get verifChange => 'Changer';

  @override
  String get marketRemoveBody =>
      'L\'annonce disparaît du marché. Vos conversations à son sujet restent lisibles, et les acheteurs qui l\'ont déjà reçue gardent leur historique.';

  @override
  String get marketRemoveFailed => 'L\'annonce n\'a pas pu être retirée.';

  @override
  String get marketImageFailed => 'Image non envoyée — réessayez.';

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
  String get callYou => 'Vous';

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
    return '$name vous appelle';
  }

  @override
  String get callIncomingGroup => 'Appel de groupe entrant';

  @override
  String get streakSubtitle =>
      'Un jour manqué, quelques minutes pour le rattraper';

  @override
  String get streakUnavailable => 'Chaînes indisponibles';

  @override
  String get streakCheckConnection => 'Vérifiez votre connexion et réessayez.';

  @override
  String get streakEmptyTitle => 'Aucune chaîne pour le moment';

  @override
  String get streakEmptyBody =>
      'Échangez un message chaque jour avec la même personne : la chaîne démarre au premier aller-retour.';

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
  String get streakLongest => 'Votre plus longue chaîne';

  @override
  String get streakRestorePending =>
      'Votre chaîne repartira dès la confirmation du paiement.';

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
  String get leagueSubtitle => 'Votre ligue monte avec ce que vous recevez';

  @override
  String get leagueUnavailable => 'Classement indisponible';

  @override
  String get leagueRanking => 'Classement';

  @override
  String get leagueProtectPending =>
      'Votre protection sera active dès la confirmation du paiement.';

  @override
  String get leaguePaymentFailed => 'Le paiement n\'a pas pu être lancé.';

  @override
  String get leagueAtTop => 'Vous êtes au sommet du classement.';

  @override
  String leaguePointsNeeded(int points, String label) {
    return 'Encore $points points pour $label.';
  }

  @override
  String get leagueProtected =>
      'Vos points sont protégés. Rien ne baisse cette semaine.';

  @override
  String get leagueDecayNow => 'Vos points baissent au prochain passage.';

  @override
  String leagueDecayIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Vos points baissent dans $days jours sans activité.',
      one: 'Vos points baissent dans 1 jour sans activité.',
    );
    return '$_temp0';
  }

  @override
  String get leagueProtectAction => 'Protéger mes points — 500 FCFA';

  @override
  String get leagueNobodyRanked =>
      'Personne n\'est encore classé. Soyez le premier.';

  @override
  String leagueMyRank(int rank, int points) {
    return 'Vous êtes $rankᵉ avec $points points.';
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
    return 'Vous : $preview';
  }

  @override
  String contactsPreviewSender(String name, String preview) {
    return '$name : $preview';
  }

  @override
  String contactsNotInContacts(String preview) {
    return '$preview · pas dans vos contacts';
  }

  @override
  String get contactsAssistantSub => 'Votre assistant IA';

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
      'Collez le lien qu\'on vous a envoyé. Groupe ou communauté, on reconnaît lequel.';

  @override
  String get joinLinkContinue => 'Continuer';

  @override
  String get joinLinkUnreadable => 'Lien d\'invitation illisible.';

  @override
  String joinAlreadyMember(String name) {
    return 'Vous êtes déjà dans « $name ».';
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
      'Vous recevrez ses annonces. Les autres groupes restent à rejoindre un par un.';

  @override
  String get joinCommunityFailed => 'Impossible de rejoindre cette communauté.';

  @override
  String get newChatOwnNumber => 'C\'est votre propre numéro.';

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
      'Modification impossible — vérifiez votre connexion.';

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
  String get convAttachmentFailed => 'Pièce jointe non envoyée — réessayez.';

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
  String get orderBuyerWaiting => 'Cet acheteur attend votre réponse.';

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
      'Tapez un mot pour retrouver un message de cette conversation.';

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
      'Toute personne qui ouvre ce lien rejoint le groupe directement, sans autre étape. Régénérez-le pour invalider celui déjà partagé.';

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
  String get groupPickParticipants => 'Choisissez les participants';

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
  String get notifReplyHint => 'Votre message';

  @override
  String get notifMarkRead => 'Marquer comme lu';

  @override
  String get notifReplyQueued => 'envoi à l\'ouverture de Pokou';

  @override
  String get notifReplyFailed =>
      'Réponse non envoyée — ouvrez Pokou pour réessayer';

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
  String get audienceContactsDesc =>
      'Toutes les personnes de votre carnet Pokou';

  @override
  String get audienceNobodyDesc =>
      'Vos statuts ne seront visibles que par vous';

  @override
  String get audienceExceptDesc =>
      'Vos contacts, à l\'exception de ceux que vous choisissez';

  @override
  String get audienceOnlyDesc => 'Seules les personnes que vous choisissez';

  @override
  String get statusViewerFallback => 'Utilisateur';

  @override
  String get statusPrivacySaved => 'Visibilité enregistrée.';

  @override
  String get statusPrivacySaveFailed =>
      'Enregistrement impossible — vérifiez votre connexion.';

  @override
  String get statusPrivacyTitle => 'Visibilité des statuts';

  @override
  String get statusExcludePeople => 'Personnes à exclure';

  @override
  String get statusAllowedPeople => 'Personnes autorisées';

  @override
  String get statusNoContactToOffer =>
      'Aucun contact Pokou à proposer pour le moment.';

  @override
  String get statusExceptFootnote =>
      'Ces personnes ne verront pas vos statuts, même si elles sont dans vos contacts.';

  @override
  String get statusOnlyFootnote =>
      'Seules ces personnes verront vos statuts. Elles n\'ont pas besoin de vous avoir en contact.';

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
  String get statusTypeHint => 'Tapez votre statut…';

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
  String get bcastNeedName => 'Donnez un nom à cette liste.';

  @override
  String get bcastNeedRecipient => 'Choisissez au moins un destinataire.';

  @override
  String get bcastSaveFailed => 'Enregistrement impossible.';

  @override
  String get bcastNewTitle => 'Nouvelle diffusion';

  @override
  String get bcastEditTitle => 'Modifier la liste';

  @override
  String get bcastNameHint => 'Nom de la liste (visible par vous seul)';

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
      'Aucun de vos contacts n\'est encore sur Pokou Messenger.';

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
  String get bcastEmptyTitle => 'Annoncez une fois, à plusieurs';

  @override
  String get bcastEmptyBody =>
      'Chaque destinataire reçoit le message dans sa conversation privée. Il ne voit pas les autres, et vous répond à vous seul — contrairement à un groupe, où tout le monde se voit.';

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
    return 'Envoyé à $sent sur $total — $skipped ne reçoit plus vos messages.';
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
      'Chaque destinataire reçoit ce message en privé. Il ne voit pas les autres, et sa réponse vous arrive dans votre conversation avec lui.';

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
  String get channelDescriptionHint => 'Présentez votre chaîne';

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
      'Créez une chaîne pour partager vos actualités.';

  @override
  String get channelGenerateLink => 'Générer un lien';

  @override
  String get channelEditTooltip => 'Modifier';

  @override
  String get channelSearchHint => 'Rechercher une chaîne…';

  @override
  String get channelSearchPrompt =>
      'Cherchez par nom ou par description. Les chaînes certifiées apparaissent en premier.';

  @override
  String get channelSearchEmpty => 'Aucune chaîne trouvée.';

  @override
  String get channelNothingPublishedAdmin =>
      'Rien de publié pour l\'instant — touchez + pour votre première publication.';

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
      'Une communauté regroupe plusieurs groupes autour des mêmes personnes. Un groupe « Annonces » est créé avec elle : vous seul y écrivez, tous ses membres y lisent.';

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
      'Vous n\'avez pas d\'autre groupe à rattacher. Seuls les groupes que vous administrez peuvent rejoindre une communauté.';

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
  String get aiHowCanIHelp => 'Comment puis-je vous aider ?';

  @override
  String get aiAskAnything => 'Posez-moi n\'importe quelle question.';

  @override
  String get aiAskAboutData => 'Posez une question sur vos données connectées.';

  @override
  String get aiThinking => 'Baba réfléchit';

  @override
  String aiHelloIm(String name) {
    return 'Bonjour, je suis $name';
  }

  @override
  String get aiPartner => 'Votre partenaire numérique';

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
  String get aiVoiceListening => 'Je vous écoute…';

  @override
  String get aiVoiceTranscribing => 'Transcription…';

  @override
  String get aiVoiceFailed => 'Je n\'ai pas pu vous entendre. Réessayez.';

  @override
  String get aiVoiceSpeak => 'Parler à l\'assistant';

  @override
  String get aiVoiceRestart => 'Recommencer';

  @override
  String get aiVoiceSend => 'Envoyer';

  @override
  String get aiVoiceStop => 'Terminer';

  @override
  String get aiSendFailed => 'Message non envoyé — réessayez.';

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
      other: '$count signaux de vos moniteurs à consulter.',
      one: '1 signal de vos moniteurs à consulter.',
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
      other: '$count messages mis en attente pendant votre réunion.',
      one: '1 message mis en attente pendant votre réunion.',
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
      'Suppression impossible — vérifiez votre connexion.';

  @override
  String get statusPublishFailed =>
      'Publication impossible — vérifiez votre connexion et réessayez.';

  @override
  String get statusBoostAction => 'Booster ce statut · 1 000 FCFA';

  @override
  String get modulesSubtitle => 'Ajoutez ce qui vous sert, laissez le reste';

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
  String get cropHint => 'Pincez pour zoomer, glissez pour cadrer';

  @override
  String get cropConfirm => 'Valider';

  @override
  String get inviteJoinMe => 'Rejoins-moi sur Pokou Messenger';

  @override
  String inviteJoinMeNamed(String name) {
    return '$name, rejoins-moi sur Pokou Messenger';
  }

  @override
  String get otpNoCodeReceived => 'Vous n\'avez pas reçu de code ?';

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
      'Il n\'a pas pu s\'enregistrer auprès du service de notifications. Touchez pour réessayer.';

  @override
  String get devicesRetryDone =>
      'Cet appareil reçoit désormais les notifications.';

  @override
  String get devicesRetryFailed =>
      'Toujours pas d\'enregistrement possible — réessayez plus tard.';

  @override
  String get chatsProfileMissing =>
      'Profil indisponible — vérifiez votre connexion, puis réessayez.';

  @override
  String get recSlideToCancel => 'Glisser pour annuler';

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
      'Vous n\'en suivez aucune pour l\'instant. En voici quelques-unes.';

  @override
  String get channelSuggestedNone => 'Aucune chaîne à proposer pour le moment.';

  @override
  String channelFollowed(String name) {
    return 'Abonné à « $name »';
  }

  @override
  String get channelFollowFailed =>
      'Abonnement impossible — vérifiez votre connexion.';

  @override
  String get certifyTitle => 'Chaîne certifiée';

  @override
  String get certifyWhyTitle => 'Un badge, et la tête des suggestions';

  @override
  String get certifyWhyBody =>
      'Les chaînes certifiées apparaissent en premier à qui cherche quoi suivre, et le badge se voit sur chacune de vos publications.';

  @override
  String get certifyReviewTitle => 'Un examen, pas un achat';

  @override
  String get certifyReviewBody =>
      'Notre équipe lit votre chaîne avant d\'accorder le badge. Un badge qui s\'achète sans regard ne vaudrait rien — c\'est ce qui fait sa valeur.';

  @override
  String get certifyRefundTitle => 'Refusée ? Vous êtes remboursé';

  @override
  String get certifyRefundBody =>
      'Si le badge ne peut pas être accordé, contactez-nous : la somme vous est rendue.';

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
      'Votre demande part à l\'équipe dès la confirmation du paiement.';

  @override
  String get certifyFailed => 'Demande impossible — réessayez.';

  @override
  String get certifyAlready => 'Cette chaîne est certifiée';

  @override
  String get certifyTooltip => 'Faire certifier cette chaîne';

  @override
  String get chatsStartTitle => 'Commencez une conversation';

  @override
  String get chatsStartBody =>
      'Vos contacts sont déjà sur Pokou. Touchez un nom pour lui écrire.';

  @override
  String get chatsSeeAllContacts => 'Voir tous mes contacts';

  @override
  String get chatsNoNetworkTitle => 'Votre réseau n\'est pas encore sur Pokou';

  @override
  String get chatsNoNetworkBody =>
      'Invitez quelqu\'un, ou suivez une chaîne en attendant qu\'on vous réponde.';

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
      'Cette personne n\'utilise pas encore une version de Pokou qui chiffre. Vos messages voyagent en clair.';

  @override
  String get e2eeIdentityChangedTitle =>
      'Les informations de sécurité de ce contact ont changé';

  @override
  String e2eeIdentityChangedBody(String name) {
    return 'La clé de $name n\'est plus la même. Cela arrive quand quelqu\'un réinstalle Pokou ou change de téléphone — mais aussi si quelqu\'un s\'intercale. Vérifiez avec $name par un autre moyen avant de continuer.';
  }

  @override
  String get e2eeIdentityAccept => 'J\'ai vérifié, continuer';

  @override
  String get e2eeBlockedTitle => 'Message non envoyé';

  @override
  String get e2eeBlockedLookup =>
      'Impossible de récupérer la clé de chiffrement. Le message n\'a pas été envoyé — Pokou ne l\'enverra jamais en clair à votre insu.';

  @override
  String get e2eeBlockedInvalid =>
      'La clé reçue est inexploitable. Le message n\'a pas été envoyé, par précaution.';

  @override
  String get e2eeBlockedIdentity =>
      'La clé de ce contact a changé. Vérifiez son identité avant d\'envoyer.';

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
  String get adYours => 'Votre publicité';

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
  String get mediaSaved => 'Enregistré dans votre galerie';

  @override
  String get mediaExported => 'Choisissez où l\'enregistrer';

  @override
  String get mediaSavePermission =>
      'Pokou a besoin d\'accéder à vos photos pour enregistrer ce fichier.';

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
  String get stickerCreated => 'Sticker ajouté à vos stickers';

  @override
  String get stickerLimitReached => 'Votre pack personnel est plein';

  @override
  String get stickerSendFailed => 'Sticker non envoyé — réessayez';

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
  String get stickerSaved => 'Sticker ajouté à vos stickers';

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
  String get statusMineBody => 'Appuyez pour publier une actualité (24 h)';

  @override
  String get statusMineVisibility => 'Visible par mes contacts';

  @override
  String get callLeaveConference => 'Quitter la conférence';

  @override
  String get callQualityExcellent => 'Excellent';

  @override
  String get callQualityGood => 'Correct';

  @override
  String get callQualityPoor => 'Faible';

  @override
  String get callYouShort => 'Vous';

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
      'Les messages de cette conversation sont chiffrés de bout en bout : personne, pas même Pokou, ne peut les lire. Les photos, fichiers et appels le sont aussi quand vous avez tous les deux une version à jour de Pokou et que vous vous êtes déjà écrit.';

  @override
  String get chatsEncryptionFooter =>
      'Vos conversations privées sont chiffrées de bout en bout : les messages, et — avec une version à jour de Pokou des deux côtés — les photos, les fichiers et les appels dès que vous vous êtes écrit.';

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
  String get marketCatalogueNoneInFilter => 'Aucune annonce dans ce filtre.';

  @override
  String get marketStatusModerated => 'Retirée du marché';

  @override
  String get marketStatusModeratedBody =>
      'Elle n\'est plus visible par les acheteurs. Écrivez au support si vous pensez que c\'est une erreur.';

  @override
  String get callsFilterDirect => 'En tête-à-tête';

  @override
  String get profileMyAccount => 'Mon compte';

  @override
  String get profileVerifyAccount => 'Vérifier mon compte';

  @override
  String get profileVerifyAccountBody =>
      'Obtenez le badge vendeur vérifié du Marché';

  @override
  String get profileCertificationPending => 'Certification en cours';

  @override
  String get profileCertificationPendingBody =>
      'Votre demande est en cours d\'examen.';

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
  String get verifPlanLabel => 'Choisissez votre formule';

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
  String get callEventYouDeclined => 'Vous avez refusé';

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
  String get mediaCall => '📞 Appel';

  @override
  String get mediaSticker => 'Sticker';

  @override
  String get identityVerifiedAccount => 'Compte certifié';

  @override
  String get privacyTitle => 'Confidentialité';

  @override
  String get privacyIntro =>
      'Ces réglages sont appliqués par le serveur : ce que vous masquez n\'est pas envoyé aux autres, pas seulement caché dans l\'application.';

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
      'À quelle heure vous étiez connecté pour la dernière fois.';

  @override
  String get privacyOnline => 'Présence en ligne';

  @override
  String get privacyOnlineBody =>
      'Le point vert qui dit que vous êtes joignable maintenant. Indépendant de la dernière activité.';

  @override
  String get privacyProfilePhoto => 'Photo de profil';

  @override
  String get privacyProfilePhotoBody =>
      'Votre photo, partout où elle apparaît.';

  @override
  String get privacyProfileInfo => 'Informations du profil';

  @override
  String get privacyProfileInfoBody =>
      'Votre description et ce que vous avez renseigné sur vous.';

  @override
  String get privacyReadReceipts => 'Confirmations de lecture';

  @override
  String get privacyReadReceiptsBody =>
      'Les désactiver vous prive aussi de celles des autres. Les accusés de réception (une coche) restent visibles.';

  @override
  String get privacyGroupInvites => 'Qui peut m\'inviter dans un groupe';

  @override
  String get privacyGroupInvitesBody =>
      'Autoriser n\'est pas accepter : vous gardez le dernier mot sur chaque invitation.';

  @override
  String get privacyGroupMembership =>
      'Visibilité de mon appartenance aux groupes';

  @override
  String get privacyGroupMembershipBody =>
      'Qui peut voir dans quels groupes vous êtes. Les membres d\'un groupe continuent de se connaître entre eux.';

  @override
  String get privacyEveryone => 'Tout le monde';

  @override
  String get privacyMyContacts => 'Mes contacts';

  @override
  String get privacyNobody => 'Personne';

  @override
  String get privacySaveFailed => 'Réglage non enregistré — réessayez.';

  @override
  String get privacyUnavailable => 'Réglages de confidentialité indisponibles.';

  @override
  String get privacyStatusesNote =>
      'La confidentialité des statuts se règle depuis l\'onglet Actus, où vous pouvez aussi exclure des personnes précises.';

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
    return '$name vous invite';
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
      'Introuvable par la recherche. Seules les personnes à qui vous donnez le lien peuvent la rejoindre et lire ses publications. Ce choix ne pourra pas être modifié ensuite.';

  @override
  String get channelPrivateBadge => 'Privée';

  @override
  String get mahizuConnectTitle => 'Connectez votre compte Mahizu';

  @override
  String mahizuConnectBody(String phone) {
    return 'L\'assistant est un service Mahizu, distinct de Pokou. Pour l\'utiliser, rattachez votre compte Mahizu : un code sera envoyé au $phone.';
  }

  @override
  String get mahizuSendCode => 'Recevoir le code';

  @override
  String get mahizuCodeLabel => 'Code reçu';

  @override
  String get mahizuPinLabel => 'Code de votre compte Mahizu';

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
  String get koryMonthTotal => 'Mes contributions confirmées ce mois-ci';

  @override
  String get koryNoMoney =>
      'Pokou ne touche pas l\'argent : il va directement de votre wallet à celui du collecteur.';

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
      'Créez une cagnotte pour un mariage, un baptême ou une cotisation, ou rejoignez-en une avec son code.';

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
    return 'Envoyez votre contribution depuis votre wallet au $phone, puis déclarez-la ici.';
  }

  @override
  String koryPerMember(String amount, String period) {
    return '$amount par membre, $period';
  }

  @override
  String get koryDeclare => 'J\'ai contribué';

  @override
  String get koryDeclareTitle => 'Déclarer une contribution';

  @override
  String get koryAmount => 'Montant (FCFA)';

  @override
  String get koryWalletRef => 'Référence de la transaction (facultatif)';

  @override
  String get koryWalletRefHelp =>
      'Elle figure dans le SMS de votre opérateur. Seuls vous et le collecteur la voyez.';

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
    return 'Rejoignez la cagnotte « $title » sur Pokou avec le code $code.';
  }

  @override
  String get koryCreateTitle => 'Nouvelle cagnotte';

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
  String get koryNeedTitle => 'Donnez un titre (3 caractères au moins).';

  @override
  String get koryNeedAmount => 'Indiquez un montant d\'au moins 100 FCFA.';

  @override
  String get koryCollectorIsYou =>
      'Vous êtes le collecteur : les contributions arrivent sur votre wallet, et c\'est vous qui les confirmez.';

  @override
  String get koryYou => 'Vous';

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
  String get koryActionFailed => 'L\'opération n\'a pas abouti. Réessayez.';

  @override
  String get welcomePromise => 'Plus qu\'une messagerie, une communauté.';

  @override
  String get welcomeSignature => 'Ensemble, plus forts.';

  @override
  String get welcomeCreate => 'Créer un compte';

  @override
  String get welcomeSignIn => 'Se connecter';

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
  String get onbProfileTitle => 'Votre profil';

  @override
  String get onbProfileBody => 'C\'est le nom que verront vos contacts.';

  @override
  String get onbDisplayName => 'Nom affiché';

  @override
  String get onbNameRequired => 'Indiquez un nom (2 caractères au moins).';

  @override
  String get onbPhotoLater =>
      'Vous pourrez ajouter une photo plus tard, depuis votre profil.';

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
  String get onbFailed => 'L\'enregistrement n\'a pas abouti. Réessayez.';

  @override
  String get moreConsents => 'Statistiques et communications';

  @override
  String get navHonam => 'Honam';

  @override
  String get honamSubtitle => 'Pharmacies & livraison';

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
  String get honamNeedPhoto => 'Ajoutez la photo de l\'ordonnance.';

  @override
  String get honamNeedAddress => 'Indiquez l\'adresse de livraison.';

  @override
  String get honamFailed => 'L\'opération n\'a pas abouti. Réessayez.';

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
    return 'Envoyez $amount depuis votre wallet au $phone (la pharmacie), puis confirmez.';
  }

  @override
  String get honamDeclarePaid => 'J\'ai payé la pharmacie';

  @override
  String get honamPaidDeclared =>
      'Paiement signalé : la pharmacie va le confirmer.';

  @override
  String get honamPaymentNotReceived =>
      'La pharmacie n\'a pas reçu votre paiement. Vérifiez le numéro et le montant.';

  @override
  String get honamCode => 'Code de remise';

  @override
  String get honamCodeHelp =>
      'Donnez ce code au coursier, seulement quand vous avez le colis en main.';

  @override
  String get honamOriginal => 'Le coursier récupérera l\'ordonnance originale.';

  @override
  String honamRefundDue(String amount, String reason) {
    return 'La pharmacie vous doit $amount : $reason';
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
      'Terminez le paiement dans la page qui s\'ouvre.';

  @override
  String get honamCourierSuspended =>
      'Compte coursier suspendu après 3 défauts de livraison. Contactez le support pour un recours.';

  @override
  String get honamPriceNote => 'Prix hors taxes, TVA du pays en sus.';

  @override
  String get certTitle => 'Pokou certifié';

  @override
  String get certPitch =>
      'Le badge prouve que votre nom est bien le vôtre. Le mode preuve garde visibles, barrés, les messages supprimés d\'un groupe.';

  @override
  String get certHowItWorks =>
      'Votre identité est vérifiée par le nom du titulaire du wallet qui paie.';

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
      'Le nom saisi ne correspond pas à celui du titulaire du wallet qui a payé. Corrigez-le tel qu\'il figure sur sa pièce d\'identité.';

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
      'Le mode preuve est actif : le message restera visible, barré, pour tous les membres.';

  @override
  String get deletedKept => 'Message supprimé, conservé par le mode preuve';

  @override
  String get certCorrectName => 'Nom complet du titulaire';

  @override
  String get certRetryName => 'Vérifier ce nom';

  @override
  String get certStillMismatch => 'Ce nom ne correspond toujours pas.';

  @override
  String get proofExport => 'Exporter la discussion (PDF)';

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
      'Les médicaments ne se vendent pas sur Assimé : passez par Honam.';

  @override
  String get honamMissingTitle => 'Un produit manque';

  @override
  String honamMissingBody(String amount, String reason) {
    return '$amount manquent : $reason. Que préférez-vous ?';
  }

  @override
  String get honamKeepRest => 'Recevoir le reste';

  @override
  String get honamCancelAll => 'Tout annuler';

  @override
  String get honamRefundDelay =>
      'La pharmacie vous rembourse sous 2 h, sur le numéro qui a payé.';

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
      'Période de lancement : vous livrez sans adhésion ni pack.';

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
  String get honamReferralTitle => 'Parraine un coursier';

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
  String get honamTrackingShowMap => 'Voir sur la carte';

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
  String get assimeWhyTitle => 'Pourquoi je vois ça';

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
}
