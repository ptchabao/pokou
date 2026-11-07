// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LAr extends L {
  LAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Pokou';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionSearch => 'بحث';

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionRemove => 'إزالة';

  @override
  String get actionSend => 'إرسال';

  @override
  String get actionJoin => 'انضمام';

  @override
  String get actionCreate => 'إنشاء';

  @override
  String get navChats => 'المحادثات';

  @override
  String get navStatus => 'الأخبار';

  @override
  String get navCalls => 'المكالمات';

  @override
  String get navMarket => 'السوق';

  @override
  String get chatsEmptyTitle => 'لا توجد محادثات';

  @override
  String get chatsEmptyBody => 'ستظهر محادثاتك هنا.';

  @override
  String get chatsSearchHint => 'بحث';

  @override
  String get chatsTyping => 'يكتب…';

  @override
  String chatsTypingNamed(String name) {
    return '$name يكتب…';
  }

  @override
  String get chatsUnknownContact => 'ليس في جهات اتصالك';

  @override
  String get chatsNoMessageYet => 'لا توجد رسائل بعد';

  @override
  String chatsYouPrefix(String message) {
    return 'أنت: $message';
  }

  @override
  String chatsGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة',
      many: '$count مجموعة',
      few: '$count مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
      zero: 'لا توجد مجموعات',
    );
    return '$_temp0';
  }

  @override
  String get newChatTitle => 'محادثة جديدة';

  @override
  String get newChatSearchHint => 'ابحث عن جهة اتصال';

  @override
  String get newChatNewGroup => 'مجموعة جديدة';

  @override
  String get newChatNewCommunity => 'مجتمع جديد';

  @override
  String get newChatJoinByLink => 'الانضمام عبر رابط';

  @override
  String get newChatOnPokou => 'على Pokou Messenger';

  @override
  String get newChatInvite => 'دعوة إلى Pokou Messenger';

  @override
  String get newChatNoMatch => 'لا توجد جهة اتصال مطابقة.';

  @override
  String get newChatNoRegisteredContact =>
      'لا أحد من جهات اتصالك يستخدم Pokou بعد.';

  @override
  String conversationSayHello(String name) {
    return 'ألقِ التحية على $name.';
  }

  @override
  String get conversationMessageHint => 'رسالة';

  @override
  String get conversationEdit => 'تعديل';

  @override
  String get conversationForward => 'إعادة توجيه';

  @override
  String get conversationReply => 'رد';

  @override
  String get conversationEditWindowOver => 'لم يعد بالإمكان تعديل هذه الرسالة.';

  @override
  String get mediaPhoto => 'صورة';

  @override
  String get mediaVideo => 'فيديو';

  @override
  String get mediaVoice => 'رسالة صوتية';

  @override
  String get mediaDocument => 'مستند';

  @override
  String get mediaLocation => 'الموقع';

  @override
  String get offlineTitle => 'غير متصل';

  @override
  String get offlineBody =>
      'سترى ما هو محفوظ على هذا الجهاز. الباقي سيصل عند عودة الشبكة.';

  @override
  String get offlineNothingCached => 'لا يوجد شيء محفوظ على هذا الجهاز بعد.';

  @override
  String get offlineSending => 'في انتظار الإرسال';

  @override
  String get errorNetwork => 'تعذّر الاتصال. تحقّق من الشبكة.';

  @override
  String get twoStepTitle => 'التحقق بخطوتين';

  @override
  String get twoStepBody => 'هذا الحساب محمي برمز. أدخله لإكمال تسجيل الدخول.';

  @override
  String get twoStepHint => 'رمز الحساب';

  @override
  String get errorGeneric => 'حدث خطأ ما.';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileLanguage => 'اللغة';

  @override
  String get profileLanguageSystem => 'لغة الهاتف';

  @override
  String get profileLanguageSubtitle => 'اختر لغة التطبيق';

  @override
  String get languageFrench => 'الفرنسية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageSpanish => 'الإسبانية';

  @override
  String get languageRussian => 'الروسية';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageItalian => 'الإيطالية';

  @override
  String get sparkTitle => 'Spark';

  @override
  String get sparkSubtitle => 'موعد اليوم';

  @override
  String get sparkTabDiscover => 'استكشاف';

  @override
  String get sparkTabMatches => 'التطابقات';

  @override
  String get sparkTabDates => 'المواعيد';

  @override
  String get sparkTabMe => 'أنا';

  @override
  String get sparkAddPhoto => 'إضافة صورة';

  @override
  String get sparkNoPhotoWarning => 'أضف صورة — بدونها لا يكاد أحد يعجب بك';

  @override
  String sparkPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة',
      many: '$count صورة',
      few: '$count صور',
      two: 'صورتان',
      one: 'صورة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get sparkLike => 'إعجاب';

  @override
  String get sparkPass => 'تخطي';

  @override
  String get sparkAgeRestricted => 'Spark مخصّص لمن هم فوق 18 عامًا.';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get authWelcome => 'مرحبًا بك في Pokou';

  @override
  String get authSubtitle =>
      'أدخل رقمك وسنرسل إليك رمزًا. جديد على Pokou؟ يُنشأ حسابك في هذه الخطوة.';

  @override
  String get authPhoneHint => 'رقمك';

  @override
  String get authPrivacyNote =>
      'تسجيل دخول آمن. يُستخدم رقمك للتحقق من هويتك فقط.';

  @override
  String get authVerifyTitle => 'التحقق';

  @override
  String authCodeSentTo(String phone) {
    return 'أدخل الرمز المكوّن من 6 أرقام المُرسل إلى $phone';
  }

  @override
  String get authChangeNumber => 'تغيير الرقم';

  @override
  String authResendIn(String time) {
    return 'إعادة إرسال الرمز خلال $time';
  }

  @override
  String get authResendSms => 'إعادة الإرسال برسالة نصية';

  @override
  String get authResendWhatsapp => 'إعادة الإرسال عبر واتساب';

  @override
  String get authCodeSentSms => 'تم إرسال رمز جديد برسالة نصية.';

  @override
  String get authCodeSentWhatsapp => 'تم إرسال رمز جديد عبر واتساب.';

  @override
  String get chatsPin => 'تثبيت';

  @override
  String get chatsUnpin => 'إلغاء التثبيت';

  @override
  String get chatsArchive => 'أرشفة';

  @override
  String get chatsUnarchive => 'إلغاء الأرشفة';

  @override
  String get chatsMute => 'كتم';

  @override
  String get chatsUnmute => 'إلغاء الكتم';

  @override
  String get chatsTag => 'وسم';

  @override
  String chatsTagNamed(String name) {
    return 'وسم $name';
  }

  @override
  String get chatsBlock => 'حظر';

  @override
  String chatsBlockTitle(String name) {
    return 'حظر $name؟';
  }

  @override
  String get chatsBlockBody =>
      'لن يتمكّن هذا الشخص من مراسلتك أو الاتصال بك. ولن يُبلَّغ بذلك.';

  @override
  String get chatsPinLimit =>
      'هناك ثلاث محادثات مثبّتة بالفعل، وهو الحد الأقصى.';

  @override
  String get chatsMute8h => '٨ ساعات';

  @override
  String get chatsMute1w => 'أسبوع واحد';

  @override
  String get chatsMuteAlways => 'دائمًا';

  @override
  String get chatsAddContact => 'إضافة إلى جهات اتصالي';

  @override
  String get chatsActionFailed => 'تعذّر تنفيذ ذلك الآن.';

  @override
  String get chatsNoResult => 'لا توجد نتائج.';

  @override
  String get chatsConnectFailed => 'تعذّر الاتصال.';

  @override
  String get navModules => 'الوحدات';

  @override
  String get navBroadcasts => 'قوائم البث';

  @override
  String get navYou => 'أنت';

  @override
  String get convProductFallback => 'منتج';

  @override
  String get convOrderUpdated => 'تم تحديث الطلب';

  @override
  String get convReactionFailed => 'تعذّر إضافة التفاعل.';

  @override
  String get convPermissionDenied => 'تم رفض الإذن.';

  @override
  String get convAttachDocument => 'مستند';

  @override
  String get convAttachGallery => 'صورة (المعرض)';

  @override
  String get convAttachVideo => 'فيديو (المعرض)';

  @override
  String get convAttachCamera => 'الكاميرا';

  @override
  String get convEditTitle => 'تعديل الرسالة';

  @override
  String get convEditHint => 'رسالتك';

  @override
  String convForwarded(String name) {
    return 'تمت إعادة توجيه الرسالة إلى $name.';
  }

  @override
  String get convForwardFailed => 'تعذّرت إعادة التوجيه.';

  @override
  String get convRecordVoice => 'تسجيل رسالة صوتية';

  @override
  String get mediaVoiceNote => 'رسالة صوتية';

  @override
  String get mediaMessage => 'رسالة';

  @override
  String get newChatInviteAction => 'دعوة';

  @override
  String get profileGallery => 'المعرض';

  @override
  String get profileCamera => 'الكاميرا';

  @override
  String get profileEdit => 'تعديل الملف الشخصي';

  @override
  String get profileFullName => 'الاسم الكامل';

  @override
  String get profileAbout => 'نبذة';

  @override
  String get profileUpdateFailed => 'تعذّر التحديث.';

  @override
  String get profileVerifiedPhone => 'تم التحقق من الهوية عبر الهاتف';

  @override
  String get profilePrivacySecurity => 'الخصوصية والأمان';

  @override
  String get profileShieldMode => 'وضع الدرع';

  @override
  String get profileShieldOn => 'تم تفعيل وضع الدرع';

  @override
  String get profileShieldOff => 'تم إيقاف وضع الدرع';

  @override
  String get profileConnection => 'الاتصال';

  @override
  String get profileEncryptedTls => 'مشفّر (TLS)';

  @override
  String get profileStatusVisibility => 'ظهور الحالات';

  @override
  String get commonEnabled => 'مفعّل';

  @override
  String get commonDisabled => 'معطّل';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String get profileDevices => 'الأجهزة المرتبطة';

  @override
  String get profileNotifications => 'الإشعارات';

  @override
  String get profileStorage => 'التخزين والبيانات';

  @override
  String get profileDataSaver => 'توفير البيانات';

  @override
  String get profileSystemPrefs => 'تفضيلات النظام';

  @override
  String get profileSignOut => 'تسجيل الخروج';

  @override
  String modulesActivated(String name) {
    return 'تم تفعيل $name.';
  }

  @override
  String get modulesUnavailable => 'الوحدات غير متاحة';

  @override
  String get modulesCheckNetwork => 'تحقّق من اتصالك وأعد المحاولة.';

  @override
  String get modulesEmptyTitle => 'لا شيء للإضافة الآن';

  @override
  String get modulesEmptyBody =>
      'ستظهر الوحدات الجديدة هنا. لا شيء عليك فعله في الأثناء.';

  @override
  String get modulesMine => 'تطبيقاتي';

  @override
  String get modulesRecommended => 'مُوصى بها';

  @override
  String get modulesRecommendedBy => 'من اختيار فريقنا';

  @override
  String get modulesPopular => 'الأكثر رواجًا';

  @override
  String get modulesPopularSub => 'الأكثر تفعيلًا الآن';

  @override
  String get modulesEnable => 'تفعيل';

  @override
  String get modulesDisable => 'إيقاف';

  @override
  String get modulesEnableFailed => 'تعذّر التفعيل.';

  @override
  String modulesComingSoon(String name) {
    return '$name قريبًا. حدّث التطبيق للحصول عليه فور صدوره.';
  }

  @override
  String modulesUserCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص يستخدمونها',
      many: '$count شخصًا يستخدمونها',
      few: '$count أشخاص يستخدمونها',
      two: 'شخصان يستخدمانها',
      one: 'شخص واحد يستخدمها',
    );
    return '$_temp0';
  }

  @override
  String get sparkEnableLocation => 'فعّل تحديد الموقع على هاتفك.';

  @override
  String get sparkLocationNeeded =>
      'بدون الموقع، لا يمكن لـ Spark معرفة من حولك.';

  @override
  String get sparkLocationFailed => 'تعذّر تحديد موقعك.';

  @override
  String get sparkFeedUnavailable => 'التدفّق غير متاح';

  @override
  String get sparkPickIntentTitle => 'اختر بطاقة اليوم';

  @override
  String get sparkPickIntentBody =>
      'قل ما تبحث عنه اليوم لترى من يبحث عن الشيء نفسه.';

  @override
  String get sparkLocationStale => 'موقعك غير محدَّث';

  @override
  String get sparkLocationStaleBody =>
      'يعرض Spark الأشخاص ضمن 5 كم فقط. بدون موقع حديث لا يمكنه عرض شيء.';

  @override
  String get sparkShareLocation => 'مشاركة موقعي';

  @override
  String get sparkQuotaTitle => 'شاهدت ملفات اليوم';

  @override
  String get sparkQuotaBody => 'عد غدًا، أو احصل على Spark+ للتصفّح بلا حدود.';

  @override
  String get sparkNobodyTitle => 'لا أحد الآن';

  @override
  String get sparkNobodyBody =>
      'قلّة تبحث عن الشيء نفسه هنا والآن. حاول لاحقًا أو غيّر بطاقتك.';

  @override
  String get sparkPickCard => 'اختر بطاقتك';

  @override
  String get sparkTodayLooking => 'ما تبحث عنه اليوم';

  @override
  String get sparkCardExpired => 'انتهت صلاحية بطاقتك';

  @override
  String sparkHoursLeft(int hours) {
    return 'يتبقّى $hours ساعة';
  }

  @override
  String sparkMinutesLeft(int minutes) {
    return 'يتبقّى $minutes دقيقة';
  }

  @override
  String get sparkIntentSheetTitle => 'اليوم أبحث عن';

  @override
  String get sparkIntentSheetBody =>
      'تنتهي بطاقتك خلال 24 ساعة. سترى فقط من اختار الشيء نفسه.';

  @override
  String get sparkLikesExhausted =>
      'نفدت إعجاباتك لليوم. احصل على باقة من «أنا».';

  @override
  String get sparkMatchesUnavailable => 'التطابقات غير متاحة';

  @override
  String get sparkNoMatchTitle => 'لا يوجد تطابق بعد';

  @override
  String get sparkNoMatchBody =>
      'عندما يُعجب كلٌّ منكما بالآخر، تُفتح غرفة مدتها عشر دقائق. هناك يُحسم الأمر.';

  @override
  String get sparkOpenRooms => 'الغرف المفتوحة';

  @override
  String get sparkRoomsClose => 'تُغلق من تلقاء نفسها';

  @override
  String get sparkMyMatches => 'تطابقاتي';

  @override
  String get sparkNext => 'التالي';

  @override
  String get sparkPhotoFailed => 'تعذّر إضافة الصورة.';

  @override
  String get sparkGoFaster => 'تقدّم أسرع';

  @override
  String get sparkNoExpiry => 'بلا انتهاء';

  @override
  String get sparkPlusActive => 'نشِط — يمدّد اشتراكك';

  @override
  String get sparkPlusPitch => 'ملفات بلا حدود، لمدة شهر';

  @override
  String get sparkBoost => 'ملف مميّز';

  @override
  String get sparkBoostPitch => 'في صدارة التدفّق لمدة ساعة';

  @override
  String get sparkAroundMe => 'حولي';

  @override
  String get sparkSafety => 'الأمان';

  @override
  String get sparkSafetyPitch => 'تنبيه صامت ودائرة ثقة';

  @override
  String get sparkWingman => 'رأي أصدقائي';

  @override
  String get sparkWingmanPitch => 'ملفات يُطلب رأيك فيها';

  @override
  String get sparkUploading => 'جارٍ الرفع…';

  @override
  String get sparkKarma => 'Street Cred';

  @override
  String get sparkCanInvite => 'يمكنك الدعوة';

  @override
  String get sparkCannotInvite => 'منخفض جدًا للدعوة. التزم بمواعيدك.';

  @override
  String sparkLikersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص أعجبوا بك',
      many: '$count شخصًا أعجبوا بك',
      few: '$count أشخاص أعجبوا بك',
      two: 'شخصان أعجبا بك',
      one: 'شخص واحد أعجب بك',
    );
    return '$_temp0';
  }

  @override
  String get sparkSeeWho => 'شاهد من';

  @override
  String get sparkFindInDiscover => 'تجدهم في «استكشاف».';

  @override
  String get sparkPaymentPendingLikers => 'ستُفتح القائمة فور تأكيد الدفع.';

  @override
  String get sparkPaymentPendingLikes => 'ستصلك الإعجابات فور تأكيد الدفع.';

  @override
  String get sparkPaymentPendingPlus => 'سيُفعَّل Spark+ فور تأكيد الدفع.';

  @override
  String get sparkPaymentPendingBoost => 'سيرتفع ملفك فور تأكيد الدفع.';

  @override
  String get sparkBirthDateLabel => 'تاريخ ميلادك';

  @override
  String get sparkNameAndBirthNeeded => 'اسم وتاريخ ميلاد، على الأقل.';

  @override
  String get sparkProfileFailed => 'تعذّر إنشاء الملف.';

  @override
  String get sparkCreateProfile => 'أنشئ ملفك';

  @override
  String get sparkStep1Title => 'تقول ما تبحث عنه، اليوم';

  @override
  String get sparkStep1Body =>
      'تنتهي بطاقتك خلال 24 ساعة. ترى فقط من يبحث عن الشيء نفسه، ضمن 5 كم.';

  @override
  String get sparkStep2Title => 'عشر دقائق صوتية قبل الكتابة';

  @override
  String get sparkStep2Body =>
      'بعد التوافق تُفتح غرفة: صوت وملصقات فقط. الملفات المزيّفة لا تتجاوزها.';

  @override
  String get sparkStep3Title => 'أحبّاؤك يعرفون أين أنت';

  @override
  String get sparkStep3Body =>
      'إيماءة صامتة تنبّه دائرتك مع موقعك. ونسألك أيضًا إن كان كل شيء بخير أثناء الموعد.';

  @override
  String get sparkSeparateTitle => 'ملفك منفصل عن Pokou';

  @override
  String get sparkSeparateBody =>
      'لا يُعرض اسمك ورقمك في Pokou هنا أبدًا. اختر ما تريد إظهاره.';

  @override
  String get sparkDisplayName => 'الاسم المعروض';

  @override
  String get sparkNameExample => 'مثال: أما';

  @override
  String get sparkBirthDate => 'تاريخ الميلاد';

  @override
  String get sparkBirthDateLocked => 'لا يمكن تغييره لاحقًا.';

  @override
  String get sparkChoose => 'اختيار';

  @override
  String get sparkYouAre => 'أنت';

  @override
  String get sparkWoman => 'امرأة';

  @override
  String get sparkMan => 'رجل';

  @override
  String get sparkOther => 'آخر';

  @override
  String get sparkBioLabel => 'كلمتان عنك (اختياري)';

  @override
  String get sparkBioHint => 'ما يجدر معرفته قبل لقائك';

  @override
  String get sparkCreateAction => 'إنشاء ملفي';

  @override
  String get truthSubtitle => 'سؤال مدفوع، وإجابة حرّة';

  @override
  String get truthAsk => 'اطرح سؤالًا';

  @override
  String get truthForMe => 'لي';

  @override
  String get truthMine => 'أسئلتي';

  @override
  String get truthUnavailable => 'الأسئلة غير متاحة';

  @override
  String get truthEmptyTitle => 'لا أسئلة بعد';

  @override
  String get truthEmptyBody =>
      'عندما يدفع أحدهم ليطرح عليك سؤالًا، سيظهر هنا. وتبقى حرًّا في الرفض.';

  @override
  String get truthYourAnswer => 'إجابتك';

  @override
  String get truthAnswerPrivacy =>
      'تذهب فقط إلى من دفع. ولا يعيد Pokou نشرها في أي مكان.';

  @override
  String get truthWhatToSay => 'ما تريد قوله';

  @override
  String get truthSendAnswer => 'إرسال إجابتي';

  @override
  String get truthAskedAnon => 'سُئل بشكل مجهول';

  @override
  String get truthDecline => 'رفض';

  @override
  String get truthAnswer => 'إجابة';

  @override
  String get truthDeclineFree =>
      'الرفض لا يكلّفك شيئًا. تُدفع لك فقط عند الإجابة.';

  @override
  String get truthHistoryUnavailable => 'السجل غير متاح';

  @override
  String get truthNothingAsked => 'لم تسأل شيئًا بعد';

  @override
  String get truthNothingAskedBody =>
      'اطرح سؤالًا على أحدهم: سيرى المبلغ والسؤال، لا اسمك.';

  @override
  String get truthAnswered => 'تمت الإجابة';

  @override
  String get truthDeclined => 'مرفوض';

  @override
  String get truthPending => 'قيد الانتظار';

  @override
  String truthToSomeone(String name) {
    return 'إلى $name';
  }

  @override
  String get truthSomeone => 'شخص ما';

  @override
  String get truthPreferredNot => 'فضّل ألّا يجيب.';

  @override
  String get truthAwaitingAnswer => 'في انتظار إجابة.';

  @override
  String get truthToWhom => 'إلى مَن؟';

  @override
  String truthQuestionTo(String name) {
    return 'سؤال إلى $name';
  }

  @override
  String get truthAnonTitle => 'لا يُعرض اسمك';

  @override
  String get truthAnonBody => 'يرى المبلغ والسؤال، لا من أرسلهما.';

  @override
  String get truthFreeTitle => 'يبقى حرًّا في الرفض';

  @override
  String get truthFreeBody =>
      'الرفض لا يعود عليه بشيء: يُدفع له عند الإجابة فقط.';

  @override
  String get truthPrivateTitle => 'تصل الإجابة إليك وحدك';

  @override
  String get truthPrivateBody =>
      'لا يعيد Pokou نشرها، وتنتهي بعد سبعة أيام دون إجابة.';

  @override
  String get truthYourQuestion => 'سؤالك';

  @override
  String get truthQuestionHint => 'ما تودّ معرفته حقًّا';

  @override
  String get truthHowMuch => 'كم تعرض';

  @override
  String truthAskForAmount(int amount) {
    return 'اطرح السؤال — $amount فرنك';
  }

  @override
  String get truthWriteFirst => 'اكتب سؤالك أولًا.';

  @override
  String get truthPaymentPending => 'سيُرسل سؤالك فور تأكيد الدفع.';

  @override
  String get hypeFinished => 'انتهى';

  @override
  String get hypeSubtitle => 'هدف واحد، القاعة كلها';

  @override
  String get hypeLaunch => 'أطلق هدفًا';

  @override
  String get hypeOngoing => 'جارية';

  @override
  String get hypeMine => 'خاصتي';

  @override
  String get hypeNoneTitle => 'لا أهداف جارية';

  @override
  String get hypeNoneBody => 'عندما يطلق منشئ هدفًا، يظهر هنا حتى يتحقّق.';

  @override
  String get hypeMineEmpty => 'لا شيء بعد';

  @override
  String get hypeMineEmptyBody => 'ستظهر هنا أهدافك وتلك التي دعمتها.';

  @override
  String get hypeUnavailable => 'الأهداف غير متاحة';

  @override
  String get hypeCreator => 'منشئ';

  @override
  String get hypeTierReached => 'تحقّق الهدف';

  @override
  String get hypeGoal => 'هدف';

  @override
  String get hypeNotFound => 'الهدف غير موجود';

  @override
  String get hypeMaybeRemoved => 'ربما تمت إزالته.';

  @override
  String get hypeUnlocked => 'تحقّق الهدف. أُطلق الوعد.';

  @override
  String get hypeContribute => 'حرّك الشريط';

  @override
  String get hypePushers => 'من يدفع';

  @override
  String get hypeBeFirst => 'لا أحد بعد. كن الأول.';

  @override
  String get hypeContributor => 'مساهم';

  @override
  String commonDueToYou(int amount) {
    return 'مستحق لك: $amount فرنك';
  }

  @override
  String get commonManualPayout => 'يتم الصرف من فريق Pokou عند الطلب.';

  @override
  String get hypeStepTogetherTitle => 'الجميع يدفع معًا';

  @override
  String get hypeStepTogetherBody =>
      'كل مساهمة ترفع الشريط، والجميع يرى تحقّقه في الوقت نفسه.';

  @override
  String get hypeStepPromiseTitle => 'ما تَعِد به';

  @override
  String get hypeStepPromiseBody =>
      'ظاهر قبل أن يدفع أحد. إنه التزامك إذا تحقّق الهدف.';

  @override
  String get hypeStepOneTitle => 'هدف واحد في كل مرة';

  @override
  String get hypeStepOneBody =>
      'هدفان في آن واحد يضعان داعميك في منافسة مع أنفسهم.';

  @override
  String get commonTitle => 'العنوان';

  @override
  String get hypeTitleExample => 'مثال: 100000 وأغنّي';

  @override
  String get hypePromiseLabel => 'ما تفتحه إذا تحقّق الهدف';

  @override
  String get hypePromiseHint => 'كن دقيقًا: هذا ما يشتريه داعموك.';

  @override
  String get hypeGoalAmount => 'الهدف بالفرنك';

  @override
  String get commonDuration => 'المدة';

  @override
  String get hypeLaunchAction => 'إطلاق';

  @override
  String get hypeFieldsNeeded => 'العنوان والوعد والهدف مطلوبة.';

  @override
  String get hypeAlreadyRunning => 'لديك هدف جارٍ بالفعل.';

  @override
  String get hypeContributeNote =>
      'مساهمتك تحرّك الشريط وتفتح محتوى. وهي غير قابلة للاسترداد.';

  @override
  String get commonAmount => 'المبلغ';

  @override
  String hypeJoinForAmount(int amount) {
    return 'شارك — $amount فرنك';
  }

  @override
  String get hypePaymentPending => 'سيتحرّك الشريط فور تأكيد الدفع.';

  @override
  String get ceremonyWedding => 'زفاف';

  @override
  String get ceremonyBaptism => 'عمادة';

  @override
  String get ceremonyFuneral => 'عزاء';

  @override
  String get ceremonyOther => 'أخرى';

  @override
  String get ceremonyTitle => 'الصناديق';

  @override
  String get ceremonySubtitle => 'المساهمات، دون إلحاح';

  @override
  String get ceremonyNew => 'صندوق جديد';

  @override
  String get ceremonyUnavailable => 'الصناديق غير متاحة';

  @override
  String get ceremonyNone => 'لا صناديق';

  @override
  String get ceremonyNoneBody =>
      'زفاف، عمادة، عزاء: أنشئ الصندوق، وادعُ، ويساهم كلٌّ بما يستطيع.';

  @override
  String ceremonyGoalHint(int amount) {
    return 'هدف إرشادي: $amount فرنك';
  }

  @override
  String get ceremonyOne => 'صندوق';

  @override
  String get ceremonyNotFound => 'الصندوق غير موجود';

  @override
  String get ceremonyMaybeClosed => 'ربما أُغلق.';

  @override
  String get ceremonyJoin => 'شارك';

  @override
  String get ceremonyClose => 'إغلاق الصندوق';

  @override
  String get ceremonyContributions => 'المساهمات';

  @override
  String get ceremonyNobodyYet => 'لم يساهم أحد بعد.';

  @override
  String get ceremonyAnonGift => 'مساهمة مجهولة';

  @override
  String get ceremonyContributor => 'مساهم';

  @override
  String get ceremonyCollected => 'مُجمَّعة';

  @override
  String get ceremonyYouOrganize => 'أنت المنظّم';

  @override
  String get ceremonyNewSubtitle =>
      'تتابع المساهمات. ولا يُلحّ Pokou على من لم يعطِ.';

  @override
  String get ceremonyOccasion => 'المناسبة';

  @override
  String get ceremonyTitleExample => 'مثال: زفاف كوسي وأما';

  @override
  String get ceremonyFewWords => 'بضع كلمات (اختياري)';

  @override
  String get ceremonyFewWordsHint => 'التاريخ، المكان، وفيمَ سيُستخدم المال.';

  @override
  String get ceremonyGoalOptional => 'الهدف بالفرنك (اختياري)';

  @override
  String get ceremonyGoalNote => 'إرشادي: يواصل الصندوق القبول بعده.';

  @override
  String get ceremonyCreate => 'إنشاء الصندوق';

  @override
  String get ceremonyNeedTitle => 'امنح الصندوق عنوانًا.';

  @override
  String ceremonyJoinTo(String title) {
    return 'شارك — $title';
  }

  @override
  String get ceremonyOtherAmount => 'أو مبلغ آخر';

  @override
  String get ceremonyWordOptional => 'كلمة (اختياري)';

  @override
  String get ceremonyWordHint => 'ما تريد قوله لهم';

  @override
  String get ceremonyAnonToggle => 'المساهمة بشكل مجهول';

  @override
  String get ceremonyAnonNote => 'سيُخفى اسمك. ويبقى المبلغ ضمن المجموع.';

  @override
  String ceremonyJoinAmount(int amount) {
    return 'شارك — $amount فرنك';
  }

  @override
  String get ceremonyMinimum => 'الحد الأدنى 100 فرنك.';

  @override
  String get ceremonyPaymentPending => 'ستظهر مساهمتك فور تأكيد الدفع.';

  @override
  String get vipSubtitle => 'مشتركوك، فضاؤك';

  @override
  String get vipDiscover => 'استكشاف';

  @override
  String get vipMySubs => 'اشتراكاتي';

  @override
  String get vipMyRoom => 'غرفتي';

  @override
  String get vipNoRoomOpen => 'لا غرف مفتوحة';

  @override
  String get vipNoRoomOpenBody => 'ستظهر هنا الغرف التي يفتحها المنشئون.';

  @override
  String get vipNoSub => 'لا اشتراكات';

  @override
  String get vipNoSubBody => 'اشترك في غرفة لتجد هنا كل ما ينشره منشئها.';

  @override
  String get vipUnavailable => 'الغرف غير متاحة';

  @override
  String get vipCreator => 'منشئ';

  @override
  String vipUntil(String date) {
    return 'حتى $date';
  }

  @override
  String get vipPaymentPending => 'ستُفتح الغرفة فور تأكيد الدفع.';

  @override
  String get vipRoom => 'غرفة';

  @override
  String get vipNotFound => 'الغرفة غير موجودة';

  @override
  String get vipMaybeClosed => 'ربما أُغلقت.';

  @override
  String get vipStepAllTitle => 'كل ما يُنشر هنا';

  @override
  String get vipStepAllBody => 'ترى فورًا ما نُشر سلفًا، وكل ما سيليه.';

  @override
  String get vipStepDaysTitle => 'ثلاثون يومًا';

  @override
  String get vipStepDaysBody =>
      'ينتهي الوصول تلقائيًا عند الأجل. ولا شيء يستمر دون قرارك.';

  @override
  String get vipStepNoRenewTitle => 'لا تجديد تلقائي';

  @override
  String get vipStepNoRenewBody =>
      'لا يحتفظ Pokou بوسيلة دفعك. للمتابعة، تدفع مرة أخرى، مرّة واحدة.';

  @override
  String vipSubscribeFor(int amount) {
    return 'اشترك — $amount فرنك';
  }

  @override
  String get vipLockedTitle => 'محتوى للمشتركين فقط';

  @override
  String get vipLockedBody => 'يُفتح باقي الغرفة فور تأكيد الدفع.';

  @override
  String get vipNothingYet => 'لا شيء بعد';

  @override
  String get vipNothingYetBody => 'لا منشورات في هذه الغرفة بعد.';

  @override
  String get vipPosts => 'المنشورات';

  @override
  String get vipRoomUnavailable => 'الغرفة غير متاحة';

  @override
  String get vipOpenYourRoom => 'افتح غرفتك';

  @override
  String get vipOpenYourRoomBody =>
      'يدفع مشتركوك مرة واحدة لثلاثين يومًا ويرون كل ما تنشره. أنت تحدّد السعر.';

  @override
  String get vipOpenAction => 'افتح غرفتي';

  @override
  String get vipPublish => 'نشر';

  @override
  String get vipSeeMyRoom => 'شاهد غرفتي';

  @override
  String get vipOpen => 'مفتوحة';

  @override
  String get vipClosed => 'مغلقة';

  @override
  String get vipEarnings => 'أرباحك';

  @override
  String vipCollected(int amount) {
    return '$amount فرنك مُجمَّعة';
  }

  @override
  String get vipDueNote =>
      'المبلغ المستحق لك. يتم الصرف من فريق Pokou عند الطلب.';

  @override
  String get vipEditRoom => 'تعديل غرفتي';

  @override
  String get vipPriceNote =>
      'السعر الجديد يسري على الاشتراكات اللاحقة فقط: كلٌّ دفع اشتراكه مسبقًا.';

  @override
  String get vipRoomName => 'اسم الغرفة';

  @override
  String get vipRoomNameHint => 'مثال: من وراء الكواليس';

  @override
  String get vipPitchLabel => 'ما سيجده مشتركوك';

  @override
  String get vipPitchNote => 'ظاهر قبل الدفع — وهو ما يدفع للاشتراك.';

  @override
  String get vipPitchHint => 'صور، إعلانات، رسائل صوتية…';

  @override
  String get vipMonthlyPrice => 'السعر الشهري بالفرنك';

  @override
  String get vipAcceptNew => 'قبول مشتركين جدد';

  @override
  String get vipAcceptNewNote => 'يحتفظ مشتركوك الحاليون بوصولهم حتى الأجل.';

  @override
  String get vipFieldsNeeded => 'الاسم والوصف والسعر مطلوبة.';

  @override
  String get vipPublishTitle => 'النشر في غرفتي';

  @override
  String get vipPublishNote => 'مرئي لمشتركيك الحاليين فقط.';

  @override
  String get vipYourMessage => 'رسالتك';

  @override
  String get vipShareHint => 'ما تريد مشاركته';

  @override
  String vipEarningsSummary(int count, int amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اشتراك',
      many: '$count اشتراكًا',
      few: '$count اشتراكات',
      two: 'اشتراكان',
      one: 'اشتراك واحد',
    );
    return '$_temp0 • $amount فرنك مُجمَّعة';
  }

  @override
  String get datesUnavailable => 'المواعيد غير متاحة';

  @override
  String get datesNone => 'لا مواعيد مقرّرة';

  @override
  String get datesNoneBody =>
      'بعد الغرفة، اقترح مكانًا. تدفع مقدّمًا، ولا يُصرف المال إلا بعد تأكيدكما معًا.';

  @override
  String get datesNotNow => 'ليس هذا وقت ذلك.';

  @override
  String get datesCancelTitle => 'إلغاء الموعد؟';

  @override
  String get datesCancelFree => 'يفصلك أكثر من 24 ساعة: سيُعاد المبلغ كاملًا.';

  @override
  String get datesCancelLate =>
      'بقي أقل من 24 ساعة. حجز المكان بالفعل، ويبقى دفعك له.';

  @override
  String get datesKeep => 'الإبقاء';

  @override
  String get datesCancelAction => 'إلغاء الموعد';

  @override
  String get datesAwaitingPayment => 'في انتظار الدفع';

  @override
  String get datesPaidToConfirm => 'مدفوع — بانتظار التأكيد';

  @override
  String get datesDone => 'منتهٍ';

  @override
  String get datesRefunded => 'مُعاد';

  @override
  String get datesNoShow => 'تم الإبلاغ عن الغياب';

  @override
  String get datesCancelled => 'مُلغى';

  @override
  String get datesOne => 'موعد';

  @override
  String datesWithPeer(String venue, String name) {
    return '$venue • مع $name';
  }

  @override
  String get datesYourMatch => 'توافقك';

  @override
  String get datesWentWell => 'سارت الأمور جيدًا';

  @override
  String get datesYouConfirmed => 'لقد أكّدت. ننتظر تأكيد الطرف الآخر.';

  @override
  String get datesNoShowAction => 'لم يحضر';

  @override
  String get datesVoucher => 'قسيمتك، تُقدَّم في المكان';

  @override
  String get datesPickBoth => 'اختر صيغة ووقتًا.';

  @override
  String get datesVoucherPending => 'ستُصدر قسيمتك فور تأكيد الدفع.';

  @override
  String get datesBookingFailed => 'لم يكتمل الحجز.';

  @override
  String get datesWhereTo => 'إلى أين ستذهبان؟';

  @override
  String get datesStepPayTitle => 'تدفع مقدّمًا، ولا يُصرف شيء';

  @override
  String get datesStepPayBody =>
      'المال محجوز. ولا يصل إلى المكان إلا إذا أكّدتما معًا.';

  @override
  String get datesStepCancelTitle => 'إلغاء حرّ قبل 24 ساعة';

  @override
  String get datesStepCancelBody =>
      'استرداد كامل. دون ذلك، حجز المكان بالفعل ويحتفظ بدفعك.';

  @override
  String get datesStepNoShowTitle => 'إن لم يحضر الآخر';

  @override
  String get datesStepNoShowBody =>
      'يعود لك النصف. ولا يأخذ التطبيق شيئًا على موعد فائت.';

  @override
  String get datesThePackage => 'الصيغة';

  @override
  String get datesPacksUnavailable => 'الصيغ غير متاحة حاليًا.';

  @override
  String get datesNoPackNearby => 'لا صيغ مقترحة قربك بعد.';

  @override
  String get datesWhen => 'متى؟';

  @override
  String get datesPickWhen => 'اختر التاريخ والوقت';

  @override
  String get datesBook => 'احجز';

  @override
  String datesBookAmount(int amount) {
    return 'احجز — $amount فرنك';
  }

  @override
  String get roomNeedMic => 'بدون ميكروفون تبقى الملصقات فقط — الغرفة صوتية.';

  @override
  String get roomVoiceFailed => 'لم تُرسل الرسالة الصوتية.';

  @override
  String get roomBothYes => 'انطلقتما. يمكنك الآن اقتراح موعد.';

  @override
  String get roomWaitingOther => 'سُجّل. ننتظر رده قبل انتهاء العدّ التنازلي.';

  @override
  String get roomExtendPending => 'عشر دقائق إضافية فور تأكيد الدفع.';

  @override
  String get roomTitle => 'غرفة الدخول';

  @override
  String get roomNotFound => 'الغرفة غير موجودة';

  @override
  String get roomMaybeClosed => 'ربما أُغلقت.';

  @override
  String get roomVoiceOnly => 'صوت وملصقات فقط';

  @override
  String get roomTimeUp => 'انتهى الوقت.';

  @override
  String roomTimeLeft(String clock) {
    return 'يتبقّى $clock لتقرّرا معًا';
  }

  @override
  String get roomSaySomething => 'قل شيئًا';

  @override
  String get roomNoTextBody =>
      'لا نصّ هنا: رسالة صوتية أو ملصق. هذا ما يميّز شخصًا حقيقيًا عن رسالة منسوخة.';

  @override
  String get roomVoice => 'صوت';

  @override
  String get roomWaitingReply => 'بانتظار رده';

  @override
  String roomExtendFor(int amount) {
    return 'عشر دقائق إضافية — $amount فرنك';
  }

  @override
  String get roomBothSaidYes => 'قلتما نعم كلاكما.';

  @override
  String get roomSaved => 'نجا التوافق. يمكنك اقتراح موعد.';

  @override
  String get roomClosedNoAnswer => 'أُغلقت الغرفة دون إجابة.';

  @override
  String get roomSuggestDate => 'اقترح موعدًا';

  @override
  String get safetyCheckin => 'هل كل شيء بخير؟';

  @override
  String get safetyCheckinBody =>
      'إن لم تردّ خلال خمس دقائق، سيُبلَّغ دائرة أمانك مع موقعك.';

  @override
  String get safetyAllGood => 'نعم، كل شيء بخير';

  @override
  String get safetyCircleAlerted => 'تم تنبيه دائرتك.';

  @override
  String get safetyNoCircle =>
      'سُجّل التنبيه. أضف مقرّبين ليُبلَّغوا في المرة القادمة.';

  @override
  String get safetyWhoToAlert => 'مَن يُنبَّه؟';

  @override
  String get safetyWhoToAlertBody =>
      'سيتلقّى هؤلاء موقعك المباشر إن أطلقت تنبيهًا.';

  @override
  String get safetyTitle => 'الأمان';

  @override
  String get safetySubtitle => 'مَن يُبلَّغ إن ساءت الأمور';

  @override
  String get safetyQuietAlert => 'تنبيه صامت';

  @override
  String get safetyQuietAlertBody =>
      'يُنبّه دائرتك مع موقعك. ولا يظهر شيء على شاشة هاتفك.';

  @override
  String get safetyTrigger => 'أطلق تنبيهًا';

  @override
  String get safetyMyCircle => 'دائرتي';

  @override
  String get safetyThreeEnough => 'ثلاثة أشخاص يكفون';

  @override
  String get safetyNobodyYet =>
      'لا أحد بعد. بدون دائرة، يُسجَّل التنبيه لكنه لا يُبلّغ أحدًا.';

  @override
  String get safetyAddSomeone => 'أضف شخصًا';

  @override
  String get wingmanTitle => 'رأي الأصدقاء';

  @override
  String get wingmanAnon => 'يبقى رأيك مجهولًا';

  @override
  String get wingmanUnavailable => 'الطلبات غير متاحة';

  @override
  String get wingmanNothing => 'لا شيء للتقييم';

  @override
  String get wingmanNothingBody =>
      'عندما يسألك صديق عن رأيك في ملف، سيظهر هنا.';

  @override
  String wingmanAsksYou(String name) {
    return '$name يطلب رأيك';
  }

  @override
  String get wingmanMeh => 'لا بأس';

  @override
  String get wingmanWorthIt => 'يستحق';

  @override
  String get wingmanPrivacy =>
      'سيرى صديقك ما إذا وافقت المجموعة فقط، لا مَن قال ماذا.';

  @override
  String get marketLocationOff => 'خدمة الموقع معطّلة.';

  @override
  String get marketGpsDenied => 'تم رفض إذن الموقع.';

  @override
  String get marketGpsApplied => 'تم تطبيق موقع GPS.';

  @override
  String get marketGpsFailed => 'تعذّر الحصول على موقعك.';

  @override
  String get marketYourArea => 'منطقتك';

  @override
  String get marketCityOrArea => 'المدينة أو الحي';

  @override
  String get marketLocationCleared => 'أُلغي تحديد الموقع.';

  @override
  String get marketUseGps => 'استخدام موقعي عبر GPS';

  @override
  String get marketApply => 'تطبيق';

  @override
  String marketRemoveProduct(String name) {
    return 'إزالة «$name»؟';
  }

  @override
  String get marketProductUnavailable => 'المنتج غير متاح.';

  @override
  String get marketPaymentUnavailable => 'الدفع عبر Mobile Money غير متاح.';

  @override
  String get marketCheckoutUnreachable => 'تعذّر الوصول إلى صفحة الدفع.';

  @override
  String get marketBoostDone => 'تم الدفع: الإعلان مموَّل.';

  @override
  String get marketBoostPending => 'دفع التعزيز قيد الانتظار.';

  @override
  String get marketBoostFailed => 'تعذّر التعزيز الآن.';

  @override
  String get marketTitle => 'Assimé';

  @override
  String get marketBecomeSeller => 'كن بائعًا موثّقًا';

  @override
  String get marketAddProduct => 'أضف منتجًا';

  @override
  String get marketAroundYou => 'حولك';

  @override
  String get marketMyGps => 'موقعي عبر GPS';

  @override
  String get marketPickArea => 'اختر منطقة';

  @override
  String get marketNearYou => 'منتجات بالقرب منك';

  @override
  String get marketUnavailable => 'السوق غير متاح.';

  @override
  String get marketNoProduct => 'لا منتجات منشورة.';

  @override
  String get marketNoMatch => 'لا منتج يطابق هذا البحث.';

  @override
  String get marketAllShown => 'عُرضت كل المنتجات';

  @override
  String get marketMyCatalogue => 'كتالوجي';

  @override
  String get marketSwipeCatalogue => 'اسحب لرؤية كل منتجاتك';

  @override
  String get marketCatalogueEmpty => 'كتالوجك فارغ';

  @override
  String get marketCatalogueEmptyBody => 'أضف منتجك الأول لتبدأ البيع!';

  @override
  String get marketBoosted => 'مموَّل';

  @override
  String get vitrineSeeProduct => 'عرض المنتج';

  @override
  String get vitrineHint => 'المس المنتج لفتحه';

  @override
  String get vitrineTitle => 'واجهة السوق';

  @override
  String get versesMorning => 'آية الصباح';

  @override
  String get versesEvening => 'آية المساء';

  @override
  String get versesChannel => 'آيات اليوم';

  @override
  String get versesChannelDesc => 'آيات السادسة صباحًا والسادسة مساءً';

  @override
  String get versesSchedule => 'كل يوم في السادسة صباحًا والسادسة مساءً';

  @override
  String get versesThisMorning => 'هذا الصباح';

  @override
  String get versesThisEvening => 'هذا المساء';

  @override
  String get versesBibleTitle => 'آيات من الكتاب المقدس';

  @override
  String get versesQuranTitle => 'آيات من القرآن';

  @override
  String get versesShare => 'مشاركة';

  @override
  String get versesOfflineHint =>
      'تصل الآيات حتى دون اتصال: إنها موجودة بالفعل على هاتفك.';

  @override
  String get marketBoosted48h => 'مموَّل';

  @override
  String get marketBoost => 'تمييز';

  @override
  String get marketRemove => 'إزالة';

  @override
  String get marketGpsSaved => 'تم حفظ موقع GPS.';

  @override
  String get marketNameAndPrice => 'الاسم والسعر مطلوبان.';

  @override
  String get marketEditProduct => 'تعديل المنتج';

  @override
  String get marketMainPhoto => 'الصورة الرئيسية';

  @override
  String get marketOtherPhotos => 'صور أخرى';

  @override
  String get marketDescription => 'الوصف';

  @override
  String get marketCurrency => 'العملة';

  @override
  String get marketCategory => 'الفئة';

  @override
  String get marketPickCategory => 'اختر فئة';

  @override
  String get marketSpecifyCategory => 'حدّد الفئة';

  @override
  String marketGpsCoords(String lat, String lon) {
    return 'إحداثيات GPS: $lat، $lon';
  }

  @override
  String get marketUploadingPhoto => 'جارٍ رفع الصورة…';

  @override
  String get marketAddPhoto => 'أضف صورة';

  @override
  String get groupEditName => 'تعديل الاسم';

  @override
  String get groupAddPhoto => 'أضف صورة';

  @override
  String get groupChangePhoto => 'تغيير الصورة';

  @override
  String get groupRemovePhoto => 'إزالة الصورة';

  @override
  String get groupNoLink => 'لا رابط فعّال';

  @override
  String get groupLinkActive => 'يوجد رابط فعّال';

  @override
  String get groupCreator => 'المنشئ';

  @override
  String get groupAdmin => 'مشرف';

  @override
  String get groupAddMembers => 'إضافة مشاركين';

  @override
  String get groupLeave => 'مغادرة المجموعة';

  @override
  String get groupName => 'اسم المجموعة';

  @override
  String get groupCopyLink => 'نسخ الرابط';

  @override
  String get groupRegenLink => 'إعادة توليد الرابط';

  @override
  String get groupDisableLink => 'تعطيل الرابط';

  @override
  String get groupLinkCopied => 'تم نسخ الرابط.';

  @override
  String get groupLinkDisabled => 'تم تعطيل الرابط.';

  @override
  String get groupAllContactsIn =>
      'كل جهات اتصالك في Pokou موجودة في هذه المجموعة.';

  @override
  String get groupAddToGroup => 'إضافة إلى المجموعة';

  @override
  String groupMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إضافة $count مشارك.',
      many: 'تمت إضافة $count مشاركًا.',
      few: 'تمت إضافة $count مشاركين.',
      two: 'تمت إضافة مشاركَين.',
      one: 'تمت إضافة مشارك.',
    );
    return '$_temp0';
  }

  @override
  String get groupLeaveTitle => 'مغادرة المجموعة؟';

  @override
  String groupLeaveBody(String name) {
    return 'لن تتلقّى بعد الآن رسائل «$name».';
  }

  @override
  String get groupLeaveAction => 'مغادرة';

  @override
  String get groupNoMessage => 'لا رسائل. ابدأ المحادثة.';

  @override
  String get groupNotEncryptedNotice =>
      'مشفّرة من طرف إلى طرف: الأعضاء فقط يمكنهم قراءتها.';

  @override
  String get botLabel => 'بوت';

  @override
  String get botConversationNotice =>
      'أنت تراسل بوت إحدى الشركات. هذه الرسائل غير مشفّرة تشفيرًا تامًّا بين الطرفين: الشركة تقرأ ما ترسله.';

  @override
  String get groupAdminsOnly => 'المشرفون فقط';

  @override
  String get groupCallOngoing => 'مكالمة جارية';

  @override
  String get communityEdit => 'تعديل المجتمع';

  @override
  String get commonName => 'الاسم';

  @override
  String get communityEditFailed => 'تعذّر التعديل.';

  @override
  String get communityAddGroup => 'إضافة مجموعة';

  @override
  String get communityNewGroup => 'إنشاء مجموعة جديدة';

  @override
  String get communityAttachGroup => 'إلحاق مجموعة قائمة';

  @override
  String communityDetachTitle(String name) {
    return 'فصل «$name»؟';
  }

  @override
  String get communityDetachBody =>
      'تغادر المجموعة المجتمع لكنها تبقى قائمة: محادثتها ومشاركوها لا يتغيّرون.';

  @override
  String get communityDetach => 'فصل';

  @override
  String get communityDetachFailed => 'تعذّر فصل هذه المجموعة.';

  @override
  String get communityLinkNote =>
      'مَن يملك هذا الرابط ينضم إلى المجتمع ومجموعة الإعلانات — لا إلى بقية المجموعات، فتُنضم واحدة تلو الأخرى.';

  @override
  String get communityActionFailed => 'تعذّر التنفيذ.';

  @override
  String get communityLeaveTitle => 'مغادرة المجتمع؟';

  @override
  String get communityLeaveBody =>
      'لن تتلقّى إعلاناته بعد الآن. وتبقى المجموعات التي انضممت إليها لك.';

  @override
  String get communityLeave => 'مغادرة المجتمع';

  @override
  String get communityLeaveFailed => 'تعذّرت مغادرة المجتمع.';

  @override
  String get communityOne => 'مجتمع';

  @override
  String get communityUnavailable => 'المجتمع غير متاح — تحقّق من اتصالك.';

  @override
  String get communityGroups => 'المجموعات';

  @override
  String get communityAnnouncements => 'إعلانات · للمشرفين فقط';

  @override
  String get communityOnlyAdminGroups =>
      'المجموعات التي تديرها فقط يمكنها الانضمام إلى مجتمع.';

  @override
  String get channelPostsUnavailable => 'المنشورات غير متاحة.';

  @override
  String get channelReactionFailed => 'لم يُسجَّل التفاعل.';

  @override
  String get channelPostFailed => 'تعذّر النشر.';

  @override
  String get channelEditPost => 'تعديل المنشور';

  @override
  String get channelEditTooOld => 'تعذّر التعديل — المنشور قديم جدًا.';

  @override
  String get channelDeletePost => 'حذف المنشور؟';

  @override
  String get channelDeleteBody => 'ستختفي لدى جميع المشتركين.';

  @override
  String get channelDeleteFailed => 'تعذّر الحذف.';

  @override
  String get channelLinkCopied => 'تم نسخ رابط القناة.';

  @override
  String get channelLinkUnavailable => 'الرابط غير متاح.';

  @override
  String get channelEdit => 'تعديل القناة';

  @override
  String get channelPublish => 'نشر';

  @override
  String channelFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشترك',
      many: '$count مشتركًا',
      few: '$count مشتركين',
      two: 'مشتركان',
      one: 'مشترك واحد',
    );
    return '$_temp0';
  }

  @override
  String get channelFollowing => 'مشترك';

  @override
  String get channelEdited => '· مُعدّل';

  @override
  String get channelImageFailed => 'لم تُرسل الصورة.';

  @override
  String get channelNewPost => 'منشور جديد';

  @override
  String get channelPostHint => 'إعلانك…';

  @override
  String pollAnswerN(int index) {
    return 'إجابة $index';
  }

  @override
  String get pollAddAnswer => 'أضف إجابة';

  @override
  String get pollMultiple => 'يُسمح بإجابات متعددة';

  @override
  String get pollAddImage => 'أضف صورة';

  @override
  String get pollRemove => 'إزالة الاستطلاع';

  @override
  String get pollOne => 'استطلاع';

  @override
  String get pollQuestion => 'سؤالك';

  @override
  String get commonSending => 'جارٍ الإرسال…';

  @override
  String channelPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منشور',
      many: '$count منشورًا',
      few: '$count منشورات',
      two: 'منشوران',
      one: 'منشور واحد',
    );
    return '$_temp0';
  }

  @override
  String get lockChooseCode => 'اختر رمزًا';

  @override
  String get lockCodeRule =>
      'من 4 إلى 8 أرقام. لا يغادر الرمز هذا الجهاز أبدًا ولا يمكن استرجاعه — إذا نسيته، يُرفع القفل بالتحقق من رقم هاتفك.';

  @override
  String get lockCode => 'الرمز';

  @override
  String get lockConfirmCode => 'أكّد الرمز';

  @override
  String get lockTooShort => 'يجب أن يتكوّن الرمز من 4 أرقام على الأقل.';

  @override
  String get lockMismatch => 'الرمزان غير متطابقين.';

  @override
  String get lockCurrentCode => 'الرمز الحالي';

  @override
  String get lockValidate => 'تأكيد';

  @override
  String get lockEnabledToast => 'تم تفعيل القفل.';

  @override
  String get lockSaveFailed => 'تعذّر حفظ الرمز.';

  @override
  String get lockEnterCurrent => 'أدخل الرمز الحالي';

  @override
  String get lockWrongCode => 'رمز غير صحيح.';

  @override
  String get lockCodeChanged => 'تم تغيير الرمز.';

  @override
  String get lockEnterToDisable => 'أدخل الرمز للتعطيل';

  @override
  String get lockDisabledToast => 'تم تعطيل القفل.';

  @override
  String get lockTitle => 'قفل التطبيق';

  @override
  String get lockByCode => 'القفل برمز';

  @override
  String get lockOn => 'مفعّل';

  @override
  String get lockOff => 'معطّل';

  @override
  String get lockChangeCode => 'تغيير الرمز';

  @override
  String get lockFootnoteKeystore =>
      'يطلب Pokou الرمز في كل مرة يعود فيها إلى المقدمة. يُحفظ الرمز في مخزن النظام الآمن (Keystore) ولا يُرسل إلى الخادم: فهو يحمي الشاشة لا بيانات الجهاز نفسه.';

  @override
  String get lockFootnoteBiometrics =>
      'لم تُتَح بعد البصمة — فهي تتطلب تغييرًا في إعدادات أندرويد (FlutterFragmentActivity وإذن USE_BIOMETRIC).';

  @override
  String get lockScreenTitle => 'Pokou مقفل';

  @override
  String get lockEnterToContinue => 'أدخل رمزك للمتابعة.';

  @override
  String get lockUnlock => 'إلغاء القفل';

  @override
  String get lockForgotQuestion => 'هل نسيت الرمز؟';

  @override
  String get lockSendFailed => 'تعذّر الإرسال — تحقّق من اتصالك.';

  @override
  String get lockRemovedToast =>
      'تمت إزالة القفل. يمكنك اختيار رمز جديد من الملف الشخصي.';

  @override
  String get lockVerifyFailed => 'تعذّر التحقّق — تحقّق من اتصالك.';

  @override
  String get lockLogoutQuestion => 'تسجيل الخروج؟';

  @override
  String get lockLogoutBody =>
      'استخدم هذا إن لم يعد لديك وصول إلى هذا الرقم. تبقى محادثاتك على الخادم، لكنك ستحتاج إلى رقم يمكن الوصول إليه لتسجيل الدخول مجددًا.';

  @override
  String get lockLogout => 'تسجيل الخروج';

  @override
  String get lockForgotTitle => 'الرمز المنسي';

  @override
  String get lockNoPhoneOnDevice => 'تعذّر العثور على رقمك على هذا الجهاز.';

  @override
  String lockEnterSentCode(String phone) {
    return 'أدخل الرمز المُرسل إلى $phone عبر الرسائل القصيرة وواتساب.';
  }

  @override
  String lockForgotExplain(String phone) {
    return 'يُخزَّن رمز القفل على هذا الجهاز فقط ولا يمكن استرجاعه. لرفع القفل، تحقّق من رقمك $phone.';
  }

  @override
  String get lockLift => 'رفع القفل';

  @override
  String get lockSendCode => 'إرسال رمز';

  @override
  String get lockResendCode => 'إعادة إرسال الرمز';

  @override
  String get lockNoAccessToNumber => 'لم يعد لديّ وصول إلى هذا الرقم';

  @override
  String get notifInApp => 'داخل التطبيق';

  @override
  String get notifMessages => 'الرسائل';

  @override
  String get notifMessagesSub => 'المحادثات الفردية';

  @override
  String get notifMessagesSemantic => 'إشعارات الرسائل';

  @override
  String get notifGroups => 'المجموعات';

  @override
  String get notifGroupsSub => 'محادثات المجموعات';

  @override
  String get notifGroupsSemantic => 'إشعارات المجموعات';

  @override
  String get notifCallsSub => 'المكالمات الصوتية والمرئية الواردة';

  @override
  String get notifCallsSemantic => 'إشعارات المكالمات';

  @override
  String get notifSound => 'الصوت والاهتزاز';

  @override
  String get notifSoundSemantic => 'صوت الإشعارات';

  @override
  String get notifCallsFootnote =>
      'إيقاف المكالمات هنا يزيل فقط الشريط الذي يظهر عندما يكون Pokou مفتوحًا: تظل المكالمة الواردة ترنّ بملء الشاشة، وإلا لفاتتك مكالمات دون أن تدري.';

  @override
  String get notifSystem => 'النظام';

  @override
  String get notifWebEnable => 'تفعيل إشعارات المتصفح';

  @override
  String get notifWebEnableSub => 'السماح لهذا المتصفح بتلقي إشعارات Pokou.';

  @override
  String get notifWebEnabled => 'تم تفعيل إشعارات المتصفح.';

  @override
  String get notifWebEnableFailed =>
      'تعذر تفعيل الإشعارات. تحقق من إعدادات الموقع في المتصفح.';

  @override
  String get notifAndroidSettings => 'إعدادات أندرويد';

  @override
  String get notifAndroidSettingsSub => 'الإذن والقنوات وصوت كل قناة';

  @override
  String get notifSystemFootnote =>
      'عندما يكون Pokou مغلقًا، يعرض أندرويد الإشعارات الواردة بنفسه دون المرور بالتطبيق: إعدادات النظام أعلاه وحدها يمكنها تغييرها.';

  @override
  String get devicesRemoveTitle => 'إزالة هذا الجهاز؟';

  @override
  String get devicesRemoveCurrentBody =>
      'لن يتلقّى هذا الجهاز إشعارات حتى تفتح Pokou من جديد.';

  @override
  String get devicesRemoveOtherBody =>
      'لن يتلقّى هذا الجهاز إشعارات. يبقى مسجّل الدخول حتى تسجيل الخروج التالي.';

  @override
  String get devicesRemove => 'إزالة';

  @override
  String get devicesRemoveFailed => 'تعذّرت إزالة هذا الجهاز.';

  @override
  String get devicesTitle => 'الأجهزة المتصلة';

  @override
  String get devicesUnavailable =>
      'القائمة غير متاحة — تحقّق من اتصالك ثم اسحب للتحديث.';

  @override
  String get devicesEmpty =>
      'لا يوجد جهاز مسجَّل للإشعارات. تُفعَّل عند أول فتح لـ Pokou على جهاز.';

  @override
  String get devicesThisDevice => ' · هذا الجهاز';

  @override
  String devicesLastSeen(String date, String hint) {
    return 'نشِط في $date · …$hint';
  }

  @override
  String get devicesFootnote =>
      'يظهر الجهاز هنا بمجرّد تسجيله لإشعارات الدفع. إزالته توقف إشعاراته؛ ولا تُنهي جلسته التي تنتهي من تلقاء نفسها.';

  @override
  String get devicesBrowser => 'متصفّح';

  @override
  String devicesTodayAt(String time) {
    return 'اليوم في $time';
  }

  @override
  String get storageNoCachedMedia => 'لا توجد وسائط في الذاكرة المؤقتة.';

  @override
  String storageFilesCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُذف $count ملف من الذاكرة المؤقتة.',
      many: 'حُذف $count ملفًا من الذاكرة المؤقتة.',
      few: 'حُذفت $count ملفات من الذاكرة المؤقتة.',
      two: 'حُذف ملفان من الذاكرة المؤقتة.',
      one: 'حُذف ملف واحد من الذاكرة المؤقتة.',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'التخزين والبيانات';

  @override
  String get storageCachedMedia => 'الوسائط المؤقتة';

  @override
  String get storageMediaLabel => 'الصور والفيديوهات والرسائل الصوتية';

  @override
  String get storageComputing => 'جارٍ الحساب…';

  @override
  String get storageNoFile => 'لا توجد ملفات';

  @override
  String storageFileCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
    );
    return '$_temp0 · $size';
  }

  @override
  String get storageClearCache => 'إفراغ الذاكرة المؤقتة';

  @override
  String get storageClearFootnote =>
      'تُعاد الملفات المحذوفة عند الطلب حين تفتح المحادثة مجددًا: لا يضيع شيء، بل يُفرَّغ المكان فقط.';

  @override
  String get storageMobileData => 'بيانات الجوال';

  @override
  String get storageDataSaver => 'توفير البيانات';

  @override
  String get storageDataSaverSub => 'عدم تنزيل الوسائط تلقائيًا';

  @override
  String get storageDataSaverFootnote =>
      'عند تفعيله، تنتظر الصور والفيديوهات الواردة أن تلمسها لتُنزَّل، وتُضغط الصور التي ترسلها أكثر.';

  @override
  String get profileAvatarFailed => 'تعذّر تحديث صورة الملف الشخصي.';

  @override
  String get profileChooseMonitor => 'اختر مراقبًا';

  @override
  String get profileBabaMessaging => 'مراسلة Baba';

  @override
  String profileMonitorAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تنبيهات $count مراقب',
      many: 'تنبيهات $count مراقبًا',
      few: 'تنبيهات $count مراقبين',
      two: 'تنبيهات مراقبين',
      one: 'تنبيهات مراقب واحد',
    );
    return '$_temp0';
  }

  @override
  String get profileBabaAssistant => 'مساعد Baba';

  @override
  String get profileShieldModeBody =>
      'يُبقي المكالمات في الانتظار ويُخفت المحادثات غير ذات الأولوية أثناء تركيزك. أمّا جهات الاتصال الموسومة بـ Business أو عميل أو مورّد أو مدير فتمرّ دائمًا.';

  @override
  String get contactConnectFailed => 'تعذّر الاتصال.';

  @override
  String get contactCallFailed => 'تعذّر إجراء المكالمة الآن.';

  @override
  String contactBlockTitle(String name) {
    return 'حظر $name؟';
  }

  @override
  String get contactBlockBody =>
      'لن يتمكّن هذا الشخص من مراسلتك أو الاتصال بك بعد الآن، ولن يُعلَم بذلك.';

  @override
  String get contactActionFailed => 'تعذّر تنفيذ الإجراء الآن.';

  @override
  String get contactSavedToast => 'تم حفظ جهة الاتصال';

  @override
  String get contactCall => 'مكالمة';

  @override
  String get contactSharedTitle => 'العناصر المتبادلة';

  @override
  String get contactSharedMedia => 'الوسائط';

  @override
  String get contactSharedDocuments => 'المستندات';

  @override
  String get contactSharedLinks => 'الروابط';

  @override
  String get contactNoMedia => 'لم تُتبادل صور أو فيديوهات.';

  @override
  String get contactNoDocuments => 'لم تُتبادل مستندات.';

  @override
  String get contactNoLinks => 'لم تُتبادل روابط.';

  @override
  String contactCommonGroups(int count) {
    return 'المجموعات المشتركة ($count)';
  }

  @override
  String contactCatalog(int count) {
    return 'الكتالوج ($count)';
  }

  @override
  String contactUnblockName(String name) {
    return 'إلغاء حظر $name';
  }

  @override
  String contactBlockName(String name) {
    return 'حظر $name';
  }

  @override
  String get contactUnblockHint =>
      'يمكن لهذا الشخص مراسلتك والاتصال بك مجددًا.';

  @override
  String get contactBlockHint =>
      'لن يتمكّن من مراسلتك أو الاتصال بك، ولن يُعلَم بذلك.';

  @override
  String get adNeedTitleBody => 'امنح إعلانك عنوانًا ونصًّا.';

  @override
  String get adSendFailed => 'تعذّر إرسال الطلب.';

  @override
  String get adCreateTitle => 'إنشاء إعلان';

  @override
  String get adWhoSeesTitle => 'من سيراه';

  @override
  String get adWhoSeesBody =>
      'جميع مستخدمي Pokou Messenger في تبويب السوق، أو بين حالتين — القرار لك.';

  @override
  String get adReviewTitle => 'مراجعة قبل النشر';

  @override
  String get adReviewBody =>
      'يقرأ فريقنا كل حملة قبل انطلاقها. توقّع بضع ساعات.';

  @override
  String get adCountdownTitle => 'يبدأ العدّ من لحظة الموافقة';

  @override
  String get adCountdownBody =>
      'تبدأ أيام النشر عند قبول الحملة، لا عند الدفع.';

  @override
  String get adRefundTitle => 'مرفوضة؟ تُعاد إليك النقود';

  @override
  String get adRefundBody =>
      'إن تعذّر نشر الحملة، تواصل معنا: يُعاد إليك المبلغ.';

  @override
  String get adTitleHint => 'مثال: إسمنت CIMTOGO بعرض خاص';

  @override
  String get adBodyHint => 'ما تعرضه، وكيف يمكن الوصول إليك.';

  @override
  String get adMediaLabel => 'صورة أو فيديو (اختياري)';

  @override
  String get adMediaHint =>
      'فيديو مدته 30 ثانية كحد أقصى. بدون صورة، يُنشر النص وحده.';

  @override
  String get adVideo30s => 'فيديو 30 ثانية';

  @override
  String get adPlacement => 'الموضع';

  @override
  String get adPlacementMarket => 'تبويب السوق';

  @override
  String get adPlacementStatus => 'بين الحالات';

  @override
  String get adDuration => 'المدة';

  @override
  String get adOneWeek => 'أسبوع';

  @override
  String get adTwoWeeks => 'أسبوعان';

  @override
  String get adOneMonth => 'شهر';

  @override
  String get adPayCaption => 'الدفع عبر Mobile Money';

  @override
  String get adPayAction => 'ادفع وأرسل';

  @override
  String productInterestedMessage(String name, String price, String currency) {
    return 'مرحبًا، أنا مهتم بـ$name بسعر $price $currency. هل هو متوفّر؟';
  }

  @override
  String get productWriteFailed => 'تعذّرت مراسلة البائع الآن.';

  @override
  String get productCallFirstWrite => 'تعذّر الاتصال — راسله أولًا.';

  @override
  String get productRateSeller => 'قيّم هذا البائع';

  @override
  String get productEditReview => 'تعديل تقييمي';

  @override
  String get productReviewScope =>
      'التقييم يخصّ البائع، لا المنتج: المهم هو الثقة بالشخص، وتبقى حتى لو خرجت السلعة من الكتالوج.';

  @override
  String get productReviewHint => 'تعليقك (اختياري)';

  @override
  String get productDeleteReview => 'حذف تقييمي';

  @override
  String get productReviewFailed => 'لم يُحفظ التقييم.';

  @override
  String get productTitle => 'منتج';

  @override
  String get productOpening => 'جارٍ الفتح…';

  @override
  String get productDiscuss => 'محادثة';

  @override
  String get productCallAction => 'اتصال';

  @override
  String get productReviews => 'التقييمات';

  @override
  String get productNoReviewYet => 'لا توجد تقييمات بعد';

  @override
  String productRatingSummary(String rating, int reviews) {
    String _temp0 = intl.Intl.pluralLogic(
      reviews,
      locale: localeName,
      other: '$reviews تقييم',
      many: '$reviews تقييمًا',
      few: '$reviews تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String productCountSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
    );
    return ' · $_temp0';
  }

  @override
  String get productCertified => 'حساب موثّق من فريق Pokou.';

  @override
  String get productReviewMine => 'أنت';

  @override
  String get verifNeedDocument => 'أضف صورة لبطاقة هويتك.';

  @override
  String get verifTitle => 'كن بائعًا موثّقًا';

  @override
  String get verifBadgeTitle => 'شارة زرقاء على إعلاناتك';

  @override
  String get verifBadgeBody => 'يرى المشترون أنّ فريقنا قد تحقّق من هويتك.';

  @override
  String get verifWhyTitle => 'لماذا يغيّر ذلك كل شيء';

  @override
  String get verifWhyBody =>
      'يُرسل المشتري أموال Mobile Money بسهولة أكبر إلى شخص مؤكّدة هويته منه إلى مجهول.';

  @override
  String get verifNeedTitle => 'ما يجب تقديمه';

  @override
  String get verifNeedBody =>
      'صورة واضحة لبطاقة هويتك أو جواز سفرك أو رخصتك. يجب أن يكون الاسم مقروءًا.';

  @override
  String get verifUseTitle => 'ماذا نفعل بها';

  @override
  String get verifUseBody =>
      'يقرؤها فريقنا للتحقّق فقط، ولا تظهر أبدًا في ملفك الشخصي، ولا تُعرض على أي مشترٍ.';

  @override
  String get verifOneYearTitle => 'صالحة لمدة سنة';

  @override
  String get verifOneYearBody =>
      'تدوم الشارة اثني عشر شهرًا. توقّع بضعة أيام لدراسة الطلب.';

  @override
  String get verifDocumentLabel => 'وثيقة هويتك';

  @override
  String get verifPayCaption => 'الدفع عبر Mobile Money · سنة واحدة';

  @override
  String get verifChoosePhoto => 'اختر صورة';

  @override
  String get verifChange => 'تغيير';

  @override
  String get marketRemoveBody =>
      'يختفي الإعلان من السوق. تبقى محادثاتك بشأنه قابلة للقراءة، ويحتفظ المشترون الذين تلقّوه بسجلّهم.';

  @override
  String get marketRemoveFailed => 'تعذّرت إزالة الإعلان.';

  @override
  String get marketImageFailed => 'لم تُرسَل الصورة — أعد المحاولة.';

  @override
  String get marketMainPhotoHint => 'هي التي تمثّل المنتج في القائمة.';

  @override
  String get marketName => 'الاسم';

  @override
  String get marketPrice => 'السعر';

  @override
  String get marketNoReviewYet => 'لا تقييمات بعد';

  @override
  String get marketSearchHint => 'ابحث عن منتج…';

  @override
  String get callLogEmpty => 'لا توجد مكالمات بعد.';

  @override
  String get callLogUnknownUser => 'مستخدم';

  @override
  String get callStatusMissed => 'فائتة';

  @override
  String get callStatusNoAnswer => 'بلا ردّ';

  @override
  String get callStatusDeclined => 'مرفوضة';

  @override
  String get callStatusReceived => 'واردة';

  @override
  String get callStatusEnded => 'منتهية';

  @override
  String get callStatusOngoing => 'جارية';

  @override
  String get callStatusOutgoing => 'صادرة';

  @override
  String get callVideoTitle => 'مكالمة فيديو';

  @override
  String get callAudioTitle => 'مكالمة صوتية';

  @override
  String callRedialQuestion(String name) {
    return 'معاودة الاتصال بـ$name؟';
  }

  @override
  String get callJoinFailed => 'تعذّر الاتصال بالمكالمة.';

  @override
  String get callNobodyToAdd => 'لا أحد آخر لإضافته.';

  @override
  String get callAddToCall => 'إضافة إلى المكالمة';

  @override
  String get callAdd => 'إضافة';

  @override
  String get callAddFailed => 'تعذّرت إضافة هذا المشارك.';

  @override
  String get callReactionFailed => 'تعذّر إرسال هذا التفاعل.';

  @override
  String get callLeaveConfirmTitle => 'مغادرة المكالمة؟';

  @override
  String get callLeaveConfirmBody =>
      'قد يواصل المشاركون الآخرون الحديث. يمكنك إغلاق هذه الشاشة دون إنهاء المكالمة والعودة من شريط المكالمة.';

  @override
  String get callYou => 'أنت';

  @override
  String get callContact => 'جهة اتصال';

  @override
  String get callConnecting => 'جارٍ الاتصال بالمكالمة…';

  @override
  String get callPreparing => 'يجري تجهيز المكالمة';

  @override
  String get callWaiting => 'في الانتظار…';

  @override
  String get callJoinImpossible => 'تعذّر الانضمام إلى المكالمة.';

  @override
  String get callEncryptedJoinFailed =>
      'تعذّر فتح هذه المكالمة المشفّرة على هذا الهاتف. تم إبلاغ المتصل.';

  @override
  String get callIncoming => 'مكالمة واردة';

  @override
  String callIncomingFrom(String name) {
    return '$name يتّصل بك';
  }

  @override
  String get callIncomingGroup => 'مكالمة جماعية واردة';

  @override
  String get streakSubtitle => 'يوم فائت، ودقائق قليلة لتعويضه';

  @override
  String get streakUnavailable => 'السلاسل غير متاحة';

  @override
  String get streakCheckConnection => 'تحقّق من اتصالك وأعد المحاولة.';

  @override
  String get streakEmptyTitle => 'لا توجد سلسلة بعد';

  @override
  String get streakEmptyBody =>
      'تبادل رسالة كل يوم مع الشخص نفسه: تبدأ السلسلة من أول ردّ متبادل.';

  @override
  String get streakToRescue => 'لإنقاذها الآن';

  @override
  String get streakToRescueSub => 'بعد انقضاء المهلة، تبدأ السلسلة من الصفر';

  @override
  String get streakMine => 'سلاسلي';

  @override
  String get streakRunning => 'جارية';

  @override
  String streakRecord(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return 'الرقم القياسي: $_temp0';
  }

  @override
  String get streakLongest => 'أطول سلسلة لديك';

  @override
  String get streakRestorePending => 'ستستأنف سلسلتك فور تأكيد الدفع.';

  @override
  String get streakDeadlinePassed => 'ربما انقضت المهلة.';

  @override
  String streakBroken(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'انقطعت سلسلة $days يوم',
      many: 'انقطعت سلسلة $days يومًا',
      few: 'انقطعت سلسلة $days أيام',
      two: 'انقطعت سلسلة يومين',
      one: 'انقطعت سلسلة يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get streakExpired => 'انقضت المهلة. تبدأ السلسلة من الصفر.';

  @override
  String streakCountdown(String time) {
    return 'بقي $time لإنقاذها';
  }

  @override
  String streakRescueAction(int amount) {
    return 'أنقذ السلسلة — $amount فرنك';
  }

  @override
  String get leagueSubtitle => 'ترتفع فئتك بما تتلقّاه';

  @override
  String get leagueUnavailable => 'الترتيب غير متاح';

  @override
  String get leagueRanking => 'الترتيب';

  @override
  String get leagueProtectPending => 'ستُفعَّل حمايتك فور تأكيد الدفع.';

  @override
  String get leaguePaymentFailed => 'تعذّر بدء الدفع.';

  @override
  String get leagueAtTop => 'أنت في قمة الترتيب.';

  @override
  String leaguePointsNeeded(int points, String label) {
    return 'بقيت $points نقطة للوصول إلى $label.';
  }

  @override
  String get leagueProtected => 'نقاطك محميّة. لا شيء ينقص هذا الأسبوع.';

  @override
  String get leagueDecayNow => 'ستنقص نقاطك في الدورة القادمة.';

  @override
  String leagueDecayIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'ستنقص نقاطك بعد $days يوم دون نشاط.',
      many: 'ستنقص نقاطك بعد $days يومًا دون نشاط.',
      few: 'ستنقص نقاطك بعد $days أيام دون نشاط.',
      two: 'ستنقص نقاطك بعد يومين دون نشاط.',
      one: 'ستنقص نقاطك بعد يوم واحد دون نشاط.',
    );
    return '$_temp0';
  }

  @override
  String get leagueProtectAction => 'احمِ نقاطي — 500 فرنك';

  @override
  String get leagueNobodyRanked => 'لا أحد في الترتيب بعد. كن الأول.';

  @override
  String leagueMyRank(int rank, int points) {
    return 'أنت في المركز $rank بـ$points نقطة.';
  }

  @override
  String get reactWith => 'تفاعل بـ…';

  @override
  String get reactPickEmoji => 'اختر رمزًا تعبيريًا من لوحة المفاتيح';

  @override
  String get reactAction => 'تفاعل';

  @override
  String get mediaPoll => 'استطلاع';

  @override
  String get mediaContact => 'جهة اتصال';

  @override
  String get mediaSharedContact => 'جهة اتصال مشتركة';

  @override
  String get convEdited => '· مُعدّل';

  @override
  String get convFallbackName => 'محادثة';

  @override
  String get convSomeone => 'شخص ما';

  @override
  String get contactsTagFailed => 'تعذّر تحديث التسمية.';

  @override
  String get contactsTag => 'وضع تسمية';

  @override
  String get contactsTitle => 'جهات الاتصال';

  @override
  String get contactsTyping => 'يكتب…';

  @override
  String contactsTypingNamed(String name) {
    return '$name يكتب…';
  }

  @override
  String contactsPreviewMine(String preview) {
    return 'أنت: $preview';
  }

  @override
  String contactsPreviewSender(String name, String preview) {
    return '$name: $preview';
  }

  @override
  String contactsNotInContacts(String preview) {
    return '$preview · ليس في جهات اتصالك';
  }

  @override
  String get contactsAssistantSub => 'مساعدك الذكي';

  @override
  String get addContactTitle => 'إضافة جهة اتصال';

  @override
  String get addContactName => 'الاسم';

  @override
  String get addContactAction => 'إضافة';

  @override
  String get joinLinkTitle => 'الانضمام عبر رابط';

  @override
  String get joinLinkBody =>
      'الصق الرابط الذي أُرسل إليك. مجموعة كانت أم مجتمعًا، سنميّز أيّهما.';

  @override
  String get joinLinkContinue => 'متابعة';

  @override
  String get joinLinkUnreadable => 'رابط الدعوة غير مقروء.';

  @override
  String joinAlreadyMember(String name) {
    return 'أنت بالفعل في «$name».';
  }

  @override
  String joinGroupQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشارك',
      many: '$count مشاركًا',
      few: '$count مشاركين',
      two: 'مشاركان',
      one: 'مشارك واحد',
    );
    return '$_temp0. الانضمام إلى هذه المجموعة؟';
  }

  @override
  String get joinAction => 'انضمام';

  @override
  String get joinGroupFailed => 'تعذّر الانضمام إلى هذه المجموعة.';

  @override
  String joinCommunityCounts(int members, int groups) {
    String _temp0 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members عضو',
      many: '$members عضوًا',
      few: '$members أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups مجموعة',
      many: '$groups مجموعة',
      few: '$groups مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
    );
    return '$_temp0 · $_temp1.';
  }

  @override
  String get joinCommunityBody =>
      'ستتلقّى إعلاناته. أمّا المجموعات الأخرى فيُنضم إليها واحدة تلو الأخرى.';

  @override
  String get joinCommunityFailed => 'تعذّر الانضمام إلى هذا المجتمع.';

  @override
  String get newChatOwnNumber => 'هذا رقمك أنت.';

  @override
  String get phoneLookupFailed => 'رقم غير صالح أو تعذّر التحقّق منه.';

  @override
  String get phoneNotOnPokou => 'هذا الرقم لا يستخدم Pokou بعد.';

  @override
  String get phoneInviteWhatsApp => 'الدعوة عبر واتساب';

  @override
  String get phoneInviteText =>
      'مرحبًا! أدعوك لتجربة Pokou، تطبيق مراسلة خاص — نزّل التطبيق وأضِفني.';

  @override
  String get contactCardTitle => 'بطاقة تعريف';

  @override
  String get viewOnceSeen => 'شوهدت';

  @override
  String get viewOnceTapToSee => 'عرض لمرة واحدة — المس للمشاهدة';

  @override
  String get audioPlayFailed => 'تعذّر التشغيل';

  @override
  String mediaPhotoSize(Object size) {
    return 'صورة · $size';
  }

  @override
  String get mediaTapToDownload => 'المس للتنزيل';

  @override
  String get mediaVideoUnavailable => 'الفيديو غير متاح';

  @override
  String get mediaOpenDocFailed => 'تعذّر فتح هذا المستند.';

  @override
  String get mediaOpenRetry => 'فشل الفتح — المس لإعادة المحاولة';

  @override
  String get dayToday => 'اليوم';

  @override
  String get dayYesterday => 'أمس';

  @override
  String get weekdayMonday => 'الاثنين';

  @override
  String get weekdayTuesday => 'الثلاثاء';

  @override
  String get weekdayWednesday => 'الأربعاء';

  @override
  String get weekdayThursday => 'الخميس';

  @override
  String get weekdayFriday => 'الجمعة';

  @override
  String get weekdaySaturday => 'السبت';

  @override
  String get weekdaySunday => 'الأحد';

  @override
  String liveHoursLeft(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'بقيت $hours ساعة',
      many: 'بقيت $hours ساعة',
      few: 'بقيت $hours ساعات',
      two: 'بقيت ساعتان',
      one: 'بقيت ساعة',
    );
    return '$_temp0';
  }

  @override
  String liveMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'بقيت $minutes دقيقة',
      many: 'بقيت $minutes دقيقة',
      few: 'بقيت $minutes دقائق',
      two: 'بقيت دقيقتان',
      one: 'بقيت دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get liveAlmostOver => 'على وشك الانتهاء';

  @override
  String liveLocation(String remaining) {
    return 'مباشر · $remaining';
  }

  @override
  String get openInMaps => 'الفتح في الخرائط';

  @override
  String get composerEditPhoto => 'تعديل الصورة';

  @override
  String get composerEditorFailed => 'تعذّر فتح المحرّر.';

  @override
  String get composerCropRotate => 'قصّ أو تدوير';

  @override
  String get composerCaptionHint => 'أضف تعليقًا…';

  @override
  String composerTo(String name) {
    return 'إلى $name';
  }

  @override
  String get composerSend => 'إرسال';

  @override
  String get convOfflineNotCached => 'دون اتصال — لم تُحفظ هذه المحادثة بعد.';

  @override
  String get convLoadFailed => 'تعذّر تحميل المحادثة.';

  @override
  String get convEmptyEdit => 'لا يمكن لرسالة فارغة أن تحلّ محل نص.';

  @override
  String get convEditFailed => 'تعذّر التعديل — تحقّق من اتصالك.';

  @override
  String get convOrderUpdateFailed => 'تعذّر تحديث الطلب.';

  @override
  String get convDeleteFailed => 'تعذّر حذف الرسالة.';

  @override
  String get convForwardFailedMsg => 'تعذّرت إعادة توجيه الرسالة.';

  @override
  String get convOfflineAttachment => 'دون اتصال — تحتاج المرفقات إلى اتصال.';

  @override
  String get convAttachmentFailed => 'لم يُرسَل المرفق — أعد المحاولة.';

  @override
  String get groupOfflineNotCached => 'دون اتصال — لم تُحفظ هذه المجموعة بعد.';

  @override
  String get groupLoadFailed => 'تعذّر تحميل المجموعة.';

  @override
  String get groupRenameFailed => 'تعذّرت إعادة تسمية المجموعة.';

  @override
  String get groupPhotoFailed => 'لم تُحفظ صورة المجموعة.';

  @override
  String get groupClearPhotoFailed => 'تعذّرت إزالة الصورة.';

  @override
  String get groupRoleFailed => 'تعذّر تغيير هذا الدور.';

  @override
  String get groupInviteCreateFailed => 'تعذّر إنشاء رابط الدعوة.';

  @override
  String get groupInviteRevokeFailed => 'تعذّر تعطيل الرابط.';

  @override
  String get groupLeaveFailed => 'تعذّرت مغادرة المجموعة.';

  @override
  String get groupRemoveMemberFailed => 'تعذّرت إزالة هذا العضو.';

  @override
  String get apiNetworkSilent => 'الشبكة لا تستجيب';

  @override
  String apiError(int code) {
    return 'خطأ ($code)';
  }

  @override
  String get orderProductDiscussed => 'السلعة قيد النقاش';

  @override
  String get orderValidate => 'تأكيد الطلب';

  @override
  String get orderMarkShipped => 'وسمه كمُرسَل';

  @override
  String get orderMarkDelivered => 'وسمه كمُسلَّم';

  @override
  String get orderBuyerWaiting => 'هذا المشتري ينتظر ردّك.';

  @override
  String get orderNextStep => 'الخطوة التالية من الطلب.';

  @override
  String get msgNotSentRetry => 'لم تُرسَل — المس لإعادة المحاولة';

  @override
  String get msgPendingSend => 'في انتظار الإرسال';

  @override
  String convSearchHint(String name) {
    return 'ابحث في $name…';
  }

  @override
  String get convSearchPrompt => 'اكتب كلمة للعثور على رسالة في هذه المحادثة.';

  @override
  String get convSearchEmpty => 'لم يُعثر على أي رسالة.';

  @override
  String get commonUnknownName => 'غير معروف';

  @override
  String get groupInviteLink => 'رابط الدعوة';

  @override
  String get groupDemoteAdmin => 'سحب صلاحية الإدارة';

  @override
  String get groupPromoteAdmin => 'تعيين مشرفًا';

  @override
  String get groupInviteLinkBody =>
      'كل من يفتح هذا الرابط ينضم إلى المجموعة مباشرةً دون أي خطوة أخرى. أعِد توليده لإبطال الرابط الذي شاركته سابقًا.';

  @override
  String get groupNewLinkCreated => 'أُنشئ رابط جديد — لم يعد القديم يعمل.';

  @override
  String get groupAddFailed => 'تعذّرت الإضافة.';

  @override
  String get groupCreateFailed => 'تعذّر إنشاء المجموعة.';

  @override
  String get groupNewTitle => 'مجموعة جديدة';

  @override
  String get groupCreateAction => 'إنشاء';

  @override
  String get groupNameHint => 'اسم المجموعة';

  @override
  String get groupPickParticipants => 'اختر المشاركين';

  @override
  String groupSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم اختيار $count مشارك',
      many: 'تم اختيار $count مشاركًا',
      few: 'تم اختيار $count مشاركين',
      two: 'تم اختيار مشاركين',
      one: 'تم اختيار مشارك واحد',
    );
    return '$_temp0';
  }

  @override
  String get pushIncomingVideoCall => 'مكالمة فيديو واردة';

  @override
  String get pushIncomingAudioCall => 'مكالمة صوتية واردة';

  @override
  String get pushAnswer => 'ردّ';

  @override
  String get pushDecline => 'رفض';

  @override
  String get pushMessagesChannel => 'الرسائل';

  @override
  String get pushMessagesChannelDesc => 'إشعارات رسائل Pokou الجديدة';

  @override
  String get pushCallsChannel => 'المكالمات';

  @override
  String get pushCallsChannelDesc => 'إشعارات مكالمات Pokou الواردة';

  @override
  String get pushGroupFallback => 'مجموعة';

  @override
  String get notifNewMessage => 'رسالة جديدة';

  @override
  String get notifPhoto => '📷 صورة';

  @override
  String get notifVideo => '🎥 فيديو';

  @override
  String get notifVoice => '🎤 رسالة صوتية';

  @override
  String get notifDocument => '📄 مستند';

  @override
  String get notifSticker => 'ملصق';

  @override
  String get notifLocation => '📍 موقع';

  @override
  String get notifContact => '👤 جهة اتصال';

  @override
  String get notifPoll => '📊 استطلاع';

  @override
  String get notifMe => 'أنا';

  @override
  String get notifReply => 'رد';

  @override
  String get notifReplyHint => 'رسالتك';

  @override
  String get notifMarkRead => 'تعليم كمقروءة';

  @override
  String get notifReplyQueued => 'يُرسل عند فتح Pokou';

  @override
  String get notifReplyFailed => 'لم يُرسل الرد — افتح Pokou لإعادة المحاولة';

  @override
  String notifSummary(int count, int conversations) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسائل',
      one: 'رسالة واحدة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations محادثات',
      one: 'محادثة واحدة',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get audienceContacts => 'جهات اتصالي';

  @override
  String get audienceNobody => 'لا أحد';

  @override
  String get audienceExcept => 'جهات اتصالي ما عدا…';

  @override
  String get audienceOnly => 'فقط…';

  @override
  String get audienceContactsDesc => 'كل من في دفتر عناوين Pokou لديك';

  @override
  String get audienceNobodyDesc => 'لن تكون حالاتك مرئية إلا لك';

  @override
  String get audienceExceptDesc => 'جهات اتصالك، باستثناء من تختارهم';

  @override
  String get audienceOnlyDesc => 'الأشخاص الذين تختارهم فقط';

  @override
  String get statusViewerFallback => 'مستخدم';

  @override
  String get statusPrivacySaved => 'تم حفظ إعدادات الظهور.';

  @override
  String get statusPrivacySaveFailed => 'تعذّر الحفظ — تحقّق من اتصالك.';

  @override
  String get statusPrivacyTitle => 'ظهور الحالات';

  @override
  String get statusExcludePeople => 'الأشخاص المستبعدون';

  @override
  String get statusAllowedPeople => 'الأشخاص المسموح لهم';

  @override
  String get statusNoContactToOffer => 'لا توجد جهة اتصال Pokou لعرضها الآن.';

  @override
  String get statusExceptFootnote =>
      'لن يرى هؤلاء حالاتك، حتى لو كانوا ضمن جهات اتصالك.';

  @override
  String get statusOnlyFootnote =>
      'هؤلاء وحدهم سيرون حالاتك، ولا يلزم أن تكون لديهم ضمن جهات الاتصال.';

  @override
  String get status24hFootnote =>
      'تختفي الحالة على أي حال بعد 24 ساعة، للجميع.';

  @override
  String get statusGallery => 'المعرض';

  @override
  String get statusCamera => 'الكاميرا';

  @override
  String get statusNewTitle => 'حالة جديدة';

  @override
  String get statusText => 'نص';

  @override
  String get statusTypeHint => 'اكتب حالتك…';

  @override
  String get statusPublish => 'نشر';

  @override
  String get statusFeedTitle => 'المستجدات';

  @override
  String get statusFeedUnavailable => 'الحالات غير متاحة — أعد المحاولة';

  @override
  String get statusSection => 'الحالات';

  @override
  String get statusMine => 'أنا';

  @override
  String get channelsSection => 'القنوات';

  @override
  String get bcastNeedName => 'امنح هذه القائمة اسمًا.';

  @override
  String get bcastNeedRecipient => 'اختر مستلمًا واحدًا على الأقل.';

  @override
  String get bcastSaveFailed => 'تعذّر الحفظ.';

  @override
  String get bcastNewTitle => 'بث جديد';

  @override
  String get bcastEditTitle => 'تعديل القائمة';

  @override
  String get bcastNameHint => 'اسم القائمة (مرئي لك وحدك)';

  @override
  String get bcastNoRecipient => 'لا مستلمين';

  @override
  String bcastRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مستلم',
      many: '$count مستلمًا',
      few: '$count مستلمين',
      two: 'مستلمان',
      one: 'مستلم واحد',
    );
    return '$_temp0';
  }

  @override
  String get bcastContactsUnavailable => 'جهات الاتصال غير متاحة.';

  @override
  String get bcastNobodyOnPokou =>
      'لا أحد من جهات اتصالك على Pokou Messenger بعد.';

  @override
  String get bcastNewList => 'قائمة جديدة';

  @override
  String get bcastListsTitle => 'قوائم البث';

  @override
  String get bcastListsUnavailable => 'القوائم غير متاحة.';

  @override
  String bcastDeleteTitle(String name) {
    return 'حذف «$name»؟';
  }

  @override
  String get bcastDeleteBody =>
      'تبقى الرسائل المُرسلة لدى مستلميها. القائمة وحدها هي التي تختفي.';

  @override
  String get bcastEmptyTitle => 'أعلن مرة واحدة، للجميع';

  @override
  String get bcastEmptyBody =>
      'يتلقّى كل مستلم الرسالة في محادثته الخاصة. لا يرى الآخرين ويردّ عليك وحدك — بخلاف المجموعة حيث يرى الجميع بعضهم.';

  @override
  String bcastSentTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُرسلت إلى $count مستلم.',
      many: 'أُرسلت إلى $count مستلمًا.',
      few: 'أُرسلت إلى $count مستلمين.',
      two: 'أُرسلت إلى مستلمين.',
      one: 'أُرسلت إلى مستلم واحد.',
    );
    return '$_temp0';
  }

  @override
  String bcastSentPartly(int sent, int total, int skipped) {
    return 'أُرسلت إلى $sent من أصل $total — $skipped لم يعودوا يتلقّون رسائلك.';
  }

  @override
  String get bcastSendFailed => 'فشل الإرسال.';

  @override
  String get bcastEditRecipients => 'تعديل المستلمين';

  @override
  String get bcastHistoryUnavailable => 'السجل غير متاح.';

  @override
  String get bcastNothingSent => 'لم يُبثّ أي شيء بعد.';

  @override
  String get bcastMessageHint => 'رسالة للبثّ';

  @override
  String get bcastPrivacyNotice =>
      'يتلقّى كل مستلم هذه الرسالة على انفراد. لا يرى الآخرين، ويصلك ردّه في محادثتك معه.';

  @override
  String get channelNameRequired => 'اسم القناة إلزامي.';

  @override
  String get channelSaveFailed => 'تعذّر حفظ القناة.';

  @override
  String get channelEditTitle => 'تعديل القناة';

  @override
  String get channelNewTitle => 'قناة جديدة';

  @override
  String get channelAddImage => 'إضافة صورة';

  @override
  String get channelChangeImage => 'تغيير الصورة';

  @override
  String get channelRemoveImage => 'إزالة الصورة';

  @override
  String get channelNameLabel => 'اسم القناة';

  @override
  String get channelNameHint => 'مثال: أخبار شركتي';

  @override
  String get channelDescriptionLabel => 'الوصف';

  @override
  String get channelDescriptionHint => 'عرّف بقناتك';

  @override
  String get channelSaveChanges => 'حفظ التعديلات';

  @override
  String get channelCreateAction => 'إنشاء القناة';

  @override
  String get channelLinkCopiedClipboard => 'نُسخ الرابط إلى الحافظة.';

  @override
  String get channelLinkUnavailableShort => 'الرابط غير متاح.';

  @override
  String get channelSearchTooltip => 'البحث عن قناة';

  @override
  String get channelCreateTooltip => 'إنشاء قناة';

  @override
  String get channelEmptyHint => 'أنشئ قناة لمشاركة أخبارك.';

  @override
  String get channelGenerateLink => 'توليد رابط';

  @override
  String get channelEditTooltip => 'تعديل';

  @override
  String get channelSearchHint => 'ابحث عن قناة…';

  @override
  String get channelSearchPrompt =>
      'ابحث بالاسم أو الوصف. تظهر القنوات الموثّقة أولًا.';

  @override
  String get channelSearchEmpty => 'لم يُعثر على أي قناة.';

  @override
  String get channelNothingPublishedAdmin =>
      'لم يُنشر شيء بعد — المس + لأول منشور لك.';

  @override
  String get channelNothingPublished => 'لم تنشر هذه القناة أي شيء بعد.';

  @override
  String get channelFollow => 'اشترك';

  @override
  String get channelFallbackName => 'قناة';

  @override
  String get communityNewTitle => 'مجتمع جديد';

  @override
  String get communityNewBody =>
      'يجمع المجتمع عدة مجموعات حول الأشخاص أنفسهم. وتُنشأ معه مجموعة «إعلانات»: أنت وحدك من يكتب فيها، وجميع أعضائه يقرؤون.';

  @override
  String get communityNameHint => 'اسم المجتمع';

  @override
  String get communityDescriptionHint => 'الوصف (اختياري)';

  @override
  String get communityCreateAction => 'إنشاء';

  @override
  String get communityCreateFailed => 'تعذّر الإنشاء.';

  @override
  String get communityNoGroupToAttach =>
      'ليست لديك مجموعة أخرى لإلحاقها. لا يمكن أن تنضم إلى مجتمع إلا المجموعات التي تديرها.';

  @override
  String get communityAddGroupFailed => 'تعذّرت إضافة هذه المجموعة.';

  @override
  String get communityLinkFailed => 'تعذّر إنشاء الرابط.';

  @override
  String get communityCreateLink => 'إنشاء رابط';

  @override
  String get sparkOpenRoomsSub => 'تُغلق من تلقاء نفسها';

  @override
  String get sparkMore => 'المزيد';

  @override
  String sparkRoomOpen(String time) {
    return 'الغرفة مفتوحة — $time';
  }

  @override
  String get sparkBothYes => 'قلتما نعم كلاكما';

  @override
  String get sparkMatchSaved => 'تم إنقاذ التطابق';

  @override
  String get sparkRoomClosed => 'الغرفة مغلقة';

  @override
  String get sparkMatch => 'تطابق';

  @override
  String get sparkUnavailable => 'Spark غير متاح';

  @override
  String get sparkTodaysDate => 'موعد اليوم';

  @override
  String get sparkTabOutings => 'الخرجات';

  @override
  String sparkPersonAge(String name, int age) {
    return '$name، $age';
  }

  @override
  String get aiSuggestSummary => 'ملخّص';

  @override
  String get aiSuggestSummarySub => 'نظرة عامة سريعة';

  @override
  String get aiSuggestSummaryPrompt => 'قدّم لي ملخّصًا للوضع الحالي.';

  @override
  String get aiSuggestTrend => 'الاتجاه';

  @override
  String get aiSuggestTrendSub => 'تحليل تطوّر';

  @override
  String get aiSuggestTrendPrompt => 'ما الاتجاه خلال الأيام السبعة الماضية؟';

  @override
  String get aiSuggestAlerts => 'التنبيهات';

  @override
  String get aiSuggestAlertsSub => 'آخر الإشارات';

  @override
  String get aiSuggestAlertsPrompt => 'هل هناك تنبيهات حديثة ينبغي أن أعرفها؟';

  @override
  String get aiSuggestAdvice => 'نصيحة';

  @override
  String get aiSuggestAdviceSub => 'اطلب فكرة';

  @override
  String get aiSuggestAdvicePrompt => 'انصحني بكيفية تنظيم يومي.';

  @override
  String get aiSuggestWrite => 'الصياغة';

  @override
  String get aiSuggestWriteSub => 'كتابة نص';

  @override
  String get aiSuggestWritePrompt => 'ساعدني في صياغة رسالة.';

  @override
  String get aiSuggestQuestion => 'سؤال';

  @override
  String get aiSuggestQuestionSub => 'أي شيء';

  @override
  String get aiSuggestQuestionPrompt => 'لديّ سؤال أطرحه عليك.';

  @override
  String get aiMessageHint => 'رسالة…';

  @override
  String get aiHowCanIHelp => 'كيف يمكنني مساعدتك؟';

  @override
  String get aiAskAnything => 'اسألني عمّا تشاء.';

  @override
  String get aiAskAboutData => 'اطرح سؤالًا عن بياناتك المتصلة.';

  @override
  String get aiThinking => 'Baba يفكّر';

  @override
  String aiHelloIm(String name) {
    return 'مرحبًا، أنا $name';
  }

  @override
  String get aiPartner => 'شريكك الرقمي';

  @override
  String get aiGreetMorning => 'صباح الخير';

  @override
  String get aiGreetAfternoon => 'مساء الخير';

  @override
  String get aiGreetEvening => 'مساء الخير';

  @override
  String get aiNewChat => 'محادثة جديدة';

  @override
  String get aiCopy => 'نسخ';

  @override
  String get aiCopied => 'تم النسخ';

  @override
  String get aiGenerated => 'مُنشأ بالذكاء الاصطناعي';

  @override
  String get aiVoiceListening => 'أنا أستمع…';

  @override
  String get aiVoiceTranscribing => 'جارٍ التفريغ…';

  @override
  String get aiVoiceFailed => 'لم أتمكن من سماعك. حاول مرة أخرى.';

  @override
  String get aiVoiceSpeak => 'التحدث إلى المساعد';

  @override
  String get aiVoiceRestart => 'البدء من جديد';

  @override
  String get aiVoiceSend => 'إرسال';

  @override
  String get aiVoiceStop => 'إنهاء';

  @override
  String get aiSendFailed => 'لم تُرسَل الرسالة — أعد المحاولة.';

  @override
  String get digestTitle => 'ملخّص اليوم';

  @override
  String get digestUnread => 'الرسائل غير المقروءة:';

  @override
  String get digestMissedCalls => 'المكالمات الفائتة:';

  @override
  String get digestVideoSuffix => ' (فيديو)';

  @override
  String digestShieldDeferred(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة محتجزة بواسطة وضع الدرع.',
      many: '$count رسالة محتجزة بواسطة وضع الدرع.',
      few: '$count رسائل محتجزة بواسطة وضع الدرع.',
      two: 'رسالتان محتجزتان بواسطة وضع الدرع.',
      one: 'رسالة واحدة محتجزة بواسطة وضع الدرع.',
    );
    return '$_temp0';
  }

  @override
  String digestMonitorSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشارة من مراقبيك للاطّلاع.',
      many: '$count إشارة من مراقبيك للاطّلاع.',
      few: '$count إشارات من مراقبيك للاطّلاع.',
      two: 'إشارتان من مراقبيك للاطّلاع.',
      one: 'إشارة واحدة من مراقبيك للاطّلاع.',
    );
    return '$_temp0';
  }

  @override
  String get digestNothing => 'لا جديد اليوم — طاب مساؤك!';

  @override
  String get shieldUnknownNumber => 'رقم غير معروف';

  @override
  String shieldFlushSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة محتجزة أثناء اجتماعك.',
      many: '$count رسالة محتجزة أثناء اجتماعك.',
      few: '$count رسائل محتجزة أثناء اجتماعك.',
      two: 'رسالتان محتجزتان أثناء اجتماعك.',
      one: 'رسالة واحدة محتجزة أثناء اجتماعك.',
    );
    return '$_temp0';
  }

  @override
  String get shieldPendingMessages => 'الرسائل المعلّقة';

  @override
  String shieldHandleSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة محتجزة بواسطة وضع الدرع — اسحب للأسفل لعرضها',
      many: '$count رسالة محتجزة بواسطة وضع الدرع — اسحب للأسفل لعرضها',
      few: '$count رسائل محتجزة بواسطة وضع الدرع — اسحب للأسفل لعرضها',
      two: 'رسالتان محتجزتان بواسطة وضع الدرع — اسحب للأسفل لعرضهما',
      one: 'رسالة واحدة محتجزة بواسطة وضع الدرع — اسحب للأسفل لعرضها',
    );
    return '$_temp0';
  }

  @override
  String shieldCallFrom(Object name) {
    return 'مكالمة من $name';
  }

  @override
  String get shieldCallHeld => 'في الانتظار — وضع الدرع';

  @override
  String get statusViewersUnavailable => 'قائمة المشاهدات غير متاحة.';

  @override
  String statusSeenBy(int count) {
    return 'شاهده $count';
  }

  @override
  String get statusNobodySeen => 'لم يشاهده أحد بعد.';

  @override
  String get statusBoostFailed => 'تعذّر تعزيز الحالة.';

  @override
  String get statusDeleteTitle => 'حذف هذه الحالة؟';

  @override
  String get statusDeleteBody => 'ستختفي لدى كل من يمكنه رؤيتها.';

  @override
  String get statusDeleteFailed => 'تعذّر الحذف — تحقّق من اتصالك.';

  @override
  String get statusPublishFailed =>
      'تعذّر النشر — تحقّق من اتصالك وأعد المحاولة.';

  @override
  String get statusBoostAction => 'عزّز هذه الحالة · 1000 فرنك';

  @override
  String get modulesSubtitle => 'أضف ما يفيدك، ودع الباقي';

  @override
  String get modulePaymentFailed => 'تعذّر بدء الدفع.';

  @override
  String deeplinkFollowedChannel(String name) {
    return 'تم الاشتراك في قناة «$name»';
  }

  @override
  String get deeplinkOpenFailed => 'تعذّر فتح رابط الدعوة هذا الآن.';

  @override
  String get cropTitle => 'قصّ';

  @override
  String get cropHint => 'اقرص للتكبير، واسحب للتأطير';

  @override
  String get cropConfirm => 'تأكيد';

  @override
  String get inviteJoinMe => 'انضم إليّ على Pokou Messenger';

  @override
  String inviteJoinMeNamed(String name) {
    return '$name، انضم إليّ على Pokou Messenger';
  }

  @override
  String get otpNoCodeReceived => 'ألم تتلقَّ رمزًا؟';

  @override
  String get countryDialCode => 'رمز الاتصال الدولي';

  @override
  String get countrySearchHint => 'البلد أو الرمز (مثال: بنين، 229)';

  @override
  String get countryNoneFound => 'لم يُعثر على أي بلد.';

  @override
  String get presenceSomeone => 'شخص ما';

  @override
  String atTime(String time) {
    return 'في $time';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date في $time';
  }

  @override
  String truthAskedTo(String name) {
    return 'إلى $name';
  }

  @override
  String get devicesNoPushHere => 'هذا الجهاز لا يتلقّى الإشعارات.';

  @override
  String get devicesNoPushHereBody =>
      'لم يتمكّن من التسجيل في خدمة الإشعارات. المس لإعادة المحاولة.';

  @override
  String get devicesRetryDone => 'أصبح هذا الجهاز يتلقّى الإشعارات الآن.';

  @override
  String get devicesRetryFailed =>
      'ما زال التسجيل متعذّرًا — أعد المحاولة لاحقًا.';

  @override
  String get chatsProfileMissing =>
      'الملف الشخصي غير متاح — تحقّق من اتصالك ثم أعد المحاولة.';

  @override
  String get recSlideToCancel => 'اسحب للإلغاء';

  @override
  String get recReleaseToCancel => 'اترك للإلغاء';

  @override
  String get recLocked => 'مثبّت';

  @override
  String get recSlideUpToLock => 'اسحب للأعلى للتثبيت';

  @override
  String get recDelete => 'حذف التسجيل';

  @override
  String get recHoldToRecord => 'اضغط مطولًا للتسجيل';

  @override
  String get composerViewOnce => 'عرض لمرة واحدة';

  @override
  String get composerViewOnceOn =>
      'العرض لمرة واحدة مفعّل — ستختفي الصورة بعد فتحها.';

  @override
  String get composerViewOnceOff => 'العرض لمرة واحدة معطّل.';

  @override
  String get channelSuggestedTitle => 'قنوات تستحق المتابعة';

  @override
  String get channelSuggestedBody => 'لا تتابع أي قناة بعد. إليك بعضها.';

  @override
  String get channelSuggestedNone => 'لا توجد قناة لاقتراحها الآن.';

  @override
  String channelFollowed(String name) {
    return 'تتابع الآن «$name»';
  }

  @override
  String get channelFollowFailed => 'تعذّرت المتابعة — تحقّق من اتصالك.';

  @override
  String get certifyTitle => 'قناة موثّقة';

  @override
  String get certifyWhyTitle => 'شارة، وصدارة الاقتراحات';

  @override
  String get certifyWhyBody =>
      'تظهر القنوات الموثّقة أولًا لمن يبحث عمّا يتابعه، وتظهر الشارة على كل منشور.';

  @override
  String get certifyReviewTitle => 'مراجعة، لا عملية شراء';

  @override
  String get certifyReviewBody =>
      'يقرأ فريقنا قناتك قبل منح الشارة. شارة تُشترى دون مراجعة لا قيمة لها — وهذا ما يمنحها قيمتها.';

  @override
  String get certifyRefundTitle => 'مرفوضة؟ تُعاد إليك النقود';

  @override
  String get certifyRefundBody =>
      'إن تعذّر منح الشارة، تواصل معنا: يُعاد إليك المبلغ.';

  @override
  String get certifyRenewTitle => 'اشتراك، لا امتياز دائم';

  @override
  String get certifyRenewBody =>
      'تدوم الشارة بمدة الصيغة المختارة. التجديد قبل انتهائها يمدّدها دون فقدان شيء.';

  @override
  String get certifyPlanMonthly => 'شهري — 3000 فرنك';

  @override
  String get certifyPlanAnnual => 'سنوي — 30000 فرنك (شهران مجانًا)';

  @override
  String get certifyAction => 'ادفع وأرسل الطلب';

  @override
  String get certifyPending => 'يصل طلبك إلى الفريق فور تأكيد الدفع.';

  @override
  String get certifyFailed => 'تعذّر الطلب — أعد المحاولة.';

  @override
  String get certifyAlready => 'هذه القناة موثّقة';

  @override
  String get certifyTooltip => 'توثيق هذه القناة';

  @override
  String get chatsStartTitle => 'ابدأ محادثة';

  @override
  String get chatsStartBody =>
      'جهات اتصالك موجودة على Pokou. المس اسمًا لمراسلته.';

  @override
  String get chatsSeeAllContacts => 'عرض كل جهات اتصالي';

  @override
  String get chatsNoNetworkTitle => 'شبكتك ليست على Pokou بعد';

  @override
  String get chatsNoNetworkBody =>
      'ادعُ شخصًا، أو تابع قناة ريثما يردّ عليك أحد.';

  @override
  String get chatsInviteContacts => 'دعوة جهات اتصال';

  @override
  String get chatsDiscoverChannels => 'اكتشف قنوات';

  @override
  String get e2eeEncrypted => 'مشفّر من طرف إلى طرف';

  @override
  String get e2eeNotEncrypted => 'غير مشفّر';

  @override
  String get e2eeNotEncryptedBody =>
      'يجب على هذا الشخص تحديث Pokou لتفعيل التشفير.';

  @override
  String get e2eeIdentityChangedTitle =>
      'تغيّرت معلومات الأمان لجهة الاتصال هذه';

  @override
  String e2eeIdentityChangedBody(String name) {
    return 'تغيّر مفتاح أمان $name (هاتف جديد أو إعادة تثبيت). إن شككت، تحقّق مع $name.';
  }

  @override
  String get e2eeIdentityAccept => 'تحقّقت، متابعة';

  @override
  String get e2eeBlockedTitle => 'لم تُرسل الرسالة';

  @override
  String get e2eeBlockedLookup =>
      'تعذّر الحصول على مفتاح التشفير. لم تُرسل الرسالة — لن يرسلها Pokou دون تشفير من وراء ظهرك.';

  @override
  String get e2eeBlockedInvalid =>
      'المفتاح المستلَم غير صالح. لم تُرسل الرسالة، احتياطًا.';

  @override
  String get e2eeBlockedIdentity =>
      'تغيّر مفتاح جهة الاتصال هذه. تحقّق من هويتها قبل الإرسال.';

  @override
  String get e2eeBlockedCrypto => 'فشل التشفير. لم تُرسل الرسالة.';

  @override
  String get e2eeRetry => 'إعادة المحاولة';

  @override
  String get profileTheme => 'المظهر';

  @override
  String get themeSystem => 'حسب إعداد الهاتف';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeHint =>
      'الوضع الداكن أرفق بالعين ليلًا ويوفّر البطارية على شاشات OLED.';

  @override
  String get a11yBack => 'رجوع';

  @override
  String get a11yRefresh => 'تحديث';

  @override
  String get a11yMoreOptions => 'خيارات أخرى';

  @override
  String get a11yVoiceCall => 'مكالمة صوتية';

  @override
  String get a11yVideoCall => 'مكالمة فيديو';

  @override
  String get a11yAttach => 'إرفاق ملف';

  @override
  String get a11yRate => 'تقييم';

  @override
  String get a11yAudioLevel => 'مستوى الصوت';

  @override
  String get marketCreateAd => 'إنشاء إعلان';

  @override
  String get adSponsored => 'مُموَّل';

  @override
  String get adYours => 'إعلانك';

  @override
  String get adContact => 'تواصل';

  @override
  String get adContactFailed => 'تعذّر التواصل مع المعلِن.';

  @override
  String get mediaSaveToPhone => 'حفظ في الهاتف';

  @override
  String get mediaUndecryptable =>
      'تعذّرت قراءة المرفق المشفّر على هذا الهاتف.';

  @override
  String get mediaSaved => 'حُفظ في معرض الصور';

  @override
  String get mediaExported => 'اختر مكان الحفظ';

  @override
  String get mediaSavePermission =>
      'يحتاج Pokou إلى الوصول إلى صورك لحفظ هذا الملف.';

  @override
  String get mediaSaveNoSpace => 'لا توجد مساحة كافية على الهاتف.';

  @override
  String get mediaSaveFailed => 'تعذّر الحفظ.';

  @override
  String get composerEmoji => 'الرموز التعبيرية';

  @override
  String get convAttachGif => 'صورة متحركة';

  @override
  String get stickerTabEmoji => 'الرموز التعبيرية';

  @override
  String get stickerTabStickers => 'الملصقات';

  @override
  String get stickerSearchHint => 'ابحث عن ملصق';

  @override
  String get stickerRecents => 'الأخيرة';

  @override
  String get stickerFavorites => 'المفضلة';

  @override
  String get stickerNoResult => 'لم يُعثر على أي ملصق';

  @override
  String get stickerEmptyPanel => 'لا توجد ملصقات بعد';

  @override
  String get stickerBrowsePacks => 'تصفح الحزم';

  @override
  String get stickerManagePacks => 'إدارة الحزم';

  @override
  String get stickerPacksTitle => 'حزم الملصقات';

  @override
  String get stickerPackAdd => 'إضافة';

  @override
  String get stickerPackAdded => 'مضافة';

  @override
  String get stickerPackRemove => 'إزالة';

  @override
  String get stickerPackDelete => 'حذف الحزمة';

  @override
  String get stickerPackDeleteConfirm => 'هل تريد حذف هذه الحزمة وكل ملصقاتها؟';

  @override
  String get stickerMyPackName => 'ملصقاتي';

  @override
  String get stickerCreateFromPhoto => 'إنشاء من صورة';

  @override
  String get stickerCreated => 'أُضيف الملصق إلى ملصقاتك';

  @override
  String get stickerLimitReached => 'حزمتك الشخصية ممتلئة';

  @override
  String get stickerSendFailed => 'لم يُرسل الملصق — أعد المحاولة';

  @override
  String get stickerLabel => 'ملصق';

  @override
  String get stickerFavoriteAdded => 'أُضيف إلى المفضلة';

  @override
  String get stickerFavoriteRemoved => 'أُزيل من المفضلة';

  @override
  String get stickerStoreEmpty => 'لا توجد حزم متاحة بعد';

  @override
  String get stickerSaveToMine => 'إضافة إلى ملصقاتي';

  @override
  String get stickerSaved => 'أُضيف الملصق إلى ملصقاتك';

  @override
  String get navBaba => 'بابا';

  @override
  String get appBarOnline => 'متصل';

  @override
  String get appBarOffline => 'غير متصل';

  @override
  String get marketNegotiate => 'تفاوض';

  @override
  String get callsCallBack => 'إعادة الاتصال';

  @override
  String get callsFilterMissed => 'الفائتة';

  @override
  String get callsFilterAll => 'الكل';

  @override
  String get chatsFilterAll => 'الكل';

  @override
  String get chatsFilterUnread => 'غير المقروءة';

  @override
  String get chatsFilterGroups => 'المجموعات';

  @override
  String get chatsSearchOrAsk => 'ابحث أو اسأل بابا…';

  @override
  String get convEncryptedHint => 'رسالة مشفّرة…';

  @override
  String get chatsArchivedSection => 'المحادثات المؤرشفة';

  @override
  String get statusMineTitle => 'جديدي';

  @override
  String get statusMineBody => 'اضغط للنشر (24 ساعة)';

  @override
  String get statusMineVisibility => 'مرئي لجهات اتصالي';

  @override
  String get callLeaveConference => 'مغادرة المكالمة';

  @override
  String get callQualityExcellent => 'ممتاز';

  @override
  String get callQualityGood => 'جيد';

  @override
  String get callQualityPoor => 'ضعيف';

  @override
  String get callYouShort => 'أنت';

  @override
  String get callMutedShort => 'مكتوم';

  @override
  String get callMuteLabel => 'الميكروفون';

  @override
  String get callCameraLabel => 'الكاميرا';

  @override
  String get callSpeakerLabel => 'مكبر الصوت';

  @override
  String get callFlipCamera => 'تبديل الكاميرا';

  @override
  String get callFlipCameraFailed => 'تعذّر تبديل الكاميرا.';

  @override
  String get callNoAnswer => 'لا يوجد رد.';

  @override
  String callOngoingBanner(String duration) {
    return 'مكالمة جارية · $duration — اضغط للعودة';
  }

  @override
  String get callOngoingBannerRinging => 'مكالمة جارية — اضغط للعودة';

  @override
  String get callHangUp => 'إنهاء المكالمة';

  @override
  String get callInviteLabel => 'دعوة';

  @override
  String get e2eeReassurance =>
      'مشفّرة من طرف إلى طرف: لا يمكن لأحد غيركما، ولا حتى Pokou، قراءتها.';

  @override
  String get chatsEncryptionFooter => 'محادثاتك مشفّرة من طرف إلى طرف.';

  @override
  String get callsRecentSection => 'الأخيرة';

  @override
  String get callsGroupChip => 'مجموعة';

  @override
  String get callGroupNotEncrypted =>
      'مكالمة جماعية عادية — غير مشفّرة من طرف إلى طرف';

  @override
  String get marketCatalogueSeeAll => 'عرض الكل';

  @override
  String get marketCatalogueOpen => 'فتح كتالوجي';

  @override
  String get marketCatalogueTotal => 'الإعلانات';

  @override
  String get marketCatalogueOnline => 'منشورة';

  @override
  String get marketCatalogueBoostedLabel => 'مُعزَّزة';

  @override
  String get marketCatalogueWithdrawn => 'مسحوبة';

  @override
  String get marketFilterAll => 'الكل';

  @override
  String get marketCertifiedSellers => 'البائعون المعتمدون';

  @override
  String get marketCatalogueNoneInFilter => 'لا توجد إعلانات ضمن هذا التصنيف.';

  @override
  String get marketStatusModerated => 'أُزيل من السوق';

  @override
  String get marketStatusModeratedBody =>
      'لم يعد المشترون يرونه. راسل الدعم إذا كنت ترى أن هذا خطأ.';

  @override
  String get callsFilterDirect => 'فردي';

  @override
  String get profileMyAccount => 'حسابي';

  @override
  String get profileVerifyAccount => 'توثيق حسابي';

  @override
  String get profileVerifyAccountBody =>
      'احصل على شارة البائع الموثّق في السوق';

  @override
  String get profileCertificationPending => 'التوثيق قيد المراجعة';

  @override
  String get profileCertificationPendingBody => 'طلبك قيد المراجعة الآن.';

  @override
  String get profileCertificationActive => 'حساب موثّق';

  @override
  String get profileCertificationActiveBody => 'تظهر شارة التوثيق بجانب اسمك.';

  @override
  String get profileSellerCertified => 'بائع موثّق';

  @override
  String profileSellerCertifiedUntil(String date) {
    return 'شارة البائع سارية حتى $date.';
  }

  @override
  String get verifPlanLabel => 'اختر صيغتك';

  @override
  String get callEventAudio => 'مكالمة صوتية';

  @override
  String get callEventVideo => 'مكالمة فيديو';

  @override
  String get callEventGroup => 'مكالمة جماعية';

  @override
  String get callEventMissed => 'مكالمة فائتة';

  @override
  String get callEventNoAnswer => 'بلا ردّ';

  @override
  String get callEventDeclined => 'مرفوضة';

  @override
  String get callEventYouDeclined => 'رفضتها';

  @override
  String get callEventEnded => 'انتهت';

  @override
  String callEventSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ث',
    );
    return '$_temp0';
  }

  @override
  String callEventMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count د',
    );
    return '$_temp0';
  }

  @override
  String callEventHours(Object hours, Object minutes) {
    return '$hours س $minutes';
  }

  @override
  String callEventParticipants(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشارك',
    );
    return '$_temp0';
  }

  @override
  String get mediaCall => 'مكالمة';

  @override
  String get mediaSticker => 'ملصق';

  @override
  String get identityVerifiedAccount => 'حساب موثّق';

  @override
  String get privacyTitle => 'الخصوصية';

  @override
  String get privacyIntro =>
      'هذه الإعدادات يطبّقها الخادم: ما تخفيه لا يُرسل إلى الآخرين، لا يُخفى في التطبيق فحسب.';

  @override
  String get privacySectionWhoSees => 'من يمكنه رؤية معلوماتي';

  @override
  String get privacySectionMessages => 'الرسائل';

  @override
  String get privacySectionGroups => 'المجموعات';

  @override
  String get privacyLastSeen => 'آخر ظهور';

  @override
  String get privacyLastSeenBody => 'متى كنت متصلاً آخر مرة.';

  @override
  String get privacyOnline => 'الحضور على الإنترنت';

  @override
  String get privacyOnlineBody =>
      'النقطة الخضراء التي تعني أنك متاح الآن. مستقلة عن آخر ظهور.';

  @override
  String get privacyProfilePhoto => 'صورة الملف الشخصي';

  @override
  String get privacyProfilePhotoBody => 'صورتك أينما ظهرت.';

  @override
  String get privacyProfileInfo => 'معلومات الملف الشخصي';

  @override
  String get privacyProfileInfoBody => 'وصفك وما دوّنته عن نفسك.';

  @override
  String get privacyReadReceipts => 'إشعارات القراءة';

  @override
  String get privacyReadReceiptsBody =>
      'تعطيلها يحرمك أيضاً من إشعارات الآخرين. تبقى علامة التسليم ظاهرة.';

  @override
  String get privacyGroupInvites => 'من يمكنه دعوتي إلى مجموعة';

  @override
  String get privacyGroupInvitesBody =>
      'السماح ليس قبولاً: القرار الأخير يبقى لك في كل دعوة.';

  @override
  String get privacyGroupMembership => 'ظهور عضويتي في المجموعات';

  @override
  String get privacyGroupMembershipBody =>
      'من يرى المجموعات التي تنتمي إليها. أعضاء المجموعة يظلّون يعرفون بعضهم.';

  @override
  String get privacyEveryone => 'الجميع';

  @override
  String get privacyMyContacts => 'جهات اتصالي';

  @override
  String get privacyNobody => 'لا أحد';

  @override
  String get privacySaveFailed => 'لم يُحفظ الإعداد — أعد المحاولة.';

  @override
  String get privacyUnavailable => 'إعدادات الخصوصية غير متاحة.';

  @override
  String get privacyStatusesNote =>
      'تُضبط خصوصية الحالات من تبويب المستجدّات، حيث يمكنك أيضاً استثناء أشخاص بعينهم.';

  @override
  String groupInvitesSent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُرسلت $count دعوة',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationTitle => 'دعوة إلى مجموعة';

  @override
  String groupInvitationFrom(Object name) {
    return '$name يدعوك';
  }

  @override
  String groupInvitationMembers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationAccept => 'انضمام';

  @override
  String get groupInvitationReject => 'رفض';

  @override
  String groupInvitationExpires(Object hours) {
    return 'تنتهي خلال $hours س';
  }

  @override
  String get groupInvitationExpiresSoon => 'تنتهي قريباً';

  @override
  String groupInvitationsHeader(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوة',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationFailed =>
      'تعذّر التنفيذ — ربما لم تعد الدعوة صالحة.';

  @override
  String get mediaStatePreparing => 'جارٍ التحضير…';

  @override
  String get mediaStateSending => 'جارٍ الإرسال…';

  @override
  String mediaStateSendingPercent(Object percent) {
    return 'الإرسال · $percent ٪';
  }

  @override
  String get mediaStateWaitingNetwork => 'في انتظار الاتصال';

  @override
  String get mediaStateFailed => 'تعذّر الإرسال';

  @override
  String get mediaStateFileGone => 'لم يعد الملف على هذا الجهاز';

  @override
  String get channelPrivateLabel => 'قناة خاصة';

  @override
  String get channelPrivateBody =>
      'لا تظهر في البحث. لا ينضم ويقرأ منشوراتها إلا من تعطيه الرابط. لا يمكن تغيير ذلك لاحقاً.';

  @override
  String get channelPrivateBadge => 'خاصة';

  @override
  String get mahizuConnectTitle => 'اربط حسابك على Mahizu';

  @override
  String mahizuConnectBody(String phone) {
    return 'المساعد خدمة من Mahizu، منفصلة عن Pokou. لاستخدامه، اربط حسابك على Mahizu: سيُرسل رمز إلى $phone.';
  }

  @override
  String get mahizuSendCode => 'استلام الرمز';

  @override
  String get mahizuCodeLabel => 'الرمز المستلم';

  @override
  String get mahizuPinLabel => 'الرمز السري لحساب Mahizu';

  @override
  String get mahizuConfirm => 'ربط';

  @override
  String get mahizuRestart => 'البدء من جديد';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navKory => 'Kory';

  @override
  String get navMore => 'المزيد';

  @override
  String homeGreeting(String name) {
    return 'مرحبًا $name';
  }

  @override
  String get homeSeeAll => 'عرض الكل';

  @override
  String get homeNoChats => 'لا توجد محادثات بعد';

  @override
  String get homeKoryEmpty => 'لا يوجد صندوق جارٍ';

  @override
  String get homeSearchHint => 'ابحث عن محادثة';

  @override
  String get moreCertifiedTitle => 'Pokou موثَّق';

  @override
  String get moreCertifiedBody => 'هوية موثَّقة ووضع الإثبات: قريبًا.';

  @override
  String get moreSectionServices => 'الخدمات';

  @override
  String get moreSectionSettings => 'الإعدادات';

  @override
  String get moreAccount => 'الحساب والأمان';

  @override
  String get moreEdit => 'تعديل';

  @override
  String get koryTitle => 'Kory';

  @override
  String get korySubtitle => 'صناديق وجمعيات ادخار';

  @override
  String get koryMyPots => 'صناديقي';

  @override
  String get koryMonthTotal => 'مساهماتي المؤكَّدة هذا الشهر';

  @override
  String get koryNoMoney =>
      'لا يلمس Pokou المال: ينتقل مباشرة من محفظتك إلى محفظة الجامع.';

  @override
  String get koryCreate => 'إنشاء صندوق';

  @override
  String get koryJoin => 'انضمام';

  @override
  String get koryJournalTab => 'السجل';

  @override
  String get koryJoinTitle => 'الانضمام برمز';

  @override
  String get koryJoinHint => 'رمز الصندوق';

  @override
  String get koryJoinUnknown => 'رمز غير معروف أو صندوق مغلق.';

  @override
  String get koryNone => 'لا يوجد صندوق جارٍ';

  @override
  String get koryNoneBody =>
      'أنشئ صندوقًا لزفاف أو عقيقة أو اشتراك دوري، أو انضم إلى صندوق برمزه.';

  @override
  String get koryUnavailable => 'Kory غير متاح';

  @override
  String get koryKindCagnotte => 'صندوق';

  @override
  String get koryKindCotisation => 'اشتراك';

  @override
  String get koryTotalConfirmed => 'المجموع المؤكَّد';

  @override
  String koryGoal(String amount) {
    return 'الهدف: $amount';
  }

  @override
  String koryDue(String date) {
    return 'الموعد: $date';
  }

  @override
  String koryMyShare(String amount) {
    return 'حصتي المؤكَّدة: $amount';
  }

  @override
  String koryToReview(String count) {
    return 'بانتظار التأكيد: $count';
  }

  @override
  String get koryClosed => 'مغلق';

  @override
  String get koryOpen => 'مفتوح';

  @override
  String koryCollector(String name) {
    return 'الجامع: $name';
  }

  @override
  String koryPayTo(String phone) {
    return 'أرسل مساهمتك من محفظتك إلى $phone، ثم صرِّح بها هنا.';
  }

  @override
  String koryPerMember(String amount, String period) {
    return '$amount لكل عضو، $period';
  }

  @override
  String get koryDeclare => 'لقد ساهمت';

  @override
  String get koryDeclareTitle => 'التصريح بمساهمة';

  @override
  String get koryAmount => 'المبلغ (FCFA)';

  @override
  String get koryWalletRef => 'مرجع المعاملة (اختياري)';

  @override
  String get koryWalletRefHelp =>
      'تجده في رسالة المشغِّل. لا يراه إلا أنت والجامع.';

  @override
  String get koryNote => 'رسالة (اختياري)';

  @override
  String get koryPeriodLabel => 'الفترة المشمولة (مثل 2026-11)';

  @override
  String get koryJournal => 'سجل المساهمات';

  @override
  String get koryJournalEmpty => 'لم يُصرَّح بأي مساهمة بعد.';

  @override
  String get koryStatusDeclared => 'بانتظار الجامع';

  @override
  String get koryStatusConfirmed => 'مؤكَّدة';

  @override
  String get koryStatusRejected => 'متنازع عليها';

  @override
  String get koryConfirm => 'استُلم';

  @override
  String get koryReject => 'لم يُستلَم';

  @override
  String get koryCloseAction => 'إغلاق';

  @override
  String get koryCloseConfirm =>
      'إغلاق الصندوق؟ لن يتمكن أحد من التصريح بمساهمة بعد ذلك.';

  @override
  String koryShareCode(String code) {
    return 'الرمز: $code';
  }

  @override
  String koryShareText(String title, String code) {
    return 'انضم إلى صندوق «$title» على Pokou بالرمز $code.';
  }

  @override
  String get koryCreateTitle => 'صندوق جديد';

  @override
  String get koryFieldTitle => 'العنوان';

  @override
  String get koryFieldDescription => 'الوصف (اختياري)';

  @override
  String get koryFieldGoal => 'الهدف بالـ FCFA (اختياري)';

  @override
  String get koryFieldPerMember => 'المبلغ لكل عضو (FCFA)';

  @override
  String get koryPeriodMonthly => 'كل شهر';

  @override
  String get koryPeriodWeekly => 'كل أسبوع';

  @override
  String get koryFieldDue => 'الموعد (اختياري)';

  @override
  String get koryNeedTitle => 'أدخل عنوانًا (3 أحرف على الأقل).';

  @override
  String get koryNeedAmount => 'أدخل مبلغًا لا يقل عن 100 FCFA.';

  @override
  String get koryCollectorIsYou =>
      'أنت الجامع: تصل المساهمات إلى محفظتك، وأنت من يؤكدها.';

  @override
  String get koryYou => 'أنت';

  @override
  String get koryTontinePlus => 'جمعية ادخار دوّارة: قريبًا مع Kory Plus';

  @override
  String get koryDeclared => 'تم التصريح بالمساهمة. سيؤكدها الجامع.';

  @override
  String get koryCopyPhone => 'نسخ الرقم';

  @override
  String get koryCopied => 'تم النسخ';

  @override
  String get koryActionFailed => 'لم تنجح العملية. حاول مرة أخرى.';

  @override
  String get welcomePromise => 'أكثر من تطبيق مراسلة، إنه مجتمع.';

  @override
  String get welcomeSignature => 'معًا، أقوى.';

  @override
  String get welcomeServiceChats => 'محادثات ومجموعات ومكالمات';

  @override
  String get welcomeServiceKory => 'صناديق وجمعيات ادخار';

  @override
  String get legalPrivacy => 'الخصوصية';

  @override
  String get legalTerms => 'شروط الاستخدام';

  @override
  String get legalUnavailable => 'المستند غير متاح حاليًا.';

  @override
  String onbStep(String step) {
    return 'الخطوة $step من 3';
  }

  @override
  String get onbProfileTitle => 'ملفك الشخصي';

  @override
  String get onbProfileBody => 'هذا هو الاسم الذي ستراه جهات اتصالك.';

  @override
  String get onbDisplayName => 'الاسم المعروض';

  @override
  String get onbNameRequired => 'أدخل اسمًا (حرفان على الأقل).';

  @override
  String get onbPhotoLater => 'يمكنك إضافة صورة لاحقًا من ملفك الشخصي.';

  @override
  String get onbContinue => 'متابعة';

  @override
  String get onbTermsTitle => 'قبل أن تبدأ';

  @override
  String get onbAcceptTerms =>
      'قرأت شروط الاستخدام وسياسة الخصوصية وأوافق عليهما.';

  @override
  String get onbAge => 'أبلغ السن المطلوبة لاستخدام Pokou.';

  @override
  String get onbOptional => 'اختياري، ويمكن تغييره في أي وقت من الإعدادات';

  @override
  String get onbAnalytics => 'مشاركة إحصاءات الاستخدام لتحسين Pokou';

  @override
  String get onbMarketing => 'تلقي أخبار Pokou وعروضه';

  @override
  String get onbFinish => 'إنهاء';

  @override
  String get onbFailed => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String get moreConsents => 'الإحصاءات والمراسلات';

  @override
  String get navHonam => 'Honam';

  @override
  String get honamSubtitle => 'صيدليات وتوصيل';

  @override
  String get honamIntro =>
      'ترسل إليك صيدلية قريبة عرض السعر. ادفع من محفظتك وسيوصل الطلب مندوب.';

  @override
  String get honamSend => 'إرسال وصفة طبية';

  @override
  String get honamPhotograph => 'تصوير الوصفة';

  @override
  String get honamFromGallery => 'اختيار صورة';

  @override
  String get honamUrgent => 'طوارئ';

  @override
  String get honamNotEmergency => 'Pokou ليس خدمة طوارئ.';

  @override
  String get honamNearby => 'صيدليات قريبة';

  @override
  String get honamOnDuty => 'مناوبة';

  @override
  String get honamNoPharmacy => 'لا توجد صيدلية شريكة حاليًا.';

  @override
  String get honamCurrentOrder => 'طلب جارٍ';

  @override
  String get honamMyOrders => 'طلباتي';

  @override
  String get honamChoosePharmacy => 'اختر الصيدلية';

  @override
  String get honamAddress => 'عنوان التوصيل';

  @override
  String get honamNote => 'ملاحظة للصيدلي (اختياري)';

  @override
  String get honamSubmit => 'إرسال إلى الصيدلية';

  @override
  String get honamNeedPhoto => 'أضف صورة الوصفة.';

  @override
  String get honamNeedAddress => 'أدخل عنوان التوصيل.';

  @override
  String get honamFailed => 'لم تنجح العملية. حاول مرة أخرى.';

  @override
  String honamOrderTitle(String id) {
    return 'الطلب رقم $id';
  }

  @override
  String get honamStSubmitted => 'أُرسلت، بانتظار الصيدلي';

  @override
  String get honamStQuoted => 'تم استلام عرض السعر';

  @override
  String get honamStAccepted => 'تم قبول العرض، بانتظار الدفع';

  @override
  String get honamStPaid => 'مدفوع، قيد التحضير';

  @override
  String get honamStReady => 'جاهز، بانتظار المندوب';

  @override
  String get honamStInDelivery => 'قيد التوصيل';

  @override
  String get honamStDelivered => 'تم التوصيل';

  @override
  String get honamStRejected => 'رُفضت الوصفة';

  @override
  String get honamStExpired => 'انتهت صلاحية العرض';

  @override
  String get honamStCancelled => 'أُلغي';

  @override
  String get honamQuote => 'عرض السعر';

  @override
  String get honamUnavailableItem => 'غير متوفر';

  @override
  String get honamMedicines => 'الأدوية';

  @override
  String get honamDelivery => 'التوصيل';

  @override
  String get honamTotal => 'المجموع المستحق';

  @override
  String get honamAcceptQuote => 'قبول العرض';

  @override
  String honamPayTo(String amount, String phone) {
    return 'أرسل $amount من محفظتك إلى $phone (الصيدلية)، ثم أكّد.';
  }

  @override
  String get honamDeclarePaid => 'لقد دفعت للصيدلية';

  @override
  String get honamPaidDeclared => 'تم الإبلاغ عن الدفع: ستؤكده الصيدلية.';

  @override
  String get honamPaymentNotReceived =>
      'لم تستلم الصيدلية دفعتك. تحقق من الرقم والمبلغ.';

  @override
  String get honamCode => 'رمز الاستلام';

  @override
  String get honamCodeHelp =>
      'أعطِ هذا الرمز للمندوب فقط عندما يكون الطرد في يدك.';

  @override
  String get honamOriginal => 'سيستلم المندوب الوصفة الأصلية.';

  @override
  String honamRefundDue(String amount, String reason) {
    return 'تدين لك الصيدلية بـ $amount: $reason';
  }

  @override
  String get honamRefundReceived => 'استلمت المبلغ المسترد';

  @override
  String get honamCancel => 'إلغاء الطلب';

  @override
  String get honamResend => 'إرسال إلى صيدلية أخرى';

  @override
  String honamReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get honamTimeline => 'التتبع';

  @override
  String get honamOrderMessages => 'رسائل الطلب';

  @override
  String get honamWriteMessage => 'اكتب رسالة';

  @override
  String get honamCourierMode => 'وضع المندوب';

  @override
  String get honamCourierJoin => 'كن مندوب Win Pokou';

  @override
  String get honamCourierJoinBody =>
      '5 توصيلات تجريبية بلا عمولة لمدة شهر. بعد ذلك: عضوية Win Pokou وباقة مدفوعة مسبقًا.';

  @override
  String honamRidesLeft(String count) {
    return 'التوصيلات المتبقية: $count';
  }

  @override
  String get honamUnlimited => 'توصيلات غير محدودة';

  @override
  String honamMembership(String amount) {
    return 'عضوية Win Pokou: $amount دون ضريبة / شهر';
  }

  @override
  String get honamPayMembership => 'دفع العضوية';

  @override
  String get honamPacks => 'باقات التوصيل';

  @override
  String honamPackPrice(String amount) {
    return '$amount دون ضريبة';
  }

  @override
  String get honamAvailableRides => 'التوصيلات المتاحة';

  @override
  String get honamMyRides => 'توصيلاتي';

  @override
  String get honamNoRides => 'لا توجد توصيلات حاليًا.';

  @override
  String get honamAcceptRide => 'قبول التوصيل';

  @override
  String get honamPickup => 'تم استلام الطرد';

  @override
  String get honamDeliver => 'تأكيد التسليم';

  @override
  String get honamEnterCode => 'الرمز الذي قدّمه المريض';

  @override
  String get honamCoursePaid => 'استلمت أجرة التوصيل';

  @override
  String get honamPaymentLinkOpened => 'أكمل الدفع في الصفحة التي ستُفتح.';

  @override
  String get honamCourierSuspended =>
      'عُلّق حساب المندوب بعد 3 إخفاقات في التوصيل. تواصل مع الدعم للطعن.';

  @override
  String get honamPriceNote => 'الأسعار دون ضريبة؛ تُضاف ضريبة البلد.';

  @override
  String get certTitle => 'Pokou موثَّق';

  @override
  String get certPitch =>
      'تثبت الشارة أن اسمك هو اسمك حقًا. يُبقي وضع الإثبات رسائل المجموعة المحذوفة ظاهرة ومشطوبة.';

  @override
  String get certHowItWorks =>
      'يتم التحقق من هويتك عبر اسم صاحب المحفظة التي تدفع منها.';

  @override
  String certStartTrial(String days) {
    return 'جرّب $days يومًا';
  }

  @override
  String get certTrialNote =>
      'أثناء التجربة يتوفر وضع الإثبات؛ تظهر الشارة عند أول دفعة.';

  @override
  String certPlanPrice(String ht, String ttc) {
    return '$ht دون ضريبة · $ttc مع الضريبة';
  }

  @override
  String get certSubscribe => 'اختيار';

  @override
  String get certActive => 'الشارة مفعّلة';

  @override
  String certTrialUntil(String date) {
    return 'تجربة حتى $date';
  }

  @override
  String certActiveUntil(String date) {
    return 'مفعّل حتى $date';
  }

  @override
  String get certExpired => 'انتهى الاشتراك';

  @override
  String get certMismatchTitle => 'الاسمان غير متطابقين';

  @override
  String get certMismatchBody =>
      'الاسم المُدخل لا يطابق اسم صاحب المحفظة التي دفعت. صحّحه كما هو في بطاقة الهوية.';

  @override
  String get proofModeTitle => 'وضع الإثبات';

  @override
  String get proofModeOnBanner =>
      'وضع الإثبات مفعّل: تبقى الرسالة المحذوفة ظاهرة ومشطوبة للجميع.';

  @override
  String get proofModeEnable => 'تفعيل وضع الإثبات';

  @override
  String get proofModeDisable => 'إيقاف وضع الإثبات';

  @override
  String get proofModeNeedsCert =>
      'يتطلب وضع الإثبات Pokou موثَّق (تتوفر تجربة مجانية).';

  @override
  String get deleteForAll => 'حذف لدى الجميع';

  @override
  String get deleteProofWarning =>
      'وضع الإثبات مفعّل: ستبقى الرسالة ظاهرة ومشطوبة لجميع الأعضاء.';

  @override
  String get deletedKept => 'رسالة محذوفة، احتفظ بها وضع الإثبات';

  @override
  String get certCorrectName => 'الاسم الكامل لصاحب المحفظة';

  @override
  String get certRetryName => 'تحقق من هذا الاسم';

  @override
  String get certStillMismatch => 'هذا الاسم لا يزال غير مطابق.';

  @override
  String get proofExport => 'تصدير المحادثة (PDF)';

  @override
  String proofModeOn(String name) {
    return 'فعّل $name وضع الإثبات';
  }

  @override
  String proofModeOff(String name) {
    return 'أوقف $name وضع الإثبات';
  }

  @override
  String proofOriginal(String text) {
    return 'النسخة الأصلية: $text';
  }

  @override
  String get proofDisableReserved =>
      'لا يمكن إيقافه إلا لمن فعّله أو لمشرف يملك شارة مدفوعة.';

  @override
  String get marketBoost3 => '3 أيام · 600 FCFA';

  @override
  String get marketBoost7 => '7 أيام · 1300 FCFA';

  @override
  String get marketUseHonam => 'لا تُباع الأدوية على Assimé: استخدم Honam.';

  @override
  String get honamMissingTitle => 'هناك منتج ناقص';

  @override
  String honamMissingBody(String amount, String reason) {
    return 'ينقص $amount: $reason. ماذا تفضّل؟';
  }

  @override
  String get honamKeepRest => 'استلام الباقي';

  @override
  String get honamCancelAll => 'إلغاء الكل';

  @override
  String get honamRefundDelay =>
      'تعيد الصيدلية المبلغ خلال ساعتين إلى الرقم الذي دفع.';

  @override
  String get honamZones => 'المناطق والأوقات (مثل Bè وTokoin — مساءً)';

  @override
  String get honamWallet => 'رقم المحفظة التي تستلم أجرة التوصيل';

  @override
  String get honamRules =>
      'أقبل القواعد الذهبية: أسلّم الطرد مقابل الرمز فقط، ولا أطّلع على الوصفات، وأبقى مهذّبًا.';

  @override
  String get honamApply => 'إرسال طلبي';

  @override
  String get honamPending => 'أُرسل الطلب: يراجعه فريق Pokou.';

  @override
  String get honamLaunch => 'فترة الإطلاق: توصل دون عضوية أو باقة.';

  @override
  String get honamQueenLocked =>
      'تُفتح Queen Pokou بعد شهر دون إخفاق في التوصيل.';

  @override
  String koryDeclaredTotal(String amount) {
    return 'المجموع المصرّح به: $amount';
  }

  @override
  String koryRemaining(String amount) {
    return 'المتبقي للجمع: $amount';
  }

  @override
  String get onbBabaWelcome => 'أنا Baba، مساعد Pokou. بماذا تحب أن نناديك؟';

  @override
  String get onbContactsTitle => 'العثور على أحبّائك';

  @override
  String get onbContactsBody =>
      'يمكن لـ Baba العثور على جهات اتصالك الموجودة على Pokou. يمكنك الرفض: سنسألك لاحقًا.';

  @override
  String get onbContactsAllow => 'سماح';

  @override
  String get onbLater => 'لاحقًا';

  @override
  String get proofModeDirectHint =>
      'كل ما يُكتب يبقى قابلاً للإثبات: الرسالة المحذوفة تبقى مشطوبة، والتعديل يحتفظ بالأصل. أنت وحدك من يستطيع إيقافه.';

  @override
  String get proofDisableReservedDirect =>
      'وحده من فعّل وضع الإثبات يمكنه إيقافه.';

  @override
  String get proofExportMe => 'أنا';

  @override
  String get proofExportTitle => 'Pokou — تصدير وضع الإثبات';

  @override
  String proofExportBetween(String me, String contact) {
    return 'محادثة بين $me و$contact';
  }

  @override
  String proofExportPeriod(String since, String now) {
    return 'وضع الإثبات مفعّل منذ $since · صُدِّر في $now من هذا الهاتف';
  }

  @override
  String proofExportFooter(String page, String pages) {
    return 'الصفحة $page من $pages — أُنشئ على الجهاز: لا يصل خادم Pokou إلى الرسائل المشفّرة.';
  }

  @override
  String get proofExportAttachment => '[مرفق]';

  @override
  String proofExportEdited(String at) {
    return 'عُدّل في $at';
  }

  @override
  String proofExportDeleted(String at) {
    return 'حُذف في $at، واحتفظ به وضع الإثبات';
  }

  @override
  String get proTitle => 'Pokou موثّق Pro';

  @override
  String get proTeaser => 'لنشاط تجاري: الاسم التجاري و«يديره»';

  @override
  String get proPitch =>
      'يظهر اسمك التجاري أولاً، مع «يديره» واسمك الموثّق. سيضم ملف Pro إعلاناتك على Assimé.';

  @override
  String proSteps(String hours) {
    return '1. ترسل الوثيقة. 2. يتحقق منها الدعم خلال $hours ساعة. 3. لا تدفع إلا بعد الموافقة.';
  }

  @override
  String proPending(String due) {
    return 'التحقق جارٍ. الرد في موعد أقصاه $due.';
  }

  @override
  String get proApproved =>
      'تمت الموافقة على الوثيقة: يمكنك تفعيل Pokou موثّق Pro.';

  @override
  String get proPay => 'ادفع Pokou موثّق Pro';

  @override
  String get proCorrection => 'الوثيقة بحاجة إلى تصحيح';

  @override
  String get proRejected => 'رُفض الطلب';

  @override
  String get proActivity => 'نشاطك';

  @override
  String get proBusinessName => 'الاسم التجاري';

  @override
  String get proActivityField => 'النشاط (خياطة، متجر، نقل…)';

  @override
  String get proDocument => 'أضف الوثيقة';

  @override
  String get proDocumentChosen => 'أُضيفت الوثيقة — المس للتغيير';

  @override
  String get proDocumentNote =>
      'السجل التجاري أو البطاقة المهنية أو الرخصة. يراها الدعم فقط، ولا تُعرض أبداً.';

  @override
  String get proSend => 'أرسل للتحقق';

  @override
  String proManagedBy(String name) {
    return 'يديره $name';
  }

  @override
  String get proProfileNote => 'هكذا يرى الآخرون ملفك Pro.';

  @override
  String get honamCity => 'المدينة';

  @override
  String get honamOtherCity => 'مدينة أخرى';

  @override
  String get honamYourCity => 'مدينتك';

  @override
  String get honamNotServed =>
      'لا يوصّل Honam بعد إلى هذه المدينة. سجّل وسنخبرك عند الافتتاح.';

  @override
  String get honamJoinWaitlist => 'سجّلني في قائمة الانتظار';

  @override
  String honamWaitlistDone(String city) {
    return 'مسجّل لـ$city';
  }

  @override
  String get honamWaitlistBody =>
      'سنخبرك فور بدء Honam التوصيل في مدينتك. لا شيء غير ذلك.';

  @override
  String get honamReferralCodeField => 'رمز الإحالة (اختياري)';

  @override
  String get honamReferralTitle => 'ادعُ ساعياً';

  @override
  String honamReferralBody(String rides) {
    return '$rides توصيلات مجانية عند أول توصيل لمن دعوته.';
  }

  @override
  String get honamReferralShare => 'شارك رمزي';

  @override
  String honamReferralMessage(String code) {
    return 'وصّل لـHonam مع Pokou: استخدم رمز الإحالة $code في وضع الساعي.';
  }

  @override
  String honamReferralCount(String count) {
    return 'المدعوون: $count';
  }

  @override
  String get honamTrialEnded => 'انتهت فترتك التجريبية';

  @override
  String honamRecommendedPack(String pack) {
    return 'بحسب توصيلاتك هذا الشهر، تكفيك باقة $pack.';
  }

  @override
  String get honamNavigate => 'المسار في تطبيق الخرائط';

  @override
  String get honamLocationShared =>
      'تُشارك موقعك كل 15 ثانية أثناء التوصيل، ولا تُشارك بعده.';

  @override
  String get honamLocationDenied => 'اسمح بتحديد الموقع ليتابع المريض التوصيل.';

  @override
  String get honamCourier => 'الساعي';

  @override
  String honamTrackingTitle(String name) {
    return '$name في الطريق';
  }

  @override
  String get honamTrackingWaiting => 'لم يصل الموقع بعد.';

  @override
  String honamTrackingDistance(String km) {
    return 'على بعد $km كم منك';
  }

  @override
  String honamTrackingUpdated(String minutes) {
    return 'حُدّث منذ $minutes دقيقة';
  }

  @override
  String get honamTrackingStale => 'الموقع غير محدّث';

  @override
  String get honamTrackingShowMap => 'اعرض على الخريطة';

  @override
  String get honamTrackingMapDataSaver => 'اعرض على الخريطة (يستهلك البيانات)';

  @override
  String get assimeFavoritesAlerts => 'المفضلة والتنبيهات';

  @override
  String get assimeFavorites => 'المفضلة';

  @override
  String get assimeAlerts => 'التنبيهات';

  @override
  String get assimeNoFavorites => 'لا مفضلات';

  @override
  String get assimeFavoritesHint => 'المس القلب في الإعلان لتحتفظ به هنا.';

  @override
  String get assimeAddFavorite => 'أضف إلى المفضلة';

  @override
  String get assimeRemoveFavorite => 'أزل من المفضلة';

  @override
  String get assimeNewAlert => 'تنبيه جديد';

  @override
  String get assimeAlertQuery => 'ما تبحث عنه';

  @override
  String get assimeAlertMaxPrice => 'أقصى سعر (اختياري)';

  @override
  String get assimeAlertNote =>
      'سنخبرك عند ظهور إعلان مطابق. لا يقرأ التنبيه سوى الإعلانات، ولا يقرأ رسائلك أبداً.';

  @override
  String get assimeNoAlerts => 'لا تنبيهات حالياً.';

  @override
  String assimeAlertUpTo(String price) {
    return 'حتى $price فرنك';
  }

  @override
  String assimeAlertMatches(String count) {
    return '$count إعلان موجود';
  }

  @override
  String get assimeSponsored => 'مُموَّل';

  @override
  String get assimeWhyTitle => 'لماذا أرى هذا';

  @override
  String get assimeWhyNotSponsored => 'لم يعد هذا الإعلان مُروَّجاً.';

  @override
  String get assimeReportTitle => 'حصيلة الترويج';

  @override
  String get assimeReportEmpty => 'لا ترويج لهذا الإعلان بعد.';

  @override
  String assimeReportPeriod(String days, String start, String end) {
    return '$days أيام · من $start إلى $end';
  }

  @override
  String assimeReportImpressions(String count) {
    return 'ظهر أعلى النتائج: $count مرة';
  }

  @override
  String assimeReportStatusViews(String count) {
    return 'شوهد في الحالات: $count مرة';
  }

  @override
  String assimeReportContacts(String count) {
    return 'أشخاص تواصلوا معك: $count';
  }

  @override
  String get assimeStatusPending => 'مكان في الحالات: قيد مراجعة الإشراف';

  @override
  String get assimeStatusRejected => 'رفض الإشراف المكان في الحالات';

  @override
  String get koryKindTontine => 'تونتين';

  @override
  String get koryFieldStake => 'مساهمة كل عضو في الدورة (فرنك)';

  @override
  String get koryRotation => 'ترتيب الدورات';

  @override
  String get koryRotationHint =>
      'اسحب للترتيب. يُثبَّت الترتيب عند الفتح ولا يتغير.';

  @override
  String get koryRemoveFromRotation => 'أزل من التونتين';

  @override
  String get koryNeedRotation => 'يحتاج التونتين إلى مشاركَين على الأقل.';

  @override
  String get koryTontineNote =>
      'في كل دورة، يرسل كل عضو مساهمته إلى محفظة المستفيد، الذي يؤكد ما استلمه. لا يلمس Pokou المال أبداً.';

  @override
  String get koryRounds => 'الدورات';

  @override
  String koryRoundNumber(String number) {
    return 'الدورة $number';
  }

  @override
  String koryRoundConfirmed(String confirmed, String expected) {
    return '$confirmed مؤكَّد من $expected';
  }

  @override
  String get koryNextRound => 'انتقل إلى الدورة التالية';

  @override
  String get koryNextRoundBody =>
      'تنتهي الدورة الحالية. تبقى المساهمات المعلنة بانتظار تأكيد مستفيدها.';

  @override
  String get koryLastRoundBody =>
      'كانت هذه الدورة الأخيرة: سيُغلق التونتين. يبقى السجل متاحاً.';

  @override
  String get welcomeStart => 'ابدأ';

  @override
  String get authAcceptAndContinue => 'الموافقة والمتابعة';

  @override
  String get authAcceptNotice =>
      'بلمس «الموافقة والمتابعة»، فإنك توافق على شروط الاستخدام وسياسة الخصوصية، وتقرّ بأنك بالغ السن المطلوب.';

  @override
  String get deleteAccountTitle => 'حذف حسابي';

  @override
  String get deleteAccountWarning => 'هذا الإجراء نهائي.';

  @override
  String get deleteAccountRemovedTitle => 'ما سيُحذف';

  @override
  String get deleteAccountRemovedProfile =>
      'ملفك الشخصي وصورتك ونسختك الاحتياطية';

  @override
  String get deleteAccountRemovedChats => 'محادثاتك على هذا الهاتف';

  @override
  String get deleteAccountRemovedBadge => 'شارتك، دون استرداد الشهر الجاري';

  @override
  String get deleteAccountKeptTitle => 'ما يبقى';

  @override
  String get deleteAccountKeptMessages =>
      'الرسائل التي استلمها جهات اتصالك بالفعل';

  @override
  String get deleteAccountKeptProof =>
      'سجلات وضع الإثبات لدى المشاركين الآخرين';

  @override
  String get deleteAccountKeptKory => 'سجل صناديق Kory الذي لا يُمحى';

  @override
  String get deleteAccountConfirmLabel => 'أكّد رقمك';

  @override
  String get deleteAccountMismatch => 'هذا الرقم لا يطابق حسابك.';

  @override
  String get deleteAccountFailed => 'فشل الحذف. حاول مرة أخرى.';

  @override
  String get helpTitle => 'المساعدة والدعم';

  @override
  String get helpSearchHint => 'ابحث في المساعدة';

  @override
  String get helpAskBaba => 'اسأل بابا';

  @override
  String get helpAskBabaSub => 'يجيب المساعد الذكي فورًا';

  @override
  String get helpFaqTitle => 'الأسئلة الشائعة';

  @override
  String get helpQMoney => 'هل يتعامل Pokou مع أموالي؟';

  @override
  String get helpAMoney =>
      'لا. تُدفع الصناديق والصيدليات والمندوبون من محفظة إلى محفظة. لا يحتفظ Pokou بأموالك أبدًا.';

  @override
  String get helpQProof => 'كيف يعمل وضع الإثبات؟';

  @override
  String get helpAProof =>
      'يفعّله حامل شارة Pokou الموثّق، فتبقى الرسائل المحذوفة أو المعدّلة ظاهرة مشطوبة. ويُعرض ذلك دائمًا أعلى المحادثة.';

  @override
  String get helpQSms => 'لا يصلني رمز الرسائل القصيرة';

  @override
  String get helpASms =>
      'تحقق من الرقم والشبكة، ثم انتظر انتهاء العد التنازلي لطلب رمز جديد. لن يطلب منك Pokou هذا الرمز أبدًا، لا برسالة ولا بمكالمة.';

  @override
  String get helpQCourier => 'كيف أصبح مندوب توصيل في Honam؟';

  @override
  String get helpACourier =>
      'في «المزيد»، اضغط «كن مندوب Honam»: الهوية والمناطق والمحفظة والقواعد الذهبية. يفتح Honam مدينةً تلو الأخرى.';

  @override
  String get helpQScam => 'كيف أكتشف عملية احتيال؟';

  @override
  String get helpAScam =>
      'احذر ممن يطلب رمز رسالة قصيرة أو رمزك السري أو دفعًا عاجلًا. Pokou لا يفعل ذلك أبدًا. احظر جهة الاتصال وأبلغ عنها.';

  @override
  String get helpSupport => 'راسل الدعم';

  @override
  String get helpSupportSub => 'الرد داخل التطبيق';

  @override
  String get helpReport => 'الإبلاغ عن مشكلة';

  @override
  String get helpNoResult => 'لا يوجد سؤال مطابق. اسأل بابا.';

  @override
  String get aboutTitle => 'حول Pokou';

  @override
  String aboutVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get aboutNamesTitle => 'معنى أسمائنا';

  @override
  String get aboutPokou => 'اسم من لغة الباولي';

  @override
  String get aboutKory => 'صدفة الودع';

  @override
  String get aboutHonam => '«ساعدني» بلغة الإيوي';

  @override
  String get aboutAssime => '«في السوق» بلغة الإيوي';

  @override
  String get aboutWetri => '«شهر» بلغة الإيوي';

  @override
  String get aboutEpe => '«سنة» بلغة الإيوي';

  @override
  String get aboutNextNames =>
      'ستحمل خدماتنا القادمة أيضًا أسماءً من لغات أفريقية.';

  @override
  String get aboutLicenses => 'تراخيص البرمجيات الحرة';

  @override
  String get legalEssentials => 'الأساسيات';

  @override
  String get legalFullText => 'النص الكامل';

  @override
  String get termsE1 =>
      'لا يتعامل Pokou مع الأموال أبدًا: تُدفع الصناديق والصيدليات والمندوبون من محفظة إلى محفظة.';

  @override
  String get termsE2 =>
      'يحتفظ وضع الإثبات بأثر الرسائل المحذوفة، ويُعرض ذلك دائمًا.';

  @override
  String get termsE3 => 'Honam ليس خدمة طوارئ.';

  @override
  String get termsE4 => 'يمكن إلغاء الشارات المدفوعة في أي وقت.';

  @override
  String get privacyE1 => 'لا يُعرض رقمك أبدًا على بائع أو مندوب.';

  @override
  String get privacyE2 =>
      'لا يقرأ Pokou رسائلك. البلاغ يرسل آخر 5 رسائل فقط إلى الدعم.';

  @override
  String get privacyE3 => 'لا يُحتفظ بموقع المندوب بعد التسليم.';

  @override
  String get privacyE4 =>
      'تُستهدف الإعلانات الممولة حسب المدينة، وليس أبدًا من رسائلك.';

  @override
  String get languageNote =>
      'لغة التطبيق لا تغيّر لغة رسائلك. تبقى أسماء Pokou وKory وHonam وAssimé كما هي في كل اللغات.';

  @override
  String get securityPinWarning =>
      'لن يطلب منك Pokou أبدًا رمزك السري ولا رمز الرسائل القصيرة، لا برسالة ولا بمكالمة.';

  @override
  String get statusReplyPrivate => 'يصل ردك بشكل خاص، في محادثتكما الثنائية.';

  @override
  String get statusViewersNote =>
      'أنت وحدك ترى هذه القائمة. تصل الردود بشكل خاص في محادثاتك.';

  @override
  String get statusWhoSees => 'من يرى حالاتي';

  @override
  String get attachCompressNote =>
      'تُضغط الصور ومقاطع الفيديو قبل الإرسال لتوفير بياناتك.';

  @override
  String get otpTitle => 'أدخل الرمز';

  @override
  String get pinForgot => 'نسيت الرمز السري؟';

  @override
  String get pinTitle => 'رمزك السري';

  @override
  String statusReplyHint(String name) {
    return 'الرد على $name…';
  }

  @override
  String get statusReplyQuote => '↩ ردًا على حالتك';

  @override
  String get statusReplySent => 'تم إرسال الرد بشكل خاص.';

  @override
  String get changeNumberTitle => 'تغيير الرقم';

  @override
  String get changeNumberOld => 'الرقم القديم';

  @override
  String get changeNumberNew => 'الرقم الجديد';

  @override
  String get changeNumberNotify => 'إبلاغ جهات اتصالي';

  @override
  String get changeNumberNotifyAll => 'كل جهات اتصالي';

  @override
  String get changeNumberNotifyChatted => 'من تحدثت معهم';

  @override
  String get changeNumberNotifyNone => 'لا أحد';

  @override
  String get changeNumberNotifyNoneSub => 'تُبلَّغ مجموعاتك دائمًا';

  @override
  String get changeNumberInfo =>
      'يتبعك حسابك ومحادثاتك وشارة Pokou الموثّقة وصناديق Kory. يُرسل رمز إلى الرقم الجديد.';

  @override
  String get changeNumberKoryWarning =>
      'إذا كنت جامع صندوق، فلن يتغير رقم الجمع تلقائيًا: عدّله في Kory وسيُبلَّغ الأعضاء.';

  @override
  String get changeNumberSendCode => 'إرسال الرمز';

  @override
  String get changeNumberCodeLabel => 'الرمز المستلم بالرسائل القصيرة';

  @override
  String get changeNumberConfirm => 'تأكيد التغيير';

  @override
  String get changeNumberDone => 'تم تغيير رقمك.';

  @override
  String get pinForgotIntro => 'طريقتان لاستعادة حسابك:';

  @override
  String get pinForgotEmail => 'عبر البريد الإلكتروني';

  @override
  String get pinForgotEmailSub =>
      'إذا أضفت عنوانًا: يُرسل إليك رابط إعادة تعيين';

  @override
  String get pinForgotWait => 'الانتظار 7 أيام';

  @override
  String get pinForgotWaitSub =>
      'بعدها تسجّل الدخول دون رمز سري برمز الرسائل القصيرة، شرط الاحتفاظ برقمك';

  @override
  String get pinForgotWarning =>
      'تمنع مهلة 7 أيام من سرق شريحتك من الاستيلاء على حسابك فورًا.';

  @override
  String get pinForgotMeanwhile =>
      'أثناء الانتظار، تظل جهات اتصالك تراك ورسائلك بانتظارك.';

  @override
  String get pinForgotContinue => 'متابعة';

  @override
  String pinForgotScheduled(String date) {
    return 'تم. ابتداءً من $date سيكفي رمز الرسائل القصيرة لتسجيل الدخول.';
  }

  @override
  String get groupDelete => 'حذف المجموعة';

  @override
  String groupDeleteTitle(String name) {
    return 'حذف «$name»؟';
  }

  @override
  String get groupDeleteBody =>
      'تختفي المجموعة لدى جميع أعضائها مع رسائلها. هذا الإجراء نهائي.';

  @override
  String get groupDeleteFailed => 'تعذّر الحذف — حاول مرة أخرى.';

  @override
  String get groupManageTitle => 'إدارة المجموعة';

  @override
  String get groupManageSubtitle => 'الأذونات، الأعضاء الجدد، الرسائل المؤقتة';

  @override
  String get groupPermissions => 'الأذونات';

  @override
  String get groupEditInfoSetting => 'تعديل الاسم والصورة';

  @override
  String get groupSendSetting => 'إرسال الرسائل';

  @override
  String get groupApproveSetting => 'الموافقة على الأعضاء الجدد';

  @override
  String get groupApproveSettingSub => 'يوافق مشرف على كل انضمام عبر الرابط';

  @override
  String get groupAllMembers => 'جميع الأعضاء';

  @override
  String get groupDisappearing => 'الرسائل المؤقتة';

  @override
  String get groupDisappearingOff => 'معطّلة';

  @override
  String get groupDisappearing24h => '24 ساعة';

  @override
  String get groupDisappearing7d => '7 أيام';

  @override
  String get groupDisappearing90d => '90 يومًا';

  @override
  String get groupJoinRequests => 'طلبات الانضمام';

  @override
  String get groupNoJoinRequest => 'لا توجد طلبات معلّقة.';

  @override
  String get groupApprove => 'قبول';

  @override
  String get groupReject => 'رفض';

  @override
  String get groupJoinPending =>
      'تم إرسال الطلب: يجب أن يوافق مشرف على انضمامك.';

  @override
  String get groupSettingsSaveFailed => 'لم يُحفظ الإعداد — حاول مجددًا.';

  @override
  String get groupLeaveKoryNote =>
      'مغادرة المجموعة لا تحذف الصندوق الجاري: تبقى مساهماتك في سجل Kory.';

  @override
  String get messageWaiting => 'بانتظار هذه الرسالة…';

  @override
  String get callWaitingNotice =>
      'أنت في مكالمة بالفعل. الرفض يبقيها؛ القبول ينهيها.';

  @override
  String get callEndAndAccept => 'إنهاء وقبول';

  @override
  String get homeHelloOverline => 'مرحبًا';

  @override
  String get koryOverline => 'ادخار تضامني';

  @override
  String koryActiveCount(String count) {
    return '$count نشطة';
  }

  @override
  String get searchIntro => 'ابحث في رسائلك والقنوات وإعلانات Assimé.';

  @override
  String get searchRecent => 'عمليات البحث الأخيرة';

  @override
  String get homeTagline => 'كل ما يهمّ، في مكان واحد.';

  @override
  String get homeWhatToDo => 'ماذا تريد أن تفعل؟';

  @override
  String get homeInProgress => 'قيد التنفيذ';

  @override
  String get homeKoryPitch =>
      'اجمعوا المال معًا لمشروع أو مناسبة أو جمعية ادخار.';

  @override
  String get homeHonamPitch => 'أرسل وصفتك واحصل على عروض الصيدليات القريبة.';

  @override
  String get homeAssimeTitle => 'Assimé';

  @override
  String get homeAssimeSubtitle => 'إعلانات مبوبة';

  @override
  String get homeAssimePitch => 'اشترِ وبِع بالقرب منك بكل ثقة.';

  @override
  String get homeAssimeCta => 'تصفح الإعلانات';
}
