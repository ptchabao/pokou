import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ru'),
  ];

  /// Nom de l'application — jamais traduit, c'est une marque.
  ///
  /// In fr, this message translates to:
  /// **'Pokou'**
  String get appName;

  /// No description provided for @actionCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get actionCancel;

  /// No description provided for @actionConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get actionConfirm;

  /// No description provided for @actionSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get actionDelete;

  /// No description provided for @actionRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get actionRetry;

  /// No description provided for @actionContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get actionContinue;

  /// No description provided for @actionClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get actionClose;

  /// No description provided for @actionShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get actionShare;

  /// No description provided for @actionSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get actionSearch;

  /// No description provided for @actionAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get actionAdd;

  /// No description provided for @actionRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get actionRemove;

  /// No description provided for @actionSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get actionSend;

  /// No description provided for @actionJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get actionJoin;

  /// No description provided for @actionCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get actionCreate;

  /// No description provided for @navChats.
  ///
  /// In fr, this message translates to:
  /// **'Discussions'**
  String get navChats;

  /// No description provided for @navStatus.
  ///
  /// In fr, this message translates to:
  /// **'Actus'**
  String get navStatus;

  /// No description provided for @navCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels'**
  String get navCalls;

  /// No description provided for @navMarket.
  ///
  /// In fr, this message translates to:
  /// **'Marché'**
  String get navMarket;

  /// No description provided for @chatsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune discussion'**
  String get chatsEmptyTitle;

  /// No description provided for @chatsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Tes discussions apparaîtront ici.'**
  String get chatsEmptyBody;

  /// No description provided for @chatsSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get chatsSearchHint;

  /// No description provided for @chatsTyping.
  ///
  /// In fr, this message translates to:
  /// **'écrit…'**
  String get chatsTyping;

  /// En groupe, on nomme qui écrit ; en 1:1 c'est inutile.
  ///
  /// In fr, this message translates to:
  /// **'{name} écrit…'**
  String chatsTypingNamed(String name);

  /// No description provided for @chatsUnknownContact.
  ///
  /// In fr, this message translates to:
  /// **'pas dans tes contacts'**
  String get chatsUnknownContact;

  /// No description provided for @chatsNoMessageYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message pour l\'instant'**
  String get chatsNoMessageYet;

  /// No description provided for @chatsYouPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Toi : {message}'**
  String chatsYouPrefix(String message);

  /// No description provided for @chatsGroupCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun groupe} =1{1 groupe} other{{count} groupes}}'**
  String chatsGroupCount(int count);

  /// No description provided for @newChatTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle discussion'**
  String get newChatTitle;

  /// No description provided for @newChatSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un contact'**
  String get newChatSearchHint;

  /// No description provided for @newChatNewGroup.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau groupe'**
  String get newChatNewGroup;

  /// No description provided for @newChatNewCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle communauté'**
  String get newChatNewCommunity;

  /// No description provided for @newChatJoinByLink.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre par lien'**
  String get newChatJoinByLink;

  /// No description provided for @newChatOnPokou.
  ///
  /// In fr, this message translates to:
  /// **'Sur Pokou Messenger'**
  String get newChatOnPokou;

  /// No description provided for @newChatInvite.
  ///
  /// In fr, this message translates to:
  /// **'Inviter sur Pokou Messenger'**
  String get newChatInvite;

  /// No description provided for @newChatNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact ne correspond.'**
  String get newChatNoMatch;

  /// No description provided for @newChatNoRegisteredContact.
  ///
  /// In fr, this message translates to:
  /// **'Aucun de tes contacts n\'utilise encore Pokou.'**
  String get newChatNoRegisteredContact;

  /// No description provided for @conversationSayHello.
  ///
  /// In fr, this message translates to:
  /// **'Dites bonjour à {name}.'**
  String conversationSayHello(String name);

  /// No description provided for @conversationMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get conversationMessageHint;

  /// No description provided for @conversationEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get conversationEdit;

  /// No description provided for @conversationForward.
  ///
  /// In fr, this message translates to:
  /// **'Transférer'**
  String get conversationForward;

  /// No description provided for @conversationReply.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get conversationReply;

  /// No description provided for @conversationEditWindowOver.
  ///
  /// In fr, this message translates to:
  /// **'Ce message ne peut plus être modifié.'**
  String get conversationEditWindowOver;

  /// No description provided for @mediaPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get mediaPhoto;

  /// No description provided for @mediaVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get mediaVideo;

  /// No description provided for @mediaVoice.
  ///
  /// In fr, this message translates to:
  /// **'Message vocal'**
  String get mediaVoice;

  /// No description provided for @mediaDocument.
  ///
  /// In fr, this message translates to:
  /// **'Document'**
  String get mediaDocument;

  /// No description provided for @mediaLocation.
  ///
  /// In fr, this message translates to:
  /// **'Position'**
  String get mediaLocation;

  /// No description provided for @offlineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get offlineTitle;

  /// No description provided for @offlineBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu verras ce qui est déjà sur ce téléphone. Le reste arrivera au retour du réseau.'**
  String get offlineBody;

  /// No description provided for @offlineNothingCached.
  ///
  /// In fr, this message translates to:
  /// **'Rien n\'est encore enregistré sur cet appareil.'**
  String get offlineNothingCached;

  /// No description provided for @offlineSending.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'envoi'**
  String get offlineSending;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifie ton réseau.'**
  String get errorNetwork;

  /// No description provided for @twoStepTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification en deux étapes'**
  String get twoStepTitle;

  /// No description provided for @twoStepBody.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte est protégé par la vérification en deux étapes. Saisis ton code PIN pour te reconnecter.'**
  String get twoStepBody;

  /// No description provided for @twoStepHint.
  ///
  /// In fr, this message translates to:
  /// **'Code du compte'**
  String get twoStepHint;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Quelque chose n\'a pas fonctionné.'**
  String get errorGeneric;

  /// No description provided for @profileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get profileLanguage;

  /// No description provided for @profileLanguageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Langue du téléphone'**
  String get profileLanguageSystem;

  /// No description provided for @profileLanguageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisis la langue de l\'application'**
  String get profileLanguageSubtitle;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In fr, this message translates to:
  /// **'Espagnol'**
  String get languageSpanish;

  /// No description provided for @languageRussian.
  ///
  /// In fr, this message translates to:
  /// **'Russe'**
  String get languageRussian;

  /// No description provided for @languageArabic.
  ///
  /// In fr, this message translates to:
  /// **'Arabe'**
  String get languageArabic;

  /// No description provided for @languageItalian.
  ///
  /// In fr, this message translates to:
  /// **'Italien'**
  String get languageItalian;

  /// No description provided for @sparkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Spark'**
  String get sparkTitle;

  /// No description provided for @sparkSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le rendez-vous d\'aujourd\'hui'**
  String get sparkSubtitle;

  /// No description provided for @sparkTabDiscover.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get sparkTabDiscover;

  /// No description provided for @sparkTabMatches.
  ///
  /// In fr, this message translates to:
  /// **'Matchs'**
  String get sparkTabMatches;

  /// No description provided for @sparkTabDates.
  ///
  /// In fr, this message translates to:
  /// **'Sorties'**
  String get sparkTabDates;

  /// No description provided for @sparkTabMe.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get sparkTabMe;

  /// No description provided for @sparkAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get sparkAddPhoto;

  /// No description provided for @sparkNoPhotoWarning.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute une photo — sans elle, presque personne ne like'**
  String get sparkNoPhotoWarning;

  /// No description provided for @sparkPhotoCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String sparkPhotoCount(int count);

  /// No description provided for @sparkLike.
  ///
  /// In fr, this message translates to:
  /// **'Liker'**
  String get sparkLike;

  /// No description provided for @sparkPass.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get sparkPass;

  /// No description provided for @sparkAgeRestricted.
  ///
  /// In fr, this message translates to:
  /// **'Spark est réservé aux 18 ans et plus.'**
  String get sparkAgeRestricted;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @authWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur Pokou'**
  String get authWelcome;

  /// No description provided for @authSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau ou déjà inscrit, c’est le même chemin : tu reçois un code par SMS.'**
  String get authSubtitle;

  /// No description provided for @authPhoneHint.
  ///
  /// In fr, this message translates to:
  /// **'Ton numéro de mobile'**
  String get authPhoneHint;

  /// No description provided for @authPrivacyNote.
  ///
  /// In fr, this message translates to:
  /// **'Connexion sécurisée. Ton numéro sert uniquement à vérifier ton identité.'**
  String get authPrivacyNote;

  /// No description provided for @authVerifyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification'**
  String get authVerifyTitle;

  /// No description provided for @authCodeSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé par SMS au {phone}'**
  String authCodeSentTo(String phone);

  /// No description provided for @authChangeNumber.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le numéro'**
  String get authChangeNumber;

  /// No description provided for @authResendIn.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code dans {time}'**
  String authResendIn(String time);

  /// No description provided for @authResendSms.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer par SMS'**
  String get authResendSms;

  /// No description provided for @authResendWhatsapp.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer via WhatsApp'**
  String get authResendWhatsapp;

  /// No description provided for @authCodeSentSms.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code envoyé par SMS.'**
  String get authCodeSentSms;

  /// No description provided for @authCodeSentWhatsapp.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code envoyé sur WhatsApp.'**
  String get authCodeSentWhatsapp;

  /// No description provided for @chatsPin.
  ///
  /// In fr, this message translates to:
  /// **'Épingler'**
  String get chatsPin;

  /// No description provided for @chatsUnpin.
  ///
  /// In fr, this message translates to:
  /// **'Désépingler'**
  String get chatsUnpin;

  /// No description provided for @chatsArchive.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get chatsArchive;

  /// No description provided for @chatsUnarchive.
  ///
  /// In fr, this message translates to:
  /// **'Désarchiver'**
  String get chatsUnarchive;

  /// No description provided for @chatsMute.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en sourdine'**
  String get chatsMute;

  /// No description provided for @chatsUnmute.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver le son'**
  String get chatsUnmute;

  /// No description provided for @chatsTag.
  ///
  /// In fr, this message translates to:
  /// **'Étiqueter'**
  String get chatsTag;

  /// No description provided for @chatsTagNamed.
  ///
  /// In fr, this message translates to:
  /// **'Étiqueter {name}'**
  String chatsTagNamed(String name);

  /// No description provided for @chatsBlock.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer'**
  String get chatsBlock;

  /// No description provided for @chatsBlockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer {name} ?'**
  String chatsBlockTitle(String name);

  /// No description provided for @chatsBlockBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne ne pourra plus t\'écrire ni t\'appeler. Elle ne sera pas prévenue.'**
  String get chatsBlockBody;

  /// No description provided for @chatsPinLimit.
  ///
  /// In fr, this message translates to:
  /// **'Trois discussions épinglées au maximum.'**
  String get chatsPinLimit;

  /// No description provided for @chatsMute8h.
  ///
  /// In fr, this message translates to:
  /// **'8 heures'**
  String get chatsMute8h;

  /// No description provided for @chatsMute1w.
  ///
  /// In fr, this message translates to:
  /// **'1 semaine'**
  String get chatsMute1w;

  /// No description provided for @chatsMuteAlways.
  ///
  /// In fr, this message translates to:
  /// **'Toujours'**
  String get chatsMuteAlways;

  /// No description provided for @chatsAddContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à mes contacts'**
  String get chatsAddContact;

  /// No description provided for @chatsActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible pour le moment.'**
  String get chatsActionFailed;

  /// No description provided for @chatsNoResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get chatsNoResult;

  /// No description provided for @chatsConnectFailed.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible.'**
  String get chatsConnectFailed;

  /// No description provided for @navModules.
  ///
  /// In fr, this message translates to:
  /// **'Modules'**
  String get navModules;

  /// No description provided for @navBroadcasts.
  ///
  /// In fr, this message translates to:
  /// **'Listes de diffusion'**
  String get navBroadcasts;

  /// No description provided for @navYou.
  ///
  /// In fr, this message translates to:
  /// **'Toi'**
  String get navYou;

  /// No description provided for @convProductFallback.
  ///
  /// In fr, this message translates to:
  /// **'Produit'**
  String get convProductFallback;

  /// No description provided for @convOrderUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Commande mise à jour'**
  String get convOrderUpdated;

  /// No description provided for @convReactionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Réaction impossible.'**
  String get convReactionFailed;

  /// No description provided for @convPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée.'**
  String get convPermissionDenied;

  /// No description provided for @convAttachDocument.
  ///
  /// In fr, this message translates to:
  /// **'Document'**
  String get convAttachDocument;

  /// No description provided for @convAttachGallery.
  ///
  /// In fr, this message translates to:
  /// **'Photo (galerie)'**
  String get convAttachGallery;

  /// No description provided for @convAttachVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo (galerie)'**
  String get convAttachVideo;

  /// No description provided for @convAttachCamera.
  ///
  /// In fr, this message translates to:
  /// **'Appareil photo'**
  String get convAttachCamera;

  /// No description provided for @convEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le message'**
  String get convEditTitle;

  /// No description provided for @convEditHint.
  ///
  /// In fr, this message translates to:
  /// **'Ton message'**
  String get convEditHint;

  /// No description provided for @convForwarded.
  ///
  /// In fr, this message translates to:
  /// **'Message transféré à {name}.'**
  String convForwarded(String name);

  /// No description provided for @convForwardFailed.
  ///
  /// In fr, this message translates to:
  /// **'Transfert impossible.'**
  String get convForwardFailed;

  /// No description provided for @convRecordVoice.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer une note vocale'**
  String get convRecordVoice;

  /// No description provided for @mediaVoiceNote.
  ///
  /// In fr, this message translates to:
  /// **'Note vocale'**
  String get mediaVoiceNote;

  /// No description provided for @mediaMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get mediaMessage;

  /// No description provided for @newChatInviteAction.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get newChatInviteAction;

  /// No description provided for @profileGallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get profileGallery;

  /// No description provided for @profileCamera.
  ///
  /// In fr, this message translates to:
  /// **'Appareil photo'**
  String get profileCamera;

  /// No description provided for @profileEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get profileEdit;

  /// No description provided for @profileFullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get profileFullName;

  /// No description provided for @profileAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get profileAbout;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour impossible.'**
  String get profileUpdateFailed;

  /// No description provided for @profileVerifiedPhone.
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée par téléphone'**
  String get profileVerifiedPhone;

  /// No description provided for @profilePrivacySecurity.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité & Sécurité'**
  String get profilePrivacySecurity;

  /// No description provided for @profileShieldMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Bouclier'**
  String get profileShieldMode;

  /// No description provided for @profileShieldOn.
  ///
  /// In fr, this message translates to:
  /// **'Mode Bouclier activé'**
  String get profileShieldOn;

  /// No description provided for @profileShieldOff.
  ///
  /// In fr, this message translates to:
  /// **'Mode Bouclier désactivé'**
  String get profileShieldOff;

  /// No description provided for @profileConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get profileConnection;

  /// No description provided for @profileEncryptedTls.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrée (TLS)'**
  String get profileEncryptedTls;

  /// No description provided for @profileStatusVisibility.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité des statuts'**
  String get profileStatusVisibility;

  /// No description provided for @commonEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get commonDisabled;

  /// No description provided for @commonLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get commonLoading;

  /// No description provided for @profileDevices.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get profileDevices;

  /// No description provided for @profileNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// No description provided for @profileStorage.
  ///
  /// In fr, this message translates to:
  /// **'Stockage et données'**
  String get profileStorage;

  /// No description provided for @profileDataSaver.
  ///
  /// In fr, this message translates to:
  /// **'Économie de données'**
  String get profileDataSaver;

  /// No description provided for @profileSystemPrefs.
  ///
  /// In fr, this message translates to:
  /// **'Préférences système'**
  String get profileSystemPrefs;

  /// No description provided for @profileSignOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get profileSignOut;

  /// No description provided for @modulesActivated.
  ///
  /// In fr, this message translates to:
  /// **'{name} est activé.'**
  String modulesActivated(String name);

  /// No description provided for @modulesUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Modules indisponibles'**
  String get modulesUnavailable;

  /// No description provided for @modulesCheckNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ta connexion et réessaie.'**
  String get modulesCheckNetwork;

  /// No description provided for @modulesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien à ajouter pour l\'instant'**
  String get modulesEmptyTitle;

  /// No description provided for @modulesEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'De nouveaux modules arriveront ici. Tu n\'as rien à faire en attendant.'**
  String get modulesEmptyBody;

  /// No description provided for @modulesMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes apps'**
  String get modulesMine;

  /// No description provided for @modulesRecommended.
  ///
  /// In fr, this message translates to:
  /// **'Recommandés'**
  String get modulesRecommended;

  /// No description provided for @modulesRecommendedBy.
  ///
  /// In fr, this message translates to:
  /// **'Choisis par notre équipe'**
  String get modulesRecommendedBy;

  /// No description provided for @modulesPopular.
  ///
  /// In fr, this message translates to:
  /// **'Populaires'**
  String get modulesPopular;

  /// No description provided for @modulesPopularSub.
  ///
  /// In fr, this message translates to:
  /// **'Les plus activés en ce moment'**
  String get modulesPopularSub;

  /// No description provided for @modulesEnable.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get modulesEnable;

  /// No description provided for @modulesDisable.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get modulesDisable;

  /// No description provided for @modulesEnableFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'activation n\'a pas pu aboutir.'**
  String get modulesEnableFailed;

  /// No description provided for @modulesComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'{name} arrive bientôt. Mets l\'application à jour pour en profiter dès sa sortie.'**
  String modulesComingSoon(String name);

  /// No description provided for @modulesUserCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 personne l\'utilise} other{{count} personnes l\'utilisent}}'**
  String modulesUserCount(int count);

  /// No description provided for @sparkEnableLocation.
  ///
  /// In fr, this message translates to:
  /// **'Active la localisation sur ton téléphone.'**
  String get sparkEnableLocation;

  /// No description provided for @sparkLocationNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Sans position, Spark ne peut pas savoir qui est autour de toi.'**
  String get sparkLocationNeeded;

  /// No description provided for @sparkLocationFailed.
  ///
  /// In fr, this message translates to:
  /// **'La position n\'a pas pu être relevée.'**
  String get sparkLocationFailed;

  /// No description provided for @sparkFeedUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Flux indisponible'**
  String get sparkFeedUnavailable;

  /// No description provided for @sparkPickIntentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisis ta carte du moment'**
  String get sparkPickIntentTitle;

  /// No description provided for @sparkPickIntentBody.
  ///
  /// In fr, this message translates to:
  /// **'Dis ce que tu cherches aujourd\'hui pour voir qui cherche la même chose.'**
  String get sparkPickIntentBody;

  /// No description provided for @sparkLocationStale.
  ///
  /// In fr, this message translates to:
  /// **'Ta position n\'est pas à jour'**
  String get sparkLocationStale;

  /// No description provided for @sparkLocationStaleBody.
  ///
  /// In fr, this message translates to:
  /// **'Spark ne montre que des gens à moins de 5 km. Sans position fraîche, il ne peut rien afficher.'**
  String get sparkLocationStaleBody;

  /// No description provided for @sparkShareLocation.
  ///
  /// In fr, this message translates to:
  /// **'Partager ma position'**
  String get sparkShareLocation;

  /// No description provided for @sparkQuotaTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu as vu tes profils du jour'**
  String get sparkQuotaTitle;

  /// No description provided for @sparkQuotaBody.
  ///
  /// In fr, this message translates to:
  /// **'Reviens demain, ou prends Spark+ pour voir sans compter.'**
  String get sparkQuotaBody;

  /// No description provided for @sparkNobodyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Personne pour l\'instant'**
  String get sparkNobodyTitle;

  /// No description provided for @sparkNobodyBody.
  ///
  /// In fr, this message translates to:
  /// **'Peu de monde cherche la même chose que toi, ici et maintenant. Réessaie plus tard — ou change de carte.'**
  String get sparkNobodyBody;

  /// No description provided for @sparkPickCard.
  ///
  /// In fr, this message translates to:
  /// **'Choisis ta carte'**
  String get sparkPickCard;

  /// No description provided for @sparkTodayLooking.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu cherches aujourd\'hui'**
  String get sparkTodayLooking;

  /// No description provided for @sparkCardExpired.
  ///
  /// In fr, this message translates to:
  /// **'Ta carte a expiré'**
  String get sparkCardExpired;

  /// No description provided for @sparkHoursLeft.
  ///
  /// In fr, this message translates to:
  /// **'Encore {hours} h'**
  String sparkHoursLeft(int hours);

  /// No description provided for @sparkMinutesLeft.
  ///
  /// In fr, this message translates to:
  /// **'Encore {minutes} min'**
  String sparkMinutesLeft(int minutes);

  /// No description provided for @sparkIntentSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui, je cherche'**
  String get sparkIntentSheetTitle;

  /// No description provided for @sparkIntentSheetBody.
  ///
  /// In fr, this message translates to:
  /// **'Ta carte expire dans 24 h. Tu ne verras que des gens qui ont choisi la même chose.'**
  String get sparkIntentSheetBody;

  /// No description provided for @sparkLikesExhausted.
  ///
  /// In fr, this message translates to:
  /// **'Tes likes du jour sont épuisés. Prends un pack dans « Moi ».'**
  String get sparkLikesExhausted;

  /// No description provided for @sparkMatchesUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Matchs indisponibles'**
  String get sparkMatchesUnavailable;

  /// No description provided for @sparkNoMatchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun match pour l\'instant'**
  String get sparkNoMatchTitle;

  /// No description provided for @sparkNoMatchBody.
  ///
  /// In fr, this message translates to:
  /// **'Quand vous vous likez tous les deux, une salle de dix minutes s\'ouvre. C\'est là que ça se joue.'**
  String get sparkNoMatchBody;

  /// No description provided for @sparkOpenRooms.
  ///
  /// In fr, this message translates to:
  /// **'Salles ouvertes'**
  String get sparkOpenRooms;

  /// No description provided for @sparkRoomsClose.
  ///
  /// In fr, this message translates to:
  /// **'Elles se referment toutes seules'**
  String get sparkRoomsClose;

  /// No description provided for @sparkMyMatches.
  ///
  /// In fr, this message translates to:
  /// **'Mes matchs'**
  String get sparkMyMatches;

  /// No description provided for @sparkNext.
  ///
  /// In fr, this message translates to:
  /// **'Suite'**
  String get sparkNext;

  /// No description provided for @sparkPhotoFailed.
  ///
  /// In fr, this message translates to:
  /// **'La photo n\'a pas pu être ajoutée.'**
  String get sparkPhotoFailed;

  /// No description provided for @sparkGoFaster.
  ///
  /// In fr, this message translates to:
  /// **'Aller plus vite'**
  String get sparkGoFaster;

  /// No description provided for @sparkNoExpiry.
  ///
  /// In fr, this message translates to:
  /// **'Sans expiration'**
  String get sparkNoExpiry;

  /// No description provided for @sparkPlusActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif — prolonge ton abonnement'**
  String get sparkPlusActive;

  /// No description provided for @sparkPlusPitch.
  ///
  /// In fr, this message translates to:
  /// **'Profils illimités, un mois'**
  String get sparkPlusPitch;

  /// No description provided for @sparkBoost.
  ///
  /// In fr, this message translates to:
  /// **'Top Profil'**
  String get sparkBoost;

  /// No description provided for @sparkBoostPitch.
  ///
  /// In fr, this message translates to:
  /// **'En tête du flux pendant une heure'**
  String get sparkBoostPitch;

  /// No description provided for @sparkAroundMe.
  ///
  /// In fr, this message translates to:
  /// **'Autour de moi'**
  String get sparkAroundMe;

  /// No description provided for @sparkSafety.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get sparkSafety;

  /// No description provided for @sparkSafetyPitch.
  ///
  /// In fr, this message translates to:
  /// **'Alerte discrète et cercle de confiance'**
  String get sparkSafetyPitch;

  /// No description provided for @sparkWingman.
  ///
  /// In fr, this message translates to:
  /// **'Avis de mes potes'**
  String get sparkWingman;

  /// No description provided for @sparkWingmanPitch.
  ///
  /// In fr, this message translates to:
  /// **'Les profils sur lesquels on te demande un avis'**
  String get sparkWingmanPitch;

  /// No description provided for @sparkUploading.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get sparkUploading;

  /// No description provided for @sparkKarma.
  ///
  /// In fr, this message translates to:
  /// **'Street Cred'**
  String get sparkKarma;

  /// No description provided for @sparkCanInvite.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux inviter'**
  String get sparkCanInvite;

  /// No description provided for @sparkCannotInvite.
  ///
  /// In fr, this message translates to:
  /// **'Trop bas pour inviter. Honore tes rendez-vous.'**
  String get sparkCannotInvite;

  /// No description provided for @sparkLikersCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une personne t\'a liké} other{{count} personnes t\'ont liké}}'**
  String sparkLikersCount(int count);

  /// No description provided for @sparkSeeWho.
  ///
  /// In fr, this message translates to:
  /// **'Voir qui'**
  String get sparkSeeWho;

  /// No description provided for @sparkFindInDiscover.
  ///
  /// In fr, this message translates to:
  /// **'Retrouve-les dans Découvrir.'**
  String get sparkFindInDiscover;

  /// No description provided for @sparkPaymentPendingLikers.
  ///
  /// In fr, this message translates to:
  /// **'La liste s\'ouvrira dès la confirmation du paiement.'**
  String get sparkPaymentPendingLikers;

  /// No description provided for @sparkPaymentPendingLikes.
  ///
  /// In fr, this message translates to:
  /// **'Tes likes arriveront dès la confirmation du paiement.'**
  String get sparkPaymentPendingLikes;

  /// No description provided for @sparkPaymentPendingPlus.
  ///
  /// In fr, this message translates to:
  /// **'Spark+ s\'activera dès la confirmation du paiement.'**
  String get sparkPaymentPendingPlus;

  /// No description provided for @sparkPaymentPendingBoost.
  ///
  /// In fr, this message translates to:
  /// **'Ton profil remontera dès la confirmation du paiement.'**
  String get sparkPaymentPendingBoost;

  /// No description provided for @sparkBirthDateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ta date de naissance'**
  String get sparkBirthDateLabel;

  /// No description provided for @sparkNameAndBirthNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Un prénom et une date de naissance, au minimum.'**
  String get sparkNameAndBirthNeeded;

  /// No description provided for @sparkProfileFailed.
  ///
  /// In fr, this message translates to:
  /// **'La fiche n\'a pas pu être créée.'**
  String get sparkProfileFailed;

  /// No description provided for @sparkCreateProfile.
  ///
  /// In fr, this message translates to:
  /// **'Crée ta fiche'**
  String get sparkCreateProfile;

  /// No description provided for @sparkStep1Title.
  ///
  /// In fr, this message translates to:
  /// **'Tu dis ce que tu cherches, aujourd\'hui'**
  String get sparkStep1Title;

  /// No description provided for @sparkStep1Body.
  ///
  /// In fr, this message translates to:
  /// **'Ta carte expire en 24 h. Tu ne vois que des gens qui cherchent la même chose, à moins de 5 km.'**
  String get sparkStep1Body;

  /// No description provided for @sparkStep2Title.
  ///
  /// In fr, this message translates to:
  /// **'Dix minutes de vocal avant d\'écrire'**
  String get sparkStep2Title;

  /// No description provided for @sparkStep2Body.
  ///
  /// In fr, this message translates to:
  /// **'Après un match, une salle s\'ouvre : vocaux et stickers seulement. Les faux profils ne passent pas cette étape.'**
  String get sparkStep2Body;

  /// No description provided for @sparkStep3Title.
  ///
  /// In fr, this message translates to:
  /// **'Tes proches savent où tu es'**
  String get sparkStep3Title;

  /// No description provided for @sparkStep3Body.
  ///
  /// In fr, this message translates to:
  /// **'Un geste discret prévient ton cercle avec ta position. On te demande aussi si tout va bien pendant le rendez-vous.'**
  String get sparkStep3Body;

  /// No description provided for @sparkSeparateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ta fiche est séparée de Pokou'**
  String get sparkSeparateTitle;

  /// No description provided for @sparkSeparateBody.
  ///
  /// In fr, this message translates to:
  /// **'Ton nom et ton numéro Pokou ne sont jamais montrés ici. Choisis ce que tu veux afficher.'**
  String get sparkSeparateBody;

  /// No description provided for @sparkDisplayName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom affiché'**
  String get sparkDisplayName;

  /// No description provided for @sparkNameExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Ama'**
  String get sparkNameExample;

  /// No description provided for @sparkBirthDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get sparkBirthDate;

  /// No description provided for @sparkBirthDateLocked.
  ///
  /// In fr, this message translates to:
  /// **'Elle ne pourra plus être modifiée ensuite.'**
  String get sparkBirthDateLocked;

  /// No description provided for @sparkChoose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get sparkChoose;

  /// No description provided for @sparkYouAre.
  ///
  /// In fr, this message translates to:
  /// **'Tu es'**
  String get sparkYouAre;

  /// No description provided for @sparkWoman.
  ///
  /// In fr, this message translates to:
  /// **'Une femme'**
  String get sparkWoman;

  /// No description provided for @sparkMan.
  ///
  /// In fr, this message translates to:
  /// **'Un homme'**
  String get sparkMan;

  /// No description provided for @sparkOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get sparkOther;

  /// No description provided for @sparkBioLabel.
  ///
  /// In fr, this message translates to:
  /// **'Deux mots sur toi (facultatif)'**
  String get sparkBioLabel;

  /// No description provided for @sparkBioHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce qu\'il faut savoir avant de te rencontrer'**
  String get sparkBioHint;

  /// No description provided for @sparkCreateAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer ma fiche'**
  String get sparkCreateAction;

  /// No description provided for @truthSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Une question payée, une réponse libre'**
  String get truthSubtitle;

  /// No description provided for @truthAsk.
  ///
  /// In fr, this message translates to:
  /// **'Poser une question'**
  String get truthAsk;

  /// No description provided for @truthForMe.
  ///
  /// In fr, this message translates to:
  /// **'Pour moi'**
  String get truthForMe;

  /// No description provided for @truthMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes questions'**
  String get truthMine;

  /// No description provided for @truthUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Questions indisponibles'**
  String get truthUnavailable;

  /// No description provided for @truthEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune question pour le moment'**
  String get truthEmptyTitle;

  /// No description provided for @truthEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Quand quelqu\'un paiera pour te poser une question, elle apparaîtra ici. Tu resteras libre de refuser.'**
  String get truthEmptyBody;

  /// No description provided for @truthYourAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Ta réponse'**
  String get truthYourAnswer;

  /// No description provided for @truthAnswerPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Elle ne va qu\'à la personne qui a payé. Pokou ne la republie nulle part.'**
  String get truthAnswerPrivacy;

  /// No description provided for @truthWhatToSay.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu veux dire'**
  String get truthWhatToSay;

  /// No description provided for @truthSendAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ma réponse'**
  String get truthSendAnswer;

  /// No description provided for @truthAskedAnon.
  ///
  /// In fr, this message translates to:
  /// **'Demandé anonymement'**
  String get truthAskedAnon;

  /// No description provided for @truthDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get truthDecline;

  /// No description provided for @truthAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get truthAnswer;

  /// No description provided for @truthDeclineFree.
  ///
  /// In fr, this message translates to:
  /// **'Refuser ne te coûte rien. Tu n\'es payé qu\'en répondant.'**
  String get truthDeclineFree;

  /// No description provided for @truthHistoryUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Historique indisponible'**
  String get truthHistoryUnavailable;

  /// No description provided for @truthNothingAsked.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'as encore rien demandé'**
  String get truthNothingAsked;

  /// No description provided for @truthNothingAskedBody.
  ///
  /// In fr, this message translates to:
  /// **'Pose une question à quelqu\'un : il verra le montant et la question, jamais ton nom.'**
  String get truthNothingAskedBody;

  /// No description provided for @truthAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Répondu'**
  String get truthAnswered;

  /// No description provided for @truthDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get truthDeclined;

  /// No description provided for @truthPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get truthPending;

  /// No description provided for @truthToSomeone.
  ///
  /// In fr, this message translates to:
  /// **'À {name}'**
  String truthToSomeone(String name);

  /// No description provided for @truthSomeone.
  ///
  /// In fr, this message translates to:
  /// **'quelqu\'un'**
  String get truthSomeone;

  /// No description provided for @truthPreferredNot.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne a préféré ne pas répondre.'**
  String get truthPreferredNot;

  /// No description provided for @truthAwaitingAnswer.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'une réponse.'**
  String get truthAwaitingAnswer;

  /// No description provided for @truthToWhom.
  ///
  /// In fr, this message translates to:
  /// **'À qui ?'**
  String get truthToWhom;

  /// No description provided for @truthQuestionTo.
  ///
  /// In fr, this message translates to:
  /// **'Une question à {name}'**
  String truthQuestionTo(String name);

  /// No description provided for @truthAnonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton nom n\'est pas montré'**
  String get truthAnonTitle;

  /// No description provided for @truthAnonBody.
  ///
  /// In fr, this message translates to:
  /// **'La personne voit le montant et la question, jamais qui les a envoyés.'**
  String get truthAnonBody;

  /// No description provided for @truthFreeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Elle reste libre de refuser'**
  String get truthFreeTitle;

  /// No description provided for @truthFreeBody.
  ///
  /// In fr, this message translates to:
  /// **'Refuser ne lui rapporte rien : elle n\'est payée qu\'en répondant.'**
  String get truthFreeBody;

  /// No description provided for @truthPrivateTitle.
  ///
  /// In fr, this message translates to:
  /// **'La réponse ne va qu\'à toi'**
  String get truthPrivateTitle;

  /// No description provided for @truthPrivateBody.
  ///
  /// In fr, this message translates to:
  /// **'Pokou ne la republie nulle part, et elle expire au bout de sept jours sans réponse.'**
  String get truthPrivateBody;

  /// No description provided for @truthYourQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Ta question'**
  String get truthYourQuestion;

  /// No description provided for @truthQuestionHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu aimerais vraiment savoir'**
  String get truthQuestionHint;

  /// No description provided for @truthHowMuch.
  ///
  /// In fr, this message translates to:
  /// **'Combien tu proposes'**
  String get truthHowMuch;

  /// No description provided for @truthAskForAmount.
  ///
  /// In fr, this message translates to:
  /// **'Poser la question — {amount} FCFA'**
  String truthAskForAmount(int amount);

  /// No description provided for @truthWriteFirst.
  ///
  /// In fr, this message translates to:
  /// **'Écris d\'abord ta question.'**
  String get truthWriteFirst;

  /// No description provided for @truthPaymentPending.
  ///
  /// In fr, this message translates to:
  /// **'Ta question partira dès la confirmation du paiement.'**
  String get truthPaymentPending;

  /// No description provided for @hypeFinished.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get hypeFinished;

  /// No description provided for @hypeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un objectif, toute la salle'**
  String get hypeSubtitle;

  /// No description provided for @hypeLaunch.
  ///
  /// In fr, this message translates to:
  /// **'Lancer un objectif'**
  String get hypeLaunch;

  /// No description provided for @hypeOngoing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get hypeOngoing;

  /// No description provided for @hypeMine.
  ///
  /// In fr, this message translates to:
  /// **'Les miens'**
  String get hypeMine;

  /// No description provided for @hypeNoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun objectif en cours'**
  String get hypeNoneTitle;

  /// No description provided for @hypeNoneBody.
  ///
  /// In fr, this message translates to:
  /// **'Quand un créateur lance un objectif, il apparaît ici jusqu\'à ce que le palier tombe.'**
  String get hypeNoneBody;

  /// No description provided for @hypeMineEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Rien pour le moment'**
  String get hypeMineEmpty;

  /// No description provided for @hypeMineEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Tes objectifs et ceux que tu as soutenus apparaîtront ici.'**
  String get hypeMineEmptyBody;

  /// No description provided for @hypeUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Objectifs indisponibles'**
  String get hypeUnavailable;

  /// No description provided for @hypeCreator.
  ///
  /// In fr, this message translates to:
  /// **'Créateur'**
  String get hypeCreator;

  /// No description provided for @hypeTierReached.
  ///
  /// In fr, this message translates to:
  /// **'Palier atteint'**
  String get hypeTierReached;

  /// No description provided for @hypeGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif'**
  String get hypeGoal;

  /// No description provided for @hypeNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Objectif introuvable'**
  String get hypeNotFound;

  /// No description provided for @hypeMaybeRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Il a peut-être été retiré.'**
  String get hypeMaybeRemoved;

  /// No description provided for @hypeUnlocked.
  ///
  /// In fr, this message translates to:
  /// **'Le palier est tombé. La promesse est débloquée.'**
  String get hypeUnlocked;

  /// No description provided for @hypeContribute.
  ///
  /// In fr, this message translates to:
  /// **'Faire avancer la barre'**
  String get hypeContribute;

  /// No description provided for @hypePushers.
  ///
  /// In fr, this message translates to:
  /// **'Ceux qui poussent'**
  String get hypePushers;

  /// No description provided for @hypeBeFirst.
  ///
  /// In fr, this message translates to:
  /// **'Personne encore. Sois le premier.'**
  String get hypeBeFirst;

  /// No description provided for @hypeContributor.
  ///
  /// In fr, this message translates to:
  /// **'Contributeur'**
  String get hypeContributor;

  /// No description provided for @commonDueToYou.
  ///
  /// In fr, this message translates to:
  /// **'Te revient : {amount} FCFA'**
  String commonDueToYou(int amount);

  /// No description provided for @commonManualPayout.
  ///
  /// In fr, this message translates to:
  /// **'Le versement se fait par l\'équipe Pokou, sur demande.'**
  String get commonManualPayout;

  /// No description provided for @hypeStepTogetherTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde pousse ensemble'**
  String get hypeStepTogetherTitle;

  /// No description provided for @hypeStepTogetherBody.
  ///
  /// In fr, this message translates to:
  /// **'Chaque participation fait monter la barre, et tout le monde voit le palier tomber en même temps.'**
  String get hypeStepTogetherBody;

  /// No description provided for @hypeStepPromiseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu promets'**
  String get hypeStepPromiseTitle;

  /// No description provided for @hypeStepPromiseBody.
  ///
  /// In fr, this message translates to:
  /// **'Visible avant que quiconque ne paie. C\'est ton engagement si l\'objectif est atteint.'**
  String get hypeStepPromiseBody;

  /// No description provided for @hypeStepOneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un seul objectif à la fois'**
  String get hypeStepOneTitle;

  /// No description provided for @hypeStepOneBody.
  ///
  /// In fr, this message translates to:
  /// **'Deux objectifs simultanés mettraient tes contributeurs en concurrence avec eux-mêmes.'**
  String get hypeStepOneBody;

  /// No description provided for @commonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get commonTitle;

  /// No description provided for @hypeTitleExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex : 100 000 et je chante'**
  String get hypeTitleExample;

  /// No description provided for @hypePromiseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu débloques si l\'objectif tombe'**
  String get hypePromiseLabel;

  /// No description provided for @hypePromiseHint.
  ///
  /// In fr, this message translates to:
  /// **'Sois précis : c\'est ce que tes contributeurs achètent.'**
  String get hypePromiseHint;

  /// No description provided for @hypeGoalAmount.
  ///
  /// In fr, this message translates to:
  /// **'Objectif en FCFA'**
  String get hypeGoalAmount;

  /// No description provided for @commonDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get commonDuration;

  /// No description provided for @hypeLaunchAction.
  ///
  /// In fr, this message translates to:
  /// **'Lancer'**
  String get hypeLaunchAction;

  /// No description provided for @hypeFieldsNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Titre, promesse et objectif sont nécessaires.'**
  String get hypeFieldsNeeded;

  /// No description provided for @hypeAlreadyRunning.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà un objectif en cours.'**
  String get hypeAlreadyRunning;

  /// No description provided for @hypeContributeNote.
  ///
  /// In fr, this message translates to:
  /// **'Ta participation fait avancer la barre et débloque un contenu. Elle n\'est pas remboursable.'**
  String get hypeContributeNote;

  /// No description provided for @commonAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get commonAmount;

  /// No description provided for @hypeJoinForAmount.
  ///
  /// In fr, this message translates to:
  /// **'Participer — {amount} FCFA'**
  String hypeJoinForAmount(int amount);

  /// No description provided for @hypePaymentPending.
  ///
  /// In fr, this message translates to:
  /// **'La barre avancera dès la confirmation du paiement.'**
  String get hypePaymentPending;

  /// No description provided for @ceremonyWedding.
  ///
  /// In fr, this message translates to:
  /// **'Mariage'**
  String get ceremonyWedding;

  /// No description provided for @ceremonyBaptism.
  ///
  /// In fr, this message translates to:
  /// **'Baptême'**
  String get ceremonyBaptism;

  /// No description provided for @ceremonyFuneral.
  ///
  /// In fr, this message translates to:
  /// **'Deuil'**
  String get ceremonyFuneral;

  /// No description provided for @ceremonyOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get ceremonyOther;

  /// No description provided for @ceremonyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Cagnottes'**
  String get ceremonyTitle;

  /// No description provided for @ceremonySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les cotisations, sans les relances'**
  String get ceremonySubtitle;

  /// No description provided for @ceremonyNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle cagnotte'**
  String get ceremonyNew;

  /// No description provided for @ceremonyUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Cagnottes indisponibles'**
  String get ceremonyUnavailable;

  /// No description provided for @ceremonyNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune cagnotte'**
  String get ceremonyNone;

  /// No description provided for @ceremonyNoneBody.
  ///
  /// In fr, this message translates to:
  /// **'Mariage, baptême, deuil : crée la cagnotte, invite, et chacun contribue comme il peut.'**
  String get ceremonyNoneBody;

  /// No description provided for @ceremonyGoalHint.
  ///
  /// In fr, this message translates to:
  /// **'Objectif indicatif : {amount} FCFA'**
  String ceremonyGoalHint(int amount);

  /// No description provided for @ceremonyOne.
  ///
  /// In fr, this message translates to:
  /// **'Cagnotte'**
  String get ceremonyOne;

  /// No description provided for @ceremonyNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Cagnotte introuvable'**
  String get ceremonyNotFound;

  /// No description provided for @ceremonyMaybeClosed.
  ///
  /// In fr, this message translates to:
  /// **'Elle a peut-être été clôturée.'**
  String get ceremonyMaybeClosed;

  /// No description provided for @ceremonyJoin.
  ///
  /// In fr, this message translates to:
  /// **'Participer'**
  String get ceremonyJoin;

  /// No description provided for @ceremonyClose.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer la cagnotte'**
  String get ceremonyClose;

  /// No description provided for @ceremonyContributions.
  ///
  /// In fr, this message translates to:
  /// **'Participations'**
  String get ceremonyContributions;

  /// No description provided for @ceremonyNobodyYet.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'a encore participé.'**
  String get ceremonyNobodyYet;

  /// No description provided for @ceremonyAnonGift.
  ///
  /// In fr, this message translates to:
  /// **'Participation anonyme'**
  String get ceremonyAnonGift;

  /// No description provided for @ceremonyContributor.
  ///
  /// In fr, this message translates to:
  /// **'Contributeur'**
  String get ceremonyContributor;

  /// No description provided for @ceremonyCollected.
  ///
  /// In fr, this message translates to:
  /// **'collectés'**
  String get ceremonyCollected;

  /// No description provided for @ceremonyYouOrganize.
  ///
  /// In fr, this message translates to:
  /// **'tu organises'**
  String get ceremonyYouOrganize;

  /// No description provided for @ceremonyNewSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu suis les participations. Pokou n\'envoie aucune relance à ceux qui n\'ont pas donné.'**
  String get ceremonyNewSubtitle;

  /// No description provided for @ceremonyOccasion.
  ///
  /// In fr, this message translates to:
  /// **'Occasion'**
  String get ceremonyOccasion;

  /// No description provided for @ceremonyTitleExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Mariage de Kossi et Ama'**
  String get ceremonyTitleExample;

  /// No description provided for @ceremonyFewWords.
  ///
  /// In fr, this message translates to:
  /// **'Quelques mots (facultatif)'**
  String get ceremonyFewWords;

  /// No description provided for @ceremonyFewWordsHint.
  ///
  /// In fr, this message translates to:
  /// **'La date, le lieu, à quoi servira l\'argent.'**
  String get ceremonyFewWordsHint;

  /// No description provided for @ceremonyGoalOptional.
  ///
  /// In fr, this message translates to:
  /// **'Objectif en FCFA (facultatif)'**
  String get ceremonyGoalOptional;

  /// No description provided for @ceremonyGoalNote.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif : la cagnotte continue d\'accepter au-delà.'**
  String get ceremonyGoalNote;

  /// No description provided for @ceremonyCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer la cagnotte'**
  String get ceremonyCreate;

  /// No description provided for @ceremonyNeedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Donne un titre à la cagnotte.'**
  String get ceremonyNeedTitle;

  /// No description provided for @ceremonyJoinTo.
  ///
  /// In fr, this message translates to:
  /// **'Participer — {title}'**
  String ceremonyJoinTo(String title);

  /// No description provided for @ceremonyOtherAmount.
  ///
  /// In fr, this message translates to:
  /// **'Ou un autre montant'**
  String get ceremonyOtherAmount;

  /// No description provided for @ceremonyWordOptional.
  ///
  /// In fr, this message translates to:
  /// **'Un mot (facultatif)'**
  String get ceremonyWordOptional;

  /// No description provided for @ceremonyWordHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu veux leur dire'**
  String get ceremonyWordHint;

  /// No description provided for @ceremonyAnonToggle.
  ///
  /// In fr, this message translates to:
  /// **'Participer anonymement'**
  String get ceremonyAnonToggle;

  /// No description provided for @ceremonyAnonNote.
  ///
  /// In fr, this message translates to:
  /// **'Ton nom sera masqué. Le montant reste dans le total.'**
  String get ceremonyAnonNote;

  /// No description provided for @ceremonyJoinAmount.
  ///
  /// In fr, this message translates to:
  /// **'Participer — {amount} FCFA'**
  String ceremonyJoinAmount(int amount);

  /// No description provided for @ceremonyMinimum.
  ///
  /// In fr, this message translates to:
  /// **'Le minimum est de 100 FCFA.'**
  String get ceremonyMinimum;

  /// No description provided for @ceremonyPaymentPending.
  ///
  /// In fr, this message translates to:
  /// **'Ta participation apparaîtra dès la confirmation du paiement.'**
  String get ceremonyPaymentPending;

  /// No description provided for @vipSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Tes abonnés, ton espace'**
  String get vipSubtitle;

  /// No description provided for @vipDiscover.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get vipDiscover;

  /// No description provided for @vipMySubs.
  ///
  /// In fr, this message translates to:
  /// **'Mes abonnements'**
  String get vipMySubs;

  /// No description provided for @vipMyRoom.
  ///
  /// In fr, this message translates to:
  /// **'Mon salon'**
  String get vipMyRoom;

  /// No description provided for @vipNoRoomOpen.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon ouvert'**
  String get vipNoRoomOpen;

  /// No description provided for @vipNoRoomOpenBody.
  ///
  /// In fr, this message translates to:
  /// **'Les salons que des créateurs ouvrent apparaîtront ici.'**
  String get vipNoRoomOpenBody;

  /// No description provided for @vipNoSub.
  ///
  /// In fr, this message translates to:
  /// **'Aucun abonnement'**
  String get vipNoSub;

  /// No description provided for @vipNoSubBody.
  ///
  /// In fr, this message translates to:
  /// **'Abonne-toi à un salon pour retrouver ici tout ce que son créateur publie.'**
  String get vipNoSubBody;

  /// No description provided for @vipUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Salons indisponibles'**
  String get vipUnavailable;

  /// No description provided for @vipCreator.
  ///
  /// In fr, this message translates to:
  /// **'Créateur'**
  String get vipCreator;

  /// No description provided for @vipUntil.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au {date}'**
  String vipUntil(String date);

  /// No description provided for @vipPaymentPending.
  ///
  /// In fr, this message translates to:
  /// **'Le salon s\'ouvrira dès la confirmation du paiement.'**
  String get vipPaymentPending;

  /// No description provided for @vipRoom.
  ///
  /// In fr, this message translates to:
  /// **'Salon'**
  String get vipRoom;

  /// No description provided for @vipNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Salon introuvable'**
  String get vipNotFound;

  /// No description provided for @vipMaybeClosed.
  ///
  /// In fr, this message translates to:
  /// **'Il a peut-être été fermé.'**
  String get vipMaybeClosed;

  /// No description provided for @vipStepAllTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tout ce qui est publié ici'**
  String get vipStepAllTitle;

  /// No description provided for @vipStepAllBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu vois immédiatement les publications déjà en ligne, et celles qui suivront.'**
  String get vipStepAllBody;

  /// No description provided for @vipStepDaysTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trente jours'**
  String get vipStepDaysTitle;

  /// No description provided for @vipStepDaysBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès s\'arrête tout seul au terme. Rien ne continue sans que tu le décides.'**
  String get vipStepDaysBody;

  /// No description provided for @vipStepNoRenewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune reconduction automatique'**
  String get vipStepNoRenewTitle;

  /// No description provided for @vipStepNoRenewBody.
  ///
  /// In fr, this message translates to:
  /// **'Pokou ne conserve pas ton moyen de paiement. Pour continuer, tu repaies, une fois.'**
  String get vipStepNoRenewBody;

  /// No description provided for @vipSubscribeFor.
  ///
  /// In fr, this message translates to:
  /// **'S\'abonner — {amount} FCFA'**
  String vipSubscribeFor(int amount);

  /// No description provided for @vipLockedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contenu réservé aux abonnés'**
  String get vipLockedTitle;

  /// No description provided for @vipLockedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le reste du salon s\'ouvre dès la confirmation du paiement.'**
  String get vipLockedBody;

  /// No description provided for @vipNothingYet.
  ///
  /// In fr, this message translates to:
  /// **'Rien encore'**
  String get vipNothingYet;

  /// No description provided for @vipNothingYetBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce salon n\'a pas encore de publication.'**
  String get vipNothingYetBody;

  /// No description provided for @vipPosts.
  ///
  /// In fr, this message translates to:
  /// **'Publications'**
  String get vipPosts;

  /// No description provided for @vipRoomUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Salon indisponible'**
  String get vipRoomUnavailable;

  /// No description provided for @vipOpenYourRoom.
  ///
  /// In fr, this message translates to:
  /// **'Ouvre ton salon'**
  String get vipOpenYourRoom;

  /// No description provided for @vipOpenYourRoomBody.
  ///
  /// In fr, this message translates to:
  /// **'Tes abonnés paient une fois pour trente jours et voient tout ce que tu publies ici. Tu fixes le prix.'**
  String get vipOpenYourRoomBody;

  /// No description provided for @vipOpenAction.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir mon salon'**
  String get vipOpenAction;

  /// No description provided for @vipPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get vipPublish;

  /// No description provided for @vipSeeMyRoom.
  ///
  /// In fr, this message translates to:
  /// **'Voir mon salon'**
  String get vipSeeMyRoom;

  /// No description provided for @vipOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get vipOpen;

  /// No description provided for @vipClosed.
  ///
  /// In fr, this message translates to:
  /// **'Fermé'**
  String get vipClosed;

  /// No description provided for @vipEarnings.
  ///
  /// In fr, this message translates to:
  /// **'Tes revenus'**
  String get vipEarnings;

  /// No description provided for @vipCollected.
  ///
  /// In fr, this message translates to:
  /// **'{amount} FCFA collectés'**
  String vipCollected(int amount);

  /// No description provided for @vipDueNote.
  ///
  /// In fr, this message translates to:
  /// **'Montant qui te revient. Le versement se fait par l\'équipe Pokou, sur demande.'**
  String get vipDueNote;

  /// No description provided for @vipEditRoom.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon salon'**
  String get vipEditRoom;

  /// No description provided for @vipPriceNote.
  ///
  /// In fr, this message translates to:
  /// **'Un nouveau prix ne s\'applique qu\'aux abonnements suivants : chacun a payé le sien d\'avance.'**
  String get vipPriceNote;

  /// No description provided for @vipRoomName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du salon'**
  String get vipRoomName;

  /// No description provided for @vipRoomNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Les coulisses'**
  String get vipRoomNameHint;

  /// No description provided for @vipPitchLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tes abonnés y trouveront'**
  String get vipPitchLabel;

  /// No description provided for @vipPitchNote.
  ///
  /// In fr, this message translates to:
  /// **'Visible avant de payer — c\'est ce qui donne envie de s\'abonner.'**
  String get vipPitchNote;

  /// No description provided for @vipPitchHint.
  ///
  /// In fr, this message translates to:
  /// **'Des photos, des annonces, des messages vocaux…'**
  String get vipPitchHint;

  /// No description provided for @vipMonthlyPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix mensuel en FCFA'**
  String get vipMonthlyPrice;

  /// No description provided for @vipAcceptNew.
  ///
  /// In fr, this message translates to:
  /// **'Accepter de nouveaux abonnés'**
  String get vipAcceptNew;

  /// No description provided for @vipAcceptNewNote.
  ///
  /// In fr, this message translates to:
  /// **'Tes abonnés actuels gardent leur accès jusqu\'au terme.'**
  String get vipAcceptNewNote;

  /// No description provided for @vipFieldsNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Nom, description et prix sont nécessaires.'**
  String get vipFieldsNeeded;

  /// No description provided for @vipPublishTitle.
  ///
  /// In fr, this message translates to:
  /// **'Publier dans mon salon'**
  String get vipPublishTitle;

  /// No description provided for @vipPublishNote.
  ///
  /// In fr, this message translates to:
  /// **'Visible uniquement par tes abonnés en cours.'**
  String get vipPublishNote;

  /// No description provided for @vipYourMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ton message'**
  String get vipYourMessage;

  /// No description provided for @vipShareHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu veux partager'**
  String get vipShareHint;

  /// No description provided for @vipEarningsSummary.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 abonnement} other{{count} abonnements}} • {amount} FCFA collectés'**
  String vipEarningsSummary(int count, int amount);

  /// No description provided for @datesUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Sorties indisponibles'**
  String get datesUnavailable;

  /// No description provided for @datesNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sortie prévue'**
  String get datesNone;

  /// No description provided for @datesNoneBody.
  ///
  /// In fr, this message translates to:
  /// **'Une fois la salle passée, propose un endroit. Tu paies d\'avance, et l\'argent n\'est versé qu\'une fois que vous confirmez tous les deux.'**
  String get datesNoneBody;

  /// No description provided for @datesNotNow.
  ///
  /// In fr, this message translates to:
  /// **'Ce n\'est pas le moment pour ce geste.'**
  String get datesNotNow;

  /// No description provided for @datesCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la sortie ?'**
  String get datesCancelTitle;

  /// No description provided for @datesCancelFree.
  ///
  /// In fr, this message translates to:
  /// **'Tu es à plus de 24 h : tu seras intégralement remboursé.'**
  String get datesCancelFree;

  /// No description provided for @datesCancelLate.
  ///
  /// In fr, this message translates to:
  /// **'Il reste moins de 24 h. L\'établissement a déjà réservé, ton paiement lui reste acquis.'**
  String get datesCancelLate;

  /// No description provided for @datesKeep.
  ///
  /// In fr, this message translates to:
  /// **'Garder'**
  String get datesKeep;

  /// No description provided for @datesCancelAction.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la sortie'**
  String get datesCancelAction;

  /// No description provided for @datesAwaitingPayment.
  ///
  /// In fr, this message translates to:
  /// **'En attente de paiement'**
  String get datesAwaitingPayment;

  /// No description provided for @datesPaidToConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Payé — à confirmer'**
  String get datesPaidToConfirm;

  /// No description provided for @datesDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get datesDone;

  /// No description provided for @datesRefunded.
  ///
  /// In fr, this message translates to:
  /// **'Remboursé'**
  String get datesRefunded;

  /// No description provided for @datesNoShow.
  ///
  /// In fr, this message translates to:
  /// **'Lapin signalé'**
  String get datesNoShow;

  /// No description provided for @datesCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get datesCancelled;

  /// No description provided for @datesOne.
  ///
  /// In fr, this message translates to:
  /// **'Sortie'**
  String get datesOne;

  /// No description provided for @datesWithPeer.
  ///
  /// In fr, this message translates to:
  /// **'{venue} • avec {name}'**
  String datesWithPeer(String venue, String name);

  /// No description provided for @datesYourMatch.
  ///
  /// In fr, this message translates to:
  /// **'ton match'**
  String get datesYourMatch;

  /// No description provided for @datesWentWell.
  ///
  /// In fr, this message translates to:
  /// **'Ça s\'est bien passé'**
  String get datesWentWell;

  /// No description provided for @datesYouConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Tu as confirmé. On attend la confirmation de l\'autre.'**
  String get datesYouConfirmed;

  /// No description provided for @datesNoShowAction.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'est pas venu'**
  String get datesNoShowAction;

  /// No description provided for @datesVoucher.
  ///
  /// In fr, this message translates to:
  /// **'Ton bon, à donner sur place'**
  String get datesVoucher;

  /// No description provided for @datesPickBoth.
  ///
  /// In fr, this message translates to:
  /// **'Choisis une formule et un moment.'**
  String get datesPickBoth;

  /// No description provided for @datesVoucherPending.
  ///
  /// In fr, this message translates to:
  /// **'Ton bon sera émis dès la confirmation du paiement.'**
  String get datesVoucherPending;

  /// No description provided for @datesBookingFailed.
  ///
  /// In fr, this message translates to:
  /// **'La réservation n\'a pas abouti.'**
  String get datesBookingFailed;

  /// No description provided for @datesWhereTo.
  ///
  /// In fr, this message translates to:
  /// **'Où allez-vous ?'**
  String get datesWhereTo;

  /// No description provided for @datesStepPayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu paies d\'avance, rien n\'est versé'**
  String get datesStepPayTitle;

  /// No description provided for @datesStepPayBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'argent est bloqué. Il ne part chez l\'établissement que si vous confirmez tous les deux.'**
  String get datesStepPayBody;

  /// No description provided for @datesStepCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annulation libre à plus de 24 h'**
  String get datesStepCancelTitle;

  /// No description provided for @datesStepCancelBody.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement intégral. En deçà, l\'établissement a déjà réservé et garde ton paiement.'**
  String get datesStepCancelBody;

  /// No description provided for @datesStepNoShowTitle.
  ///
  /// In fr, this message translates to:
  /// **'Si l\'autre ne vient pas'**
  String get datesStepNoShowTitle;

  /// No description provided for @datesStepNoShowBody.
  ///
  /// In fr, this message translates to:
  /// **'La moitié te revient. L\'application ne prend rien sur un rendez-vous manqué.'**
  String get datesStepNoShowBody;

  /// No description provided for @datesThePackage.
  ///
  /// In fr, this message translates to:
  /// **'La formule'**
  String get datesThePackage;

  /// No description provided for @datesPacksUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Les formules ne sont pas disponibles pour le moment.'**
  String get datesPacksUnavailable;

  /// No description provided for @datesNoPackNearby.
  ///
  /// In fr, this message translates to:
  /// **'Aucune formule n\'est proposée près de chez toi pour l\'instant.'**
  String get datesNoPackNearby;

  /// No description provided for @datesWhen.
  ///
  /// In fr, this message translates to:
  /// **'Quand ?'**
  String get datesWhen;

  /// No description provided for @datesPickWhen.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la date et l\'heure'**
  String get datesPickWhen;

  /// No description provided for @datesBook.
  ///
  /// In fr, this message translates to:
  /// **'Réserver'**
  String get datesBook;

  /// No description provided for @datesBookAmount.
  ///
  /// In fr, this message translates to:
  /// **'Réserver — {amount} FCFA'**
  String datesBookAmount(int amount);

  /// No description provided for @roomNeedMic.
  ///
  /// In fr, this message translates to:
  /// **'Sans micro, il n\'y a que les stickers — la salle est vocale.'**
  String get roomNeedMic;

  /// No description provided for @roomVoiceFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le vocal n\'est pas parti.'**
  String get roomVoiceFailed;

  /// No description provided for @roomBothYes.
  ///
  /// In fr, this message translates to:
  /// **'C\'est parti. Tu peux maintenant proposer une sortie.'**
  String get roomBothYes;

  /// No description provided for @roomWaitingOther.
  ///
  /// In fr, this message translates to:
  /// **'C\'est noté. On attend sa réponse avant la fin du compte à rebours.'**
  String get roomWaitingOther;

  /// No description provided for @roomExtendPending.
  ///
  /// In fr, this message translates to:
  /// **'Dix minutes de plus dès la confirmation du paiement.'**
  String get roomExtendPending;

  /// No description provided for @roomTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salle d\'entrée'**
  String get roomTitle;

  /// No description provided for @roomNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Salle introuvable'**
  String get roomNotFound;

  /// No description provided for @roomMaybeClosed.
  ///
  /// In fr, this message translates to:
  /// **'Elle s\'est peut-être refermée.'**
  String get roomMaybeClosed;

  /// No description provided for @roomVoiceOnly.
  ///
  /// In fr, this message translates to:
  /// **'Vocaux et stickers seulement'**
  String get roomVoiceOnly;

  /// No description provided for @roomTimeUp.
  ///
  /// In fr, this message translates to:
  /// **'Le temps est écoulé.'**
  String get roomTimeUp;

  /// No description provided for @roomTimeLeft.
  ///
  /// In fr, this message translates to:
  /// **'Il reste {clock} pour décider ensemble'**
  String roomTimeLeft(String clock);

  /// No description provided for @roomSaySomething.
  ///
  /// In fr, this message translates to:
  /// **'Dites quelque chose'**
  String get roomSaySomething;

  /// No description provided for @roomNoTextBody.
  ///
  /// In fr, this message translates to:
  /// **'Pas de texte ici : un vocal ou un sticker. C\'est ce qui fait la différence entre une vraie personne et un message recopié.'**
  String get roomNoTextBody;

  /// No description provided for @roomVoice.
  ///
  /// In fr, this message translates to:
  /// **'Vocal'**
  String get roomVoice;

  /// No description provided for @roomWaitingReply.
  ///
  /// In fr, this message translates to:
  /// **'En attente de sa réponse'**
  String get roomWaitingReply;

  /// No description provided for @roomExtendFor.
  ///
  /// In fr, this message translates to:
  /// **'Dix minutes de plus — {amount} FCFA'**
  String roomExtendFor(int amount);

  /// No description provided for @roomBothSaidYes.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez tous les deux dit oui.'**
  String get roomBothSaidYes;

  /// No description provided for @roomSaved.
  ///
  /// In fr, this message translates to:
  /// **'Le match est sauvé. Tu peux proposer une sortie.'**
  String get roomSaved;

  /// No description provided for @roomClosedNoAnswer.
  ///
  /// In fr, this message translates to:
  /// **'La salle s\'est refermée sans réponse.'**
  String get roomClosedNoAnswer;

  /// No description provided for @roomSuggestDate.
  ///
  /// In fr, this message translates to:
  /// **'Proposer une sortie'**
  String get roomSuggestDate;

  /// No description provided for @safetyCheckin.
  ///
  /// In fr, this message translates to:
  /// **'Tout va bien ?'**
  String get safetyCheckin;

  /// No description provided for @safetyCheckinBody.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse de ta part dans les cinq minutes, ton cercle de sécurité sera prévenu avec ta position.'**
  String get safetyCheckinBody;

  /// No description provided for @safetyAllGood.
  ///
  /// In fr, this message translates to:
  /// **'Oui, tout va bien'**
  String get safetyAllGood;

  /// No description provided for @safetyCircleAlerted.
  ///
  /// In fr, this message translates to:
  /// **'Ton cercle a été prévenu.'**
  String get safetyCircleAlerted;

  /// No description provided for @safetyNoCircle.
  ///
  /// In fr, this message translates to:
  /// **'Alerte enregistrée. Ajoute des proches pour qu\'ils soient prévenus la prochaine fois.'**
  String get safetyNoCircle;

  /// No description provided for @safetyWhoToAlert.
  ///
  /// In fr, this message translates to:
  /// **'Qui prévenir ?'**
  String get safetyWhoToAlert;

  /// No description provided for @safetyWhoToAlertBody.
  ///
  /// In fr, this message translates to:
  /// **'Ces personnes recevront ta position en direct si tu déclenches une alerte.'**
  String get safetyWhoToAlertBody;

  /// No description provided for @safetyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get safetyTitle;

  /// No description provided for @safetySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Qui est prévenu si ça tourne mal'**
  String get safetySubtitle;

  /// No description provided for @safetyQuietAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte discrète'**
  String get safetyQuietAlert;

  /// No description provided for @safetyQuietAlertBody.
  ///
  /// In fr, this message translates to:
  /// **'Prévient ton cercle avec ta position. Rien ne s\'affiche à l\'écran de ton téléphone.'**
  String get safetyQuietAlertBody;

  /// No description provided for @safetyTrigger.
  ///
  /// In fr, this message translates to:
  /// **'Déclencher une alerte'**
  String get safetyTrigger;

  /// No description provided for @safetyMyCircle.
  ///
  /// In fr, this message translates to:
  /// **'Mon cercle'**
  String get safetyMyCircle;

  /// No description provided for @safetyThreeEnough.
  ///
  /// In fr, this message translates to:
  /// **'Trois personnes suffisent'**
  String get safetyThreeEnough;

  /// No description provided for @safetyNobodyYet.
  ///
  /// In fr, this message translates to:
  /// **'Personne pour l\'instant. Sans cercle, une alerte est enregistrée mais ne prévient personne.'**
  String get safetyNobodyYet;

  /// No description provided for @safetyAddSomeone.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter quelqu\'un'**
  String get safetyAddSomeone;

  /// No description provided for @wingmanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Avis de potes'**
  String get wingmanTitle;

  /// No description provided for @wingmanAnon.
  ///
  /// In fr, this message translates to:
  /// **'Ton avis reste anonyme'**
  String get wingmanAnon;

  /// No description provided for @wingmanUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Demandes indisponibles'**
  String get wingmanUnavailable;

  /// No description provided for @wingmanNothing.
  ///
  /// In fr, this message translates to:
  /// **'Rien à valider'**
  String get wingmanNothing;

  /// No description provided for @wingmanNothingBody.
  ///
  /// In fr, this message translates to:
  /// **'Quand un ami te demandera ce que tu penses d\'un profil, il apparaîtra ici.'**
  String get wingmanNothingBody;

  /// No description provided for @wingmanAsksYou.
  ///
  /// In fr, this message translates to:
  /// **'{name} demande ton avis'**
  String wingmanAsksYou(String name);

  /// No description provided for @wingmanMeh.
  ///
  /// In fr, this message translates to:
  /// **'Bof'**
  String get wingmanMeh;

  /// No description provided for @wingmanWorthIt.
  ///
  /// In fr, this message translates to:
  /// **'Ça vaut le coup'**
  String get wingmanWorthIt;

  /// No description provided for @wingmanPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Ton ami verra seulement si le groupe valide, jamais qui a répondu quoi.'**
  String get wingmanPrivacy;

  /// No description provided for @marketLocationOff.
  ///
  /// In fr, this message translates to:
  /// **'Service de localisation désactivé.'**
  String get marketLocationOff;

  /// No description provided for @marketGpsDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission GPS refusée.'**
  String get marketGpsDenied;

  /// No description provided for @marketGpsApplied.
  ///
  /// In fr, this message translates to:
  /// **'Localisation GPS appliquée.'**
  String get marketGpsApplied;

  /// No description provided for @marketGpsFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de récupérer ta position.'**
  String get marketGpsFailed;

  /// No description provided for @marketYourArea.
  ///
  /// In fr, this message translates to:
  /// **'Ta zone'**
  String get marketYourArea;

  /// No description provided for @marketCityOrArea.
  ///
  /// In fr, this message translates to:
  /// **'Ville et quartier'**
  String get marketCityOrArea;

  /// No description provided for @marketLocationCleared.
  ///
  /// In fr, this message translates to:
  /// **'Localisation désactivée.'**
  String get marketLocationCleared;

  /// No description provided for @marketUseGps.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ma position GPS'**
  String get marketUseGps;

  /// No description provided for @marketApply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get marketApply;

  /// No description provided for @marketRemoveProduct.
  ///
  /// In fr, this message translates to:
  /// **'Retirer « {name} » ?'**
  String marketRemoveProduct(String name);

  /// No description provided for @marketProductUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Produit indisponible.'**
  String get marketProductUnavailable;

  /// No description provided for @marketPaymentUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Paiement Mobile Money indisponible.'**
  String get marketPaymentUnavailable;

  /// No description provided for @marketCheckoutUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Checkout Mobile Money inaccessible.'**
  String get marketCheckoutUnreachable;

  /// No description provided for @marketBoostDone.
  ///
  /// In fr, this message translates to:
  /// **'Paiement effectué : annonce sponsorisée.'**
  String get marketBoostDone;

  /// No description provided for @marketBoostPending.
  ///
  /// In fr, this message translates to:
  /// **'Paiement du boost en attente.'**
  String get marketBoostPending;

  /// No description provided for @marketBoostFailed.
  ///
  /// In fr, this message translates to:
  /// **'Boost impossible pour le moment.'**
  String get marketBoostFailed;

  /// No description provided for @marketTitle.
  ///
  /// In fr, this message translates to:
  /// **'Assimé'**
  String get marketTitle;

  /// No description provided for @marketBecomeSeller.
  ///
  /// In fr, this message translates to:
  /// **'Devenir vendeur vérifié'**
  String get marketBecomeSeller;

  /// No description provided for @marketAddProduct.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un produit'**
  String get marketAddProduct;

  /// No description provided for @marketAroundYou.
  ///
  /// In fr, this message translates to:
  /// **'Près de chez toi'**
  String get marketAroundYou;

  /// No description provided for @marketMyGps.
  ///
  /// In fr, this message translates to:
  /// **'Ma position GPS'**
  String get marketMyGps;

  /// No description provided for @marketPickArea.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une zone'**
  String get marketPickArea;

  /// No description provided for @marketNearYou.
  ///
  /// In fr, this message translates to:
  /// **'Près de chez toi'**
  String get marketNearYou;

  /// No description provided for @marketUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Marketplace indisponible.'**
  String get marketUnavailable;

  /// No description provided for @marketNoProduct.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit publié.'**
  String get marketNoProduct;

  /// No description provided for @marketNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit ne correspond à cette recherche.'**
  String get marketNoMatch;

  /// No description provided for @marketAllShown.
  ///
  /// In fr, this message translates to:
  /// **'Tous les produits sont affichés'**
  String get marketAllShown;

  /// No description provided for @marketMyCatalogue.
  ///
  /// In fr, this message translates to:
  /// **'Mon catalogue'**
  String get marketMyCatalogue;

  /// No description provided for @marketSwipeCatalogue.
  ///
  /// In fr, this message translates to:
  /// **'Glisse pour voir toutes tes annonces'**
  String get marketSwipeCatalogue;

  /// No description provided for @marketCatalogueEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'as pas encore d\'annonce'**
  String get marketCatalogueEmpty;

  /// No description provided for @marketCatalogueEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Publie ta première annonce pour commencer à vendre !'**
  String get marketCatalogueEmptyBody;

  /// No description provided for @marketBoosted.
  ///
  /// In fr, this message translates to:
  /// **'Sponsorisé'**
  String get marketBoosted;

  /// No description provided for @vitrineSeeProduct.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'article'**
  String get vitrineSeeProduct;

  /// No description provided for @vitrineHint.
  ///
  /// In fr, this message translates to:
  /// **'Touche l\'article pour l\'ouvrir'**
  String get vitrineHint;

  /// No description provided for @vitrineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vitrine du Marché'**
  String get vitrineTitle;

  /// No description provided for @versesMorning.
  ///
  /// In fr, this message translates to:
  /// **'Verset du matin'**
  String get versesMorning;

  /// No description provided for @versesEvening.
  ///
  /// In fr, this message translates to:
  /// **'Verset du soir'**
  String get versesEvening;

  /// No description provided for @versesChannel.
  ///
  /// In fr, this message translates to:
  /// **'Versets du jour'**
  String get versesChannel;

  /// No description provided for @versesChannelDesc.
  ///
  /// In fr, this message translates to:
  /// **'Les versets de 6 h et de 18 h'**
  String get versesChannelDesc;

  /// No description provided for @versesSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Chaque jour à 6 h et à 18 h'**
  String get versesSchedule;

  /// No description provided for @versesThisMorning.
  ///
  /// In fr, this message translates to:
  /// **'Ce matin'**
  String get versesThisMorning;

  /// No description provided for @versesThisEvening.
  ///
  /// In fr, this message translates to:
  /// **'Ce soir'**
  String get versesThisEvening;

  /// No description provided for @versesBibleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Versets bibliques'**
  String get versesBibleTitle;

  /// No description provided for @versesQuranTitle.
  ///
  /// In fr, this message translates to:
  /// **'Versets coraniques'**
  String get versesQuranTitle;

  /// No description provided for @versesShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get versesShare;

  /// No description provided for @versesOfflineHint.
  ///
  /// In fr, this message translates to:
  /// **'Les versets arrivent même sans connexion : ils sont déjà sur ton téléphone.'**
  String get versesOfflineHint;

  /// No description provided for @marketBoosted48h.
  ///
  /// In fr, this message translates to:
  /// **'Sponsorisé'**
  String get marketBoosted48h;

  /// No description provided for @marketBoost.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en avant'**
  String get marketBoost;

  /// No description provided for @marketRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get marketRemove;

  /// No description provided for @marketGpsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Position GPS enregistrée.'**
  String get marketGpsSaved;

  /// No description provided for @marketNameAndPrice.
  ///
  /// In fr, this message translates to:
  /// **'Un nom et un prix sont nécessaires.'**
  String get marketNameAndPrice;

  /// No description provided for @marketEditProduct.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le produit'**
  String get marketEditProduct;

  /// No description provided for @marketMainPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo principale'**
  String get marketMainPhoto;

  /// No description provided for @marketOtherPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Autres photos'**
  String get marketOtherPhotos;

  /// No description provided for @marketDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get marketDescription;

  /// No description provided for @marketCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get marketCurrency;

  /// No description provided for @marketCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get marketCategory;

  /// No description provided for @marketPickCategory.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une catégorie'**
  String get marketPickCategory;

  /// No description provided for @marketSpecifyCategory.
  ///
  /// In fr, this message translates to:
  /// **'Préciser la catégorie'**
  String get marketSpecifyCategory;

  /// No description provided for @marketGpsCoords.
  ///
  /// In fr, this message translates to:
  /// **'Coordonnées GPS : {lat}, {lon}'**
  String marketGpsCoords(String lat, String lon);

  /// No description provided for @marketUploadingPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Envoi de la photo…'**
  String get marketUploadingPhoto;

  /// No description provided for @marketAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get marketAddPhoto;

  /// No description provided for @groupEditName.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le nom'**
  String get groupEditName;

  /// No description provided for @groupAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get groupAddPhoto;

  /// No description provided for @groupChangePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Changer la photo'**
  String get groupChangePhoto;

  /// No description provided for @groupRemovePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo'**
  String get groupRemovePhoto;

  /// No description provided for @groupNoLink.
  ///
  /// In fr, this message translates to:
  /// **'Aucun lien actif'**
  String get groupNoLink;

  /// No description provided for @groupLinkActive.
  ///
  /// In fr, this message translates to:
  /// **'Un lien est actif'**
  String get groupLinkActive;

  /// No description provided for @groupCreator.
  ///
  /// In fr, this message translates to:
  /// **'Créateur'**
  String get groupCreator;

  /// No description provided for @groupAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Administrateur'**
  String get groupAdmin;

  /// No description provided for @groupAddMembers.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des participants'**
  String get groupAddMembers;

  /// No description provided for @groupLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe'**
  String get groupLeave;

  /// No description provided for @groupName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe'**
  String get groupName;

  /// No description provided for @groupCopyLink.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get groupCopyLink;

  /// No description provided for @groupRegenLink.
  ///
  /// In fr, this message translates to:
  /// **'Régénérer le lien'**
  String get groupRegenLink;

  /// No description provided for @groupDisableLink.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le lien'**
  String get groupDisableLink;

  /// No description provided for @groupLinkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié.'**
  String get groupLinkCopied;

  /// No description provided for @groupLinkDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Lien désactivé.'**
  String get groupLinkDisabled;

  /// No description provided for @groupAllContactsIn.
  ///
  /// In fr, this message translates to:
  /// **'Tous tes contacts Pokou sont déjà dans ce groupe.'**
  String get groupAllContactsIn;

  /// No description provided for @groupAddToGroup.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au groupe'**
  String get groupAddToGroup;

  /// No description provided for @groupMembersAdded.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Participant ajouté.} other{{count} participants ajoutés.}}'**
  String groupMembersAdded(int count);

  /// No description provided for @groupLeaveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe ?'**
  String get groupLeaveTitle;

  /// No description provided for @groupLeaveBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu ne recevras plus les messages de « {name} ». Tes messages restent chez les autres membres, et les administrateurs sont prévenus.'**
  String groupLeaveBody(String name);

  /// No description provided for @groupLeaveAction.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get groupLeaveAction;

  /// No description provided for @groupNoMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message. Lance la discussion.'**
  String get groupNoMessage;

  /// No description provided for @groupNotEncryptedNotice.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré de bout en bout : seuls les membres peuvent lire ces messages.'**
  String get groupNotEncryptedNotice;

  /// No description provided for @botLabel.
  ///
  /// In fr, this message translates to:
  /// **'Bot'**
  String get botLabel;

  /// No description provided for @botConversationNotice.
  ///
  /// In fr, this message translates to:
  /// **'Tu écris au bot d\'une entreprise. Ces messages ne sont pas chiffrés de bout en bout : l\'entreprise lit ce que tu lui envoies.'**
  String get botConversationNotice;

  /// No description provided for @groupAdminsOnly.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux administrateurs'**
  String get groupAdminsOnly;

  /// No description provided for @groupCallOngoing.
  ///
  /// In fr, this message translates to:
  /// **'Appel en cours'**
  String get groupCallOngoing;

  /// No description provided for @communityEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la communauté'**
  String get communityEdit;

  /// No description provided for @commonName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get commonName;

  /// No description provided for @communityEditFailed.
  ///
  /// In fr, this message translates to:
  /// **'Modification impossible.'**
  String get communityEditFailed;

  /// No description provided for @communityAddGroup.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un groupe'**
  String get communityAddGroup;

  /// No description provided for @communityNewGroup.
  ///
  /// In fr, this message translates to:
  /// **'Créer un nouveau groupe'**
  String get communityNewGroup;

  /// No description provided for @communityAttachGroup.
  ///
  /// In fr, this message translates to:
  /// **'Rattacher un groupe existant'**
  String get communityAttachGroup;

  /// No description provided for @communityDetachTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détacher « {name} » ?'**
  String communityDetachTitle(String name);

  /// No description provided for @communityDetachBody.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe quitte la communauté mais continue d\'exister : sa conversation et ses participants ne changent pas.'**
  String get communityDetachBody;

  /// No description provided for @communityDetach.
  ///
  /// In fr, this message translates to:
  /// **'Détacher'**
  String get communityDetach;

  /// No description provided for @communityDetachFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de détacher ce groupe.'**
  String get communityDetachFailed;

  /// No description provided for @communityLinkNote.
  ///
  /// In fr, this message translates to:
  /// **'Qui a ce lien rejoint la communauté et son groupe Annonces — pas les autres groupes, qui restent à rejoindre un par un.'**
  String get communityLinkNote;

  /// No description provided for @communityActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible.'**
  String get communityActionFailed;

  /// No description provided for @communityLeaveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la communauté ?'**
  String get communityLeaveTitle;

  /// No description provided for @communityLeaveBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu ne recevras plus ses annonces. Les groupes que tu as rejoints restent les tiens.'**
  String get communityLeaveBody;

  /// No description provided for @communityLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la communauté'**
  String get communityLeave;

  /// No description provided for @communityLeaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de quitter la communauté.'**
  String get communityLeaveFailed;

  /// No description provided for @communityOne.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get communityOne;

  /// No description provided for @communityUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Communauté indisponible — vérifie ta connexion.'**
  String get communityUnavailable;

  /// No description provided for @communityGroups.
  ///
  /// In fr, this message translates to:
  /// **'GROUPES'**
  String get communityGroups;

  /// No description provided for @communityAnnouncements.
  ///
  /// In fr, this message translates to:
  /// **'Annonces · réservé aux administrateurs'**
  String get communityAnnouncements;

  /// No description provided for @communityOnlyAdminGroups.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les groupes que tu administres peuvent rejoindre une communauté.'**
  String get communityOnlyAdminGroups;

  /// No description provided for @channelPostsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Publications indisponibles.'**
  String get channelPostsUnavailable;

  /// No description provided for @channelReactionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Réaction non enregistrée.'**
  String get channelReactionFailed;

  /// No description provided for @channelPostFailed.
  ///
  /// In fr, this message translates to:
  /// **'Publication impossible.'**
  String get channelPostFailed;

  /// No description provided for @channelEditPost.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la publication'**
  String get channelEditPost;

  /// No description provided for @channelEditTooOld.
  ///
  /// In fr, this message translates to:
  /// **'Modification impossible — publication trop ancienne.'**
  String get channelEditTooOld;

  /// No description provided for @channelDeletePost.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la publication ?'**
  String get channelDeletePost;

  /// No description provided for @channelDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle disparaîtra pour tous les abonnés.'**
  String get channelDeleteBody;

  /// No description provided for @channelDeleteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible.'**
  String get channelDeleteFailed;

  /// No description provided for @channelLinkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien de la chaîne copié.'**
  String get channelLinkCopied;

  /// No description provided for @channelLinkUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Lien indisponible.'**
  String get channelLinkUnavailable;

  /// No description provided for @channelEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la chaîne'**
  String get channelEdit;

  /// No description provided for @channelPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get channelPublish;

  /// No description provided for @channelFollowers.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 abonné} other{{count} abonnés}}'**
  String channelFollowers(int count);

  /// No description provided for @channelFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Abonné'**
  String get channelFollowing;

  /// No description provided for @channelEdited.
  ///
  /// In fr, this message translates to:
  /// **'· modifié'**
  String get channelEdited;

  /// No description provided for @channelImageFailed.
  ///
  /// In fr, this message translates to:
  /// **'Image non envoyée.'**
  String get channelImageFailed;

  /// No description provided for @channelNewPost.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle publication'**
  String get channelNewPost;

  /// No description provided for @channelPostHint.
  ///
  /// In fr, this message translates to:
  /// **'Ton annonce…'**
  String get channelPostHint;

  /// No description provided for @pollAnswerN.
  ///
  /// In fr, this message translates to:
  /// **'Réponse {index}'**
  String pollAnswerN(int index);

  /// No description provided for @pollAddAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une réponse'**
  String get pollAddAnswer;

  /// No description provided for @pollMultiple.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs réponses possibles'**
  String get pollMultiple;

  /// No description provided for @pollAddImage.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une image'**
  String get pollAddImage;

  /// No description provided for @pollRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le sondage'**
  String get pollRemove;

  /// No description provided for @pollOne.
  ///
  /// In fr, this message translates to:
  /// **'Sondage'**
  String get pollOne;

  /// No description provided for @pollQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Ta question'**
  String get pollQuestion;

  /// No description provided for @commonSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get commonSending;

  /// No description provided for @channelPosts.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 publication} other{{count} publications}}'**
  String channelPosts(int count);

  /// No description provided for @lockChooseCode.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un code'**
  String get lockChooseCode;

  /// No description provided for @lockCodeRule.
  ///
  /// In fr, this message translates to:
  /// **'4 à 8 chiffres. Le code ne quitte jamais ce téléphone et ne peut pas être retrouvé — en cas d\'oubli, le verrou se lève en vérifiant ton numéro de téléphone.'**
  String get lockCodeRule;

  /// No description provided for @lockCode.
  ///
  /// In fr, this message translates to:
  /// **'Code'**
  String get lockCode;

  /// No description provided for @lockConfirmCode.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le code'**
  String get lockConfirmCode;

  /// No description provided for @lockTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le code doit faire au moins 4 chiffres.'**
  String get lockTooShort;

  /// No description provided for @lockMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux codes ne correspondent pas.'**
  String get lockMismatch;

  /// No description provided for @lockCurrentCode.
  ///
  /// In fr, this message translates to:
  /// **'Code actuel'**
  String get lockCurrentCode;

  /// No description provided for @lockValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get lockValidate;

  /// No description provided for @lockEnabledToast.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage activé.'**
  String get lockEnabledToast;

  /// No description provided for @lockSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer le code.'**
  String get lockSaveFailed;

  /// No description provided for @lockEnterCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Saisir le code actuel'**
  String get lockEnterCurrent;

  /// No description provided for @lockWrongCode.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect.'**
  String get lockWrongCode;

  /// No description provided for @lockCodeChanged.
  ///
  /// In fr, this message translates to:
  /// **'Code modifié.'**
  String get lockCodeChanged;

  /// No description provided for @lockEnterToDisable.
  ///
  /// In fr, this message translates to:
  /// **'Saisir le code pour désactiver'**
  String get lockEnterToDisable;

  /// No description provided for @lockDisabledToast.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage désactivé.'**
  String get lockDisabledToast;

  /// No description provided for @lockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage de l\'application'**
  String get lockTitle;

  /// No description provided for @lockByCode.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller par code'**
  String get lockByCode;

  /// No description provided for @lockOn.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get lockOn;

  /// No description provided for @lockOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get lockOff;

  /// No description provided for @lockChangeCode.
  ///
  /// In fr, this message translates to:
  /// **'Changer le code'**
  String get lockChangeCode;

  /// No description provided for @lockFootnoteKeystore.
  ///
  /// In fr, this message translates to:
  /// **'Pokou demande le code à chaque retour au premier plan. Le code est gardé dans le coffre sécurisé du système (Keystore), pas envoyé au serveur : il protège l\'écran, pas les données de l\'appareil lui-même.'**
  String get lockFootnoteKeystore;

  /// No description provided for @lockFootnoteBiometrics.
  ///
  /// In fr, this message translates to:
  /// **'L\'empreinte digitale n\'est pas encore proposée — elle demande un changement de configuration Android (FlutterFragmentActivity et la permission USE_BIOMETRIC).'**
  String get lockFootnoteBiometrics;

  /// No description provided for @lockScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pokou est verrouillé'**
  String get lockScreenTitle;

  /// No description provided for @lockEnterToContinue.
  ///
  /// In fr, this message translates to:
  /// **'Saisis ton code pour continuer.'**
  String get lockEnterToContinue;

  /// No description provided for @lockUnlock.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller'**
  String get lockUnlock;

  /// No description provided for @lockForgotQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Code oublié ?'**
  String get lockForgotQuestion;

  /// No description provided for @lockSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'Envoi impossible — vérifie ta connexion.'**
  String get lockSendFailed;

  /// No description provided for @lockRemovedToast.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage retiré. Tu peux choisir un nouveau code dans Profil.'**
  String get lockRemovedToast;

  /// No description provided for @lockVerifyFailed.
  ///
  /// In fr, this message translates to:
  /// **'Vérification impossible — vérifie ta connexion.'**
  String get lockVerifyFailed;

  /// No description provided for @lockLogoutQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter ?'**
  String get lockLogoutQuestion;

  /// No description provided for @lockLogoutBody.
  ///
  /// In fr, this message translates to:
  /// **'À utiliser si tu n\'as plus accès à ce numéro. Tes discussions restent sur le serveur, mais il faudra un numéro joignable pour te reconnecter.'**
  String get lockLogoutBody;

  /// No description provided for @lockLogout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get lockLogout;

  /// No description provided for @lockForgotTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code oublié'**
  String get lockForgotTitle;

  /// No description provided for @lockNoPhoneOnDevice.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de retrouver ton numéro sur ce téléphone.'**
  String get lockNoPhoneOnDevice;

  /// No description provided for @lockEnterSentCode.
  ///
  /// In fr, this message translates to:
  /// **'Saisis le code envoyé au {phone} par SMS et WhatsApp.'**
  String lockEnterSentCode(String phone);

  /// No description provided for @lockForgotExplain.
  ///
  /// In fr, this message translates to:
  /// **'Le code de verrouillage n\'est stocké que sur ce téléphone et ne peut pas être retrouvé. Pour lever le verrou, vérifie ton numéro {phone}.'**
  String lockForgotExplain(String phone);

  /// No description provided for @lockLift.
  ///
  /// In fr, this message translates to:
  /// **'Lever le verrouillage'**
  String get lockLift;

  /// No description provided for @lockSendCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un code'**
  String get lockSendCode;

  /// No description provided for @lockResendCode.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get lockResendCode;

  /// No description provided for @lockNoAccessToNumber.
  ///
  /// In fr, this message translates to:
  /// **'Je n\'ai plus accès à ce numéro'**
  String get lockNoAccessToNumber;

  /// No description provided for @notifInApp.
  ///
  /// In fr, this message translates to:
  /// **'Dans l\'application'**
  String get notifInApp;

  /// No description provided for @notifMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get notifMessages;

  /// No description provided for @notifMessagesSub.
  ///
  /// In fr, this message translates to:
  /// **'Conversations individuelles'**
  String get notifMessagesSub;

  /// No description provided for @notifMessagesSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Notifications de messages'**
  String get notifMessagesSemantic;

  /// No description provided for @notifGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get notifGroups;

  /// No description provided for @notifGroupsSub.
  ///
  /// In fr, this message translates to:
  /// **'Conversations de groupe'**
  String get notifGroupsSub;

  /// No description provided for @notifGroupsSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Notifications de groupes'**
  String get notifGroupsSemantic;

  /// No description provided for @notifCallsSub.
  ///
  /// In fr, this message translates to:
  /// **'Appels audio et vidéo entrants'**
  String get notifCallsSub;

  /// No description provided for @notifCallsSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Notifications d\'appels'**
  String get notifCallsSemantic;

  /// No description provided for @notifSound.
  ///
  /// In fr, this message translates to:
  /// **'Son et vibration'**
  String get notifSound;

  /// No description provided for @notifSoundSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Son des notifications'**
  String get notifSoundSemantic;

  /// No description provided for @notifCallsFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Couper les appels ici ne supprime que la bannière affichée quand Pokou est ouvert : un appel entrant continue de sonner en plein écran, sinon tu manquerais des appels sans le savoir.'**
  String get notifCallsFootnote;

  /// No description provided for @notifSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get notifSystem;

  /// No description provided for @notifWebEnable.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications Web'**
  String get notifWebEnable;

  /// No description provided for @notifWebEnableSub.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser ce navigateur à recevoir les notifications Pokou.'**
  String get notifWebEnableSub;

  /// No description provided for @notifWebEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Notifications du navigateur activées.'**
  String get notifWebEnabled;

  /// No description provided for @notifWebEnableFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'activer les notifications. Vérifie les réglages de ce site dans le navigateur.'**
  String get notifWebEnableFailed;

  /// No description provided for @notifAndroidSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages Android'**
  String get notifAndroidSettings;

  /// No description provided for @notifAndroidSettingsSub.
  ///
  /// In fr, this message translates to:
  /// **'Autorisation, canaux, son par canal'**
  String get notifAndroidSettingsSub;

  /// No description provided for @notifSystemFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Quand Pokou est fermé, c\'est Android qui affiche les notifications reçues, sans passer par l\'application : seuls les réglages système ci-dessus peuvent les modifier.'**
  String get notifSystemFootnote;

  /// No description provided for @devicesRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer cet appareil ?'**
  String get devicesRemoveTitle;

  /// No description provided for @devicesRemoveCurrentBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce téléphone ne recevra plus de notifications tant que tu n\'ouvriras pas Pokou à nouveau.'**
  String get devicesRemoveCurrentBody;

  /// No description provided for @devicesRemoveOtherBody.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil ne recevra plus de notifications. Il reste connecté jusqu\'à sa prochaine déconnexion.'**
  String get devicesRemoveOtherBody;

  /// No description provided for @devicesRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get devicesRemove;

  /// No description provided for @devicesRemoveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de retirer cet appareil.'**
  String get devicesRemoveFailed;

  /// No description provided for @devicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get devicesTitle;

  /// No description provided for @devicesUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Liste indisponible — vérifie ta connexion, puis tire pour rafraîchir.'**
  String get devicesUnavailable;

  /// No description provided for @devicesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appareil enregistré pour les notifications. Elles s\'activent à la première ouverture de Pokou sur un appareil.'**
  String get devicesEmpty;

  /// No description provided for @devicesThisDevice.
  ///
  /// In fr, this message translates to:
  /// **' · cet appareil'**
  String get devicesThisDevice;

  /// No description provided for @devicesLastSeen.
  ///
  /// In fr, this message translates to:
  /// **'Actif le {date} · …{hint}'**
  String devicesLastSeen(String date, String hint);

  /// No description provided for @devicesFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Un appareil apparaît ici dès qu\'il s\'enregistre pour les notifications push. Le retirer coupe ses notifications ; cela ne ferme pas sa session, qui expire d\'elle-même.'**
  String get devicesFootnote;

  /// No description provided for @devicesBrowser.
  ///
  /// In fr, this message translates to:
  /// **'Navigateur'**
  String get devicesBrowser;

  /// No description provided for @devicesTodayAt.
  ///
  /// In fr, this message translates to:
  /// **'aujourd\'hui à {time}'**
  String devicesTodayAt(String time);

  /// No description provided for @storageNoCachedMedia.
  ///
  /// In fr, this message translates to:
  /// **'Aucun média en cache.'**
  String get storageNoCachedMedia;

  /// No description provided for @storageFilesCleared.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 fichier supprimé du cache.} other{{count} fichiers supprimés du cache.}}'**
  String storageFilesCleared(int count);

  /// No description provided for @storageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Stockage et données'**
  String get storageTitle;

  /// No description provided for @storageCachedMedia.
  ///
  /// In fr, this message translates to:
  /// **'Médias en cache'**
  String get storageCachedMedia;

  /// No description provided for @storageMediaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photos, vidéos et notes vocales'**
  String get storageMediaLabel;

  /// No description provided for @storageComputing.
  ///
  /// In fr, this message translates to:
  /// **'Calcul en cours…'**
  String get storageComputing;

  /// No description provided for @storageNoFile.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier'**
  String get storageNoFile;

  /// No description provided for @storageFileCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 fichier} other{{count} fichiers}} · {size}'**
  String storageFileCount(int count, String size);

  /// No description provided for @storageClearCache.
  ///
  /// In fr, this message translates to:
  /// **'Vider le cache'**
  String get storageClearCache;

  /// No description provided for @storageClearFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers vidés sont retéléchargés à la demande quand tu rouvres la discussion : rien n\'est perdu, seulement libéré.'**
  String get storageClearFootnote;

  /// No description provided for @storageMobileData.
  ///
  /// In fr, this message translates to:
  /// **'En données mobiles'**
  String get storageMobileData;

  /// No description provided for @storageDataSaver.
  ///
  /// In fr, this message translates to:
  /// **'Économie de données'**
  String get storageDataSaver;

  /// No description provided for @storageDataSaverSub.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas télécharger les médias automatiquement'**
  String get storageDataSaverSub;

  /// No description provided for @storageDataSaverFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Activée, les photos et vidéos reçues attendent que tu les touches pour se télécharger, et les photos que tu envoies sont compressées davantage.'**
  String get storageDataSaverFootnote;

  /// No description provided for @profileAvatarFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de mettre à jour la photo de profil.'**
  String get profileAvatarFailed;

  /// No description provided for @profileChooseMonitor.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un moniteur'**
  String get profileChooseMonitor;

  /// No description provided for @profileBabaMessaging.
  ///
  /// In fr, this message translates to:
  /// **'Messagerie Baba'**
  String get profileBabaMessaging;

  /// No description provided for @profileMonitorAlerts.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Alertes de 1 moniteur} other{Alertes de {count} moniteurs}}'**
  String profileMonitorAlerts(int count);

  /// No description provided for @profileBabaAssistant.
  ///
  /// In fr, this message translates to:
  /// **'Assistant Baba'**
  String get profileBabaAssistant;

  /// No description provided for @profileShieldModeBody.
  ///
  /// In fr, this message translates to:
  /// **'Met en attente les appels et met en veilleuse les discussions non prioritaires pendant que tu es concentré. Tes contacts étiquetés Business, Client, Fournisseur ou Boss passent toujours.'**
  String get profileShieldModeBody;

  /// No description provided for @contactConnectFailed.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible.'**
  String get contactConnectFailed;

  /// No description provided for @contactCallFailed.
  ///
  /// In fr, this message translates to:
  /// **'Appel impossible pour l\'instant.'**
  String get contactCallFailed;

  /// No description provided for @contactBlockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer {name} ?'**
  String contactBlockTitle(String name);

  /// No description provided for @contactBlockBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne ne pourra plus t\'écrire ni t\'appeler. Elle n\'en sera pas informée.'**
  String get contactBlockBody;

  /// No description provided for @contactActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible pour le moment.'**
  String get contactActionFailed;

  /// No description provided for @contactSavedToast.
  ///
  /// In fr, this message translates to:
  /// **'Contact enregistré'**
  String get contactSavedToast;

  /// No description provided for @contactCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel'**
  String get contactCall;

  /// No description provided for @contactSharedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Éléments échangés'**
  String get contactSharedTitle;

  /// No description provided for @contactSharedMedia.
  ///
  /// In fr, this message translates to:
  /// **'Médias'**
  String get contactSharedMedia;

  /// No description provided for @contactSharedDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get contactSharedDocuments;

  /// No description provided for @contactSharedLinks.
  ///
  /// In fr, this message translates to:
  /// **'Liens'**
  String get contactSharedLinks;

  /// No description provided for @contactNoMedia.
  ///
  /// In fr, this message translates to:
  /// **'Aucune photo ni vidéo échangée.'**
  String get contactNoMedia;

  /// No description provided for @contactNoDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document échangé.'**
  String get contactNoDocuments;

  /// No description provided for @contactNoLinks.
  ///
  /// In fr, this message translates to:
  /// **'Aucun lien échangé.'**
  String get contactNoLinks;

  /// No description provided for @contactCommonGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes en commun ({count})'**
  String contactCommonGroups(int count);

  /// No description provided for @contactCatalog.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue ({count})'**
  String contactCatalog(int count);

  /// No description provided for @contactUnblockName.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer {name}'**
  String contactUnblockName(String name);

  /// No description provided for @contactBlockName.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer {name}'**
  String contactBlockName(String name);

  /// No description provided for @contactUnblockHint.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne peut à nouveau t\'écrire et t\'appeler.'**
  String get contactUnblockHint;

  /// No description provided for @contactBlockHint.
  ///
  /// In fr, this message translates to:
  /// **'Elle ne pourra plus t\'écrire ni t\'appeler, sans en être informée.'**
  String get contactBlockHint;

  /// No description provided for @adNeedTitleBody.
  ///
  /// In fr, this message translates to:
  /// **'Donne un titre et un message à ta publicité.'**
  String get adNeedTitleBody;

  /// No description provided for @adSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'La demande n\'a pas pu être envoyée.'**
  String get adSendFailed;

  /// No description provided for @adCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer une publicité'**
  String get adCreateTitle;

  /// No description provided for @adWhoSeesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qui la verra'**
  String get adWhoSeesTitle;

  /// No description provided for @adWhoSeesBody.
  ///
  /// In fr, this message translates to:
  /// **'Tous les utilisateurs de Pokou dans Assimé, ou entre deux statuts — à toi de choisir.'**
  String get adWhoSeesBody;

  /// No description provided for @adReviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une relecture avant diffusion'**
  String get adReviewTitle;

  /// No description provided for @adReviewBody.
  ///
  /// In fr, this message translates to:
  /// **'Notre équipe lit chaque campagne avant qu\'elle ne parte. Compte quelques heures.'**
  String get adReviewBody;

  /// No description provided for @adCountdownTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le décompte part de la validation'**
  String get adCountdownTitle;

  /// No description provided for @adCountdownBody.
  ///
  /// In fr, this message translates to:
  /// **'Tes jours de diffusion commencent une fois la campagne acceptée, pas au paiement.'**
  String get adCountdownBody;

  /// No description provided for @adRefundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Refusée ? Tu es remboursé'**
  String get adRefundTitle;

  /// No description provided for @adRefundBody.
  ///
  /// In fr, this message translates to:
  /// **'Si la campagne ne peut pas être diffusée, contacte-nous : la somme t\'est rendue.'**
  String get adRefundBody;

  /// No description provided for @adTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Ciment CIMTOGO en promotion'**
  String get adTitleHint;

  /// No description provided for @adBodyHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu proposes, et comment te joindre.'**
  String get adBodyHint;

  /// No description provided for @adMediaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photo ou vidéo (facultatif)'**
  String get adMediaLabel;

  /// No description provided for @adMediaHint.
  ///
  /// In fr, this message translates to:
  /// **'Une vidéo de 30 secondes au maximum. Sans image, seul le texte est diffusé.'**
  String get adMediaHint;

  /// No description provided for @adVideo30s.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo 30 s'**
  String get adVideo30s;

  /// No description provided for @adPlacement.
  ///
  /// In fr, this message translates to:
  /// **'Emplacement'**
  String get adPlacement;

  /// No description provided for @adPlacementMarket.
  ///
  /// In fr, this message translates to:
  /// **'Onglet Marché'**
  String get adPlacementMarket;

  /// No description provided for @adPlacementStatus.
  ///
  /// In fr, this message translates to:
  /// **'Entre les statuts'**
  String get adPlacementStatus;

  /// No description provided for @adDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get adDuration;

  /// No description provided for @adOneWeek.
  ///
  /// In fr, this message translates to:
  /// **'1 semaine'**
  String get adOneWeek;

  /// No description provided for @adTwoWeeks.
  ///
  /// In fr, this message translates to:
  /// **'2 semaines'**
  String get adTwoWeeks;

  /// No description provided for @adOneMonth.
  ///
  /// In fr, this message translates to:
  /// **'1 mois'**
  String get adOneMonth;

  /// No description provided for @adPayCaption.
  ///
  /// In fr, this message translates to:
  /// **'Paiement Mobile Money'**
  String get adPayCaption;

  /// No description provided for @adPayAction.
  ///
  /// In fr, this message translates to:
  /// **'Payer et envoyer'**
  String get adPayAction;

  /// No description provided for @productInterestedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, je suis intéressé par ton annonce « {name} » à {price} {currency}. Est-elle toujours disponible ?'**
  String productInterestedMessage(String name, String price, String currency);

  /// No description provided for @productWriteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'écrire au vendeur pour l\'instant.'**
  String get productWriteFailed;

  /// No description provided for @productCallFirstWrite.
  ///
  /// In fr, this message translates to:
  /// **'Appel impossible — écris-lui d\'abord.'**
  String get productCallFirstWrite;

  /// No description provided for @productRateSeller.
  ///
  /// In fr, this message translates to:
  /// **'Noter ce vendeur'**
  String get productRateSeller;

  /// No description provided for @productEditReview.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon avis'**
  String get productEditReview;

  /// No description provided for @productReviewScope.
  ///
  /// In fr, this message translates to:
  /// **'L\'avis porte sur le VENDEUR, pas sur un produit : c\'est la confiance dans la personne qui compte, et elle reste même si l\'article quitte le catalogue.'**
  String get productReviewScope;

  /// No description provided for @productReviewHint.
  ///
  /// In fr, this message translates to:
  /// **'Ton commentaire (facultatif)'**
  String get productReviewHint;

  /// No description provided for @productDeleteReview.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon avis'**
  String get productDeleteReview;

  /// No description provided for @productReviewFailed.
  ///
  /// In fr, this message translates to:
  /// **'Avis non enregistré.'**
  String get productReviewFailed;

  /// No description provided for @productTitle.
  ///
  /// In fr, this message translates to:
  /// **'Produit'**
  String get productTitle;

  /// No description provided for @productOpening.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture…'**
  String get productOpening;

  /// No description provided for @productDiscuss.
  ///
  /// In fr, this message translates to:
  /// **'Discuter'**
  String get productDiscuss;

  /// No description provided for @productCallAction.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get productCallAction;

  /// No description provided for @productReviews.
  ///
  /// In fr, this message translates to:
  /// **'Avis'**
  String get productReviews;

  /// No description provided for @productNoReviewYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d\'avis'**
  String get productNoReviewYet;

  /// No description provided for @productRatingSummary.
  ///
  /// In fr, this message translates to:
  /// **'{rating} ★ · {reviews, plural, =1{1 avis} other{{reviews} avis}}'**
  String productRatingSummary(String rating, int reviews);

  /// No description provided for @productCountSuffix.
  ///
  /// In fr, this message translates to:
  /// **' · {count, plural, =1{1 produit} other{{count} produits}}'**
  String productCountSuffix(int count);

  /// No description provided for @productCertified.
  ///
  /// In fr, this message translates to:
  /// **'Compte vérifié par l\'équipe Pokou.'**
  String get productCertified;

  /// No description provided for @productReviewMine.
  ///
  /// In fr, this message translates to:
  /// **'Toi'**
  String get productReviewMine;

  /// No description provided for @verifNeedDocument.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute une photo de ta pièce d\'identité.'**
  String get verifNeedDocument;

  /// No description provided for @verifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Devenir vendeur vérifié'**
  String get verifTitle;

  /// No description provided for @verifBadgeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un badge bleu sur tes annonces'**
  String get verifBadgeTitle;

  /// No description provided for @verifBadgeBody.
  ///
  /// In fr, this message translates to:
  /// **'Les acheteurs voient que ton identité a été vérifiée par notre équipe.'**
  String get verifBadgeBody;

  /// No description provided for @verifWhyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi ça change tout'**
  String get verifWhyTitle;

  /// No description provided for @verifWhyBody.
  ///
  /// In fr, this message translates to:
  /// **'Un acheteur envoie plus facilement de l\'argent Mobile Money à quelqu\'un dont l\'identité est confirmée qu\'à un inconnu.'**
  String get verifWhyBody;

  /// No description provided for @verifNeedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce qu\'il faut fournir'**
  String get verifNeedTitle;

  /// No description provided for @verifNeedBody.
  ///
  /// In fr, this message translates to:
  /// **'Une photo nette de ta carte d\'identité, passeport ou permis. Le nom doit être lisible.'**
  String get verifNeedBody;

  /// No description provided for @verifUseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que nous en faisons'**
  String get verifUseTitle;

  /// No description provided for @verifUseBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle est lue par notre équipe pour la seule vérification, n\'apparaît jamais sur ton profil, et n\'est montrée à aucun acheteur.'**
  String get verifUseBody;

  /// No description provided for @verifOneYearTitle.
  ///
  /// In fr, this message translates to:
  /// **'Valable un an'**
  String get verifOneYearTitle;

  /// No description provided for @verifOneYearBody.
  ///
  /// In fr, this message translates to:
  /// **'Le badge dure douze mois. Compte quelques jours pour l\'examen du dossier.'**
  String get verifOneYearBody;

  /// No description provided for @verifDocumentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ta pièce d\'identité'**
  String get verifDocumentLabel;

  /// No description provided for @verifPayCaption.
  ///
  /// In fr, this message translates to:
  /// **'Paiement Mobile Money · 1 an'**
  String get verifPayCaption;

  /// No description provided for @verifChoosePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get verifChoosePhoto;

  /// No description provided for @verifChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get verifChange;

  /// No description provided for @marketRemoveBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'annonce disparaît d\'Assimé. Tes discussions à son sujet restent lisibles, et les acheteurs qui l\'ont déjà reçue gardent leur historique.'**
  String get marketRemoveBody;

  /// No description provided for @marketRemoveFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'annonce n\'a pas pu être retirée.'**
  String get marketRemoveFailed;

  /// No description provided for @marketImageFailed.
  ///
  /// In fr, this message translates to:
  /// **'Image non envoyée — réessaie.'**
  String get marketImageFailed;

  /// No description provided for @marketMainPhotoHint.
  ///
  /// In fr, this message translates to:
  /// **'C\'est elle qui illustre le produit dans la liste.'**
  String get marketMainPhotoHint;

  /// No description provided for @marketName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get marketName;

  /// No description provided for @marketPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get marketPrice;

  /// No description provided for @marketNoReviewYet.
  ///
  /// In fr, this message translates to:
  /// **'pas encore d\'avis'**
  String get marketNoReviewYet;

  /// No description provided for @marketSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un produit…'**
  String get marketSearchHint;

  /// No description provided for @callLogEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appel pour l\'instant.'**
  String get callLogEmpty;

  /// No description provided for @callLogUnknownUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get callLogUnknownUser;

  /// No description provided for @callStatusMissed.
  ///
  /// In fr, this message translates to:
  /// **'Manqué'**
  String get callStatusMissed;

  /// No description provided for @callStatusNoAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse'**
  String get callStatusNoAnswer;

  /// No description provided for @callStatusDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get callStatusDeclined;

  /// No description provided for @callStatusReceived.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get callStatusReceived;

  /// No description provided for @callStatusEnded.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get callStatusEnded;

  /// No description provided for @callStatusOngoing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get callStatusOngoing;

  /// No description provided for @callStatusOutgoing.
  ///
  /// In fr, this message translates to:
  /// **'Appelé'**
  String get callStatusOutgoing;

  /// No description provided for @callVideoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo'**
  String get callVideoTitle;

  /// No description provided for @callAudioTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio'**
  String get callAudioTitle;

  /// No description provided for @callRedialQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Rappeler {name} ?'**
  String callRedialQuestion(String name);

  /// No description provided for @callJoinFailed.
  ///
  /// In fr, this message translates to:
  /// **'Connexion à l\'appel impossible.'**
  String get callJoinFailed;

  /// No description provided for @callNobodyToAdd.
  ///
  /// In fr, this message translates to:
  /// **'Personne d\'autre à ajouter.'**
  String get callNobodyToAdd;

  /// No description provided for @callAddToCall.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à l\'appel'**
  String get callAddToCall;

  /// No description provided for @callAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get callAdd;

  /// No description provided for @callAddFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter ce participant.'**
  String get callAddFailed;

  /// No description provided for @callReactionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'envoyer cette réaction.'**
  String get callReactionFailed;

  /// No description provided for @callLeaveConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter l\'appel ?'**
  String get callLeaveConfirmTitle;

  /// No description provided for @callLeaveConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Les autres participants peuvent encore parler. Pour revenir à l\'appel, tu peux fermer cet écran sans raccrocher.'**
  String get callLeaveConfirmBody;

  /// No description provided for @callYou.
  ///
  /// In fr, this message translates to:
  /// **'Toi'**
  String get callYou;

  /// No description provided for @callContact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get callContact;

  /// No description provided for @callConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion à l\'appel…'**
  String get callConnecting;

  /// No description provided for @callPreparing.
  ///
  /// In fr, this message translates to:
  /// **'L\'appel est en cours de préparation'**
  String get callPreparing;

  /// No description provided for @callWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente…'**
  String get callWaiting;

  /// No description provided for @callJoinImpossible.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de rejoindre l\'appel.'**
  String get callJoinImpossible;

  /// No description provided for @callEncryptedJoinFailed.
  ///
  /// In fr, this message translates to:
  /// **'Cet appel chiffré n\'a pas pu être ouvert sur ce téléphone. L\'appelant en est averti.'**
  String get callEncryptedJoinFailed;

  /// No description provided for @callIncoming.
  ///
  /// In fr, this message translates to:
  /// **'Appel entrant'**
  String get callIncoming;

  /// No description provided for @callIncomingFrom.
  ///
  /// In fr, this message translates to:
  /// **'{name} t\'appelle'**
  String callIncomingFrom(String name);

  /// No description provided for @callIncomingGroup.
  ///
  /// In fr, this message translates to:
  /// **'Appel de groupe entrant'**
  String get callIncomingGroup;

  /// No description provided for @streakSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un jour manqué, quelques minutes pour le rattraper'**
  String get streakSubtitle;

  /// No description provided for @streakUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Chaînes indisponibles'**
  String get streakUnavailable;

  /// No description provided for @streakCheckConnection.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ta connexion et réessaie.'**
  String get streakCheckConnection;

  /// No description provided for @streakEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune chaîne pour le moment'**
  String get streakEmptyTitle;

  /// No description provided for @streakEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Échange un message chaque jour avec la même personne : la chaîne démarre au premier aller-retour.'**
  String get streakEmptyBody;

  /// No description provided for @streakToRescue.
  ///
  /// In fr, this message translates to:
  /// **'À sauver maintenant'**
  String get streakToRescue;

  /// No description provided for @streakToRescueSub.
  ///
  /// In fr, this message translates to:
  /// **'Passé le délai, la chaîne repart de zéro'**
  String get streakToRescueSub;

  /// No description provided for @streakMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes chaînes'**
  String get streakMine;

  /// No description provided for @streakRunning.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get streakRunning;

  /// No description provided for @streakRecord.
  ///
  /// In fr, this message translates to:
  /// **'Record : {days, plural, =1{1 jour} other{{days} jours}}'**
  String streakRecord(int days);

  /// No description provided for @streakLongest.
  ///
  /// In fr, this message translates to:
  /// **'Ta plus longue chaîne'**
  String get streakLongest;

  /// No description provided for @streakRestorePending.
  ///
  /// In fr, this message translates to:
  /// **'Ta chaîne repartira dès la confirmation du paiement.'**
  String get streakRestorePending;

  /// No description provided for @streakDeadlinePassed.
  ///
  /// In fr, this message translates to:
  /// **'Le délai est peut-être passé.'**
  String get streakDeadlinePassed;

  /// No description provided for @streakBroken.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Chaîne de 1 jour rompue} other{Chaîne de {days} jours rompue}}'**
  String streakBroken(int days);

  /// No description provided for @streakExpired.
  ///
  /// In fr, this message translates to:
  /// **'Le délai est passé. La chaîne repart de zéro.'**
  String get streakExpired;

  /// No description provided for @streakCountdown.
  ///
  /// In fr, this message translates to:
  /// **'Encore {time} pour la sauver'**
  String streakCountdown(String time);

  /// No description provided for @streakRescueAction.
  ///
  /// In fr, this message translates to:
  /// **'Sauver la chaîne — {amount} FCFA'**
  String streakRescueAction(int amount);

  /// No description provided for @leagueSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ta ligue monte avec ce que tu reçois'**
  String get leagueSubtitle;

  /// No description provided for @leagueUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Classement indisponible'**
  String get leagueUnavailable;

  /// No description provided for @leagueRanking.
  ///
  /// In fr, this message translates to:
  /// **'Classement'**
  String get leagueRanking;

  /// No description provided for @leagueProtectPending.
  ///
  /// In fr, this message translates to:
  /// **'Ta protection sera active dès la confirmation du paiement.'**
  String get leagueProtectPending;

  /// No description provided for @leaguePaymentFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement n\'a pas pu être lancé.'**
  String get leaguePaymentFailed;

  /// No description provided for @leagueAtTop.
  ///
  /// In fr, this message translates to:
  /// **'Tu es au sommet du classement.'**
  String get leagueAtTop;

  /// No description provided for @leaguePointsNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Encore {points} points pour {label}.'**
  String leaguePointsNeeded(int points, String label);

  /// No description provided for @leagueProtected.
  ///
  /// In fr, this message translates to:
  /// **'Tes points sont protégés. Rien ne baisse cette semaine.'**
  String get leagueProtected;

  /// No description provided for @leagueDecayNow.
  ///
  /// In fr, this message translates to:
  /// **'Tes points baissent au prochain passage.'**
  String get leagueDecayNow;

  /// No description provided for @leagueDecayIn.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{Tes points baissent dans 1 jour sans activité.} other{Tes points baissent dans {days} jours sans activité.}}'**
  String leagueDecayIn(int days);

  /// No description provided for @leagueProtectAction.
  ///
  /// In fr, this message translates to:
  /// **'Protéger mes points — 500 FCFA'**
  String get leagueProtectAction;

  /// No description provided for @leagueNobodyRanked.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'est encore classé. Sois le premier.'**
  String get leagueNobodyRanked;

  /// No description provided for @leagueMyRank.
  ///
  /// In fr, this message translates to:
  /// **'Tu es {rank}ᵉ avec {points} points.'**
  String leagueMyRank(int rank, int points);

  /// No description provided for @reactWith.
  ///
  /// In fr, this message translates to:
  /// **'Réagir avec…'**
  String get reactWith;

  /// No description provided for @reactPickEmoji.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un émoji sur le clavier'**
  String get reactPickEmoji;

  /// No description provided for @reactAction.
  ///
  /// In fr, this message translates to:
  /// **'Réagir'**
  String get reactAction;

  /// No description provided for @mediaPoll.
  ///
  /// In fr, this message translates to:
  /// **'Sondage'**
  String get mediaPoll;

  /// No description provided for @mediaContact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get mediaContact;

  /// No description provided for @mediaSharedContact.
  ///
  /// In fr, this message translates to:
  /// **'Contact partagé'**
  String get mediaSharedContact;

  /// No description provided for @convEdited.
  ///
  /// In fr, this message translates to:
  /// **'· modifié'**
  String get convEdited;

  /// No description provided for @convFallbackName.
  ///
  /// In fr, this message translates to:
  /// **'Conversation'**
  String get convFallbackName;

  /// No description provided for @convSomeone.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu\'un'**
  String get convSomeone;

  /// No description provided for @contactsTagFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de mettre à jour l\'étiquette.'**
  String get contactsTagFailed;

  /// No description provided for @contactsTag.
  ///
  /// In fr, this message translates to:
  /// **'Étiqueter'**
  String get contactsTag;

  /// No description provided for @contactsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get contactsTitle;

  /// No description provided for @contactsTyping.
  ///
  /// In fr, this message translates to:
  /// **'écrit…'**
  String get contactsTyping;

  /// No description provided for @contactsTypingNamed.
  ///
  /// In fr, this message translates to:
  /// **'{name} écrit…'**
  String contactsTypingNamed(String name);

  /// No description provided for @contactsPreviewMine.
  ///
  /// In fr, this message translates to:
  /// **'Toi : {preview}'**
  String contactsPreviewMine(String preview);

  /// No description provided for @contactsPreviewSender.
  ///
  /// In fr, this message translates to:
  /// **'{name} : {preview}'**
  String contactsPreviewSender(String name, String preview);

  /// No description provided for @contactsNotInContacts.
  ///
  /// In fr, this message translates to:
  /// **'{preview} · pas dans tes contacts'**
  String contactsNotInContacts(String preview);

  /// No description provided for @contactsAssistantSub.
  ///
  /// In fr, this message translates to:
  /// **'Pose-moi une question sur Pokou.'**
  String get contactsAssistantSub;

  /// No description provided for @addContactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact'**
  String get addContactTitle;

  /// No description provided for @addContactName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get addContactName;

  /// No description provided for @addContactAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addContactAction;

  /// No description provided for @joinLinkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre par lien'**
  String get joinLinkTitle;

  /// No description provided for @joinLinkBody.
  ///
  /// In fr, this message translates to:
  /// **'Colle le lien qu\'on t\'a envoyé. Groupe ou communauté, on reconnaît lequel.'**
  String get joinLinkBody;

  /// No description provided for @joinLinkContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get joinLinkContinue;

  /// No description provided for @joinLinkUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'Lien d\'invitation illisible.'**
  String get joinLinkUnreadable;

  /// No description provided for @joinAlreadyMember.
  ///
  /// In fr, this message translates to:
  /// **'Tu es déjà dans « {name} ».'**
  String joinAlreadyMember(String name);

  /// No description provided for @joinGroupQuestion.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 participant} other{{count} participants}}. Rejoindre ce groupe ?'**
  String joinGroupQuestion(int count);

  /// No description provided for @joinAction.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinAction;

  /// No description provided for @joinGroupFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de rejoindre ce groupe.'**
  String get joinGroupFailed;

  /// No description provided for @joinCommunityCounts.
  ///
  /// In fr, this message translates to:
  /// **'{members, plural, =1{1 membre} other{{members} membres}} · {groups, plural, =1{1 groupe} other{{groups} groupes}}.'**
  String joinCommunityCounts(int members, int groups);

  /// No description provided for @joinCommunityBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu recevras ses annonces. Les autres groupes restent à rejoindre un par un.'**
  String get joinCommunityBody;

  /// No description provided for @joinCommunityFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de rejoindre cette communauté.'**
  String get joinCommunityFailed;

  /// No description provided for @newChatOwnNumber.
  ///
  /// In fr, this message translates to:
  /// **'C\'est ton propre numéro.'**
  String get newChatOwnNumber;

  /// No description provided for @phoneLookupFailed.
  ///
  /// In fr, this message translates to:
  /// **'Numéro invalide ou vérification impossible.'**
  String get phoneLookupFailed;

  /// No description provided for @phoneNotOnPokou.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro n\'utilise pas encore Pokou.'**
  String get phoneNotOnPokou;

  /// No description provided for @phoneInviteWhatsApp.
  ///
  /// In fr, this message translates to:
  /// **'Inviter par WhatsApp'**
  String get phoneInviteWhatsApp;

  /// No description provided for @phoneInviteText.
  ///
  /// In fr, this message translates to:
  /// **'Salut ! Je t\'invite à essayer Pokou, une messagerie privée — télécharge l\'app et ajoute-moi.'**
  String get phoneInviteText;

  /// No description provided for @contactCardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Carte de visite'**
  String get contactCardTitle;

  /// No description provided for @viewOnceSeen.
  ///
  /// In fr, this message translates to:
  /// **'Consultée'**
  String get viewOnceSeen;

  /// No description provided for @viewOnceTapToSee.
  ///
  /// In fr, this message translates to:
  /// **'Vue unique — toucher pour voir'**
  String get viewOnceTapToSee;

  /// No description provided for @audioPlayFailed.
  ///
  /// In fr, this message translates to:
  /// **'Lecture impossible'**
  String get audioPlayFailed;

  /// No description provided for @mediaPhotoSize.
  ///
  /// In fr, this message translates to:
  /// **'Photo · {size}'**
  String mediaPhotoSize(Object size);

  /// No description provided for @mediaTapToDownload.
  ///
  /// In fr, this message translates to:
  /// **'Toucher pour télécharger'**
  String get mediaTapToDownload;

  /// No description provided for @mediaVideoUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo indisponible'**
  String get mediaVideoUnavailable;

  /// No description provided for @mediaOpenDocFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir ce document.'**
  String get mediaOpenDocFailed;

  /// No description provided for @mediaOpenRetry.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'ouverture — toucher pour réessayer'**
  String get mediaOpenRetry;

  /// No description provided for @dayToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get dayYesterday;

  /// No description provided for @weekdayMonday.
  ///
  /// In fr, this message translates to:
  /// **'lundi'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In fr, this message translates to:
  /// **'mardi'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In fr, this message translates to:
  /// **'mercredi'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In fr, this message translates to:
  /// **'jeudi'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In fr, this message translates to:
  /// **'vendredi'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In fr, this message translates to:
  /// **'samedi'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In fr, this message translates to:
  /// **'dimanche'**
  String get weekdaySunday;

  /// No description provided for @liveHoursLeft.
  ///
  /// In fr, this message translates to:
  /// **'{hours, plural, =1{1 h restante} other{{hours} h restantes}}'**
  String liveHoursLeft(int hours);

  /// No description provided for @liveMinutesLeft.
  ///
  /// In fr, this message translates to:
  /// **'{minutes, plural, =1{1 min restante} other{{minutes} min restantes}}'**
  String liveMinutesLeft(int minutes);

  /// No description provided for @liveAlmostOver.
  ///
  /// In fr, this message translates to:
  /// **'bientôt terminé'**
  String get liveAlmostOver;

  /// No description provided for @liveLocation.
  ///
  /// In fr, this message translates to:
  /// **'En direct · {remaining}'**
  String liveLocation(String remaining);

  /// No description provided for @openInMaps.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir dans Maps'**
  String get openInMaps;

  /// No description provided for @composerEditPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la photo'**
  String get composerEditPhoto;

  /// No description provided for @composerEditorFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'éditeur n\'a pas pu s\'ouvrir.'**
  String get composerEditorFailed;

  /// No description provided for @composerCropRotate.
  ///
  /// In fr, this message translates to:
  /// **'Rogner ou pivoter'**
  String get composerCropRotate;

  /// No description provided for @composerCaptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une légende…'**
  String get composerCaptionHint;

  /// No description provided for @composerTo.
  ///
  /// In fr, this message translates to:
  /// **'à {name}'**
  String composerTo(String name);

  /// No description provided for @composerSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get composerSend;

  /// No description provided for @convOfflineNotCached.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — cette conversation n\'est pas encore en mémoire.'**
  String get convOfflineNotCached;

  /// No description provided for @convLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la conversation.'**
  String get convLoadFailed;

  /// No description provided for @convEmptyEdit.
  ///
  /// In fr, this message translates to:
  /// **'Un message vide ne peut pas remplacer un texte.'**
  String get convEmptyEdit;

  /// No description provided for @convEditFailed.
  ///
  /// In fr, this message translates to:
  /// **'Modification impossible — vérifie ta connexion.'**
  String get convEditFailed;

  /// No description provided for @convOrderUpdateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de mettre à jour la commande.'**
  String get convOrderUpdateFailed;

  /// No description provided for @convDeleteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer le message.'**
  String get convDeleteFailed;

  /// No description provided for @convForwardFailedMsg.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de transférer le message.'**
  String get convForwardFailedMsg;

  /// No description provided for @convOfflineAttachment.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — les pièces jointes exigent une connexion.'**
  String get convOfflineAttachment;

  /// No description provided for @convAttachmentFailed.
  ///
  /// In fr, this message translates to:
  /// **'Pièce jointe non envoyée — réessaie.'**
  String get convAttachmentFailed;

  /// No description provided for @groupOfflineNotCached.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — ce groupe n\'est pas encore en mémoire.'**
  String get groupOfflineNotCached;

  /// No description provided for @groupLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le groupe.'**
  String get groupLoadFailed;

  /// No description provided for @groupRenameFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de renommer le groupe.'**
  String get groupRenameFailed;

  /// No description provided for @groupPhotoFailed.
  ///
  /// In fr, this message translates to:
  /// **'Photo du groupe non enregistrée.'**
  String get groupPhotoFailed;

  /// No description provided for @groupClearPhotoFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de retirer la photo.'**
  String get groupClearPhotoFailed;

  /// No description provided for @groupRoleFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de changer ce rôle.'**
  String get groupRoleFailed;

  /// No description provided for @groupInviteCreateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer le lien d\'invitation.'**
  String get groupInviteCreateFailed;

  /// No description provided for @groupInviteRevokeFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de désactiver le lien.'**
  String get groupInviteRevokeFailed;

  /// No description provided for @groupLeaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de quitter le groupe.'**
  String get groupLeaveFailed;

  /// No description provided for @groupRemoveMemberFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de retirer ce membre.'**
  String get groupRemoveMemberFailed;

  /// No description provided for @apiNetworkSilent.
  ///
  /// In fr, this message translates to:
  /// **'Le réseau ne répond pas'**
  String get apiNetworkSilent;

  /// No description provided for @apiError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur ({code})'**
  String apiError(int code);

  /// No description provided for @orderProductDiscussed.
  ///
  /// In fr, this message translates to:
  /// **'Article discuté'**
  String get orderProductDiscussed;

  /// No description provided for @orderValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider la commande'**
  String get orderValidate;

  /// No description provided for @orderMarkShipped.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme expédié'**
  String get orderMarkShipped;

  /// No description provided for @orderMarkDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme livré'**
  String get orderMarkDelivered;

  /// No description provided for @orderBuyerWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Cet acheteur attend ta réponse.'**
  String get orderBuyerWaiting;

  /// No description provided for @orderNextStep.
  ///
  /// In fr, this message translates to:
  /// **'Étape suivante de la commande.'**
  String get orderNextStep;

  /// No description provided for @msgNotSentRetry.
  ///
  /// In fr, this message translates to:
  /// **'Non envoyé — toucher pour réessayer'**
  String get msgNotSentRetry;

  /// No description provided for @msgPendingSend.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'envoi'**
  String get msgPendingSend;

  /// No description provided for @convSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans {name}…'**
  String convSearchHint(String name);

  /// No description provided for @convSearchPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Tape un mot pour retrouver un message de cette discussion.'**
  String get convSearchPrompt;

  /// No description provided for @convSearchEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message trouvé.'**
  String get convSearchEmpty;

  /// No description provided for @commonUnknownName.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get commonUnknownName;

  /// No description provided for @groupInviteLink.
  ///
  /// In fr, this message translates to:
  /// **'Lien d\'invitation'**
  String get groupInviteLink;

  /// No description provided for @groupDemoteAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l\'administration'**
  String get groupDemoteAdmin;

  /// No description provided for @groupPromoteAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Nommer administrateur'**
  String get groupPromoteAdmin;

  /// No description provided for @groupInviteLinkBody.
  ///
  /// In fr, this message translates to:
  /// **'Toute personne qui ouvre ce lien rejoint le groupe directement, sans autre étape. Régénère-le pour invalider celui déjà partagé.'**
  String get groupInviteLinkBody;

  /// No description provided for @groupNewLinkCreated.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau lien créé — l\'ancien ne fonctionne plus.'**
  String get groupNewLinkCreated;

  /// No description provided for @groupAddFailed.
  ///
  /// In fr, this message translates to:
  /// **'Ajout impossible.'**
  String get groupAddFailed;

  /// No description provided for @groupCreateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Création du groupe impossible.'**
  String get groupCreateFailed;

  /// No description provided for @groupNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau groupe'**
  String get groupNewTitle;

  /// No description provided for @groupCreateAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get groupCreateAction;

  /// No description provided for @groupNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe'**
  String get groupNameHint;

  /// No description provided for @groupPickParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Choisis les participants'**
  String get groupPickParticipants;

  /// No description provided for @groupSelectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 participant sélectionné} other{{count} participants sélectionnés}}'**
  String groupSelectedCount(int count);

  /// No description provided for @pushIncomingVideoCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo entrant'**
  String get pushIncomingVideoCall;

  /// No description provided for @pushIncomingAudioCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio entrant'**
  String get pushIncomingAudioCall;

  /// No description provided for @pushAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get pushAnswer;

  /// No description provided for @pushDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get pushDecline;

  /// No description provided for @pushMessagesChannel.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get pushMessagesChannel;

  /// No description provided for @pushMessagesChannelDesc.
  ///
  /// In fr, this message translates to:
  /// **'Notifications pour les nouveaux messages Pokou'**
  String get pushMessagesChannelDesc;

  /// No description provided for @pushCallsChannel.
  ///
  /// In fr, this message translates to:
  /// **'Appels'**
  String get pushCallsChannel;

  /// No description provided for @pushCallsChannelDesc.
  ///
  /// In fr, this message translates to:
  /// **'Notifications pour les appels entrants Pokou'**
  String get pushCallsChannelDesc;

  /// No description provided for @pushGroupFallback.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get pushGroupFallback;

  /// No description provided for @notifNewMessage.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau message'**
  String get notifNewMessage;

  /// No description provided for @notifPhoto.
  ///
  /// In fr, this message translates to:
  /// **'📷 Photo'**
  String get notifPhoto;

  /// No description provided for @notifVideo.
  ///
  /// In fr, this message translates to:
  /// **'🎥 Vidéo'**
  String get notifVideo;

  /// No description provided for @notifVoice.
  ///
  /// In fr, this message translates to:
  /// **'🎤 Message vocal'**
  String get notifVoice;

  /// No description provided for @notifDocument.
  ///
  /// In fr, this message translates to:
  /// **'📄 Document'**
  String get notifDocument;

  /// No description provided for @notifSticker.
  ///
  /// In fr, this message translates to:
  /// **'Autocollant'**
  String get notifSticker;

  /// No description provided for @notifLocation.
  ///
  /// In fr, this message translates to:
  /// **'📍 Position'**
  String get notifLocation;

  /// No description provided for @notifContact.
  ///
  /// In fr, this message translates to:
  /// **'👤 Contact'**
  String get notifContact;

  /// No description provided for @notifPoll.
  ///
  /// In fr, this message translates to:
  /// **'📊 Sondage'**
  String get notifPoll;

  /// No description provided for @notifMe.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get notifMe;

  /// No description provided for @notifReply.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get notifReply;

  /// No description provided for @notifReplyHint.
  ///
  /// In fr, this message translates to:
  /// **'Ton message'**
  String get notifReplyHint;

  /// No description provided for @notifMarkRead.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme lu'**
  String get notifMarkRead;

  /// No description provided for @notifReplyQueued.
  ///
  /// In fr, this message translates to:
  /// **'envoi à l\'ouverture de Pokou'**
  String get notifReplyQueued;

  /// No description provided for @notifReplyFailed.
  ///
  /// In fr, this message translates to:
  /// **'Réponse non envoyée — ouvre Pokou pour réessayer'**
  String get notifReplyFailed;

  /// Résumé du groupe de notifications de message.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}} · {conversations, plural, =1{1 conversation} other{{conversations} conversations}}'**
  String notifSummary(int count, int conversations);

  /// No description provided for @audienceContacts.
  ///
  /// In fr, this message translates to:
  /// **'Mes contacts'**
  String get audienceContacts;

  /// No description provided for @audienceNobody.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get audienceNobody;

  /// No description provided for @audienceExcept.
  ///
  /// In fr, this message translates to:
  /// **'Mes contacts sauf…'**
  String get audienceExcept;

  /// No description provided for @audienceOnly.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement…'**
  String get audienceOnly;

  /// No description provided for @audienceContactsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les personnes de ton carnet Pokou'**
  String get audienceContactsDesc;

  /// No description provided for @audienceNobodyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tes statuts ne seront visibles que par toi'**
  String get audienceNobodyDesc;

  /// No description provided for @audienceExceptDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tes contacts, à l\'exception de ceux que tu choisis'**
  String get audienceExceptDesc;

  /// No description provided for @audienceOnlyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Seules les personnes que tu choisis'**
  String get audienceOnlyDesc;

  /// No description provided for @statusViewerFallback.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get statusViewerFallback;

  /// No description provided for @statusPrivacySaved.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité enregistrée.'**
  String get statusPrivacySaved;

  /// No description provided for @statusPrivacySaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible — vérifie ta connexion.'**
  String get statusPrivacySaveFailed;

  /// No description provided for @statusPrivacyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qui voit mes statuts'**
  String get statusPrivacyTitle;

  /// No description provided for @statusExcludePeople.
  ///
  /// In fr, this message translates to:
  /// **'Personnes à exclure'**
  String get statusExcludePeople;

  /// No description provided for @statusAllowedPeople.
  ///
  /// In fr, this message translates to:
  /// **'Personnes autorisées'**
  String get statusAllowedPeople;

  /// No description provided for @statusNoContactToOffer.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact Pokou à proposer pour le moment.'**
  String get statusNoContactToOffer;

  /// No description provided for @statusExceptFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Ces personnes ne verront pas tes statuts, même si elles sont dans tes contacts.'**
  String get statusExceptFootnote;

  /// No description provided for @statusOnlyFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Seules ces personnes verront tes statuts. Elles n\'ont pas besoin de t\'avoir en contact.'**
  String get statusOnlyFootnote;

  /// No description provided for @status24hFootnote.
  ///
  /// In fr, this message translates to:
  /// **'Un statut disparaît de toute façon au bout de 24 heures, pour tout le monde.'**
  String get status24hFootnote;

  /// No description provided for @statusGallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get statusGallery;

  /// No description provided for @statusCamera.
  ///
  /// In fr, this message translates to:
  /// **'Appareil photo'**
  String get statusCamera;

  /// No description provided for @statusNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau statut'**
  String get statusNewTitle;

  /// No description provided for @statusText.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get statusText;

  /// No description provided for @statusTypeHint.
  ///
  /// In fr, this message translates to:
  /// **'Tape ton statut…'**
  String get statusTypeHint;

  /// No description provided for @statusPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get statusPublish;

  /// No description provided for @statusFeedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Actualités'**
  String get statusFeedTitle;

  /// No description provided for @statusFeedUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Statuts indisponibles — réessayer'**
  String get statusFeedUnavailable;

  /// No description provided for @statusSection.
  ///
  /// In fr, this message translates to:
  /// **'Statuts'**
  String get statusSection;

  /// No description provided for @statusMine.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get statusMine;

  /// No description provided for @channelsSection.
  ///
  /// In fr, this message translates to:
  /// **'Chaînes'**
  String get channelsSection;

  /// No description provided for @bcastNeedName.
  ///
  /// In fr, this message translates to:
  /// **'Donne un nom à cette liste.'**
  String get bcastNeedName;

  /// No description provided for @bcastNeedRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Choisis au moins un destinataire.'**
  String get bcastNeedRecipient;

  /// No description provided for @bcastSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible.'**
  String get bcastSaveFailed;

  /// No description provided for @bcastNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle diffusion'**
  String get bcastNewTitle;

  /// No description provided for @bcastEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la liste'**
  String get bcastEditTitle;

  /// No description provided for @bcastNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la liste (visible par toi seul)'**
  String get bcastNameHint;

  /// No description provided for @bcastNoRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Aucun destinataire'**
  String get bcastNoRecipient;

  /// No description provided for @bcastRecipientCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 destinataire} other{{count} destinataires}}'**
  String bcastRecipientCount(int count);

  /// No description provided for @bcastContactsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Contacts indisponibles.'**
  String get bcastContactsUnavailable;

  /// No description provided for @bcastNobodyOnPokou.
  ///
  /// In fr, this message translates to:
  /// **'Aucun de tes contacts n\'est encore sur Pokou.'**
  String get bcastNobodyOnPokou;

  /// No description provided for @bcastNewList.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle liste'**
  String get bcastNewList;

  /// No description provided for @bcastListsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Listes de diffusion'**
  String get bcastListsTitle;

  /// No description provided for @bcastListsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Listes indisponibles.'**
  String get bcastListsUnavailable;

  /// No description provided for @bcastDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ?'**
  String bcastDeleteTitle(String name);

  /// No description provided for @bcastDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Les messages déjà envoyés restent chez leurs destinataires. Seule la liste disparaît.'**
  String get bcastDeleteBody;

  /// No description provided for @bcastEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annonce une fois, à plusieurs'**
  String get bcastEmptyTitle;

  /// No description provided for @bcastEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Chaque destinataire reçoit le message dans sa discussion privée. Il ne voit pas les autres, et ne répond qu\'à toi — contrairement à un groupe, où tout le monde se voit.'**
  String get bcastEmptyBody;

  /// No description provided for @bcastSentTo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Envoyé à 1 destinataire.} other{Envoyé à {count} destinataires.}}'**
  String bcastSentTo(int count);

  /// No description provided for @bcastSentPartly.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé à {sent} sur {total} — {skipped} ne reçoit plus tes messages.'**
  String bcastSentPartly(int sent, int total, int skipped);

  /// No description provided for @bcastSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'envoi a échoué.'**
  String get bcastSendFailed;

  /// No description provided for @bcastEditRecipients.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les destinataires'**
  String get bcastEditRecipients;

  /// No description provided for @bcastHistoryUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Historique indisponible.'**
  String get bcastHistoryUnavailable;

  /// No description provided for @bcastNothingSent.
  ///
  /// In fr, this message translates to:
  /// **'Rien n\'a encore été diffusé.'**
  String get bcastNothingSent;

  /// No description provided for @bcastMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Message à diffuser'**
  String get bcastMessageHint;

  /// No description provided for @bcastPrivacyNotice.
  ///
  /// In fr, this message translates to:
  /// **'Chaque destinataire reçoit ce message en privé. Il ne voit pas les autres, et sa réponse t\'arrive dans ta discussion avec lui.'**
  String get bcastPrivacyNotice;

  /// No description provided for @channelNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom de la chaîne est obligatoire.'**
  String get channelNameRequired;

  /// No description provided for @channelSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer la chaîne.'**
  String get channelSaveFailed;

  /// No description provided for @channelEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la chaîne'**
  String get channelEditTitle;

  /// No description provided for @channelNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle chaîne'**
  String get channelNewTitle;

  /// No description provided for @channelAddImage.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une image'**
  String get channelAddImage;

  /// No description provided for @channelChangeImage.
  ///
  /// In fr, this message translates to:
  /// **'Changer l\'image'**
  String get channelChangeImage;

  /// No description provided for @channelRemoveImage.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l\'image'**
  String get channelRemoveImage;

  /// No description provided for @channelNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la chaîne'**
  String get channelNameLabel;

  /// No description provided for @channelNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Actualités de mon entreprise'**
  String get channelNameHint;

  /// No description provided for @channelDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get channelDescriptionLabel;

  /// No description provided for @channelDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Présente ta chaîne'**
  String get channelDescriptionHint;

  /// No description provided for @channelSaveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get channelSaveChanges;

  /// No description provided for @channelCreateAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer la chaîne'**
  String get channelCreateAction;

  /// No description provided for @channelLinkCopiedClipboard.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié dans le presse-papiers.'**
  String get channelLinkCopiedClipboard;

  /// No description provided for @channelLinkUnavailableShort.
  ///
  /// In fr, this message translates to:
  /// **'Lien indisponible.'**
  String get channelLinkUnavailableShort;

  /// No description provided for @channelSearchTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une chaîne'**
  String get channelSearchTooltip;

  /// No description provided for @channelCreateTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Créer une chaîne'**
  String get channelCreateTooltip;

  /// No description provided for @channelEmptyHint.
  ///
  /// In fr, this message translates to:
  /// **'Crée une chaîne pour partager tes actualités.'**
  String get channelEmptyHint;

  /// No description provided for @channelGenerateLink.
  ///
  /// In fr, this message translates to:
  /// **'Générer un lien'**
  String get channelGenerateLink;

  /// No description provided for @channelEditTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get channelEditTooltip;

  /// No description provided for @channelSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une chaîne…'**
  String get channelSearchHint;

  /// No description provided for @channelSearchPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Cherche par nom ou par description. Les chaînes certifiées apparaissent en premier.'**
  String get channelSearchPrompt;

  /// No description provided for @channelSearchEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune chaîne trouvée.'**
  String get channelSearchEmpty;

  /// No description provided for @channelNothingPublishedAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Rien de publié pour l\'instant — touche + pour ta première publication.'**
  String get channelNothingPublishedAdmin;

  /// No description provided for @channelNothingPublished.
  ///
  /// In fr, this message translates to:
  /// **'Cette chaîne n\'a encore rien publié.'**
  String get channelNothingPublished;

  /// No description provided for @channelFollow.
  ///
  /// In fr, this message translates to:
  /// **'S\'abonner'**
  String get channelFollow;

  /// No description provided for @channelFallbackName.
  ///
  /// In fr, this message translates to:
  /// **'Chaîne'**
  String get channelFallbackName;

  /// No description provided for @communityNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle communauté'**
  String get communityNewTitle;

  /// No description provided for @communityNewBody.
  ///
  /// In fr, this message translates to:
  /// **'Une communauté regroupe plusieurs groupes autour des mêmes personnes. Un groupe « Annonces » est créé avec elle : toi seul y écris, tous ses membres y lisent.'**
  String get communityNewBody;

  /// No description provided for @communityNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la communauté'**
  String get communityNameHint;

  /// No description provided for @communityDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Description (facultatif)'**
  String get communityDescriptionHint;

  /// No description provided for @communityCreateAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get communityCreateAction;

  /// No description provided for @communityCreateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Création impossible.'**
  String get communityCreateFailed;

  /// No description provided for @communityNoGroupToAttach.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'as pas d\'autre groupe à rattacher. Seuls les groupes que tu administres peuvent rejoindre une communauté.'**
  String get communityNoGroupToAttach;

  /// No description provided for @communityAddGroupFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter ce groupe.'**
  String get communityAddGroupFailed;

  /// No description provided for @communityLinkFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer le lien.'**
  String get communityLinkFailed;

  /// No description provided for @communityCreateLink.
  ///
  /// In fr, this message translates to:
  /// **'Créer un lien'**
  String get communityCreateLink;

  /// No description provided for @sparkOpenRoomsSub.
  ///
  /// In fr, this message translates to:
  /// **'Elles se referment toutes seules'**
  String get sparkOpenRoomsSub;

  /// No description provided for @sparkMore.
  ///
  /// In fr, this message translates to:
  /// **'Suite'**
  String get sparkMore;

  /// No description provided for @sparkRoomOpen.
  ///
  /// In fr, this message translates to:
  /// **'Salle ouverte — {time}'**
  String sparkRoomOpen(String time);

  /// No description provided for @sparkBothYes.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez dit oui tous les deux'**
  String get sparkBothYes;

  /// No description provided for @sparkMatchSaved.
  ///
  /// In fr, this message translates to:
  /// **'Match sauvé'**
  String get sparkMatchSaved;

  /// No description provided for @sparkRoomClosed.
  ///
  /// In fr, this message translates to:
  /// **'Salle fermée'**
  String get sparkRoomClosed;

  /// No description provided for @sparkMatch.
  ///
  /// In fr, this message translates to:
  /// **'Match'**
  String get sparkMatch;

  /// No description provided for @sparkUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Spark est indisponible'**
  String get sparkUnavailable;

  /// No description provided for @sparkTodaysDate.
  ///
  /// In fr, this message translates to:
  /// **'Le rendez-vous d\'aujourd\'hui'**
  String get sparkTodaysDate;

  /// No description provided for @sparkTabOutings.
  ///
  /// In fr, this message translates to:
  /// **'Sorties'**
  String get sparkTabOutings;

  /// No description provided for @sparkPersonAge.
  ///
  /// In fr, this message translates to:
  /// **'{name}, {age}'**
  String sparkPersonAge(String name, int age);

  /// No description provided for @aiSuggestSummary.
  ///
  /// In fr, this message translates to:
  /// **'Résumé'**
  String get aiSuggestSummary;

  /// No description provided for @aiSuggestSummarySub.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble rapide'**
  String get aiSuggestSummarySub;

  /// No description provided for @aiSuggestSummaryPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Fais-moi un résumé de la situation actuelle.'**
  String get aiSuggestSummaryPrompt;

  /// No description provided for @aiSuggestTrend.
  ///
  /// In fr, this message translates to:
  /// **'Tendance'**
  String get aiSuggestTrend;

  /// No description provided for @aiSuggestTrendSub.
  ///
  /// In fr, this message translates to:
  /// **'Analyser une évolution'**
  String get aiSuggestTrendSub;

  /// No description provided for @aiSuggestTrendPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Quelle est la tendance sur les 7 derniers jours ?'**
  String get aiSuggestTrendPrompt;

  /// No description provided for @aiSuggestAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get aiSuggestAlerts;

  /// No description provided for @aiSuggestAlertsSub.
  ///
  /// In fr, this message translates to:
  /// **'Derniers signaux'**
  String get aiSuggestAlertsSub;

  /// No description provided for @aiSuggestAlertsPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Y a-t-il des alertes récentes à connaître ?'**
  String get aiSuggestAlertsPrompt;

  /// No description provided for @aiSuggestAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Conseil'**
  String get aiSuggestAdvice;

  /// No description provided for @aiSuggestAdviceSub.
  ///
  /// In fr, this message translates to:
  /// **'Demander une idée'**
  String get aiSuggestAdviceSub;

  /// No description provided for @aiSuggestAdvicePrompt.
  ///
  /// In fr, this message translates to:
  /// **'Donne-moi un conseil pour organiser ma journée.'**
  String get aiSuggestAdvicePrompt;

  /// No description provided for @aiSuggestWrite.
  ///
  /// In fr, this message translates to:
  /// **'Rédiger'**
  String get aiSuggestWrite;

  /// No description provided for @aiSuggestWriteSub.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un texte'**
  String get aiSuggestWriteSub;

  /// No description provided for @aiSuggestWritePrompt.
  ///
  /// In fr, this message translates to:
  /// **'Aide-moi à rédiger un message.'**
  String get aiSuggestWritePrompt;

  /// No description provided for @aiSuggestQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Question'**
  String get aiSuggestQuestion;

  /// No description provided for @aiSuggestQuestionSub.
  ///
  /// In fr, this message translates to:
  /// **'N\'importe quoi'**
  String get aiSuggestQuestionSub;

  /// No description provided for @aiSuggestQuestionPrompt.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai une question à te poser.'**
  String get aiSuggestQuestionPrompt;

  /// No description provided for @aiMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Message…'**
  String get aiMessageHint;

  /// No description provided for @aiHowCanIHelp.
  ///
  /// In fr, this message translates to:
  /// **'Comment puis-je t\'aider ?'**
  String get aiHowCanIHelp;

  /// No description provided for @aiAskAnything.
  ///
  /// In fr, this message translates to:
  /// **'Pose-moi n\'importe quelle question.'**
  String get aiAskAnything;

  /// No description provided for @aiAskAboutData.
  ///
  /// In fr, this message translates to:
  /// **'Pose une question sur tes données connectées.'**
  String get aiAskAboutData;

  /// No description provided for @aiThinking.
  ///
  /// In fr, this message translates to:
  /// **'Baba réfléchit'**
  String get aiThinking;

  /// No description provided for @aiHelloIm.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, je suis {name}'**
  String aiHelloIm(String name);

  /// No description provided for @aiPartner.
  ///
  /// In fr, this message translates to:
  /// **'Ton partenaire numérique'**
  String get aiPartner;

  /// No description provided for @aiGreetMorning.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get aiGreetMorning;

  /// No description provided for @aiGreetAfternoon.
  ///
  /// In fr, this message translates to:
  /// **'Bon après-midi'**
  String get aiGreetAfternoon;

  /// No description provided for @aiGreetEvening.
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir'**
  String get aiGreetEvening;

  /// No description provided for @aiNewChat.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle discussion'**
  String get aiNewChat;

  /// No description provided for @aiCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get aiCopy;

  /// No description provided for @aiCopied.
  ///
  /// In fr, this message translates to:
  /// **'Copié'**
  String get aiCopied;

  /// No description provided for @aiGenerated.
  ///
  /// In fr, this message translates to:
  /// **'Généré par l\'IA'**
  String get aiGenerated;

  /// No description provided for @aiVoiceListening.
  ///
  /// In fr, this message translates to:
  /// **'Je t\'écoute…'**
  String get aiVoiceListening;

  /// No description provided for @aiVoiceTranscribing.
  ///
  /// In fr, this message translates to:
  /// **'Transcription…'**
  String get aiVoiceTranscribing;

  /// No description provided for @aiVoiceFailed.
  ///
  /// In fr, this message translates to:
  /// **'Je n\'ai pas pu t\'entendre. Réessaie.'**
  String get aiVoiceFailed;

  /// No description provided for @aiVoiceSpeak.
  ///
  /// In fr, this message translates to:
  /// **'Parler à l\'assistant'**
  String get aiVoiceSpeak;

  /// No description provided for @aiVoiceRestart.
  ///
  /// In fr, this message translates to:
  /// **'Recommencer'**
  String get aiVoiceRestart;

  /// No description provided for @aiVoiceSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get aiVoiceSend;

  /// No description provided for @aiVoiceStop.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get aiVoiceStop;

  /// No description provided for @aiSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'Message non envoyé — réessaie.'**
  String get aiSendFailed;

  /// No description provided for @digestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Récap du jour'**
  String get digestTitle;

  /// No description provided for @digestUnread.
  ///
  /// In fr, this message translates to:
  /// **'Messages non lus :'**
  String get digestUnread;

  /// No description provided for @digestMissedCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels manqués :'**
  String get digestMissedCalls;

  /// No description provided for @digestVideoSuffix.
  ///
  /// In fr, this message translates to:
  /// **' (vidéo)'**
  String get digestVideoSuffix;

  /// No description provided for @digestShieldDeferred.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 message mis en attente par le Mode Bouclier.} other{{count} messages mis en attente par le Mode Bouclier.}}'**
  String digestShieldDeferred(int count);

  /// No description provided for @digestMonitorSignals.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 signal de tes moniteurs à consulter.} other{{count} signaux de tes moniteurs à consulter.}}'**
  String digestMonitorSignals(int count);

  /// No description provided for @digestNothing.
  ///
  /// In fr, this message translates to:
  /// **'Rien à signaler aujourd\'hui — bonne soirée !'**
  String get digestNothing;

  /// No description provided for @shieldUnknownNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro inconnu'**
  String get shieldUnknownNumber;

  /// No description provided for @shieldFlushSummary.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 message mis en attente pendant ta réunion.} other{{count} messages mis en attente pendant ta réunion.}}'**
  String shieldFlushSummary(int count);

  /// No description provided for @shieldPendingMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages en attente'**
  String get shieldPendingMessages;

  /// No description provided for @shieldHandleSemantic.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 message mis en attente par le Mode Bouclier — glisser vers le bas pour l\'afficher} other{{count} messages mis en attente par le Mode Bouclier — glisser vers le bas pour les afficher}}'**
  String shieldHandleSemantic(int count);

  /// No description provided for @shieldCallFrom.
  ///
  /// In fr, this message translates to:
  /// **'Appel de {name}'**
  String shieldCallFrom(Object name);

  /// No description provided for @shieldCallHeld.
  ///
  /// In fr, this message translates to:
  /// **'En attente — Mode Bouclier'**
  String get shieldCallHeld;

  /// No description provided for @statusViewersUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Liste des vues indisponible.'**
  String get statusViewersUnavailable;

  /// No description provided for @statusSeenBy.
  ///
  /// In fr, this message translates to:
  /// **'Vu par {count}'**
  String statusSeenBy(int count);

  /// No description provided for @statusNobodySeen.
  ///
  /// In fr, this message translates to:
  /// **'Personne ne l\'a encore vu.'**
  String get statusNobodySeen;

  /// No description provided for @statusBoostFailed.
  ///
  /// In fr, this message translates to:
  /// **'Boost du statut impossible.'**
  String get statusBoostFailed;

  /// No description provided for @statusDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce statut ?'**
  String get statusDeleteTitle;

  /// No description provided for @statusDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Il disparaîtra pour tous ceux qui peuvent le voir.'**
  String get statusDeleteBody;

  /// No description provided for @statusDeleteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible — vérifie ta connexion.'**
  String get statusDeleteFailed;

  /// No description provided for @statusPublishFailed.
  ///
  /// In fr, this message translates to:
  /// **'Publication impossible — vérifie ta connexion et réessaie.'**
  String get statusPublishFailed;

  /// No description provided for @statusBoostAction.
  ///
  /// In fr, this message translates to:
  /// **'Booster ce statut · 1 000 FCFA'**
  String get statusBoostAction;

  /// No description provided for @modulesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute ce qui te sert, laisse le reste'**
  String get modulesSubtitle;

  /// No description provided for @modulePaymentFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement n\'a pas pu être lancé.'**
  String get modulePaymentFailed;

  /// No description provided for @deeplinkFollowedChannel.
  ///
  /// In fr, this message translates to:
  /// **'Abonné à la chaîne « {name} »'**
  String deeplinkFollowedChannel(String name);

  /// No description provided for @deeplinkOpenFailed.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien d\'invitation n\'a pas pu être ouvert pour l\'instant.'**
  String get deeplinkOpenFailed;

  /// No description provided for @cropTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recadrer'**
  String get cropTitle;

  /// No description provided for @cropHint.
  ///
  /// In fr, this message translates to:
  /// **'Pince pour zoomer, glisse pour cadrer'**
  String get cropHint;

  /// No description provided for @cropConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get cropConfirm;

  /// No description provided for @inviteJoinMe.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins-moi sur Pokou Messenger'**
  String get inviteJoinMe;

  /// No description provided for @inviteJoinMeNamed.
  ///
  /// In fr, this message translates to:
  /// **'{name}, rejoins-moi sur Pokou Messenger'**
  String inviteJoinMeNamed(String name);

  /// No description provided for @otpNoCodeReceived.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'as pas reçu de code ?'**
  String get otpNoCodeReceived;

  /// No description provided for @countryDialCode.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif du pays'**
  String get countryDialCode;

  /// No description provided for @countrySearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Pays ou indicatif (ex. Bénin, 229)'**
  String get countrySearchHint;

  /// No description provided for @countryNoneFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pays trouvé.'**
  String get countryNoneFound;

  /// No description provided for @presenceSomeone.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu\'un'**
  String get presenceSomeone;

  /// No description provided for @atTime.
  ///
  /// In fr, this message translates to:
  /// **'à {time}'**
  String atTime(String time);

  /// No description provided for @dateAtTime.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {time}'**
  String dateAtTime(String date, String time);

  /// No description provided for @truthAskedTo.
  ///
  /// In fr, this message translates to:
  /// **'À {name}'**
  String truthAskedTo(String name);

  /// No description provided for @devicesNoPushHere.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil ne reçoit pas les notifications.'**
  String get devicesNoPushHere;

  /// No description provided for @devicesNoPushHereBody.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'a pas pu s\'enregistrer auprès du service de notifications. Touche pour réessayer.'**
  String get devicesNoPushHereBody;

  /// No description provided for @devicesRetryDone.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil reçoit désormais les notifications.'**
  String get devicesRetryDone;

  /// No description provided for @devicesRetryFailed.
  ///
  /// In fr, this message translates to:
  /// **'Toujours pas d\'enregistrement possible — réessaie plus tard.'**
  String get devicesRetryFailed;

  /// No description provided for @chatsProfileMissing.
  ///
  /// In fr, this message translates to:
  /// **'Profil indisponible — vérifie ta connexion, puis réessaie.'**
  String get chatsProfileMissing;

  /// No description provided for @recSlideToCancel.
  ///
  /// In fr, this message translates to:
  /// **'Glisse pour annuler'**
  String get recSlideToCancel;

  /// No description provided for @recReleaseToCancel.
  ///
  /// In fr, this message translates to:
  /// **'Relâcher pour annuler'**
  String get recReleaseToCancel;

  /// No description provided for @recLocked.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillé'**
  String get recLocked;

  /// No description provided for @recSlideUpToLock.
  ///
  /// In fr, this message translates to:
  /// **'Glisser vers le haut pour verrouiller'**
  String get recSlideUpToLock;

  /// No description provided for @recDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'enregistrement'**
  String get recDelete;

  /// No description provided for @recHoldToRecord.
  ///
  /// In fr, this message translates to:
  /// **'Maintenir pour enregistrer'**
  String get recHoldToRecord;

  /// No description provided for @composerViewOnce.
  ///
  /// In fr, this message translates to:
  /// **'Vue unique'**
  String get composerViewOnce;

  /// No description provided for @composerViewOnceOn.
  ///
  /// In fr, this message translates to:
  /// **'Vue unique activée — la photo disparaîtra après avoir été ouverte.'**
  String get composerViewOnceOn;

  /// No description provided for @composerViewOnceOff.
  ///
  /// In fr, this message translates to:
  /// **'Vue unique désactivée.'**
  String get composerViewOnceOff;

  /// No description provided for @channelSuggestedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Des chaînes à suivre'**
  String get channelSuggestedTitle;

  /// No description provided for @channelSuggestedBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'en suis aucune pour l\'instant. En voici quelques-unes.'**
  String get channelSuggestedBody;

  /// No description provided for @channelSuggestedNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune chaîne à proposer pour le moment.'**
  String get channelSuggestedNone;

  /// No description provided for @channelFollowed.
  ///
  /// In fr, this message translates to:
  /// **'Abonné à « {name} »'**
  String channelFollowed(String name);

  /// No description provided for @channelFollowFailed.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement impossible — vérifie ta connexion.'**
  String get channelFollowFailed;

  /// No description provided for @certifyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chaîne certifiée'**
  String get certifyTitle;

  /// No description provided for @certifyWhyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un badge, et la tête des suggestions'**
  String get certifyWhyTitle;

  /// No description provided for @certifyWhyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les chaînes certifiées apparaissent en premier à qui cherche quoi suivre, et le badge se voit sur chacune de tes publications.'**
  String get certifyWhyBody;

  /// No description provided for @certifyReviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un examen, pas un achat'**
  String get certifyReviewTitle;

  /// No description provided for @certifyReviewBody.
  ///
  /// In fr, this message translates to:
  /// **'Notre équipe lit ta chaîne avant d\'accorder le badge. Un badge qui s\'achète sans regard ne vaudrait rien — c\'est ce qui fait sa valeur.'**
  String get certifyReviewBody;

  /// No description provided for @certifyRefundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Refusée ? Tu es remboursé'**
  String get certifyRefundTitle;

  /// No description provided for @certifyRefundBody.
  ///
  /// In fr, this message translates to:
  /// **'Si le badge ne peut pas être accordé, contacte-nous : la somme t\'est rendue.'**
  String get certifyRefundBody;

  /// No description provided for @certifyRenewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un abonnement, pas un acquis'**
  String get certifyRenewTitle;

  /// No description provided for @certifyRenewBody.
  ///
  /// In fr, this message translates to:
  /// **'Le badge dure le temps de la formule choisie. Renouveler avant l\'échéance prolonge sans rien perdre.'**
  String get certifyRenewBody;

  /// No description provided for @certifyPlanMonthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel — 3 000 FCFA'**
  String get certifyPlanMonthly;

  /// No description provided for @certifyPlanAnnual.
  ///
  /// In fr, this message translates to:
  /// **'Annuel — 30 000 FCFA (deux mois offerts)'**
  String get certifyPlanAnnual;

  /// No description provided for @certifyAction.
  ///
  /// In fr, this message translates to:
  /// **'Payer et envoyer la demande'**
  String get certifyAction;

  /// No description provided for @certifyPending.
  ///
  /// In fr, this message translates to:
  /// **'Ta demande part à l\'équipe dès la confirmation du paiement.'**
  String get certifyPending;

  /// No description provided for @certifyFailed.
  ///
  /// In fr, this message translates to:
  /// **'Demande impossible — réessaie.'**
  String get certifyFailed;

  /// No description provided for @certifyAlready.
  ///
  /// In fr, this message translates to:
  /// **'Cette chaîne est certifiée'**
  String get certifyAlready;

  /// No description provided for @certifyTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Faire certifier cette chaîne'**
  String get certifyTooltip;

  /// No description provided for @chatsStartTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commence une discussion'**
  String get chatsStartTitle;

  /// No description provided for @chatsStartBody.
  ///
  /// In fr, this message translates to:
  /// **'Tes contacts sont déjà sur Pokou. Touche un nom pour lui écrire.'**
  String get chatsStartBody;

  /// No description provided for @chatsSeeAllContacts.
  ///
  /// In fr, this message translates to:
  /// **'Voir tous mes contacts'**
  String get chatsSeeAllContacts;

  /// No description provided for @chatsNoNetworkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tes proches ne sont pas encore sur Pokou'**
  String get chatsNoNetworkTitle;

  /// No description provided for @chatsNoNetworkBody.
  ///
  /// In fr, this message translates to:
  /// **'Invite quelqu\'un, ou suis une chaîne en attendant qu\'on te réponde.'**
  String get chatsNoNetworkBody;

  /// No description provided for @chatsInviteContacts.
  ///
  /// In fr, this message translates to:
  /// **'Inviter des contacts'**
  String get chatsInviteContacts;

  /// No description provided for @chatsDiscoverChannels.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir des chaînes'**
  String get chatsDiscoverChannels;

  /// No description provided for @e2eeEncrypted.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré de bout en bout'**
  String get e2eeEncrypted;

  /// No description provided for @e2eeNotEncrypted.
  ///
  /// In fr, this message translates to:
  /// **'Non chiffré'**
  String get e2eeNotEncrypted;

  /// No description provided for @e2eeNotEncryptedBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne doit mettre Pokou à jour pour le chiffrement.'**
  String get e2eeNotEncryptedBody;

  /// No description provided for @e2eeIdentityChangedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les informations de sécurité de ce contact ont changé'**
  String get e2eeIdentityChangedTitle;

  /// No description provided for @e2eeIdentityChangedBody.
  ///
  /// In fr, this message translates to:
  /// **'La clé de sécurité de {name} a changé (nouveau téléphone ou réinstallation). En cas de doute, vérifie avec {name}.'**
  String e2eeIdentityChangedBody(String name);

  /// No description provided for @e2eeIdentityAccept.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai vérifié, continuer'**
  String get e2eeIdentityAccept;

  /// No description provided for @e2eeBlockedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Message non envoyé'**
  String get e2eeBlockedTitle;

  /// No description provided for @e2eeBlockedLookup.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de récupérer la clé de chiffrement. Le message n\'a pas été envoyé — Pokou ne l\'enverra jamais en clair à ton insu.'**
  String get e2eeBlockedLookup;

  /// No description provided for @e2eeBlockedInvalid.
  ///
  /// In fr, this message translates to:
  /// **'La clé reçue est inexploitable. Le message n\'a pas été envoyé, par précaution.'**
  String get e2eeBlockedInvalid;

  /// No description provided for @e2eeBlockedIdentity.
  ///
  /// In fr, this message translates to:
  /// **'La clé de ce contact a changé. Vérifie son identité avant d\'envoyer.'**
  String get e2eeBlockedIdentity;

  /// No description provided for @e2eeBlockedCrypto.
  ///
  /// In fr, this message translates to:
  /// **'Le chiffrement a échoué. Le message n\'a pas été envoyé.'**
  String get e2eeBlockedCrypto;

  /// No description provided for @e2eeRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get e2eeRetry;

  /// No description provided for @profileTheme.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get profileTheme;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Comme le téléphone'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @themeHint.
  ///
  /// In fr, this message translates to:
  /// **'Le mode sombre repose les yeux le soir et économise la batterie sur les écrans OLED.'**
  String get themeHint;

  /// No description provided for @a11yBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get a11yBack;

  /// No description provided for @a11yRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get a11yRefresh;

  /// No description provided for @a11yMoreOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get a11yMoreOptions;

  /// No description provided for @a11yVoiceCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio'**
  String get a11yVoiceCall;

  /// No description provided for @a11yVideoCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo'**
  String get a11yVideoCall;

  /// No description provided for @a11yAttach.
  ///
  /// In fr, this message translates to:
  /// **'Joindre un fichier'**
  String get a11yAttach;

  /// No description provided for @a11yRate.
  ///
  /// In fr, this message translates to:
  /// **'Noter'**
  String get a11yRate;

  /// No description provided for @a11yAudioLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau sonore'**
  String get a11yAudioLevel;

  /// No description provided for @marketCreateAd.
  ///
  /// In fr, this message translates to:
  /// **'Créer une publicité'**
  String get marketCreateAd;

  /// No description provided for @adSponsored.
  ///
  /// In fr, this message translates to:
  /// **'Sponsorisé'**
  String get adSponsored;

  /// No description provided for @adYours.
  ///
  /// In fr, this message translates to:
  /// **'Ta publicité'**
  String get adYours;

  /// No description provided for @adContact.
  ///
  /// In fr, this message translates to:
  /// **'Contacter'**
  String get adContact;

  /// No description provided for @adContactFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de contacter l\'annonceur.'**
  String get adContactFailed;

  /// No description provided for @mediaSaveToPhone.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer sur le téléphone'**
  String get mediaSaveToPhone;

  /// No description provided for @mediaUndecryptable.
  ///
  /// In fr, this message translates to:
  /// **'Pièce jointe chiffrée illisible sur ce téléphone.'**
  String get mediaUndecryptable;

  /// No description provided for @mediaSaved.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré dans ta galerie'**
  String get mediaSaved;

  /// No description provided for @mediaExported.
  ///
  /// In fr, this message translates to:
  /// **'Choisis où l\'enregistrer'**
  String get mediaExported;

  /// No description provided for @mediaSavePermission.
  ///
  /// In fr, this message translates to:
  /// **'Pokou a besoin d\'accéder à tes photos pour enregistrer ce fichier.'**
  String get mediaSavePermission;

  /// No description provided for @mediaSaveNoSpace.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez d\'espace sur le téléphone.'**
  String get mediaSaveNoSpace;

  /// No description provided for @mediaSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible.'**
  String get mediaSaveFailed;

  /// No description provided for @composerEmoji.
  ///
  /// In fr, this message translates to:
  /// **'Emojis'**
  String get composerEmoji;

  /// No description provided for @convAttachGif.
  ///
  /// In fr, this message translates to:
  /// **'GIF'**
  String get convAttachGif;

  /// No description provided for @stickerTabEmoji.
  ///
  /// In fr, this message translates to:
  /// **'Emoji'**
  String get stickerTabEmoji;

  /// No description provided for @stickerTabStickers.
  ///
  /// In fr, this message translates to:
  /// **'Stickers'**
  String get stickerTabStickers;

  /// No description provided for @stickerSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un sticker'**
  String get stickerSearchHint;

  /// No description provided for @stickerRecents.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get stickerRecents;

  /// No description provided for @stickerFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get stickerFavorites;

  /// No description provided for @stickerNoResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sticker trouvé'**
  String get stickerNoResult;

  /// No description provided for @stickerEmptyPanel.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sticker pour l\'instant'**
  String get stickerEmptyPanel;

  /// No description provided for @stickerBrowsePacks.
  ///
  /// In fr, this message translates to:
  /// **'Parcourir les packs'**
  String get stickerBrowsePacks;

  /// No description provided for @stickerManagePacks.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les packs'**
  String get stickerManagePacks;

  /// No description provided for @stickerPacksTitle.
  ///
  /// In fr, this message translates to:
  /// **'Packs de stickers'**
  String get stickerPacksTitle;

  /// No description provided for @stickerPackAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get stickerPackAdd;

  /// No description provided for @stickerPackAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté'**
  String get stickerPackAdded;

  /// No description provided for @stickerPackRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get stickerPackRemove;

  /// No description provided for @stickerPackDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le pack'**
  String get stickerPackDelete;

  /// No description provided for @stickerPackDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce pack et tous ses stickers ?'**
  String get stickerPackDeleteConfirm;

  /// No description provided for @stickerMyPackName.
  ///
  /// In fr, this message translates to:
  /// **'Mes stickers'**
  String get stickerMyPackName;

  /// No description provided for @stickerCreateFromPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Créer depuis une photo'**
  String get stickerCreateFromPhoto;

  /// No description provided for @stickerCreated.
  ///
  /// In fr, this message translates to:
  /// **'Sticker ajouté à tes stickers'**
  String get stickerCreated;

  /// No description provided for @stickerLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Ton pack personnel est plein'**
  String get stickerLimitReached;

  /// No description provided for @stickerSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'Sticker non envoyé — réessaie'**
  String get stickerSendFailed;

  /// No description provided for @stickerLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sticker'**
  String get stickerLabel;

  /// No description provided for @stickerFavoriteAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté aux favoris'**
  String get stickerFavoriteAdded;

  /// No description provided for @stickerFavoriteRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Retiré des favoris'**
  String get stickerFavoriteRemoved;

  /// No description provided for @stickerStoreEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pack disponible pour l\'instant'**
  String get stickerStoreEmpty;

  /// No description provided for @stickerSaveToMine.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à mes stickers'**
  String get stickerSaveToMine;

  /// No description provided for @stickerSaved.
  ///
  /// In fr, this message translates to:
  /// **'Sticker ajouté à tes stickers'**
  String get stickerSaved;

  /// No description provided for @navBaba.
  ///
  /// In fr, this message translates to:
  /// **'Baba'**
  String get navBaba;

  /// No description provided for @appBarOnline.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get appBarOnline;

  /// No description provided for @appBarOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get appBarOffline;

  /// No description provided for @marketNegotiate.
  ///
  /// In fr, this message translates to:
  /// **'Négocier'**
  String get marketNegotiate;

  /// No description provided for @callsCallBack.
  ///
  /// In fr, this message translates to:
  /// **'Rappeler'**
  String get callsCallBack;

  /// No description provided for @callsFilterMissed.
  ///
  /// In fr, this message translates to:
  /// **'Manqués'**
  String get callsFilterMissed;

  /// No description provided for @callsFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get callsFilterAll;

  /// No description provided for @chatsFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get chatsFilterAll;

  /// No description provided for @chatsFilterUnread.
  ///
  /// In fr, this message translates to:
  /// **'Non lues'**
  String get chatsFilterUnread;

  /// No description provided for @chatsFilterGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get chatsFilterGroups;

  /// No description provided for @chatsSearchOrAsk.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher ou demander à Baba…'**
  String get chatsSearchOrAsk;

  /// No description provided for @convEncryptedHint.
  ///
  /// In fr, this message translates to:
  /// **'Message chiffré…'**
  String get convEncryptedHint;

  /// No description provided for @chatsArchivedSection.
  ///
  /// In fr, this message translates to:
  /// **'Discussions archivées'**
  String get chatsArchivedSection;

  /// No description provided for @statusMineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon Actu'**
  String get statusMineTitle;

  /// No description provided for @statusMineBody.
  ///
  /// In fr, this message translates to:
  /// **'Touche pour ajouter un statut'**
  String get statusMineBody;

  /// No description provided for @statusMineVisibility.
  ///
  /// In fr, this message translates to:
  /// **'Visible par : Mes contacts'**
  String get statusMineVisibility;

  /// No description provided for @callLeaveConference.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la conférence'**
  String get callLeaveConference;

  /// No description provided for @callQualityExcellent.
  ///
  /// In fr, this message translates to:
  /// **'Excellent'**
  String get callQualityExcellent;

  /// No description provided for @callQualityGood.
  ///
  /// In fr, this message translates to:
  /// **'Correct'**
  String get callQualityGood;

  /// No description provided for @callQualityPoor.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get callQualityPoor;

  /// No description provided for @callYouShort.
  ///
  /// In fr, this message translates to:
  /// **'Toi'**
  String get callYouShort;

  /// No description provided for @callMutedShort.
  ///
  /// In fr, this message translates to:
  /// **'Coupé'**
  String get callMutedShort;

  /// No description provided for @callMuteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Micro'**
  String get callMuteLabel;

  /// No description provided for @callCameraLabel.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get callCameraLabel;

  /// No description provided for @callSpeakerLabel.
  ///
  /// In fr, this message translates to:
  /// **'Haut-parleur'**
  String get callSpeakerLabel;

  /// No description provided for @callFlipCamera.
  ///
  /// In fr, this message translates to:
  /// **'Retourner la caméra'**
  String get callFlipCamera;

  /// No description provided for @callFlipCameraFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de changer de caméra.'**
  String get callFlipCameraFailed;

  /// No description provided for @callNoAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réponse.'**
  String get callNoAnswer;

  /// No description provided for @callOngoingBanner.
  ///
  /// In fr, this message translates to:
  /// **'Appel en cours · {duration} — toucher pour revenir'**
  String callOngoingBanner(String duration);

  /// No description provided for @callOngoingBannerRinging.
  ///
  /// In fr, this message translates to:
  /// **'Appel en cours — toucher pour revenir'**
  String get callOngoingBannerRinging;

  /// No description provided for @callHangUp.
  ///
  /// In fr, this message translates to:
  /// **'Raccrocher'**
  String get callHangUp;

  /// No description provided for @callInviteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get callInviteLabel;

  /// No description provided for @e2eeReassurance.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré de bout en bout : personne d’autre, pas même Pokou, ne peut lire ces messages.'**
  String get e2eeReassurance;

  /// No description provided for @chatsEncryptionFooter.
  ///
  /// In fr, this message translates to:
  /// **'Tes discussions sont chiffrées de bout en bout.'**
  String get chatsEncryptionFooter;

  /// No description provided for @callsRecentSection.
  ///
  /// In fr, this message translates to:
  /// **'RÉCENTS'**
  String get callsRecentSection;

  /// No description provided for @callsGroupChip.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get callsGroupChip;

  /// No description provided for @callGroupNotEncrypted.
  ///
  /// In fr, this message translates to:
  /// **'Appel de groupe standard — non chiffré de bout en bout'**
  String get callGroupNotEncrypted;

  /// No description provided for @marketCatalogueSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get marketCatalogueSeeAll;

  /// No description provided for @marketCatalogueOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir mon catalogue'**
  String get marketCatalogueOpen;

  /// No description provided for @marketCatalogueTotal.
  ///
  /// In fr, this message translates to:
  /// **'Annonces'**
  String get marketCatalogueTotal;

  /// No description provided for @marketCatalogueOnline.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get marketCatalogueOnline;

  /// No description provided for @marketCatalogueBoostedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Boostées'**
  String get marketCatalogueBoostedLabel;

  /// No description provided for @marketCatalogueWithdrawn.
  ///
  /// In fr, this message translates to:
  /// **'Retirées'**
  String get marketCatalogueWithdrawn;

  /// No description provided for @marketFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get marketFilterAll;

  /// No description provided for @marketCertifiedSellers.
  ///
  /// In fr, this message translates to:
  /// **'Vendeurs certifiés'**
  String get marketCertifiedSellers;

  /// No description provided for @marketCatalogueNoneInFilter.
  ///
  /// In fr, this message translates to:
  /// **'Aucune annonce dans ce filtre.'**
  String get marketCatalogueNoneInFilter;

  /// No description provided for @marketStatusModerated.
  ///
  /// In fr, this message translates to:
  /// **'Retirée du marché'**
  String get marketStatusModerated;

  /// No description provided for @marketStatusModeratedBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle n\'est plus visible par les acheteurs. Écris au support si tu penses que c\'est une erreur.'**
  String get marketStatusModeratedBody;

  /// No description provided for @callsFilterDirect.
  ///
  /// In fr, this message translates to:
  /// **'En tête-à-tête'**
  String get callsFilterDirect;

  /// No description provided for @profileMyAccount.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get profileMyAccount;

  /// No description provided for @profileVerifyAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier mon compte'**
  String get profileVerifyAccount;

  /// No description provided for @profileVerifyAccountBody.
  ///
  /// In fr, this message translates to:
  /// **'Obtiens le badge vendeur vérifié d\'Assimé'**
  String get profileVerifyAccountBody;

  /// No description provided for @profileCertificationPending.
  ///
  /// In fr, this message translates to:
  /// **'Certification en cours'**
  String get profileCertificationPending;

  /// No description provided for @profileCertificationPendingBody.
  ///
  /// In fr, this message translates to:
  /// **'Ta demande est en cours d\'examen.'**
  String get profileCertificationPendingBody;

  /// No description provided for @profileCertificationActive.
  ///
  /// In fr, this message translates to:
  /// **'Compte certifié'**
  String get profileCertificationActive;

  /// No description provided for @profileCertificationActiveBody.
  ///
  /// In fr, this message translates to:
  /// **'Le badge de certification apparaît à côté de votre nom.'**
  String get profileCertificationActiveBody;

  /// No description provided for @profileSellerCertified.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur vérifié'**
  String get profileSellerCertified;

  /// No description provided for @profileSellerCertifiedUntil.
  ///
  /// In fr, this message translates to:
  /// **'Badge vendeur actif jusqu\'au {date}.'**
  String profileSellerCertifiedUntil(String date);

  /// No description provided for @verifPlanLabel.
  ///
  /// In fr, this message translates to:
  /// **'Choisis ta formule'**
  String get verifPlanLabel;

  /// No description provided for @callEventAudio.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio'**
  String get callEventAudio;

  /// No description provided for @callEventVideo.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo'**
  String get callEventVideo;

  /// No description provided for @callEventGroup.
  ///
  /// In fr, this message translates to:
  /// **'Appel de groupe'**
  String get callEventGroup;

  /// No description provided for @callEventMissed.
  ///
  /// In fr, this message translates to:
  /// **'Appel manqué'**
  String get callEventMissed;

  /// No description provided for @callEventNoAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse'**
  String get callEventNoAnswer;

  /// No description provided for @callEventDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get callEventDeclined;

  /// No description provided for @callEventYouDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Tu as refusé'**
  String get callEventYouDeclined;

  /// No description provided for @callEventEnded.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get callEventEnded;

  /// No description provided for @callEventSeconds.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 s} other{{count} s}}'**
  String callEventSeconds(num count);

  /// No description provided for @callEventMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 min} other{{count} min}}'**
  String callEventMinutes(num count);

  /// No description provided for @callEventHours.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h {minutes}'**
  String callEventHours(Object hours, Object minutes);

  /// No description provided for @callEventParticipants.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 participant} other{{count} participants}}'**
  String callEventParticipants(num count);

  /// No description provided for @mediaCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel'**
  String get mediaCall;

  /// No description provided for @mediaSticker.
  ///
  /// In fr, this message translates to:
  /// **'Sticker'**
  String get mediaSticker;

  /// No description provided for @identityVerifiedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte certifié'**
  String get identityVerifiedAccount;

  /// No description provided for @privacyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get privacyTitle;

  /// No description provided for @privacyIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ces réglages sont appliqués par le serveur : ce que tu masques n\'est pas envoyé aux autres, pas seulement caché dans l\'application.'**
  String get privacyIntro;

  /// No description provided for @privacySectionWhoSees.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut voir mes informations'**
  String get privacySectionWhoSees;

  /// No description provided for @privacySectionMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get privacySectionMessages;

  /// No description provided for @privacySectionGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get privacySectionGroups;

  /// No description provided for @privacyLastSeen.
  ///
  /// In fr, this message translates to:
  /// **'Dernière activité'**
  String get privacyLastSeen;

  /// No description provided for @privacyLastSeenBody.
  ///
  /// In fr, this message translates to:
  /// **'À quelle heure tu étais connecté pour la dernière fois.'**
  String get privacyLastSeenBody;

  /// No description provided for @privacyOnline.
  ///
  /// In fr, this message translates to:
  /// **'Présence en ligne'**
  String get privacyOnline;

  /// No description provided for @privacyOnlineBody.
  ///
  /// In fr, this message translates to:
  /// **'Le point vert qui dit que tu es joignable maintenant. Indépendant de la dernière activité.'**
  String get privacyOnlineBody;

  /// No description provided for @privacyProfilePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get privacyProfilePhoto;

  /// No description provided for @privacyProfilePhotoBody.
  ///
  /// In fr, this message translates to:
  /// **'Ta photo, partout où elle apparaît.'**
  String get privacyProfilePhotoBody;

  /// No description provided for @privacyProfileInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations du profil'**
  String get privacyProfileInfo;

  /// No description provided for @privacyProfileInfoBody.
  ///
  /// In fr, this message translates to:
  /// **'Ta description et ce que tu as renseigné sur toi.'**
  String get privacyProfileInfoBody;

  /// No description provided for @privacyReadReceipts.
  ///
  /// In fr, this message translates to:
  /// **'Confirmations de lecture'**
  String get privacyReadReceipts;

  /// No description provided for @privacyReadReceiptsBody.
  ///
  /// In fr, this message translates to:
  /// **'Les désactiver te prive aussi de celles des autres. Les accusés de réception (une coche) restent visibles.'**
  String get privacyReadReceiptsBody;

  /// No description provided for @privacyGroupInvites.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut m\'inviter dans un groupe'**
  String get privacyGroupInvites;

  /// No description provided for @privacyGroupInvitesBody.
  ///
  /// In fr, this message translates to:
  /// **'Les autres t’envoient une invitation : tu gardes le dernier mot sur chacune.'**
  String get privacyGroupInvitesBody;

  /// No description provided for @privacyGroupMembership.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité de mon appartenance aux groupes'**
  String get privacyGroupMembership;

  /// No description provided for @privacyGroupMembershipBody.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut voir dans quels groupes tu es. Les membres d\'un groupe continuent de se connaître entre eux.'**
  String get privacyGroupMembershipBody;

  /// No description provided for @privacyEveryone.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde'**
  String get privacyEveryone;

  /// No description provided for @privacyMyContacts.
  ///
  /// In fr, this message translates to:
  /// **'Mes contacts'**
  String get privacyMyContacts;

  /// No description provided for @privacyNobody.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get privacyNobody;

  /// No description provided for @privacySaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Réglage non enregistré — réessaie.'**
  String get privacySaveFailed;

  /// No description provided for @privacyUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Réglages de confidentialité indisponibles.'**
  String get privacyUnavailable;

  /// No description provided for @privacyStatusesNote.
  ///
  /// In fr, this message translates to:
  /// **'La confidentialité des statuts se règle depuis l\'onglet Statuts, où tu peux aussi exclure des personnes précises.'**
  String get privacyStatusesNote;

  /// No description provided for @groupInvitesSent.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune invitation envoyée} =1{Invitation envoyée} other{{count} invitations envoyées}}'**
  String groupInvitesSent(num count);

  /// No description provided for @groupInvitationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Invitation à un groupe'**
  String get groupInvitationTitle;

  /// No description provided for @groupInvitationFrom.
  ///
  /// In fr, this message translates to:
  /// **'{name} t\'invite'**
  String groupInvitationFrom(Object name);

  /// No description provided for @groupInvitationMembers.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 membre} other{{count} membres}}'**
  String groupInvitationMembers(num count);

  /// No description provided for @groupInvitationAccept.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get groupInvitationAccept;

  /// No description provided for @groupInvitationReject.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get groupInvitationReject;

  /// No description provided for @groupInvitationExpires.
  ///
  /// In fr, this message translates to:
  /// **'Expire dans {hours} h'**
  String groupInvitationExpires(Object hours);

  /// No description provided for @groupInvitationExpiresSoon.
  ///
  /// In fr, this message translates to:
  /// **'Expire bientôt'**
  String get groupInvitationExpiresSoon;

  /// No description provided for @groupInvitationsHeader.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 invitation} other{{count} invitations}}'**
  String groupInvitationsHeader(num count);

  /// No description provided for @groupInvitationFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible — l\'invitation n\'est peut-être plus valable.'**
  String get groupInvitationFailed;

  /// No description provided for @mediaStatePreparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation…'**
  String get mediaStatePreparing;

  /// No description provided for @mediaStateSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get mediaStateSending;

  /// No description provided for @mediaStateSendingPercent.
  ///
  /// In fr, this message translates to:
  /// **'Envoi · {percent} %'**
  String mediaStateSendingPercent(Object percent);

  /// No description provided for @mediaStateWaitingNetwork.
  ///
  /// In fr, this message translates to:
  /// **'En attente de connexion'**
  String get mediaStateWaitingNetwork;

  /// No description provided for @mediaStateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Envoi impossible'**
  String get mediaStateFailed;

  /// No description provided for @mediaStateFileGone.
  ///
  /// In fr, this message translates to:
  /// **'Fichier introuvable sur cet appareil'**
  String get mediaStateFileGone;

  /// No description provided for @channelPrivateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Chaîne privée'**
  String get channelPrivateLabel;

  /// No description provided for @channelPrivateBody.
  ///
  /// In fr, this message translates to:
  /// **'Introuvable par la recherche. Seules les personnes à qui tu donnes le lien peuvent la rejoindre et lire ses publications. Ce choix ne pourra pas être modifié ensuite.'**
  String get channelPrivateBody;

  /// No description provided for @channelPrivateBadge.
  ///
  /// In fr, this message translates to:
  /// **'Privée'**
  String get channelPrivateBadge;

  /// No description provided for @mahizuConnectTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecte ton compte Mahizu'**
  String get mahizuConnectTitle;

  /// No description provided for @mahizuConnectBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'assistant est un service Mahizu, distinct de Pokou. Pour l\'utiliser, rattache ton compte Mahizu : un code sera envoyé au {phone}.'**
  String mahizuConnectBody(String phone);

  /// No description provided for @mahizuSendCode.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir le code'**
  String get mahizuSendCode;

  /// No description provided for @mahizuCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code reçu'**
  String get mahizuCodeLabel;

  /// No description provided for @mahizuPinLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code de ton compte Mahizu'**
  String get mahizuPinLabel;

  /// No description provided for @mahizuConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Connecter'**
  String get mahizuConfirm;

  /// No description provided for @mahizuRestart.
  ///
  /// In fr, this message translates to:
  /// **'Recommencer'**
  String get mahizuRestart;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navKory.
  ///
  /// In fr, this message translates to:
  /// **'Kory'**
  String get navKory;

  /// No description provided for @navMore.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get navMore;

  /// No description provided for @homeGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get homeSeeAll;

  /// No description provided for @homeNoChats.
  ///
  /// In fr, this message translates to:
  /// **'Aucune discussion pour l\'instant'**
  String get homeNoChats;

  /// No description provided for @homeKoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune cagnotte en cours'**
  String get homeKoryEmpty;

  /// No description provided for @homeSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une discussion'**
  String get homeSearchHint;

  /// No description provided for @moreCertifiedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pokou certifié'**
  String get moreCertifiedTitle;

  /// No description provided for @moreCertifiedBody.
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée et mode preuve : bientôt disponible.'**
  String get moreCertifiedBody;

  /// No description provided for @moreSectionServices.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get moreSectionServices;

  /// No description provided for @moreSectionSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get moreSectionSettings;

  /// No description provided for @moreAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte et sécurité'**
  String get moreAccount;

  /// No description provided for @moreEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get moreEdit;

  /// No description provided for @koryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Kory'**
  String get koryTitle;

  /// No description provided for @korySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Cagnottes & tontines'**
  String get korySubtitle;

  /// No description provided for @koryMyPots.
  ///
  /// In fr, this message translates to:
  /// **'Mes cagnottes'**
  String get koryMyPots;

  /// No description provided for @koryMonthTotal.
  ///
  /// In fr, this message translates to:
  /// **'Mes contributions confirmées ce mois-ci'**
  String get koryMonthTotal;

  /// No description provided for @koryNoMoney.
  ///
  /// In fr, this message translates to:
  /// **'Pokou ne touche pas l\'argent : il va directement de ton wallet à celui du collecteur.'**
  String get koryNoMoney;

  /// No description provided for @koryCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer une cagnotte'**
  String get koryCreate;

  /// No description provided for @koryJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get koryJoin;

  /// No description provided for @koryJournalTab.
  ///
  /// In fr, this message translates to:
  /// **'Journal'**
  String get koryJournalTab;

  /// No description provided for @koryJoinTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre avec un code'**
  String get koryJoinTitle;

  /// No description provided for @koryJoinHint.
  ///
  /// In fr, this message translates to:
  /// **'Code de la cagnotte'**
  String get koryJoinHint;

  /// No description provided for @koryJoinUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Code inconnu ou cagnotte clôturée.'**
  String get koryJoinUnknown;

  /// No description provided for @koryNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune cagnotte en cours'**
  String get koryNone;

  /// No description provided for @koryNoneBody.
  ///
  /// In fr, this message translates to:
  /// **'Crée une cagnotte pour un mariage, un baptême ou une cotisation, ou rejoins-en une avec son code.'**
  String get koryNoneBody;

  /// No description provided for @koryUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Kory est indisponible'**
  String get koryUnavailable;

  /// No description provided for @koryKindCagnotte.
  ///
  /// In fr, this message translates to:
  /// **'Cagnotte'**
  String get koryKindCagnotte;

  /// No description provided for @koryKindCotisation.
  ///
  /// In fr, this message translates to:
  /// **'Cotisation'**
  String get koryKindCotisation;

  /// No description provided for @koryTotalConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Total confirmé'**
  String get koryTotalConfirmed;

  /// No description provided for @koryGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif : {amount}'**
  String koryGoal(String amount);

  /// No description provided for @koryDue.
  ///
  /// In fr, this message translates to:
  /// **'Échéance : {date}'**
  String koryDue(String date);

  /// No description provided for @koryMyShare.
  ///
  /// In fr, this message translates to:
  /// **'Ma part confirmée : {amount}'**
  String koryMyShare(String amount);

  /// No description provided for @koryToReview.
  ///
  /// In fr, this message translates to:
  /// **'À confirmer : {count}'**
  String koryToReview(String count);

  /// No description provided for @koryClosed.
  ///
  /// In fr, this message translates to:
  /// **'Clôturée'**
  String get koryClosed;

  /// No description provided for @koryOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouverte'**
  String get koryOpen;

  /// No description provided for @koryCollector.
  ///
  /// In fr, this message translates to:
  /// **'Collecteur : {name}'**
  String koryCollector(String name);

  /// No description provided for @koryPayTo.
  ///
  /// In fr, this message translates to:
  /// **'Envoie ta contribution depuis ton wallet au {phone}, puis déclare-la ici.'**
  String koryPayTo(String phone);

  /// No description provided for @koryPerMember.
  ///
  /// In fr, this message translates to:
  /// **'{amount} par membre, {period}'**
  String koryPerMember(String amount, String period);

  /// No description provided for @koryDeclare.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai contribué'**
  String get koryDeclare;

  /// No description provided for @koryDeclareTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer ma contribution'**
  String get koryDeclareTitle;

  /// No description provided for @koryAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant (FCFA)'**
  String get koryAmount;

  /// No description provided for @koryWalletRef.
  ///
  /// In fr, this message translates to:
  /// **'Référence de la transaction (facultatif)'**
  String get koryWalletRef;

  /// No description provided for @koryWalletRefHelp.
  ///
  /// In fr, this message translates to:
  /// **'Elle figure dans le SMS de ton opérateur. Seuls toi et le collecteur la voyez.'**
  String get koryWalletRefHelp;

  /// No description provided for @koryNote.
  ///
  /// In fr, this message translates to:
  /// **'Message (facultatif)'**
  String get koryNote;

  /// No description provided for @koryPeriodLabel.
  ///
  /// In fr, this message translates to:
  /// **'Période couverte (ex. 2026-11)'**
  String get koryPeriodLabel;

  /// No description provided for @koryJournal.
  ///
  /// In fr, this message translates to:
  /// **'Journal des contributions'**
  String get koryJournal;

  /// No description provided for @koryJournalEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune contribution déclarée pour l\'instant.'**
  String get koryJournalEmpty;

  /// No description provided for @koryStatusDeclared.
  ///
  /// In fr, this message translates to:
  /// **'En attente du collecteur'**
  String get koryStatusDeclared;

  /// No description provided for @koryStatusConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmée'**
  String get koryStatusConfirmed;

  /// No description provided for @koryStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Contestée'**
  String get koryStatusRejected;

  /// No description provided for @koryConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get koryConfirm;

  /// No description provided for @koryReject.
  ///
  /// In fr, this message translates to:
  /// **'Pas reçu'**
  String get koryReject;

  /// No description provided for @koryCloseAction.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get koryCloseAction;

  /// No description provided for @koryCloseConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer la cagnotte ? Plus personne ne pourra déclarer de contribution.'**
  String get koryCloseConfirm;

  /// No description provided for @koryShareCode.
  ///
  /// In fr, this message translates to:
  /// **'Code : {code}'**
  String koryShareCode(String code);

  /// No description provided for @koryShareText.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins la cagnotte « {title} » sur Pokou avec le code {code}.'**
  String koryShareText(String title, String code);

  /// No description provided for @koryCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle collecte'**
  String get koryCreateTitle;

  /// No description provided for @koryFieldTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get koryFieldTitle;

  /// No description provided for @koryFieldDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description (facultatif)'**
  String get koryFieldDescription;

  /// No description provided for @koryFieldGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif en FCFA (facultatif)'**
  String get koryFieldGoal;

  /// No description provided for @koryFieldPerMember.
  ///
  /// In fr, this message translates to:
  /// **'Montant par membre (FCFA)'**
  String get koryFieldPerMember;

  /// No description provided for @koryPeriodMonthly.
  ///
  /// In fr, this message translates to:
  /// **'chaque mois'**
  String get koryPeriodMonthly;

  /// No description provided for @koryPeriodWeekly.
  ///
  /// In fr, this message translates to:
  /// **'chaque semaine'**
  String get koryPeriodWeekly;

  /// No description provided for @koryFieldDue.
  ///
  /// In fr, this message translates to:
  /// **'Échéance (facultatif)'**
  String get koryFieldDue;

  /// No description provided for @koryNeedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Donne un titre (3 caractères au moins).'**
  String get koryNeedTitle;

  /// No description provided for @koryNeedAmount.
  ///
  /// In fr, this message translates to:
  /// **'Indique un montant d\'au moins 100 FCFA.'**
  String get koryNeedAmount;

  /// No description provided for @koryCollectorIsYou.
  ///
  /// In fr, this message translates to:
  /// **'Tu es le collecteur : les contributions arrivent sur ton wallet, et c\'est toi qui les confirmes.'**
  String get koryCollectorIsYou;

  /// No description provided for @koryYou.
  ///
  /// In fr, this message translates to:
  /// **'Toi'**
  String get koryYou;

  /// No description provided for @koryTontinePlus.
  ///
  /// In fr, this message translates to:
  /// **'Tontine en rotation : bientôt avec Kory Plus'**
  String get koryTontinePlus;

  /// No description provided for @koryDeclared.
  ///
  /// In fr, this message translates to:
  /// **'Contribution déclarée. Le collecteur va la confirmer.'**
  String get koryDeclared;

  /// No description provided for @koryCopyPhone.
  ///
  /// In fr, this message translates to:
  /// **'Copier le numéro'**
  String get koryCopyPhone;

  /// No description provided for @koryCopied.
  ///
  /// In fr, this message translates to:
  /// **'Copié'**
  String get koryCopied;

  /// No description provided for @koryActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'opération n\'a pas abouti. Réessaie.'**
  String get koryActionFailed;

  /// No description provided for @welcomePromise.
  ///
  /// In fr, this message translates to:
  /// **'Plus qu\'une messagerie, une communauté.'**
  String get welcomePromise;

  /// No description provided for @welcomeSignature.
  ///
  /// In fr, this message translates to:
  /// **'Ensemble, plus forts.'**
  String get welcomeSignature;

  /// No description provided for @welcomeServiceChats.
  ///
  /// In fr, this message translates to:
  /// **'Discussions, groupes et appels'**
  String get welcomeServiceChats;

  /// No description provided for @welcomeServiceKory.
  ///
  /// In fr, this message translates to:
  /// **'Cagnottes & tontines'**
  String get welcomeServiceKory;

  /// No description provided for @legalPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get legalPrivacy;

  /// No description provided for @legalTerms.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get legalTerms;

  /// No description provided for @legalUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Document indisponible pour l\'instant.'**
  String get legalUnavailable;

  /// No description provided for @onbStep.
  ///
  /// In fr, this message translates to:
  /// **'Étape {step} sur 3'**
  String onbStep(String step);

  /// No description provided for @onbProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton profil'**
  String get onbProfileTitle;

  /// No description provided for @onbProfileBody.
  ///
  /// In fr, this message translates to:
  /// **'C\'est le nom que verront tes contacts.'**
  String get onbProfileBody;

  /// No description provided for @onbDisplayName.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiché'**
  String get onbDisplayName;

  /// No description provided for @onbNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indique un nom (2 caractères au moins).'**
  String get onbNameRequired;

  /// No description provided for @onbPhotoLater.
  ///
  /// In fr, this message translates to:
  /// **'Tu pourras ajouter une photo plus tard, depuis ton profil.'**
  String get onbPhotoLater;

  /// No description provided for @onbContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get onbContinue;

  /// No description provided for @onbTermsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Avant de commencer'**
  String get onbTermsTitle;

  /// No description provided for @onbAcceptTerms.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai lu et j\'accepte les conditions d\'utilisation et la politique de confidentialité.'**
  String get onbAcceptTerms;

  /// No description provided for @onbAge.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai l\'âge requis pour utiliser Pokou.'**
  String get onbAge;

  /// No description provided for @onbOptional.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif, modifiable à tout moment dans les réglages'**
  String get onbOptional;

  /// No description provided for @onbAnalytics.
  ///
  /// In fr, this message translates to:
  /// **'Partager des statistiques d\'usage pour améliorer Pokou'**
  String get onbAnalytics;

  /// No description provided for @onbMarketing.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir les nouvelles et offres de Pokou'**
  String get onbMarketing;

  /// No description provided for @onbFinish.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get onbFinish;

  /// No description provided for @onbFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement n\'a pas abouti. Réessaie.'**
  String get onbFailed;

  /// No description provided for @moreConsents.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques et communications'**
  String get moreConsents;

  /// No description provided for @navHonam.
  ///
  /// In fr, this message translates to:
  /// **'Honam'**
  String get navHonam;

  /// No description provided for @honamSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacies & livraison'**
  String get honamSubtitle;

  /// No description provided for @honamIntro.
  ///
  /// In fr, this message translates to:
  /// **'Une pharmacie proche t\'envoie un devis. Tu la paies depuis ton wallet, puis un coursier te la livre.'**
  String get honamIntro;

  /// No description provided for @honamSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une ordonnance'**
  String get honamSend;

  /// No description provided for @honamPhotograph.
  ///
  /// In fr, this message translates to:
  /// **'Photographier l\'ordonnance'**
  String get honamPhotograph;

  /// No description provided for @honamFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get honamFromGallery;

  /// No description provided for @honamUrgent.
  ///
  /// In fr, this message translates to:
  /// **'Urgence'**
  String get honamUrgent;

  /// No description provided for @honamNotEmergency.
  ///
  /// In fr, this message translates to:
  /// **'Pokou n\'est pas un service d\'urgence.'**
  String get honamNotEmergency;

  /// No description provided for @honamNearby.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacies proches'**
  String get honamNearby;

  /// No description provided for @honamOnDuty.
  ///
  /// In fr, this message translates to:
  /// **'De garde'**
  String get honamOnDuty;

  /// No description provided for @honamNoPharmacy.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pharmacie partenaire pour l\'instant.'**
  String get honamNoPharmacy;

  /// No description provided for @honamCurrentOrder.
  ///
  /// In fr, this message translates to:
  /// **'Commande en cours'**
  String get honamCurrentOrder;

  /// No description provided for @honamMyOrders.
  ///
  /// In fr, this message translates to:
  /// **'Mes commandes'**
  String get honamMyOrders;

  /// No description provided for @honamChoosePharmacy.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la pharmacie'**
  String get honamChoosePharmacy;

  /// No description provided for @honamAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse de livraison'**
  String get honamAddress;

  /// No description provided for @honamNote.
  ///
  /// In fr, this message translates to:
  /// **'Note pour le pharmacien (facultatif)'**
  String get honamNote;

  /// No description provided for @honamSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer à la pharmacie'**
  String get honamSubmit;

  /// No description provided for @honamNeedPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute la photo de l\'ordonnance.'**
  String get honamNeedPhoto;

  /// No description provided for @honamNeedAddress.
  ///
  /// In fr, this message translates to:
  /// **'Indique l\'adresse de livraison.'**
  String get honamNeedAddress;

  /// No description provided for @honamFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'opération n\'a pas abouti. Réessaie.'**
  String get honamFailed;

  /// No description provided for @honamOrderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commande n° {id}'**
  String honamOrderTitle(String id);

  /// No description provided for @honamStSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Envoyée, en attente du pharmacien'**
  String get honamStSubmitted;

  /// No description provided for @honamStQuoted.
  ///
  /// In fr, this message translates to:
  /// **'Devis reçu'**
  String get honamStQuoted;

  /// No description provided for @honamStAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Devis accepté, à payer'**
  String get honamStAccepted;

  /// No description provided for @honamStPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payée, en préparation'**
  String get honamStPaid;

  /// No description provided for @honamStReady.
  ///
  /// In fr, this message translates to:
  /// **'Prête, coursier attendu'**
  String get honamStReady;

  /// No description provided for @honamStInDelivery.
  ///
  /// In fr, this message translates to:
  /// **'En livraison'**
  String get honamStInDelivery;

  /// No description provided for @honamStDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Livrée'**
  String get honamStDelivered;

  /// No description provided for @honamStRejected.
  ///
  /// In fr, this message translates to:
  /// **'Ordonnance refusée'**
  String get honamStRejected;

  /// No description provided for @honamStExpired.
  ///
  /// In fr, this message translates to:
  /// **'Devis expiré'**
  String get honamStExpired;

  /// No description provided for @honamStCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get honamStCancelled;

  /// No description provided for @honamQuote.
  ///
  /// In fr, this message translates to:
  /// **'Devis'**
  String get honamQuote;

  /// No description provided for @honamUnavailableItem.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get honamUnavailableItem;

  /// No description provided for @honamMedicines.
  ///
  /// In fr, this message translates to:
  /// **'Médicaments'**
  String get honamMedicines;

  /// No description provided for @honamDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get honamDelivery;

  /// No description provided for @honamTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total à payer'**
  String get honamTotal;

  /// No description provided for @honamAcceptQuote.
  ///
  /// In fr, this message translates to:
  /// **'Accepter le devis'**
  String get honamAcceptQuote;

  /// No description provided for @honamPayTo.
  ///
  /// In fr, this message translates to:
  /// **'Envoie {amount} depuis ton wallet au {phone} (la pharmacie), puis confirme.'**
  String honamPayTo(String amount, String phone);

  /// No description provided for @honamDeclarePaid.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai payé la pharmacie'**
  String get honamDeclarePaid;

  /// No description provided for @honamPaidDeclared.
  ///
  /// In fr, this message translates to:
  /// **'Paiement signalé : la pharmacie va le confirmer.'**
  String get honamPaidDeclared;

  /// No description provided for @honamPaymentNotReceived.
  ///
  /// In fr, this message translates to:
  /// **'La pharmacie n\'a pas reçu ton paiement. Vérifie le numéro et le montant.'**
  String get honamPaymentNotReceived;

  /// No description provided for @honamCode.
  ///
  /// In fr, this message translates to:
  /// **'Ton code de remise'**
  String get honamCode;

  /// No description provided for @honamCodeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Donne ce code au coursier, seulement quand tu as le colis en main.'**
  String get honamCodeHelp;

  /// No description provided for @honamOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Le coursier récupérera l\'ordonnance originale.'**
  String get honamOriginal;

  /// No description provided for @honamRefundDue.
  ///
  /// In fr, this message translates to:
  /// **'La pharmacie te doit {amount} : {reason}'**
  String honamRefundDue(String amount, String reason);

  /// No description provided for @honamRefundReceived.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai reçu le remboursement'**
  String get honamRefundReceived;

  /// No description provided for @honamCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la commande'**
  String get honamCancel;

  /// No description provided for @honamResend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer à une autre pharmacie'**
  String get honamResend;

  /// No description provided for @honamReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif : {reason}'**
  String honamReason(String reason);

  /// No description provided for @honamTimeline.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get honamTimeline;

  /// No description provided for @honamOrderMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages de la commande'**
  String get honamOrderMessages;

  /// No description provided for @honamWriteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un message'**
  String get honamWriteMessage;

  /// No description provided for @honamCourierMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode coursier'**
  String get honamCourierMode;

  /// No description provided for @honamCourierJoin.
  ///
  /// In fr, this message translates to:
  /// **'Devenir coursier Win Pokou'**
  String get honamCourierJoin;

  /// No description provided for @honamCourierJoinBody.
  ///
  /// In fr, this message translates to:
  /// **'5 courses d\'essai sans commission pendant un mois. Ensuite : adhésion Win Pokou et pack de courses payé d\'avance.'**
  String get honamCourierJoinBody;

  /// No description provided for @honamRidesLeft.
  ///
  /// In fr, this message translates to:
  /// **'Courses restantes : {count}'**
  String honamRidesLeft(String count);

  /// No description provided for @honamUnlimited.
  ///
  /// In fr, this message translates to:
  /// **'Courses illimitées'**
  String get honamUnlimited;

  /// No description provided for @honamMembership.
  ///
  /// In fr, this message translates to:
  /// **'Adhésion Win Pokou : {amount} HT / mois'**
  String honamMembership(String amount);

  /// No description provided for @honamPayMembership.
  ///
  /// In fr, this message translates to:
  /// **'Payer l\'adhésion'**
  String get honamPayMembership;

  /// No description provided for @honamPacks.
  ///
  /// In fr, this message translates to:
  /// **'Packs de courses'**
  String get honamPacks;

  /// No description provided for @honamPackPrice.
  ///
  /// In fr, this message translates to:
  /// **'{amount} HT'**
  String honamPackPrice(String amount);

  /// No description provided for @honamAvailableRides.
  ///
  /// In fr, this message translates to:
  /// **'Courses disponibles'**
  String get honamAvailableRides;

  /// No description provided for @honamMyRides.
  ///
  /// In fr, this message translates to:
  /// **'Mes courses'**
  String get honamMyRides;

  /// No description provided for @honamNoRides.
  ///
  /// In fr, this message translates to:
  /// **'Aucune course pour l\'instant.'**
  String get honamNoRides;

  /// No description provided for @honamAcceptRide.
  ///
  /// In fr, this message translates to:
  /// **'Accepter la course'**
  String get honamAcceptRide;

  /// No description provided for @honamPickup.
  ///
  /// In fr, this message translates to:
  /// **'Colis récupéré'**
  String get honamPickup;

  /// No description provided for @honamDeliver.
  ///
  /// In fr, this message translates to:
  /// **'Valider la remise'**
  String get honamDeliver;

  /// No description provided for @honamEnterCode.
  ///
  /// In fr, this message translates to:
  /// **'Code donné par le patient'**
  String get honamEnterCode;

  /// No description provided for @honamCoursePaid.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai reçu le prix de la course'**
  String get honamCoursePaid;

  /// No description provided for @honamPaymentLinkOpened.
  ///
  /// In fr, this message translates to:
  /// **'Termine le paiement dans la page qui s\'ouvre.'**
  String get honamPaymentLinkOpened;

  /// No description provided for @honamCourierSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Compte coursier suspendu après 3 défauts de livraison. Contacte le support pour un recours.'**
  String get honamCourierSuspended;

  /// No description provided for @honamPriceNote.
  ///
  /// In fr, this message translates to:
  /// **'Prix hors taxes, TVA du pays en sus.'**
  String get honamPriceNote;

  /// No description provided for @certTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pokou certifié'**
  String get certTitle;

  /// No description provided for @certPitch.
  ///
  /// In fr, this message translates to:
  /// **'Nom vérifié et mode preuve · essai d’un mois'**
  String get certPitch;

  /// No description provided for @certHowItWorks.
  ///
  /// In fr, this message translates to:
  /// **'Ton identité est vérifiée par le nom du titulaire du wallet qui paie.'**
  String get certHowItWorks;

  /// No description provided for @certStartTrial.
  ///
  /// In fr, this message translates to:
  /// **'Essayer {days} jours'**
  String certStartTrial(String days);

  /// No description provided for @certTrialNote.
  ///
  /// In fr, this message translates to:
  /// **'Pendant l\'essai, le mode preuve est disponible ; le badge s\'affiche au premier paiement.'**
  String get certTrialNote;

  /// No description provided for @certPlanPrice.
  ///
  /// In fr, this message translates to:
  /// **'{ht} HT · {ttc} TTC'**
  String certPlanPrice(String ht, String ttc);

  /// No description provided for @certSubscribe.
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get certSubscribe;

  /// No description provided for @certActive.
  ///
  /// In fr, this message translates to:
  /// **'Badge actif'**
  String get certActive;

  /// No description provided for @certTrialUntil.
  ///
  /// In fr, this message translates to:
  /// **'Essai jusqu\'au {date}'**
  String certTrialUntil(String date);

  /// No description provided for @certActiveUntil.
  ///
  /// In fr, this message translates to:
  /// **'Actif jusqu\'au {date}'**
  String certActiveUntil(String date);

  /// No description provided for @certExpired.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement expiré'**
  String get certExpired;

  /// No description provided for @certMismatchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les noms ne correspondent pas'**
  String get certMismatchTitle;

  /// No description provided for @certMismatchBody.
  ///
  /// In fr, this message translates to:
  /// **'Le nom saisi ne correspond pas à celui du titulaire du wallet qui a payé. Corrige-le tel qu\'il figure sur sa pièce d\'identité.'**
  String get certMismatchBody;

  /// No description provided for @proofModeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode preuve'**
  String get proofModeTitle;

  /// No description provided for @proofModeOnBanner.
  ///
  /// In fr, this message translates to:
  /// **'Mode preuve actif : un message supprimé reste visible, barré, pour tous.'**
  String get proofModeOnBanner;

  /// No description provided for @proofModeEnable.
  ///
  /// In fr, this message translates to:
  /// **'Activer le mode preuve'**
  String get proofModeEnable;

  /// No description provided for @proofModeDisable.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le mode preuve'**
  String get proofModeDisable;

  /// No description provided for @proofModeNeedsCert.
  ///
  /// In fr, this message translates to:
  /// **'Le mode preuve demande Pokou certifié (essai gratuit disponible).'**
  String get proofModeNeedsCert;

  /// No description provided for @deleteForAll.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer pour tous'**
  String get deleteForAll;

  /// No description provided for @deleteProofWarning.
  ///
  /// In fr, this message translates to:
  /// **'Le mode preuve est actif. Ton message restera visible, barré, pour tous les participants, avec l’heure de la suppression.'**
  String get deleteProofWarning;

  /// No description provided for @deletedKept.
  ///
  /// In fr, this message translates to:
  /// **'Message supprimé, conservé par le mode preuve'**
  String get deletedKept;

  /// No description provided for @certCorrectName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet du titulaire'**
  String get certCorrectName;

  /// No description provided for @certRetryName.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier ce nom'**
  String get certRetryName;

  /// No description provided for @certStillMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom ne correspond toujours pas.'**
  String get certStillMismatch;

  /// No description provided for @proofExport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter la discussion en PDF'**
  String get proofExport;

  /// No description provided for @proofModeOn.
  ///
  /// In fr, this message translates to:
  /// **'{name} a activé le mode preuve'**
  String proofModeOn(String name);

  /// No description provided for @proofModeOff.
  ///
  /// In fr, this message translates to:
  /// **'{name} a désactivé le mode preuve'**
  String proofModeOff(String name);

  /// No description provided for @proofOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Version d\'origine : {text}'**
  String proofOriginal(String text);

  /// No description provided for @proofDisableReserved.
  ///
  /// In fr, this message translates to:
  /// **'Seule la personne qui l\'a activé, ou un administrateur au badge payant, peut le désactiver.'**
  String get proofDisableReserved;

  /// No description provided for @marketBoost3.
  ///
  /// In fr, this message translates to:
  /// **'3 jours · 600 FCFA'**
  String get marketBoost3;

  /// No description provided for @marketBoost7.
  ///
  /// In fr, this message translates to:
  /// **'7 jours · 1 300 FCFA'**
  String get marketBoost7;

  /// No description provided for @marketUseHonam.
  ///
  /// In fr, this message translates to:
  /// **'Les médicaments ne se vendent pas sur Assimé : passe par Honam.'**
  String get marketUseHonam;

  /// No description provided for @honamMissingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un produit manque'**
  String get honamMissingTitle;

  /// No description provided for @honamMissingBody.
  ///
  /// In fr, this message translates to:
  /// **'{amount} manquent : {reason}. Que préfères-tu ?'**
  String honamMissingBody(String amount, String reason);

  /// No description provided for @honamKeepRest.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir le reste'**
  String get honamKeepRest;

  /// No description provided for @honamCancelAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout annuler'**
  String get honamCancelAll;

  /// No description provided for @honamRefundDelay.
  ///
  /// In fr, this message translates to:
  /// **'La pharmacie te rembourse sous 2 h, sur le numéro qui a payé.'**
  String get honamRefundDelay;

  /// No description provided for @honamZones.
  ///
  /// In fr, this message translates to:
  /// **'Zones et créneaux (ex. Bè, Tokoin — soirs)'**
  String get honamZones;

  /// No description provided for @honamWallet.
  ///
  /// In fr, this message translates to:
  /// **'Numéro du wallet qui reçoit le prix des courses'**
  String get honamWallet;

  /// No description provided for @honamRules.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les règles d\'or : je remets le colis seulement contre le code, je ne regarde pas les ordonnances, je reste courtois.'**
  String get honamRules;

  /// No description provided for @honamApply.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ma candidature'**
  String get honamApply;

  /// No description provided for @honamPending.
  ///
  /// In fr, this message translates to:
  /// **'Candidature envoyée : l\'équipe Pokou la vérifie.'**
  String get honamPending;

  /// No description provided for @honamLaunch.
  ///
  /// In fr, this message translates to:
  /// **'Période de lancement : tu livres sans adhésion ni pack.'**
  String get honamLaunch;

  /// No description provided for @honamQueenLocked.
  ///
  /// In fr, this message translates to:
  /// **'Queen Pokou se débloque après un mois sans défaut de livraison.'**
  String get honamQueenLocked;

  /// No description provided for @koryDeclaredTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total déclaré : {amount}'**
  String koryDeclaredTotal(String amount);

  /// No description provided for @koryRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Reste à collecter : {amount}'**
  String koryRemaining(String amount);

  /// No description provided for @onbBabaWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Je suis Baba, l\'assistant de Pokou. Comment veux-tu qu\'on t\'appelle ?'**
  String get onbBabaWelcome;

  /// No description provided for @onbContactsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retrouver tes proches'**
  String get onbContactsTitle;

  /// No description provided for @onbContactsBody.
  ///
  /// In fr, this message translates to:
  /// **'Baba peut retrouver ceux de tes contacts qui sont déjà sur Pokou. Tu peux refuser : on te le redemandera plus tard.'**
  String get onbContactsBody;

  /// No description provided for @onbContactsAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get onbContactsAllow;

  /// No description provided for @onbLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get onbLater;

  /// No description provided for @proofModeDirectHint.
  ///
  /// In fr, this message translates to:
  /// **'Tout ce qui s\'écrit reste prouvable : un message supprimé reste barré, une modification garde l\'original. Seule toi pourras le couper.'**
  String get proofModeDirectHint;

  /// No description provided for @proofDisableReservedDirect.
  ///
  /// In fr, this message translates to:
  /// **'Seule la personne qui a activé le mode preuve peut le désactiver.'**
  String get proofDisableReservedDirect;

  /// No description provided for @proofExportMe.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get proofExportMe;

  /// No description provided for @proofExportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pokou — export du mode preuve'**
  String get proofExportTitle;

  /// No description provided for @proofExportBetween.
  ///
  /// In fr, this message translates to:
  /// **'Discussion entre {me} et {contact}'**
  String proofExportBetween(String me, String contact);

  /// No description provided for @proofExportPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Mode preuve actif depuis le {since} · exporté le {now} depuis ce téléphone'**
  String proofExportPeriod(String since, String now);

  /// No description provided for @proofExportFooter.
  ///
  /// In fr, this message translates to:
  /// **'Page {page} sur {pages} — produit sur l\'appareil : le serveur Pokou n\'a pas accès aux messages chiffrés.'**
  String proofExportFooter(String page, String pages);

  /// No description provided for @proofExportAttachment.
  ///
  /// In fr, this message translates to:
  /// **'[pièce jointe]'**
  String get proofExportAttachment;

  /// No description provided for @proofExportEdited.
  ///
  /// In fr, this message translates to:
  /// **'Modifié le {at}'**
  String proofExportEdited(String at);

  /// No description provided for @proofExportDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Supprimé le {at}, conservé par le mode preuve'**
  String proofExportDeleted(String at);

  /// No description provided for @proTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pokou certifié Pro'**
  String get proTitle;

  /// No description provided for @proTeaser.
  ///
  /// In fr, this message translates to:
  /// **'Pour une activité : nom commercial et « Géré par »'**
  String get proTeaser;

  /// No description provided for @proPitch.
  ///
  /// In fr, this message translates to:
  /// **'Ton nom commercial s\'affiche en premier, avec « Géré par » et ton nom vérifié. Le profil Pro accueillera tes annonces Assimé.'**
  String get proPitch;

  /// No description provided for @proSteps.
  ///
  /// In fr, this message translates to:
  /// **'1. Tu envoies ton justificatif. 2. Le support le vérifie sous {hours} h. 3. Tu ne paies qu\'après la validation.'**
  String proSteps(String hours);

  /// No description provided for @proPending.
  ///
  /// In fr, this message translates to:
  /// **'Vérification en cours. Réponse au plus tard le {due}.'**
  String proPending(String due);

  /// No description provided for @proApproved.
  ///
  /// In fr, this message translates to:
  /// **'Justificatif validé : tu peux activer Pokou certifié Pro.'**
  String get proApproved;

  /// No description provided for @proPay.
  ///
  /// In fr, this message translates to:
  /// **'Payer Pokou certifié Pro'**
  String get proPay;

  /// No description provided for @proCorrection.
  ///
  /// In fr, this message translates to:
  /// **'Justificatif à corriger'**
  String get proCorrection;

  /// No description provided for @proRejected.
  ///
  /// In fr, this message translates to:
  /// **'Dossier refusé'**
  String get proRejected;

  /// No description provided for @proActivity.
  ///
  /// In fr, this message translates to:
  /// **'Ton activité'**
  String get proActivity;

  /// No description provided for @proBusinessName.
  ///
  /// In fr, this message translates to:
  /// **'Nom commercial'**
  String get proBusinessName;

  /// No description provided for @proActivityField.
  ///
  /// In fr, this message translates to:
  /// **'Activité (couture, boutique, transport…)'**
  String get proActivityField;

  /// No description provided for @proDocument.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le justificatif'**
  String get proDocument;

  /// No description provided for @proDocumentChosen.
  ///
  /// In fr, this message translates to:
  /// **'Justificatif ajouté — toucher pour changer'**
  String get proDocumentChosen;

  /// No description provided for @proDocumentNote.
  ///
  /// In fr, this message translates to:
  /// **'Registre de commerce, carte professionnelle ou patente. Vu par le support seulement, jamais affiché.'**
  String get proDocumentNote;

  /// No description provided for @proSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer pour vérification'**
  String get proSend;

  /// No description provided for @proManagedBy.
  ///
  /// In fr, this message translates to:
  /// **'Géré par {name}'**
  String proManagedBy(String name);

  /// No description provided for @proProfileNote.
  ///
  /// In fr, this message translates to:
  /// **'C\'est ainsi que les autres voient ton profil Pro.'**
  String get proProfileNote;

  /// No description provided for @honamCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get honamCity;

  /// No description provided for @honamOtherCity.
  ///
  /// In fr, this message translates to:
  /// **'Une autre ville'**
  String get honamOtherCity;

  /// No description provided for @honamYourCity.
  ///
  /// In fr, this message translates to:
  /// **'Ta ville'**
  String get honamYourCity;

  /// No description provided for @honamNotServed.
  ///
  /// In fr, this message translates to:
  /// **'Honam ne livre pas encore dans cette ville. Inscris-toi : on te prévient à l\'ouverture.'**
  String get honamNotServed;

  /// No description provided for @honamJoinWaitlist.
  ///
  /// In fr, this message translates to:
  /// **'M\'inscrire sur la liste d\'attente'**
  String get honamJoinWaitlist;

  /// No description provided for @honamWaitlistDone.
  ///
  /// In fr, this message translates to:
  /// **'Inscrit·e pour {city}'**
  String honamWaitlistDone(String city);

  /// No description provided for @honamWaitlistBody.
  ///
  /// In fr, this message translates to:
  /// **'On te prévient dès que Honam livre dans ta ville. Rien d\'autre.'**
  String get honamWaitlistBody;

  /// No description provided for @honamReferralCodeField.
  ///
  /// In fr, this message translates to:
  /// **'Code de parrainage (facultatif)'**
  String get honamReferralCodeField;

  /// No description provided for @honamReferralTitle.
  ///
  /// In fr, this message translates to:
  /// **'Invite un coursier'**
  String get honamReferralTitle;

  /// No description provided for @honamReferralBody.
  ///
  /// In fr, this message translates to:
  /// **'{rides} courses offertes à la première livraison de ton filleul.'**
  String honamReferralBody(String rides);

  /// No description provided for @honamReferralShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager mon code'**
  String get honamReferralShare;

  /// No description provided for @honamReferralMessage.
  ///
  /// In fr, this message translates to:
  /// **'Livre pour Honam avec Pokou : utilise mon code de parrainage {code} dans le mode coursier.'**
  String honamReferralMessage(String code);

  /// No description provided for @honamReferralCount.
  ///
  /// In fr, this message translates to:
  /// **'Filleuls : {count}'**
  String honamReferralCount(String count);

  /// No description provided for @honamTrialEnded.
  ///
  /// In fr, this message translates to:
  /// **'Ton essai est terminé'**
  String get honamTrialEnded;

  /// No description provided for @honamRecommendedPack.
  ///
  /// In fr, this message translates to:
  /// **'D\'après tes courses du mois, le pack {pack} te suffit.'**
  String honamRecommendedPack(String pack);

  /// No description provided for @honamNavigate.
  ///
  /// In fr, this message translates to:
  /// **'Itinéraire dans mon appli de cartes'**
  String get honamNavigate;

  /// No description provided for @honamLocationShared.
  ///
  /// In fr, this message translates to:
  /// **'Ta position est partagée toutes les 15 s pendant la course, jamais après.'**
  String get honamLocationShared;

  /// No description provided for @honamLocationDenied.
  ///
  /// In fr, this message translates to:
  /// **'Autorise la localisation pour que le patient suive sa livraison.'**
  String get honamLocationDenied;

  /// No description provided for @honamCourier.
  ///
  /// In fr, this message translates to:
  /// **'le coursier'**
  String get honamCourier;

  /// No description provided for @honamTrackingTitle.
  ///
  /// In fr, this message translates to:
  /// **'{name} est en route'**
  String honamTrackingTitle(String name);

  /// No description provided for @honamTrackingWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Position pas encore reçue.'**
  String get honamTrackingWaiting;

  /// No description provided for @honamTrackingDistance.
  ///
  /// In fr, this message translates to:
  /// **'À {km} km de chez toi'**
  String honamTrackingDistance(String km);

  /// No description provided for @honamTrackingUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour il y a {minutes} min'**
  String honamTrackingUpdated(String minutes);

  /// No description provided for @honamTrackingStale.
  ///
  /// In fr, this message translates to:
  /// **'Position non à jour'**
  String get honamTrackingStale;

  /// No description provided for @honamTrackingShowMap.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la carte'**
  String get honamTrackingShowMap;

  /// No description provided for @honamTrackingMapDataSaver.
  ///
  /// In fr, this message translates to:
  /// **'Voir sur la carte (consomme des données)'**
  String get honamTrackingMapDataSaver;

  /// No description provided for @assimeFavoritesAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Favoris et alertes'**
  String get assimeFavoritesAlerts;

  /// No description provided for @assimeFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get assimeFavorites;

  /// No description provided for @assimeAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get assimeAlerts;

  /// No description provided for @assimeNoFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Aucun favori'**
  String get assimeNoFavorites;

  /// No description provided for @assimeFavoritesHint.
  ///
  /// In fr, this message translates to:
  /// **'Touche le cœur d\'une annonce pour la garder ici.'**
  String get assimeFavoritesHint;

  /// No description provided for @assimeAddFavorite.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get assimeAddFavorite;

  /// No description provided for @assimeRemoveFavorite.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get assimeRemoveFavorite;

  /// No description provided for @assimeNewAlert.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle alerte'**
  String get assimeNewAlert;

  /// No description provided for @assimeAlertQuery.
  ///
  /// In fr, this message translates to:
  /// **'Ce que tu cherches'**
  String get assimeAlertQuery;

  /// No description provided for @assimeAlertMaxPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix maximum (facultatif)'**
  String get assimeAlertMaxPrice;

  /// No description provided for @assimeAlertNote.
  ///
  /// In fr, this message translates to:
  /// **'On te prévient quand une annonce correspond. L\'alerte ne lit que les annonces, jamais tes messages.'**
  String get assimeAlertNote;

  /// No description provided for @assimeNoAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte pour l\'instant.'**
  String get assimeNoAlerts;

  /// No description provided for @assimeAlertUpTo.
  ///
  /// In fr, this message translates to:
  /// **'jusqu\'à {price} FCFA'**
  String assimeAlertUpTo(String price);

  /// No description provided for @assimeAlertMatches.
  ///
  /// In fr, this message translates to:
  /// **'{count} annonce(s) trouvée(s)'**
  String assimeAlertMatches(String count);

  /// No description provided for @assimeSponsored.
  ///
  /// In fr, this message translates to:
  /// **'Sponsorisé'**
  String get assimeSponsored;

  /// No description provided for @assimeWhyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi je vois cette annonce ?'**
  String get assimeWhyTitle;

  /// No description provided for @assimeWhyNotSponsored.
  ///
  /// In fr, this message translates to:
  /// **'Cette annonce n\'est plus mise en avant.'**
  String get assimeWhyNotSponsored;

  /// No description provided for @assimeReportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bilan de la mise en avant'**
  String get assimeReportTitle;

  /// No description provided for @assimeReportEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de mise en avant pour cette annonce.'**
  String get assimeReportEmpty;

  /// No description provided for @assimeReportPeriod.
  ///
  /// In fr, this message translates to:
  /// **'{days} jours · du {start} au {end}'**
  String assimeReportPeriod(String days, String start, String end);

  /// No description provided for @assimeReportImpressions.
  ///
  /// In fr, this message translates to:
  /// **'Vue en tête des résultats : {count} fois'**
  String assimeReportImpressions(String count);

  /// No description provided for @assimeReportStatusViews.
  ///
  /// In fr, this message translates to:
  /// **'Vue dans les statuts : {count} fois'**
  String assimeReportStatusViews(String count);

  /// No description provided for @assimeReportContacts.
  ///
  /// In fr, this message translates to:
  /// **'Personnes qui t\'ont contacté : {count}'**
  String assimeReportContacts(String count);

  /// No description provided for @assimeStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'Place dans les statuts : en relecture par la modération'**
  String get assimeStatusPending;

  /// No description provided for @assimeStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Place dans les statuts refusée par la modération'**
  String get assimeStatusRejected;

  /// No description provided for @koryKindTontine.
  ///
  /// In fr, this message translates to:
  /// **'Tontine'**
  String get koryKindTontine;

  /// No description provided for @koryFieldStake.
  ///
  /// In fr, this message translates to:
  /// **'Mise de chacun par tour (FCFA)'**
  String get koryFieldStake;

  /// No description provided for @koryRotation.
  ///
  /// In fr, this message translates to:
  /// **'Ordre des tours'**
  String get koryRotation;

  /// No description provided for @koryRotationHint.
  ///
  /// In fr, this message translates to:
  /// **'Glisse pour ordonner. L\'ordre est fixé à l\'ouverture et ne change plus.'**
  String get koryRotationHint;

  /// No description provided for @koryRemoveFromRotation.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la tontine'**
  String get koryRemoveFromRotation;

  /// No description provided for @koryNeedRotation.
  ///
  /// In fr, this message translates to:
  /// **'Une tontine demande au moins deux participants.'**
  String get koryNeedRotation;

  /// No description provided for @koryTontineNote.
  ///
  /// In fr, this message translates to:
  /// **'Chaque tour, chacun envoie sa mise au wallet du bénéficiaire, qui confirme ce qu\'il a reçu. Pokou ne touche jamais l\'argent.'**
  String get koryTontineNote;

  /// No description provided for @koryRounds.
  ///
  /// In fr, this message translates to:
  /// **'Les tours'**
  String get koryRounds;

  /// No description provided for @koryRoundNumber.
  ///
  /// In fr, this message translates to:
  /// **'Tour {number}'**
  String koryRoundNumber(String number);

  /// No description provided for @koryRoundConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'{confirmed} confirmés sur {expected}'**
  String koryRoundConfirmed(String confirmed, String expected);

  /// No description provided for @koryNextRound.
  ///
  /// In fr, this message translates to:
  /// **'Passer au tour suivant'**
  String get koryNextRound;

  /// No description provided for @koryNextRoundBody.
  ///
  /// In fr, this message translates to:
  /// **'Le tour en cours se termine. Les contributions déjà déclarées restent à confirmer par son bénéficiaire.'**
  String get koryNextRoundBody;

  /// No description provided for @koryLastRoundBody.
  ///
  /// In fr, this message translates to:
  /// **'C\'était le dernier tour : la tontine sera clôturée. Le journal reste consultable.'**
  String get koryLastRoundBody;

  /// No description provided for @welcomeStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get welcomeStart;

  /// No description provided for @authAcceptAndContinue.
  ///
  /// In fr, this message translates to:
  /// **'Accepter et continuer'**
  String get authAcceptAndContinue;

  /// No description provided for @authAcceptNotice.
  ///
  /// In fr, this message translates to:
  /// **'En touchant « Accepter et continuer », tu acceptes les conditions d\'utilisation et la politique de confidentialité, et tu déclares avoir l\'âge requis.'**
  String get authAcceptNotice;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est définitive.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountRemovedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui est supprimé'**
  String get deleteAccountRemovedTitle;

  /// No description provided for @deleteAccountRemovedProfile.
  ///
  /// In fr, this message translates to:
  /// **'Ton profil, ta photo et ta sauvegarde'**
  String get deleteAccountRemovedProfile;

  /// No description provided for @deleteAccountRemovedChats.
  ///
  /// In fr, this message translates to:
  /// **'Tes discussions sur ce téléphone'**
  String get deleteAccountRemovedChats;

  /// No description provided for @deleteAccountRemovedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Ton badge, sans remboursement du mois en cours'**
  String get deleteAccountRemovedBadge;

  /// No description provided for @deleteAccountKeptTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui reste'**
  String get deleteAccountKeptTitle;

  /// No description provided for @deleteAccountKeptMessages.
  ///
  /// In fr, this message translates to:
  /// **'Les messages déjà reçus par tes contacts'**
  String get deleteAccountKeptMessages;

  /// No description provided for @deleteAccountKeptProof.
  ///
  /// In fr, this message translates to:
  /// **'Les traces du mode preuve chez les autres participants'**
  String get deleteAccountKeptProof;

  /// No description provided for @deleteAccountKeptKory.
  ///
  /// In fr, this message translates to:
  /// **'Le journal des cagnottes Kory, qui ne s’efface pas'**
  String get deleteAccountKeptKory;

  /// No description provided for @deleteAccountConfirmLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confirme ton numéro'**
  String get deleteAccountConfirmLabel;

  /// No description provided for @deleteAccountMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro ne correspond pas à ton compte.'**
  String get deleteAccountMismatch;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In fr, this message translates to:
  /// **'La suppression a échoué. Réessaie.'**
  String get deleteAccountFailed;

  /// No description provided for @helpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aide et support'**
  String get helpTitle;

  /// No description provided for @helpSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans l’aide'**
  String get helpSearchHint;

  /// No description provided for @helpAskBaba.
  ///
  /// In fr, this message translates to:
  /// **'Demander à Baba'**
  String get helpAskBaba;

  /// No description provided for @helpAskBabaSub.
  ///
  /// In fr, this message translates to:
  /// **'L’assistant IA répond tout de suite'**
  String get helpAskBabaSub;

  /// No description provided for @helpFaqTitle.
  ///
  /// In fr, this message translates to:
  /// **'Questions fréquentes'**
  String get helpFaqTitle;

  /// No description provided for @helpQMoney.
  ///
  /// In fr, this message translates to:
  /// **'Pokou touche-t-il mon argent ?'**
  String get helpQMoney;

  /// No description provided for @helpAMoney.
  ///
  /// In fr, this message translates to:
  /// **'Non. Cagnottes, pharmacies et coursiers se paient de wallet à wallet. Pokou ne garde jamais ton argent.'**
  String get helpAMoney;

  /// No description provided for @helpQProof.
  ///
  /// In fr, this message translates to:
  /// **'Comment marche le mode preuve ?'**
  String get helpQProof;

  /// No description provided for @helpAProof.
  ///
  /// In fr, this message translates to:
  /// **'Activé par un titulaire de Pokou certifié, il garde visibles, barrés, les messages supprimés ou modifiés. C’est toujours affiché en tête de la discussion.'**
  String get helpAProof;

  /// No description provided for @helpQSms.
  ///
  /// In fr, this message translates to:
  /// **'Je ne reçois pas le code SMS'**
  String get helpQSms;

  /// No description provided for @helpASms.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie le numéro et le réseau, puis attends la fin du compte à rebours pour redemander un code. Pokou ne te demandera jamais ce code, ni par message ni par appel.'**
  String get helpASms;

  /// No description provided for @helpQCourier.
  ///
  /// In fr, this message translates to:
  /// **'Comment devenir coursier Honam ?'**
  String get helpQCourier;

  /// No description provided for @helpACourier.
  ///
  /// In fr, this message translates to:
  /// **'Dans Plus, touche « Devenir coursier Honam » : identité, zones, wallet et règles d’or. Honam ouvre ville par ville.'**
  String get helpACourier;

  /// No description provided for @helpQScam.
  ///
  /// In fr, this message translates to:
  /// **'Comment repérer une arnaque ?'**
  String get helpQScam;

  /// No description provided for @helpAScam.
  ///
  /// In fr, this message translates to:
  /// **'Méfie-toi de qui demande un code reçu par SMS, ton code PIN ou un paiement urgent. Pokou ne le fait jamais. Bloque et signale le contact.'**
  String get helpAScam;

  /// No description provided for @helpSupport.
  ///
  /// In fr, this message translates to:
  /// **'Écrire au support'**
  String get helpSupport;

  /// No description provided for @helpSupportSub.
  ///
  /// In fr, this message translates to:
  /// **'Réponse dans l’application'**
  String get helpSupportSub;

  /// No description provided for @helpReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème'**
  String get helpReport;

  /// No description provided for @helpNoResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucune question ne correspond. Demande à Baba.'**
  String get helpNoResult;

  /// No description provided for @aboutTitle.
  ///
  /// In fr, this message translates to:
  /// **'À propos de Pokou'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutNamesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le sens de nos noms'**
  String get aboutNamesTitle;

  /// No description provided for @aboutPokou.
  ///
  /// In fr, this message translates to:
  /// **'un nom baoulé'**
  String get aboutPokou;

  /// No description provided for @aboutKory.
  ///
  /// In fr, this message translates to:
  /// **'le cauris'**
  String get aboutKory;

  /// No description provided for @aboutHonam.
  ///
  /// In fr, this message translates to:
  /// **'« aide-moi », en éwé'**
  String get aboutHonam;

  /// No description provided for @aboutAssime.
  ///
  /// In fr, this message translates to:
  /// **'« au marché », en éwé'**
  String get aboutAssime;

  /// No description provided for @aboutWetri.
  ///
  /// In fr, this message translates to:
  /// **'« mois », en éwé'**
  String get aboutWetri;

  /// No description provided for @aboutEpe.
  ///
  /// In fr, this message translates to:
  /// **'« année », en éwé'**
  String get aboutEpe;

  /// No description provided for @aboutNextNames.
  ///
  /// In fr, this message translates to:
  /// **'Nos prochains services porteront eux aussi des noms venus de langues africaines.'**
  String get aboutNextNames;

  /// No description provided for @aboutLicenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences des logiciels libres'**
  String get aboutLicenses;

  /// No description provided for @legalEssentials.
  ///
  /// In fr, this message translates to:
  /// **'L’essentiel'**
  String get legalEssentials;

  /// No description provided for @legalFullText.
  ///
  /// In fr, this message translates to:
  /// **'Texte complet'**
  String get legalFullText;

  /// No description provided for @termsE1.
  ///
  /// In fr, this message translates to:
  /// **'Pokou ne touche jamais l’argent : cagnottes, pharmacies et coursiers se paient de wallet à wallet.'**
  String get termsE1;

  /// No description provided for @termsE2.
  ///
  /// In fr, this message translates to:
  /// **'Le mode preuve garde la trace des messages supprimés, et c’est toujours affiché.'**
  String get termsE2;

  /// No description provided for @termsE3.
  ///
  /// In fr, this message translates to:
  /// **'Honam n’est pas un service d’urgence.'**
  String get termsE3;

  /// No description provided for @termsE4.
  ///
  /// In fr, this message translates to:
  /// **'Les badges payants se résilient à tout moment.'**
  String get termsE4;

  /// No description provided for @privacyE1.
  ///
  /// In fr, this message translates to:
  /// **'Ton numéro n’est jamais montré à un vendeur ni à un coursier.'**
  String get privacyE1;

  /// No description provided for @privacyE2.
  ///
  /// In fr, this message translates to:
  /// **'Pokou ne lit pas tes messages. Un signalement n’envoie que les 5 derniers au support.'**
  String get privacyE2;

  /// No description provided for @privacyE3.
  ///
  /// In fr, this message translates to:
  /// **'La position du coursier n’est pas conservée après la livraison.'**
  String get privacyE3;

  /// No description provided for @privacyE4.
  ///
  /// In fr, this message translates to:
  /// **'Les annonces sponsorisées sont ciblées par ville, jamais à partir de tes messages.'**
  String get privacyE4;

  /// No description provided for @languageNote.
  ///
  /// In fr, this message translates to:
  /// **'La langue de l’application ne change pas celle de tes messages. Les noms Pokou, Kory, Honam et Assimé restent les mêmes dans toutes les langues.'**
  String get languageNote;

  /// No description provided for @securityPinWarning.
  ///
  /// In fr, this message translates to:
  /// **'Pokou ne te demandera jamais ton code PIN ni le code reçu par SMS, ni par message ni par appel.'**
  String get securityPinWarning;

  /// No description provided for @statusReplyPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Ta réponse arrive en privé, dans votre discussion à deux.'**
  String get statusReplyPrivate;

  /// No description provided for @statusViewersNote.
  ///
  /// In fr, this message translates to:
  /// **'Toi seul vois cette liste. Les réponses arrivent en privé, dans vos discussions.'**
  String get statusViewersNote;

  /// No description provided for @statusWhoSees.
  ///
  /// In fr, this message translates to:
  /// **'Qui voit mes statuts'**
  String get statusWhoSees;

  /// No description provided for @attachCompressNote.
  ///
  /// In fr, this message translates to:
  /// **'Photos et vidéos sont compressées avant l’envoi pour économiser tes données.'**
  String get attachCompressNote;

  /// No description provided for @otpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisis le code'**
  String get otpTitle;

  /// No description provided for @pinForgot.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN oublié ?'**
  String get pinForgot;

  /// No description provided for @pinTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton code PIN'**
  String get pinTitle;

  /// No description provided for @statusReplyHint.
  ///
  /// In fr, this message translates to:
  /// **'Répondre à {name}…'**
  String statusReplyHint(String name);

  /// No description provided for @statusReplyQuote.
  ///
  /// In fr, this message translates to:
  /// **'↩ En réponse à ton statut'**
  String get statusReplyQuote;

  /// No description provided for @statusReplySent.
  ///
  /// In fr, this message translates to:
  /// **'Réponse envoyée en privé.'**
  String get statusReplySent;

  /// No description provided for @changeNumberTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer de numéro'**
  String get changeNumberTitle;

  /// No description provided for @changeNumberOld.
  ///
  /// In fr, this message translates to:
  /// **'Ancien numéro'**
  String get changeNumberOld;

  /// No description provided for @changeNumberNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau numéro'**
  String get changeNumberNew;

  /// No description provided for @changeNumberNotify.
  ///
  /// In fr, this message translates to:
  /// **'Prévenir mes contacts'**
  String get changeNumberNotify;

  /// No description provided for @changeNumberNotifyAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous mes contacts'**
  String get changeNumberNotifyAll;

  /// No description provided for @changeNumberNotifyChatted.
  ///
  /// In fr, this message translates to:
  /// **'Ceux avec qui j’ai discuté'**
  String get changeNumberNotifyChatted;

  /// No description provided for @changeNumberNotifyNone.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get changeNumberNotifyNone;

  /// No description provided for @changeNumberNotifyNoneSub.
  ///
  /// In fr, this message translates to:
  /// **'Tes groupes sont toujours prévenus'**
  String get changeNumberNotifyNoneSub;

  /// No description provided for @changeNumberInfo.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte, tes discussions, ton badge Pokou certifié et tes cagnottes Kory te suivent. Un code est envoyé au nouveau numéro.'**
  String get changeNumberInfo;

  /// No description provided for @changeNumberKoryWarning.
  ///
  /// In fr, this message translates to:
  /// **'Si tu es collecteur d’une cagnotte, ton numéro de collecte ne change pas tout seul : modifie-le dans Kory, les membres en seront prévenus.'**
  String get changeNumberKoryWarning;

  /// No description provided for @changeNumberSendCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get changeNumberSendCode;

  /// No description provided for @changeNumberCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code reçu par SMS'**
  String get changeNumberCodeLabel;

  /// No description provided for @changeNumberConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le changement'**
  String get changeNumberConfirm;

  /// No description provided for @changeNumberDone.
  ///
  /// In fr, this message translates to:
  /// **'Ton numéro est changé.'**
  String get changeNumberDone;

  /// No description provided for @pinForgotIntro.
  ///
  /// In fr, this message translates to:
  /// **'Deux façons de retrouver ton compte :'**
  String get pinForgotIntro;

  /// No description provided for @pinForgotEmail.
  ///
  /// In fr, this message translates to:
  /// **'Par e-mail'**
  String get pinForgotEmail;

  /// No description provided for @pinForgotEmailSub.
  ///
  /// In fr, this message translates to:
  /// **'Si tu as ajouté une adresse : un lien de réinitialisation t’est envoyé'**
  String get pinForgotEmailSub;

  /// No description provided for @pinForgotWait.
  ///
  /// In fr, this message translates to:
  /// **'Attendre 7 jours'**
  String get pinForgotWait;

  /// No description provided for @pinForgotWaitSub.
  ///
  /// In fr, this message translates to:
  /// **'Ensuite, tu te connectes sans code PIN avec le code SMS, à condition de garder ton numéro'**
  String get pinForgotWaitSub;

  /// No description provided for @pinForgotWarning.
  ///
  /// In fr, this message translates to:
  /// **'Le délai de 7 jours empêche quelqu’un qui aurait volé ta carte SIM de prendre ton compte tout de suite.'**
  String get pinForgotWarning;

  /// No description provided for @pinForgotMeanwhile.
  ///
  /// In fr, this message translates to:
  /// **'Pendant l’attente, tes contacts continuent de te voir et tes messages t’attendent.'**
  String get pinForgotMeanwhile;

  /// No description provided for @pinForgotContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get pinForgotContinue;

  /// No description provided for @pinForgotScheduled.
  ///
  /// In fr, this message translates to:
  /// **'C’est noté. À partir du {date}, le code SMS suffira pour te connecter.'**
  String pinForgotScheduled(String date);

  /// No description provided for @groupDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le groupe'**
  String get groupDelete;

  /// No description provided for @groupDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ?'**
  String groupDeleteTitle(String name);

  /// No description provided for @groupDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe disparaît pour tous ses membres, avec ses messages. Cette action est définitive.'**
  String get groupDeleteBody;

  /// No description provided for @groupDeleteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible — réessaie.'**
  String get groupDeleteFailed;

  /// No description provided for @groupManageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérer le groupe'**
  String get groupManageTitle;

  /// No description provided for @groupManageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Autorisations, nouveaux membres, messages éphémères'**
  String get groupManageSubtitle;

  /// No description provided for @groupPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Autorisations'**
  String get groupPermissions;

  /// No description provided for @groupEditInfoSetting.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le nom et la photo'**
  String get groupEditInfoSetting;

  /// No description provided for @groupSendSetting.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer des messages'**
  String get groupSendSetting;

  /// No description provided for @groupApproveSetting.
  ///
  /// In fr, this message translates to:
  /// **'Approuver les nouveaux membres'**
  String get groupApproveSetting;

  /// No description provided for @groupApproveSettingSub.
  ///
  /// In fr, this message translates to:
  /// **'Un administrateur valide chaque entrée par lien'**
  String get groupApproveSettingSub;

  /// No description provided for @groupAllMembers.
  ///
  /// In fr, this message translates to:
  /// **'Tous les membres'**
  String get groupAllMembers;

  /// No description provided for @groupDisappearing.
  ///
  /// In fr, this message translates to:
  /// **'Messages éphémères'**
  String get groupDisappearing;

  /// No description provided for @groupDisappearingOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivés'**
  String get groupDisappearingOff;

  /// No description provided for @groupDisappearing24h.
  ///
  /// In fr, this message translates to:
  /// **'24 heures'**
  String get groupDisappearing24h;

  /// No description provided for @groupDisappearing7d.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get groupDisappearing7d;

  /// No description provided for @groupDisappearing90d.
  ///
  /// In fr, this message translates to:
  /// **'90 jours'**
  String get groupDisappearing90d;

  /// No description provided for @groupJoinRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d’entrée'**
  String get groupJoinRequests;

  /// No description provided for @groupNoJoinRequest.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande en attente.'**
  String get groupNoJoinRequest;

  /// No description provided for @groupApprove.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get groupApprove;

  /// No description provided for @groupReject.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get groupReject;

  /// No description provided for @groupJoinPending.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée : un administrateur doit valider ton entrée.'**
  String get groupJoinPending;

  /// No description provided for @groupSettingsSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Réglage non enregistré — réessaie.'**
  String get groupSettingsSaveFailed;

  /// No description provided for @groupLeaveKoryNote.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe ne supprime pas la cagnotte en cours : tes contributions restent dans le journal Kory.'**
  String get groupLeaveKoryNote;

  /// No description provided for @messageWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente de ce message…'**
  String get messageWaiting;

  /// No description provided for @callWaitingNotice.
  ///
  /// In fr, this message translates to:
  /// **'Tu es déjà en appel. Refuser le garde ; accepter le termine.'**
  String get callWaitingNotice;

  /// No description provided for @callEndAndAccept.
  ///
  /// In fr, this message translates to:
  /// **'Terminer et accepter'**
  String get callEndAndAccept;

  /// No description provided for @homeHelloOverline.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get homeHelloOverline;

  /// No description provided for @koryOverline.
  ///
  /// In fr, this message translates to:
  /// **'Épargne solidaire'**
  String get koryOverline;

  /// No description provided for @koryActiveCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} actives'**
  String koryActiveCount(String count);

  /// No description provided for @searchIntro.
  ///
  /// In fr, this message translates to:
  /// **'Cherche dans tes messages, les chaînes et les annonces d’Assimé.'**
  String get searchIntro;

  /// No description provided for @searchRecent.
  ///
  /// In fr, this message translates to:
  /// **'Recherches récentes'**
  String get searchRecent;

  /// No description provided for @homeTagline.
  ///
  /// In fr, this message translates to:
  /// **'Tout ce qui compte, au même endroit.'**
  String get homeTagline;

  /// No description provided for @homeWhatToDo.
  ///
  /// In fr, this message translates to:
  /// **'Que veux-tu faire ?'**
  String get homeWhatToDo;

  /// No description provided for @homeInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get homeInProgress;

  /// No description provided for @homeKoryPitch.
  ///
  /// In fr, this message translates to:
  /// **'Collecte à plusieurs pour un projet, un événement ou une tontine.'**
  String get homeKoryPitch;

  /// No description provided for @homeHonamPitch.
  ///
  /// In fr, this message translates to:
  /// **'Envoie ton ordonnance et reçois les devis des pharmacies proches.'**
  String get homeHonamPitch;

  /// No description provided for @homeAssimeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Assimé'**
  String get homeAssimeTitle;

  /// No description provided for @homeAssimeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Petites annonces'**
  String get homeAssimeSubtitle;

  /// No description provided for @homeAssimePitch.
  ///
  /// In fr, this message translates to:
  /// **'Achète et vends près de chez toi, en toute confiance.'**
  String get homeAssimePitch;

  /// No description provided for @homeAssimeCta.
  ///
  /// In fr, this message translates to:
  /// **'Voir les annonces'**
  String get homeAssimeCta;

  /// No description provided for @koryPledgeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Je m’engage'**
  String get koryPledgeTitle;

  /// No description provided for @koryPledgeSubtitleDue.
  ///
  /// In fr, this message translates to:
  /// **'{title} · clôture le {date}'**
  String koryPledgeSubtitleDue(Object date, Object title);

  /// No description provided for @koryPledgeStart.
  ///
  /// In fr, this message translates to:
  /// **'Montant de départ'**
  String get koryPledgeStart;

  /// No description provided for @koryPledgeDailyToggle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un montant journalier'**
  String get koryPledgeDailyToggle;

  /// No description provided for @koryPledgeDailyToggleSub.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté chaque jour à ton engagement, jusqu’à la clôture'**
  String get koryPledgeDailyToggleSub;

  /// No description provided for @koryPledgePerDay.
  ///
  /// In fr, this message translates to:
  /// **'Montant par jour'**
  String get koryPledgePerDay;

  /// No description provided for @koryPledgeStartRow.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get koryPledgeStartRow;

  /// No description provided for @koryPledgeDailyRow.
  ///
  /// In fr, this message translates to:
  /// **'{amount} × {days} jours'**
  String koryPledgeDailyRow(Object amount, Object days);

  /// No description provided for @koryPledgeTotalAt.
  ///
  /// In fr, this message translates to:
  /// **'Total engagé au {date}'**
  String koryPledgeTotalAt(Object date);

  /// No description provided for @koryPledgeEditableNotice.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux modifier ton engagement pendant 8 h. Ensuite il devient ferme : il s’inscrit au journal et le collecteur le voit.'**
  String get koryPledgeEditableNotice;

  /// No description provided for @koryPledgeConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer mon engagement'**
  String get koryPledgeConfirm;

  /// No description provided for @koryPledgeNeedDue.
  ///
  /// In fr, this message translates to:
  /// **'Un montant journalier demande une date de fin.'**
  String get koryPledgeNeedDue;

  /// No description provided for @koryMyPledgeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon engagement'**
  String get koryMyPledgeTitle;

  /// No description provided for @koryEditableFor.
  ///
  /// In fr, this message translates to:
  /// **'Modifiable encore {duration}'**
  String koryEditableFor(Object duration);

  /// No description provided for @koryFirmToday.
  ///
  /// In fr, this message translates to:
  /// **'Devient ferme aujourd’hui à {time}'**
  String koryFirmToday(Object time);

  /// No description provided for @koryFirmOn.
  ///
  /// In fr, this message translates to:
  /// **'Devient ferme le {date} à {time}'**
  String koryFirmOn(Object date, Object time);

  /// No description provided for @koryDailyRow.
  ///
  /// In fr, this message translates to:
  /// **'Montant journalier'**
  String get koryDailyRow;

  /// No description provided for @koryPerDay.
  ///
  /// In fr, this message translates to:
  /// **'{amount} par jour'**
  String koryPerDay(Object amount);

  /// No description provided for @koryPledgeEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon engagement'**
  String get koryPledgeEdit;

  /// No description provided for @koryTimelineSaved.
  ///
  /// In fr, this message translates to:
  /// **'Engagement enregistré'**
  String get koryTimelineSaved;

  /// No description provided for @koryTimelineEditable.
  ///
  /// In fr, this message translates to:
  /// **'Modifiable pendant 8 h'**
  String get koryTimelineEditable;

  /// No description provided for @koryTimelineUntil.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à {time} · le collecteur ne le voit pas encore'**
  String koryTimelineUntil(Object time);

  /// No description provided for @koryTimelineFirm.
  ///
  /// In fr, this message translates to:
  /// **'Engagement ferme'**
  String get koryTimelineFirm;

  /// No description provided for @koryTimelineFirmSub.
  ///
  /// In fr, this message translates to:
  /// **'Inscrit au journal, visible du collecteur'**
  String get koryTimelineFirmSub;

  /// No description provided for @koryPayNowOrLater.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux verser dès maintenant, ou attendre la clôture : Pokou te rappellera ce qu’il reste à verser.'**
  String get koryPayNowOrLater;

  /// No description provided for @koryPayNow.
  ///
  /// In fr, this message translates to:
  /// **'Verser maintenant'**
  String get koryPayNow;

  /// No description provided for @koryFirmSince.
  ///
  /// In fr, this message translates to:
  /// **'Ferme depuis le {date}'**
  String koryFirmSince(Object date);

  /// No description provided for @koryPaidConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Versé et confirmé'**
  String get koryPaidConfirmed;

  /// No description provided for @koryRemainingToPay.
  ///
  /// In fr, this message translates to:
  /// **'Reste à verser'**
  String get koryRemainingToPay;

  /// No description provided for @koryNextDailyAdd.
  ///
  /// In fr, this message translates to:
  /// **'Prochain ajout journalier : demain, +{amount}'**
  String koryNextDailyAdd(Object amount);

  /// No description provided for @koryFirmNotice.
  ///
  /// In fr, this message translates to:
  /// **'Un engagement ferme ne se modifie plus. En cas d’imprévu, écris au collecteur : lui seul peut l’annuler, et c’est noté au journal.'**
  String get koryFirmNotice;

  /// No description provided for @koryPayAmount.
  ///
  /// In fr, this message translates to:
  /// **'Verser {amount}'**
  String koryPayAmount(Object amount);

  /// No description provided for @koryWriteTo.
  ///
  /// In fr, this message translates to:
  /// **'Écrire à {name}'**
  String koryWriteTo(Object name);

  /// No description provided for @koryMyPledgeTotal.
  ///
  /// In fr, this message translates to:
  /// **'Engagé : {amount}'**
  String koryMyPledgeTotal(Object amount);

  /// No description provided for @koryContestedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contribution contestée'**
  String get koryContestedTitle;

  /// No description provided for @koryContestedHead.
  ///
  /// In fr, this message translates to:
  /// **'{name} n’a pas constaté ton envoi'**
  String koryContestedHead(Object name);

  /// No description provided for @koryContestedDeclared.
  ///
  /// In fr, this message translates to:
  /// **'{amount} déclarés à {time}'**
  String koryContestedDeclared(Object amount, Object time);

  /// No description provided for @koryContestedReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif : « {reason} »'**
  String koryContestedReason(Object reason);

  /// No description provided for @koryCheckReference.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier la référence'**
  String get koryCheckReference;

  /// No description provided for @koryAddSmsCapture.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une capture du SMS'**
  String get koryAddSmsCapture;

  /// No description provided for @koryContestedOperatorNotice.
  ///
  /// In fr, this message translates to:
  /// **'Si tu as envoyé sur un autre numéro, seul ton opérateur peut récupérer l’argent : il ne passe jamais par Pokou.'**
  String get koryContestedOperatorNotice;

  /// No description provided for @koryResubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyé au collecteur pour une nouvelle vérification.'**
  String get koryResubmitted;

  /// No description provided for @koryRejectReasonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi ne l’as-tu pas reçu ?'**
  String get koryRejectReasonTitle;

  /// No description provided for @koryRejectReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Rien reçu sur mon wallet à cette heure-là.'**
  String get koryRejectReasonHint;

  /// No description provided for @koryFinishTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fin de la collecte'**
  String get koryFinishTitle;

  /// No description provided for @koryFinishSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{title} · vue du collecteur'**
  String koryFinishSubtitle(Object title);

  /// No description provided for @koryFinishDueNotice.
  ///
  /// In fr, this message translates to:
  /// **'La date de fin est atteinte : à toi de clôturer ou de prolonger.'**
  String get koryFinishDueNotice;

  /// No description provided for @koryEngaged.
  ///
  /// In fr, this message translates to:
  /// **'Engagé'**
  String get koryEngaged;

  /// No description provided for @koryParticipantsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 participant} other{{count} participants}}'**
  String koryParticipantsCount(num count);

  /// No description provided for @koryConfirmedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confirmé'**
  String get koryConfirmedLabel;

  /// No description provided for @koryOnGoal.
  ///
  /// In fr, this message translates to:
  /// **'sur {amount}'**
  String koryOnGoal(Object amount);

  /// No description provided for @koryToConfirmLabel.
  ///
  /// In fr, this message translates to:
  /// **'À confirmer'**
  String get koryToConfirmLabel;

  /// No description provided for @koryDeclarationsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 déclaration} other{{count} déclarations}}'**
  String koryDeclarationsCount(num count);

  /// No description provided for @koryWhatDoYouDo.
  ///
  /// In fr, this message translates to:
  /// **'Que fais-tu ?'**
  String get koryWhatDoYouDo;

  /// No description provided for @koryCloseCollect.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer la collecte'**
  String get koryCloseCollect;

  /// No description provided for @koryCloseCollectSub.
  ///
  /// In fr, this message translates to:
  /// **'Chacun reçoit ce qu’il lui reste à verser, et le lien vers son wallet'**
  String get koryCloseCollectSub;

  /// No description provided for @koryExtend.
  ///
  /// In fr, this message translates to:
  /// **'Prolonger'**
  String get koryExtend;

  /// No description provided for @koryExtendSub.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle date de fin : {date} · les engagements restent fermes'**
  String koryExtendSub(Object date);

  /// No description provided for @koryFinishJournalNote.
  ///
  /// In fr, this message translates to:
  /// **'Les participants sont prévenus par une notification. Le journal garde la date et ton choix.'**
  String get koryFinishJournalNote;

  /// No description provided for @koryCloseAndNotify.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Clôturer et prévenir le participant} other{Clôturer et prévenir les {count} participants}}'**
  String koryCloseAndNotify(num count);

  /// No description provided for @koryExtendTo.
  ///
  /// In fr, this message translates to:
  /// **'Prolonger jusqu’au {date}'**
  String koryExtendTo(Object date);

  /// No description provided for @koryFinishCta.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer ou prolonger'**
  String get koryFinishCta;

  /// No description provided for @koryClosedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Collecte clôturée'**
  String get koryClosedTitle;

  /// No description provided for @koryClosedSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{title} · vue du participant'**
  String koryClosedSubtitle(Object title);

  /// No description provided for @koryClosedBody.
  ///
  /// In fr, this message translates to:
  /// **'{name} a clôturé la collecte le {date}. Il te reste à verser la fin de ton engagement.'**
  String koryClosedBody(Object date, Object name);

  /// No description provided for @koryAlreadyConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Déjà confirmé'**
  String get koryAlreadyConfirmed;

  /// No description provided for @koryToPay.
  ///
  /// In fr, this message translates to:
  /// **'À verser'**
  String get koryToPay;

  /// No description provided for @korySendTo.
  ///
  /// In fr, this message translates to:
  /// **'Envoie à'**
  String get korySendTo;

  /// No description provided for @koryReferenceToGive.
  ///
  /// In fr, this message translates to:
  /// **'Référence à indiquer {reference}'**
  String koryReferenceToGive(Object reference);

  /// No description provided for @koryCopyReference.
  ///
  /// In fr, this message translates to:
  /// **'Copier la référence'**
  String get koryCopyReference;

  /// No description provided for @koryPayFromWallet.
  ///
  /// In fr, this message translates to:
  /// **'Verser {amount} depuis mon wallet'**
  String koryPayFromWallet(Object amount);

  /// No description provided for @koryAlreadySent.
  ///
  /// In fr, this message translates to:
  /// **'J’ai déjà envoyé'**
  String get koryAlreadySent;

  /// No description provided for @notifCenterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifCenterTitle;

  /// No description provided for @notifReadAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout lire'**
  String get notifReadAll;

  /// No description provided for @notifToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui'**
  String get notifToday;

  /// No description provided for @notifYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get notifYesterday;

  /// No description provided for @notifEarlier.
  ///
  /// In fr, this message translates to:
  /// **'Plus tôt'**
  String get notifEarlier;

  /// No description provided for @notifMessagesElsewhere.
  ///
  /// In fr, this message translates to:
  /// **'Les messages n’apparaissent pas ici : ils restent dans Discussions.'**
  String get notifMessagesElsewhere;

  /// No description provided for @notifEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification pour l’instant.'**
  String get notifEmpty;

  /// No description provided for @notifServiceCertified.
  ///
  /// In fr, this message translates to:
  /// **'Pokou certifié'**
  String get notifServiceCertified;

  /// No description provided for @notifSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages des notifications'**
  String get notifSettings;

  /// No description provided for @certPausedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Badge en pause'**
  String get certPausedTitle;

  /// No description provided for @certPausedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement du {due} n’a pas abouti. Ton badge est masqué depuis le {since}, après {days} jours de grâce.'**
  String certPausedBody(Object days, Object due, Object since);

  /// No description provided for @certWhatRemains.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui reste'**
  String get certWhatRemains;

  /// No description provided for @certRemainsChats.
  ///
  /// In fr, this message translates to:
  /// **'Tes discussions et tes contacts'**
  String get certRemainsChats;

  /// No description provided for @certRemainsTraces.
  ///
  /// In fr, this message translates to:
  /// **'Les traces déjà enregistrées par le mode preuve'**
  String get certRemainsTraces;

  /// No description provided for @certWhatPaused.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui est en pause'**
  String get certWhatPaused;

  /// No description provided for @certPausedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Le badge et le nom vérifié'**
  String get certPausedBadge;

  /// No description provided for @certPausedProof.
  ///
  /// In fr, this message translates to:
  /// **'Le mode preuve des nouveaux messages et l’export daté'**
  String get certPausedProof;

  /// No description provided for @certPausedWallet.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement se fait par ton wallet. Si ton solde était insuffisant, recharge-le puis réessaie.'**
  String get certPausedWallet;

  /// No description provided for @certPausedPay.
  ///
  /// In fr, this message translates to:
  /// **'Payer {amount} et réafficher mon badge'**
  String certPausedPay(Object amount);

  /// No description provided for @certChangePlan.
  ///
  /// In fr, this message translates to:
  /// **'Changer de formule'**
  String get certChangePlan;

  /// No description provided for @annSoldTitle.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme vendue'**
  String get annSoldTitle;

  /// No description provided for @annSoldWho.
  ///
  /// In fr, this message translates to:
  /// **'À qui l’as-tu vendue ? Cette personne pourra noter la transaction.'**
  String get annSoldWho;

  /// No description provided for @annSoldDiscussionOf.
  ///
  /// In fr, this message translates to:
  /// **'Discussion du {date}'**
  String annSoldDiscussionOf(Object date);

  /// No description provided for @annSoldOutside.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu’un hors de Pokou'**
  String get annSoldOutside;

  /// No description provided for @annSoldOutsideSub.
  ///
  /// In fr, this message translates to:
  /// **'Pas de note possible pour cette vente'**
  String get annSoldOutsideSub;

  /// No description provided for @annSoldFinalPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix final'**
  String get annSoldFinalPrice;

  /// No description provided for @annSoldPriceHelp.
  ///
  /// In fr, this message translates to:
  /// **'Visible seulement de toi et de l’acheteur'**
  String get annSoldPriceHelp;

  /// No description provided for @annSoldConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la vente'**
  String get annSoldConfirm;

  /// No description provided for @annSoldBadge.
  ///
  /// In fr, this message translates to:
  /// **'Vendue'**
  String get annSoldBadge;

  /// No description provided for @annSoldDone.
  ///
  /// In fr, this message translates to:
  /// **'Vente enregistrée.'**
  String get annSoldDone;

  /// No description provided for @annRateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Noter la transaction'**
  String get annRateTitle;

  /// No description provided for @annRateHow.
  ///
  /// In fr, this message translates to:
  /// **'Comment s’est passée ta transaction ?'**
  String get annRateHow;

  /// No description provided for @annRate1.
  ///
  /// In fr, this message translates to:
  /// **'Décevant'**
  String get annRate1;

  /// No description provided for @annRate2.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get annRate2;

  /// No description provided for @annRate3.
  ///
  /// In fr, this message translates to:
  /// **'Correct'**
  String get annRate3;

  /// No description provided for @annRate4.
  ///
  /// In fr, this message translates to:
  /// **'Très bien'**
  String get annRate4;

  /// No description provided for @annRate5.
  ///
  /// In fr, this message translates to:
  /// **'Excellent'**
  String get annRate5;

  /// No description provided for @annRateStars.
  ///
  /// In fr, this message translates to:
  /// **'{count} étoiles sur 5'**
  String annRateStars(Object count);

  /// No description provided for @annRateWentWell.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui s’est bien passé'**
  String get annRateWentWell;

  /// No description provided for @annTagAsDescribed.
  ///
  /// In fr, this message translates to:
  /// **'Conforme à l’annonce'**
  String get annTagAsDescribed;

  /// No description provided for @annTagPunctual.
  ///
  /// In fr, this message translates to:
  /// **'Ponctuel·le'**
  String get annTagPunctual;

  /// No description provided for @annTagFairPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix respecté'**
  String get annTagFairPrice;

  /// No description provided for @annTagFriendly.
  ///
  /// In fr, this message translates to:
  /// **'Aimable'**
  String get annTagFriendly;

  /// No description provided for @annTagCommunication.
  ///
  /// In fr, this message translates to:
  /// **'Bonne communication'**
  String get annTagCommunication;

  /// No description provided for @annRateComment.
  ///
  /// In fr, this message translates to:
  /// **'Ton avis (facultatif)'**
  String get annRateComment;

  /// No description provided for @annRateNotice.
  ///
  /// In fr, this message translates to:
  /// **'Ton avis s’affiche avec ton prénom et l’initiale de ton nom. Seule une vente confirmée par le vendeur peut être notée, une seule fois.'**
  String get annRateNotice;

  /// No description provided for @annRatePublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier mon avis'**
  String get annRatePublish;

  /// No description provided for @annRatePublished.
  ///
  /// In fr, this message translates to:
  /// **'Merci, ton avis est publié.'**
  String get annRatePublished;

  /// No description provided for @annRateAlready.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà noté cette vente.'**
  String get annRateAlready;

  /// No description provided for @annRateSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{seller} · {product}'**
  String annRateSubtitle(Object product, Object seller);

  /// No description provided for @backupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde'**
  String get backupTitle;

  /// No description provided for @backupWhere.
  ///
  /// In fr, this message translates to:
  /// **'Pokou, chiffrée sur ton téléphone'**
  String get backupWhere;

  /// No description provided for @backupLast.
  ///
  /// In fr, this message translates to:
  /// **'Dernière sauvegarde'**
  String get backupLast;

  /// No description provided for @backupContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu'**
  String get backupContent;

  /// No description provided for @backupContentValue.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 discussion} other{{count} discussions}} · {size}'**
  String backupContentValue(num count, Object size);

  /// No description provided for @backupNever.
  ///
  /// In fr, this message translates to:
  /// **'Jamais'**
  String get backupNever;

  /// No description provided for @backupExplain.
  ///
  /// In fr, this message translates to:
  /// **'Tes discussions sont chiffrées sur ce téléphone avec ton mot de passe avant d’être envoyées. Sans lui, personne ne peut les lire, pas même Pokou : garde-le précieusement.'**
  String get backupExplain;

  /// No description provided for @backupSetPassword.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un mot de passe'**
  String get backupSetPassword;

  /// No description provided for @backupChangePassword.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get backupChangePassword;

  /// No description provided for @backupPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe de sauvegarde'**
  String get backupPasswordLabel;

  /// No description provided for @backupPasswordConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirme le mot de passe'**
  String get backupPasswordConfirm;

  /// No description provided for @backupPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères au moins.'**
  String get backupPasswordTooShort;

  /// No description provided for @backupPasswordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux mots de passe ne correspondent pas.'**
  String get backupPasswordMismatch;

  /// No description provided for @backupNow.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder maintenant'**
  String get backupNow;

  /// No description provided for @backupDone.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde terminée.'**
  String get backupDone;

  /// No description provided for @backupDaily.
  ///
  /// In fr, this message translates to:
  /// **'Une sauvegarde est faite chaque jour, à l’ouverture de Pokou.'**
  String get backupDaily;

  /// No description provided for @backupDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la sauvegarde'**
  String get backupDelete;

  /// No description provided for @backupFailed.
  ///
  /// In fr, this message translates to:
  /// **'La sauvegarde n’a pas abouti. Réessaie.'**
  String get backupFailed;

  /// No description provided for @welcomeBackBaba.
  ///
  /// In fr, this message translates to:
  /// **'Bon retour, {name} ! J’ai retrouvé ton compte et ta sauvegarde. Tes groupes, tes cagnottes Kory et ton badge te suivent.'**
  String welcomeBackBaba(Object name);

  /// No description provided for @welcomeBackOrder.
  ///
  /// In fr, this message translates to:
  /// **'Discussions et état du mode preuve d’abord ; photos et vidéos ensuite, à l’ouverture de chaque discussion.'**
  String get welcomeBackOrder;

  /// No description provided for @welcomeBackOldPhone.
  ///
  /// In fr, this message translates to:
  /// **'Ton ancien téléphone sera déconnecté.'**
  String get welcomeBackOldPhone;

  /// No description provided for @welcomeBackRestore.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get welcomeBackRestore;

  /// No description provided for @welcomeBackSkip.
  ///
  /// In fr, this message translates to:
  /// **'Continuer sans restaurer'**
  String get welcomeBackSkip;

  /// No description provided for @restoreWrongPassword.
  ///
  /// In fr, this message translates to:
  /// **'Ce mot de passe ne correspond pas à la sauvegarde.'**
  String get restoreWrongPassword;

  /// No description provided for @restoreCardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Restauration de tes discussions'**
  String get restoreCardTitle;

  /// No description provided for @restoreCardBody.
  ///
  /// In fr, this message translates to:
  /// **'{done} discussions sur {total}. Photos et vidéos ensuite, à l’ouverture.'**
  String restoreCardBody(Object done, Object total);

  /// No description provided for @restoreDone.
  ///
  /// In fr, this message translates to:
  /// **'Tes discussions sont de retour.'**
  String get restoreDone;

  /// No description provided for @koryParticipantsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get koryParticipantsTitle;

  /// No description provided for @koryStepOf.
  ///
  /// In fr, this message translates to:
  /// **'{title} · étape {step} sur {total}'**
  String koryStepOf(Object step, Object title, Object total);

  /// No description provided for @koryLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get koryLastName;

  /// No description provided for @koryFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get koryFirstName;

  /// No description provided for @koryPhoneField.
  ///
  /// In fr, this message translates to:
  /// **'Numéro'**
  String get koryPhoneField;

  /// No description provided for @koryAddParticipant.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get koryAddParticipant;

  /// No description provided for @koryAddedCount.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutés · {count}'**
  String koryAddedCount(Object count);

  /// No description provided for @koryFromContacts.
  ///
  /// In fr, this message translates to:
  /// **'Depuis mes contacts'**
  String get koryFromContacts;

  /// No description provided for @koryOnPokou.
  ///
  /// In fr, this message translates to:
  /// **'Sur Pokou'**
  String get koryOnPokou;

  /// No description provided for @koryInvitedChip.
  ///
  /// In fr, this message translates to:
  /// **'Invité·e'**
  String get koryInvitedChip;

  /// No description provided for @koryCollectorChip.
  ///
  /// In fr, this message translates to:
  /// **'Collecteur'**
  String get koryCollectorChip;

  /// No description provided for @koryRemoveParticipant.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name}'**
  String koryRemoveParticipant(Object name);

  /// No description provided for @koryInviteNote.
  ///
  /// In fr, this message translates to:
  /// **'Sans Pokou, la personne reçoit un SMS d’invitation. Elle reste « Invitée » jusqu’à son inscription, puis s’engage comme les autres.'**
  String get koryInviteNote;

  /// No description provided for @koryContinueWith.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Continuer sans participant} =1{Continuer avec 1 participant} other{Continuer avec {count} participants}}'**
  String koryContinueWith(num count);

  /// No description provided for @koryInvalidPhone.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro n’est pas valide.'**
  String get koryInvalidPhone;

  /// No description provided for @storageManage.
  ///
  /// In fr, this message translates to:
  /// **'Gérer le stockage'**
  String get storageManage;

  /// No description provided for @storageBigFiles.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers de plus de 5 Mo'**
  String get storageBigFiles;

  /// No description provided for @storageAutoDownload.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement automatique'**
  String get storageAutoDownload;

  /// No description provided for @storageOnWifi.
  ///
  /// In fr, this message translates to:
  /// **'En Wi-Fi'**
  String get storageOnWifi;

  /// No description provided for @autoDownloadNone.
  ///
  /// In fr, this message translates to:
  /// **'Rien'**
  String get autoDownloadNone;

  /// No description provided for @autoDownloadPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get autoDownloadPhotos;

  /// No description provided for @autoDownloadPhotosVideos.
  ///
  /// In fr, this message translates to:
  /// **'Photos et vidéos'**
  String get autoDownloadPhotosVideos;

  /// No description provided for @autoDownloadAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get autoDownloadAll;

  /// No description provided for @storageCallSaver.
  ///
  /// In fr, this message translates to:
  /// **'Économiser les données pendant les appels'**
  String get storageCallSaver;

  /// No description provided for @storageCallSaverSub.
  ///
  /// In fr, this message translates to:
  /// **'Qualité réduite, appel plus stable'**
  String get storageCallSaverSub;

  /// No description provided for @storagePokouUses.
  ///
  /// In fr, this message translates to:
  /// **'Pokou · {size}'**
  String storagePokouUses(Object size);

  /// No description provided for @storageOtherDiscussion.
  ///
  /// In fr, this message translates to:
  /// **'Autres fichiers'**
  String get storageOtherDiscussion;

  /// No description provided for @callReconnecting.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion…'**
  String get callReconnecting;

  /// No description provided for @homeSearchEverything.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un contact, un service, une annonce'**
  String get homeSearchEverything;

  /// No description provided for @homeBabaTitle.
  ///
  /// In fr, this message translates to:
  /// **'Besoin d’un coup de main ?'**
  String get homeBabaTitle;

  /// No description provided for @homeBabaSub.
  ///
  /// In fr, this message translates to:
  /// **'Pose ta question à Baba, il s’occupe du reste.'**
  String get homeBabaSub;

  /// No description provided for @homeAlertsActive.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 alerte active} other{{count} alertes actives}}'**
  String homeAlertsActive(num count);

  /// No description provided for @homeSeeAllUnread.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir ({count} non lus)'**
  String homeSeeAllUnread(Object count);

  /// No description provided for @homeServicesSub.
  ///
  /// In fr, this message translates to:
  /// **'Des services simples, pensés pour ton quotidien.'**
  String get homeServicesSub;

  /// No description provided for @homeKoryOverline.
  ///
  /// In fr, this message translates to:
  /// **'CAGNOTTES & TONTINES'**
  String get homeKoryOverline;

  /// No description provided for @homeHonamOverline.
  ///
  /// In fr, this message translates to:
  /// **'« AIDE-MOI »'**
  String get homeHonamOverline;

  /// No description provided for @homeAssimeOverline.
  ///
  /// In fr, this message translates to:
  /// **'« AU MARCHÉ »'**
  String get homeAssimeOverline;

  /// No description provided for @homeTrustOverline.
  ///
  /// In fr, this message translates to:
  /// **'CONFIANCE ABSOLUE'**
  String get homeTrustOverline;

  /// No description provided for @homeTrustBody.
  ///
  /// In fr, this message translates to:
  /// **'Tes données et échanges sont chiffrés de bout en bout.'**
  String get homeTrustBody;

  /// No description provided for @homeKoryInProgress.
  ///
  /// In fr, this message translates to:
  /// **'KORY • CAGNOTTE'**
  String get homeKoryInProgress;

  /// No description provided for @homeHonamInProgress.
  ///
  /// In fr, this message translates to:
  /// **'HONAM • SANTÉ'**
  String get homeHonamInProgress;

  /// No description provided for @homeKoryNoMoney.
  ///
  /// In fr, this message translates to:
  /// **'Pokou ne touche pas l’argent'**
  String get homeKoryNoMoney;

  /// No description provided for @discussionsStatusesNews.
  ///
  /// In fr, this message translates to:
  /// **'STATUTS & NOUVELLES'**
  String get discussionsStatusesNews;

  /// No description provided for @statusMyStatus.
  ///
  /// In fr, this message translates to:
  /// **'Mon statut'**
  String get statusMyStatus;

  /// No description provided for @babaAssistantChip.
  ///
  /// In fr, this message translates to:
  /// **'ASSISTANT IA'**
  String get babaAssistantChip;

  /// No description provided for @babaTranslate.
  ///
  /// In fr, this message translates to:
  /// **'Traduire'**
  String get babaTranslate;

  /// No description provided for @babaSummarize.
  ///
  /// In fr, this message translates to:
  /// **'Résumer'**
  String get babaSummarize;

  /// No description provided for @babaAlwaysThere.
  ///
  /// In fr, this message translates to:
  /// **'Toujours là pour traduire, résumer ou répondre à tes questions.'**
  String get babaAlwaysThere;

  /// No description provided for @koryHeadline.
  ///
  /// In fr, this message translates to:
  /// **'Kory · Le cauris'**
  String get koryHeadline;

  /// No description provided for @koryWalletChip.
  ///
  /// In fr, this message translates to:
  /// **'WALLET À WALLET'**
  String get koryWalletChip;

  /// No description provided for @koryNeverTouches.
  ///
  /// In fr, this message translates to:
  /// **'Pokou ne touche jamais ton argent. Les contributions passent directement de wallet à wallet, sans intermédiaire.'**
  String get koryNeverTouches;

  /// No description provided for @koryMonthActivity.
  ///
  /// In fr, this message translates to:
  /// **'ACTIVITÉ DU MOIS'**
  String get koryMonthActivity;

  /// No description provided for @backupDestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Où sauvegarder'**
  String get backupDestTitle;

  /// No description provided for @backupDestDrive.
  ///
  /// In fr, this message translates to:
  /// **'Google Drive'**
  String get backupDestDrive;

  /// No description provided for @backupDestDriveSub.
  ///
  /// In fr, this message translates to:
  /// **'Sur ton compte Google, dans un dossier caché que seul Pokou peut lire'**
  String get backupDestDriveSub;

  /// No description provided for @backupDestPokou.
  ///
  /// In fr, this message translates to:
  /// **'Pokou'**
  String get backupDestPokou;

  /// No description provided for @backupGoogleAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte Google'**
  String get backupGoogleAccount;

  /// No description provided for @backupChangeAccount.
  ///
  /// In fr, this message translates to:
  /// **'Changer de compte'**
  String get backupChangeAccount;

  /// No description provided for @backupNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte choisi'**
  String get backupNoAccount;

  /// No description provided for @backupWhereDrive.
  ///
  /// In fr, this message translates to:
  /// **'Google Drive · {email}'**
  String backupWhereDrive(Object email);

  /// No description provided for @restoreFindDrive.
  ///
  /// In fr, this message translates to:
  /// **'Retrouver ma sauvegarde Google Drive'**
  String get restoreFindDrive;

  /// No description provided for @restoreNoDrive.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sauvegarde Pokou sur ce compte Google.'**
  String get restoreNoDrive;

  /// No description provided for @restoreWelcomeNoBackup.
  ///
  /// In fr, this message translates to:
  /// **'Bon retour ! Si tu avais sauvegardé tes discussions sur Google Drive, retrouve-les ici.'**
  String get restoreWelcomeNoBackup;

  /// No description provided for @marketPriceInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Ce prix n\'est pas valide. Écris seulement le montant, par exemple 5000.'**
  String get marketPriceInvalid;

  /// No description provided for @marketPublishFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'annonce n\'a pas pu être publiée. Rien n\'est perdu : vérifie ta connexion et réessaie.'**
  String get marketPublishFailed;

  /// No description provided for @statusChangeFont.
  ///
  /// In fr, this message translates to:
  /// **'Changer la police'**
  String get statusChangeFont;

  /// No description provided for @statusChangeBackground.
  ///
  /// In fr, this message translates to:
  /// **'Changer le fond'**
  String get statusChangeBackground;

  /// No description provided for @statusBackgroundNumber.
  ///
  /// In fr, this message translates to:
  /// **'Fond {number}'**
  String statusBackgroundNumber(String number);

  /// No description provided for @statusVisible24h.
  ///
  /// In fr, this message translates to:
  /// **'Visible 24 h, par les contacts que tu as choisis.'**
  String get statusVisible24h;

  /// No description provided for @homeUnreadSummary.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 message non lu} other{{count} messages non lus}}'**
  String homeUnreadSummary(int count);

  /// No description provided for @homeServicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get homeServicesTitle;

  /// No description provided for @homeKoryShort.
  ///
  /// In fr, this message translates to:
  /// **'Cagnottes et tontines à plusieurs'**
  String get homeKoryShort;

  /// No description provided for @homeHonamShort.
  ///
  /// In fr, this message translates to:
  /// **'Tes médicaments livrés'**
  String get homeHonamShort;

  /// No description provided for @homeAssimeShort.
  ///
  /// In fr, this message translates to:
  /// **'Acheter et vendre près de chez toi'**
  String get homeAssimeShort;

  /// No description provided for @homeDaysLeft.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{Dernier jour} =1{1 jour} other{{days} jours}}'**
  String homeDaysLeft(int days);

  /// No description provided for @emojiNoRecents.
  ///
  /// In fr, this message translates to:
  /// **'Tes emojis récents apparaîtront ici.'**
  String get emojiNoRecents;

  /// No description provided for @emojiSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un emoji'**
  String get emojiSearchHint;

  /// No description provided for @composerBackspace.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get composerBackspace;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'fr',
    'it',
    'ru',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LAr();
    case 'en':
      return LEn();
    case 'es':
      return LEs();
    case 'fr':
      return LFr();
    case 'it':
      return LIt();
    case 'ru':
      return LRu();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
