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
  String get navStatus => 'Updates';

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
  String get chatsPinLimit =>
      'Three chats are already pinned — that\'s the maximum.';

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
  String get marketCityOrArea => 'City or neighbourhood';

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
  String get versesMorning => '☀️ Morning verse';

  @override
  String get versesEvening => '🌙 Evening verse';

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
      'Messages in this group are end-to-end encrypted: only its members can read them, not even Pokou. Keys change whenever someone joins or leaves.';

  @override
  String get botLabel => 'Bot';

  @override
  String get botConversationNotice =>
      'You are writing to a business\'s bot. These messages are not end-to-end encrypted: the business reads what you send.';

  @override
  String get groupAdminsOnly => 'Only admins can post in announcements.';

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
  String get storageMobileData => 'Mobile data';

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
  String get marketSearchHint => 'Search for a product…';

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
  String get msgNotSentRetry => 'Not sent — tap to retry';

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
  String get audienceOnly => 'Only…';

  @override
  String get audienceContactsDesc => 'Everyone in your Pokou address book';

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
  String get statusFeedTitle => 'Updates';

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
      'This person isn\'t using a version of Pokou that encrypts yet. Your messages travel unencrypted.';

  @override
  String get e2eeIdentityChangedTitle =>
      'This contact\'s security information has changed';

  @override
  String e2eeIdentityChangedBody(String name) {
    return '$name\'s key is no longer the same. This happens when someone reinstalls Pokou or changes phone — but also if someone steps in between. Check with $name by another means before continuing.';
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
  String get statusMineTitle => 'My update';

  @override
  String get statusMineBody => 'Tap to post an update (24 h)';

  @override
  String get statusMineVisibility => 'Visible to my contacts';

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
      'Messages in this chat are end-to-end encrypted: no one, not even Pokou, can read them. Photos, files and calls are too when you both have an up-to-date version of Pokou and have already messaged each other.';

  @override
  String get chatsEncryptionFooter =>
      'Your private chats are end-to-end encrypted: messages, and — with an up-to-date Pokou on both sides — photos, files and calls once you have messaged each other.';

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
  String get mediaCall => '📞 Call';

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
  String get koryDeclareTitle => 'Declare a contribution';

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
  String get koryCreateTitle => 'New pot';

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
  String get onbProfileBody => 'This is the name your contacts will see.';

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
  String get onbOptional => 'Optional, can be changed anytime in settings';

  @override
  String get onbAnalytics => 'Share usage statistics to improve Pokou';

  @override
  String get onbMarketing => 'Receive news and offers from Pokou';

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
  String get honamCode => 'Handover code';

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
      'The badge proves your name is really yours. Proof mode keeps deleted group messages visible, struck through.';

  @override
  String get certHowItWorks =>
      'Your identity is verified by the name of the wallet holder who pays.';

  @override
  String certStartTrial(String days) {
    return 'Try for $days days';
  }

  @override
  String get certTrialNote =>
      'During the trial, proof mode is available; the badge appears at the first payment.';

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
      'Proof mode on: a deleted message stays visible, struck through, for everyone.';

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
      'Proof mode is on: the message will stay visible, struck through, for all members.';

  @override
  String get deletedKept => 'Deleted message, kept by proof mode';

  @override
  String get certCorrectName => 'Holder\'s full name';

  @override
  String get certRetryName => 'Check this name';

  @override
  String get certStillMismatch => 'This name still doesn\'t match.';

  @override
  String get proofExport => 'Export the chat (PDF)';

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
      'I\'m Baba, Pokou\'s assistant. What should we call you?';

  @override
  String get onbContactsTitle => 'Find your people';

  @override
  String get onbContactsBody =>
      'Baba can find which of your contacts are already on Pokou. You can say no: we\'ll ask again later.';

  @override
  String get onbContactsAllow => 'Allow';

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
  String get honamReferralTitle => 'Refer a courier';

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
  String get honamTrackingShowMap => 'Show on the map';

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
  String get assimeWhyTitle => 'Why am I seeing this';

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
}
