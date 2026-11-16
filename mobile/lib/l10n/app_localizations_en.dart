// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Pokou';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionClose => 'Close';

  @override
  String get actionShare => 'Share';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionSend => 'Send';

  @override
  String get actionJoin => 'Join';

  @override
  String get actionCreate => 'Create';

  @override
  String get navChats => 'Chats';

  @override
  String get navStatus => 'Status';

  @override
  String get navCalls => 'Calls';

  @override
  String get navMarket => 'Market';

  @override
  String get chatsEmptyTitle => 'No chats yet';

  @override
  String get chatsEmptyBody => 'Your conversations will show up here.';

  @override
  String get chatsSearchHint => 'Search';

  @override
  String get chatsTyping => 'typing…';

  @override
  String chatsTypingNamed(String name) {
    return '$name is typing…';
  }

  @override
  String get chatsUnknownContact => 'not in your contacts';

  @override
  String get chatsNoMessageYet => 'No messages yet';

  @override
  String chatsYouPrefix(String message) {
    return 'You: $message';
  }

  @override
  String chatsGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups',
      one: '1 group',
      zero: 'No groups',
    );
    return '$_temp0';
  }

  @override
  String get newChatTitle => 'New chat';

  @override
  String get newChatSearchHint => 'Search a contact';

  @override
  String get newChatNewGroup => 'New group';

  @override
  String get newChatNewCommunity => 'New community';

  @override
  String get newChatJoinByLink => 'Join with a link';

  @override
  String get newChatOnPokou => 'On Pokou Messenger';

  @override
  String get newChatInvite => 'Invite to Pokou Messenger';

  @override
  String get newChatNoMatch => 'No contact matches.';

  @override
  String get newChatNoRegisteredContact =>
      'None of your contacts are on Pokou yet.';

  @override
  String conversationSayHello(String name) {
    return 'Say hello to $name.';
  }

  @override
  String get conversationMessageHint => 'Message';

  @override
  String get conversationEdit => 'Edit';

  @override
  String get conversationForward => 'Forward';

  @override
  String get conversationReply => 'Reply';

  @override
  String get conversationEditWindowOver =>
      'This message can no longer be edited.';

  @override
  String get mediaPhoto => 'Photo';

  @override
  String get mediaVideo => 'Video';

  @override
  String get mediaVoice => 'Voice message';

  @override
  String get mediaDocument => 'Document';

  @override
  String get mediaLocation => 'Location';

  @override
  String get offlineTitle => 'Offline';

  @override
  String get offlineBody =>
      'You\'ll see what is already on this device. The rest arrives when the network comes back.';

  @override
  String get offlineNothingCached => 'Nothing is saved on this device yet.';

  @override
  String get offlineSending => 'Waiting to send';

  @override
  String get errorNetwork => 'Can\'t connect. Check your network.';

  @override
  String get twoStepTitle => 'Two-step verification';

  @override
  String get twoStepBody =>
      'This account is protected by a PIN. Enter it to finish signing in.';

  @override
  String get twoStepHint => 'Account PIN';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLanguageSystem => 'Phone language';

  @override
  String get profileLanguageSubtitle => 'Choose the app language';

  @override
  String get languageFrench => 'French';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageItalian => 'Italian';

  @override
  String get sparkTitle => 'Spark';

  @override
  String get sparkSubtitle => 'Today\'s date';

  @override
  String get sparkTabDiscover => 'Discover';

  @override
  String get sparkTabMatches => 'Matches';

  @override
  String get sparkTabDates => 'Dates';

  @override
  String get sparkTabMe => 'Me';

  @override
  String get sparkAddPhoto => 'Add a photo';

  @override
  String get sparkNoPhotoWarning =>
      'Add a photo — without one, almost nobody likes';

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
  String get sparkLike => 'Like';

  @override
  String get sparkPass => 'Pass';

  @override
  String get sparkAgeRestricted => 'Spark is for 18 and over.';

  @override
  String get navProfile => 'Profile';

  @override
  String get authWelcome => 'Welcome to Pokou';

  @override
  String get authSubtitle =>
      'Enter your number and we\'ll send you a code. New to Pokou? Your account is created at this step.';

  @override
  String get authPhoneHint => 'Your number';

  @override
  String get authPrivacyNote =>
      'Secure sign-in. Your number is only used to verify who you are.';

  @override
  String get authVerifyTitle => 'Verification';

  @override
  String authCodeSentTo(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String get authChangeNumber => 'Change number';

  @override
  String authResendIn(String time) {
    return 'Resend the code in $time';
  }

  @override
  String get authResendSms => 'Resend by SMS';

  @override
  String get authResendWhatsapp => 'Resend via WhatsApp';

  @override
  String get authCodeSentSms => 'A new code was sent by SMS.';

  @override
  String get authCodeSentWhatsapp => 'A new code was sent on WhatsApp.';

  @override
  String get chatsPin => 'Pin';

  @override
  String get chatsUnpin => 'Unpin';

  @override
  String get chatsArchive => 'Archive';

  @override
  String get chatsUnarchive => 'Unarchive';

  @override
  String get chatsMute => 'Mute';

  @override
  String get chatsUnmute => 'Unmute';

  @override
  String get chatsTag => 'Tag';

  @override
  String chatsTagNamed(String name) {
    return 'Tag $name';
  }

  @override
  String get chatsBlock => 'Block';

  @override
  String chatsBlockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get chatsBlockBody =>
      'This person won\'t be able to message or call you. They won\'t be told.';

  @override
  String get chatsPinLimit => 'Three pinned chats at most.';

  @override
  String get chatsMute8h => '8 hours';

  @override
  String get chatsMute1w => '1 week';

  @override
  String get chatsMuteAlways => 'Always';

  @override
  String get chatsAddContact => 'Add to my contacts';

  @override
  String get chatsActionFailed => 'That didn\'t work right now.';

  @override
  String get chatsNoResult => 'No results.';

  @override
  String get chatsConnectFailed => 'Can\'t connect.';

  @override
  String get navModules => 'Modules';

  @override
  String get navBroadcasts => 'Broadcast lists';

  @override
  String get navYou => 'You';

  @override
  String get convProductFallback => 'Product';

  @override
  String get convOrderUpdated => 'Order updated';

  @override
  String get convReactionFailed => 'Couldn\'t react.';

  @override
  String get convPermissionDenied => 'Permission denied.';

  @override
  String get convAttachDocument => 'Document';

  @override
  String get convAttachGallery => 'Photo (gallery)';

  @override
  String get convAttachVideo => 'Video (gallery)';

  @override
  String get convAttachCamera => 'Camera';

  @override
  String get convEditTitle => 'Edit message';

  @override
  String get convEditHint => 'Your message';

  @override
  String convForwarded(String name) {
    return 'Message forwarded to $name.';
  }

  @override
  String get convForwardFailed => 'Couldn\'t forward.';

  @override
  String get convRecordVoice => 'Record a voice note';

  @override
  String get mediaVoiceNote => 'Voice note';

  @override
  String get mediaMessage => 'Message';

  @override
  String get newChatInviteAction => 'Invite';

  @override
  String get profileGallery => 'Gallery';

  @override
  String get profileCamera => 'Camera';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get profileFullName => 'Full name';

  @override
  String get profileAbout => 'About';

  @override
  String get profileUpdateFailed => 'Couldn\'t update.';

  @override
  String get profileVerifiedPhone => 'Identity verified by phone';

  @override
  String get profilePrivacySecurity => 'Privacy & Security';

  @override
  String get profileShieldMode => 'Shield Mode';

  @override
  String get profileShieldOn => 'Shield Mode on';

  @override
  String get profileShieldOff => 'Shield Mode off';

  @override
  String get profileConnection => 'Connection';

  @override
  String get profileEncryptedTls => 'Encrypted (TLS)';

  @override
  String get profileStatusVisibility => 'Status visibility';

  @override
  String get commonEnabled => 'On';

  @override
  String get commonDisabled => 'Off';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get profileDevices => 'Linked devices';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileStorage => 'Storage and data';

  @override
  String get profileDataSaver => 'Data saver';

  @override
  String get profileSystemPrefs => 'System preferences';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String modulesActivated(String name) {
    return '$name is on.';
  }

  @override
  String get modulesUnavailable => 'Modules unavailable';

  @override
  String get modulesCheckNetwork => 'Check your connection and try again.';

  @override
  String get modulesEmptyTitle => 'Nothing to add yet';

  @override
  String get modulesEmptyBody =>
      'New modules will show up here. Nothing to do in the meantime.';

  @override
  String get modulesMine => 'My apps';

  @override
  String get modulesRecommended => 'Recommended';

  @override
  String get modulesRecommendedBy => 'Picked by our team';

  @override
  String get modulesPopular => 'Popular';

  @override
  String get modulesPopularSub => 'Most switched on right now';

  @override
  String get modulesEnable => 'Turn on';

  @override
  String get modulesDisable => 'Turn off';

  @override
  String get modulesEnableFailed => 'Couldn\'t turn it on.';

  @override
  String modulesComingSoon(String name) {
    return '$name is coming soon. Update the app to get it as soon as it lands.';
  }

  @override
  String modulesUserCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people use it',
      one: '1 person uses it',
    );
    return '$_temp0';
  }

  @override
  String get sparkEnableLocation => 'Turn on location on your phone.';

  @override
  String get sparkLocationNeeded =>
      'Without location, Spark can\'t tell who is around you.';

  @override
  String get sparkLocationFailed => 'Couldn\'t get your location.';

  @override
  String get sparkFeedUnavailable => 'Feed unavailable';

  @override
  String get sparkPickIntentTitle => 'Pick today\'s card';

  @override
  String get sparkPickIntentBody =>
      'Say what you\'re after today to see who wants the same.';

  @override
  String get sparkLocationStale => 'Your location isn\'t current';

  @override
  String get sparkLocationStaleBody =>
      'Spark only shows people within 5 km. Without a fresh location it can\'t show anything.';

  @override
  String get sparkShareLocation => 'Share my location';

  @override
  String get sparkQuotaTitle => 'You\'ve seen today\'s profiles';

  @override
  String get sparkQuotaBody =>
      'Come back tomorrow, or get Spark+ to browse without a limit.';

  @override
  String get sparkNobodyTitle => 'Nobody right now';

  @override
  String get sparkNobodyBody =>
      'Few people want the same thing here and now. Try later — or change your card.';

  @override
  String get sparkPickCard => 'Pick your card';

  @override
  String get sparkTodayLooking => 'What you\'re after today';

  @override
  String get sparkCardExpired => 'Your card has expired';

  @override
  String sparkHoursLeft(int hours) {
    return '${hours}h left';
  }

  @override
  String sparkMinutesLeft(int minutes) {
    return '$minutes min left';
  }

  @override
  String get sparkIntentSheetTitle => 'Today, I\'m after';

  @override
  String get sparkIntentSheetBody =>
      'Your card expires in 24 h. You\'ll only see people who picked the same.';

  @override
  String get sparkLikesExhausted =>
      'You\'re out of likes for today. Get a pack in \"Me\".';

  @override
  String get sparkMatchesUnavailable => 'Matches unavailable';

  @override
  String get sparkNoMatchTitle => 'No match yet';

  @override
  String get sparkNoMatchBody =>
      'When you both like each other, a ten-minute room opens. That is where it plays out.';

  @override
  String get sparkOpenRooms => 'Open rooms';

  @override
  String get sparkRoomsClose => 'They close on their own';

  @override
  String get sparkMyMatches => 'My matches';

  @override
  String get sparkNext => 'Next';

  @override
  String get sparkPhotoFailed => 'Couldn\'t add the photo.';

  @override
  String get sparkGoFaster => 'Move faster';

  @override
  String get sparkNoExpiry => 'Never expires';

  @override
  String get sparkPlusActive => 'Active — extends your subscription';

  @override
  String get sparkPlusPitch => 'Unlimited profiles, one month';

  @override
  String get sparkBoost => 'Top Profile';

  @override
  String get sparkBoostPitch => 'At the top of the feed for an hour';

  @override
  String get sparkAroundMe => 'Around me';

  @override
  String get sparkSafety => 'Safety';

  @override
  String get sparkSafetyPitch => 'Quiet alert and circle of trust';

  @override
  String get sparkWingman => 'My friends\' take';

  @override
  String get sparkWingmanPitch => 'Profiles someone asked you about';

  @override
  String get sparkUploading => 'Uploading…';

  @override
  String get sparkKarma => 'Street Cred';

  @override
  String get sparkCanInvite => 'You can invite';

  @override
  String get sparkCannotInvite => 'Too low to invite. Keep your dates.';

  @override
  String sparkLikersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people liked you',
      one: 'One person liked you',
    );
    return '$_temp0';
  }

  @override
  String get sparkSeeWho => 'See who';

  @override
  String get sparkFindInDiscover => 'Find them in Discover.';

  @override
  String get sparkPaymentPendingLikers =>
      'The list opens as soon as the payment is confirmed.';

  @override
  String get sparkPaymentPendingLikes =>
      'Your likes arrive as soon as the payment is confirmed.';

  @override
  String get sparkPaymentPendingPlus =>
      'Spark+ turns on as soon as the payment is confirmed.';

  @override
  String get sparkPaymentPendingBoost =>
      'Your profile moves up as soon as the payment is confirmed.';

  @override
  String get sparkBirthDateLabel => 'Your date of birth';

  @override
  String get sparkNameAndBirthNeeded =>
      'A first name and a date of birth, at least.';

  @override
  String get sparkProfileFailed => 'Couldn\'t create the profile.';

  @override
  String get sparkCreateProfile => 'Create your profile';

  @override
  String get sparkStep1Title => 'You say what you\'re after, today';

  @override
  String get sparkStep1Body =>
      'Your card expires in 24 h. You only see people after the same thing, within 5 km.';

  @override
  String get sparkStep2Title => 'Ten minutes of voice before typing';

  @override
  String get sparkStep2Body =>
      'After a match, a room opens: voice and stickers only. Fake profiles don\'t get past it.';

  @override
  String get sparkStep3Title => 'Your people know where you are';

  @override
  String get sparkStep3Body =>
      'A quiet gesture alerts your circle with your location. We also ask if you\'re all right during the date.';

  @override
  String get sparkSeparateTitle => 'Your profile is separate from Pokou';

  @override
  String get sparkSeparateBody =>
      'Your Pokou name and number are never shown here. Choose what you want to display.';

  @override
  String get sparkDisplayName => 'Display name';

  @override
  String get sparkNameExample => 'e.g. Ama';

  @override
  String get sparkBirthDate => 'Date of birth';

  @override
  String get sparkBirthDateLocked => 'It can\'t be changed afterwards.';

  @override
  String get sparkChoose => 'Choose';

  @override
  String get sparkYouAre => 'You are';

  @override
  String get sparkWoman => 'A woman';

  @override
  String get sparkMan => 'A man';

  @override
  String get sparkOther => 'Other';

  @override
  String get sparkBioLabel => 'A line about you (optional)';

  @override
  String get sparkBioHint => 'What\'s worth knowing before meeting you';

  @override
  String get sparkCreateAction => 'Create my profile';

  @override
  String get truthSubtitle => 'A paid question, a free answer';

  @override
  String get truthAsk => 'Ask a question';

  @override
  String get truthForMe => 'For me';

  @override
  String get truthMine => 'My questions';

  @override
  String get truthUnavailable => 'Questions unavailable';

  @override
  String get truthEmptyTitle => 'No questions yet';

  @override
  String get truthEmptyBody =>
      'When someone pays to ask you a question, it shows up here. You stay free to decline.';

  @override
  String get truthYourAnswer => 'Your answer';

  @override
  String get truthAnswerPrivacy =>
      'It only goes to the person who paid. Pokou republishes it nowhere.';

  @override
  String get truthWhatToSay => 'What you want to say';

  @override
  String get truthSendAnswer => 'Send my answer';

  @override
  String get truthAskedAnon => 'Asked anonymously';

  @override
  String get truthDecline => 'Decline';

  @override
  String get truthAnswer => 'Answer';

  @override
  String get truthDeclineFree =>
      'Declining costs you nothing. You\'re only paid for answering.';

  @override
  String get truthHistoryUnavailable => 'History unavailable';

  @override
  String get truthNothingAsked => 'You haven\'t asked anything yet';

  @override
  String get truthNothingAskedBody =>
      'Ask someone a question: they\'ll see the amount and the question, never your name.';

  @override
  String get truthAnswered => 'Answered';

  @override
  String get truthDeclined => 'Declined';

  @override
  String get truthPending => 'Pending';

  @override
  String truthToSomeone(String name) {
    return 'To $name';
  }

  @override
  String get truthSomeone => 'someone';

  @override
  String get truthPreferredNot => 'They chose not to answer.';

  @override
  String get truthAwaitingAnswer => 'Waiting for an answer.';

  @override
  String get truthToWhom => 'To whom?';

  @override
  String truthQuestionTo(String name) {
    return 'A question for $name';
  }

  @override
  String get truthAnonTitle => 'Your name isn\'t shown';

  @override
  String get truthAnonBody =>
      'They see the amount and the question, never who sent them.';

  @override
  String get truthFreeTitle => 'They stay free to decline';

  @override
  String get truthFreeBody =>
      'Declining earns them nothing: they\'re only paid for answering.';

  @override
  String get truthPrivateTitle => 'The answer goes only to you';

  @override
  String get truthPrivateBody =>
      'Pokou republishes it nowhere, and it expires after seven days without an answer.';

  @override
  String get truthYourQuestion => 'Your question';

  @override
  String get truthQuestionHint => 'What you\'d really like to know';

  @override
  String get truthHowMuch => 'How much you\'re offering';

  @override
  String truthAskForAmount(int amount) {
    return 'Ask the question — $amount FCFA';
  }

  @override
  String get truthWriteFirst => 'Write your question first.';

  @override
  String get truthPaymentPending =>
      'Your question goes out as soon as the payment is confirmed.';

  @override
  String get hypeFinished => 'Finished';

  @override
  String get hypeSubtitle => 'One goal, the whole room';

  @override
  String get hypeLaunch => 'Launch a goal';

  @override
  String get hypeOngoing => 'Live';

  @override
  String get hypeMine => 'Mine';

  @override
  String get hypeNoneTitle => 'No goal running';

  @override
  String get hypeNoneBody =>
      'When a creator launches a goal, it shows here until the bar is hit.';

  @override
  String get hypeMineEmpty => 'Nothing yet';

  @override
  String get hypeMineEmptyBody =>
      'Your goals and the ones you backed will show up here.';

  @override
  String get hypeUnavailable => 'Goals unavailable';

  @override
  String get hypeCreator => 'Creator';

  @override
  String get hypeTierReached => 'Goal reached';

  @override
  String get hypeGoal => 'Goal';

  @override
  String get hypeNotFound => 'Goal not found';

  @override
  String get hypeMaybeRemoved => 'It may have been taken down.';

  @override
  String get hypeUnlocked => 'The bar is hit. The promise is unlocked.';

  @override
  String get hypeContribute => 'Move the bar';

  @override
  String get hypePushers => 'Who\'s pushing';

  @override
  String get hypeBeFirst => 'Nobody yet. Be the first.';

  @override
  String get hypeContributor => 'Contributor';

  @override
  String commonDueToYou(int amount) {
    return 'Owed to you: $amount FCFA';
  }

  @override
  String get commonManualPayout =>
      'Payouts are made by the Pokou team, on request.';

  @override
  String get hypeStepTogetherTitle => 'Everyone pushes together';

  @override
  String get hypeStepTogetherBody =>
      'Every contribution raises the bar, and everyone sees it hit at the same time.';

  @override
  String get hypeStepPromiseTitle => 'What you promise';

  @override
  String get hypeStepPromiseBody =>
      'Visible before anyone pays. It\'s your commitment if the goal is met.';

  @override
  String get hypeStepOneTitle => 'One goal at a time';

  @override
  String get hypeStepOneBody =>
      'Two goals at once would put your backers in competition with themselves.';

  @override
  String get commonTitle => 'Title';

  @override
  String get hypeTitleExample => 'e.g. 100,000 and I sing';

  @override
  String get hypePromiseLabel => 'What you unlock if the goal is met';

  @override
  String get hypePromiseHint =>
      'Be specific: this is what your backers are buying.';

  @override
  String get hypeGoalAmount => 'Goal in FCFA';

  @override
  String get commonDuration => 'Duration';

  @override
  String get hypeLaunchAction => 'Launch';

  @override
  String get hypeFieldsNeeded => 'Title, promise and goal are required.';

  @override
  String get hypeAlreadyRunning => 'You already have a goal running.';

  @override
  String get hypeContributeNote =>
      'Your contribution moves the bar and unlocks content. It is not refundable.';

  @override
  String get commonAmount => 'Amount';

  @override
  String hypeJoinForAmount(int amount) {
    return 'Chip in — $amount FCFA';
  }

  @override
  String get hypePaymentPending =>
      'The bar moves as soon as the payment is confirmed.';

  @override
  String get ceremonyWedding => 'Wedding';

  @override
  String get ceremonyBaptism => 'Christening';

  @override
  String get ceremonyFuneral => 'Funeral';

  @override
  String get ceremonyOther => 'Other';

  @override
  String get ceremonyTitle => 'Pots';

  @override
  String get ceremonySubtitle => 'Contributions, without the chasing';

  @override
  String get ceremonyNew => 'New pot';

  @override
  String get ceremonyUnavailable => 'Pots unavailable';

  @override
  String get ceremonyNone => 'No pots';

  @override
  String get ceremonyNoneBody =>
      'Wedding, christening, funeral: create the pot, invite, and everyone gives what they can.';

  @override
  String ceremonyGoalHint(int amount) {
    return 'Indicative goal: $amount FCFA';
  }

  @override
  String get ceremonyOne => 'Pot';

  @override
  String get ceremonyNotFound => 'Pot not found';

  @override
  String get ceremonyMaybeClosed => 'It may have been closed.';

  @override
  String get ceremonyJoin => 'Chip in';

  @override
  String get ceremonyClose => 'Close the pot';

  @override
  String get ceremonyContributions => 'Contributions';

  @override
  String get ceremonyNobodyYet => 'Nobody has chipped in yet.';

  @override
  String get ceremonyAnonGift => 'Anonymous contribution';

  @override
  String get ceremonyContributor => 'Contributor';

  @override
  String get ceremonyCollected => 'collected';

  @override
  String get ceremonyYouOrganize => 'you\'re organizing';

  @override
  String get ceremonyNewSubtitle =>
      'You follow the contributions. Pokou never chases those who haven\'t given.';

  @override
  String get ceremonyOccasion => 'Occasion';

  @override
  String get ceremonyTitleExample => 'e.g. Kossi and Ama\'s wedding';

  @override
  String get ceremonyFewWords => 'A few words (optional)';

  @override
  String get ceremonyFewWordsHint =>
      'The date, the place, what the money is for.';

  @override
  String get ceremonyGoalOptional => 'Goal in FCFA (optional)';

  @override
  String get ceremonyGoalNote =>
      'Indicative: the pot keeps accepting beyond it.';

  @override
  String get ceremonyCreate => 'Create the pot';

  @override
  String get ceremonyNeedTitle => 'Give the pot a title.';

  @override
  String ceremonyJoinTo(String title) {
    return 'Chip in — $title';
  }

  @override
  String get ceremonyOtherAmount => 'Or another amount';

  @override
  String get ceremonyWordOptional => 'A word (optional)';

  @override
  String get ceremonyWordHint => 'What you want to tell them';

  @override
  String get ceremonyAnonToggle => 'Contribute anonymously';

  @override
  String get ceremonyAnonNote =>
      'Your name is hidden. The amount still counts in the total.';

  @override
  String ceremonyJoinAmount(int amount) {
    return 'Chip in — $amount FCFA';
  }

  @override
  String get ceremonyMinimum => 'The minimum is 100 FCFA.';

  @override
  String get ceremonyPaymentPending =>
      'Your contribution shows as soon as the payment is confirmed.';

  @override
  String get vipSubtitle => 'Your subscribers, your space';

  @override
  String get vipDiscover => 'Discover';

  @override
  String get vipMySubs => 'My subscriptions';

  @override
  String get vipMyRoom => 'My room';

  @override
  String get vipNoRoomOpen => 'No rooms open';

  @override
  String get vipNoRoomOpenBody => 'Rooms that creators open will show up here.';

  @override
  String get vipNoSub => 'No subscriptions';

  @override
  String get vipNoSubBody =>
      'Subscribe to a room to find everything its creator posts here.';

  @override
  String get vipUnavailable => 'Rooms unavailable';

  @override
  String get vipCreator => 'Creator';

  @override
  String vipUntil(String date) {
    return 'Until $date';
  }

  @override
  String get vipPaymentPending =>
      'The room opens as soon as the payment is confirmed.';

  @override
  String get vipRoom => 'Room';

  @override
  String get vipNotFound => 'Room not found';

  @override
  String get vipMaybeClosed => 'It may have been closed.';

  @override
  String get vipStepAllTitle => 'Everything posted here';

  @override
  String get vipStepAllBody =>
      'You immediately see what\'s already posted, and everything that follows.';

  @override
  String get vipStepDaysTitle => 'Thirty days';

  @override
  String get vipStepDaysBody =>
      'Access stops on its own at the end. Nothing continues unless you decide it.';

  @override
  String get vipStepNoRenewTitle => 'No automatic renewal';

  @override
  String get vipStepNoRenewBody =>
      'Pokou doesn\'t keep your payment method. To continue, you pay again, once.';

  @override
  String vipSubscribeFor(int amount) {
    return 'Subscribe — $amount FCFA';
  }

  @override
  String get vipLockedTitle => 'Subscribers-only content';

  @override
  String get vipLockedBody =>
      'The rest of the room opens as soon as the payment is confirmed.';

  @override
  String get vipNothingYet => 'Nothing yet';

  @override
  String get vipNothingYetBody => 'This room has no posts yet.';

  @override
  String get vipPosts => 'Posts';

  @override
  String get vipRoomUnavailable => 'Room unavailable';

  @override
  String get vipOpenYourRoom => 'Open your room';

  @override
  String get vipOpenYourRoomBody =>
      'Subscribers pay once for thirty days and see everything you post here. You set the price.';

  @override
  String get vipOpenAction => 'Open my room';

  @override
  String get vipPublish => 'Post';

  @override
  String get vipSeeMyRoom => 'See my room';

  @override
  String get vipOpen => 'Open';

  @override
  String get vipClosed => 'Closed';

  @override
  String get vipEarnings => 'Your earnings';

  @override
  String vipCollected(int amount) {
    return '$amount FCFA collected';
  }

  @override
  String get vipDueNote =>
      'The amount owed to you. Payouts are made by the Pokou team, on request.';

  @override
  String get vipEditRoom => 'Edit my room';

  @override
  String get vipPriceNote =>
      'A new price only applies to future subscriptions: everyone paid theirs upfront.';

  @override
  String get vipRoomName => 'Room name';

  @override
  String get vipRoomNameHint => 'e.g. Behind the scenes';

  @override
  String get vipPitchLabel => 'What subscribers will find there';

  @override
  String get vipPitchNote =>
      'Shown before paying — it\'s what makes people subscribe.';

  @override
  String get vipPitchHint => 'Photos, announcements, voice notes…';

  @override
  String get vipMonthlyPrice => 'Monthly price in FCFA';

  @override
  String get vipAcceptNew => 'Accept new subscribers';

  @override
  String get vipAcceptNewNote =>
      'Current subscribers keep their access until it ends.';

  @override
  String get vipFieldsNeeded => 'Name, description and price are required.';

  @override
  String get vipPublishTitle => 'Post in my room';

  @override
  String get vipPublishNote => 'Visible only to your current subscribers.';

  @override
  String get vipYourMessage => 'Your message';

  @override
  String get vipShareHint => 'What you want to share';

  @override
  String vipEarningsSummary(int count, int amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions',
      one: '1 subscription',
    );
    return '$_temp0 • $amount FCFA collected';
  }

  @override
  String get datesUnavailable => 'Dates unavailable';

  @override
  String get datesNone => 'No dates planned';

  @override
  String get datesNoneBody =>
      'Once past the room, suggest a place. You pay upfront, and the money is only released once you both confirm.';

  @override
  String get datesNotNow => 'That\'s not possible right now.';

  @override
  String get datesCancelTitle => 'Cancel the date?';

  @override
  String get datesCancelFree =>
      'You\'re more than 24 h out: you\'ll be fully refunded.';

  @override
  String get datesCancelLate =>
      'Less than 24 h left. The venue has already booked; your payment stays with them.';

  @override
  String get datesKeep => 'Keep it';

  @override
  String get datesCancelAction => 'Cancel the date';

  @override
  String get datesAwaitingPayment => 'Awaiting payment';

  @override
  String get datesPaidToConfirm => 'Paid — to confirm';

  @override
  String get datesDone => 'Done';

  @override
  String get datesRefunded => 'Refunded';

  @override
  String get datesNoShow => 'No-show reported';

  @override
  String get datesCancelled => 'Cancelled';

  @override
  String get datesOne => 'Date';

  @override
  String datesWithPeer(String venue, String name) {
    return '$venue • with $name';
  }

  @override
  String get datesYourMatch => 'your match';

  @override
  String get datesWentWell => 'It went well';

  @override
  String get datesYouConfirmed =>
      'You\'ve confirmed. We\'re waiting on the other side.';

  @override
  String get datesNoShowAction => 'They didn\'t show';

  @override
  String get datesVoucher => 'Your voucher, to give on site';

  @override
  String get datesPickBoth => 'Pick a package and a time.';

  @override
  String get datesVoucherPending =>
      'Your voucher is issued as soon as the payment is confirmed.';

  @override
  String get datesBookingFailed => 'The booking didn\'t go through.';

  @override
  String get datesWhereTo => 'Where are you going?';

  @override
  String get datesStepPayTitle => 'You pay upfront, nothing is released';

  @override
  String get datesStepPayBody =>
      'The money is held. It only reaches the venue if you both confirm.';

  @override
  String get datesStepCancelTitle => 'Free cancellation over 24 h ahead';

  @override
  String get datesStepCancelBody =>
      'Full refund. Under that, the venue has already booked and keeps your payment.';

  @override
  String get datesStepNoShowTitle => 'If they don\'t show';

  @override
  String get datesStepNoShowBody =>
      'Half comes back to you. The app takes nothing on a missed date.';

  @override
  String get datesThePackage => 'The package';

  @override
  String get datesPacksUnavailable => 'Packages aren\'t available right now.';

  @override
  String get datesNoPackNearby => 'No packages are offered near you yet.';

  @override
  String get datesWhen => 'When?';

  @override
  String get datesPickWhen => 'Pick the date and time';

  @override
  String get datesBook => 'Book';

  @override
  String datesBookAmount(int amount) {
    return 'Book — $amount FCFA';
  }

  @override
  String get roomNeedMic =>
      'Without a mic there are only stickers — the room is voice.';

  @override
  String get roomVoiceFailed => 'The voice note didn\'t send.';

  @override
  String get roomBothYes => 'You\'re on. You can suggest a date now.';

  @override
  String get roomWaitingOther =>
      'Noted. We\'re waiting on their answer before the countdown ends.';

  @override
  String get roomExtendPending =>
      'Ten more minutes as soon as the payment is confirmed.';

  @override
  String get roomTitle => 'Entry room';

  @override
  String get roomNotFound => 'Room not found';

  @override
  String get roomMaybeClosed => 'It may have closed.';

  @override
  String get roomVoiceOnly => 'Voice and stickers only';

  @override
  String get roomTimeUp => 'Time\'s up.';

  @override
  String roomTimeLeft(String clock) {
    return '$clock left to decide together';
  }

  @override
  String get roomSaySomething => 'Say something';

  @override
  String get roomNoTextBody =>
      'No text here: a voice note or a sticker. That\'s what tells a real person from a copied message.';

  @override
  String get roomVoice => 'Voice';

  @override
  String get roomWaitingReply => 'Waiting for their answer';

  @override
  String roomExtendFor(int amount) {
    return 'Ten more minutes — $amount FCFA';
  }

  @override
  String get roomBothSaidYes => 'You both said yes.';

  @override
  String get roomSaved => 'The match is saved. You can suggest a date.';

  @override
  String get roomClosedNoAnswer => 'The room closed with no answer.';

  @override
  String get roomSuggestDate => 'Suggest a date';

  @override
  String get safetyCheckin => 'All good?';

  @override
  String get safetyCheckinBody =>
      'Without a reply within five minutes, your safety circle is alerted with your location.';

  @override
  String get safetyAllGood => 'Yes, all good';

  @override
  String get safetyCircleAlerted => 'Your circle has been alerted.';

  @override
  String get safetyNoCircle =>
      'Alert recorded. Add people close to you so they\'re alerted next time.';

  @override
  String get safetyWhoToAlert => 'Who to alert?';

  @override
  String get safetyWhoToAlertBody =>
      'These people get your live location if you raise an alert.';

  @override
  String get safetyTitle => 'Safety';

  @override
  String get safetySubtitle => 'Who gets told if things go wrong';

  @override
  String get safetyQuietAlert => 'Quiet alert';

  @override
  String get safetyQuietAlertBody =>
      'Alerts your circle with your location. Nothing shows on your phone screen.';

  @override
  String get safetyTrigger => 'Raise an alert';

  @override
  String get safetyMyCircle => 'My circle';

  @override
  String get safetyThreeEnough => 'Three people is enough';

  @override
  String get safetyNobodyYet =>
      'Nobody yet. Without a circle, an alert is recorded but tells no one.';

  @override
  String get safetyAddSomeone => 'Add someone';

  @override
  String get wingmanTitle => 'Friends\' take';

  @override
  String get wingmanAnon => 'Your take stays anonymous';

  @override
  String get wingmanUnavailable => 'Requests unavailable';

  @override
  String get wingmanNothing => 'Nothing to weigh in on';

  @override
  String get wingmanNothingBody =>
      'When a friend asks what you think of a profile, it shows up here.';

  @override
  String wingmanAsksYou(String name) {
    return '$name is asking what you think';
  }

  @override
  String get wingmanMeh => 'Meh';

  @override
  String get wingmanWorthIt => 'Worth it';

  @override
  String get wingmanPrivacy =>
      'Your friend only sees whether the group approves, never who said what.';

  @override
  String get marketLocationOff => 'Location services are off.';

  @override
  String get marketGpsDenied => 'Location permission denied.';

  @override
  String get marketGpsApplied => 'GPS location applied.';

  @override
  String get marketGpsFailed => 'Couldn\'t get your location.';

  @override
  String get marketYourArea => 'Your area';

  @override
  String get marketCityOrArea => 'City and area';

  @override
  String get marketLocationCleared => 'Location cleared.';

  @override
  String get marketUseGps => 'Use my GPS location';

  @override
  String get marketApply => 'Apply';

  @override
  String marketRemoveProduct(String name) {
    return 'Remove \"$name\"?';
  }

  @override
  String get marketProductUnavailable => 'Product unavailable.';

  @override
  String get marketPaymentUnavailable => 'Mobile Money payment unavailable.';

  @override
  String get marketCheckoutUnreachable => 'Mobile Money checkout unreachable.';

  @override
  String get marketBoostDone => 'Payment done: listing sponsored.';

  @override
  String get marketBoostPending => 'Boost payment pending.';

  @override
  String get marketBoostFailed => 'Can\'t boost right now.';

  @override
  String get marketTitle => 'Assimé';

  @override
  String get marketBecomeSeller => 'Become a verified seller';

  @override
  String get marketAddProduct => 'Add a product';

  @override
  String get marketAroundYou => 'Around you';

  @override
  String get marketMyGps => 'My GPS location';

  @override
  String get marketPickArea => 'Pick an area';

  @override
  String get marketNearYou => 'Products near you';

  @override
  String get marketUnavailable => 'Marketplace unavailable.';

  @override
  String get marketNoProduct => 'No products posted.';

  @override
  String get marketNoMatch => 'No product matches this search.';

  @override
  String get marketAllShown => 'All products are shown';

  @override
  String get marketMyCatalogue => 'My catalogue';

  @override
  String get marketSwipeCatalogue => 'Swipe to see all your products';

  @override
  String get marketCatalogueEmpty => 'Your catalogue is empty';

  @override
  String get marketCatalogueEmptyBody =>
      'Add your first product to start selling!';

  @override
  String get marketBoosted => 'Sponsored';

  @override
  String get vitrineSeeProduct => 'View item';

  @override
  String get vitrineHint => 'Tap the item to open it';

  @override
  String get vitrineTitle => 'Marketplace showcase';

  @override
  String get versesMorning => 'Morning verse';

  @override
  String get versesEvening => 'Evening verse';

  @override
  String get versesChannel => 'Daily verses';

  @override
  String get versesChannelDesc => 'Your 6 am and 6 pm verses';

  @override
  String get versesSchedule => 'Every day at 6 am and 6 pm';

  @override
  String get versesThisMorning => 'This morning';

  @override
  String get versesThisEvening => 'This evening';

  @override
  String get versesBibleTitle => 'Bible verses';

  @override
  String get versesQuranTitle => 'Quran verses';

  @override
  String get versesShare => 'Share';

  @override
  String get versesOfflineHint =>
      'Verses arrive even offline: they are already on your phone.';

  @override
  String get marketBoosted48h => 'Sponsored';

  @override
  String get marketBoost => 'Feature';

  @override
  String get marketRemove => 'Remove';

  @override
  String get marketGpsSaved => 'GPS location saved.';

  @override
  String get marketNameAndPrice => 'A name and a price are required.';

  @override
  String get marketEditProduct => 'Edit product';

  @override
  String get marketMainPhoto => 'Main photo';

  @override
  String get marketOtherPhotos => 'Other photos';

  @override
  String get marketDescription => 'Description';

  @override
  String get marketCurrency => 'Currency';

  @override
  String get marketCategory => 'Category';

  @override
  String get marketPickCategory => 'Pick a category';

  @override
  String get marketSpecifyCategory => 'Specify the category';

  @override
  String marketGpsCoords(String lat, String lon) {
    return 'GPS coordinates: $lat, $lon';
  }

  @override
  String get marketUploadingPhoto => 'Uploading the photo…';

  @override
  String get marketAddPhoto => 'Add a photo';

  @override
  String get groupEditName => 'Edit name';

  @override
  String get groupAddPhoto => 'Add a photo';

  @override
  String get groupChangePhoto => 'Change photo';

  @override
  String get groupRemovePhoto => 'Remove photo';

  @override
  String get groupNoLink => 'No active link';

  @override
  String get groupLinkActive => 'A link is active';

  @override
  String get groupCreator => 'Creator';

  @override
  String get groupAdmin => 'Admin';

  @override
  String get groupAddMembers => 'Add participants';

  @override
  String get groupLeave => 'Leave the group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupCopyLink => 'Copy the link';

  @override
  String get groupRegenLink => 'Regenerate the link';

  @override
  String get groupDisableLink => 'Disable the link';

  @override
  String get groupLinkCopied => 'Link copied.';

  @override
  String get groupLinkDisabled => 'Link disabled.';

  @override
  String get groupAllContactsIn =>
      'All your Pokou contacts are already in this group.';

  @override
  String get groupAddToGroup => 'Add to the group';

  @override
  String groupMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants added.',
      one: 'Participant added.',
    );
    return '$_temp0';
  }

  @override
  String get groupLeaveTitle => 'Leave the group?';

  @override
  String groupLeaveBody(String name) {
    return 'You\'ll stop receiving messages from \"$name\".';
  }

  @override
  String get groupLeaveAction => 'Leave';

  @override
  String get groupNoMessage => 'No messages. Start the conversation.';

  @override
  String get groupNotEncryptedNotice =>
      'End-to-end encrypted: only members can read these messages.';

  @override
  String get botLabel => 'Bot';

  @override
  String get botConversationNotice =>
      'You are writing to a business\'s bot. These messages are not end-to-end encrypted: the business reads what you send.';

  @override
  String get groupAdminsOnly => 'Admins only';

  @override
  String get groupCallOngoing => 'Call in progress';

  @override
  String get communityEdit => 'Edit the community';

  @override
  String get commonName => 'Name';

  @override
  String get communityEditFailed => 'Couldn\'t save the change.';

  @override
  String get communityAddGroup => 'Add a group';

  @override
  String get communityNewGroup => 'Create a new group';

  @override
  String get communityAttachGroup => 'Attach an existing group';

  @override
  String communityDetachTitle(String name) {
    return 'Detach \"$name\"?';
  }

  @override
  String get communityDetachBody =>
      'The group leaves the community but keeps existing: its chat and members don\'t change.';

  @override
  String get communityDetach => 'Detach';

  @override
  String get communityDetachFailed => 'Couldn\'t detach this group.';

  @override
  String get communityLinkNote =>
      'Anyone with this link joins the community and its Announcements group — not the other groups, which are joined one by one.';

  @override
  String get communityActionFailed => 'That didn\'t work.';

  @override
  String get communityLeaveTitle => 'Leave the community?';

  @override
  String get communityLeaveBody =>
      'You\'ll stop getting its announcements. The groups you joined stay yours.';

  @override
  String get communityLeave => 'Leave the community';

  @override
  String get communityLeaveFailed => 'Couldn\'t leave the community.';

  @override
  String get communityOne => 'Community';

  @override
  String get communityUnavailable =>
      'Community unavailable — check your connection.';

  @override
  String get communityGroups => 'GROUPS';

  @override
  String get communityAnnouncements => 'Announcements · admins only';

  @override
  String get communityOnlyAdminGroups =>
      'Only groups you administer can join a community.';

  @override
  String get channelPostsUnavailable => 'Posts unavailable.';

  @override
  String get channelReactionFailed => 'Reaction not saved.';

  @override
  String get channelPostFailed => 'Couldn\'t post.';

  @override
  String get channelEditPost => 'Edit the post';

  @override
  String get channelEditTooOld => 'Can\'t edit — the post is too old.';

  @override
  String get channelDeletePost => 'Delete the post?';

  @override
  String get channelDeleteBody => 'It disappears for every subscriber.';

  @override
  String get channelDeleteFailed => 'Couldn\'t delete.';

  @override
  String get channelLinkCopied => 'Channel link copied.';

  @override
  String get channelLinkUnavailable => 'Link unavailable.';

  @override
  String get channelEdit => 'Edit the channel';

  @override
  String get channelPublish => 'Post';

  @override
  String channelFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscribers',
      one: '1 subscriber',
    );
    return '$_temp0';
  }

  @override
  String get channelFollowing => 'Following';

  @override
  String get channelEdited => '· edited';

  @override
  String get channelImageFailed => 'Image not sent.';

  @override
  String get channelNewPost => 'New post';

  @override
  String get channelPostHint => 'Your announcement…';

  @override
  String pollAnswerN(int index) {
    return 'Answer $index';
  }

  @override
  String get pollAddAnswer => 'Add an answer';

  @override
  String get pollMultiple => 'Multiple answers allowed';

  @override
  String get pollAddImage => 'Add an image';

  @override
  String get pollRemove => 'Remove the poll';

  @override
  String get pollOne => 'Poll';

  @override
  String get pollQuestion => 'Your question';

  @override
  String get commonSending => 'Sending…';

  @override
  String channelPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String get lockChooseCode => 'Choose a code';

  @override
  String get lockCodeRule =>
      '4 to 8 digits. The code never leaves this device and cannot be recovered — if you forget it, the lock is released by verifying your phone number.';

  @override
  String get lockCode => 'Code';

  @override
  String get lockConfirmCode => 'Confirm the code';

  @override
  String get lockTooShort => 'The code must be at least 4 digits.';

  @override
  String get lockMismatch => 'The two codes do not match.';

  @override
  String get lockCurrentCode => 'Current code';

  @override
  String get lockValidate => 'Validate';

  @override
  String get lockEnabledToast => 'Lock enabled.';

  @override
  String get lockSaveFailed => 'Could not save the code.';

  @override
  String get lockEnterCurrent => 'Enter the current code';

  @override
  String get lockWrongCode => 'Wrong code.';

  @override
  String get lockCodeChanged => 'Code changed.';

  @override
  String get lockEnterToDisable => 'Enter the code to disable';

  @override
  String get lockDisabledToast => 'Lock disabled.';

  @override
  String get lockTitle => 'App lock';

  @override
  String get lockByCode => 'Lock with a code';

  @override
  String get lockOn => 'On';

  @override
  String get lockOff => 'Off';

  @override
  String get lockChangeCode => 'Change the code';

  @override
  String get lockFootnoteKeystore =>
      'Pokou asks for the code every time it returns to the foreground. The code is kept in the system\'s secure store (Keystore), not sent to the server: it protects the screen, not the data on the device itself.';

  @override
  String get lockFootnoteBiometrics =>
      'Fingerprint unlock is not offered yet — it requires an Android configuration change (FlutterFragmentActivity and the USE_BIOMETRIC permission).';

  @override
  String get lockScreenTitle => 'Pokou is locked';

  @override
  String get lockEnterToContinue => 'Enter your code to continue.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockForgotQuestion => 'Forgot your code?';

  @override
  String get lockSendFailed => 'Could not send — check your connection.';

  @override
  String get lockRemovedToast =>
      'Lock removed. You can choose a new code in Profile.';

  @override
  String get lockVerifyFailed => 'Verification failed — check your connection.';

  @override
  String get lockLogoutQuestion => 'Log out?';

  @override
  String get lockLogoutBody =>
      'Use this if you no longer have access to this number. Your conversations stay on the server, but you will need a reachable number to sign back in.';

  @override
  String get lockLogout => 'Log out';

  @override
  String get lockForgotTitle => 'Forgotten code';

  @override
  String get lockNoPhoneOnDevice =>
      'Could not find your number on this device.';

  @override
  String lockEnterSentCode(String phone) {
    return 'Enter the code sent to $phone by SMS and WhatsApp.';
  }

  @override
  String lockForgotExplain(String phone) {
    return 'The lock code is stored only on this device and cannot be recovered. To remove the lock, verify your number $phone.';
  }

  @override
  String get lockLift => 'Remove the lock';

  @override
  String get lockSendCode => 'Send a code';

  @override
  String get lockResendCode => 'Resend the code';

  @override
  String get lockNoAccessToNumber => 'I no longer have access to this number';

  @override
  String get notifInApp => 'In the app';

  @override
  String get notifMessages => 'Messages';

  @override
  String get notifMessagesSub => 'One-to-one chats';

  @override
  String get notifMessagesSemantic => 'Message notifications';

  @override
  String get notifGroups => 'Groups';

  @override
  String get notifGroupsSub => 'Group chats';

  @override
  String get notifGroupsSemantic => 'Group notifications';

  @override
  String get notifCallsSub => 'Incoming audio and video calls';

  @override
  String get notifCallsSemantic => 'Call notifications';

  @override
  String get notifSound => 'Sound and vibration';

  @override
  String get notifSoundSemantic => 'Notification sound';

  @override
  String get notifCallsFootnote =>
      'Turning calls off here only removes the banner shown while Pokou is open: an incoming call still rings full screen, otherwise you would miss calls without knowing.';

  @override
  String get notifSystem => 'System';

  @override
  String get notifWebEnable => 'Enable browser notifications';

  @override
  String get notifWebEnableSub =>
      'Allow this browser to receive Pokou notifications.';

  @override
  String get notifWebEnabled => 'Browser notifications enabled.';

  @override
  String get notifWebEnableFailed =>
      'Could not enable notifications. Check this site\'s browser settings.';

  @override
  String get notifAndroidSettings => 'Android settings';

  @override
  String get notifAndroidSettingsSub =>
      'Permission, channels, per-channel sound';

  @override
  String get notifSystemFootnote =>
      'When Pokou is closed, Android displays incoming notifications itself, without running the app: only the system settings above can change them.';

  @override
  String get devicesRemoveTitle => 'Remove this device?';

  @override
  String get devicesRemoveCurrentBody =>
      'This device will stop receiving notifications until you open Pokou again.';

  @override
  String get devicesRemoveOtherBody =>
      'This device will stop receiving notifications. It stays signed in until it next logs out.';

  @override
  String get devicesRemove => 'Remove';

  @override
  String get devicesRemoveFailed => 'Could not remove this device.';

  @override
  String get devicesTitle => 'Connected devices';

  @override
  String get devicesUnavailable =>
      'List unavailable — check your connection, then pull to refresh.';

  @override
  String get devicesEmpty =>
      'No device registered for notifications. They turn on the first time Pokou is opened on a device.';

  @override
  String get devicesThisDevice => ' · this device';

  @override
  String devicesLastSeen(String date, String hint) {
    return 'Active $date · …$hint';
  }

  @override
  String get devicesFootnote =>
      'A device shows up here as soon as it registers for push notifications. Removing it cuts its notifications; it does not end its session, which expires on its own.';

  @override
  String get devicesBrowser => 'Browser';

  @override
  String devicesTodayAt(String time) {
    return 'today at $time';
  }

  @override
  String get storageNoCachedMedia => 'No cached media.';

  @override
  String storageFilesCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files removed from the cache.',
      one: '1 file removed from the cache.',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Storage and data';

  @override
  String get storageCachedMedia => 'Cached media';

  @override
  String get storageMediaLabel => 'Photos, videos and voice notes';

  @override
  String get storageComputing => 'Calculating…';

  @override
  String get storageNoFile => 'No file';

  @override
  String storageFileCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 · $size';
  }

  @override
  String get storageClearCache => 'Clear the cache';

  @override
  String get storageClearFootnote =>
      'Cleared files are downloaded again on demand when you reopen the chat: nothing is lost, only freed.';

  @override
  String get storageMobileData => 'On mobile data';

  @override
  String get storageDataSaver => 'Data saver';

  @override
  String get storageDataSaverSub => 'Do not download media automatically';

  @override
  String get storageDataSaverFootnote =>
      'When on, incoming photos and videos wait for you to tap them before downloading, and the photos you send are compressed more.';

  @override
  String get profileAvatarFailed => 'Could not update the profile picture.';

  @override
  String get profileChooseMonitor => 'Choose a monitor';

  @override
  String get profileBabaMessaging => 'Baba messaging';

  @override
  String profileMonitorAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alerts from $count monitors',
      one: 'Alerts from 1 monitor',
    );
    return '$_temp0';
  }

  @override
  String get profileBabaAssistant => 'Baba assistant';

  @override
  String get profileShieldModeBody =>
      'Holds calls and dims non-priority chats while you are focused. Contacts tagged Business, Client, Supplier or Boss always get through.';

  @override
  String get contactConnectFailed => 'Connection failed.';

  @override
  String get contactCallFailed => 'Cannot call right now.';

  @override
  String contactBlockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get contactBlockBody =>
      'This person will no longer be able to message or call you. They will not be told.';

  @override
  String get contactActionFailed => 'Action not possible right now.';

  @override
  String get contactSavedToast => 'Contact saved';

  @override
  String get contactCall => 'Call';

  @override
  String get contactSharedTitle => 'Shared items';

  @override
  String get contactSharedMedia => 'Media';

  @override
  String get contactSharedDocuments => 'Documents';

  @override
  String get contactSharedLinks => 'Links';

  @override
  String get contactNoMedia => 'No photos or videos shared.';

  @override
  String get contactNoDocuments => 'No documents shared.';

  @override
  String get contactNoLinks => 'No links shared.';

  @override
  String contactCommonGroups(int count) {
    return 'Groups in common ($count)';
  }

  @override
  String contactCatalog(int count) {
    return 'Catalogue ($count)';
  }

  @override
  String contactUnblockName(String name) {
    return 'Unblock $name';
  }

  @override
  String contactBlockName(String name) {
    return 'Block $name';
  }

  @override
  String get contactUnblockHint =>
      'This person can message and call you again.';

  @override
  String get contactBlockHint =>
      'They will no longer be able to message or call you, and will not be told.';

  @override
  String get adNeedTitleBody => 'Give your ad a title and a message.';

  @override
  String get adSendFailed => 'The request could not be sent.';

  @override
  String get adCreateTitle => 'Create an ad';

  @override
  String get adWhoSeesTitle => 'Who will see it';

  @override
  String get adWhoSeesBody =>
      'All Pokou Messenger users in the Market tab, or between two statuses — your choice.';

  @override
  String get adReviewTitle => 'A review before it runs';

  @override
  String get adReviewBody =>
      'Our team reads every campaign before it goes out. Allow a few hours.';

  @override
  String get adCountdownTitle => 'The countdown starts at approval';

  @override
  String get adCountdownBody =>
      'Your run days start once the campaign is accepted, not at payment.';

  @override
  String get adRefundTitle => 'Rejected? You get a refund';

  @override
  String get adRefundBody =>
      'If the campaign cannot run, contact us: the amount is returned to you.';

  @override
  String get adTitleHint => 'E.g. CIMTOGO cement on sale';

  @override
  String get adBodyHint => 'What you are offering, and how to reach you.';

  @override
  String get adMediaLabel => 'Photo or video (optional)';

  @override
  String get adMediaHint =>
      'A video of 30 seconds at most. Without an image, only the text runs.';

  @override
  String get adVideo30s => 'Video 30 s';

  @override
  String get adPlacement => 'Placement';

  @override
  String get adPlacementMarket => 'Market tab';

  @override
  String get adPlacementStatus => 'Between statuses';

  @override
  String get adDuration => 'Duration';

  @override
  String get adOneWeek => '1 week';

  @override
  String get adTwoWeeks => '2 weeks';

  @override
  String get adOneMonth => '1 month';

  @override
  String get adPayCaption => 'Mobile Money payment';

  @override
  String get adPayAction => 'Pay and send';

  @override
  String productInterestedMessage(String name, String price, String currency) {
    return 'Hello, I am interested in your $name at $price $currency. Is it available?';
  }

  @override
  String get productWriteFailed => 'Cannot message the seller right now.';

  @override
  String get productCallFirstWrite => 'Cannot call — message them first.';

  @override
  String get productRateSeller => 'Rate this seller';

  @override
  String get productEditReview => 'Edit my review';

  @override
  String get productReviewScope =>
      'The review is about the SELLER, not a product: what counts is trust in the person, and it stays even if the item leaves the catalogue.';

  @override
  String get productReviewHint => 'Your comment (optional)';

  @override
  String get productDeleteReview => 'Delete my review';

  @override
  String get productReviewFailed => 'Review not saved.';

  @override
  String get productTitle => 'Product';

  @override
  String get productOpening => 'Opening…';

  @override
  String get productDiscuss => 'Chat';

  @override
  String get productCallAction => 'Call';

  @override
  String get productReviews => 'Reviews';

  @override
  String get productNoReviewYet => 'No reviews yet';

  @override
  String productRatingSummary(String rating, int reviews) {
    String _temp0 = intl.Intl.pluralLogic(
      reviews,
      locale: localeName,
      other: '$reviews reviews',
      one: '1 review',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String productCountSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return ' · $_temp0';
  }

  @override
  String get productCertified => 'Account verified by the Pokou team.';

  @override
  String get productReviewMine => 'You';

  @override
  String get verifNeedDocument => 'Add a photo of your ID document.';

  @override
  String get verifTitle => 'Become a verified seller';

  @override
  String get verifBadgeTitle => 'A blue badge on your listings';

  @override
  String get verifBadgeBody =>
      'Buyers can see that your identity was verified by our team.';

  @override
  String get verifWhyTitle => 'Why it changes everything';

  @override
  String get verifWhyBody =>
      'A buyer sends Mobile Money more readily to someone whose identity is confirmed than to a stranger.';

  @override
  String get verifNeedTitle => 'What you need to provide';

  @override
  String get verifNeedBody =>
      'A sharp photo of your ID card, passport or licence. The name must be readable.';

  @override
  String get verifUseTitle => 'What we do with it';

  @override
  String get verifUseBody =>
      'It is read by our team for verification only, never appears on your profile, and is shown to no buyer.';

  @override
  String get verifOneYearTitle => 'Valid for one year';

  @override
  String get verifOneYearBody =>
      'The badge lasts twelve months. Allow a few days for the review.';

  @override
  String get verifDocumentLabel => 'Your ID document';

  @override
  String get verifPayCaption => 'Mobile Money payment · 1 year';

  @override
  String get verifChoosePhoto => 'Choose a photo';

  @override
  String get verifChange => 'Change';

  @override
  String get marketRemoveBody =>
      'The listing disappears from the market. Your chats about it stay readable, and buyers who already received it keep their history.';

  @override
  String get marketRemoveFailed => 'The listing could not be removed.';

  @override
  String get marketImageFailed => 'Image not sent — try again.';

  @override
  String get marketMainPhotoHint =>
      'This is the one that illustrates the product in the list.';

  @override
  String get marketName => 'Name';

  @override
  String get marketPrice => 'Price';

  @override
  String get marketNoReviewYet => 'no reviews yet';

  @override
  String get marketSearchHint => 'Search for an ad';

  @override
  String get callLogEmpty => 'No calls yet.';

  @override
  String get callLogUnknownUser => 'User';

  @override
  String get callStatusMissed => 'Missed';

  @override
  String get callStatusNoAnswer => 'No answer';

  @override
  String get callStatusDeclined => 'Declined';

  @override
  String get callStatusReceived => 'Received';

  @override
  String get callStatusEnded => 'Ended';

  @override
  String get callStatusOngoing => 'Ongoing';

  @override
  String get callStatusOutgoing => 'Called';

  @override
  String get callVideoTitle => 'Video call';

  @override
  String get callAudioTitle => 'Audio call';

  @override
  String callRedialQuestion(String name) {
    return 'Call $name back?';
  }

  @override
  String get callJoinFailed => 'Could not join the call.';

  @override
  String get callNobodyToAdd => 'Nobody else to add.';

  @override
  String get callAddToCall => 'Add to the call';

  @override
  String get callAdd => 'Add';

  @override
  String get callAddFailed => 'Could not add this participant.';

  @override
  String get callReactionFailed => 'Could not send this reaction.';

  @override
  String get callLeaveConfirmTitle => 'Leave the call?';

  @override
  String get callLeaveConfirmBody =>
      'Other participants may still be talking. You can return to the call banner instead of hanging up.';

  @override
  String get callYou => 'You';

  @override
  String get callContact => 'Contact';

  @override
  String get callConnecting => 'Connecting to the call…';

  @override
  String get callPreparing => 'The call is being set up';

  @override
  String get callWaiting => 'Waiting…';

  @override
  String get callJoinImpossible => 'Could not join the call.';

  @override
  String get callEncryptedJoinFailed =>
      'This encrypted call couldn\'t be opened on this phone. The caller has been told.';

  @override
  String get callIncoming => 'Incoming call';

  @override
  String callIncomingFrom(String name) {
    return '$name is calling you';
  }

  @override
  String get callIncomingGroup => 'Incoming group call';

  @override
  String get streakSubtitle => 'One missed day, a few minutes to catch it up';

  @override
  String get streakUnavailable => 'Streaks unavailable';

  @override
  String get streakCheckConnection => 'Check your connection and try again.';

  @override
  String get streakEmptyTitle => 'No streak yet';

  @override
  String get streakEmptyBody =>
      'Exchange a message every day with the same person: the streak starts at the first round trip.';

  @override
  String get streakToRescue => 'To rescue now';

  @override
  String get streakToRescueSub =>
      'Past the deadline, the streak restarts from zero';

  @override
  String get streakMine => 'My streaks';

  @override
  String get streakRunning => 'Running';

  @override
  String streakRecord(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Record: $_temp0';
  }

  @override
  String get streakLongest => 'Your longest streak';

  @override
  String get streakRestorePending =>
      'Your streak will restart as soon as the payment is confirmed.';

  @override
  String get streakDeadlinePassed => 'The deadline may have passed.';

  @override
  String streakBroken(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days-day streak broken',
      one: '1-day streak broken',
    );
    return '$_temp0';
  }

  @override
  String get streakExpired =>
      'The deadline has passed. The streak restarts from zero.';

  @override
  String streakCountdown(String time) {
    return '$time left to save it';
  }

  @override
  String streakRescueAction(int amount) {
    return 'Save the streak — $amount FCFA';
  }

  @override
  String get leagueSubtitle => 'Your league rises with what you receive';

  @override
  String get leagueUnavailable => 'Ranking unavailable';

  @override
  String get leagueRanking => 'Ranking';

  @override
  String get leagueProtectPending =>
      'Your protection becomes active as soon as the payment is confirmed.';

  @override
  String get leaguePaymentFailed => 'The payment could not be started.';

  @override
  String get leagueAtTop => 'You are at the top of the ranking.';

  @override
  String leaguePointsNeeded(int points, String label) {
    return '$points more points to reach $label.';
  }

  @override
  String get leagueProtected =>
      'Your points are protected. Nothing drops this week.';

  @override
  String get leagueDecayNow => 'Your points drop at the next pass.';

  @override
  String leagueDecayIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Your points drop in $days days without activity.',
      one: 'Your points drop in 1 day without activity.',
    );
    return '$_temp0';
  }

  @override
  String get leagueProtectAction => 'Protect my points — 500 FCFA';

  @override
  String get leagueNobodyRanked => 'Nobody is ranked yet. Be the first.';

  @override
  String leagueMyRank(int rank, int points) {
    return 'You are #$rank with $points points.';
  }

  @override
  String get reactWith => 'React with…';

  @override
  String get reactPickEmoji => 'Pick an emoji on the keyboard';

  @override
  String get reactAction => 'React';

  @override
  String get mediaPoll => 'Poll';

  @override
  String get mediaContact => 'Contact';

  @override
  String get mediaSharedContact => 'Shared contact';

  @override
  String get convEdited => '· edited';

  @override
  String get convFallbackName => 'Conversation';

  @override
  String get convSomeone => 'Someone';

  @override
  String get contactsTagFailed => 'Could not update the label.';

  @override
  String get contactsTag => 'Label';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactsTyping => 'typing…';

  @override
  String contactsTypingNamed(String name) {
    return '$name is typing…';
  }

  @override
  String contactsPreviewMine(String preview) {
    return 'You: $preview';
  }

  @override
  String contactsPreviewSender(String name, String preview) {
    return '$name: $preview';
  }

  @override
  String contactsNotInContacts(String preview) {
    return '$preview · not in your contacts';
  }

  @override
  String get contactsAssistantSub => 'Your AI assistant';

  @override
  String get addContactTitle => 'Add a contact';

  @override
  String get addContactName => 'Name';

  @override
  String get addContactAction => 'Add';

  @override
  String get joinLinkTitle => 'Join by link';

  @override
  String get joinLinkBody =>
      'Paste the link you were sent. Group or community, we recognise which.';

  @override
  String get joinLinkContinue => 'Continue';

  @override
  String get joinLinkUnreadable => 'Invitation link unreadable.';

  @override
  String joinAlreadyMember(String name) {
    return 'You are already in “$name”.';
  }

  @override
  String joinGroupQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0. Join this group?';
  }

  @override
  String get joinAction => 'Join';

  @override
  String get joinGroupFailed => 'Could not join this group.';

  @override
  String joinCommunityCounts(int members, int groups) {
    String _temp0 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members members',
      one: '1 member',
    );
    String _temp1 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groups',
      one: '1 group',
    );
    return '$_temp0 · $_temp1.';
  }

  @override
  String get joinCommunityBody =>
      'You will receive its announcements. The other groups still have to be joined one by one.';

  @override
  String get joinCommunityFailed => 'Could not join this community.';

  @override
  String get newChatOwnNumber => 'That is your own number.';

  @override
  String get phoneLookupFailed => 'Invalid number, or it could not be checked.';

  @override
  String get phoneNotOnPokou => 'This number is not on Pokou yet.';

  @override
  String get phoneInviteWhatsApp => 'Invite via WhatsApp';

  @override
  String get phoneInviteText =>
      'Hi! I\'m inviting you to try Pokou, a private messenger — download the app and add me.';

  @override
  String get contactCardTitle => 'Contact card';

  @override
  String get viewOnceSeen => 'Viewed';

  @override
  String get viewOnceTapToSee => 'View once — tap to see';

  @override
  String get audioPlayFailed => 'Playback failed';

  @override
  String mediaPhotoSize(Object size) {
    return 'Photo · $size';
  }

  @override
  String get mediaTapToDownload => 'Tap to download';

  @override
  String get mediaVideoUnavailable => 'Video unavailable';

  @override
  String get mediaOpenDocFailed => 'Could not open this document.';

  @override
  String get mediaOpenRetry => 'Opening failed — tap to retry';

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdayTuesday => 'Tuesday';

  @override
  String get weekdayWednesday => 'Wednesday';

  @override
  String get weekdayThursday => 'Thursday';

  @override
  String get weekdayFriday => 'Friday';

  @override
  String get weekdaySaturday => 'Saturday';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String liveHoursLeft(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours h left',
      one: '1 h left',
    );
    return '$_temp0';
  }

  @override
  String liveMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min left',
      one: '1 min left',
    );
    return '$_temp0';
  }

  @override
  String get liveAlmostOver => 'almost over';

  @override
  String liveLocation(String remaining) {
    return 'Live · $remaining';
  }

  @override
  String get openInMaps => 'Open in Maps';

  @override
  String get composerEditPhoto => 'Edit the photo';

  @override
  String get composerEditorFailed => 'The editor could not open.';

  @override
  String get composerCropRotate => 'Crop or rotate';

  @override
  String get composerCaptionHint => 'Add a caption…';

  @override
  String composerTo(String name) {
    return 'to $name';
  }

  @override
  String get composerSend => 'Send';

  @override
  String get convOfflineNotCached =>
      'Offline — this conversation is not cached yet.';

  @override
  String get convLoadFailed => 'Could not load the conversation.';

  @override
  String get convEmptyEdit => 'An empty message cannot replace a text.';

  @override
  String get convEditFailed => 'Edit failed — check your connection.';

  @override
  String get convOrderUpdateFailed => 'Could not update the order.';

  @override
  String get convDeleteFailed => 'Could not delete the message.';

  @override
  String get convForwardFailedMsg => 'Could not forward the message.';

  @override
  String get convOfflineAttachment =>
      'Offline — attachments need a connection.';

  @override
  String get convAttachmentFailed => 'Attachment not sent — try again.';

  @override
  String get groupOfflineNotCached => 'Offline — this group is not cached yet.';

  @override
  String get groupLoadFailed => 'Could not load the group.';

  @override
  String get groupRenameFailed => 'Could not rename the group.';

  @override
  String get groupPhotoFailed => 'Group photo not saved.';

  @override
  String get groupClearPhotoFailed => 'Could not remove the photo.';

  @override
  String get groupRoleFailed => 'Could not change this role.';

  @override
  String get groupInviteCreateFailed => 'Could not create the invitation link.';

  @override
  String get groupInviteRevokeFailed => 'Could not disable the link.';

  @override
  String get groupLeaveFailed => 'Could not leave the group.';

  @override
  String get groupRemoveMemberFailed => 'Could not remove this member.';

  @override
  String get apiNetworkSilent => 'The network is not responding';

  @override
  String apiError(int code) {
    return 'Error ($code)';
  }

  @override
  String get orderProductDiscussed => 'Item discussed';

  @override
  String get orderValidate => 'Confirm the order';

  @override
  String get orderMarkShipped => 'Mark as shipped';

  @override
  String get orderMarkDelivered => 'Mark as delivered';

  @override
  String get orderBuyerWaiting => 'This buyer is waiting for your answer.';

  @override
  String get orderNextStep => 'Next step of the order.';

  @override
  String get msgNotSentRetry => 'Not sent · Retry';

  @override
  String get msgPendingSend => 'Waiting to be sent';

  @override
  String convSearchHint(String name) {
    return 'Search in $name…';
  }

  @override
  String get convSearchPrompt =>
      'Type a word to find a message in this conversation.';

  @override
  String get convSearchEmpty => 'No message found.';

  @override
  String get commonUnknownName => 'Unknown';

  @override
  String get groupInviteLink => 'Invitation link';

  @override
  String get groupDemoteAdmin => 'Remove admin rights';

  @override
  String get groupPromoteAdmin => 'Make admin';

  @override
  String get groupInviteLinkBody =>
      'Anyone who opens this link joins the group directly, with no further step. Regenerate it to invalidate the one already shared.';

  @override
  String get groupNewLinkCreated =>
      'New link created — the old one no longer works.';

  @override
  String get groupAddFailed => 'Could not add.';

  @override
  String get groupCreateFailed => 'Could not create the group.';

  @override
  String get groupNewTitle => 'New group';

  @override
  String get groupCreateAction => 'Create';

  @override
  String get groupNameHint => 'Group name';

  @override
  String get groupPickParticipants => 'Choose the participants';

  @override
  String groupSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants selected',
      one: '1 participant selected',
    );
    return '$_temp0';
  }

  @override
  String get pushIncomingVideoCall => 'Incoming video call';

  @override
  String get pushIncomingAudioCall => 'Incoming audio call';

  @override
  String get pushAnswer => 'Answer';

  @override
  String get pushDecline => 'Decline';

  @override
  String get pushMessagesChannel => 'Messages';

  @override
  String get pushMessagesChannelDesc => 'Notifications for new Pokou messages';

  @override
  String get pushCallsChannel => 'Calls';

  @override
  String get pushCallsChannelDesc => 'Notifications for incoming Pokou calls';

  @override
  String get pushGroupFallback => 'Group';

  @override
  String get notifNewMessage => 'New message';

  @override
  String get notifPhoto => '📷 Photo';

  @override
  String get notifVideo => '🎥 Video';

  @override
  String get notifVoice => '🎤 Voice message';

  @override
  String get notifDocument => '📄 Document';

  @override
  String get notifSticker => 'Sticker';

  @override
  String get notifLocation => '📍 Location';

  @override
  String get notifContact => '👤 Contact';

  @override
  String get notifPoll => '📊 Poll';

  @override
  String get notifMe => 'Me';

  @override
  String get notifReply => 'Reply';

  @override
  String get notifReplyHint => 'Your message';

  @override
  String get notifMarkRead => 'Mark as read';

  @override
  String get notifReplyQueued => 'sends when Pokou opens';

  @override
  String get notifReplyFailed => 'Reply not sent — open Pokou to try again';

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
  String get audienceContacts => 'My contacts';

  @override
  String get audienceNobody => 'Nobody';

  @override
  String get audienceExcept => 'My contacts except…';

  @override
  String get audienceOnly => 'Only share with…';

  @override
  String get audienceContactsDesc => 'All the contacts saved on your phone';

  @override
  String get audienceNobodyDesc => 'Your statuses will be visible to you only';

  @override
  String get audienceExceptDesc => 'Your contacts, except those you pick';

  @override
  String get audienceOnlyDesc => 'Only the people you pick';

  @override
  String get statusViewerFallback => 'User';

  @override
  String get statusPrivacySaved => 'Visibility saved.';

  @override
  String get statusPrivacySaveFailed =>
      'Could not save — check your connection.';

  @override
  String get statusPrivacyTitle => 'Status visibility';

  @override
  String get statusExcludePeople => 'People to exclude';

  @override
  String get statusAllowedPeople => 'Allowed people';

  @override
  String get statusNoContactToOffer => 'No Pokou contact to offer right now.';

  @override
  String get statusExceptFootnote =>
      'These people will not see your statuses, even if they are in your contacts.';

  @override
  String get statusOnlyFootnote =>
      'Only these people will see your statuses. They do not need to have you in their contacts.';

  @override
  String get status24hFootnote =>
      'A status disappears after 24 hours anyway, for everyone.';

  @override
  String get statusGallery => 'Gallery';

  @override
  String get statusCamera => 'Camera';

  @override
  String get statusNewTitle => 'New status';

  @override
  String get statusText => 'Text';

  @override
  String get statusTypeHint => 'Type your status…';

  @override
  String get statusPublish => 'Publish';

  @override
  String get statusFeedTitle => 'Statuses';

  @override
  String get statusFeedUnavailable => 'Statuses unavailable — retry';

  @override
  String get statusSection => 'Statuses';

  @override
  String get statusMine => 'Me';

  @override
  String get channelsSection => 'Channels';

  @override
  String get bcastNeedName => 'Give this list a name.';

  @override
  String get bcastNeedRecipient => 'Choose at least one recipient.';

  @override
  String get bcastSaveFailed => 'Could not save.';

  @override
  String get bcastNewTitle => 'New broadcast';

  @override
  String get bcastEditTitle => 'Edit the list';

  @override
  String get bcastNameHint => 'List name (visible to you only)';

  @override
  String get bcastNoRecipient => 'No recipient';

  @override
  String bcastRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '1 recipient',
    );
    return '$_temp0';
  }

  @override
  String get bcastContactsUnavailable => 'Contacts unavailable.';

  @override
  String get bcastNobodyOnPokou =>
      'None of your contacts is on Pokou Messenger yet.';

  @override
  String get bcastNewList => 'New list';

  @override
  String get bcastListsTitle => 'Broadcast lists';

  @override
  String get bcastListsUnavailable => 'Lists unavailable.';

  @override
  String bcastDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get bcastDeleteBody =>
      'Messages already sent stay with their recipients. Only the list disappears.';

  @override
  String get bcastEmptyTitle => 'Announce once, to many';

  @override
  String get bcastEmptyBody =>
      'Each recipient gets the message in their private chat. They do not see the others, and reply to you alone — unlike a group, where everyone sees everyone.';

  @override
  String bcastSentTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sent to $count recipients.',
      one: 'Sent to 1 recipient.',
    );
    return '$_temp0';
  }

  @override
  String bcastSentPartly(int sent, int total, int skipped) {
    return 'Sent to $sent of $total — $skipped no longer receive your messages.';
  }

  @override
  String get bcastSendFailed => 'Sending failed.';

  @override
  String get bcastEditRecipients => 'Edit the recipients';

  @override
  String get bcastHistoryUnavailable => 'History unavailable.';

  @override
  String get bcastNothingSent => 'Nothing has been broadcast yet.';

  @override
  String get bcastMessageHint => 'Message to broadcast';

  @override
  String get bcastPrivacyNotice =>
      'Each recipient gets this message privately. They do not see the others, and their reply reaches you in your chat with them.';

  @override
  String get channelNameRequired => 'The channel name is required.';

  @override
  String get channelSaveFailed => 'Could not save the channel.';

  @override
  String get channelEditTitle => 'Edit the channel';

  @override
  String get channelNewTitle => 'New channel';

  @override
  String get channelAddImage => 'Add an image';

  @override
  String get channelChangeImage => 'Change the image';

  @override
  String get channelRemoveImage => 'Remove the image';

  @override
  String get channelNameLabel => 'Channel name';

  @override
  String get channelNameHint => 'E.g. My company news';

  @override
  String get channelDescriptionLabel => 'Description';

  @override
  String get channelDescriptionHint => 'Introduce your channel';

  @override
  String get channelSaveChanges => 'Save changes';

  @override
  String get channelCreateAction => 'Create the channel';

  @override
  String get channelLinkCopiedClipboard => 'Link copied to the clipboard.';

  @override
  String get channelLinkUnavailableShort => 'Link unavailable.';

  @override
  String get channelSearchTooltip => 'Search for a channel';

  @override
  String get channelCreateTooltip => 'Create a channel';

  @override
  String get channelEmptyHint => 'Create a channel to share your news.';

  @override
  String get channelGenerateLink => 'Generate a link';

  @override
  String get channelEditTooltip => 'Edit';

  @override
  String get channelSearchHint => 'Search for a channel…';

  @override
  String get channelSearchPrompt =>
      'Search by name or description. Verified channels appear first.';

  @override
  String get channelSearchEmpty => 'No channel found.';

  @override
  String get channelNothingPublishedAdmin =>
      'Nothing published yet — tap + for your first post.';

  @override
  String get channelNothingPublished =>
      'This channel has not published anything yet.';

  @override
  String get channelFollow => 'Follow';

  @override
  String get channelFallbackName => 'Channel';

  @override
  String get communityNewTitle => 'New community';

  @override
  String get communityNewBody =>
      'A community brings several groups together around the same people. An “Announcements” group is created with it: you alone write there, all its members read.';

  @override
  String get communityNameHint => 'Community name';

  @override
  String get communityDescriptionHint => 'Description (optional)';

  @override
  String get communityCreateAction => 'Create';

  @override
  String get communityCreateFailed => 'Could not create.';

  @override
  String get communityNoGroupToAttach =>
      'You have no other group to attach. Only groups you administer can join a community.';

  @override
  String get communityAddGroupFailed => 'Could not add this group.';

  @override
  String get communityLinkFailed => 'Could not create the link.';

  @override
  String get communityCreateLink => 'Create a link';

  @override
  String get sparkOpenRoomsSub => 'They close on their own';

  @override
  String get sparkMore => 'More';

  @override
  String sparkRoomOpen(String time) {
    return 'Room open — $time';
  }

  @override
  String get sparkBothYes => 'You both said yes';

  @override
  String get sparkMatchSaved => 'Match saved';

  @override
  String get sparkRoomClosed => 'Room closed';

  @override
  String get sparkMatch => 'Match';

  @override
  String get sparkUnavailable => 'Spark is unavailable';

  @override
  String get sparkTodaysDate => 'Today\'s date';

  @override
  String get sparkTabOutings => 'Outings';

  @override
  String sparkPersonAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String get aiSuggestSummary => 'Summary';

  @override
  String get aiSuggestSummarySub => 'A quick overview';

  @override
  String get aiSuggestSummaryPrompt =>
      'Give me a summary of the current situation.';

  @override
  String get aiSuggestTrend => 'Trend';

  @override
  String get aiSuggestTrendSub => 'Analyse a change';

  @override
  String get aiSuggestTrendPrompt => 'What is the trend over the last 7 days?';

  @override
  String get aiSuggestAlerts => 'Alerts';

  @override
  String get aiSuggestAlertsSub => 'Latest signals';

  @override
  String get aiSuggestAlertsPrompt =>
      'Are there any recent alerts I should know about?';

  @override
  String get aiSuggestAdvice => 'Advice';

  @override
  String get aiSuggestAdviceSub => 'Ask for an idea';

  @override
  String get aiSuggestAdvicePrompt =>
      'Give me some advice for organising my day.';

  @override
  String get aiSuggestWrite => 'Write';

  @override
  String get aiSuggestWriteSub => 'Write a text';

  @override
  String get aiSuggestWritePrompt => 'Help me write a message.';

  @override
  String get aiSuggestQuestion => 'Question';

  @override
  String get aiSuggestQuestionSub => 'Anything at all';

  @override
  String get aiSuggestQuestionPrompt => 'I have a question for you.';

  @override
  String get aiMessageHint => 'Message…';

  @override
  String get aiHowCanIHelp => 'How can I help you?';

  @override
  String get aiAskAnything => 'Ask me anything.';

  @override
  String get aiAskAboutData => 'Ask a question about your connected data.';

  @override
  String get aiThinking => 'Baba is thinking';

  @override
  String aiHelloIm(String name) {
    return 'Hello, I\'m $name';
  }

  @override
  String get aiPartner => 'Your digital partner';

  @override
  String get aiGreetMorning => 'Good morning';

  @override
  String get aiGreetAfternoon => 'Good afternoon';

  @override
  String get aiGreetEvening => 'Good evening';

  @override
  String get aiNewChat => 'New chat';

  @override
  String get aiCopy => 'Copy';

  @override
  String get aiCopied => 'Copied';

  @override
  String get aiGenerated => 'AI-generated';

  @override
  String get aiVoiceListening => 'I\'m listening…';

  @override
  String get aiVoiceTranscribing => 'Transcribing…';

  @override
  String get aiVoiceFailed => 'I couldn\'t hear you. Try again.';

  @override
  String get aiVoiceSpeak => 'Talk to the assistant';

  @override
  String get aiVoiceRestart => 'Start over';

  @override
  String get aiVoiceSend => 'Send';

  @override
  String get aiVoiceStop => 'Done';

  @override
  String get aiSendFailed => 'Message not sent — try again.';

  @override
  String get digestTitle => 'Today\'s recap';

  @override
  String get digestUnread => 'Unread messages:';

  @override
  String get digestMissedCalls => 'Missed calls:';

  @override
  String get digestVideoSuffix => ' (video)';

  @override
  String digestShieldDeferred(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages held by Shield Mode.',
      one: '1 message held by Shield Mode.',
    );
    return '$_temp0';
  }

  @override
  String digestMonitorSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signals from your monitors to review.',
      one: '1 signal from your monitors to review.',
    );
    return '$_temp0';
  }

  @override
  String get digestNothing => 'Nothing to report today — have a good evening!';

  @override
  String get shieldUnknownNumber => 'Unknown number';

  @override
  String shieldFlushSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages held during your meeting.',
      one: '1 message held during your meeting.',
    );
    return '$_temp0';
  }

  @override
  String get shieldPendingMessages => 'Held messages';

  @override
  String shieldHandleSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages held by Shield Mode — swipe down to show them',
      one: '1 message held by Shield Mode — swipe down to show it',
    );
    return '$_temp0';
  }

  @override
  String shieldCallFrom(Object name) {
    return 'Call from $name';
  }

  @override
  String get shieldCallHeld => 'On hold — Shield Mode';

  @override
  String get statusViewersUnavailable => 'Viewer list unavailable.';

  @override
  String statusSeenBy(int count) {
    return 'Seen by $count';
  }

  @override
  String get statusNobodySeen => 'Nobody has seen it yet.';

  @override
  String get statusBoostFailed => 'Could not boost the status.';

  @override
  String get statusDeleteTitle => 'Delete this status?';

  @override
  String get statusDeleteBody =>
      'It will disappear for everyone who can see it.';

  @override
  String get statusDeleteFailed => 'Couldn\'t delete — check your connection.';

  @override
  String get statusPublishFailed =>
      'Couldn\'t publish — check your connection and try again.';

  @override
  String get statusBoostAction => 'Boost this status · 1,000 FCFA';

  @override
  String get modulesSubtitle => 'Add what serves you, leave the rest';

  @override
  String get modulePaymentFailed => 'The payment could not be started.';

  @override
  String deeplinkFollowedChannel(String name) {
    return 'Subscribed to the channel “$name”';
  }

  @override
  String get deeplinkOpenFailed =>
      'This invitation link could not be opened right now.';

  @override
  String get cropTitle => 'Crop';

  @override
  String get cropHint => 'Pinch to zoom, drag to frame';

  @override
  String get cropConfirm => 'Confirm';

  @override
  String get inviteJoinMe => 'Join me on Pokou Messenger';

  @override
  String inviteJoinMeNamed(String name) {
    return '$name, join me on Pokou Messenger';
  }

  @override
  String get otpNoCodeReceived => 'Didn\'t get a code?';

  @override
  String get countryDialCode => 'Country dialling code';

  @override
  String get countrySearchHint => 'Country or code (e.g. Benin, 229)';

  @override
  String get countryNoneFound => 'No country found.';

  @override
  String get presenceSomeone => 'Someone';

  @override
  String atTime(String time) {
    return 'at $time';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String truthAskedTo(String name) {
    return 'To $name';
  }

  @override
  String get devicesNoPushHere => 'This device is not receiving notifications.';

  @override
  String get devicesNoPushHereBody =>
      'It could not register with the notification service. Tap to try again.';

  @override
  String get devicesRetryDone => 'This device now receives notifications.';

  @override
  String get devicesRetryFailed =>
      'Still could not register — try again later.';

  @override
  String get chatsProfileMissing =>
      'Profile unavailable — check your connection, then try again.';

  @override
  String get recSlideToCancel => 'Slide to cancel';

  @override
  String get recReleaseToCancel => 'Release to cancel';

  @override
  String get recLocked => 'Locked';

  @override
  String get recSlideUpToLock => 'Slide up to lock';

  @override
  String get recDelete => 'Delete the recording';

  @override
  String get recHoldToRecord => 'Hold to record';

  @override
  String get composerViewOnce => 'View once';

  @override
  String get composerViewOnceOn =>
      'View once on — the photo will disappear after it is opened.';

  @override
  String get composerViewOnceOff => 'View once off.';

  @override
  String get channelSuggestedTitle => 'Channels to follow';

  @override
  String get channelSuggestedBody =>
      'You don\'t follow any yet. Here are a few.';

  @override
  String get channelSuggestedNone => 'No channel to suggest right now.';

  @override
  String channelFollowed(String name) {
    return 'Following “$name”';
  }

  @override
  String get channelFollowFailed => 'Could not follow — check your connection.';

  @override
  String get certifyTitle => 'Verified channel';

  @override
  String get certifyWhyTitle => 'A badge, and the top of the suggestions';

  @override
  String get certifyWhyBody =>
      'Verified channels appear first to anyone looking for something to follow, and the badge shows on every post you publish.';

  @override
  String get certifyReviewTitle => 'A review, not a purchase';

  @override
  String get certifyReviewBody =>
      'Our team reads your channel before granting the badge. A badge you could simply buy would be worth nothing — that is what gives it value.';

  @override
  String get certifyRefundTitle => 'Rejected? You get a refund';

  @override
  String get certifyRefundBody =>
      'If the badge cannot be granted, contact us: the amount is returned to you.';

  @override
  String get certifyRenewTitle => 'A subscription, not a permanent right';

  @override
  String get certifyRenewBody =>
      'The badge lasts as long as the plan you choose. Renewing before it expires extends it without losing anything.';

  @override
  String get certifyPlanMonthly => 'Monthly — 3,000 FCFA';

  @override
  String get certifyPlanAnnual => 'Annual — 30,000 FCFA (two months free)';

  @override
  String get certifyAction => 'Pay and send the request';

  @override
  String get certifyPending =>
      'Your request reaches the team as soon as the payment is confirmed.';

  @override
  String get certifyFailed => 'Request failed — try again.';

  @override
  String get certifyAlready => 'This channel is verified';

  @override
  String get certifyTooltip => 'Get this channel verified';

  @override
  String get chatsStartTitle => 'Start a conversation';

  @override
  String get chatsStartBody =>
      'Your contacts are already on Pokou. Tap a name to write to them.';

  @override
  String get chatsSeeAllContacts => 'See all my contacts';

  @override
  String get chatsNoNetworkTitle => 'Your network isn\'t on Pokou yet';

  @override
  String get chatsNoNetworkBody =>
      'Invite someone, or follow a channel while you wait for a reply.';

  @override
  String get chatsInviteContacts => 'Invite contacts';

  @override
  String get chatsDiscoverChannels => 'Discover channels';

  @override
  String get e2eeEncrypted => 'End-to-end encrypted';

  @override
  String get e2eeNotEncrypted => 'Not encrypted';

  @override
  String get e2eeNotEncryptedBody =>
      'This person needs to update Pokou for encryption.';

  @override
  String get e2eeIdentityChangedTitle =>
      'This contact\'s security information has changed';

  @override
  String e2eeIdentityChangedBody(String name) {
    return '$name\'s security key changed (new phone or reinstall). If in doubt, check with $name.';
  }

  @override
  String get e2eeIdentityAccept => 'I\'ve verified, continue';

  @override
  String get e2eeBlockedTitle => 'Message not sent';

  @override
  String get e2eeBlockedLookup =>
      'Could not retrieve the encryption key. The message was not sent — Pokou will never send it unencrypted without telling you.';

  @override
  String get e2eeBlockedInvalid =>
      'The key received is unusable. The message was not sent, as a precaution.';

  @override
  String get e2eeBlockedIdentity =>
      'This contact\'s key has changed. Verify their identity before sending.';

  @override
  String get e2eeBlockedCrypto =>
      'Encryption failed. The message was not sent.';

  @override
  String get e2eeRetry => 'Try again';

  @override
  String get profileTheme => 'Appearance';

  @override
  String get themeSystem => 'Match the phone';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeHint =>
      'Dark mode is easier on the eyes at night and saves battery on OLED screens.';

  @override
  String get a11yBack => 'Back';

  @override
  String get a11yRefresh => 'Refresh';

  @override
  String get a11yMoreOptions => 'More options';

  @override
  String get a11yVoiceCall => 'Voice call';

  @override
  String get a11yVideoCall => 'Video call';

  @override
  String get a11yAttach => 'Attach a file';

  @override
  String get a11yRate => 'Rate';

  @override
  String get a11yAudioLevel => 'Audio level';

  @override
  String get marketCreateAd => 'Create an ad';

  @override
  String get adSponsored => 'Sponsored';

  @override
  String get adYours => 'Your ad';

  @override
  String get adContact => 'Contact';

  @override
  String get adContactFailed => 'Couldn\'t contact the advertiser.';

  @override
  String get mediaSaveToPhone => 'Save to phone';

  @override
  String get mediaUndecryptable =>
      'Encrypted attachment can\'t be opened on this phone.';

  @override
  String get mediaSaved => 'Saved to your gallery';

  @override
  String get mediaExported => 'Choose where to save it';

  @override
  String get mediaSavePermission =>
      'Pokou needs access to your photos to save this file.';

  @override
  String get mediaSaveNoSpace => 'Not enough space on the phone.';

  @override
  String get mediaSaveFailed => 'Could not save.';

  @override
  String get composerEmoji => 'Emojis';

  @override
  String get convAttachGif => 'GIF';

  @override
  String get stickerTabEmoji => 'Emoji';

  @override
  String get stickerTabStickers => 'Stickers';

  @override
  String get stickerSearchHint => 'Search for a sticker';

  @override
  String get stickerRecents => 'Recent';

  @override
  String get stickerFavorites => 'Favourites';

  @override
  String get stickerNoResult => 'No sticker found';

  @override
  String get stickerEmptyPanel => 'No stickers yet';

  @override
  String get stickerBrowsePacks => 'Browse packs';

  @override
  String get stickerManagePacks => 'Manage packs';

  @override
  String get stickerPacksTitle => 'Sticker packs';

  @override
  String get stickerPackAdd => 'Add';

  @override
  String get stickerPackAdded => 'Added';

  @override
  String get stickerPackRemove => 'Remove';

  @override
  String get stickerPackDelete => 'Delete pack';

  @override
  String get stickerPackDeleteConfirm =>
      'Delete this pack and all its stickers?';

  @override
  String get stickerMyPackName => 'My stickers';

  @override
  String get stickerCreateFromPhoto => 'Create from a photo';

  @override
  String get stickerCreated => 'Sticker added to your stickers';

  @override
  String get stickerLimitReached => 'Your personal pack is full';

  @override
  String get stickerSendFailed => 'Sticker not sent — try again';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get stickerFavoriteAdded => 'Added to favourites';

  @override
  String get stickerFavoriteRemoved => 'Removed from favourites';

  @override
  String get stickerStoreEmpty => 'No packs available yet';

  @override
  String get stickerSaveToMine => 'Add to my stickers';

  @override
  String get stickerSaved => 'Sticker added to your stickers';

  @override
  String get navBaba => 'Baba';

  @override
  String get appBarOnline => 'Online';

  @override
  String get appBarOffline => 'Offline';

  @override
  String get marketNegotiate => 'Negotiate';

  @override
  String get callsCallBack => 'Call back';

  @override
  String get callsFilterMissed => 'Missed';

  @override
  String get callsFilterAll => 'All';

  @override
  String get chatsFilterAll => 'All';

  @override
  String get chatsFilterUnread => 'Unread';

  @override
  String get chatsFilterGroups => 'Groups';

  @override
  String get chatsSearchOrAsk => 'Search or ask Baba…';

  @override
  String get convEncryptedHint => 'Encrypted message…';

  @override
  String get chatsArchivedSection => 'Archived chats';

  @override
  String get statusMineTitle => 'My status';

  @override
  String get statusMineBody => 'Tap to post an update (24 h)';

  @override
  String get statusMineVisibility => 'Visible to: My contacts';

  @override
  String get callLeaveConference => 'Leave the call';

  @override
  String get callQualityExcellent => 'Excellent';

  @override
  String get callQualityGood => 'Good';

  @override
  String get callQualityPoor => 'Poor';

  @override
  String get callYouShort => 'You';

  @override
  String get callMutedShort => 'Muted';

  @override
  String get callMuteLabel => 'Mic';

  @override
  String get callCameraLabel => 'Camera';

  @override
  String get callSpeakerLabel => 'Speaker';

  @override
  String get callFlipCamera => 'Flip camera';

  @override
  String get callFlipCameraFailed => 'Couldn\'t switch camera.';

  @override
  String get callNoAnswer => 'No answer.';

  @override
  String callOngoingBanner(String duration) {
    return 'Call in progress · $duration — tap to return';
  }

  @override
  String get callOngoingBannerRinging => 'Call in progress — tap to return';

  @override
  String get callHangUp => 'Hang up';

  @override
  String get callInviteLabel => 'Invite';

  @override
  String get e2eeReassurance =>
      'End-to-end encrypted: no one else, not even Pokou, can read these messages.';

  @override
  String get chatsEncryptionFooter => 'Your chats are end-to-end encrypted.';

  @override
  String get callsRecentSection => 'RECENT';

  @override
  String get callsGroupChip => 'Group';

  @override
  String get callGroupNotEncrypted =>
      'Standard group call — not end-to-end encrypted';

  @override
  String get marketCatalogueSeeAll => 'See all';

  @override
  String get marketCatalogueOpen => 'Open my catalogue';

  @override
  String get marketCatalogueTotal => 'Listings';

  @override
  String get marketCatalogueOnline => 'Online';

  @override
  String get marketCatalogueBoostedLabel => 'Boosted';

  @override
  String get marketCatalogueWithdrawn => 'Withdrawn';

  @override
  String get marketFilterAll => 'All';

  @override
  String get marketCertifiedSellers => 'Certified sellers';

  @override
  String get marketCatalogueNoneInFilter => 'No listing matches this filter.';

  @override
  String get marketStatusModerated => 'Removed from the marketplace';

  @override
  String get marketStatusModeratedBody =>
      'Buyers can no longer see it. Contact support if you think this is a mistake.';

  @override
  String get callsFilterDirect => 'One-to-one';

  @override
  String get profileMyAccount => 'My account';

  @override
  String get profileVerifyAccount => 'Verify my account';

  @override
  String get profileVerifyAccountBody =>
      'Get the verified seller badge on the Market';

  @override
  String get profileCertificationPending => 'Certification pending';

  @override
  String get profileCertificationPendingBody =>
      'Your request is being reviewed.';

  @override
  String get profileCertificationActive => 'Certified account';

  @override
  String get profileCertificationActiveBody =>
      'The certification badge appears next to your name.';

  @override
  String get profileSellerCertified => 'Verified seller';

  @override
  String profileSellerCertifiedUntil(String date) {
    return 'Seller badge active until $date.';
  }

  @override
  String get verifPlanLabel => 'Choose your plan';

  @override
  String get callEventAudio => 'Voice call';

  @override
  String get callEventVideo => 'Video call';

  @override
  String get callEventGroup => 'Group call';

  @override
  String get callEventMissed => 'Missed call';

  @override
  String get callEventNoAnswer => 'No answer';

  @override
  String get callEventDeclined => 'Declined';

  @override
  String get callEventYouDeclined => 'You declined';

  @override
  String get callEventEnded => 'Ended';

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
  String get mediaCall => 'Call';

  @override
  String get mediaSticker => 'Sticker';

  @override
  String get identityVerifiedAccount => 'Verified account';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyIntro =>
      'These settings are enforced by the server: what you hide is not sent to others, not merely hidden in the app.';

  @override
  String get privacySectionWhoSees => 'Who can see my information';

  @override
  String get privacySectionMessages => 'Messages';

  @override
  String get privacySectionGroups => 'Groups';

  @override
  String get privacyLastSeen => 'Last seen';

  @override
  String get privacyLastSeenBody => 'When you were last connected.';

  @override
  String get privacyOnline => 'Online presence';

  @override
  String get privacyOnlineBody =>
      'The green dot that says you are reachable now. Independent from last seen.';

  @override
  String get privacyProfilePhoto => 'Profile photo';

  @override
  String get privacyProfilePhotoBody => 'Your photo, everywhere it appears.';

  @override
  String get privacyProfileInfo => 'Profile info';

  @override
  String get privacyProfileInfoBody =>
      'Your description and what you filled in about yourself.';

  @override
  String get privacyReadReceipts => 'Read receipts';

  @override
  String get privacyReadReceiptsBody =>
      'Turning them off also hides other people\'s. Delivery ticks stay visible.';

  @override
  String get privacyGroupInvites => 'Who can invite me to a group';

  @override
  String get privacyGroupInvitesBody =>
      'Allowing is not accepting: you keep the final say on every invitation.';

  @override
  String get privacyGroupMembership => 'Who can see my group memberships';

  @override
  String get privacyGroupMembershipBody =>
      'Who can see which groups you are in. Members of a group still know each other.';

  @override
  String get privacyEveryone => 'Everyone';

  @override
  String get privacyMyContacts => 'My contacts';

  @override
  String get privacyNobody => 'Nobody';

  @override
  String get privacySaveFailed => 'Setting not saved — try again.';

  @override
  String get privacyUnavailable => 'Privacy settings unavailable.';

  @override
  String get privacyStatusesNote =>
      'Status privacy is set from the Updates tab, where you can also exclude specific people.';

  @override
  String groupInvitesSent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations sent',
      one: 'Invitation sent',
      zero: 'No invitation sent',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationTitle => 'Group invitation';

  @override
  String groupInvitationFrom(Object name) {
    return '$name invites you';
  }

  @override
  String groupInvitationMembers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationAccept => 'Join';

  @override
  String get groupInvitationReject => 'Decline';

  @override
  String groupInvitationExpires(Object hours) {
    return 'Expires in $hours h';
  }

  @override
  String get groupInvitationExpiresSoon => 'Expires soon';

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
      'Action failed — the invitation may no longer be valid.';

  @override
  String get mediaStatePreparing => 'Preparing…';

  @override
  String get mediaStateSending => 'Sending…';

  @override
  String mediaStateSendingPercent(Object percent) {
    return 'Sending · $percent %';
  }

  @override
  String get mediaStateWaitingNetwork => 'Waiting for connection';

  @override
  String get mediaStateFailed => 'Could not send';

  @override
  String get mediaStateFileGone => 'File no longer on this device';

  @override
  String get channelPrivateLabel => 'Private channel';

  @override
  String get channelPrivateBody =>
      'Not discoverable by search. Only people you give the link to can join and read its posts. This cannot be changed later.';

  @override
  String get channelPrivateBadge => 'Private';

  @override
  String get mahizuConnectTitle => 'Connect your Mahizu account';

  @override
  String mahizuConnectBody(String phone) {
    return 'The assistant is a Mahizu service, separate from Pokou. To use it, link your Mahizu account: a code will be sent to $phone.';
  }

  @override
  String get mahizuSendCode => 'Get the code';

  @override
  String get mahizuCodeLabel => 'Code received';

  @override
  String get mahizuPinLabel => 'Your Mahizu account PIN';

  @override
  String get mahizuConfirm => 'Connect';

  @override
  String get mahizuRestart => 'Start over';

  @override
  String get navHome => 'Home';

  @override
  String get navKory => 'Kory';

  @override
  String get navMore => 'More';

  @override
  String homeGreeting(String name) {
    return 'Hello $name';
  }

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeNoChats => 'No chats yet';

  @override
  String get homeKoryEmpty => 'No active pot';

  @override
  String get homeSearchHint => 'Search a chat';

  @override
  String get moreCertifiedTitle => 'Pokou certified';

  @override
  String get moreCertifiedBody =>
      'Verified identity and proof mode: coming soon.';

  @override
  String get moreSectionServices => 'Services';

  @override
  String get moreSectionSettings => 'Settings';

  @override
  String get moreAccount => 'Account and security';

  @override
  String get moreEdit => 'Edit';

  @override
  String get koryTitle => 'Kory';

  @override
  String get korySubtitle => 'Group pots & savings circles';

  @override
  String get koryMyPots => 'My pots';

  @override
  String get koryMonthTotal => 'My confirmed contributions this month';

  @override
  String get koryNoMoney =>
      'Pokou never touches the money: it goes straight from your wallet to the collector\'s.';

  @override
  String get koryCreate => 'Create a pot';

  @override
  String get koryJoin => 'Join';

  @override
  String get koryJournalTab => 'Log';

  @override
  String get koryJoinTitle => 'Join with a code';

  @override
  String get koryJoinHint => 'Pot code';

  @override
  String get koryJoinUnknown => 'Unknown code or closed pot.';

  @override
  String get koryNone => 'No active pot';

  @override
  String get koryNoneBody =>
      'Create a pot for a wedding, a baptism or a regular contribution, or join one with its code.';

  @override
  String get koryUnavailable => 'Kory is unavailable';

  @override
  String get koryKindCagnotte => 'Pot';

  @override
  String get koryKindCotisation => 'Contribution';

  @override
  String get koryTotalConfirmed => 'Confirmed total';

  @override
  String koryGoal(String amount) {
    return 'Goal: $amount';
  }

  @override
  String koryDue(String date) {
    return 'Due: $date';
  }

  @override
  String koryMyShare(String amount) {
    return 'My confirmed share: $amount';
  }

  @override
  String koryToReview(String count) {
    return 'To confirm: $count';
  }

  @override
  String get koryClosed => 'Closed';

  @override
  String get koryOpen => 'Open';

  @override
  String koryCollector(String name) {
    return 'Collector: $name';
  }

  @override
  String koryPayTo(String phone) {
    return 'Send your contribution from your wallet to $phone, then declare it here.';
  }

  @override
  String koryPerMember(String amount, String period) {
    return '$amount per member, $period';
  }

  @override
  String get koryDeclare => 'I contributed';

  @override
  String get koryDeclareTitle => 'Declare my contribution';

  @override
  String get koryAmount => 'Amount (FCFA)';

  @override
  String get koryWalletRef => 'Transaction reference (optional)';

  @override
  String get koryWalletRefHelp =>
      'It\'s in your operator\'s SMS. Only you and the collector can see it.';

  @override
  String get koryNote => 'Message (optional)';

  @override
  String get koryPeriodLabel => 'Period covered (e.g. 2026-11)';

  @override
  String get koryJournal => 'Contribution log';

  @override
  String get koryJournalEmpty => 'No contribution declared yet.';

  @override
  String get koryStatusDeclared => 'Waiting for the collector';

  @override
  String get koryStatusConfirmed => 'Confirmed';

  @override
  String get koryStatusRejected => 'Disputed';

  @override
  String get koryConfirm => 'Received';

  @override
  String get koryReject => 'Not received';

  @override
  String get koryCloseAction => 'Close';

  @override
  String get koryCloseConfirm =>
      'Close the pot? Nobody will be able to declare a contribution anymore.';

  @override
  String koryShareCode(String code) {
    return 'Code: $code';
  }

  @override
  String koryShareText(String title, String code) {
    return 'Join the pot “$title” on Pokou with the code $code.';
  }

  @override
  String get koryCreateTitle => 'New collection';

  @override
  String get koryFieldTitle => 'Title';

  @override
  String get koryFieldDescription => 'Description (optional)';

  @override
  String get koryFieldGoal => 'Goal in FCFA (optional)';

  @override
  String get koryFieldPerMember => 'Amount per member (FCFA)';

  @override
  String get koryPeriodMonthly => 'every month';

  @override
  String get koryPeriodWeekly => 'every week';

  @override
  String get koryFieldDue => 'Due date (optional)';

  @override
  String get koryNeedTitle => 'Give it a title (at least 3 characters).';

  @override
  String get koryNeedAmount => 'Enter an amount of at least 100 FCFA.';

  @override
  String get koryCollectorIsYou =>
      'You are the collector: contributions arrive on your wallet, and you confirm them.';

  @override
  String get koryYou => 'You';

  @override
  String get koryTontinePlus =>
      'Rotating savings circle: coming with Kory Plus';

  @override
  String get koryDeclared =>
      'Contribution declared. The collector will confirm it.';

  @override
  String get koryCopyPhone => 'Copy number';

  @override
  String get koryCopied => 'Copied';

  @override
  String get koryActionFailed => 'That didn\'t work. Try again.';

  @override
  String get welcomePromise => 'More than a messenger, a community.';

  @override
  String get welcomeSignature => 'Stronger together.';

  @override
  String get welcomeServiceChats => 'Chats, groups and calls';

  @override
  String get welcomeServiceKory => 'Group pots & savings circles';

  @override
  String get legalPrivacy => 'Privacy';

  @override
  String get legalTerms => 'Terms of use';

  @override
  String get legalUnavailable => 'Document unavailable for now.';

  @override
  String onbStep(String step) {
    return 'Step $step of 3';
  }

  @override
  String get onbProfileTitle => 'Your profile';

  @override
  String get onbProfileBody =>
      'Your first name or a nickname. You can add a photo later, from your profile.';

  @override
  String get onbDisplayName => 'Display name';

  @override
  String get onbNameRequired => 'Enter a name (at least 2 characters).';

  @override
  String get onbPhotoLater => 'You can add a photo later from your profile.';

  @override
  String get onbContinue => 'Continue';

  @override
  String get onbTermsTitle => 'Before you start';

  @override
  String get onbAcceptTerms =>
      'I have read and accept the terms of use and the privacy policy.';

  @override
  String get onbAge => 'I am old enough to use Pokou.';

  @override
  String get onbOptional => 'Optional';

  @override
  String get onbAnalytics => 'Usage statistics';

  @override
  String get onbMarketing => 'Pokou news';

  @override
  String get onbFinish => 'Finish';

  @override
  String get onbFailed => 'Saving failed. Try again.';

  @override
  String get moreConsents => 'Statistics and communications';

  @override
  String get navHonam => 'Honam';

  @override
  String get honamSubtitle => 'Pharmacies & delivery';

  @override
  String get honamIntro =>
      'A nearby pharmacy sends you a quote. Pay from your wallet and a courier delivers it to you.';

  @override
  String get honamSend => 'Send a prescription';

  @override
  String get honamPhotograph => 'Photograph the prescription';

  @override
  String get honamFromGallery => 'Choose a photo';

  @override
  String get honamUrgent => 'Emergency';

  @override
  String get honamNotEmergency => 'Pokou is not an emergency service.';

  @override
  String get honamNearby => 'Nearby pharmacies';

  @override
  String get honamOnDuty => 'On duty';

  @override
  String get honamNoPharmacy => 'No partner pharmacy yet.';

  @override
  String get honamCurrentOrder => 'Current order';

  @override
  String get honamMyOrders => 'My orders';

  @override
  String get honamChoosePharmacy => 'Choose the pharmacy';

  @override
  String get honamAddress => 'Delivery address';

  @override
  String get honamNote => 'Note for the pharmacist (optional)';

  @override
  String get honamSubmit => 'Send to the pharmacy';

  @override
  String get honamNeedPhoto => 'Add the prescription photo.';

  @override
  String get honamNeedAddress => 'Enter the delivery address.';

  @override
  String get honamFailed => 'That didn\'t work. Try again.';

  @override
  String honamOrderTitle(String id) {
    return 'Order #$id';
  }

  @override
  String get honamStSubmitted => 'Sent, waiting for the pharmacist';

  @override
  String get honamStQuoted => 'Quote received';

  @override
  String get honamStAccepted => 'Quote accepted, to pay';

  @override
  String get honamStPaid => 'Paid, being prepared';

  @override
  String get honamStReady => 'Ready, waiting for a courier';

  @override
  String get honamStInDelivery => 'Out for delivery';

  @override
  String get honamStDelivered => 'Delivered';

  @override
  String get honamStRejected => 'Prescription refused';

  @override
  String get honamStExpired => 'Quote expired';

  @override
  String get honamStCancelled => 'Cancelled';

  @override
  String get honamQuote => 'Quote';

  @override
  String get honamUnavailableItem => 'Unavailable';

  @override
  String get honamMedicines => 'Medicines';

  @override
  String get honamDelivery => 'Delivery';

  @override
  String get honamTotal => 'Total to pay';

  @override
  String get honamAcceptQuote => 'Accept the quote';

  @override
  String honamPayTo(String amount, String phone) {
    return 'Send $amount from your wallet to $phone (the pharmacy), then confirm.';
  }

  @override
  String get honamDeclarePaid => 'I paid the pharmacy';

  @override
  String get honamPaidDeclared =>
      'Payment reported: the pharmacy will confirm it.';

  @override
  String get honamPaymentNotReceived =>
      'The pharmacy hasn\'t received your payment. Check the number and amount.';

  @override
  String get honamCode => 'Your handover code';

  @override
  String get honamCodeHelp =>
      'Give this code to the courier only once you have the parcel in hand.';

  @override
  String get honamOriginal =>
      'The courier will collect the original prescription.';

  @override
  String honamRefundDue(String amount, String reason) {
    return 'The pharmacy owes you $amount: $reason';
  }

  @override
  String get honamRefundReceived => 'I received the refund';

  @override
  String get honamCancel => 'Cancel the order';

  @override
  String get honamResend => 'Send to another pharmacy';

  @override
  String honamReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get honamTimeline => 'Tracking';

  @override
  String get honamOrderMessages => 'Order messages';

  @override
  String get honamWriteMessage => 'Write a message';

  @override
  String get honamCourierMode => 'Courier mode';

  @override
  String get honamCourierJoin => 'Become a Win Pokou courier';

  @override
  String get honamCourierJoinBody =>
      '5 trial rides without commission for a month. Then: Win Pokou membership and a prepaid ride pack.';

  @override
  String honamRidesLeft(String count) {
    return 'Rides left: $count';
  }

  @override
  String get honamUnlimited => 'Unlimited rides';

  @override
  String honamMembership(String amount) {
    return 'Win Pokou membership: $amount excl. VAT / month';
  }

  @override
  String get honamPayMembership => 'Pay the membership';

  @override
  String get honamPacks => 'Ride packs';

  @override
  String honamPackPrice(String amount) {
    return '$amount excl. VAT';
  }

  @override
  String get honamAvailableRides => 'Available rides';

  @override
  String get honamMyRides => 'My rides';

  @override
  String get honamNoRides => 'No rides for now.';

  @override
  String get honamAcceptRide => 'Accept the ride';

  @override
  String get honamPickup => 'Parcel picked up';

  @override
  String get honamDeliver => 'Confirm handover';

  @override
  String get honamEnterCode => 'Code given by the patient';

  @override
  String get honamCoursePaid => 'I received the ride payment';

  @override
  String get honamPaymentLinkOpened =>
      'Finish the payment on the page that opens.';

  @override
  String get honamCourierSuspended =>
      'Courier account suspended after 3 delivery failures. Contact support to appeal.';

  @override
  String get honamPriceNote => 'Prices excl. VAT; local VAT applies.';

  @override
  String get certTitle => 'Pokou certified';

  @override
  String get certPitch =>
      'Your verified name, and a record of what people write to you.';

  @override
  String get certHowItWorks =>
      'Your identity is verified by the name of the wallet holder who pays.';

  @override
  String certStartTrial(String days) {
    String _temp0 = intl.Intl.selectLogic(days, {
      '30': 'Start the one-month trial',
      'other': 'Start the $days-day trial',
    });
    return '$_temp0';
  }

  @override
  String get certTrialNote =>
      'During the trial, proof mode is available. The badge shows at the first payment, which verifies your name.';

  @override
  String certPlanPrice(String ht, String ttc) {
    return '$ht excl. VAT · $ttc incl. VAT';
  }

  @override
  String get certSubscribe => 'Choose';

  @override
  String get certActive => 'Badge active';

  @override
  String certTrialUntil(String date) {
    return 'Trial until $date';
  }

  @override
  String certActiveUntil(String date) {
    return 'Active until $date';
  }

  @override
  String get certExpired => 'Subscription expired';

  @override
  String get certMismatchTitle => 'The names don\'t match';

  @override
  String get certMismatchBody =>
      'The name entered doesn\'t match the holder of the wallet that paid. Correct it as it appears on their ID.';

  @override
  String get proofModeTitle => 'Proof mode';

  @override
  String get proofModeOnBanner =>
      'Proof mode on. Deleted messages stay visible, struck through, for everyone.';

  @override
  String get proofModeEnable => 'Turn on proof mode';

  @override
  String get proofModeDisable => 'Turn off proof mode';

  @override
  String get proofModeNeedsCert =>
      'Proof mode requires Pokou certified (free trial available).';

  @override
  String get deleteForAll => 'Delete for everyone';

  @override
  String get deleteProofWarning =>
      'Proof mode is on. Your message will stay visible, struck through, for all participants, with the time it was deleted.';

  @override
  String get deletedKept => 'Deleted message, kept by proof mode';

  @override
  String get certCorrectName => 'Holder\'s full name';

  @override
  String get certRetryName => 'Check this name';

  @override
  String get certStillMismatch => 'This name still doesn\'t match.';

  @override
  String get proofExport => 'Export the chat as PDF';

  @override
  String proofModeOn(String name) {
    return '$name turned on proof mode';
  }

  @override
  String proofModeOff(String name) {
    return '$name turned off proof mode';
  }

  @override
  String proofOriginal(String text) {
    return 'Original version: $text';
  }

  @override
  String get proofDisableReserved =>
      'Only the person who turned it on, or an admin with a paid badge, can turn it off.';

  @override
  String get marketBoost3 => '3 days · 600 FCFA';

  @override
  String get marketBoost7 => '7 days · 1,300 FCFA';

  @override
  String get marketUseHonam => 'Medicines can\'t be sold on Assimé: use Honam.';

  @override
  String get honamMissingTitle => 'A product is missing';

  @override
  String honamMissingBody(String amount, String reason) {
    return '$amount is missing: $reason. What do you prefer?';
  }

  @override
  String get honamKeepRest => 'Receive the rest';

  @override
  String get honamCancelAll => 'Cancel everything';

  @override
  String get honamRefundDelay =>
      'The pharmacy refunds you within 2 hours, to the number that paid.';

  @override
  String get honamZones => 'Areas and hours (e.g. Bè, Tokoin — evenings)';

  @override
  String get honamWallet => 'Wallet number that receives ride payments';

  @override
  String get honamRules =>
      'I accept the golden rules: I hand over the parcel only against the code, I don\'t look at prescriptions, I stay polite.';

  @override
  String get honamApply => 'Send my application';

  @override
  String get honamPending =>
      'Application sent: the Pokou team is reviewing it.';

  @override
  String get honamLaunch =>
      'Launch period: you deliver without membership or pack.';

  @override
  String get honamQueenLocked =>
      'Queen Pokou unlocks after a month without delivery failures.';

  @override
  String koryDeclaredTotal(String amount) {
    return 'Declared total: $amount';
  }

  @override
  String koryRemaining(String amount) {
    return 'Left to collect: $amount';
  }

  @override
  String get onbBabaWelcome =>
      'Welcome to Pokou! I\'m Baba, the app\'s assistant. What should your loved ones call you?';

  @override
  String get onbContactsTitle => 'Find your loved ones';

  @override
  String get onbContactsBody =>
      'I can look for which of your contacts are already on Pokou. Their numbers are compared without your address book being kept. You can change your mind in Privacy.';

  @override
  String get onbContactsAllow => 'Yes, find them';

  @override
  String get onbLater => 'Later';

  @override
  String get proofModeDirectHint =>
      'Everything written stays provable: a deleted message stays struck through, an edit keeps the original. Only you will be able to turn it off.';

  @override
  String get proofDisableReservedDirect =>
      'Only the person who turned on proof mode can turn it off.';

  @override
  String get proofExportMe => 'Me';

  @override
  String get proofExportTitle => 'Pokou — proof mode export';

  @override
  String proofExportBetween(String me, String contact) {
    return 'Conversation between $me and $contact';
  }

  @override
  String proofExportPeriod(String since, String now) {
    return 'Proof mode on since $since · exported on $now from this phone';
  }

  @override
  String proofExportFooter(String page, String pages) {
    return 'Page $page of $pages — produced on the device: the Pokou server has no access to encrypted messages.';
  }

  @override
  String get proofExportAttachment => '[attachment]';

  @override
  String proofExportEdited(String at) {
    return 'Edited on $at';
  }

  @override
  String proofExportDeleted(String at) {
    return 'Deleted on $at, kept by proof mode';
  }

  @override
  String get proTitle => 'Pokou certified Pro';

  @override
  String get proTeaser => 'For a business: trade name and “Managed by”';

  @override
  String get proPitch =>
      'Your trade name shows first, with “Managed by” and your verified name. The Pro profile will host your Assimé listings.';

  @override
  String proSteps(String hours) {
    return '1. You send your proof. 2. Support checks it within $hours h. 3. You only pay after approval.';
  }

  @override
  String proPending(String due) {
    return 'Verification in progress. Answer by $due at the latest.';
  }

  @override
  String get proApproved =>
      'Proof approved: you can activate Pokou certified Pro.';

  @override
  String get proPay => 'Pay for Pokou certified Pro';

  @override
  String get proCorrection => 'Proof needs correcting';

  @override
  String get proRejected => 'Application declined';

  @override
  String get proActivity => 'Your business';

  @override
  String get proBusinessName => 'Trade name';

  @override
  String get proActivityField => 'Activity (tailoring, shop, transport…)';

  @override
  String get proDocument => 'Add the proof document';

  @override
  String get proDocumentChosen => 'Document added — tap to change';

  @override
  String get proDocumentNote =>
      'Trade register, professional card or business licence. Seen by support only, never displayed.';

  @override
  String get proSend => 'Send for verification';

  @override
  String proManagedBy(String name) {
    return 'Managed by $name';
  }

  @override
  String get proProfileNote => 'This is how others see your Pro profile.';

  @override
  String get actionDone => 'Done';

  @override
  String get badgeProLabel => 'Pokou certified Pro';

  @override
  String get certAdvantageNameTitle => 'A verified name';

  @override
  String get certAdvantageNameBody =>
      'Your badge shows you are really you, thanks to the mobile money wallet that pays.';

  @override
  String get certAdvantageProofTitle => 'Proof mode';

  @override
  String get certAdvantageProofBody =>
      'In a conversation, deleted messages stay visible, struck through, for everyone.';

  @override
  String get certAdvantageExportTitle => 'Dated export';

  @override
  String get certAdvantageExportBody =>
      'Keep a conversation as a PDF, with dates and times.';

  @override
  String get certFormulaLabel => 'Plan';

  @override
  String get certMonthlyLabel => 'Monthly';

  @override
  String get certYearlyLabel => 'Yearly';

  @override
  String certMonthsOffered(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months free',
      two: 'Two months free',
      one: 'One month free',
    );
    return '$_temp0';
  }

  @override
  String certTtcPerMonth(String amount) {
    return '$amount incl. VAT per month';
  }

  @override
  String certTtcPerYear(String amount) {
    return '$amount incl. VAT per year';
  }

  @override
  String get certSeeProOffer => 'Professional? See Pokou certified Pro';

  @override
  String get certPayNowShowBadge => 'Pay now and show my badge';

  @override
  String get certPayTitle => 'Verify and pay';

  @override
  String get certNameFieldLabel => 'First and last name, as on your ID';

  @override
  String get certNameFieldHelp =>
      'Pokou compares it with the wallet holder\'s name, already verified by your operator. This name will be shown with your badge.';

  @override
  String get certPayWith => 'Pay with';

  @override
  String get certOwnWallet => 'This number\'s wallet';

  @override
  String get certOtherWallet => 'Another wallet';

  @override
  String get certOtherWalletHint => 'Wallet number';

  @override
  String certVatLabel(String rate) {
    return 'VAT $rate%';
  }

  @override
  String get certTotalLabel => 'Total';

  @override
  String get certPaymentNote =>
      'Payment by CashPay. Invoice available in your account.';

  @override
  String certVerifyAndPay(String amount) {
    return 'Verify and pay $amount';
  }

  @override
  String get certMismatchAlertBody =>
      'The name of this wallet\'s holder doesn\'t match your name. Correct your name or pay from your own wallet.';

  @override
  String get certNameNeverShown =>
      'The holder\'s name is never shown. Your trial and proof mode carry on in the meantime.';

  @override
  String get certBadgeActiveTitle => 'Your badge is active';

  @override
  String get certBadgeActiveBody => 'Your contacts now see your verified name.';

  @override
  String certNameVerifiedBy(String operator) {
    return 'Name verified by $operator';
  }

  @override
  String get certNextPaymentLabel => 'Next payment';

  @override
  String get certDownloadInvoice => 'Download the invoice';

  @override
  String get proofModeActivatesAnywhere =>
      'Proof mode can be turned on in any of your chats, one-to-one or group.';

  @override
  String certTrialEndingTitle(String days, String date) {
    return 'Your trial ends in $days days, on $date.';
  }

  @override
  String get certIfYouPay => 'If you pay';

  @override
  String get certIfYouPayBadge =>
      'Your badge shows, your name is verified by your wallet';

  @override
  String get certIfYouPayProof => 'Proof mode and dated export carry on';

  @override
  String get certWithoutPayment => 'Without payment';

  @override
  String get certWithoutPaymentActivate =>
      'You can no longer turn on proof mode in a new chat';

  @override
  String get certWithoutPaymentTraces =>
      'What has already been recorded stays visible to everyone';

  @override
  String get certPayAndShowBadge => 'Pay and show my badge';

  @override
  String get certLater => 'Later';

  @override
  String get certPausedScreenTitle => 'Badge paused';

  @override
  String get proofLearnMore => 'Learn more';

  @override
  String get proofLearnMoreBody =>
      'Proof mode is never hidden: a system message announces it and a banner stays at the top of the chat. A message deleted by its author stays visible, struck through, for everyone, with the deletion time; an edited message keeps its original version. The record stays with the other participants even if someone deletes the chat, leaves the group or changes phone. You can export the chat as a dated PDF.';

  @override
  String get proofDirectHeaderSubtitle => 'One-to-one chat · proof mode on';

  @override
  String proofGroupHeaderSubtitle(String count) {
    return '$count members · proof mode on';
  }

  @override
  String get proofActivateTitle => 'Turn on proof mode?';

  @override
  String proofActivateGroupBody(String name, String count) {
    return 'In “$name”, a message deleted by its author will stay visible, struck through, for the $count members, with the deletion time.';
  }

  @override
  String proofActivateGroupBodyAll(String name) {
    return 'In “$name”, a message deleted by its author will stay visible, struck through, for all members, with the deletion time.';
  }

  @override
  String proofActivateDirectBody(String name) {
    return 'In your chat with $name, a message deleted by its author will stay visible, struck through, for both of you, with the deletion time.';
  }

  @override
  String get proofActivateBulletGroupNotice =>
      'All members are told: a message in the group and a permanent banner.';

  @override
  String proofActivateBulletDirectNotice(String name) {
    return '$name is told: a message in the chat and a permanent banner.';
  }

  @override
  String get proofActivateBulletFromNow =>
      'Only messages sent from now on are covered.';

  @override
  String get proofActivateBulletCanDisable =>
      'You can turn it off; messages sent while it was on keep the rule.';

  @override
  String get proofDeactivateTitle => 'Turn off proof mode?';

  @override
  String get proofDeactivateBulletNotice =>
      'Participants are told by a message in the chat.';

  @override
  String get proofDeactivateBulletKeepsRule =>
      'Messages sent while it was on keep the rule: their original version stays visible.';

  @override
  String get proofDeactivateBulletReenable =>
      'You can turn it back on whenever you like.';

  @override
  String get proofKeepMode => 'Keep proof mode';

  @override
  String get proofReservedTitle => 'Turn off proof mode';

  @override
  String get proofReservedBody =>
      'In a group, it can be turned off by the person who turned it on or by an admin with a paid badge, Pokou certified or Pro. The trial isn\'t enough.';

  @override
  String get proofReservedYourBadge => 'Your badge';

  @override
  String get proofReservedLevelRequired => 'Required level';

  @override
  String get proofReservedPaidBadge => 'Paid badge';

  @override
  String get proofReservedTrial => 'Trial';

  @override
  String get proofReservedNote =>
      'Payment verifies your name and shows your badge; you can then turn off proof mode. Traders and associations can choose Pokou certified Pro.';

  @override
  String get proofDeleteTitle => 'Delete this message?';

  @override
  String get proofDeleteWarningTitle => 'Proof mode is on.';

  @override
  String get proofDeleteForMeOnly => 'Delete for me only';

  @override
  String proofBannerBy(String name) {
    return 'Proof mode turned on by $name.';
  }

  @override
  String get proofBannerRule =>
      'Deleted messages stay visible, struck through, for everyone.';

  @override
  String get proofChooseDiscussion => 'Choose a chat';

  @override
  String get proofChooseDiscussionNote =>
      'With your badge, proof mode can be turned on in any chat: one-to-one or group, whether or not you\'re an admin. Participants are always told.';

  @override
  String get proofSearchDiscussion => 'Search a chat';

  @override
  String get proofDirectSubtitle => 'One-to-one chat';

  @override
  String get proofGroupSubtitle => 'Group';

  @override
  String proofActivatedFor(String name) {
    return 'Proof mode on in “$name”';
  }

  @override
  String get proofExportOptionsTitle => 'Export the chat';

  @override
  String get proofExportPeriodLabel => 'Period';

  @override
  String get proofExportSinceActivation => 'Since proof mode was turned on';

  @override
  String get proofExportAllDiscussion => 'The whole chat';

  @override
  String get proofExportCustomDates => 'Choose dates';

  @override
  String get proofIncludeMedia => 'Include photos and documents';

  @override
  String get proofIncludeMediaNote => 'The PDF will be larger';

  @override
  String get proofExportContains => 'The PDF contains';

  @override
  String get proofExportContainsDates => 'Date and time of each message';

  @override
  String get proofExportContainsDeleted =>
      'Deleted or edited messages, with their original version';

  @override
  String get proofExportContainsHash => 'File integrity fingerprint (SHA-256)';

  @override
  String get proofExportLegalNote =>
      'The PDF is created on your phone; Pokou keeps no copy. Its legal value is for the judge to assess.';

  @override
  String get proofCreatePdf => 'Create the PDF';

  @override
  String get proofReadyTitle => 'PDF ready';

  @override
  String proofReadySubtitle(String name, String size) {
    return '$name · $size KB';
  }

  @override
  String get proofReadyPreviewNote =>
      'The PDF lists each message with its date and time, deleted messages struck through and original versions.';

  @override
  String get proofIntegrityHash => 'Integrity fingerprint (SHA-256)';

  @override
  String get proofIntegrityNote =>
      'Keep the file as is: the slightest change alters the fingerprint.';

  @override
  String get proOfferTitle => 'For traders and organisations';

  @override
  String get proOfferAudience => 'Traders, sellers, businesses, associations';

  @override
  String get proOfferPointName =>
      'Your verified trading name, with the Pro badge';

  @override
  String get proOfferPointProfile =>
      'A Pro profile: address, opening hours, activity';

  @override
  String get proOfferPointBadge =>
      'The Pro badge on your statuses, then on your Assimé listings';

  @override
  String get proOfferPointBadgeLot1 =>
      'The Pro badge on your profile and statuses';

  @override
  String get proOfferPointProof =>
      'Proof mode and dated export, like Pokou certified';

  @override
  String get proPerMonth => 'per month';

  @override
  String proPriceTtcCancel(String amount) {
    return '$amount incl. VAT · cancel any time';
  }

  @override
  String get proHowItWorks => 'How it works';

  @override
  String get proStepSendTitle => 'Send your proof document';

  @override
  String get proStepSendBody => 'RCCM, NIF or association receipt';

  @override
  String proStepCheckTitle(String hours) {
    return 'Pokou checks within $hours h';
  }

  @override
  String get proStepCheckBody => 'You\'re told as soon as it\'s decided';

  @override
  String get proStepPayTitle => 'You pay and your badge shows';

  @override
  String get proStepPayBody => 'No payment before approval';

  @override
  String get proStart => 'Start';

  @override
  String proStepOf(String step) {
    return 'Pokou certified Pro · step $step of 3';
  }

  @override
  String get proActivityLabel => 'Activity';

  @override
  String get proAddressLabel => 'Address or landmark';

  @override
  String get proDocumentLabel => 'Proof document';

  @override
  String get proDocRccm => 'RCCM';

  @override
  String get proDocNif => 'NIF';

  @override
  String get proDocRecepisse => 'Receipt';

  @override
  String proDocumentSize(String size) {
    return 'Photo · $size MB';
  }

  @override
  String get proChange => 'Change';

  @override
  String get proDocumentNameNote =>
      'The trading name must appear on the document. Your verified name stays visible under the trading name: “Managed by…”.';

  @override
  String get proPendingTitle => 'Verification in progress';

  @override
  String proPendingBody(String hours) {
    return 'Pokou support checks your document within $hours h. You get a notification as soon as it\'s decided.';
  }

  @override
  String get proStepSent => 'Document sent';

  @override
  String get proStepSupport => 'Check by support';

  @override
  String proAtTheLatest(String date) {
    return 'By $date at the latest';
  }

  @override
  String get proStepPayBadge => 'Payment and Pro badge';

  @override
  String get proAfterValidation => 'After approval';

  @override
  String get proPendingKeep =>
      'Meanwhile, you keep your Pokou certified badge, your chats and proof mode.';

  @override
  String get proNameMismatchTitle => 'The name doesn\'t match';

  @override
  String get proWhatToDo => 'What do you want to do?';

  @override
  String proUseDocumentName(String name) {
    return 'Use “$name”';
  }

  @override
  String proNameOnDocument(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'NIF': 'The name on your NIF',
      'RECEPISSE': 'The name on your receipt',
      'other': 'The name on your RCCM',
    });
    return '$_temp0';
  }

  @override
  String get proSendOtherDocument => 'Send another document';

  @override
  String get proNoPaymentTaken =>
      'No payment has been taken. You can resend as many times as needed.';

  @override
  String get proCorrectAndResend => 'Correct and resend';

  @override
  String get proContactSupport => 'Contact support';

  @override
  String get proSupportHint =>
      'Reply to the decision notification: it reaches support.';

  @override
  String proGoodNews(String name) {
    return 'Good news: $name is verified.';
  }

  @override
  String proDocumentVerifiedBySupport(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'NIF': 'NIF verified by support',
      'RECEPISSE': 'Receipt verified by support',
      'other': 'RCCM verified by support',
    });
    return '$_temp0';
  }

  @override
  String get proNameShownAfterPayment =>
      'Your trading name shows as soon as you pay';

  @override
  String get proReplacesCertified =>
      'Your Pokou certified badge stops: the Pro badge replaces it, with no double payment.';

  @override
  String proPayTtc(String amount) {
    return 'Pay $amount incl. VAT';
  }

  @override
  String get proProfileTitle => 'Profile';

  @override
  String proManagedByVerified(String name) {
    return 'Managed by $name · verified name';
  }

  @override
  String get proDeclaredAddress => 'Declared address';

  @override
  String proHoursLine(String days, String open, String close) {
    return '$days, $open to $close';
  }

  @override
  String get proOpenNow => 'Open';

  @override
  String get proClosedNow => 'Closed';

  @override
  String proSinceDate(String date) {
    return 'Pokou certified Pro since $date';
  }

  @override
  String contactReport(String name) {
    return 'Report $name';
  }

  @override
  String get contactReportReasonHint => 'What\'s wrong';

  @override
  String get contactReportSend => 'Report';

  @override
  String get contactReportSent => 'Report sent to the Pokou team.';

  @override
  String get honamCity => 'City';

  @override
  String get honamOtherCity => 'Another city';

  @override
  String get honamYourCity => 'Your city';

  @override
  String get honamNotServed =>
      'Honam doesn\'t deliver in this city yet. Sign up: we\'ll let you know when it opens.';

  @override
  String get honamJoinWaitlist => 'Join the waiting list';

  @override
  String honamWaitlistDone(String city) {
    return 'On the list for $city';
  }

  @override
  String get honamWaitlistBody =>
      'We\'ll tell you as soon as Honam delivers in your city. Nothing else.';

  @override
  String get honamReferralCodeField => 'Referral code (optional)';

  @override
  String get honamReferralTitle => 'Invite a courier';

  @override
  String honamReferralBody(String rides) {
    return '$rides free rides when your referral completes their first delivery.';
  }

  @override
  String get honamReferralShare => 'Share my code';

  @override
  String honamReferralMessage(String code) {
    return 'Deliver for Honam with Pokou: use my referral code $code in courier mode.';
  }

  @override
  String honamReferralCount(String count) {
    return 'Referrals: $count';
  }

  @override
  String get honamTrialEnded => 'Your trial is over';

  @override
  String honamRecommendedPack(String pack) {
    return 'Based on this month\'s rides, the $pack pack is enough for you.';
  }

  @override
  String get honamNavigate => 'Directions in my maps app';

  @override
  String get honamLocationShared =>
      'Your location is shared every 15 s during the ride, never after.';

  @override
  String get honamLocationDenied =>
      'Allow location so the patient can follow the delivery.';

  @override
  String get honamCourier => 'the courier';

  @override
  String honamTrackingTitle(String name) {
    return '$name is on the way';
  }

  @override
  String get honamTrackingWaiting => 'Location not received yet.';

  @override
  String honamTrackingDistance(String km) {
    return '$km km from you';
  }

  @override
  String honamTrackingUpdated(String minutes) {
    return 'Updated $minutes min ago';
  }

  @override
  String get honamTrackingStale => 'Location not up to date';

  @override
  String get honamTrackingShowMap => 'Show the map';

  @override
  String get honamTrackingMapDataSaver => 'Show on the map (uses data)';

  @override
  String get assimeFavoritesAlerts => 'Favourites and alerts';

  @override
  String get assimeFavorites => 'Favourites';

  @override
  String get assimeAlerts => 'Alerts';

  @override
  String get assimeNoFavorites => 'No favourites';

  @override
  String get assimeFavoritesHint =>
      'Tap the heart on a listing to keep it here.';

  @override
  String get assimeAddFavorite => 'Add to favourites';

  @override
  String get assimeRemoveFavorite => 'Remove from favourites';

  @override
  String get assimeNewAlert => 'New alert';

  @override
  String get assimeAlertQuery => 'What you\'re looking for';

  @override
  String get assimeAlertMaxPrice => 'Maximum price (optional)';

  @override
  String get assimeAlertNote =>
      'We\'ll notify you when a listing matches. The alert only reads listings, never your messages.';

  @override
  String get assimeNoAlerts => 'No alerts yet.';

  @override
  String assimeAlertUpTo(String price) {
    return 'up to $price FCFA';
  }

  @override
  String assimeAlertMatches(String count) {
    return '$count listing(s) found';
  }

  @override
  String get assimeSponsored => 'Sponsored';

  @override
  String get assimeWhyTitle => 'Why am I seeing this ad?';

  @override
  String get assimeWhyNotSponsored => 'This listing is no longer promoted.';

  @override
  String get assimeReportTitle => 'Promotion report';

  @override
  String get assimeReportEmpty => 'No promotion for this listing yet.';

  @override
  String assimeReportPeriod(String days, String start, String end) {
    return '$days days · $start to $end';
  }

  @override
  String assimeReportImpressions(String count) {
    return 'Shown at the top of results: $count times';
  }

  @override
  String assimeReportStatusViews(String count) {
    return 'Seen in statuses: $count times';
  }

  @override
  String assimeReportContacts(String count) {
    return 'People who contacted you: $count';
  }

  @override
  String get assimeStatusPending => 'Status spot: under moderation review';

  @override
  String get assimeStatusRejected => 'Status spot declined by moderation';

  @override
  String get koryKindTontine => 'Tontine';

  @override
  String get koryFieldStake => 'Each member\'s stake per round (FCFA)';

  @override
  String get koryRotation => 'Order of rounds';

  @override
  String get koryRotationHint =>
      'Drag to reorder. The order is fixed at opening and won\'t change.';

  @override
  String get koryRemoveFromRotation => 'Remove from the tontine';

  @override
  String get koryNeedRotation => 'A tontine needs at least two participants.';

  @override
  String get koryTontineNote =>
      'Each round, everyone sends their stake to the beneficiary\'s wallet, who confirms what they received. Pokou never touches the money.';

  @override
  String get koryRounds => 'Rounds';

  @override
  String koryRoundNumber(String number) {
    return 'Round $number';
  }

  @override
  String koryRoundConfirmed(String confirmed, String expected) {
    return '$confirmed confirmed of $expected';
  }

  @override
  String get koryNextRound => 'Move to the next round';

  @override
  String get koryNextRoundBody =>
      'The current round ends. Contributions already declared remain to be confirmed by its beneficiary.';

  @override
  String get koryLastRoundBody =>
      'That was the last round: the tontine will be closed. The log stays available.';

  @override
  String get welcomeStart => 'Get started';

  @override
  String get authAcceptAndContinue => 'Accept and continue';

  @override
  String get authAcceptNotice =>
      'By tapping “Accept and continue”, you accept the terms of use and the privacy policy, and confirm you are old enough.';

  @override
  String get deleteAccountTitle => 'Delete my account';

  @override
  String get deleteAccountWarning => 'This action is permanent.';

  @override
  String get deleteAccountRemovedTitle => 'What is deleted';

  @override
  String get deleteAccountRemovedProfile => 'Your profile, photo and backup';

  @override
  String get deleteAccountRemovedChats => 'Your chats on this phone';

  @override
  String get deleteAccountRemovedBadge =>
      'Your badge, with no refund for the current month';

  @override
  String get deleteAccountKeptTitle => 'What remains';

  @override
  String get deleteAccountKeptMessages =>
      'Messages your contacts have already received';

  @override
  String get deleteAccountKeptProof =>
      'Proof mode records held by other participants';

  @override
  String get deleteAccountKeptKory =>
      'The Kory pot log, which cannot be erased';

  @override
  String get deleteAccountConfirmLabel => 'Confirm your number';

  @override
  String get deleteAccountMismatch =>
      'This number doesn\'t match your account.';

  @override
  String get deleteAccountFailed => 'Deletion failed. Try again.';

  @override
  String get helpTitle => 'Help and support';

  @override
  String get helpSearchHint => 'Search help';

  @override
  String get helpAskBaba => 'Ask Baba';

  @override
  String get helpAskBabaSub => 'The AI assistant answers right away';

  @override
  String get helpFaqTitle => 'Frequently asked questions';

  @override
  String get helpQMoney => 'Does Pokou handle my money?';

  @override
  String get helpAMoney =>
      'No. Pots, pharmacies and couriers are paid wallet to wallet. Pokou never holds your money.';

  @override
  String get helpQProof => 'How does proof mode work?';

  @override
  String get helpAProof =>
      'Turned on by a Pokou certified holder, it keeps deleted or edited messages visible, struck through. It is always shown at the top of the chat.';

  @override
  String get helpQSms => 'I don\'t receive the SMS code';

  @override
  String get helpASms =>
      'Check the number and network, then wait for the countdown to request a new code. Pokou will never ask you for this code, by message or call.';

  @override
  String get helpQCourier => 'How do I become a Honam courier?';

  @override
  String get helpACourier =>
      'In More, tap “Become a Honam courier”: identity, zones, wallet and golden rules. Honam opens city by city.';

  @override
  String get helpQScam => 'How do I spot a scam?';

  @override
  String get helpAScam =>
      'Beware of anyone asking for an SMS code, your PIN or an urgent payment. Pokou never does. Block and report the contact.';

  @override
  String get helpSupport => 'Contact support';

  @override
  String get helpSupportSub => 'Answer in the app';

  @override
  String get helpReport => 'Report a problem';

  @override
  String get helpNoResult => 'No matching question. Ask Baba.';

  @override
  String get aboutTitle => 'About Pokou';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutNamesTitle => 'What our names mean';

  @override
  String get aboutPokou => 'a Baoulé name';

  @override
  String get aboutKory => 'the cowrie shell';

  @override
  String get aboutHonam => '“help me”, in Ewe';

  @override
  String get aboutAssime => '“at the market”, in Ewe';

  @override
  String get aboutWetri => '“month”, in Ewe';

  @override
  String get aboutEpe => '“year”, in Ewe';

  @override
  String get aboutNextNames =>
      'Our next services will also carry names from African languages.';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get legalEssentials => 'The essentials';

  @override
  String get legalFullText => 'Full text';

  @override
  String get termsE1 =>
      'Pokou never handles money: pots, pharmacies and couriers are paid wallet to wallet.';

  @override
  String get termsE2 =>
      'Proof mode keeps a record of deleted messages, and this is always shown.';

  @override
  String get termsE3 => 'Honam is not an emergency service.';

  @override
  String get termsE4 => 'Paid badges can be cancelled at any time.';

  @override
  String get privacyE1 =>
      'Your number is never shown to a seller or a courier.';

  @override
  String get privacyE2 =>
      'Pokou doesn\'t read your messages. A report only sends the last 5 to support.';

  @override
  String get privacyE3 => 'The courier\'s location is not kept after delivery.';

  @override
  String get privacyE4 =>
      'Sponsored ads are targeted by city, never from your messages.';

  @override
  String get languageNote =>
      'The app language doesn\'t change the language of your messages. The names Pokou, Kory, Honam and Assimé stay the same in every language.';

  @override
  String get securityPinWarning =>
      'Pokou will never ask for your PIN or the SMS code, by message or by call.';

  @override
  String get statusReplyPrivate =>
      'Your reply arrives privately, in your one-to-one chat.';

  @override
  String get statusViewersNote =>
      'Only you see this list. Replies arrive privately, in your chats.';

  @override
  String get statusWhoSees => 'Who sees my statuses';

  @override
  String get attachCompressNote =>
      'Photos and videos are compressed before sending to save your data.';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String get pinForgot => 'Forgot your PIN?';

  @override
  String get pinTitle => 'Your PIN';

  @override
  String statusReplyHint(String name) {
    return 'Reply to $name…';
  }

  @override
  String get statusReplyQuote => '↩ Replying to your status';

  @override
  String get statusReplySent => 'Reply sent privately.';

  @override
  String get changeNumberTitle => 'Change number';

  @override
  String get changeNumberOld => 'Old number';

  @override
  String get changeNumberNew => 'New number';

  @override
  String get changeNumberNotify => 'Notify my contacts';

  @override
  String get changeNumberNotifyAll => 'All my contacts';

  @override
  String get changeNumberNotifyChatted => 'People I\'ve chatted with';

  @override
  String get changeNumberNotifyNone => 'Nobody';

  @override
  String get changeNumberNotifyNoneSub => 'Your groups are always notified';

  @override
  String get changeNumberInfo =>
      'Your account, chats, Pokou certified badge and Kory pots follow you. A code is sent to the new number.';

  @override
  String get changeNumberKoryWarning =>
      'If you collect a pot, your collection number doesn\'t change by itself: update it in Kory, members will be notified.';

  @override
  String get changeNumberSendCode => 'Send the code';

  @override
  String get changeNumberCodeLabel => 'Code received by SMS';

  @override
  String get changeNumberConfirm => 'Confirm the change';

  @override
  String get changeNumberDone => 'Your number has been changed.';

  @override
  String get pinForgotIntro => 'Two ways to get your account back:';

  @override
  String get pinForgotEmail => 'By email';

  @override
  String get pinForgotEmailSub =>
      'If you added an address: a reset link is sent to you';

  @override
  String get pinForgotWait => 'Wait 7 days';

  @override
  String get pinForgotWaitSub =>
      'Then you sign in without a PIN using the SMS code, as long as you keep your number';

  @override
  String get pinForgotWarning =>
      'The 7-day delay stops someone who stole your SIM card from taking your account right away.';

  @override
  String get pinForgotMeanwhile =>
      'While you wait, your contacts still see you and your messages wait for you.';

  @override
  String get pinForgotContinue => 'Continue';

  @override
  String pinForgotScheduled(String date) {
    return 'Noted. From $date, the SMS code will be enough to sign in.';
  }

  @override
  String get groupDelete => 'Delete group';

  @override
  String groupDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get groupDeleteBody =>
      'The group disappears for all its members, with its messages. This cannot be undone.';

  @override
  String get groupDeleteFailed => 'Couldn\'t delete — try again.';

  @override
  String get groupManageTitle => 'Manage group';

  @override
  String get groupManageSubtitle =>
      'Permissions, new members, disappearing messages';

  @override
  String get groupPermissions => 'Permissions';

  @override
  String get groupEditInfoSetting => 'Edit name and photo';

  @override
  String get groupSendSetting => 'Send messages';

  @override
  String get groupApproveSetting => 'Approve new members';

  @override
  String get groupApproveSettingSub => 'An admin approves each join by link';

  @override
  String get groupAllMembers => 'All members';

  @override
  String get groupDisappearing => 'Disappearing messages';

  @override
  String get groupDisappearingOff => 'Off';

  @override
  String get groupDisappearing24h => '24 hours';

  @override
  String get groupDisappearing7d => '7 days';

  @override
  String get groupDisappearing90d => '90 days';

  @override
  String get groupJoinRequests => 'Join requests';

  @override
  String get groupNoJoinRequest => 'No pending requests.';

  @override
  String get groupApprove => 'Approve';

  @override
  String get groupReject => 'Decline';

  @override
  String get groupJoinPending =>
      'Request sent: an admin must approve your entry.';

  @override
  String get groupSettingsSaveFailed => 'Setting not saved — try again.';

  @override
  String get groupLeaveKoryNote =>
      'Leaving the group doesn\'t delete the ongoing pot: your contributions stay in the Kory log.';

  @override
  String get messageWaiting => 'Waiting for this message…';

  @override
  String get callWaitingNotice =>
      'You\'re already on a call. Decline to keep it; accept to end it.';

  @override
  String get callEndAndAccept => 'End and accept';

  @override
  String get homeHelloOverline => 'Hello';

  @override
  String get koryOverline => 'Solidarity savings';

  @override
  String koryActiveCount(String count) {
    return '$count active';
  }

  @override
  String get searchIntro =>
      'Search your messages, channels and Assimé listings.';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get homeTagline => 'Everything that matters, in one place.';

  @override
  String get homeWhatToDo => 'What would you like to do?';

  @override
  String get homeInProgress => 'In progress';

  @override
  String get homeKoryPitch =>
      'Pool money together for a project, an event or a savings circle.';

  @override
  String get homeHonamPitch =>
      'Send your prescription and get quotes from nearby pharmacies.';

  @override
  String get homeAssimeTitle => 'Assimé';

  @override
  String get homeAssimeSubtitle => 'Classifieds';

  @override
  String get homeAssimePitch => 'Buy and sell near you, with confidence.';

  @override
  String get homeAssimeCta => 'Browse listings';

  @override
  String get koryPledgeTitle => 'I pledge';

  @override
  String koryPledgeSubtitleDue(Object date, Object title) {
    return '$title · closes on $date';
  }

  @override
  String get koryPledgeStart => 'Starting amount';

  @override
  String get koryPledgeDailyToggle => 'Add a daily amount';

  @override
  String get koryPledgeDailyToggleSub =>
      'Added to your pledge every day until closing';

  @override
  String get koryPledgePerDay => 'Amount per day';

  @override
  String get koryPledgeStartRow => 'Start';

  @override
  String koryPledgeDailyRow(Object amount, Object days) {
    return '$amount × $days days';
  }

  @override
  String koryPledgeTotalAt(Object date) {
    return 'Total pledged by $date';
  }

  @override
  String get koryPledgeEditableNotice =>
      'You can change your pledge for 8 hours. After that it becomes firm: it is recorded in the log and the collector sees it.';

  @override
  String get koryPledgeConfirm => 'Confirm my pledge';

  @override
  String get koryPledgeNeedDue => 'A daily amount needs an end date.';

  @override
  String get koryMyPledgeTitle => 'My pledge';

  @override
  String koryEditableFor(Object duration) {
    return 'Editable for $duration more';
  }

  @override
  String koryFirmToday(Object time) {
    return 'Becomes firm today at $time';
  }

  @override
  String koryFirmOn(Object date, Object time) {
    return 'Becomes firm on $date at $time';
  }

  @override
  String get koryDailyRow => 'Daily amount';

  @override
  String koryPerDay(Object amount) {
    return '$amount per day';
  }

  @override
  String get koryPledgeEdit => 'Edit my pledge';

  @override
  String get koryTimelineSaved => 'Pledge saved';

  @override
  String get koryTimelineEditable => 'Editable for 8 hours';

  @override
  String koryTimelineUntil(Object time) {
    return 'Until $time · the collector can’t see it yet';
  }

  @override
  String get koryTimelineFirm => 'Firm pledge';

  @override
  String get koryTimelineFirmSub =>
      'Recorded in the log, visible to the collector';

  @override
  String get koryPayNowOrLater =>
      'You can pay now or wait for closing: Pokou will remind you what remains to pay.';

  @override
  String get koryPayNow => 'Pay now';

  @override
  String koryFirmSince(Object date) {
    return 'Firm since $date';
  }

  @override
  String get koryPaidConfirmed => 'Paid and confirmed';

  @override
  String get koryRemainingToPay => 'Left to pay';

  @override
  String koryNextDailyAdd(Object amount) {
    return 'Next daily addition: tomorrow, +$amount';
  }

  @override
  String get koryFirmNotice =>
      'A firm pledge can no longer be changed. If something comes up, write to the collector: only they can cancel it, and it is recorded in the log.';

  @override
  String koryPayAmount(Object amount) {
    return 'Pay $amount';
  }

  @override
  String koryWriteTo(Object name) {
    return 'Write to $name';
  }

  @override
  String koryMyPledgeTotal(Object amount) {
    return 'Pledged: $amount';
  }

  @override
  String get koryContestedTitle => 'Disputed contribution';

  @override
  String koryContestedHead(Object name) {
    return '$name did not see your payment';
  }

  @override
  String koryContestedDeclared(Object amount, Object time) {
    return '$amount declared at $time';
  }

  @override
  String koryContestedReason(Object reason) {
    return 'Reason: “$reason”';
  }

  @override
  String get koryCheckReference => 'Check the reference';

  @override
  String get koryAddSmsCapture => 'Add a screenshot of the SMS';

  @override
  String get koryContestedOperatorNotice =>
      'If you sent it to another number, only your operator can recover the money: it never goes through Pokou.';

  @override
  String get koryResubmitted => 'Sent back to the collector to check again.';

  @override
  String get koryRejectReasonTitle => 'Why didn’t you receive it?';

  @override
  String get koryRejectReasonHint =>
      'E.g. Nothing received on my wallet at that time.';

  @override
  String get koryFinishTitle => 'End of the collection';

  @override
  String koryFinishSubtitle(Object title) {
    return '$title · collector’s view';
  }

  @override
  String get koryFinishDueNotice =>
      'The end date has been reached: it’s up to you to close or extend.';

  @override
  String get koryEngaged => 'Pledged';

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
  String get koryConfirmedLabel => 'Confirmed';

  @override
  String koryOnGoal(Object amount) {
    return 'of $amount';
  }

  @override
  String get koryToConfirmLabel => 'To confirm';

  @override
  String koryDeclarationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count declarations',
      one: '1 declaration',
    );
    return '$_temp0';
  }

  @override
  String get koryWhatDoYouDo => 'What will you do?';

  @override
  String get koryCloseCollect => 'Close the collection';

  @override
  String get koryCloseCollectSub =>
      'Everyone receives what they still have to pay, and the link to their wallet';

  @override
  String get koryExtend => 'Extend';

  @override
  String koryExtendSub(Object date) {
    return 'New end date: $date · pledges stay firm';
  }

  @override
  String get koryFinishJournalNote =>
      'Participants are notified. The log keeps the date and your choice.';

  @override
  String koryCloseAndNotify(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Close and notify the $count participants',
      one: 'Close and notify the participant',
    );
    return '$_temp0';
  }

  @override
  String koryExtendTo(Object date) {
    return 'Extend until $date';
  }

  @override
  String get koryFinishCta => 'Close or extend';

  @override
  String get koryClosedTitle => 'Collection closed';

  @override
  String koryClosedSubtitle(Object title) {
    return '$title · participant’s view';
  }

  @override
  String koryClosedBody(Object date, Object name) {
    return '$name closed the collection on $date. You still have to pay the rest of your pledge.';
  }

  @override
  String get koryAlreadyConfirmed => 'Already confirmed';

  @override
  String get koryToPay => 'To pay';

  @override
  String get korySendTo => 'Send to';

  @override
  String koryReferenceToGive(Object reference) {
    return 'Reference to include $reference';
  }

  @override
  String get koryCopyReference => 'Copy the reference';

  @override
  String koryPayFromWallet(Object amount) {
    return 'Pay $amount from my wallet';
  }

  @override
  String get koryAlreadySent => 'I’ve already sent it';

  @override
  String get notifCenterTitle => 'Notifications';

  @override
  String get notifReadAll => 'Mark all read';

  @override
  String get notifToday => 'Today';

  @override
  String get notifYesterday => 'Yesterday';

  @override
  String get notifEarlier => 'Earlier';

  @override
  String get notifMessagesElsewhere =>
      'Messages don’t appear here: they stay in Chats.';

  @override
  String get notifEmpty => 'No notifications yet.';

  @override
  String get notifServiceCertified => 'Pokou certified';

  @override
  String get notifSettings => 'Notification settings';

  @override
  String get certPausedTitle => 'Badge paused';

  @override
  String certPausedBody(Object days, Object due, Object since) {
    return 'The payment of $due didn’t go through. Your badge has been hidden since $since, after $days days of grace.';
  }

  @override
  String get certWhatRemains => 'What stays';

  @override
  String get certRemainsChats => 'Your chats and contacts';

  @override
  String get certRemainsTraces => 'The records already kept by proof mode';

  @override
  String get certWhatPaused => 'What is paused';

  @override
  String get certPausedBadge => 'The badge and the verified name';

  @override
  String get certPausedProof =>
      'Proof mode for new messages and the dated export';

  @override
  String get certPausedWallet =>
      'Payment is made from your wallet. If your balance was too low, top it up and try again.';

  @override
  String certPausedPay(Object amount) {
    return 'Pay $amount and show my badge again';
  }

  @override
  String get certChangePlan => 'Change plan';

  @override
  String get annSoldTitle => 'Mark as sold';

  @override
  String get annSoldWho =>
      'Who did you sell it to? This person will be able to rate the transaction.';

  @override
  String annSoldDiscussionOf(Object date) {
    return 'Chat of $date';
  }

  @override
  String get annSoldOutside => 'Someone outside Pokou';

  @override
  String get annSoldOutsideSub => 'No rating possible for this sale';

  @override
  String get annSoldFinalPrice => 'Final price';

  @override
  String get annSoldPriceHelp => 'Visible only to you and the buyer';

  @override
  String get annSoldConfirm => 'Confirm the sale';

  @override
  String get annSoldBadge => 'Sold';

  @override
  String get annSoldDone => 'Sale recorded.';

  @override
  String get annRateTitle => 'Rate the transaction';

  @override
  String get annRateHow => 'How did your transaction go?';

  @override
  String get annRate1 => 'Disappointing';

  @override
  String get annRate2 => 'Fair';

  @override
  String get annRate3 => 'Good';

  @override
  String get annRate4 => 'Very good';

  @override
  String get annRate5 => 'Excellent';

  @override
  String annRateStars(Object count) {
    return '$count stars out of 5';
  }

  @override
  String get annRateWentWell => 'What went well';

  @override
  String get annTagAsDescribed => 'As described';

  @override
  String get annTagPunctual => 'On time';

  @override
  String get annTagFairPrice => 'Price respected';

  @override
  String get annTagFriendly => 'Friendly';

  @override
  String get annTagCommunication => 'Good communication';

  @override
  String get annRateComment => 'Your review (optional)';

  @override
  String get annRateNotice =>
      'Your review shows your first name and the initial of your last name. Only a sale confirmed by the seller can be rated, once.';

  @override
  String get annRatePublish => 'Publish my review';

  @override
  String get annRatePublished => 'Thanks, your review is published.';

  @override
  String get annRateAlready => 'You’ve already rated this sale.';

  @override
  String annRateSubtitle(Object product, Object seller) {
    return '$seller · $product';
  }

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupWhere => 'Pokou, encrypted on your phone';

  @override
  String get backupLast => 'Last backup';

  @override
  String get backupContent => 'Content';

  @override
  String backupContentValue(num count, Object size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '1 chat',
    );
    return '$_temp0 · $size';
  }

  @override
  String get backupNever => 'Never';

  @override
  String get backupExplain =>
      'Your chats are encrypted on this phone with your password before being sent. Without it, nobody can read them, not even Pokou: keep it safe.';

  @override
  String get backupSetPassword => 'Choose a password';

  @override
  String get backupChangePassword => 'Change the password';

  @override
  String get backupPasswordLabel => 'Backup password';

  @override
  String get backupPasswordConfirm => 'Confirm the password';

  @override
  String get backupPasswordTooShort => 'At least 8 characters.';

  @override
  String get backupPasswordMismatch => 'The two passwords don’t match.';

  @override
  String get backupNow => 'Back up now';

  @override
  String get backupDone => 'Backup complete.';

  @override
  String get backupDaily => 'A backup is made every day when Pokou opens.';

  @override
  String get backupDelete => 'Delete the backup';

  @override
  String get backupFailed => 'The backup didn’t complete. Try again.';

  @override
  String welcomeBackBaba(Object name) {
    return 'Welcome back, $name! I found your account and your backup. Your groups, Kory pots and badge come with you.';
  }

  @override
  String get welcomeBackOrder =>
      'Chats and proof-mode state first; photos and videos afterwards, when you open each chat.';

  @override
  String get welcomeBackOldPhone => 'Your old phone will be signed out.';

  @override
  String get welcomeBackRestore => 'Restore';

  @override
  String get welcomeBackSkip => 'Continue without restoring';

  @override
  String get restoreWrongPassword => 'This password doesn’t match the backup.';

  @override
  String get restoreCardTitle => 'Restoring your chats';

  @override
  String restoreCardBody(Object done, Object total) {
    return '$done of $total chats. Photos and videos afterwards, when opened.';
  }

  @override
  String get restoreDone => 'Your chats are back.';

  @override
  String get koryParticipantsTitle => 'Participants';

  @override
  String koryStepOf(Object step, Object title, Object total) {
    return '$title · step $step of $total';
  }

  @override
  String get koryLastName => 'Last name';

  @override
  String get koryFirstName => 'First name';

  @override
  String get koryPhoneField => 'Number';

  @override
  String get koryAddParticipant => 'Add';

  @override
  String koryAddedCount(Object count) {
    return 'Added · $count';
  }

  @override
  String get koryFromContacts => 'From my contacts';

  @override
  String get koryOnPokou => 'On Pokou';

  @override
  String get koryInvitedChip => 'Invited';

  @override
  String get koryCollectorChip => 'Collector';

  @override
  String koryRemoveParticipant(Object name) {
    return 'Remove $name';
  }

  @override
  String get koryInviteNote =>
      'Without Pokou, the person gets an invitation SMS. They stay “Invited” until they sign up, then pledge like everyone else.';

  @override
  String koryContinueWith(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Continue with $count participants',
      one: 'Continue with 1 participant',
      zero: 'Continue without participants',
    );
    return '$_temp0';
  }

  @override
  String get koryInvalidPhone => 'This number isn’t valid.';

  @override
  String get storageManage => 'Manage storage';

  @override
  String get storageBigFiles => 'Files over 5 MB';

  @override
  String get storageAutoDownload => 'Automatic download';

  @override
  String get storageOnWifi => 'On Wi-Fi';

  @override
  String get autoDownloadNone => 'Nothing';

  @override
  String get autoDownloadPhotos => 'Photos';

  @override
  String get autoDownloadPhotosVideos => 'Photos and videos';

  @override
  String get autoDownloadAll => 'Everything';

  @override
  String get storageCallSaver => 'Save data during calls';

  @override
  String get storageCallSaverSub => 'Lower quality, more stable call';

  @override
  String storagePokouUses(Object size) {
    return 'Pokou · $size';
  }

  @override
  String get storageOtherDiscussion => 'Other files';

  @override
  String get callReconnecting => 'Reconnecting…';

  @override
  String get homeSearchEverything => 'Search a contact, a service, an ad';

  @override
  String get homeBabaTitle => 'Need a hand?';

  @override
  String get homeBabaSub => 'Ask Baba, he takes care of the rest.';

  @override
  String homeAlertsActive(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active alerts',
      one: '1 active alert',
    );
    return '$_temp0';
  }

  @override
  String homeSeeAllUnread(Object count) {
    return 'See all ($count unread)';
  }

  @override
  String get homeServicesSub =>
      'Simple services, designed for your everyday life.';

  @override
  String get homeKoryOverline => 'POTS & SAVINGS CIRCLES';

  @override
  String get homeHonamOverline => '“HELP ME”';

  @override
  String get homeAssimeOverline => '“AT THE MARKET”';

  @override
  String get homeTrustOverline => 'COMPLETE TRUST';

  @override
  String get homeTrustBody =>
      'Your data and conversations are end-to-end encrypted.';

  @override
  String get homeKoryInProgress => 'KORY • POT';

  @override
  String get homeHonamInProgress => 'HONAM • HEALTH';

  @override
  String get homeKoryNoMoney => 'Pokou never touches the money';

  @override
  String get discussionsStatusesNews => 'STATUSES';

  @override
  String get statusMyStatus => 'My status';

  @override
  String get babaAssistantChip => 'AI ASSISTANT';

  @override
  String get babaTranslate => 'Translate';

  @override
  String get babaSummarize => 'Summarize';

  @override
  String get babaAlwaysThere =>
      'Always here to translate, summarize or answer your questions.';

  @override
  String get koryHeadline => 'Kory · The cowrie';

  @override
  String get koryWalletChip => 'WALLET TO WALLET';

  @override
  String get koryNeverTouches =>
      'Pokou never touches your money. Contributions go directly from wallet to wallet, with no intermediary.';

  @override
  String get koryMonthActivity => 'THIS MONTH’S ACTIVITY';

  @override
  String get backupDestTitle => 'Where to back up';

  @override
  String get backupDestDrive => 'Google Drive';

  @override
  String get backupDestDriveSub =>
      'On your Google account, in a hidden folder only Pokou can read';

  @override
  String get backupDestPokou => 'Pokou';

  @override
  String get backupGoogleAccount => 'Google account';

  @override
  String get backupChangeAccount => 'Change account';

  @override
  String get backupNoAccount => 'No account chosen';

  @override
  String backupWhereDrive(Object email) {
    return 'Google Drive · $email';
  }

  @override
  String get restoreFindDrive => 'Find my Google Drive backup';

  @override
  String get restoreNoDrive => 'No Pokou backup on this Google account.';

  @override
  String get restoreWelcomeNoBackup =>
      'Welcome back! If you backed up your chats to Google Drive, find them here.';

  @override
  String get marketPriceInvalid =>
      'This price is not valid. Enter just the amount, for example 5000.';

  @override
  String get marketPublishFailed =>
      'The listing could not be published. Nothing is lost: check your connection and try again.';

  @override
  String get statusChangeFont => 'Change font';

  @override
  String get statusChangeBackground => 'Change background';

  @override
  String statusBackgroundNumber(String number) {
    return 'Background $number';
  }

  @override
  String get statusVisible24h =>
      'Visible for 24 hours to the contacts you chose.';

  @override
  String homeUnreadSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get homeServicesTitle => 'Services';

  @override
  String get homeKoryShort => 'Group pots and tontines';

  @override
  String get homeHonamShort => 'Your medicines delivered';

  @override
  String get homeAssimeShort => 'Buy and sell near you';

  @override
  String homeDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
      zero: 'Due today',
    );
    return '$_temp0';
  }

  @override
  String get emojiNoRecents => 'Your recent emojis will appear here.';

  @override
  String get emojiSearchHint => 'Search emoji';

  @override
  String get composerBackspace => 'Delete';

  @override
  String get messageCopy => 'Copy';

  @override
  String get messageCopied => 'Message copied';

  @override
  String get messageSelectText => 'Select text';

  @override
  String get messageSelectHint =>
      'Long-press a word to select it, then drag to extend.';

  @override
  String get messageCopyAll => 'Copy all';

  @override
  String get honamUiFilterToReceive => 'To receive';

  @override
  String get honamUiFilterCompleted => 'Completed';

  @override
  String get honamUiFilterCancelled => 'Cancelled';

  @override
  String honamUiInProgressCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders in progress',
      one: '1 order in progress',
    );
    return '$_temp0';
  }

  @override
  String honamUiOrderNo(String id) {
    return 'No. $id';
  }

  @override
  String get honamUiPrescription => 'Prescription';

  @override
  String get honamUiQuotePending => 'Quote pending';

  @override
  String get honamUiQuotePendingBody =>
      'The pharmacist has not sent a quote yet.';

  @override
  String honamUiItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get honamUiSeeMore => 'See more';

  @override
  String get honamUiSeeLess => 'See less';

  @override
  String get honamUiSeeOrder => 'View order';

  @override
  String honamUiDateAt(String date, String time) {
    return '$date at $time';
  }

  @override
  String honamUiSubmittedOn(String date) {
    return 'Sent on $date';
  }

  @override
  String honamUiQuotedOn(String date) {
    return 'Quote received on $date';
  }

  @override
  String honamUiDeliveredOn(String date) {
    return 'Delivered on $date';
  }

  @override
  String honamUiRejectedOn(String date) {
    return 'Refused on $date';
  }

  @override
  String honamUiExpiredOn(String date) {
    return 'Quote expired on $date';
  }

  @override
  String honamUiCancelledOn(String date) {
    return 'Cancelled on $date';
  }

  @override
  String honamUiStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get honamUiEmptyTitle => 'No orders';

  @override
  String get honamUiEmptyBody =>
      'Take a photo of your prescription: a nearby pharmacy sends you a quote, and a courier delivers.';

  @override
  String get honamUiEmptyCompleted => 'No completed order yet.';

  @override
  String get honamUiEmptyCancelled => 'No cancelled order.';

  @override
  String get honamUiOrdersError => 'Could not load your orders';

  @override
  String get honamUiPharmaciesError => 'Could not load pharmacies';

  @override
  String honamUiKm(String km) {
    return '$km km';
  }

  @override
  String honamUiCall(String name) {
    return 'Call $name';
  }

  @override
  String get honamUiSamu => 'Ambulance';

  @override
  String get honamUiFire => 'Fire brigade';

  @override
  String get honamUiPolice => 'Police';

  @override
  String get honamUiHeadSubmitted => 'Prescription sent';

  @override
  String get honamUiHelpSubmitted =>
      'The pharmacist is preparing your quote. We will let you know as soon as it arrives.';

  @override
  String get honamUiHeadQuoted => 'Your quote has arrived';

  @override
  String get honamUiHelpQuoted =>
      'Check the items and the total, then accept the quote.';

  @override
  String get honamUiHeadAccepted => 'Pay the pharmacy';

  @override
  String get honamUiHelpAccepted =>
      'Send the amount from your wallet, then confirm your payment.';

  @override
  String get honamUiHeadPaid => 'Order being prepared';

  @override
  String get honamUiHelpPaid =>
      'The pharmacy is preparing your parcel. Keep your handover code at hand.';

  @override
  String get honamUiHeadReady => 'Your parcel is ready';

  @override
  String get honamUiHelpReady =>
      'A courier is on the way to collect it from the pharmacy.';

  @override
  String get honamUiHeadInDelivery => 'Your order is on its way';

  @override
  String get honamUiHelpInDelivery =>
      'Give your code to the courier only once you have the parcel in hand.';

  @override
  String get honamUiHeadDelivered => 'Order delivered!';

  @override
  String get honamUiHelpDelivered =>
      'Thank you for ordering with Honam. Take care of yourself.';

  @override
  String get honamUiHeadRejected => 'Prescription refused';

  @override
  String get honamUiHelpRejected => 'You can send it to another pharmacy.';

  @override
  String get honamUiHeadExpired => 'Quote expired';

  @override
  String get honamUiHelpExpired =>
      'The quote was not accepted in time. You can send your prescription again.';

  @override
  String get honamUiHeadCancelled => 'Order cancelled';

  @override
  String get honamUiHelpCancelled => 'This order will not go any further.';

  @override
  String get honamUiDeliveryInfo => 'Delivery tracking';

  @override
  String get honamUiNoSteps => 'No step recorded yet.';

  @override
  String get honamUiItemsTitle => 'Items in order';

  @override
  String get honamUiOrderId => 'Order number';

  @override
  String get honamUiCopy => 'Copy';

  @override
  String get honamUiOrderIdCopied => 'Order number copied';

  @override
  String get honamUiOrderTime => 'Order placed';

  @override
  String get honamUiQuoteTime => 'Quote received';

  @override
  String get honamUiPaymentTime => 'Payment confirmed';

  @override
  String get honamUiShipTime => 'Courier departure';

  @override
  String get honamUiDeliveredTime => 'Parcel handed over';

  @override
  String get honamUiClosedTime => 'Order closed';

  @override
  String get honamUiPharmacy => 'Pharmacy';

  @override
  String get honamUiCourier => 'Courier';

  @override
  String get honamUiNoMessages => 'No message yet.';

  @override
  String get honamUiTrack => 'Track my order';

  @override
  String get honamUiRefundTitle => 'Refund';

  @override
  String honamUiUnitPrice(String price) {
    return '$price each';
  }

  @override
  String get koryHomeNewPot => 'New pot';

  @override
  String koryHomeActivePots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active pots',
      one: '1 active pot',
      zero: 'No active pot',
    );
    return '$_temp0';
  }

  @override
  String koryHomeCollected(String amount) {
    return '$amount raised';
  }

  @override
  String get koryHomeSearchHint => 'Find a pot';

  @override
  String get koryHomeSearchClear => 'Clear search';

  @override
  String get koryHomeFilterAll => 'All';

  @override
  String get koryHomeFilterCagnottes => 'Pots';

  @override
  String get koryHomeFilterCotisations => 'Contributions';

  @override
  String get koryHomeFilterTontines => 'Tontines';

  @override
  String get koryHomeFilterOpen => 'Ongoing';

  @override
  String get koryHomeFilterClosed => 'Closed';

  @override
  String get koryHomeFeatured => 'Featured';

  @override
  String koryHomeDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'Last day today',
    );
    return '$_temp0';
  }

  @override
  String get koryHomeOverdue => 'Past due date';

  @override
  String get koryHomeContribute => 'Contribute';

  @override
  String get koryHomeView => 'View';

  @override
  String koryHomeRoundOf(String current, String total) {
    return 'Round $current of $total';
  }

  @override
  String koryHomeBeneficiary(String name) {
    return 'Beneficiary: $name';
  }

  @override
  String get koryHomeNoMatch => 'No pot matches';

  @override
  String get koryHomeNoMatchBody => 'Try another name, or remove the filter.';

  @override
  String get koryHomeShowAll => 'Show all';

  @override
  String koryHomePercent(String percent) {
    return '$percent%';
  }

  @override
  String get groupClosedDeleted => 'This group was deleted.';

  @override
  String get groupClosedRemoved => 'You are no longer in this group.';

  @override
  String get statusVideoTooLong =>
      'Video too long: a status is limited to 60 seconds.';

  @override
  String get statusVideoLimitHint => 'Videos up to 60 seconds';

  @override
  String get homeAdLabel => 'Sponsored';

  @override
  String get homeAdCta => 'Find out more';

  @override
  String get homeBabaHello => 'Hi, I’m Baba.';

  @override
  String get homeBabaOffer => 'Tell me what you need and I’ll take care of it.';

  @override
  String get homeBabaCta => 'Talk to Baba';

  @override
  String get koryXAcceptInvite => 'Accept the invitation';

  @override
  String get koryXAcceptSwap => 'Accept the swap';

  @override
  String get koryXAccepted => 'Accepted';

  @override
  String koryXAcceptedOf(String accepted, String total) {
    return 'Accepted: $accepted of $total';
  }

  @override
  String get koryXAcceptedToast => 'Noted: you’re in the tontine.';

  @override
  String get koryXAddMemberHint =>
      'Add a member: they pay from the next due date';

  @override
  String koryXAdminOnly(String title) {
    return '$title · administrator only';
  }

  @override
  String koryXAdminWithDeputy(String admin, String deputy) {
    return '$admin · deputy $deputy';
  }

  @override
  String get koryXAdministrator => 'Administrator';

  @override
  String koryXAllAccepted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count members have accepted. The tontine is open.',
      one: 'The member has accepted. The tontine is open.',
    );
    return '$_temp0';
  }

  @override
  String get koryXAllGroupMembers => 'All members of the chat';

  @override
  String get koryXAllPaid => 'You’re up to date: nothing due for now.';

  @override
  String get koryXAmount => 'Amount';

  @override
  String get koryXAmountHidden => 'a hidden amount';

  @override
  String get koryXAmountLabel => 'Amount';

  @override
  String koryXAmountPer(String amount, String period) {
    return '$amount, $period';
  }

  @override
  String koryXAmountTo(String amount, String name) {
    return '$amount to $name';
  }

  @override
  String get koryXAmountsLabel => 'Individual amounts';

  @override
  String get koryXApproveSwap => 'Approve the swap';

  @override
  String get koryXBeneficiary => 'Beneficiary';

  @override
  String get koryXBeneficiaryField => 'Beneficiary (optional)';

  @override
  String get koryXCalendar => 'Round calendar';

  @override
  String koryXCalendarDay(String day) {
    return 'Round calendar · payout on day $day';
  }

  @override
  String get koryXCalendarUpdated => 'Swap approved: the calendar is updated.';

  @override
  String get koryXCancelled => 'Cancelled';

  @override
  String get koryXCancelledRounds => 'Cancelled rounds';

  @override
  String get koryXCaptureAdded => 'SMS screenshot added';

  @override
  String get koryXChangeAmount => 'Change the amount';

  @override
  String get koryXChangeCollector => 'Change collector';

  @override
  String get koryXChangeCollectorSub =>
      'A member of the contribution; everyone is notified';

  @override
  String get koryXCheckAndCreate => 'Check and create';

  @override
  String get koryXCheckWallet =>
      'Check in your wallet app or in the operator’s SMS. Every answer is time-stamped in the log.';

  @override
  String get koryXCheckWalletShort => 'Check your wallet, then answer';

  @override
  String get koryXChoose => 'Choose';

  @override
  String get koryXChooseMembers => 'Choose members';

  @override
  String get koryXChooseMembersSub =>
      'For example, only the adults in the group';

  @override
  String koryXClosesOn(String date) {
    return 'closes on $date';
  }

  @override
  String get koryXClosing => 'Closing date';

  @override
  String get koryXCoOrganizer => 'Co-organizer · confirms';

  @override
  String get koryXCollectType => 'Collection type';

  @override
  String get koryXCollectorLabel => 'Collector';

  @override
  String koryXCollectorWallet(String wallet) {
    return 'Collector · $wallet';
  }

  @override
  String koryXConcernedMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Members included · $count',
      one: 'Member included · 1',
    );
    return '$_temp0';
  }

  @override
  String get koryXConfirmReceipts => 'Confirm receipts';

  @override
  String koryXConfirmedOf(String done, String total) {
    return 'Confirmed: $done of $total';
  }

  @override
  String koryXConfirmedOnExpected(String expected) {
    return 'confirmed out of $expected expected';
  }

  @override
  String koryXConfirmedOnPlanned(String planned) {
    return 'confirmed out of $planned planned';
  }

  @override
  String koryXContestedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count disputed',
      one: '1 disputed',
    );
    return '$_temp0';
  }

  @override
  String get koryXContestedThenConfirmed => 'disputed, then confirmed';

  @override
  String get koryXContinue => 'Continue';

  @override
  String koryXContinueWithMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Continue with $count members',
      one: 'Continue with 1 member',
    );
    return '$_temp0';
  }

  @override
  String koryXContributeAmount(String amount) {
    return 'Contribute $amount';
  }

  @override
  String koryXContributionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributions',
      one: '1 contribution',
      zero: 'No contributions',
    );
    return '$_temp0';
  }

  @override
  String get koryXCotisationJournal => 'Contribution log';

  @override
  String get koryXCotisationStopped =>
      'This contribution has stopped. The log remains available.';

  @override
  String get koryXCreateCagnotte => 'Create the pot';

  @override
  String get koryXCreateCotisation => 'Create the contribution';

  @override
  String get koryXCsvAmount => 'Amount (FCFA)';

  @override
  String get koryXCsvDate => 'Date';

  @override
  String get koryXCsvEvent => 'Event';

  @override
  String get koryXCsvPerson => 'Person';

  @override
  String get koryXCsvReference => 'Reference';

  @override
  String get koryXCsvStatus => 'Status';

  @override
  String get koryXDeclared => 'Declared';

  @override
  String get koryXDeclaredLabel => 'Total declared';

  @override
  String koryXDeclaredUntil(String name) {
    return 'Your contribution stays “Declared” until $name confirms receiving it. You’re notified as soon as they confirm or dispute it.';
  }

  @override
  String get koryXDeclineConfirm =>
      'You won’t be part of the tontine. The administrator is notified.';

  @override
  String get koryXDeclineInvite => 'Decline the invitation';

  @override
  String get koryXDeclinedInvite => 'Declined';

  @override
  String get koryXDeputy => 'Deputy';

  @override
  String koryXDeputyIs(String name) {
    return 'Administrator’s deputy: $name';
  }

  @override
  String koryXDeputyNotice(String name) {
    return '$name has the same rights as you over the tontine: send reminders, approve a month swap, move to the next round, dissolve.';
  }

  @override
  String koryXDialUssd(String operator) {
    return 'Dial the $operator USSD code';
  }

  @override
  String get koryXDissolve => 'Dissolve the tontine';

  @override
  String get koryXDissolveFinal =>
      'Dissolving stops the tontine for everyone. It’s final.';

  @override
  String get koryXDissolveNoMoreRounds => 'No more rounds are called.';

  @override
  String koryXDissolveNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count members are notified, with the reason.',
      one: 'The member is notified, with the reason.',
    );
    return '$_temp0';
  }

  @override
  String get koryXDissolveSettle =>
      'What was paid between members is settled among you: Pokou never touched the money.';

  @override
  String get koryXDissolved => 'Dissolved';

  @override
  String koryXDissolvedReason(String reason) {
    return 'Reason: “$reason”. The log and the report remain available.';
  }

  @override
  String get koryXDissolvedTitle => 'Tontine dissolved';

  @override
  String koryXDrawAt(String date, String time) {
    return 'Draw · $date, $time';
  }

  @override
  String get koryXDrawAtStart => 'Draw at the start';

  @override
  String get koryXDrawAtStartSub => 'Done by Pokou, logged, cannot be replayed';

  @override
  String get koryXDrawLogged => 'Logged draw';

  @override
  String koryXDrawnOn(String date) {
    return 'Order drawn on $date, logged.';
  }

  @override
  String get koryXDue => 'Upcoming';

  @override
  String koryXDueOn(String month, String day) {
    return '$month · due $day';
  }

  @override
  String koryXEach(String amount) {
    return '$amount each';
  }

  @override
  String get koryXEditCotisation => 'Change or stop the contribution';

  @override
  String get koryXEditCotisationTitle => 'Change the contribution';

  @override
  String koryXEditNotice(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'What is due for $month remains due, and past months stay in the log. All $count members are notified.',
      one:
          'What is due for $month remains due, and past months stay in the log. The member is notified.',
    );
    return '$_temp0';
  }

  @override
  String koryXEditableRemaining(String amount) {
    return 'Editable · $amount left to pay';
  }

  @override
  String get koryXEnd => 'End';

  @override
  String get koryXEveryFortnight => 'Every two weeks';

  @override
  String get koryXEveryMonth => 'Every month';

  @override
  String get koryXEveryQuarter => 'Every quarter';

  @override
  String get koryXEveryWeek => 'Every week';

  @override
  String get koryXEvtClosed => 'The collection is closed.';

  @override
  String koryXEvtConfirmed(String reviewer, String amount, String who) {
    return '$reviewer confirmed $amount from $who';
  }

  @override
  String koryXEvtContested(String reviewer, String amount, String who) {
    return '$reviewer disputed $amount from $who';
  }

  @override
  String koryXEvtContestedReason(
    String reviewer,
    String amount,
    String who,
    String reason,
  ) {
    return '$reviewer disputed $amount from $who: “$reason”';
  }

  @override
  String koryXEvtCreated(String name, String kind) {
    return '$name created the collection ($kind)';
  }

  @override
  String koryXEvtDeclared(String who, String amount) {
    return '$who declared $amount';
  }

  @override
  String koryXEvtDeclaredRef(String who, String amount, String ref) {
    return '$who declared $amount · ref. $ref';
  }

  @override
  String koryXEvtDissolved(String reason) {
    return 'The tontine is dissolved: “$reason”';
  }

  @override
  String koryXEvtDrawn(String seal) {
    return 'Pokou drew the round order · fingerprint $seal';
  }

  @override
  String koryXEvtExtended(String date) {
    return 'The collection is extended until $date';
  }

  @override
  String get koryXEvtOrderFixed => 'The round order is set; the tontine starts';

  @override
  String koryXEvtSwap(String a, String b) {
    return '$a and $b swapped their months';
  }

  @override
  String get koryXExportCsv => 'Export as CSV';

  @override
  String get koryXExportPdf => 'Export as PDF';

  @override
  String get koryXFilterAll => 'All';

  @override
  String get koryXFilterConfirmed => 'Confirmed';

  @override
  String get koryXFilterContested => 'Disputed';

  @override
  String koryXFirmRemaining(String amount) {
    return 'Firm · $amount left to pay';
  }

  @override
  String get koryXFirstDue => 'First due date';

  @override
  String get koryXFirstRound => 'First round';

  @override
  String get koryXFixOrder => 'I set the order myself';

  @override
  String get koryXFixOrderSub => 'Everyone sees their month from the start';

  @override
  String koryXFixedAt(String date) {
    return 'Order set by the administrator · $date';
  }

  @override
  String koryXFixedOn(String date) {
    return 'Order set by the administrator on $date, logged.';
  }

  @override
  String get koryXFixedOrder => 'Order set by the administrator';

  @override
  String get koryXFreeNotice =>
      'Free. Pokou never touches the money: everyone pays the collector from their own wallet.';

  @override
  String koryXFromDueOf(String date) {
    return 'From the $date due date';
  }

  @override
  String get koryXGoalLabel => 'Goal';

  @override
  String koryXGroupPeople(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name · $count people',
      one: '$name · 1 person',
    );
    return '$_temp0';
  }

  @override
  String koryXHaveContributed(String done, String total) {
    return 'Paid: $done of $total';
  }

  @override
  String koryXHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
      one: '1 h ago',
    );
    return '$_temp0';
  }

  @override
  String get koryXISent => 'I’ve sent it';

  @override
  String get koryXInProgress => 'in progress';

  @override
  String koryXIncludingYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count, including you',
      one: 'Just you',
    );
    return '$_temp0';
  }

  @override
  String get koryXIndividualAmounts => 'Individual amounts';

  @override
  String get koryXInvitation => 'Invitation';

  @override
  String get koryXJoinAndPledge => 'Join and pledge';

  @override
  String get koryXJoinNotice =>
      'Pokou never touches the money. You pledge an amount, then pay the collector from your wallet and declare your payment.';

  @override
  String get koryXJournalLocked =>
      'Every action is time-stamped and cannot be erased, not even by the organizer.';

  @override
  String get koryXKoryPlus => 'Kory Plus';

  @override
  String get koryXLastDue => 'Last due date';

  @override
  String koryXLastDueOn(String date) {
    return 'Last due date: $date';
  }

  @override
  String get koryXLate => 'Late';

  @override
  String koryXLateCount(String count) {
    return 'Late · $count';
  }

  @override
  String koryXLeveeCaption(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members × $amount',
      one: '1 member × $amount',
    );
    return '$_temp0';
  }

  @override
  String get koryXLeveePerRound => 'Payout per round';

  @override
  String koryXLinkFrom(String name) {
    return 'Organized by $name';
  }

  @override
  String get koryXLinkedChat => 'Linked chat';

  @override
  String get koryXMakeCoOrganizer => 'Make co-organizer';

  @override
  String get koryXMakeDeputy => 'Make deputy';

  @override
  String get koryXMembersAndOrder => 'Members and order';

  @override
  String get koryXMembersAndRounds => 'Members and rounds';

  @override
  String koryXMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Members · $count',
      one: 'Members · 1',
    );
    return '$_temp0';
  }

  @override
  String get koryXMembersLabel => 'Members';

  @override
  String get koryXMembersNoticeAlone =>
      'You confirm receipts. Someone who joins the group later doesn’t pay automatically: you add them from the contribution, and they pay from the next due date.';

  @override
  String koryXMembersNoticeWith(String name) {
    return 'You and $name confirm receipts. Someone who joins the group later doesn’t pay automatically: you add them from the contribution, and they pay from the next due date.';
  }

  @override
  String koryXMembersTimes(int count, String amount, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members × $amount, $period',
      one: '1 member × $amount, $period',
    );
    return '$_temp0';
  }

  @override
  String get koryXMembersTitle => 'Members';

  @override
  String get koryXMessageOptional => 'Message (optional)';

  @override
  String koryXMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String get koryXMoreActions => 'More actions';

  @override
  String get koryXMyDues => 'My due dates';

  @override
  String get koryXMyLevee => 'My payout';

  @override
  String koryXMyLeveeOf(String month) {
    return 'Your $month payout';
  }

  @override
  String koryXMyPledgeAmount(String amount) {
    return 'My pledge · $amount';
  }

  @override
  String get koryXName => 'Name';

  @override
  String get koryXNeedFirstDue => 'Pick the first due date.';

  @override
  String get koryXNeedGroup =>
      'A tontine is opened from a group chat: pick one.';

  @override
  String get koryXNewAmountPerMember => 'New amount per member';

  @override
  String get koryXNewCotisation => 'New contribution';

  @override
  String get koryXNewTontine => 'New tontine';

  @override
  String koryXNextDueIn(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Next due date · $date, in $days days',
      one: 'Next due date · $date, tomorrow',
      zero: 'Next due date · $date, today',
    );
    return '$_temp0';
  }

  @override
  String get koryXNextDues => 'Next due dates';

  @override
  String get koryXNextRounds => 'Next rounds';

  @override
  String get koryXNoDeputyNotice =>
      'Without a deputy, only you run the tontine: reminders, month swaps, next round, dissolution.';

  @override
  String get koryXNoDueYet =>
      'No due date yet: the schedule starts on the first date chosen.';

  @override
  String get koryXNoEnd => 'No end date';

  @override
  String get koryXNoGroups => 'No group chat yet.';

  @override
  String get koryXNoLinkedChat => 'No chat';

  @override
  String get koryXNoSwapPossible => 'No upcoming month can be swapped.';

  @override
  String get koryXNoTransferNotice =>
      'Pokou doesn’t transfer the money. Check the recipient’s name shown by your operator before confirming. Your operator’s fees apply.';

  @override
  String get koryXNotNow => 'Not now';

  @override
  String get koryXNothingToConfirm => 'Nothing to confirm for now.';

  @override
  String koryXOfWhichToConfirm(String amount) {
    return 'of which $amount to confirm';
  }

  @override
  String koryXOnDay(String date) {
    return 'on $date';
  }

  @override
  String koryXOnGoalOf(String amount) {
    return 'out of a $amount goal';
  }

  @override
  String get koryXOnlyYouConfirm =>
      'Check in your wallet app or in the operator’s SMS. Only you confirm what you received; every answer is time-stamped in the log.';

  @override
  String get koryXOnlyYouConfirmShort => 'It’s your payout: only you confirm';

  @override
  String koryXOpenAndInvite(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Open and invite $count members',
      one: 'Open and invite 1 member',
    );
    return '$_temp0';
  }

  @override
  String get koryXOpenPot => 'Open the collection';

  @override
  String get koryXOrganizerCollector => 'Organizer · collector';

  @override
  String get koryXOrganizerSide => 'organizer’s view';

  @override
  String koryXOrganizerView(String title) {
    return '$title · organizer’s view';
  }

  @override
  String koryXOutOf(String done, String total) {
    return '$done of $total';
  }

  @override
  String koryXOverdueSince(String date) {
    return 'Due date of $date passed';
  }

  @override
  String koryXPaidOf(String paid, String total) {
    return 'Up to date: $paid of $total';
  }

  @override
  String get koryXParticipants => 'Participants';

  @override
  String get koryXPastRounds => 'Past rounds';

  @override
  String get koryXPause => 'Pause';

  @override
  String koryXPauseSub(String date) {
    return 'No due date on $date; resumes at the next one';
  }

  @override
  String koryXPendingSubtitle(String group) {
    return 'Kory Plus · $group · waiting for members';
  }

  @override
  String koryXPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get koryXPeriodBiweekly => 'every two weeks';

  @override
  String koryXPeriodCounts(String up, String pending, String late) {
    return 'Up to date: $up · to confirm: $pending · late: $late';
  }

  @override
  String get koryXPeriodQuarterly => 'every quarter';

  @override
  String get koryXPeriodicity => 'Frequency';

  @override
  String get koryXPickCollector => 'Pick the new collector.';

  @override
  String get koryXPlannedPerDue => 'Total planned per due date';

  @override
  String koryXPlannedTo(String name) {
    return 'Planned · to pay to $name';
  }

  @override
  String get koryXPreviousDues => 'Previous due dates';

  @override
  String get koryXReasonRequired => 'Reason (required)';

  @override
  String koryXRecapNotice(int count, String group) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count members are notified from “$group”.',
      one: 'The member is notified from “$group”.',
    );
    return '$_temp0';
  }

  @override
  String get koryXRecapNoticeAlone =>
      'Next, add members by their number, or share the contribution link.';

  @override
  String koryXRefShort(String ref) {
    return 'ref. $ref';
  }

  @override
  String get koryXReferenceLabel => 'Reference to include';

  @override
  String get koryXRefuse => 'Refuse';

  @override
  String get koryXRejectNeedsReason =>
      '“Not received” needs a reason; the contribution becomes “Disputed” and the person is notified.';

  @override
  String get koryXRemainingLabel => 'Left to collect';

  @override
  String get koryXRemindHint => 'Remind them: each gets a notification.';

  @override
  String get koryXRemindLate => 'Remind late payers';

  @override
  String koryXRemindMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remind $count members',
      one: 'Remind 1 member',
      zero: 'Everyone has answered',
    );
    return '$_temp0';
  }

  @override
  String get koryXRemindTooSoon =>
      'A reminder was already sent less than 12 h ago.';

  @override
  String koryXReminded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people reminded.',
      one: '1 person reminded.',
      zero: 'Nobody to remind.',
    );
    return '$_temp0';
  }

  @override
  String koryXRemindedAt(String date, String time) {
    return 'Reminded on $date at $time; everyone can mute their notifications.';
  }

  @override
  String get koryXRemoveCapture => 'Remove the screenshot';

  @override
  String get koryXReport => 'Report';

  @override
  String get koryXReportKept =>
      'The report and the log remain viewable and exportable by everyone, even if the tontine is dissolved.';

  @override
  String get koryXReportMeaning =>
      '“Has paid” means “confirmed by the round’s beneficiary”: Pokou never sees the money.';

  @override
  String get koryXReportTitle => 'Tontine report';

  @override
  String get koryXRequestSent => 'Request sent.';

  @override
  String koryXRoundCounts(String confirmed, String declared, String late) {
    return 'Confirmed: $confirmed · declared: $declared · late: $late';
  }

  @override
  String koryXRoundOfMonth(String number, String total, String month) {
    return 'Round $number of $total · $month';
  }

  @override
  String koryXRoundsSpan(int count, String from, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count · from $from to $to',
      one: '1 · in $from',
    );
    return '$_temp0';
  }

  @override
  String koryXSaveAndNotify(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save and notify all $count members',
      one: 'Save and notify the member',
    );
    return '$_temp0';
  }

  @override
  String get koryXSavedAndNotified => 'Saved. Members are notified.';

  @override
  String koryXSeal(String seal) {
    return 'Done by Pokou, logged, cannot be replayed · fingerprint $seal';
  }

  @override
  String get koryXSeeJournal => 'See the whole log';

  @override
  String get koryXSeeReport => 'See the tontine report';

  @override
  String get koryXSendRequest => 'Send the request';

  @override
  String koryXSendRequestTo(String name) {
    return 'Send the request to $name';
  }

  @override
  String get koryXSentAt => 'Sent';

  @override
  String get koryXShareLink => 'Share the link';

  @override
  String get koryXSmsCaptureAttached => 'SMS screenshot attached';

  @override
  String get koryXSomeoneDeclined =>
      'Someone declined: once everyone else has accepted, you can start without them, or dissolve.';

  @override
  String koryXStakeDue(String amount, String date) {
    return '$amount per member · due $date';
  }

  @override
  String get koryXStakeLabel => 'Stake per member';

  @override
  String get koryXStakePerMember => 'Stake per member';

  @override
  String koryXStartWithout(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Start without the $count people who declined',
      one: 'Start without the person who declined',
    );
    return '$_temp0';
  }

  @override
  String get koryXStartsWhenAllAccept =>
      'The tontine starts when every member has accepted the invitation. Everyone is notified, and the round order is then set.';

  @override
  String get koryXStatusAfter => 'Status after declaring';

  @override
  String get koryXStepParams => 'Step 1 of 3 · settings';

  @override
  String get koryXStopConfirm =>
      'No more due dates after the current one. What is due remains due, and the log stays available.';

  @override
  String get koryXStopCotisation => 'Stop the contribution';

  @override
  String get koryXSwapCalendarNotice =>
      'The calendar changes for everyone; it’s recorded in the log.';

  @override
  String get koryXSwapMyMonth => 'Swap my month';

  @override
  String get koryXSwapNotice =>
      'Everyone sees this calendar. A month swap happens between two members, with the administrator’s approval.';

  @override
  String koryXSwapRequest(String a, String b) {
    return 'Month swap between $a and $b';
  }

  @override
  String koryXSwapRounds(String a, String b) {
    return 'Round $a for round $b';
  }

  @override
  String get koryXSwapStep1 => 'You send the request';

  @override
  String koryXSwapStep2(String name) {
    return '$name accepts';
  }

  @override
  String koryXSwapStep3(String name) {
    return '$name, the administrator, approves';
  }

  @override
  String get koryXSwapWaitingAdmin =>
      'Accepted · waiting for the administrator';

  @override
  String koryXSwapWaitingMember(String name) {
    return 'Waiting for $name to answer';
  }

  @override
  String get koryXThisRound => 'This round';

  @override
  String koryXToConfirmCount(String count) {
    return 'To confirm · $count';
  }

  @override
  String koryXTodayAt(String time) {
    return 'Today, $time';
  }

  @override
  String get koryXTontineDone =>
      'The tontine is over: every round has taken place.';

  @override
  String koryXTontineInviteFrom(String name) {
    return 'Kory Plus tontine · invitation from $name';
  }

  @override
  String get koryXTontinePlus => 'Tontine Plus';

  @override
  String get koryXTontineStarts => 'The tontine starts';

  @override
  String koryXTontineStep(String step) {
    return 'Kory Plus · step $step of 3';
  }

  @override
  String koryXTontineStepOf(String title, String step) {
    return '$title · step $step of 3';
  }

  @override
  String get koryXTransactionRef => 'Transaction reference';

  @override
  String get koryXTransactionRefHelp =>
      'It appears in your operator’s confirmation SMS.';

  @override
  String get koryXUpcoming => 'Upcoming';

  @override
  String get koryXVisibleToAll => 'Visible to everyone';

  @override
  String koryXVisibleToAllMembers(String title) {
    return '$title · visible to all members';
  }

  @override
  String get koryXVisibleToCollector => 'Visible to the collector only';

  @override
  String get koryXWaiting => 'Waiting';

  @override
  String get koryXWhatHappensNext => 'What happens next';

  @override
  String get koryXWhatToChange => 'What do you want to change?';

  @override
  String get koryXWhichJournal => 'Which log to open?';

  @override
  String get koryXWithAnotherMember => 'with another member';

  @override
  String get koryXWithWhom => 'With whom?';

  @override
  String get koryXWithdrawRequest => 'Withdraw my request';

  @override
  String get koryXYouAccepted =>
      'You’ve accepted. The tontine starts as soon as everyone has answered.';

  @override
  String koryXYouAnd(String name) {
    return 'You and $name';
  }

  @override
  String get koryXYouDeclined => 'You declined this invitation.';

  @override
  String get koryXYouReceive => 'You receive this round’s payout';

  @override
  String get koryXYourContributions => 'Your payments';

  @override
  String get koryXYourMonth => 'Your month';

  @override
  String get koryXUpToDate => 'Up to date';

  @override
  String get koryXPlusFeeTitle => 'Kory Plus opening fee';

  @override
  String koryXPlusFeeBody(String ht, String ttc) {
    return '$ht excl. VAT ($ttc incl. VAT) per member, once, by CashPay.';
  }

  @override
  String koryXPlusFeePaidOf(String paid, String total) {
    return '$paid of $total members have paid';
  }

  @override
  String koryXPayAndJoin(String amount) {
    return 'Pay $amount and join';
  }

  @override
  String koryXPayMyFee(String amount) {
    return 'Pay my fee · $amount';
  }

  @override
  String get koryXFeePaymentPending =>
      'Payment being confirmed. This page updates as soon as it is received.';

  @override
  String get koryXFeePaid => 'Paid';

  @override
  String get koryXFeeYouPaid =>
      'Your fee is paid: you are in the savings circle.';

  @override
  String get koryXStartsWhenAllPaid =>
      'The savings circle starts as soon as every member has paid the opening fee.';

  @override
  String get linkCall => 'Call';

  @override
  String get linkWriteOnPokou => 'Message on Pokou';

  @override
  String get linkCopy => 'Copy';

  @override
  String get linkCopied => 'Copied';

  @override
  String get linkDial => 'Dial this code';

  @override
  String get linkOpen => 'Open link';

  @override
  String get linkSendEmail => 'Send an email';

  @override
  String get linkOpenFailed => 'This link can’t be opened on this phone.';

  @override
  String get koryFrozenTitle => 'Collection suspended by the Pokou team';

  @override
  String koryFrozenBody(String reason) {
    return 'While it is being checked, you can view it but nothing can change. Reason: $reason';
  }

  @override
  String get courierStatusRejected => 'Application declined';

  @override
  String get courierRejectedBody =>
      'The Pokou team did not accept your courier application. You can contact support to learn more.';

  @override
  String get welcomeServiceStatus => 'Share your statuses, visible for 24 h';

  @override
  String get welcomeServiceProof => 'Keep proof of your conversations';

  @override
  String get authPhoneGenericHint => 'Phone number';

  @override
  String get authContactsNotice =>
      'People who already have your number in their contacts will be able to find you on Pokou.';

  @override
  String get authAcceptIntro =>
      'By continuing, you confirm you are at least 13 years old and accept the ';

  @override
  String get authAcceptAnd => ' and the ';

  @override
  String get authAcceptEnd => '.';

  @override
  String get authVerifyButton => 'Verify';

  @override
  String get otpDigitsLabel => '6-digit code';

  @override
  String get otpAutoFilled => 'Code filled in automatically';

  @override
  String get otpAutoVerifyNote =>
      'As soon as the 6 digits are entered, verification starts on its own.';

  @override
  String get otpErrorHint =>
      'Check the latest SMS you received. After the 5th failure, entry is blocked for 15 minutes.';

  @override
  String otpWrongAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong code. You have $count attempts left.',
      one: 'Wrong code. You have 1 attempt left.',
    );
    return '$_temp0';
  }

  @override
  String get twoStepPinLabel => '6-digit PIN';

  @override
  String get twoStepRecoveryNote =>
      'Without your PIN, you can still sign back in after 7 days. This delay stops someone who got hold of your number.';

  @override
  String get homeKoryCardSubtitle => 'Group funds';

  @override
  String get homeHonamCardSubtitle => 'Pharmacies';

  @override
  String get marketSubtitle => 'Classified ads';

  @override
  String get onbAnalyticsSub => 'Anonymous, to improve the app';

  @override
  String get onbMarketingSub => 'By notification or SMS';

  @override
  String get onbStart => 'Let\'s go';

  @override
  String get onbAiTag => 'AI';

  @override
  String get onbBabaRole => 'Pokou assistant';

  @override
  String get onbBabaAiNotice =>
      'Baba is an artificial intelligence. It does not read your other chats and will never ask you for a code received by SMS.';

  @override
  String onbBabaReady(String name) {
    return 'Your account is ready, $name! I\'m here to help you get started with Pokou.';
  }

  @override
  String onbFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Done! $count of your contacts are already on Pokou:',
      one: 'Done! 1 of your contacts is already on Pokou:',
    );
    return '$_temp0';
  }

  @override
  String onbSeeAllFound(int count) {
    return 'See the $count contacts';
  }

  @override
  String get onbWrite => 'Write';

  @override
  String get onbInviteOthers =>
      'For the others, I can prepare an invitation to send by SMS or WhatsApp, if you like.';

  @override
  String get onbInviteMine => 'Invite my loved ones';

  @override
  String get onbGoToChats => 'Go to my chats';

  @override
  String get emptyChatsTitle => 'Your chats will show up here';

  @override
  String get emptyChatsBody =>
      'Find the people who already have Pokou, or invite the others by SMS.';

  @override
  String get emptyChatsFind => 'Find my loved ones';

  @override
  String get emptyChatsInviteSms => 'Invite by SMS';

  @override
  String get emptyKoryTitle => 'No group fund yet';

  @override
  String get emptyKoryBody =>
      'A birthday, a wedding, a savings circle with colleagues: everyone commits, then pays from their own wallet.';

  @override
  String get emptyKoryJoinLink => 'Join with a link';

  @override
  String get emptyKoryNoMoney =>
      'Pokou never touches the money and takes no commission on group funds.';

  @override
  String get emptyHonamNotEmergency =>
      'Honam is not an emergency service. In an emergency, call the emergency services.';

  @override
  String get emptyAssimeTitle => 'No ads';

  @override
  String emptyAssimeTitleIn(String city) {
    return 'No ads in $city';
  }

  @override
  String emptyAssimeBody(String query) {
    return 'Nobody is selling “$query” near you right now.';
  }

  @override
  String get emptyAssimeAlert => 'Create an alert';

  @override
  String get emptyAssimeAlertDone =>
      'Alert created: you\'ll be notified as soon as an ad matches.';

  @override
  String emptyAssimeWholeCountry(String country) {
    return 'Search all of $country';
  }

  @override
  String get emptyAssimeEverywhere => 'Search everywhere';

  @override
  String get emptyAssimeAlertNote =>
      'The alert lets you know as soon as a new ad matches.';

  @override
  String get lot1SoonTitle => 'Coming soon: Kory, Honam, Assimé';

  @override
  String get lot1SoonBody =>
      'Group funds, pharmacy and classified ads are arriving city by city.';

  @override
  String get lot1SoonNotify => 'Notify me';

  @override
  String get lot1SoonNoted =>
      'Noted: you\'ll be told as soon as it opens in your city.';

  @override
  String welcomeBackBabaLot1(String name) {
    return 'Welcome back, $name! I found your account and your backup. Your groups, your chats and your badge come with you.';
  }

  @override
  String get notifDirect => 'One-to-one chats';

  @override
  String get notifPreview => 'Message preview';

  @override
  String get notifPreviewSub => 'The text doesn\'t appear on the lock screen';

  @override
  String get notifReactions => 'Reactions';

  @override
  String get notifRingtone => 'Ringtone';

  @override
  String get notifVibrate => 'Vibrate';

  @override
  String get notifModules => 'Modules';

  @override
  String get notifModuleKorySub => 'Pledges, payment reminders, closings';

  @override
  String get notifModuleHonamSub => 'Quotes, delivery, handover code';

  @override
  String get notifModuleAssimeSub => 'Search alerts, at most one a day';

  @override
  String get notifRingtoneNote =>
      'Pokou\'s ringtone is the only one available for now.';

  @override
  String get accountSecurityTitle => 'Account and security';

  @override
  String get accountSecurityWarning =>
      'Pokou will never ask for your PIN or the code you got by SMS, neither by message nor by call.';

  @override
  String get accountPinTitle => 'PIN';

  @override
  String get accountPinRowSub => 'Asked on a new phone';

  @override
  String get accountPinOn => 'On';

  @override
  String get accountPinOff => 'Off';

  @override
  String get accountPinUnknown => 'Unavailable';

  @override
  String get accountPinIntro =>
      'Choose a 6-digit code. It\'s asked when your number signs in on a new phone.';

  @override
  String get accountPinCurrent => 'Your current code';

  @override
  String get accountPinChoose => 'Choose your code';

  @override
  String get accountPinConfirm => 'Confirm your code';

  @override
  String get accountPinMismatch =>
      'The two codes don\'t match. Choose it again.';

  @override
  String get accountPinReminder => 'Ask me again from time to time';

  @override
  String get accountPinReminderSub => 'So you don\'t forget it';

  @override
  String get accountPinNote =>
      'Your PIN protects your account if someone gets hold of your SIM card. Don\'t write it down in your phone.';

  @override
  String get accountPinEnable => 'Turn on PIN';

  @override
  String get accountPinSave => 'Save PIN';

  @override
  String get accountPinEnabled => 'PIN turned on.';

  @override
  String get accountPinChanged => 'PIN changed.';

  @override
  String get accountPinChange => 'Change PIN';

  @override
  String get accountPinDisable => 'Turn off PIN';

  @override
  String get accountPinDisableConfirm => 'Turn off';

  @override
  String get accountPinDisabled => 'PIN turned off.';

  @override
  String get accountPinReminderTitle => 'Your PIN';

  @override
  String get accountPinReminderBody =>
      'Enter your PIN to check you still remember it.';

  @override
  String get accountPinReminderLater => 'Later';

  @override
  String get accountPinReminderOk => 'That\'s your code.';

  @override
  String get accountExport => 'Download my data';

  @override
  String get accountExportSub => 'Profile, contacts and settings, as a file';

  @override
  String get accountExportFailed => 'Export failed — check your connection.';

  @override
  String get privacyWhoCanSee => 'Who can see';

  @override
  String get privacySeenAt => 'Last seen';

  @override
  String get privacyStatuses => 'Statuses';

  @override
  String get privacyReadReceiptsTitle => 'Read receipts';

  @override
  String get privacyReadReceiptsSub =>
      'When off, you no longer see other people\'s';

  @override
  String get privacyGroupsAndStrangers => 'Groups and strangers';

  @override
  String get privacyGroupAdd => 'Who can add me to groups';

  @override
  String get privacyGroupAddSub => 'Others send you an invitation';

  @override
  String get privacySilenceUnknown => 'Silence unknown callers';

  @override
  String get privacySilenceUnknownSub => 'They stay in the call list';

  @override
  String get privacyBlocked => 'Blocked';

  @override
  String get privacyBlockedEmpty => 'Nobody is blocked.';

  @override
  String get privacyBlockedNote =>
      'A blocked person can no longer message or call you. They are not told.';

  @override
  String get privacyUnblock => 'Unblock';

  @override
  String storagePhone(Object size) {
    return 'Phone · $size';
  }

  @override
  String storagePokouOnly(Object size) {
    return 'Pokou · $size';
  }

  @override
  String storageFreeSpace(Object size) {
    return '$size free';
  }

  @override
  String get storageOthers => 'Other';

  @override
  String get storageFreeLabel => 'Free';

  @override
  String storageFree(Object size) {
    return 'Free up $size';
  }

  @override
  String storageFreed(Object size) {
    return '$size freed.';
  }

  @override
  String get storageFreeBody =>
      'This chat\'s photos, videos and documents are removed from the phone. They\'ll download again if you reopen them; messages stay.';

  @override
  String get languageNoteLot1 =>
      'The app\'s language doesn\'t change the language of your messages. The name Pokou stays the same in every language.';

  @override
  String get helpQCertified => 'How do I pay for Pokou certified?';

  @override
  String get helpACertified =>
      'In Settings, tap \"Pokou certified\" and pick your plan. Payment is by Mobile Money, from your wallet: your identity is checked against the wallet holder\'s name. You can cancel the badge at any time.';

  @override
  String get helpQBlock => 'How do I block a stranger?';

  @override
  String get helpABlock =>
      'Open the chat, tap their name at the top, then \"Block\". They can no longer message or call you, and aren\'t told. In Settings › Privacy you can also silence unknown callers.';

  @override
  String get aboutNameTitle => 'What our name means';

  @override
  String get legalPrivacyPolicy => 'Privacy policy';

  @override
  String legalUpdatedOn(Object date) {
    return 'Updated: $date';
  }

  @override
  String get legalDownloadPdf => 'Download as PDF';

  @override
  String get legalPdfFailed => 'Couldn\'t create the PDF for now.';

  @override
  String get termsLot1Messaging =>
      'Pokou is a messaging app: everyone remains responsible for what they send.';

  @override
  String get privacyLot1Numbers => 'No phone number is shown in group chats.';

  @override
  String get privacyLot1Codes =>
      'A request for a secret code is spotted on your phone, without Pokou reading the message.';

  @override
  String get actionEdit => 'Edit';

  @override
  String statusVisibleBy(Object audience) {
    return 'Visible to: $audience';
  }

  @override
  String get statusFeedSubtitle => 'Visible for 24 h, then they disappear';

  @override
  String get statusRecent => 'Recent';

  @override
  String get statusSeen => 'Seen';

  @override
  String get statusNoneYet => 'No statuses yet.';

  @override
  String get statusJustNow => 'Just now';

  @override
  String statusMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String statusHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String statusYesterdayAt(Object time) {
    return 'Yesterday, $time';
  }

  @override
  String get statusLikeAction => 'Like';

  @override
  String statusReportBody(Object name) {
    return 'Report $name\'s status to the Pokou team?';
  }

  @override
  String get statusReportSent => 'Status reported.';

  @override
  String get statusForwardMediaUnsupported =>
      'Forwarding a photo or video isn\'t possible yet.';

  @override
  String get changeNumberHint => 'Number';

  @override
  String get changeNumberInfoLot1 =>
      'Your account, your chats and your Pokou certified badge follow you. A code is sent to the new number.';

  @override
  String statusExcludedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts excluded',
      one: '1 contact excluded',
      zero: 'No contact excluded',
    );
    return '$_temp0';
  }

  @override
  String statusAllowedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '1 contact',
      zero: 'Nobody yet',
    );
    return '$_temp0';
  }

  @override
  String get statusRule24h => 'A status disappears after 24 h';

  @override
  String get statusRuleViewers => 'Only you see who viewed your statuses';

  @override
  String get statusRuleViewersSub => 'Nobody else sees this number';

  @override
  String get statusRuleReply => 'A reply arrives privately';

  @override
  String get statusRuleReplySub => 'In your one-to-one chat';

  @override
  String get statusRuleReport => 'Any status can be reported';

  @override
  String get statusProofNote =>
      'Statuses aren\'t chat messages: proof mode doesn\'t apply to them.';

  @override
  String get koryMqVerified => 'verified';

  @override
  String koryMqCollectorLine(String name, String wallet) {
    return 'Collector: $name · $wallet · verified by code';
  }

  @override
  String koryMqBeneficiaryLine(String name) {
    return 'Beneficiary: $name';
  }

  @override
  String koryMqOpenOperatorApp(String operator) {
    return 'Open the $operator app';
  }

  @override
  String get koryMqDialUssd => 'Dial the USSD code';

  @override
  String get koryMqPrefilled => 'prefilled';

  @override
  String koryMqCheckWalletOf(String operator) {
    return 'Check in your $operator app or in the operator’s SMS. Every answer is timestamped in the log.';
  }

  @override
  String koryMqRoundSubtitle(String title, String current, String total) {
    return '$title · round $current of $total';
  }

  @override
  String koryMqAmountConfirmed(String amount) {
    return '$amount confirmed';
  }

  @override
  String koryMqOnExpected(String amount) {
    return 'out of $amount expected';
  }

  @override
  String koryMqTimesStake(String count, String amount) {
    return '$count × $amount';
  }

  @override
  String koryMqLeveeCounts(String confirmed, String toConfirm, String late) {
    return '$confirmed confirmed · $toConfirm to confirm · $late late';
  }

  @override
  String koryMqReminded(String when) {
    return 'reminded $when';
  }

  @override
  String get koryMqThisMorning => 'this morning';

  @override
  String koryMqTodayAt(String time) {
    return 'today at $time';
  }

  @override
  String get koryMqYesterday => 'yesterday';

  @override
  String koryMqOnDay(String day) {
    return 'on $day';
  }

  @override
  String get koryMqLeveeDay => 'Payout day';

  @override
  String get koryMqDueDay => 'Due day';

  @override
  String get koryMqDue => 'Due date';

  @override
  String koryMqEveryWeekday(String weekday) {
    return 'every $weekday';
  }

  @override
  String koryMqDayOfMonth(String day) {
    return 'on day $day of the month';
  }

  @override
  String get koryMqBeneficiary => 'Beneficiary';

  @override
  String get koryMqGoalOptional => 'Goal (optional)';

  @override
  String get koryMqAmountPerMember => 'Amount per member';

  @override
  String get koryMqMembers => 'Members';

  @override
  String get koryMqRounds => 'Rounds';

  @override
  String koryMqPlusFeeNotice(String ht, String ttc) {
    return 'Kory Plus · $ht excl. VAT ($ttc incl. VAT) per member, once, at opening. Contributions go straight to each round’s beneficiary.';
  }

  @override
  String get koryMqFreeNoticeDue =>
      'No fees. Pokou never touches the money: at each due date, everyone pays from their wallet to the collector.';

  @override
  String koryMqRoundCounts(String confirmed, String declared, String late) {
    return '$confirmed confirmed · $declared declared · $late late';
  }

  @override
  String get koryMqStake => 'Contribution';

  @override
  String koryMqTtc(String amount) {
    return '$amount incl. VAT';
  }

  @override
  String koryMqFeeHtOnce(String amount) {
    return '$amount excl. VAT, once, by CashPay';
  }

  @override
  String koryMqPayForRemaining(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pay for the $count remaining · $amount incl. VAT',
      one: 'Pay for the last one · $amount incl. VAT',
    );
    return '$_temp0';
  }

  @override
  String koryMqPayTtcByCashPay(String amount) {
    return 'Pay $amount incl. VAT by CashPay';
  }

  @override
  String get koryMqStartsWhenAllPaid =>
      'The tontine starts once everyone has paid their fee and accepted. Fees are non-refundable once the tontine is open.';

  @override
  String get koryMqAdd => 'Add';

  @override
  String get koryMqAddMember => 'Add a member';

  @override
  String get koryMqEveryoneIn =>
      'Everyone in the chat is already in the tontine.';

  @override
  String get koryMqOnPokou => 'On Pokou';

  @override
  String get koryMqRemoveDeputy => 'Remove deputy role';

  @override
  String get koryMqRemoveMember => 'Remove from the tontine';

  @override
  String koryMqAndOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count others',
      one: 'and 1 other',
    );
    return '$_temp0';
  }

  @override
  String get koryMqRemindersTitle => 'Reminders for this contribution';

  @override
  String get koryMqRemindersSub =>
      '2 days before, on the day, and a nudge the day after';

  @override
  String koryMqConfirmedOf(String done, String total) {
    return '$done confirmed of $total';
  }

  @override
  String get koryMqUpToDate => 'Up to date';

  @override
  String koryMqConfirmedDeclared(String confirmed, String declared) {
    return '$confirmed confirmed · $declared declared';
  }

  @override
  String koryMqLateCount(int count) {
    return '$count late';
  }

  @override
  String koryMqHaveContributed(String done, String total) {
    return '$done of $total paid';
  }

  @override
  String get koryMqPlusFeeNotRefunded => 'Kory Plus fees are not refunded.';

  @override
  String get koryMqSeeTontine => 'See the tontine';

  @override
  String koryMqAllPaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count members paid their fee. The tontine is open.',
      one: 'The member paid their fee. The tontine is open.',
    );
    return '$_temp0';
  }

  @override
  String get koryMqAmounts => 'Amounts';

  @override
  String get koryMqVerifiedByCode => 'verified by code';

  @override
  String koryMqOnPlanned(String amount) {
    return 'out of $amount planned';
  }

  @override
  String koryMqPeriodCounts(String up, String pending, String late) {
    return '$up up to date · $pending to confirm · $late late';
  }

  @override
  String get koryMqPreviousMonths => 'Previous months';

  @override
  String koryMqAmountMonthlyOn(String amount, String day) {
    return '$amount, on day $day of each month';
  }

  @override
  String get koryMqOutsidersAfter => 'Outside the group: after creating';

  @override
  String get koryMqAddOutside => 'Add from outside the group';

  @override
  String get koryMqConfirms => 'Confirms';

  @override
  String koryMqAndOtherMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count other members',
      one: 'and 1 other member',
    );
    return '$_temp0';
  }

  @override
  String koryMqDueFrom(String day, String date) {
    return '$day, from $date';
  }

  @override
  String get koryMqRemindersNotice =>
      'Reminders 2 days before and on the day, a nudge the day after if nothing is declared; everyone can turn them off for themselves.';

  @override
  String get koryMqChangeCollectorSub =>
      'New number verified by code; everyone is notified';

  @override
  String get offiEntryTitle => 'Pharmacy space';

  @override
  String offiEntryToDo(String pharmacy, int count) {
    return '$pharmacy · $count to handle';
  }

  @override
  String get offiNotStaffTitle => 'No pharmacy on this account';

  @override
  String get offiNotStaffBody =>
      'This number is not part of any Honam pharmacy team.';

  @override
  String get offiTabOrders => 'Orders';

  @override
  String get offiTabHistory => 'History';

  @override
  String get offiTabSubscription => 'Subscription';

  @override
  String get offiTabAccount => 'Account';

  @override
  String get offiLeave => 'Leave the pharmacy space';

  @override
  String get offiOpen => 'Open';

  @override
  String get offiHidden => 'Not visible';

  @override
  String offiSuspended(String reason) {
    return 'Pharmacy suspended: $reason';
  }

  @override
  String get offiWalletNotVerified =>
      'Patients cannot see you yet: your wallet must be verified by the Pokou team.';

  @override
  String get offiRenewToShow =>
      'Patients can no longer see you: renew your subscription or credit.';

  @override
  String get offiPatient => 'Patient';

  @override
  String get offiAgoNow => 'just now';

  @override
  String offiAgoMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String offiAgoHours(int hours) {
    return '$hours h ago';
  }

  @override
  String get offiStepReceived => 'Received';

  @override
  String get offiStepQuote => 'Quote';

  @override
  String get offiStepPaid => 'Paid';

  @override
  String get offiStepReady => 'Ready';

  @override
  String get offiStepDelivered => 'Delivered';

  @override
  String offiStepSemantics(String step) {
    return 'Current step: $step';
  }

  @override
  String get offiTimelineQuoted => 'Quote sent';

  @override
  String get offiTimelineAccepted => 'Quote accepted';

  @override
  String get offiOrdersTitle => 'Orders';

  @override
  String offiSegToDo(int count) {
    return 'To handle · $count';
  }

  @override
  String offiSegOngoing(int count) {
    return 'Ongoing · $count';
  }

  @override
  String offiSegDelivered(int count) {
    return 'Delivered · $count';
  }

  @override
  String get offiEmptyToDo => 'Nothing to handle';

  @override
  String get offiEmptyOngoing => 'No ongoing order';

  @override
  String get offiEmptyDelivered => 'No delivered order';

  @override
  String get offiEmptyBody =>
      'New prescriptions appear here as soon as a patient sends them to you.';

  @override
  String get offiTagNew => 'New prescription';

  @override
  String get offiTagQuoteSent => 'Quote sent';

  @override
  String get offiTagPaymentToConfirm => 'Payment to confirm';

  @override
  String get offiTagPaymentAwaited => 'Payment awaited';

  @override
  String get offiTagMissingChoice => 'Awaiting the patient’s choice';

  @override
  String get offiTagReadyToGo => 'Ready to go';

  @override
  String get offiTagSearching => 'Looking for a courier';

  @override
  String get offiTagCourierComing => 'Courier on the way';

  @override
  String get offiTagInDelivery => 'Out for delivery';

  @override
  String get offiTagCourseToPay => 'Ride to pay';

  @override
  String get offiTagDelivered => 'Delivered';

  @override
  String get offiTagCancelled => 'Cancelled';

  @override
  String get offiTagRejected => 'Rejected';

  @override
  String get offiTagExpired => 'Expired';

  @override
  String get offiTagRefunded => 'Refunded';

  @override
  String offiAwaitedOnWallet(String amount) {
    return '$amount expected on your wallet';
  }

  @override
  String offiPaidAt(String amount, String time) {
    return 'Paid $amount at $time';
  }

  @override
  String get offiNoCourierYet => 'No courier yet';

  @override
  String offiDeliveredBy(String time, String courier) {
    return 'Delivered at $time · $courier';
  }

  @override
  String get offiMakeQuote => 'Write the quote';

  @override
  String get offiCheckPayment => 'Check the payment';

  @override
  String get offiAskCourier => 'Request a courier';

  @override
  String offiQuoteTitle(String patient) {
    return 'Quote for $patient';
  }

  @override
  String offiReceivedAt(String time) {
    return 'received at $time';
  }

  @override
  String offiPrescriptionOf(String patient) {
    return '$patient’s prescription';
  }

  @override
  String get offiZoom => 'Enlarge';

  @override
  String get offiOriginalToCollect => 'Original prescription to collect';

  @override
  String offiOriginalNotice(String patient) {
    return '$patient will be told: “Have your original prescription ready for the courier.” The courier brings it back to the pharmacy.';
  }

  @override
  String get offiProducts => 'Products';

  @override
  String get offiAddProduct => 'Add a product';

  @override
  String get offiAddProductTitle => 'Add a product';

  @override
  String get offiEditProduct => 'Edit the product';

  @override
  String get offiRemoveProduct => 'Remove the product';

  @override
  String get offiProductName => 'Product';

  @override
  String get offiProductNameHint => 'e.g. Amoxicillin 500 mg, 12 capsules';

  @override
  String get offiProductQuantity => 'Quantity';

  @override
  String get offiProductUnitPrice => 'Unit price';

  @override
  String get offiAvailable => 'Available';

  @override
  String get offiUnavailable => 'Unavailable';

  @override
  String get offiAvailableHint =>
      'An unavailable product stays on the quote without being charged.';

  @override
  String offiQuantity(int count) {
    return '× $count';
  }

  @override
  String get offiSave => 'Save';

  @override
  String get offiMedicines => 'Medicines';

  @override
  String get offiCourseAddedByHonam => 'Ride, added by Honam';

  @override
  String get offiOriginalReturn => 'Return of the original';

  @override
  String get offiTotalToPay => 'Total to pay';

  @override
  String get offiCourseNote =>
      'The ride price is set by Honam for the country; you pay it to the courier after delivery.';

  @override
  String offiQuoteSend(String patient) {
    return 'Send the quote to $patient';
  }

  @override
  String get offiQuoteUpdate => 'Update the quote';

  @override
  String offiQuoteSent(String patient) {
    return 'Quote sent to $patient';
  }

  @override
  String get offiQuoteNothingAvailable =>
      'No product available: reject the prescription instead.';

  @override
  String offiQuoteWaiting(String patient, String date) {
    return 'Quote sent: $patient has until $date to accept it.';
  }

  @override
  String get offiRejectPrescription => 'Reject the prescription';

  @override
  String get offiRejectTitle => 'Reject the prescription';

  @override
  String offiPatientReceivedAt(String patient, String time) {
    return '$patient · received at $time';
  }

  @override
  String get offiReason => 'Reason';

  @override
  String get offiReasonUnavailable => 'Products unavailable';

  @override
  String offiReasonUnavailableHint(String patient) {
    return '$patient will see other pharmacies nearby';
  }

  @override
  String get offiReasonIllegible => 'Prescription illegible or incomplete';

  @override
  String get offiReasonIllegibleHint => 'A new photo is often enough';

  @override
  String get offiReasonInPerson => 'Must be dispensed in person';

  @override
  String offiReasonInPersonHint(String patient) {
    return '$patient can collect it at the pharmacy';
  }

  @override
  String get offiReasonExpired => 'Prescription expired or doubtful';

  @override
  String get offiReasonExpiredHint => 'To be shown in person to a pharmacist';

  @override
  String get offiReasonOutOfZone => 'Outside your delivery area';

  @override
  String offiReasonOutOfZoneHint(String patient) {
    return '$patient will see closer pharmacies';
  }

  @override
  String get offiReasonOther => 'Other reason';

  @override
  String get offiReasonOtherHint => 'Explain it in the message';

  @override
  String offiMessageFor(String patient) {
    return 'Message for $patient';
  }

  @override
  String offiRejectMsgUnavailable(String patient) {
    return 'Hello $patient, we don’t have all the products on your prescription today. Honam suggests nearby pharmacies that can serve you.';
  }

  @override
  String offiRejectMsgIllegible(String patient) {
    return 'Hello $patient, your prescription is illegible or incomplete in the photo. Could you send it again, flat and sharp?';
  }

  @override
  String offiRejectMsgInPerson(String patient) {
    return 'Hello $patient, this treatment must be dispensed in person. You can collect it at the pharmacy.';
  }

  @override
  String offiRejectMsgExpired(String patient) {
    return 'Hello $patient, this prescription has expired or we cannot validate it remotely. Please show it in person to a pharmacist.';
  }

  @override
  String offiRejectMsgOutOfZone(String patient) {
    return 'Hello $patient, your address is outside our delivery area. Honam suggests closer pharmacies.';
  }

  @override
  String offiRejectMsgOther(String patient) {
    return 'Hello $patient, we cannot fill this prescription: ';
  }

  @override
  String get offiAskNewPhoto => 'Ask for a new photo instead';

  @override
  String offiAskPhotoMessage(String patient) {
    return 'Hello $patient, the photo of your prescription is not readable. Could you send a new one, flat and sharp?';
  }

  @override
  String offiMessageSentTo(String patient) {
    return 'Message sent to $patient';
  }

  @override
  String offiRejectAndNotify(String patient) {
    return 'Reject and notify $patient';
  }

  @override
  String get offiRejectedTitle => 'Prescription rejected';

  @override
  String get offiExpiredTitle => 'Quote expired';

  @override
  String get offiExpiredBody =>
      'The quote was not accepted in time: the order is closed, with nothing to refund.';

  @override
  String offiPatientNotifiedAt(String patient, String time) {
    return '$patient · notified at $time';
  }

  @override
  String offiRejectedNothingPaid(String patient) {
    return '$patient paid nothing: there is nothing to refund.';
  }

  @override
  String offiMessageSentToTitle(String patient) {
    return 'Message sent to $patient';
  }

  @override
  String get offiWhatNext => 'What happens next';

  @override
  String offiNext1(String patient) {
    return '$patient receives your message and the reason.';
  }

  @override
  String get offiNext2 =>
      'Honam suggests the nearest open pharmacies: she can resend her prescription in one tap.';

  @override
  String get offiNext3 => 'The order moves to your history, with its reason.';

  @override
  String offiPaymentTitle(String patient) {
    return '$patient’s payment';
  }

  @override
  String get offiPaymentPendingTitle => 'Payment pending';

  @override
  String offiQuoteSentAt(String time) {
    return 'Quote sent at $time';
  }

  @override
  String offiPatientRemindedAt(String patient, String time) {
    return '$patient · reminded at $time';
  }

  @override
  String get offiAmountAwaited => 'Amount expected';

  @override
  String offiOnYourWallet(String wallet) {
    return 'On your wallet · $wallet';
  }

  @override
  String get offiPending => 'Pending';

  @override
  String offiPatientDeclaredPaid(String patient, String time) {
    return '$patient reported paying at $time';
  }

  @override
  String get offiCheckBeforeValidating =>
      'Check receipt in your Mobile Money app or the operator’s SMS before confirming. The money does not go through Pokou.';

  @override
  String get offiFollowUp => 'Timeline';

  @override
  String get offiOrder => 'Order';

  @override
  String get offiCourse => 'Ride';

  @override
  String offiOtherNumberNote(String patient) {
    return 'If $patient paid to another number, only her operator can recover the money: it never goes through Pokou.';
  }

  @override
  String get offiPaymentReceived => 'Payment received, I’ll prepare';

  @override
  String get offiPaymentFinallyReceived => 'Payment received after all';

  @override
  String get offiNotYetReceived => 'Not received yet';

  @override
  String get offiConfirmPaymentTitle => 'Payment received?';

  @override
  String offiConfirmPaymentBody(String amount) {
    return 'Do you confirm you received $amount on your wallet? The order moves to preparation and 100 FCFA excl. VAT is taken from your credit.';
  }

  @override
  String get offiConfirmPaymentYes => 'Yes, received';

  @override
  String get offiCancelOrder => 'Cancel the order';

  @override
  String get offiCancelOrderTitle => 'Cancel the order?';

  @override
  String get offiCancelOrderYes => 'Cancel the order';

  @override
  String get offiCancelUnpaidBody =>
      'Nothing was received: the order is closed without refund, and the patient is notified.';

  @override
  String get offiCancelUnpaidReason => 'Payment not received by the pharmacy';

  @override
  String get offiPaymentMissingTitle => 'Payment not received';

  @override
  String offiPatientAwaits(String patient, String amount) {
    return '$patient · $amount expected';
  }

  @override
  String offiWhatPatientSaid(String patient) {
    return 'What $patient reported';
  }

  @override
  String get offiTime => 'Time';

  @override
  String get offiAmount => 'Amount';

  @override
  String get offiWhatYouSee => 'What you see';

  @override
  String get offiNothingReceived => 'Nothing received';

  @override
  String offiNothingReceivedHint(String patient) {
    return '$patient must check the number and the amount';
  }

  @override
  String get offiDifferentAmount => 'Different amount received';

  @override
  String offiDifferentAmountHint(String patient) {
    return 'Enter it: $patient will have to pay the rest';
  }

  @override
  String get offiAmountReceived => 'Amount received';

  @override
  String get offiDontPrepareYet =>
      'Don’t prepare anything until the money shows on your account. A screenshot or a forwarded SMS does not prove a payment.';

  @override
  String offiNotifyPatient(String patient) {
    return 'Notify $patient';
  }

  @override
  String get offiWaitMore => 'Wait a little longer';

  @override
  String offiNotReceivedMessage(String patient, String amount, String wallet) {
    return 'Hello $patient, the pharmacy has not received your $amount on $wallet. Please check the number and the amount, then send the payment reference again.';
  }

  @override
  String offiDifferentAmountMessage(
    String patient,
    String received,
    String expected,
    String rest,
  ) {
    return 'Hello $patient, the pharmacy received $received instead of $expected. $rest is still due before we prepare your order.';
  }

  @override
  String offiPreparationTitle(String patient) {
    return 'Preparing $patient’s order';
  }

  @override
  String get offiProductsToPrepare => 'Products to prepare';

  @override
  String get offiMissing => 'Missing';

  @override
  String get offiMissingProduct => 'Missing product';

  @override
  String offiMissingReason(String names) {
    return 'Missing: $names';
  }

  @override
  String offiHonamProposes(String patient) {
    return 'Honam offers $patient';
  }

  @override
  String get offiReceiveRest => 'Receive the rest';

  @override
  String get offiReceiveRestHint => 'The other products are delivered';

  @override
  String get offiCancelAll => 'Cancel everything';

  @override
  String get offiCancelAllHint => 'And order elsewhere';

  @override
  String get offiRefunded => 'refunded';

  @override
  String offiWaitingChoice(String patient) {
    return 'Waiting for $patient’s choice';
  }

  @override
  String get offiWaitingChoiceShort => 'Choice pending';

  @override
  String get offiPatientKeeps => 'Receives the rest';

  @override
  String offiRefundToDo(String amount, String patient) {
    return 'Refund $amount to $patient';
  }

  @override
  String offiRefundConfirmedShort(String amount) {
    return 'Refund of $amount confirmed';
  }

  @override
  String get offiNoCourierYetNote =>
      'No courier has been called yet: one is only called once the order is ready. Report a missing product now, not later.';

  @override
  String get offiCancelWholeOrder => 'Cancel the whole order';

  @override
  String offiCancelPaidBody(String patient, String amount) {
    return '$patient will be refunded $amount in full, within 2 h, only to the number that paid.';
  }

  @override
  String get offiCancelPaidReason =>
      'Order cancelled by the pharmacy; full refund';

  @override
  String offiRefundTitle(String patient) {
    return 'Refund $patient';
  }

  @override
  String offiCancelledAt(String time) {
    return 'Order cancelled at $time';
  }

  @override
  String offiRequestedAt(String time) {
    return 'Requested at $time';
  }

  @override
  String offiPatientKeepsRest(String patient) {
    return '$patient receives the rest';
  }

  @override
  String offiPatientCancelsAll(String patient) {
    return '$patient prefers to cancel everything';
  }

  @override
  String get offiToRefund => 'To refund';

  @override
  String offiOnTheirNumber(String phone) {
    return 'To their number · $phone';
  }

  @override
  String get offiTheNumberThatPaid => 'The number that paid you';

  @override
  String get offiCopyNumber => 'Copy the number';

  @override
  String get offiRefundOnlyThisNumber =>
      'Refund only this number, even if someone gives you another one.';

  @override
  String get offiTransferReference => 'Transfer reference';

  @override
  String get offiTransferReferenceHint => 'It is in the confirmation SMS';

  @override
  String offiRefundBefore(String time, String patient, String amount) {
    return 'To do before $time. $patient must receive $amount: any fees are on you.';
  }

  @override
  String offiIRefunded(String patient) {
    return 'I refunded $patient';
  }

  @override
  String offiWaitingPatientConfirm(String patient) {
    return 'Waiting for $patient to confirm';
  }

  @override
  String get offiCancelledTitle => 'Order cancelled';

  @override
  String offiPatientCancelledAt(String patient, String time) {
    return '$patient · cancelled at $time';
  }

  @override
  String get offiRefundConfirmed => 'Refund confirmed';

  @override
  String offiRefundSentTo(String amount, String patient) {
    return '$amount sent to $patient';
  }

  @override
  String offiRefundSentToAt(String amount, String patient, String time) {
    return '$amount sent to $patient at $time';
  }

  @override
  String offiReference(String reference) {
    return 'Ref. $reference';
  }

  @override
  String offiPatientConfirmedAt(String patient, String time) {
    return '$patient confirmed receipt at $time';
  }

  @override
  String get offiCancelledNothingPaid =>
      'Order cancelled before payment: nothing to refund.';

  @override
  String offiCollectedFrom(String patient) {
    return 'Collected from $patient';
  }

  @override
  String offiRefundedTo(String patient) {
    return 'Refunded to $patient';
  }

  @override
  String get offiCourseNoCourier => 'Ride, no courier called';

  @override
  String get offiLeftForPharmacy => 'Left for the pharmacy';

  @override
  String get offiWhatHonamKeeps => 'What Honam keeps';

  @override
  String offiKeptInHistory(String reason) {
    return 'The order stays in your history with its reason: $reason';
  }

  @override
  String get offiAskCourierTitle => 'Request a courier';

  @override
  String offiOrderOf(String patient, String address) {
    return '$patient’s order · $address';
  }

  @override
  String get offiSearching => 'Searching…';

  @override
  String offiSince(int minutes, int seconds) {
    return 'For $minutes min $seconds';
  }

  @override
  String get offiProposedAttached => 'Offered to your regular couriers';

  @override
  String offiProposedAttachedHint(int minutes) {
    return 'They see it $minutes min before the others';
  }

  @override
  String get offiProposedZone => 'Offered to couriers in the area';

  @override
  String get offiCourierAccepts => 'A courier accepts';

  @override
  String get offiCourierAcceptsHint =>
      'You see their name, and the screen moves to delivery';

  @override
  String get offiCoursePaidToCourier => 'Ride paid to the courier';

  @override
  String get offiBy => 'By';

  @override
  String get offiByYourWallet => 'Your pharmacy, to their wallet';

  @override
  String offiSealedNote(String patient) {
    return 'The parcel stays sealed, in $patient’s name. The courier sees neither the prescription nor the products.';
  }

  @override
  String get offiNoCourierTitle => 'No courier available';

  @override
  String offiNoCourierBody(int minutes) {
    return 'No courier has accepted the ride for $minutes minutes.';
  }

  @override
  String get offiRetrySearch => 'Refresh the search';

  @override
  String get offiProposePickupTitle => 'Offer pickup at the pharmacy';

  @override
  String offiProposePickupBody(String patient, String amount) {
    return '$patient is notified. If she agrees to come, you refund her the $amount ride.';
  }

  @override
  String get offiProposePickup => 'Offer pickup';

  @override
  String offiPickupMessage(String patient, String amount) {
    return 'Hello $patient, no courier is available right now. You can collect your order at the pharmacy: we will then refund the $amount ride.';
  }

  @override
  String get offiInviteCouriers => 'Invite your regular couriers';

  @override
  String get offiBackToOrders => 'Back to orders';

  @override
  String offiDeliveryTitle(String patient) {
    return '$patient’s delivery';
  }

  @override
  String get offiVerifiedCourier => 'Verified courier';

  @override
  String offiAcceptedAt(String time) {
    return 'Accepted the ride at $time.';
  }

  @override
  String get offiWrite => 'Write';

  @override
  String get offiHandover => 'Parcel handover';

  @override
  String offiCheckSealed(String patient) {
    return 'Bag sealed, in $patient’s name.';
  }

  @override
  String get offiCheckDosage => 'Dosage written on each box';

  @override
  String get offiCheckPhoto => 'The person at the counter matches the photo';

  @override
  String get offiAfterDelivery => 'After delivery';

  @override
  String offiAfterDeliveryBody(String patient, String courier) {
    return '$patient gives her code to $courier, who enters it in Honam: the order closes.';
  }

  @override
  String offiCourseToPay(String courier) {
    return 'Ride to pay to $courier';
  }

  @override
  String offiHandedTo(String courier) {
    return 'Parcel handed to $courier';
  }

  @override
  String get offiFollowDelivery => 'Follow the delivery';

  @override
  String get offiReportDefault => 'Report a courier issue';

  @override
  String offiHandedAt(String courier, String time) {
    return 'Parcel handed to $courier at $time';
  }

  @override
  String get offiTrackingNote =>
      'Position updated every 15 seconds, visible until the code is entered. It is not kept after delivery.';

  @override
  String offiDeliveredTo(String patient) {
    return 'Delivered to $patient';
  }

  @override
  String offiCodeEnteredBy(String courier, String time) {
    return 'Code entered by $courier at $time';
  }

  @override
  String get offiToSettle => 'To settle';

  @override
  String offiPayCourierOn(String courier) {
    return 'Pay $courier on their wallet:';
  }

  @override
  String get offiNoFeeOnPayment => 'Pokou takes nothing from this payment.';

  @override
  String offiPaidToCourier(String courier) {
    return 'Ride paid to $courier';
  }

  @override
  String offiIPaid(String courier) {
    return 'I paid $courier';
  }

  @override
  String offiWaitingCourierConfirm(String courier) {
    return 'Waiting for $courier to confirm';
  }

  @override
  String get offiOriginal => 'Original prescription';

  @override
  String get offiOriginalBack => 'Received';

  @override
  String offiOriginalCollected(String courier, String time) {
    return 'Collected by $courier at $time, to bring back on their next visit.';
  }

  @override
  String offiOriginalWithCourier(String courier) {
    return 'With $courier, to bring back on their next visit.';
  }

  @override
  String offiOriginalReturnedAt(String date) {
    return 'Returned to the pharmacy on $date.';
  }

  @override
  String get offiOriginalReceived => 'Original received';

  @override
  String get offiClosedTitle => 'Order closed';

  @override
  String offiPatientDeliveredAt(String patient, String time) {
    return '$patient · delivered at $time';
  }

  @override
  String get offiCourseSettled => 'Ride settled';

  @override
  String offiCourseSettledBody(String amount, String courier, String time) {
    return '$amount paid to $courier; $courier confirmed receipt at $time.';
  }

  @override
  String get offiReportDeliveryDefault => 'Report a delivery issue';

  @override
  String get offiCouriersTitle => 'Your couriers';

  @override
  String get offiInviteYourCouriers => 'Invite your regular couriers';

  @override
  String offiInviteYourCouriersBody(int minutes) {
    return 'Your rides are offered to them first, for $minutes min, before other couriers in the area. They remain free to work for other pharmacies. They must be validated Pokou couriers.';
  }

  @override
  String get offiNoAttachedCourier => 'No courier attached yet.';

  @override
  String offiDefaults(int count) {
    return '$count issue(s)';
  }

  @override
  String offiUnpaidCourses(int count) {
    return '$count ride(s) to pay';
  }

  @override
  String offiCoursesCount(int count) {
    return '$count rides';
  }

  @override
  String get offiAttached => 'Attached';

  @override
  String get offiCourierSuspended => 'Suspended';

  @override
  String get offiShareLink => 'Share the link';

  @override
  String get offiAttachByNumber => 'Attach';

  @override
  String get offiAttachHint =>
      'The number of an already validated Pokou courier.';

  @override
  String get offiCourierNumber => 'Courier’s number';

  @override
  String get offiAttach => 'Attach';

  @override
  String get offiCourierAttached => 'Courier attached';

  @override
  String get offiCouriersNote =>
      'Without an available attached courier, the ride goes to couriers in the area, as usual.';

  @override
  String get offiDetachHint => 'Long-press a courier to remove them.';

  @override
  String offiDetachTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get offiDetachBody => 'They will no longer see your rides first.';

  @override
  String get offiDetach => 'Remove';

  @override
  String offiCourierInviteText(String pharmacy) {
    return 'Deliver for $pharmacy with Honam: install Pokou and become a courier';
  }

  @override
  String offiChatSubtitle(String patient) {
    return 'Verified courier · $patient’s ride';
  }

  @override
  String offiChatNotice(String patient) {
    return 'Conversation between the pharmacy and the courier about $patient’s ride. The patient does not see it. Numbers stay hidden.';
  }

  @override
  String get offiQuickReady => 'The parcel is ready';

  @override
  String get offiQuickWhere => 'Where are you?';

  @override
  String get offiQuickThanks => 'Thank you';

  @override
  String offiWriteTo(String courier) {
    return 'Write to $courier…';
  }

  @override
  String get offiSend => 'Send';

  @override
  String get offiDefectTitle => 'Report an issue';

  @override
  String offiCourseOf(String courier, String date) {
    return '$courier’s ride · $date';
  }

  @override
  String get offiWhatHappened => 'What happened?';

  @override
  String get offiDefectNoShow => 'Courier never came';

  @override
  String get offiDefectLate => 'Very late, without notice';

  @override
  String get offiDefectDamaged => 'Parcel opened or damaged';

  @override
  String get offiDefectOriginal => 'Original prescription not returned';

  @override
  String get offiDefectBehaviour => 'Inappropriate behaviour';

  @override
  String get offiDetails => 'Details';

  @override
  String offiDefectNoteOngoing(String courier) {
    return 'The issue counts against $courier and the order goes back to “ready” for another courier. At the 3rd issue, the courier account is suspended.';
  }

  @override
  String offiDefectNoteDelivered(String courier) {
    return 'The issue counts against $courier. At the 3rd issue, the courier account is suspended.';
  }

  @override
  String get offiSendReport => 'Send the report';

  @override
  String get offiDefaultSent => 'Report sent';

  @override
  String get offiHistoryTitle => 'History';

  @override
  String get offiPreviousMonth => 'Previous month';

  @override
  String get offiNextMonth => 'Next month';

  @override
  String get offiStatDelivered => 'Delivered';

  @override
  String get offiStatCollected => 'Collected';

  @override
  String get offiStatCollectedHint => 'medicines and rides';

  @override
  String get offiStatCancelled => 'Cancelled';

  @override
  String get offiFilterAll => 'All';

  @override
  String get offiFilterDelivered => 'Delivered';

  @override
  String get offiFilterCancelled => 'Cancelled';

  @override
  String get offiHistoryEmpty => 'Nothing this month';

  @override
  String get offiHistoryEmptyBody =>
      'Delivered, rejected or cancelled orders show up here.';

  @override
  String offiDeliveredAtShort(String time) {
    return 'delivered at $time';
  }

  @override
  String get offiExportMonth => 'Export the month as CSV';

  @override
  String get offiCsvDate => 'Date';

  @override
  String get offiCsvOrder => 'Order';

  @override
  String get offiCsvPatient => 'Patient';

  @override
  String get offiCsvStatus => 'Status';

  @override
  String get offiCsvMedicines => 'Medicines (FCFA)';

  @override
  String get offiCsvCourse => 'Ride (FCFA)';

  @override
  String get offiCsvTotal => 'Collected (FCFA)';

  @override
  String get offiCsvRefunded => 'Refunded (FCFA)';

  @override
  String get offiCsvCourier => 'Courier';

  @override
  String get offiSubscriptionTitle => 'Subscription';

  @override
  String get offiPlanWetri => 'Wétri HONAM';

  @override
  String get offiPlanEpe => 'ÉPÉ HONAM';

  @override
  String get offiActive => 'Active';

  @override
  String offiPerMonthHt(String amount) {
    return '$amount excl. VAT per month';
  }

  @override
  String offiTtcWithVat(String amount, int vat) {
    return 'That is $amount incl. $vat% VAT';
  }

  @override
  String offiNextPayment(String date) {
    return 'Next payment on $date';
  }

  @override
  String get offiRenewNow => 'Renew now';

  @override
  String get offiChoose => 'Choose this plan';

  @override
  String get offiPaidByCashPay => 'Paid with CashPay: mobile money or card';

  @override
  String offiFreeMonths(int months) {
    return '$months months free';
  }

  @override
  String offiEpePitch(String price, String instead, String ttc) {
    return '$price excl. VAT per year instead of $instead, that is $ttc incl. VAT';
  }

  @override
  String get offiSwitchToYearly => 'Switch to yearly';

  @override
  String get offiCreditTitle => 'Order credit';

  @override
  String get offiCreditSubtitle => '100 FCFA excl. VAT per paid order';

  @override
  String get offiCreditBalance => 'Credit excl. VAT';

  @override
  String offiOrdersLeft(int count) {
    return 'That is $count paid orders';
  }

  @override
  String get offiCreditLow => 'Credit running low';

  @override
  String offiBuyCredit(String ht, String ttc) {
    return 'Buy $ht excl. VAT · $ttc incl. VAT';
  }

  @override
  String get offiPricesHt =>
      'Prices excl. VAT, local VAT added. Nothing is granted before the payment is confirmed.';

  @override
  String get offiPaymentPending =>
      'Payment in progress: the subscription or credit shows as soon as it is confirmed.';

  @override
  String get offiAccountTitle => 'Account';

  @override
  String get offiOpeningHours => 'Opening hours';

  @override
  String get offiCounterPhone => 'Counter phone';

  @override
  String get offiReceivingWallet => 'Receiving wallet';

  @override
  String get offiWalletVerified => 'verified';

  @override
  String get offiWalletPending => 'verification pending';

  @override
  String offiAttachedCount(int count) {
    return '$count attached';
  }

  @override
  String get offiOnDuty => 'On-duty pharmacy';

  @override
  String get offiOnDutyHint =>
      'Patients see the “On duty” label in the directory.';

  @override
  String get offiTeamNote =>
      'To change the address, hours, wallet or add a team member, contact Pokou support.';

  @override
  String get courierTransportMoto => 'motorbike';

  @override
  String get courierTransportBike => 'bicycle';

  @override
  String get courierTransportWalk => 'on foot';

  @override
  String get honamPAddAddress => 'Add the delivery address';

  @override
  String get honamPAmountToSend => 'Amount to send';

  @override
  String honamPArrivesAround(String name, String time) {
    return '$name arrives around $time';
  }

  @override
  String honamPArrivesIn(String name, int minutes) {
    return '$name arrives in $minutes min';
  }

  @override
  String honamPAtKm(String km) {
    return '$km km away';
  }

  @override
  String honamPCallRelayed(String name) {
    return 'Call $name through Pokou, number hidden';
  }

  @override
  String honamPCancelAllBody(String amount) {
    return 'Nothing is delivered. The pharmacy refunds you $amount.';
  }

  @override
  String honamPCheckRecipient(String pharmacy) {
    return 'Check that your operator shows “$pharmacy” before confirming. Operator fees apply.';
  }

  @override
  String get honamPCodeLater =>
      'Your handover code appears when the courier is on the way. Give it only to them, when they hand you the parcel.';

  @override
  String get honamPCopyAmount => 'Copy the amount';

  @override
  String honamPCurrentLine(String pharmacy, String amount) {
    return '$pharmacy · $amount, delivery included';
  }

  @override
  String get honamPCurrentOrder => 'Current order';

  @override
  String honamPDeliverTo(String address) {
    return 'Deliver to $address';
  }

  @override
  String get honamPDeliveryByHonam => 'Delivery, added by Honam';

  @override
  String get honamPDialUssd => 'Dial the USSD code';

  @override
  String get honamPFollowOrder => 'Track my order';

  @override
  String get honamPFollowWithoutMap => 'Track without the map';

  @override
  String get honamPGeneric => 'Generic';

  @override
  String honamPGenericOffered(String names) {
    return 'A generic is offered for: $names. A question? Write to the pharmacy before paying.';
  }

  @override
  String honamPGiveCodeOnly(String name) {
    return 'Give it only to $name, when they hand you the parcel.';
  }

  @override
  String honamPGoingToPharmacy(String name) {
    return '$name is picking up your order at the pharmacy';
  }

  @override
  String get honamPHome => 'Your place';

  @override
  String get honamPInDelivery => 'Order out for delivery';

  @override
  String get honamPInProgress => 'In progress';

  @override
  String honamPKeepRestBody(String amount) {
    return 'The rest of your order is delivered. The pharmacy refunds you $amount.';
  }

  @override
  String honamPLandmark(String landmark) {
    return 'Landmark: $landmark';
  }

  @override
  String get honamPLandmarkHint => 'Blue gate opposite the kiosk';

  @override
  String get honamPLandmarkLabel => 'Landmark for the courier';

  @override
  String get honamPLater => 'Later';

  @override
  String get honamPLightTracking =>
      'Light tracking, almost no data: the map only loads if you ask for it. It is the default with data saver.';

  @override
  String get honamPMessageHint => 'Please deliver before 1 pm';

  @override
  String get honamPMessageToPharmacy => 'Message to the pharmacy';

  @override
  String honamPMissingLead(String pharmacy, String reason) {
    return '$pharmacy no longer has this product: $reason. What do you prefer?';
  }

  @override
  String get honamPMissingNoAnswer =>
      'Without an answer from you within 15 minutes, everything is cancelled and refunded.';

  @override
  String get honamPMore => 'More options';

  @override
  String get honamPMyOrder => 'My order';

  @override
  String honamPNothingPaid(String pharmacy) {
    return '$pharmacy · nothing was paid';
  }

  @override
  String get honamPOnItsWallet => 'On its wallet app';

  @override
  String honamPOrderOf(String pharmacy) {
    return 'Order from $pharmacy';
  }

  @override
  String honamPPaidOrderOf(String pharmacy) {
    return '$pharmacy · paid order';
  }

  @override
  String get honamPPast => 'Past';

  @override
  String get honamPPastQuestion =>
      'A question about a past order? Open it: the conversation with the pharmacy stays there.';

  @override
  String honamPPayAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get honamPPayDirectly =>
      'You pay the pharmacy directly from your wallet. Pokou never touches the money and takes nothing on medicines.';

  @override
  String get honamPPayTitle => 'Pay the pharmacy';

  @override
  String honamPPharmacyHonam(String pharmacy) {
    return '$pharmacy · Honam';
  }

  @override
  String get honamPPhotoAdded => 'Photo added';

  @override
  String get honamPPhotoHelp =>
      'Check that the whole page is visible, including the doctor’s name.';

  @override
  String get honamPPillCancelled => 'Cancelled';

  @override
  String get honamPPillDelivered => 'Delivered';

  @override
  String get honamPPillExpired => 'Expired';

  @override
  String get honamPPillOnTheWay => 'On the way';

  @override
  String get honamPPillPreparing => 'Being prepared';

  @override
  String get honamPPillRefundPending => 'Refund pending';

  @override
  String get honamPPillRefunded => 'Refunded';

  @override
  String get honamPPillRejected => 'Declined';

  @override
  String get honamPPillToPay => 'Quote to pay';

  @override
  String get honamPPillWaitingQuote => 'Awaiting quote';

  @override
  String get honamPPrescriptionSent => 'Prescription sent';

  @override
  String get honamPPrivacyNotice =>
      'Only the chosen pharmacy sees your photo. The courier sees neither the prescription nor the products.';

  @override
  String honamPProducts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String honamPQuoteFrom(String pharmacy) {
    return 'Quote from $pharmacy';
  }

  @override
  String get honamPReason => 'Reason';

  @override
  String honamPReceivedAt(String when) {
    return 'Received $when';
  }

  @override
  String honamPRef(String reference) {
    return 'ref. $reference';
  }

  @override
  String honamPReferenceHelp(String operator) {
    return 'In the $operator confirmation SMS';
  }

  @override
  String honamPRefundDone(String amount) {
    return 'Refund of $amount received.';
  }

  @override
  String honamPRefundToPayer(String wallet) {
    return 'The refund arrives within 2 hours, only to the number that paid: $wallet.';
  }

  @override
  String get honamPRefuseQuote => 'Decline the quote';

  @override
  String get honamPRefusedTitle => 'Prescription declined';

  @override
  String get honamPRetake => 'Retake';

  @override
  String get honamPSamePhoto =>
      'The same photo is sent: you have nothing to redo.';

  @override
  String get honamPSeeQuoteAndPay => 'See the quote and pay';

  @override
  String get honamPSendElsewhere => 'Send to another pharmacy';

  @override
  String honamPSendTo(String pharmacy) {
    return 'Send to $pharmacy';
  }

  @override
  String honamPSentAt(String pharmacy, String when) {
    return '$pharmacy · sent $when';
  }

  @override
  String get honamPShowMap => 'Show the map';

  @override
  String get honamPStepDelivered => 'Delivered';

  @override
  String get honamPStepOnTheWay => 'On the way';

  @override
  String get honamPStepPaid => 'Paid';

  @override
  String get honamPStepPaymentReceived => 'The pharmacy received your payment';

  @override
  String get honamPStepPaymentSignaled => 'Payment reported';

  @override
  String get honamPStepPharmacyChecks => 'The pharmacy checks it received it';

  @override
  String get honamPStepPreparing => 'Preparation, then the courier leaves';

  @override
  String get honamPStepPreparingBody =>
      'You track the delivery and get your code';

  @override
  String get honamPStepQuote => 'Quote';

  @override
  String get honamPStepSent => 'Sent';

  @override
  String honamPToPharmacy(String pharmacy) {
    return 'To $pharmacy';
  }

  @override
  String honamPTodayAt(String time) {
    return 'today, $time';
  }

  @override
  String honamPTomorrowAt(String time) {
    return 'tomorrow, $time';
  }

  @override
  String get honamPTotalToPay => 'Total to pay';

  @override
  String honamPUpdatedSecondsAgo(int seconds) {
    return 'updated $seconds s ago';
  }

  @override
  String honamPValidUntil(String when) {
    return 'valid until $when';
  }

  @override
  String get honamPValidateChoice => 'Confirm my choice';

  @override
  String get honamPVerifiedCourier => 'Verified courier';

  @override
  String honamPWaitingQuoteBody(String pharmacy) {
    return '$pharmacy is reading your prescription and preparing the quote. You get a notification as soon as it arrives.';
  }

  @override
  String get honamPWriteToPharmacy => 'Write to the pharmacy';

  @override
  String honamPYesterdayAt(String time) {
    return 'yesterday, $time';
  }

  @override
  String get courierAccept => 'Accept';

  @override
  String get courierAcceptConditions => 'I accept the courier terms';

  @override
  String get courierAccident => 'Accident or breakdown';

  @override
  String get courierAccidentBody =>
      'The pharmacy is told and the ride is reassigned';

  @override
  String get courierAddZone => 'Add a neighbourhood';

  @override
  String get courierAddressNotFound => 'Address not found';

  @override
  String courierAddressNotFoundBody(String name) {
    return '$name is told and can guide you by message';
  }

  @override
  String courierAfterHandover(String pharmacy, String amount) {
    return 'After the handover: the ride is counted from your trial or pack, and $pharmacy pays you $amount on your wallet. You confirm receipt in courier mode.';
  }

  @override
  String get courierAfternoon => 'Afternoon';

  @override
  String get courierAlreadyValidated => 'Already approved';

  @override
  String get courierAnswerIn30 => 'Answer within 30 seconds';

  @override
  String get courierApplicationOpen30 =>
      'Your application stays open for 30 days.';

  @override
  String courierAskCode(String name) {
    return 'Ask $name for the code: it shows in their app. Enter it when you hand over the parcel.';
  }

  @override
  String courierAtTheLatest(String when) {
    return 'At the latest $when';
  }

  @override
  String get courierAvailable => 'Available';

  @override
  String get courierAvailableBody => 'Rides reach you, even while you chat';

  @override
  String get courierAwaitingPayment =>
      'Delivered · awaiting the pharmacy’s payment';

  @override
  String get courierBack => 'the back';

  @override
  String get courierBackToPokou => 'Back to Pokou';

  @override
  String get courierBackWhereYouWere =>
      'You were elsewhere in the app: you go back there after answering.';

  @override
  String get courierBecome => 'I become a courier';

  @override
  String courierBefore(String when) {
    return 'before $when';
  }

  @override
  String get courierBirthDate => 'Date of birth';

  @override
  String courierCallAgain(String name) {
    return 'Call $name again, number hidden';
  }

  @override
  String courierCallPatient(String name) {
    return 'Call $name';
  }

  @override
  String get courierCallRelayed => 'Call relayed by Pokou, number hidden';

  @override
  String get courierChooseDate => 'Choose the date';

  @override
  String courierChoosePack(String pack) {
    return 'Choose $pack';
  }

  @override
  String get courierChooseYourPack => 'Choose your pack to keep delivering';

  @override
  String get courierCodeRefused => 'The code is refused';

  @override
  String courierCodeRefusedBody(String name) {
    return 'Check the digits with $name, then try again';
  }

  @override
  String get courierContactSupport => 'Contact support';

  @override
  String get courierContest => 'Dispute';

  @override
  String get courierContestDefault => 'Dispute this fault';

  @override
  String get courierContestHint => 'What happened, in a few words';

  @override
  String get courierContestHow =>
      'If you dispute, support compares the pickup time, your position during the ride and the calls made through Pokou.';

  @override
  String get courierContestSent => 'Dispute sent to support';

  @override
  String get courierContinue => 'Continue';

  @override
  String get courierCopyLink => 'Copy my link';

  @override
  String get courierCouldNotVerify => 'Support could not verify your identity.';

  @override
  String courierCountOf(int count, int total) {
    return '$count of $total';
  }

  @override
  String courierDefaultLead(String pharmacy, String when) {
    return '$pharmacy reported a fault on the ride of $when.';
  }

  @override
  String get courierDefaultTitle => 'Fault reported';

  @override
  String get courierDefaults => 'Faults';

  @override
  String get courierDefaultsInProgress => 'Current faults';

  @override
  String get courierDelivered => 'Parcel handed over: the ride is confirmed.';

  @override
  String get courierDelivery => 'Delivery';

  @override
  String courierDeliveryAt(String address) {
    return 'Delivery: $address';
  }

  @override
  String courierDeliveryTo(String name) {
    return 'Delivery to $name';
  }

  @override
  String get courierDocCni => 'ID card';

  @override
  String get courierDocPassport => 'Passport';

  @override
  String get courierDocVoter => 'Voter card';

  @override
  String get courierDone => 'Done';

  @override
  String courierEarned(String amount) {
    return '$amount earned';
  }

  @override
  String courierEarningsNote(String wallet) {
    return 'Each pharmacy pays you the ride on your wallet $wallet. A late payment is reported from the ride.';
  }

  @override
  String get courierEarningsTitle => 'My rides and earnings';

  @override
  String get courierEnterCode => 'Enter the code';

  @override
  String get courierEvening => 'Evening';

  @override
  String get courierFirstDeliveryDone => 'First delivery done';

  @override
  String get courierFiveAttempts =>
      '5 attempts at most. Each attempt is recorded.';

  @override
  String get courierFree => 'Free';

  @override
  String get courierFri => 'Fri';

  @override
  String get courierFriendActive => 'Active courier';

  @override
  String get courierFriendApplying => 'Signing up';

  @override
  String get courierFriendDeclined => 'Not accepted';

  @override
  String courierFriendMessage(String code) {
    return 'Hi! I deliver for Honam with Pokou: paid for every ride, near you, whenever you want. Join me with my code $code.';
  }

  @override
  String get courierFriendNotice =>
      'You get free rides when your friend completes their first delivery. The invitation is for people aged 18 and over, in a city where Honam is open.';

  @override
  String courierFromPerMonth(String amount) {
    return '$amount incl. VAT per month';
  }

  @override
  String get courierFront => 'the front';

  @override
  String get courierGains => 'Earnings';

  @override
  String courierGiftNotice(int count) {
    return 'You get $count free rides when your referral completes their first delivery.';
  }

  @override
  String get courierGoOffline => 'Go unavailable';

  @override
  String get courierGoOnline => 'Go available';

  @override
  String get courierGoToMode => 'Switch to courier mode';

  @override
  String get courierHandoverCode => 'Handover code';

  @override
  String get courierHonamOpen => 'Honam open';

  @override
  String get courierHowDoYouDeliver => 'How do you deliver?';

  @override
  String get courierHowMuch => 'How much can I earn?';

  @override
  String courierHt(String amount) {
    return '$amount excl. VAT';
  }

  @override
  String get courierIdDocument => 'Identity document';

  @override
  String get courierIdNameNotice =>
      'The name on your document must match the owner of your wallet.';

  @override
  String get courierIdPrivacy =>
      'Your document is only used to verify your identity. It is encrypted and deleted 30 days after the decision.';

  @override
  String courierInviteMessage(String code, String link) {
    return 'Deliver for Honam with me: paid for every ride, near you. My code: $code — $link';
  }

  @override
  String courierInviteSubtitle(int count) {
    return '$count free rides after their first delivery';
  }

  @override
  String get courierInviteTitle => 'Invite a courier';

  @override
  String courierInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String courierInviterCodeApplied(String code) {
    return 'Verified courier · code $code applied';
  }

  @override
  String courierInviterGets(String name, int count) {
    return '$name recommended you: they get $count free rides when you complete your first delivery.';
  }

  @override
  String get courierItemBack => 'Back of the document unreadable';

  @override
  String get courierItemFront => 'Front of the document unreadable';

  @override
  String get courierItemSelfie => 'Selfie';

  @override
  String get courierItemWallet => 'Wallet';

  @override
  String get courierItinerary => 'Directions';

  @override
  String courierKmAfterPickup(String km) {
    return '$km km after pickup';
  }

  @override
  String courierKmFromYou(String km) {
    return '$km km from you';
  }

  @override
  String get courierLaunchCaption =>
      'During the launch: no membership or pack, then Win Pokou';

  @override
  String get courierLaunchLine => 'If Honam just opened in your city';

  @override
  String get courierLetGo => 'Let this ride go';

  @override
  String courierMembershipAndPack(String pack) {
    return 'Membership and $pack pack, incl. VAT';
  }

  @override
  String courierMembershipAndPackOf(String month) {
    return 'Membership and pack for $month';
  }

  @override
  String courierMembershipAndPackTtc(String amount) {
    return 'Membership and pack: $amount incl. VAT per month';
  }

  @override
  String get courierMembershipFirst =>
      'Membership is paid first; the pack is chosen next, on the same screen.';

  @override
  String get courierMembershipLine => 'Win Pokou membership';

  @override
  String courierMinutesOf(int minutes, int total) {
    return '$minutes min of $total';
  }

  @override
  String get courierMon => 'Mon';

  @override
  String get courierMonthEarnings => 'This month’s earnings';

  @override
  String get courierMoreRides => 'Extra rides this month';

  @override
  String get courierMorning => 'Morning';

  @override
  String get courierNeedAge => '18 or older, an identity document';

  @override
  String get courierNeedPhone => 'A smartphone and a mobile money wallet';

  @override
  String get courierNeedVehicle =>
      'A motorbike, a bicycle, or your feet for nearby rides';

  @override
  String get courierNetForYou => 'Net for you';

  @override
  String get courierNewRide => 'New ride';

  @override
  String get courierNewRideMode => 'New ride · courier mode';

  @override
  String get courierNewRideNearby => 'New ride near you';

  @override
  String courierNoAnswer(String name) {
    return '$name is not answering';
  }

  @override
  String get courierNoAnswerBody =>
      'Pokou calls and warns them. Wait 10 minutes on site.';

  @override
  String courierNoAnswerReturn(String pharmacy) {
    return 'With no answer after 10 min, you take the closed parcel back to $pharmacy. It is not a fault for you.';
  }

  @override
  String get courierNoReferrals => 'Nobody yet: share your link.';

  @override
  String get courierNoon => 'Noon';

  @override
  String get courierNotNow => 'Not now';

  @override
  String courierNotYetBody(String city) {
    return 'No pharmacy in $city has joined Honam yet: there would be no rides for you. We’ll tell you as soon as they arrive.';
  }

  @override
  String courierNotYetIn(String city) {
    return 'Honam is not in $city yet';
  }

  @override
  String get courierNotifyMe => 'Notify me';

  @override
  String courierOfferCityOpen(String city) {
    return '$city · Honam is open';
  }

  @override
  String get courierOfferTitle => 'Deliver for Honam';

  @override
  String get courierOriginalToReturn => 'Original to return';

  @override
  String courierPackDifference(String from, String to) {
    return 'Difference $from → $to';
  }

  @override
  String courierPackExhausted(String pack) {
    return 'Your $pack pack is used up';
  }

  @override
  String courierPackExhaustedBody(String amount, String pack) {
    return 'This ride earns you $amount. Switch to $pack by paying only the difference and accept it.';
  }

  @override
  String get courierPackExhaustedNoNext =>
      'You have the largest pack: wait for next month or let this ride go.';

  @override
  String get courierPackForYou => 'The pack that suits you';

  @override
  String courierPackLeft(String pack, int left, int total) {
    return '$pack: $left rides left of $total';
  }

  @override
  String courierPackLine(String pack) {
    return '$pack pack';
  }

  @override
  String courierPackRides(String pack, int count) {
    return '$pack · $count rides';
  }

  @override
  String get courierPaid => 'Paid';

  @override
  String get courierPaidByPharmacy =>
      'paid by the pharmacy to your wallet, whenever you want, near you';

  @override
  String get courierPaidByPharmacyShort =>
      'paid by the pharmacy to your wallet';

  @override
  String get courierPaidOnYourWallet => 'Paid by the pharmacy to your wallet.';

  @override
  String courierPaidRides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paid rides',
      one: '1 paid ride',
      zero: 'no paid ride',
    );
    return '$_temp0';
  }

  @override
  String courierPayByCashPay(String amount) {
    return 'Pay $amount with CashPay';
  }

  @override
  String get courierPending => 'Pending';

  @override
  String courierPeopleWaiting(String city) {
    return 'people are waiting for Honam in $city, couriers and patients';
  }

  @override
  String courierPerRide(String amount) {
    return '$amount per ride';
  }

  @override
  String get courierPharmacyWrote => 'What the pharmacy wrote';

  @override
  String courierPickedUpAt(String when) {
    return 'Parcel picked up $when';
  }

  @override
  String courierPickupAt(String pharmacy) {
    return 'Pickup: $pharmacy';
  }

  @override
  String courierPlusRides(int count) {
    return '+$count rides';
  }

  @override
  String courierPositionShared(String name) {
    return 'Your position is shared with $name and the pharmacy until handover.';
  }

  @override
  String get courierProblem => 'A problem?';

  @override
  String get courierProblemDuringRide => 'A problem during the ride?';

  @override
  String get courierProposeToFriend => 'Suggest to a friend';

  @override
  String courierProposedFirst(String pharmacy) {
    return 'Offered to you first: $pharmacy invited you';
  }

  @override
  String get courierQueenUnlocked => 'Unlocked: no fault last month';

  @override
  String courierQuestionOf(int index, int total) {
    return 'Question $index of $total';
  }

  @override
  String get courierQuiz1 =>
      'The patient wants to pay you the ride in cash. What do you do?';

  @override
  String get courierQuiz1Right => 'I refuse: the pharmacy pays me';

  @override
  String get courierQuiz1Wrong => 'I accept, it’s simpler';

  @override
  String get courierQuiz2 =>
      'The patient asks you to open the parcel. What do you do?';

  @override
  String get courierQuiz2Right =>
      'The parcel stays closed: they open it after handover';

  @override
  String get courierQuiz2Wrong => 'I open it in front of them';

  @override
  String get courierQuiz3 =>
      'The patient can’t find their code. What do you do?';

  @override
  String get courierQuiz3Right =>
      'I hand over nothing without the code: they find it in their app';

  @override
  String get courierQuiz3Wrong => 'I hand over the parcel anyway';

  @override
  String get courierQuizPassed => 'Quiz passed: you know the golden rules.';

  @override
  String get courierQuizRetry =>
      'That’s not the right answer: read the rules again and retry.';

  @override
  String get courierRecommended => 'Recommended';

  @override
  String get courierReminder =>
      'Reminder: the parcel stays closed, you collect nothing from the patient, and the patient gives you the handover code.';

  @override
  String get courierRequestReview => 'Request a review';

  @override
  String get courierResendCode => 'Resend the code';

  @override
  String courierRetake(String item) {
    return 'Retake: $item';
  }

  @override
  String get courierReturnParcel => 'Take the parcel back to the pharmacy';

  @override
  String get courierReviewNotice =>
      'You can ask support for a review. Meanwhile, your chats, Kory and your Honam orders remain available.';

  @override
  String get courierReviewRequested => 'Review requested';

  @override
  String get courierRides => 'Rides';

  @override
  String courierRidesAndDefaults(int rides, int defaults) {
    return '$rides rides delivered · $defaults fault(s)';
  }

  @override
  String courierRidesLeftOf(int left, int total) {
    return '$left rides left of $total';
  }

  @override
  String courierRidesPerMonth(int count) {
    return '$count rides per month';
  }

  @override
  String get courierRule1 => 'The parcel stays closed';

  @override
  String get courierRule1Body =>
      'You see neither the prescription nor the products.';

  @override
  String get courierRule2 => 'You collect nothing from the patient';

  @override
  String get courierRule2Body =>
      'The pharmacy pays you the ride on your wallet.';

  @override
  String get courierRule3 => 'The code comes from the patient';

  @override
  String get courierRule3Body => 'It shows in their app, at handover.';

  @override
  String get courierRule4 => '3 faults, account suspended';

  @override
  String get courierRule4Body => 'With a possible appeal to support.';

  @override
  String get courierRulesAccepted => 'Golden rules accepted';

  @override
  String get courierSat => 'Sat';

  @override
  String get courierSeeAllPacks => 'See all packs';

  @override
  String get courierSeeDefault => 'See the fault';

  @override
  String get courierSelfieDone => 'Selfie taken';

  @override
  String get courierSendCode => 'Get the code by SMS';

  @override
  String get courierSendInvite => 'Send the invitation';

  @override
  String get courierSentBody =>
      'Support checks your identity within 48 hours. You get a notification as soon as your courier mode is on.';

  @override
  String get courierSentStep1 => 'Sign-up sent';

  @override
  String get courierSentStep2 => 'Identity check';

  @override
  String get courierSentStep3 => 'Courier mode on';

  @override
  String get courierSentStep3Body => 'You go “Available” whenever you want';

  @override
  String get courierShareLink => 'Share my link';

  @override
  String courierShoot(String side) {
    return 'Photograph $side';
  }

  @override
  String courierShotDone(String side) {
    return '$side · taken';
  }

  @override
  String get courierShowOrShare => 'To show, or to share as a link';

  @override
  String get courierSkip => 'Skip';

  @override
  String get courierSlots => 'Time slots';

  @override
  String get courierSmsCode => 'Code received by SMS';

  @override
  String get courierStepBefore => 'Before you start';

  @override
  String get courierStepIdentity => 'Your identity';

  @override
  String courierStepOf(int step, int total) {
    return 'Become a courier · step $step of $total';
  }

  @override
  String get courierStepRules => 'The golden rules';

  @override
  String get courierStepSent => 'Application sent';

  @override
  String get courierStepWallet => 'Where to receive your earnings';

  @override
  String get courierStepZones => 'Your areas and time slots';

  @override
  String get courierSun => 'Sun';

  @override
  String courierSuspendedLead(int count) {
    return 'You received $count confirmed faults. You no longer receive rides.';
  }

  @override
  String get courierSuspendedTitle => 'Courier account suspended';

  @override
  String get courierSuspensionScope =>
      'The suspension only affects courier mode, not your Pokou account.';

  @override
  String courierSwitchTo(String pack, String amount) {
    return 'Switch to $pack · $amount';
  }

  @override
  String get courierTakeSelfie => 'Take a selfie';

  @override
  String get courierThePatient => 'the patient';

  @override
  String get courierThenWinPokou => 'Then, Win Pokou';

  @override
  String get courierThenWinPokouCaption =>
      'Plus a pack of rides, of your choice';

  @override
  String get courierThirdDefault =>
      'At the 3rd confirmed fault, your courier account is suspended.';

  @override
  String get courierThisMonth => 'This month with Pokou';

  @override
  String get courierThu => 'Thu';

  @override
  String get courierToComplete => 'Application to complete';

  @override
  String get courierToPay => 'To pay';

  @override
  String get courierToRedo => 'To redo';

  @override
  String get courierTooYoung => 'Courier mode is not available under 18.';

  @override
  String get courierTransportBikeTitle => 'Bicycle';

  @override
  String get courierTransportMotoTitle => 'Motorbike';

  @override
  String get courierTransportNote =>
      'The rides offered take your means of transport into account. Courier mode is not available under 18.';

  @override
  String get courierTransportWalkTitle => 'On foot';

  @override
  String get courierTrial => 'Trial';

  @override
  String get courierTrialCaption => 'From approval, over one month';

  @override
  String get courierTrialEndTitle => 'Your trial is over';

  @override
  String courierTrialLeft(int left, int total) {
    return 'Trial: $left rides left of $total';
  }

  @override
  String courierTrialLeftAfter(int count) {
    return 'You will have $count trial rides left.';
  }

  @override
  String courierTrialOffered(int count) {
    return '$count free trial rides';
  }

  @override
  String get courierTrialOfferedBody =>
      'No membership or pack, over one month. Your first rides are for orders under 15,000 FCFA.';

  @override
  String courierTrialRides(int count) {
    return '$count free rides';
  }

  @override
  String courierTrialWaiting(int count) {
    return 'Once activated, $count trial rides await you, with no membership or pack.';
  }

  @override
  String courierTtc(String amount) {
    return '$amount incl. VAT';
  }

  @override
  String get courierTue => 'Tue';

  @override
  String get courierUnavailable => 'Unavailable';

  @override
  String get courierUnavailableBody =>
      'You don’t receive rides. Go “Available” when you want to deliver.';

  @override
  String get courierUnderstood => 'Understood';

  @override
  String courierUntil(String when) {
    return 'until $when';
  }

  @override
  String courierUpToKm(String km) {
    return 'up to $km km';
  }

  @override
  String get courierValidateHandover => 'Confirm handover';

  @override
  String get courierWaitingOnSite => 'Waiting on site';

  @override
  String get courierWaitlistHelps =>
      'These sign-ups help Pokou choose the next cities.';

  @override
  String get courierWaitlistJoined => 'You’ll be notified';

  @override
  String get courierWallet => 'Wallet';

  @override
  String courierWalletLabel(String wallet) {
    return 'Wallet $wallet';
  }

  @override
  String get courierWalletNotice =>
      'Pharmacies pay you directly on this wallet after each delivery. Pokou never touches this money.';

  @override
  String get courierWalletNumber => 'Wallet number';

  @override
  String get courierWalletVerified => 'Number verified by SMS.';

  @override
  String get courierWed => 'Wed';

  @override
  String courierWelcomeBody(String name) {
    return 'Your identity is verified, $name. Your courier mode is on.';
  }

  @override
  String get courierWelcomeTitle => 'Welcome to the couriers';

  @override
  String get courierWhatItCosts => 'What it costs';

  @override
  String get courierWhenAvailable => 'When are you often available?';

  @override
  String courierWriteToPatient(String name) {
    return 'Write to $name';
  }

  @override
  String get courierYouEarn => 'You earn';

  @override
  String get courierYouNeed => 'You need';

  @override
  String get courierYourCode => 'Your code';

  @override
  String courierYourCodeIs(String code) {
    return 'Your code: $code';
  }

  @override
  String get courierYourMessage => 'Your message, editable';

  @override
  String get courierYourReferrals => 'Your referrals';

  @override
  String get courierZones => 'Areas';

  @override
  String get courierZonesAndSlots => 'Areas and time slots';

  @override
  String get courierZonesNotice =>
      'These choices are used to offer you rides. You stay free: only the “Available” button counts.';

  @override
  String get courierZonesTitle => 'Neighbourhoods where you deliver';

  @override
  String get courierRideReleased =>
      'The ride goes back to the pharmacy, which reassigns it. It is not a fault.';

  @override
  String get courierParcelReturned =>
      'Take the closed parcel back to the pharmacy. It is not a fault.';

  @override
  String get courierBecomeHonam => 'Become a Honam courier';

  @override
  String get courierOfferSubtitle => 'Paid for every ride, near you';

  @override
  String get courierLaunchShort => 'Launch period · no pack';

  @override
  String courierTrialRidesLeftShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trial rides left',
      one: '1 trial ride left',
    );
    return '$_temp0';
  }

  @override
  String get courierBannerTitle => 'Earn money delivering near you';

  @override
  String get courierDiscover => 'Discover';

  @override
  String courierAfterDelivery(String who) {
    return 'Delivered by $who. You too can deliver for Honam whenever you want.';
  }

  @override
  String get courierLearnMore => 'Learn more';

  @override
  String get courierDontPropose => 'Don’t suggest again';

  @override
  String courierByAt(String name, String when) {
    return '$name $when';
  }

  @override
  String get forwardTitle => 'Forward to…';

  @override
  String get forwardLimit => 'Up to 5 chats';

  @override
  String get forwardSearch => 'Search';

  @override
  String get forwardRecent => 'Recent';

  @override
  String get forwardContacts => 'Contacts';

  @override
  String get forwardGroup => 'Group';

  @override
  String get forwardNote =>
      'The message is labelled “Forwarded”. Sent on more than 5 times, it becomes “Forwarded many times”.';

  @override
  String forwardSendTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send to $count chats',
      one: 'Send to 1 chat',
      zero: 'Choose up to 5 chats',
    );
    return '$_temp0';
  }

  @override
  String get forwardMaxReached => '5 chats at most.';

  @override
  String forwardDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Forwarded to $count chats.',
      one: 'Forwarded to 1 chat.',
    );
    return '$_temp0';
  }

  @override
  String forwardPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Could not forward to $count chats.',
      one: 'Could not forward to 1 chat.',
    );
    return '$_temp0';
  }

  @override
  String get forwardedLabel => 'Forwarded';

  @override
  String get forwardedManyLabel => 'Forwarded many times';

  @override
  String get contactAvailable => 'Available';

  @override
  String reportTitle(String name) {
    return 'Report $name';
  }

  @override
  String get reportGroup => 'Report group';

  @override
  String get reportReasonScam => 'Scam or money request';

  @override
  String get reportReasonImpersonation => 'Pretends to be someone else';

  @override
  String get reportReasonSpam => 'Spam or advertising';

  @override
  String get reportReasonShocking => 'Offensive content';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportNote =>
      'Your report goes to Pokou support with the reason you chose. Messages are attached only if you tick the box below.';

  @override
  String get reportAttachConsent =>
      'Attach the last 5 messages of this chat to help support check (they are decrypted on your phone and sent to support encrypted)';

  @override
  String get reportAlsoBlock => 'Also block this number';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSent => 'Report sent. Thank you.';

  @override
  String get reportSentBlocked => 'Report sent, number blocked.';

  @override
  String get reportFailed => 'Report not sent — check your connection.';

  @override
  String get blockedTitle => 'Blocked contacts';

  @override
  String blockedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
      zero: 'No one blocked',
    );
    return '$_temp0';
  }

  @override
  String get blockedEmpty => 'You haven\'t blocked anyone.';

  @override
  String get blockedInfo =>
      'A blocked person can\'t call or message you. They no longer see your photo, your “last seen” or your statuses. They aren\'t told.';

  @override
  String get blockedGroupsNote =>
      'Blocking also applies in shared groups: you no longer get their group calls.';

  @override
  String get blockedAdd => 'Block a contact';

  @override
  String get blockedUnblock => 'Unblock';

  @override
  String blockedUnblocked(String name) {
    return '$name is unblocked.';
  }

  @override
  String blockedOn(String date) {
    return 'Blocked on $date';
  }

  @override
  String blockedOnAfterReport(String date) {
    return 'Blocked on $date · after a report';
  }

  @override
  String get unknownSenderTitle => 'This number isn\'t in your contacts';

  @override
  String get unknownSenderBody =>
      'The name shown is chosen by the sender: it isn\'t verified. Pokou will never ask for your secret code or for money.';

  @override
  String get unknownSenderSubtitle => 'Not in your contacts';

  @override
  String get unknownSenderBlock => 'Block';

  @override
  String get unknownSenderReport => 'Report';

  @override
  String get unknownSenderAdd => 'Add';

  @override
  String get secretCodeAlertTitle => 'This message asks for a secret code.';

  @override
  String get secretCodeAlertBody => 'Never give it, not even to an agent.';

  @override
  String convEditWindow(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'For $minutes minutes after sending',
      one: 'For 1 minute after sending',
    );
    return '$_temp0';
  }

  @override
  String get messageInfoTitle => 'Message info';

  @override
  String messageInfoSentAt(String time) {
    return 'Sent $time';
  }

  @override
  String messageInfoDeliveredAt(String time) {
    return 'Delivered $time';
  }

  @override
  String messageInfoReadAt(String time) {
    return 'Read $time';
  }

  @override
  String get messageInfoSentOnly => 'Sent';

  @override
  String attachTo(String name) {
    return 'Attach to $name';
  }

  @override
  String get attachGallery => 'Gallery';

  @override
  String get attachCamera => 'Camera';

  @override
  String get attachPoll => 'Poll';

  @override
  String get attachKory => 'Kory pot';

  @override
  String get attachKoryGroupsOnly =>
      'The pot can only be created inside a group.';

  @override
  String get chatsMenuDirectChat => 'One-to-one chat';

  @override
  String get chatsMenuGroupChat => 'Group';

  @override
  String get chatsPinHint => 'Up to three pinned chats';

  @override
  String get chatsAddFavorite => 'Add to favourites';

  @override
  String get chatsRemoveFavorite => 'Remove from favourites';

  @override
  String get chatsFavoriteHint => 'Find it again in the “Favourites” filter';

  @override
  String get chatsArchiveHint => 'It leaves the list without being deleted';

  @override
  String get archivedScreenTitle => 'Archived';

  @override
  String archivedScreenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '1 chat',
      zero: 'No chats',
    );
    return '$_temp0';
  }

  @override
  String get archivedScreenNote =>
      'An archived chat stays here when a message arrives. Its content and proof mode don\'t change.';

  @override
  String get archivedScreenHelpTitle => 'Long-press a chat';

  @override
  String get archivedScreenUnarchive => 'Unarchive';

  @override
  String get archivedScreenAddFavorite => 'Add to favourites';

  @override
  String get archivedScreenEmpty => 'No archived chats.';

  @override
  String get callGroupTitle => 'Group call';

  @override
  String callParticipants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String callSpeaking(String name) {
    return '$name is speaking';
  }

  @override
  String get callPoorNetwork => 'Weak network. The call goes on.';

  @override
  String callPoorNetworkVideoPaused(String name) {
    return 'Weak network. $name\'s video is paused, the call continues as audio.';
  }

  @override
  String get callMinimize => 'Minimise';

  @override
  String get callFlipShort => 'Flip';

  @override
  String get callVideoShort => 'Video';

  @override
  String get callQuit => 'Leave';

  @override
  String get callHangUpShort => 'Hang up';

  @override
  String get callIncomingAudioTitle => 'Incoming voice call';

  @override
  String get callIncomingVideoTitle => 'Incoming video call';

  @override
  String get callIncomingPokouAudio => 'Pokou · voice call';

  @override
  String get callIncomingPokouVideo => 'Pokou · video call';

  @override
  String get callReplyWithMessage => 'Reply with a message';

  @override
  String get callReplyCallBack => 'I\'ll call you back';

  @override
  String get callReplyCantTalk => 'I can\'t talk now';

  @override
  String get callReplyWriteMe => 'Text me';

  @override
  String get callReplyFailed => 'Message not sent — the call was declined.';

  @override
  String get callDecline => 'Decline';

  @override
  String get callAccept => 'Accept';

  @override
  String get callsSearchHint => 'Search a name';

  @override
  String get callsIncoming => 'Incoming';

  @override
  String get callsOutgoing => 'Outgoing';

  @override
  String get callsGroupAudio => 'Group voice';

  @override
  String get callsGroupVideo => 'Group video';

  @override
  String callsPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String callsDurationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String callsDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String callsDurationMinSec(int minutes, String seconds) {
    return '$minutes min $seconds';
  }

  @override
  String get offlineMessagesWillSend =>
      'No connection. Your messages will go out as soon as the network is back.';

  @override
  String get groupInfoTitle => 'Group info';

  @override
  String groupInfoSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Group · $count members',
      one: 'Group · 1 member',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAudio => 'Audio';

  @override
  String get groupInfoVideo => 'Video';

  @override
  String get groupInfoAdd => 'Add';

  @override
  String get groupInfoProofOn => 'Proof mode: on';

  @override
  String get groupInfoProofOff => 'Proof mode: off';

  @override
  String get groupInfoProofHint =>
      'Any member holding the badge can turn it on';

  @override
  String get groupInfoProofEnable => 'Turn on';

  @override
  String get groupInfoProofDisable => 'Turn off';

  @override
  String get groupInfoInviteHint => 'Revocable at any time, admins only';

  @override
  String groupInfoMessage(String name) {
    return 'Message $name';
  }

  @override
  String get groupSettingsMembers => 'Members';

  @override
  String get groupSettingsAdmins => 'Admins';

  @override
  String get groupSettingsMe => 'you';

  @override
  String get groupSettingsProof => 'Proof mode';

  @override
  String get groupSettingsProofOn => 'On';

  @override
  String get groupSettingsProofOff => 'Off';

  @override
  String groupKoryOngoing(String title) {
    return 'Pot in progress · $title';
  }

  @override
  String groupKoryProgress(String collected, String goal) {
    return '$collected of $goal FCFA';
  }

  @override
  String groupKoryCollected(String collected) {
    return '$collected FCFA confirmed';
  }

  @override
  String groupKoryCloses(String date) {
    return 'closes $date';
  }

  @override
  String get contactNotifications => 'Notifications';

  @override
  String get contactNotificationsOn => 'On';

  @override
  String get contactNotificationsMuted => 'Muted';

  @override
  String get contactInfoTitle => 'Contact info';

  @override
  String get composerWriteHint => 'Write a message…';

  @override
  String newChatOnPokouCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts on Pokou',
      one: '1 contact on Pokou',
      zero: 'No contacts on Pokou',
    );
    return '$_temp0';
  }

  @override
  String get newChatNewGroupHint => 'Bring your people into one chat';

  @override
  String get newChatInviteRow => 'Invite to Pokou';

  @override
  String get newChatInviteRowHint => 'Share an invite link';

  @override
  String get newChatOnPokouSection => 'Contacts on Pokou';

  @override
  String get mentionPickerTitle => 'Mention';

  @override
  String statusReplyCardTitle(String name) {
    return '$name · Status';
  }

  @override
  String get statusReplyCardMine => 'Your status';

  @override
  String statusReplyNotice(String name) {
    return 'Your reply to $name\'s status arrived here, in private. Other contacts don\'t see it.';
  }

  @override
  String get proofEditNote =>
      'Proof mode is on. The original version of your message will stay visible to both of you, with the time of the edit.';

  @override
  String get pollKindSingle => 'Poll · single choice';

  @override
  String get pollKindMultiple => 'Poll · multiple choice';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes',
    );
    return '$_temp0';
  }

  @override
  String get pollSeeVotes => 'See votes';

  @override
  String get pollVoterUnknown => 'A member';

  @override
  String get searchScopeAll => 'All';

  @override
  String get searchScopeChats => 'Chats';

  @override
  String get searchScopeMessages => 'Messages';

  @override
  String get searchScopePhotos => 'Photos';

  @override
  String get searchScopeLinks => 'Links';

  @override
  String get searchChatsSection => 'Chats';

  @override
  String searchMessagesSection(int count) {
    return 'Messages · $count';
  }

  @override
  String searchPhotosSection(int count) {
    return 'Photos · $count';
  }

  @override
  String searchLinksSection(int count) {
    return 'Links · $count';
  }

  @override
  String searchLastMessage(String text) {
    return 'Last message: $text';
  }

  @override
  String get viewerReply => 'Reply';

  @override
  String get viewerForward => 'Forward';

  @override
  String get viewerSave => 'Save';

  @override
  String get viewerReact => 'React';

  @override
  String viewerSubtitle(String place, String when) {
    return '$place · $when';
  }

  @override
  String composerSendTo(String name) {
    return 'Send to $name';
  }

  @override
  String get composerCompressedNote =>
      'Photos are compressed to save your data.';

  @override
  String groupMembersChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members chosen',
      one: '1 member chosen',
      zero: 'No members chosen',
    );
    return '$_temp0';
  }

  @override
  String groupMembersSection(int count) {
    return 'Members · $count';
  }

  @override
  String get groupNewAdminsOnly => 'Only admins edit the group';

  @override
  String get groupNewAdminsOnlyHint => 'Name, photo and description';

  @override
  String get groupNewInviteHint => 'Revocable at any time';

  @override
  String get groupNewFootnote =>
      'You manage the group and can appoint other admins. Each member is told they were added.';

  @override
  String get groupNewCreate => 'Create group';

  @override
  String get groupNoPokouContacts =>
      'None of your contacts is on Pokou yet. Invite them to create a group.';

  @override
  String get groupCreateSettingsFailed =>
      'Group created. The photo or a setting could not be applied: try again from Group info.';

  @override
  String get newChatNotOnPokou => 'Not on Pokou yet';

  @override
  String reportGroupNamed(String name) {
    return 'Report $name';
  }

  @override
  String get groupLeaveLot1Note =>
      'Leaving the group keeps your messages with the other members. Admins are notified.';

  @override
  String get offiChatPatientSubtitle => 'Patient · order conversation';

  @override
  String offiChatPatientNotice(String patient) {
    return 'Conversation between the pharmacy and $patient. The courier does not see it. Numbers stay hidden.';
  }

  @override
  String offiChatWithPatient(String patient) {
    return 'Write to $patient';
  }

  @override
  String offiPatientWriteToCourier(String courier) {
    return 'Write to $courier';
  }

  @override
  String get assimeFilters => 'Filters';

  @override
  String assimeFiltersCount(int count) {
    return 'Filters · $count';
  }

  @override
  String get assimeFiltersClear => 'Clear';

  @override
  String get assimeFilterCategory => 'Category';

  @override
  String get assimeFilterPrice => 'Price';

  @override
  String get assimeFilterMin => 'Minimum';

  @override
  String get assimeFilterMax => 'Maximum';

  @override
  String get assimeFilterCondition => 'Condition';

  @override
  String get assimeConditionNew => 'New';

  @override
  String get assimeConditionVeryGood => 'Very good condition';

  @override
  String get assimeConditionGood => 'Good condition';

  @override
  String get assimeConditionToRepair => 'Needs repair';

  @override
  String get assimeFilterPublished => 'Posted';

  @override
  String get assimeFilterPublishedAny => 'Any time';

  @override
  String assimeFilterPublishedDays(int days) {
    return 'Less than $days days ago';
  }

  @override
  String get assimeFilterCertified => 'Certified sellers only';

  @override
  String get assimeFilterCertifiedSub => 'Pokou certified or Pro badge';

  @override
  String get assimeFilterApply => 'See listings';

  @override
  String assimeResultsCount(int count) {
    return '$count listings';
  }

  @override
  String get assimeSortRecent => 'Most recent';

  @override
  String get assimeSortPriceAsc => 'Price: low to high';

  @override
  String get assimeSortPriceDesc => 'Price: high to low';

  @override
  String get assimeReportListing => 'Report this listing';

  @override
  String get assimeReportScam => 'Scam or payment asked in advance';

  @override
  String get assimeReportForbidden => 'Prohibited item';

  @override
  String get assimeReportForbiddenSub => 'Medicine, weapon, protected animal…';

  @override
  String get assimeReportCounterfeit => 'Counterfeit';

  @override
  String get assimeReportMisleading => 'Misleading or already sold';

  @override
  String get assimeReportOther => 'Other';

  @override
  String get assimeReportNote =>
      'The seller is not told about your report. A listing reported several times is hidden until it is reviewed.';

  @override
  String get assimeReportSend => 'Send report';

  @override
  String get assimeReportSent =>
      'Thanks, your report has been sent to the Pokou team.';

  @override
  String get assimeShareTitle => 'Share this listing';

  @override
  String get assimeShareChat => 'A chat';

  @override
  String get assimeShareCopy => 'Copy link';

  @override
  String get assimeShareOther => 'Other apps';

  @override
  String get assimeShareCopied => 'Copied';

  @override
  String assimeShareSent(String name) {
    return 'Listing sent to $name';
  }

  @override
  String get assimeShareNote =>
      'Outside Pokou, the link only opens a limited preview: photo, title, price and area. To write to the seller, you need Pokou.';

  @override
  String assimeShareText(String name, String price, String link) {
    return '$name · $price on Assimé, Pokou\'s classifieds: $link';
  }

  @override
  String get assimeShareNoContact => 'No contacts on Pokou yet.';

  @override
  String get assimePreviewTitle => 'Preview';

  @override
  String assimePublishStep(int step) {
    return 'Post a listing · step $step of 3';
  }

  @override
  String get assimePreviewWhat => 'What buyers will see.';

  @override
  String get assimePreviewExpiry =>
      'Online for 30 days, then the listing expires; you can renew it.';

  @override
  String get assimePreviewPledge =>
      'My listing contains no medicine, weapon, counterfeit or protected animal.';

  @override
  String get assimePreviewBoost => 'Promote';

  @override
  String get assimePreviewBoostSub =>
      'From 600 FCFA for 3 days, at the top of results. You choose after posting.';

  @override
  String get assimePublishListing => 'Post the listing';

  @override
  String get assimeSeePreview => 'See preview';

  @override
  String get assimeNegotiable => 'Price negotiable';

  @override
  String get assimeNegotiableSub => 'The price shows “negotiable”';

  @override
  String get assimeNegotiableTag => 'negotiable';

  @override
  String get assimeForbiddenTitle => 'Medicines are not sold on Assimé';

  @override
  String get assimeForbiddenBody =>
      'For a medicine, use Honam: a pharmacy sends you a quote and a courier delivers it.';

  @override
  String get assimeGoHonam => 'Go to Honam';

  @override
  String get assimeAlsoForbidden => 'Also prohibited on Assimé';

  @override
  String get assimeForbiddenWeapons => 'Weapons and ammunition';

  @override
  String get assimeForbiddenCounterfeit => 'Counterfeits';

  @override
  String get assimeForbiddenAnimals => 'Protected animals';

  @override
  String get assimeChangeItem => 'Change item';

  @override
  String assimeReviewsTitle(String name) {
    return 'Reviews of $name';
  }

  @override
  String assimeReviewsCount(int count) {
    return '$count rated sales';
  }

  @override
  String assimeReviewReplyFrom(String name) {
    return 'Reply from $name: ';
  }

  @override
  String get assimeReportReview => 'Report a review';

  @override
  String get assimeReviewReported => 'Review reported to the Pokou team.';

  @override
  String get assimeSeeReviews => 'See reviews';

  @override
  String get assimeNoReviews =>
      'No reviews yet. Only the buyer of a sale confirmed by the seller can rate.';

  @override
  String get assimeReplyAction => 'Reply';

  @override
  String get assimeReplyHint => 'Your reply, visible to everyone';

  @override
  String get assimeContactSeller => 'Contact the seller';

  @override
  String get assimeNoPaymentNotice =>
      'Pokou takes no payment on Assimé. See the item before paying, in a public place.';

  @override
  String assimeSellerListings(int count) {
    return '$count listings';
  }

  @override
  String assimeRateInvite(String seller, String price) {
    return '$seller says you bought this item for $price.';
  }

  @override
  String get assimeMyListings => 'My listings';

  @override
  String assimeMyListingsSub(String name, int count) {
    return '$name · $count listings';
  }

  @override
  String assimeTabOnline(int count) {
    return 'Online · $count';
  }

  @override
  String assimeTabSold(int count) {
    return 'Sold · $count';
  }

  @override
  String assimeTabExpired(int count) {
    return 'Expired · $count';
  }

  @override
  String assimeBadgeSponsored(int days) {
    return 'Sponsored · $days d';
  }

  @override
  String assimeBadgeExpiresIn(int days) {
    return 'Expires in $days days';
  }

  @override
  String get assimeBadgeOnline => 'Online';

  @override
  String get assimeBadgeExpired => 'Expired';

  @override
  String get assimeBadgeSold => 'Sold';

  @override
  String assimeStatsLine(int views, int favorites, int messages) {
    return '$views views · $favorites favourites · $messages messages';
  }

  @override
  String get assimeMarkSold => 'Mark as sold';

  @override
  String get assimeRenew => 'Renew';

  @override
  String get assimeRenewed => 'Listing renewed for 30 days.';

  @override
  String get assimePromote => 'Promote';

  @override
  String get assimeStatsPrivate =>
      'Views and favourites are visible only to you.';

  @override
  String get assimePublishCta => 'Post a listing';

  @override
  String get assimeNoneInTab => 'Nothing here yet.';

  @override
  String get assimeDeleteTitle => 'Delete this listing?';

  @override
  String get assimeDeleteNotSelling => 'I’m no longer selling it';

  @override
  String get assimeDeleteSoldPokou => 'Sold on Pokou';

  @override
  String get assimeDeleteSoldPokouSub => 'Choose the buyer so they can rate';

  @override
  String get assimeDeleteSoldElsewhere => 'Sold elsewhere';

  @override
  String get assimeDeleteNote =>
      'Related chats stay in your Chats. This cannot be undone.';

  @override
  String get assimeDeleteAction => 'Delete listing';

  @override
  String get assimeEditTitle => 'Edit listing';

  @override
  String get assimeSaveChanges => 'Save changes';

  @override
  String get assimeTitleLabel => 'Title';

  @override
  String get assimeAreaLabel => 'City and area';

  @override
  String get assimeSavedSearches => 'Saved searches';

  @override
  String get assimeFavoriteListings => 'Favourite listings';

  @override
  String assimeAlertFound(int count) {
    return '$count listings found';
  }

  @override
  String get assimeAlertPaused => 'Alert off';

  @override
  String get assimeWhyPrivacy =>
      'Pokou never reads your messages or statuses to choose ads. At most one sponsored status every 5 statuses.';

  @override
  String get assimeHideListing => 'Hide this listing';

  @override
  String get assimeHideSeller => 'Stop seeing this seller’s listings';

  @override
  String get assimeHidden => 'Listing hidden.';

  @override
  String get assimeSellerHidden =>
      'You won’t see this seller’s listings any more.';

  @override
  String get assimeProfileTitle => 'Profile';

  @override
  String assimePrivateSince(String date) {
    return 'Private seller · on Pokou since $date';
  }

  @override
  String assimeProSince(String date) {
    return 'Pro seller · on Pokou since $date';
  }

  @override
  String assimeRatedSales(int count) {
    return '$count rated sales';
  }

  @override
  String get assimeMessage => 'Message';

  @override
  String get assimeReport => 'Report';

  @override
  String assimeListingsOf(String name, int count) {
    return '$name’s listings · $count';
  }

  @override
  String get assimeBadgeNote =>
      'The badge shows a name verified by Pokou certified. A private seller has no Pro badge.';

  @override
  String get assimeBoostRunning => 'Promotion running';

  @override
  String get assimeBoostEnded => 'Promotion ended';

  @override
  String assimeBoostSub(String name, int days) {
    return '$name · $days days';
  }

  @override
  String assimeBoostDayOf(int day, int total) {
    return 'Day $day of $total';
  }

  @override
  String assimeBoostEnds(String date) {
    return 'ends $date';
  }

  @override
  String get assimeViewsResults => 'Views in results';

  @override
  String get assimeViewsStatus => 'Views in status';

  @override
  String get assimeOpens => '“See listing”';

  @override
  String get assimeMessagesReceived => 'Messages received';

  @override
  String assimeMessagesBefore(int count) {
    return 'vs $count before';
  }

  @override
  String get assimeViewsPerDay => 'Views per day';

  @override
  String get assimeLegendResults => 'Results';

  @override
  String get assimeLegendStatus => 'Statuses';

  @override
  String get assimeBoostNote =>
      'Only you can see these figures. No automatic renewal: you’ll choose at the end.';

  @override
  String get assimeSeeListing => 'See listing';

  @override
  String get assimeBeforeBuying => 'Before you buy';

  @override
  String get assimeTipPublicPlace =>
      'Meet the seller in a public place, during the day.';

  @override
  String get assimeTipNoAdvance => 'Never pay in advance: see the item first.';

  @override
  String get assimeTipNoCode =>
      'Pokou takes no payment and will never ask for your PIN.';

  @override
  String get assimeNumberHidden => 'Your number is not shown to the seller.';

  @override
  String get assimeQuickPhotos => 'More photos?';

  @override
  String get assimeQuickAvailable => 'Still available?';

  @override
  String get assimeQuickNegotiable => 'Is the price negotiable?';

  @override
  String get assimeSee => 'See';

  @override
  String assimePromoteDays(int days) {
    return '$days days';
  }

  @override
  String get assimePromoteTop =>
      'At the top of its category’s results, in its city';

  @override
  String get assimePromoteStatus =>
      'A spot among the statuses of buyers in its city';

  @override
  String get assimePromoteCheaper =>
      'Cheaper per day · paid badge required for statuses';

  @override
  String get assimePromoteTtc =>
      'Prices include tax. Your listing is labelled “Sponsored”. No automatic renewal.';

  @override
  String get assimePromoteStart => 'Start';

  @override
  String get assimePromoteStartNow => 'Once confirmed';

  @override
  String get assimePromoteEnd => 'End';

  @override
  String get assimePromotePayment => 'Payment';

  @override
  String get assimePromotePaymentMm => 'Mobile Money';

  @override
  String get assimePromoteModeration =>
      'The status spot is checked by moderation before it is shown. A prohibited category can never be promoted.';

  @override
  String assimePromotePay(String amount) {
    return 'Pay $amount FCFA';
  }

  @override
  String get assimeAdAssime => 'Assimé listing';

  @override
  String get assimeWrite => 'Write';

  @override
  String get assimeNextHint => 'Tap on the right to go to the next status.';

  @override
  String get assimeCover => 'Cover';

  @override
  String get assimeAddPhotoShort => 'Add';

  @override
  String assimePhotosHint(int count) {
    return '$count photos of 5. The first is the cover. More photos can be sent in the chat with the buyer.';
  }

  @override
  String get assimeNumberNeverShown =>
      'Your number is never shown: buyers write to you on Pokou.';

  @override
  String get assimeContinue => 'Continue';

  @override
  String get assimeStep1Title => 'Photos and category';

  @override
  String get assimeStep2Title => 'Price, condition and place';

  @override
  String get assimeToday => 'today';

  @override
  String get assimeYesterday => 'yesterday';

  @override
  String get assimeNearYou => 'Near you';

  @override
  String get assimeSoldBadge => 'Sold';

  @override
  String get courierInviteCardLabel => 'Honam courier invitation';

  @override
  String courierInviteCardTitle(String name) {
    return '$name invites you to deliver for Honam';
  }

  @override
  String courierInviteCardTitleMine(String name) {
    return 'You invite $name to deliver for Honam';
  }

  @override
  String courierInviteCardCode(String code) {
    return 'code $code';
  }

  @override
  String get courierInviteSeeOffer => 'See the offer';

  @override
  String courierInviteHello(String name) {
    return 'Hi $name!';
  }

  @override
  String get courierInviteHelloAll => 'Hi!';

  @override
  String courierInviteBody(String amount, String code) {
    return 'I deliver for Honam with Pokou: $amount per ride, close to home, whenever you want. Join me with my code $code.';
  }

  @override
  String courierInviteBodyNoPrice(String code) {
    return 'I deliver for Honam with Pokou: paid for every ride, close to home, whenever you want. Join me with my code $code.';
  }

  @override
  String courierInviteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations were not sent. Try again.',
      one: 'One invitation was not sent. Try again.',
    );
    return '$_temp0';
  }

  @override
  String courierInviteSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations sent',
      one: 'Invitation sent',
    );
    return '$_temp0';
  }

  @override
  String courierInviteSendTo(String name) {
    return 'Send to $name';
  }

  @override
  String courierInviteSendToCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send to $count contacts',
      one: 'Send to 1 contact',
    );
    return '$_temp0';
  }

  @override
  String get courierInviteSearch => 'Search for a contact';

  @override
  String get courierInviteOnPokou => 'On Pokou';

  @override
  String get courierInviteBySms => 'Not on Pokou yet · invitation by SMS';

  @override
  String get courierInviteNoContact =>
      'No contact found. With no contact ticked, your message goes through your phone’s share menu.';

  @override
  String get courierInviteCardAdded =>
      'The “Become a Honam courier” card is added to the message.';

  @override
  String courierInviteFriendNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You get $count free rides when your friend completes their first delivery. The invitation only goes to people aged 18 and over, in a city where Honam is open.',
      one: 'You get 1 free ride when your friend completes their first delivery. The invitation only goes to people aged 18 and over, in a city where Honam is open.',
    );
    return '$_temp0';
  }

  @override
  String courierInviteCodeApplied(String code) {
    return 'Code $code applied';
  }

  @override
  String get courierInviteNeeds =>
      'You need to be 18 or over, with an ID document, a smartphone and a mobile money wallet. A motorbike, a bike, or your feet for nearby rides.';

  @override
  String get courierInviteTrialCaption =>
      'As soon as your registration is approved, with no membership or pack';

  @override
  String get courierInviteSimpleRides => 'Simple first rides';

  @override
  String get courierInviteSimpleRidesCaption =>
      'Orders under 15,000 FCFA, while you find your bearings';

  @override
  String courierInviteRecommended(String name) {
    return '$name recommended you';
  }

  @override
  String courierInviteRecommendedCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They get $count free rides when you complete your first delivery',
      one: 'They get 1 free ride when you complete your first delivery',
    );
    return '$_temp0';
  }
}
