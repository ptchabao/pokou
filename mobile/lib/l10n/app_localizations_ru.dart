// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class LRu extends L {
  LRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Pokou';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionConfirm => 'Подтвердить';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionContinue => 'Продолжить';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionShare => 'Поделиться';

  @override
  String get actionSearch => 'Поиск';

  @override
  String get actionAdd => 'Добавить';

  @override
  String get actionRemove => 'Убрать';

  @override
  String get actionSend => 'Отправить';

  @override
  String get actionJoin => 'Присоединиться';

  @override
  String get actionCreate => 'Создать';

  @override
  String get navChats => 'Чаты';

  @override
  String get navStatus => 'Новости';

  @override
  String get navCalls => 'Звонки';

  @override
  String get navMarket => 'Рынок';

  @override
  String get chatsEmptyTitle => 'Чатов пока нет';

  @override
  String get chatsEmptyBody => 'Здесь появятся ваши переписки.';

  @override
  String get chatsSearchHint => 'Поиск';

  @override
  String get chatsTyping => 'печатает…';

  @override
  String chatsTypingNamed(String name) {
    return '$name печатает…';
  }

  @override
  String get chatsUnknownContact => 'нет в ваших контактах';

  @override
  String get chatsNoMessageYet => 'Сообщений пока нет';

  @override
  String chatsYouPrefix(String message) {
    return 'Вы: $message';
  }

  @override
  String chatsGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count группы',
      many: '$count групп',
      few: '$count группы',
      one: '$count группа',
      zero: 'Нет групп',
    );
    return '$_temp0';
  }

  @override
  String get newChatTitle => 'Новый чат';

  @override
  String get newChatSearchHint => 'Найти контакт';

  @override
  String get newChatNewGroup => 'Новая группа';

  @override
  String get newChatNewCommunity => 'Новое сообщество';

  @override
  String get newChatJoinByLink => 'Войти по ссылке';

  @override
  String get newChatOnPokou => 'В Pokou Messenger';

  @override
  String get newChatInvite => 'Пригласить в Pokou Messenger';

  @override
  String get newChatNoMatch => 'Совпадений нет.';

  @override
  String get newChatNoRegisteredContact =>
      'Никто из ваших контактов ещё не в Pokou.';

  @override
  String conversationSayHello(String name) {
    return 'Поздоровайтесь с $name.';
  }

  @override
  String get conversationMessageHint => 'Сообщение';

  @override
  String get conversationEdit => 'Изменить';

  @override
  String get conversationForward => 'Переслать';

  @override
  String get conversationReply => 'Ответить';

  @override
  String get conversationEditWindowOver =>
      'Это сообщение больше нельзя изменить.';

  @override
  String get mediaPhoto => 'Фото';

  @override
  String get mediaVideo => 'Видео';

  @override
  String get mediaVoice => 'Голосовое сообщение';

  @override
  String get mediaDocument => 'Документ';

  @override
  String get mediaLocation => 'Местоположение';

  @override
  String get offlineTitle => 'Нет сети';

  @override
  String get offlineBody =>
      'Вы увидите то, что уже есть на этом устройстве. Остальное придёт, когда вернётся сеть.';

  @override
  String get offlineNothingCached =>
      'На этом устройстве пока ничего не сохранено.';

  @override
  String get offlineSending => 'Ожидает отправки';

  @override
  String get errorNetwork => 'Не удаётся подключиться. Проверьте сеть.';

  @override
  String get twoStepTitle => 'Двухэтапная проверка';

  @override
  String get twoStepBody =>
      'Этот аккаунт защищён кодом. Введите его, чтобы завершить вход.';

  @override
  String get twoStepHint => 'Код аккаунта';

  @override
  String get errorGeneric => 'Что-то пошло не так.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileLanguage => 'Язык';

  @override
  String get profileLanguageSystem => 'Язык телефона';

  @override
  String get profileLanguageSubtitle => 'Выберите язык приложения';

  @override
  String get languageFrench => 'Французский';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageSpanish => 'Испанский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageArabic => 'Арабский';

  @override
  String get languageItalian => 'Итальянский';

  @override
  String get sparkTitle => 'Spark';

  @override
  String get sparkSubtitle => 'Свидание на сегодня';

  @override
  String get sparkTabDiscover => 'Открыть';

  @override
  String get sparkTabMatches => 'Совпадения';

  @override
  String get sparkTabDates => 'Встречи';

  @override
  String get sparkTabMe => 'Я';

  @override
  String get sparkAddPhoto => 'Добавить фото';

  @override
  String get sparkNoPhotoWarning =>
      'Добавьте фото — без него почти никто не лайкает';

  @override
  String sparkPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return '$_temp0';
  }

  @override
  String get sparkLike => 'Лайк';

  @override
  String get sparkPass => 'Пропустить';

  @override
  String get sparkAgeRestricted => 'Spark — только для совершеннолетних.';

  @override
  String get navProfile => 'Профиль';

  @override
  String get authWelcome => 'Добро пожаловать в Pokou';

  @override
  String get authSubtitle =>
      'Введите номер — мы отправим код. Впервые в Pokou? Аккаунт создаётся на этом шаге.';

  @override
  String get authPhoneHint => 'Ваш номер';

  @override
  String get authPrivacyNote =>
      'Безопасный вход. Номер нужен только для подтверждения личности.';

  @override
  String get authVerifyTitle => 'Подтверждение';

  @override
  String authCodeSentTo(String phone) {
    return 'Введите код из 6 цифр, отправленный на $phone';
  }

  @override
  String get authChangeNumber => 'Изменить номер';

  @override
  String authResendIn(String time) {
    return 'Отправить код повторно через $time';
  }

  @override
  String get authResendSms => 'Отправить по SMS';

  @override
  String get authResendWhatsapp => 'Отправить через WhatsApp';

  @override
  String get authCodeSentSms => 'Новый код отправлен по SMS.';

  @override
  String get authCodeSentWhatsapp => 'Новый код отправлен в WhatsApp.';

  @override
  String get chatsPin => 'Закрепить';

  @override
  String get chatsUnpin => 'Открепить';

  @override
  String get chatsArchive => 'В архив';

  @override
  String get chatsUnarchive => 'Из архива';

  @override
  String get chatsMute => 'Отключить звук';

  @override
  String get chatsUnmute => 'Включить звук';

  @override
  String get chatsTag => 'Метка';

  @override
  String chatsTagNamed(String name) {
    return 'Метка для $name';
  }

  @override
  String get chatsBlock => 'Заблокировать';

  @override
  String chatsBlockTitle(String name) {
    return 'Заблокировать $name?';
  }

  @override
  String get chatsBlockBody =>
      'Этот человек больше не сможет писать и звонить вам. Его не уведомят.';

  @override
  String get chatsPinLimit => 'Уже закреплено три чата — это максимум.';

  @override
  String get chatsMute8h => '8 часов';

  @override
  String get chatsMute1w => '1 неделя';

  @override
  String get chatsMuteAlways => 'Навсегда';

  @override
  String get chatsAddContact => 'Добавить в контакты';

  @override
  String get chatsActionFailed => 'Сейчас это не получилось.';

  @override
  String get chatsNoResult => 'Ничего не найдено.';

  @override
  String get chatsConnectFailed => 'Не удаётся подключиться.';

  @override
  String get navModules => 'Модули';

  @override
  String get navBroadcasts => 'Рассылки';

  @override
  String get navYou => 'Вы';

  @override
  String get convProductFallback => 'Товар';

  @override
  String get convOrderUpdated => 'Заказ обновлён';

  @override
  String get convReactionFailed => 'Не удалось поставить реакцию.';

  @override
  String get convPermissionDenied => 'Доступ запрещён.';

  @override
  String get convAttachDocument => 'Документ';

  @override
  String get convAttachGallery => 'Фото (галерея)';

  @override
  String get convAttachVideo => 'Видео (галерея)';

  @override
  String get convAttachCamera => 'Камера';

  @override
  String get convEditTitle => 'Изменить сообщение';

  @override
  String get convEditHint => 'Ваше сообщение';

  @override
  String convForwarded(String name) {
    return 'Сообщение переслано: $name.';
  }

  @override
  String get convForwardFailed => 'Не удалось переслать.';

  @override
  String get convRecordVoice => 'Записать голосовое';

  @override
  String get mediaVoiceNote => 'Голосовое';

  @override
  String get mediaMessage => 'Сообщение';

  @override
  String get newChatInviteAction => 'Пригласить';

  @override
  String get profileGallery => 'Галерея';

  @override
  String get profileCamera => 'Камера';

  @override
  String get profileEdit => 'Изменить профиль';

  @override
  String get profileFullName => 'Полное имя';

  @override
  String get profileAbout => 'О себе';

  @override
  String get profileUpdateFailed => 'Не удалось обновить.';

  @override
  String get profileVerifiedPhone => 'Личность подтверждена по телефону';

  @override
  String get profilePrivacySecurity => 'Конфиденциальность и безопасность';

  @override
  String get profileShieldMode => 'Режим «Щит»';

  @override
  String get profileShieldOn => 'Режим «Щит» включён';

  @override
  String get profileShieldOff => 'Режим «Щит» выключен';

  @override
  String get profileConnection => 'Соединение';

  @override
  String get profileEncryptedTls => 'Шифруется (TLS)';

  @override
  String get profileStatusVisibility => 'Видимость статусов';

  @override
  String get commonEnabled => 'Включено';

  @override
  String get commonDisabled => 'Выключено';

  @override
  String get commonLoading => 'Загрузка…';

  @override
  String get profileDevices => 'Подключённые устройства';

  @override
  String get profileNotifications => 'Уведомления';

  @override
  String get profileStorage => 'Хранилище и данные';

  @override
  String get profileDataSaver => 'Экономия трафика';

  @override
  String get profileSystemPrefs => 'Системные настройки';

  @override
  String get profileSignOut => 'Выйти';

  @override
  String modulesActivated(String name) {
    return '$name включён.';
  }

  @override
  String get modulesUnavailable => 'Модули недоступны';

  @override
  String get modulesCheckNetwork => 'Проверьте соединение и повторите.';

  @override
  String get modulesEmptyTitle => 'Пока нечего добавить';

  @override
  String get modulesEmptyBody =>
      'Новые модули появятся здесь. Пока ничего делать не нужно.';

  @override
  String get modulesMine => 'Мои приложения';

  @override
  String get modulesRecommended => 'Рекомендуемые';

  @override
  String get modulesRecommendedBy => 'Выбор нашей команды';

  @override
  String get modulesPopular => 'Популярные';

  @override
  String get modulesPopularSub => 'Чаще всего включают сейчас';

  @override
  String get modulesEnable => 'Включить';

  @override
  String get modulesDisable => 'Выключить';

  @override
  String get modulesEnableFailed => 'Не удалось включить.';

  @override
  String modulesComingSoon(String name) {
    return '$name скоро появится. Обновите приложение, чтобы получить его сразу.';
  }

  @override
  String modulesUserCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека им пользуются',
      many: '$count человек им пользуются',
      few: '$count человека им пользуются',
      one: '$count человек им пользуется',
    );
    return '$_temp0';
  }

  @override
  String get sparkEnableLocation => 'Включите геолокацию на телефоне.';

  @override
  String get sparkLocationNeeded => 'Без геолокации Spark не знает, кто рядом.';

  @override
  String get sparkLocationFailed => 'Не удалось определить местоположение.';

  @override
  String get sparkFeedUnavailable => 'Лента недоступна';

  @override
  String get sparkPickIntentTitle => 'Выберите карту дня';

  @override
  String get sparkPickIntentBody =>
      'Скажите, что вы ищете сегодня, и увидите тех, кто ищет то же.';

  @override
  String get sparkLocationStale => 'Ваше местоположение устарело';

  @override
  String get sparkLocationStaleBody =>
      'Spark показывает только людей в радиусе 5 км. Без свежей геопозиции показывать нечего.';

  @override
  String get sparkShareLocation => 'Поделиться геопозицией';

  @override
  String get sparkQuotaTitle => 'Вы посмотрели профили на сегодня';

  @override
  String get sparkQuotaBody =>
      'Возвращайтесь завтра или возьмите Spark+ без ограничений.';

  @override
  String get sparkNobodyTitle => 'Пока никого';

  @override
  String get sparkNobodyBody =>
      'Сейчас здесь мало кто ищет то же самое. Попробуйте позже или смените карту.';

  @override
  String get sparkPickCard => 'Выберите карту';

  @override
  String get sparkTodayLooking => 'Что вы ищете сегодня';

  @override
  String get sparkCardExpired => 'Ваша карта истекла';

  @override
  String sparkHoursLeft(int hours) {
    return 'Осталось $hours ч';
  }

  @override
  String sparkMinutesLeft(int minutes) {
    return 'Осталось $minutes мин';
  }

  @override
  String get sparkIntentSheetTitle => 'Сегодня я ищу';

  @override
  String get sparkIntentSheetBody =>
      'Карта истекает через 24 ч. Вы увидите только тех, кто выбрал то же.';

  @override
  String get sparkLikesExhausted =>
      'Лайки на сегодня закончились. Возьмите пакет во вкладке «Я».';

  @override
  String get sparkMatchesUnavailable => 'Совпадения недоступны';

  @override
  String get sparkNoMatchTitle => 'Пока нет совпадений';

  @override
  String get sparkNoMatchBody =>
      'Когда вы понравитесь друг другу, откроется десятиминутная комната. Именно там всё и решается.';

  @override
  String get sparkOpenRooms => 'Открытые комнаты';

  @override
  String get sparkRoomsClose => 'Закрываются сами';

  @override
  String get sparkMyMatches => 'Мои совпадения';

  @override
  String get sparkNext => 'Далее';

  @override
  String get sparkPhotoFailed => 'Не удалось добавить фото.';

  @override
  String get sparkGoFaster => 'Быстрее';

  @override
  String get sparkNoExpiry => 'Без срока';

  @override
  String get sparkPlusActive => 'Активно — продлевает подписку';

  @override
  String get sparkPlusPitch => 'Безлимитные профили, месяц';

  @override
  String get sparkBoost => 'Топ-профиль';

  @override
  String get sparkBoostPitch => 'В начале ленты на час';

  @override
  String get sparkAroundMe => 'Вокруг меня';

  @override
  String get sparkSafety => 'Безопасность';

  @override
  String get sparkSafetyPitch => 'Тихая тревога и круг доверия';

  @override
  String get sparkWingman => 'Мнение друзей';

  @override
  String get sparkWingmanPitch => 'Профили, о которых вас спрашивают';

  @override
  String get sparkUploading => 'Отправка…';

  @override
  String get sparkKarma => 'Street Cred';

  @override
  String get sparkCanInvite => 'Вы можете приглашать';

  @override
  String get sparkCannotInvite =>
      'Слишком низко, чтобы приглашать. Соблюдайте встречи.';

  @override
  String sparkLikersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека поставили вам лайк',
      many: '$count человек поставили вам лайк',
      few: '$count человека поставили вам лайк',
      one: '$count человек поставил вам лайк',
    );
    return '$_temp0';
  }

  @override
  String get sparkSeeWho => 'Посмотреть кто';

  @override
  String get sparkFindInDiscover => 'Найдите их в «Люди».';

  @override
  String get sparkPaymentPendingLikers =>
      'Список откроется сразу после подтверждения оплаты.';

  @override
  String get sparkPaymentPendingLikes =>
      'Лайки придут сразу после подтверждения оплаты.';

  @override
  String get sparkPaymentPendingPlus =>
      'Spark+ включится сразу после подтверждения оплаты.';

  @override
  String get sparkPaymentPendingBoost =>
      'Профиль поднимется сразу после подтверждения оплаты.';

  @override
  String get sparkBirthDateLabel => 'Ваша дата рождения';

  @override
  String get sparkNameAndBirthNeeded => 'Как минимум имя и дата рождения.';

  @override
  String get sparkProfileFailed => 'Не удалось создать анкету.';

  @override
  String get sparkCreateProfile => 'Создайте анкету';

  @override
  String get sparkStep1Title => 'Вы говорите, что ищете, сегодня';

  @override
  String get sparkStep1Body =>
      'Карта истекает через 24 ч. Вы видите только тех, кто ищет то же, в радиусе 5 км.';

  @override
  String get sparkStep2Title => 'Десять минут голосом до текста';

  @override
  String get sparkStep2Body =>
      'После пары открывается комната: только голос и стикеры. Фальшивые анкеты её не проходят.';

  @override
  String get sparkStep3Title => 'Близкие знают, где вы';

  @override
  String get sparkStep3Body =>
      'Незаметный жест оповещает ваш круг с геопозицией. Во время встречи мы также спрашиваем, всё ли хорошо.';

  @override
  String get sparkSeparateTitle => 'Ваша анкета отделена от Pokou';

  @override
  String get sparkSeparateBody =>
      'Ваше имя и номер в Pokou здесь не показываются. Выберите, что отображать.';

  @override
  String get sparkDisplayName => 'Отображаемое имя';

  @override
  String get sparkNameExample => 'Напр. Ама';

  @override
  String get sparkBirthDate => 'Дата рождения';

  @override
  String get sparkBirthDateLocked => 'Изменить её потом нельзя.';

  @override
  String get sparkChoose => 'Выбрать';

  @override
  String get sparkYouAre => 'Вы';

  @override
  String get sparkWoman => 'Женщина';

  @override
  String get sparkMan => 'Мужчина';

  @override
  String get sparkOther => 'Другое';

  @override
  String get sparkBioLabel => 'Пара слов о себе (необязательно)';

  @override
  String get sparkBioHint => 'Что стоит знать до встречи с вами';

  @override
  String get sparkCreateAction => 'Создать анкету';

  @override
  String get truthSubtitle => 'Платный вопрос, свободный ответ';

  @override
  String get truthAsk => 'Задать вопрос';

  @override
  String get truthForMe => 'Мне';

  @override
  String get truthMine => 'Мои вопросы';

  @override
  String get truthUnavailable => 'Вопросы недоступны';

  @override
  String get truthEmptyTitle => 'Пока нет вопросов';

  @override
  String get truthEmptyBody =>
      'Когда кто-то заплатит за вопрос вам, он появится здесь. Вы вправе отказать.';

  @override
  String get truthYourAnswer => 'Ваш ответ';

  @override
  String get truthAnswerPrivacy =>
      'Он уходит только тому, кто заплатил. Pokou нигде его не публикует.';

  @override
  String get truthWhatToSay => 'Что вы хотите сказать';

  @override
  String get truthSendAnswer => 'Отправить ответ';

  @override
  String get truthAskedAnon => 'Спрошено анонимно';

  @override
  String get truthDecline => 'Отказать';

  @override
  String get truthAnswer => 'Ответить';

  @override
  String get truthDeclineFree =>
      'Отказ ничего не стоит. Платят только за ответ.';

  @override
  String get truthHistoryUnavailable => 'История недоступна';

  @override
  String get truthNothingAsked => 'Вы ещё ничего не спрашивали';

  @override
  String get truthNothingAskedBody =>
      'Задайте вопрос: человек увидит сумму и вопрос, но не ваше имя.';

  @override
  String get truthAnswered => 'Отвечено';

  @override
  String get truthDeclined => 'Отклонено';

  @override
  String get truthPending => 'Ожидает';

  @override
  String truthToSomeone(String name) {
    return 'Кому: $name';
  }

  @override
  String get truthSomeone => 'кому-то';

  @override
  String get truthPreferredNot => 'Человек предпочёл не отвечать.';

  @override
  String get truthAwaitingAnswer => 'Ожидание ответа.';

  @override
  String get truthToWhom => 'Кому?';

  @override
  String truthQuestionTo(String name) {
    return 'Вопрос для $name';
  }

  @override
  String get truthAnonTitle => 'Ваше имя не показывается';

  @override
  String get truthAnonBody =>
      'Человек видит сумму и вопрос, но не отправителя.';

  @override
  String get truthFreeTitle => 'Человек вправе отказать';

  @override
  String get truthFreeBody => 'Отказ ничего не даёт: платят только за ответ.';

  @override
  String get truthPrivateTitle => 'Ответ придёт только вам';

  @override
  String get truthPrivateBody =>
      'Pokou нигде его не публикует, и он истекает через семь дней без ответа.';

  @override
  String get truthYourQuestion => 'Ваш вопрос';

  @override
  String get truthQuestionHint => 'Что вам действительно хочется узнать';

  @override
  String get truthHowMuch => 'Сколько вы предлагаете';

  @override
  String truthAskForAmount(int amount) {
    return 'Задать вопрос — $amount FCFA';
  }

  @override
  String get truthWriteFirst => 'Сначала напишите вопрос.';

  @override
  String get truthPaymentPending =>
      'Вопрос уйдёт сразу после подтверждения оплаты.';

  @override
  String get hypeFinished => 'Завершено';

  @override
  String get hypeSubtitle => 'Одна цель, весь зал';

  @override
  String get hypeLaunch => 'Запустить цель';

  @override
  String get hypeOngoing => 'Идут';

  @override
  String get hypeMine => 'Мои';

  @override
  String get hypeNoneTitle => 'Нет активных целей';

  @override
  String get hypeNoneBody =>
      'Когда автор запускает цель, она здесь — пока планка не взята.';

  @override
  String get hypeMineEmpty => 'Пока ничего';

  @override
  String get hypeMineEmptyBody =>
      'Ваши цели и те, что вы поддержали, появятся здесь.';

  @override
  String get hypeUnavailable => 'Цели недоступны';

  @override
  String get hypeCreator => 'Автор';

  @override
  String get hypeTierReached => 'Планка взята';

  @override
  String get hypeGoal => 'Цель';

  @override
  String get hypeNotFound => 'Цель не найдена';

  @override
  String get hypeMaybeRemoved => 'Возможно, её удалили.';

  @override
  String get hypeUnlocked => 'Планка взята. Обещание разблокировано.';

  @override
  String get hypeContribute => 'Продвинуть шкалу';

  @override
  String get hypePushers => 'Кто толкает';

  @override
  String get hypeBeFirst => 'Пока никого. Будьте первым.';

  @override
  String get hypeContributor => 'Участник';

  @override
  String commonDueToYou(int amount) {
    return 'Вам причитается: $amount FCFA';
  }

  @override
  String get commonManualPayout => 'Выплату делает команда Pokou по запросу.';

  @override
  String get hypeStepTogetherTitle => 'Все толкают вместе';

  @override
  String get hypeStepTogetherBody =>
      'Каждый вклад двигает шкалу, и все видят взятие планки одновременно.';

  @override
  String get hypeStepPromiseTitle => 'Что вы обещаете';

  @override
  String get hypeStepPromiseBody =>
      'Видно до того, как кто-то заплатит. Это ваше обязательство при достижении цели.';

  @override
  String get hypeStepOneTitle => 'Только одна цель за раз';

  @override
  String get hypeStepOneBody =>
      'Две цели сразу заставят ваших сторонников конкурировать с самими собой.';

  @override
  String get commonTitle => 'Название';

  @override
  String get hypeTitleExample => 'Напр.: 100 000 и я пою';

  @override
  String get hypePromiseLabel => 'Что вы открываете при достижении цели';

  @override
  String get hypePromiseHint =>
      'Будьте конкретны: это то, что покупают ваши сторонники.';

  @override
  String get hypeGoalAmount => 'Цель в FCFA';

  @override
  String get commonDuration => 'Длительность';

  @override
  String get hypeLaunchAction => 'Запустить';

  @override
  String get hypeFieldsNeeded => 'Нужны название, обещание и цель.';

  @override
  String get hypeAlreadyRunning => 'У вас уже есть активная цель.';

  @override
  String get hypeContributeNote =>
      'Ваш вклад двигает шкалу и открывает контент. Он не возвращается.';

  @override
  String get commonAmount => 'Сумма';

  @override
  String hypeJoinForAmount(int amount) {
    return 'Участвовать — $amount FCFA';
  }

  @override
  String get hypePaymentPending =>
      'Шкала сдвинется сразу после подтверждения оплаты.';

  @override
  String get ceremonyWedding => 'Свадьба';

  @override
  String get ceremonyBaptism => 'Крестины';

  @override
  String get ceremonyFuneral => 'Похороны';

  @override
  String get ceremonyOther => 'Другое';

  @override
  String get ceremonyTitle => 'Сборы';

  @override
  String get ceremonySubtitle => 'Взносы без напоминаний';

  @override
  String get ceremonyNew => 'Новый сбор';

  @override
  String get ceremonyUnavailable => 'Сборы недоступны';

  @override
  String get ceremonyNone => 'Нет сборов';

  @override
  String get ceremonyNoneBody =>
      'Свадьба, крестины, похороны: создайте сбор, пригласите — каждый даст сколько может.';

  @override
  String ceremonyGoalHint(int amount) {
    return 'Ориентир: $amount FCFA';
  }

  @override
  String get ceremonyOne => 'Сбор';

  @override
  String get ceremonyNotFound => 'Сбор не найден';

  @override
  String get ceremonyMaybeClosed => 'Возможно, он закрыт.';

  @override
  String get ceremonyJoin => 'Внести';

  @override
  String get ceremonyClose => 'Закрыть сбор';

  @override
  String get ceremonyContributions => 'Взносы';

  @override
  String get ceremonyNobodyYet => 'Пока никто не внёс.';

  @override
  String get ceremonyAnonGift => 'Анонимный взнос';

  @override
  String get ceremonyContributor => 'Участник';

  @override
  String get ceremonyCollected => 'собрано';

  @override
  String get ceremonyYouOrganize => 'вы организуете';

  @override
  String get ceremonyNewSubtitle =>
      'Вы видите взносы. Pokou не напоминает тем, кто не дал.';

  @override
  String get ceremonyOccasion => 'Повод';

  @override
  String get ceremonyTitleExample => 'Напр.: Свадьба Косси и Амы';

  @override
  String get ceremonyFewWords => 'Несколько слов (необязательно)';

  @override
  String get ceremonyFewWordsHint => 'Дата, место, на что пойдут деньги.';

  @override
  String get ceremonyGoalOptional => 'Цель в FCFA (необязательно)';

  @override
  String get ceremonyGoalNote => 'Ориентир: сбор принимает и сверх него.';

  @override
  String get ceremonyCreate => 'Создать сбор';

  @override
  String get ceremonyNeedTitle => 'Дайте сбору название.';

  @override
  String ceremonyJoinTo(String title) {
    return 'Внести — $title';
  }

  @override
  String get ceremonyOtherAmount => 'Или другая сумма';

  @override
  String get ceremonyWordOptional => 'Пара слов (необязательно)';

  @override
  String get ceremonyWordHint => 'Что вы хотите им сказать';

  @override
  String get ceremonyAnonToggle => 'Внести анонимно';

  @override
  String get ceremonyAnonNote => 'Имя скрыто. Сумма остаётся в общем итоге.';

  @override
  String ceremonyJoinAmount(int amount) {
    return 'Внести — $amount FCFA';
  }

  @override
  String get ceremonyMinimum => 'Минимум — 100 FCFA.';

  @override
  String get ceremonyPaymentPending =>
      'Ваш взнос появится сразу после подтверждения оплаты.';

  @override
  String get vipSubtitle => 'Ваши подписчики, ваше пространство';

  @override
  String get vipDiscover => 'Обзор';

  @override
  String get vipMySubs => 'Мои подписки';

  @override
  String get vipMyRoom => 'Моя комната';

  @override
  String get vipNoRoomOpen => 'Нет открытых комнат';

  @override
  String get vipNoRoomOpenBody =>
      'Комнаты, которые открывают авторы, появятся здесь.';

  @override
  String get vipNoSub => 'Нет подписок';

  @override
  String get vipNoSubBody =>
      'Подпишитесь на комнату, чтобы видеть здесь всё, что публикует автор.';

  @override
  String get vipUnavailable => 'Комнаты недоступны';

  @override
  String get vipCreator => 'Автор';

  @override
  String vipUntil(String date) {
    return 'До $date';
  }

  @override
  String get vipPaymentPending =>
      'Комната откроется сразу после подтверждения оплаты.';

  @override
  String get vipRoom => 'Комната';

  @override
  String get vipNotFound => 'Комната не найдена';

  @override
  String get vipMaybeClosed => 'Возможно, она закрыта.';

  @override
  String get vipStepAllTitle => 'Всё, что публикуется здесь';

  @override
  String get vipStepAllBody =>
      'Вы сразу видите уже опубликованное и всё последующее.';

  @override
  String get vipStepDaysTitle => 'Тридцать дней';

  @override
  String get vipStepDaysBody =>
      'Доступ прекращается сам по истечении. Ничего не продлевается без вашего решения.';

  @override
  String get vipStepNoRenewTitle => 'Без автопродления';

  @override
  String get vipStepNoRenewBody =>
      'Pokou не хранит ваш способ оплаты. Чтобы продолжить, вы платите снова, один раз.';

  @override
  String vipSubscribeFor(int amount) {
    return 'Подписаться — $amount FCFA';
  }

  @override
  String get vipLockedTitle => 'Только для подписчиков';

  @override
  String get vipLockedBody =>
      'Остальная часть комнаты откроется после подтверждения оплаты.';

  @override
  String get vipNothingYet => 'Пока пусто';

  @override
  String get vipNothingYetBody => 'В этой комнате пока нет публикаций.';

  @override
  String get vipPosts => 'Публикации';

  @override
  String get vipRoomUnavailable => 'Комната недоступна';

  @override
  String get vipOpenYourRoom => 'Откройте свою комнату';

  @override
  String get vipOpenYourRoomBody =>
      'Подписчики платят один раз за тридцать дней и видят всё, что вы публикуете. Цену ставите вы.';

  @override
  String get vipOpenAction => 'Открыть мою комнату';

  @override
  String get vipPublish => 'Опубликовать';

  @override
  String get vipSeeMyRoom => 'Посмотреть мою комнату';

  @override
  String get vipOpen => 'Открыта';

  @override
  String get vipClosed => 'Закрыта';

  @override
  String get vipEarnings => 'Ваш доход';

  @override
  String vipCollected(int amount) {
    return 'Собрано $amount FCFA';
  }

  @override
  String get vipDueNote =>
      'Сумма, причитающаяся вам. Выплату делает команда Pokou по запросу.';

  @override
  String get vipEditRoom => 'Изменить комнату';

  @override
  String get vipPriceNote =>
      'Новая цена действует только для будущих подписок: каждый заплатил свою заранее.';

  @override
  String get vipRoomName => 'Название комнаты';

  @override
  String get vipRoomNameHint => 'Напр.: За кулисами';

  @override
  String get vipPitchLabel => 'Что там найдут подписчики';

  @override
  String get vipPitchNote =>
      'Видно до оплаты — именно это и убеждает подписаться.';

  @override
  String get vipPitchHint => 'Фото, анонсы, голосовые…';

  @override
  String get vipMonthlyPrice => 'Цена в месяц, FCFA';

  @override
  String get vipAcceptNew => 'Принимать новых подписчиков';

  @override
  String get vipAcceptNewNote =>
      'Текущие подписчики сохраняют доступ до конца срока.';

  @override
  String get vipFieldsNeeded => 'Нужны название, описание и цена.';

  @override
  String get vipPublishTitle => 'Опубликовать в моей комнате';

  @override
  String get vipPublishNote => 'Видно только вашим текущим подписчикам.';

  @override
  String get vipYourMessage => 'Ваше сообщение';

  @override
  String get vipShareHint => 'Чем вы хотите поделиться';

  @override
  String vipEarningsSummary(int count, int amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подписки',
      many: '$count подписок',
      few: '$count подписки',
      one: '$count подписка',
    );
    return '$_temp0 • собрано $amount FCFA';
  }

  @override
  String get datesUnavailable => 'Встречи недоступны';

  @override
  String get datesNone => 'Встреч не запланировано';

  @override
  String get datesNoneBody =>
      'После комнаты предложите место. Вы платите заранее, а деньги уходят только когда подтвердите оба.';

  @override
  String get datesNotNow => 'Сейчас это невозможно.';

  @override
  String get datesCancelTitle => 'Отменить встречу?';

  @override
  String get datesCancelFree => 'До встречи больше 24 ч: вам вернут всю сумму.';

  @override
  String get datesCancelLate =>
      'Осталось меньше 24 ч. Заведение уже забронировало — оплата остаётся ему.';

  @override
  String get datesKeep => 'Оставить';

  @override
  String get datesCancelAction => 'Отменить встречу';

  @override
  String get datesAwaitingPayment => 'Ожидает оплаты';

  @override
  String get datesPaidToConfirm => 'Оплачено — подтвердить';

  @override
  String get datesDone => 'Завершено';

  @override
  String get datesRefunded => 'Возвращено';

  @override
  String get datesNoShow => 'Неявка отмечена';

  @override
  String get datesCancelled => 'Отменено';

  @override
  String get datesOne => 'Встреча';

  @override
  String datesWithPeer(String venue, String name) {
    return '$venue • с $name';
  }

  @override
  String get datesYourMatch => 'вашей парой';

  @override
  String get datesWentWell => 'Всё прошло хорошо';

  @override
  String get datesYouConfirmed =>
      'Вы подтвердили. Ждём подтверждения второй стороны.';

  @override
  String get datesNoShowAction => 'Не пришёл';

  @override
  String get datesVoucher => 'Ваш ваучер — предъявите на месте';

  @override
  String get datesPickBoth => 'Выберите формулу и время.';

  @override
  String get datesVoucherPending =>
      'Ваучер выдадут сразу после подтверждения оплаты.';

  @override
  String get datesBookingFailed => 'Бронирование не прошло.';

  @override
  String get datesWhereTo => 'Куда идёте?';

  @override
  String get datesStepPayTitle => 'Вы платите заранее, ничего не выплачивается';

  @override
  String get datesStepPayBody =>
      'Деньги заморожены. Они уйдут заведению, только если подтвердите оба.';

  @override
  String get datesStepCancelTitle => 'Свободная отмена более чем за 24 ч';

  @override
  String get datesStepCancelBody =>
      'Полный возврат. Меньше — заведение уже забронировало и оставляет оплату себе.';

  @override
  String get datesStepNoShowTitle => 'Если второй не придёт';

  @override
  String get datesStepNoShowBody =>
      'Половина возвращается вам. Приложение ничего не берёт за сорванную встречу.';

  @override
  String get datesThePackage => 'Формула';

  @override
  String get datesPacksUnavailable => 'Формулы сейчас недоступны.';

  @override
  String get datesNoPackNearby => 'Рядом с вами пока нет формул.';

  @override
  String get datesWhen => 'Когда?';

  @override
  String get datesPickWhen => 'Выбрать дату и время';

  @override
  String get datesBook => 'Забронировать';

  @override
  String datesBookAmount(int amount) {
    return 'Забронировать — $amount FCFA';
  }

  @override
  String get roomNeedMic =>
      'Без микрофона остаются только стикеры — комната голосовая.';

  @override
  String get roomVoiceFailed => 'Голосовое не отправилось.';

  @override
  String get roomBothYes => 'Поехали. Теперь можно предложить встречу.';

  @override
  String get roomWaitingOther =>
      'Записано. Ждём ответа до конца обратного отсчёта.';

  @override
  String get roomExtendPending =>
      'Ещё десять минут сразу после подтверждения оплаты.';

  @override
  String get roomTitle => 'Прихожая';

  @override
  String get roomNotFound => 'Комната не найдена';

  @override
  String get roomMaybeClosed => 'Возможно, она закрылась.';

  @override
  String get roomVoiceOnly => 'Только голос и стикеры';

  @override
  String get roomTimeUp => 'Время вышло.';

  @override
  String roomTimeLeft(String clock) {
    return 'Осталось $clock, чтобы решить вместе';
  }

  @override
  String get roomSaySomething => 'Скажите что-нибудь';

  @override
  String get roomNoTextBody =>
      'Здесь нет текста: голосовое или стикер. Именно это отличает живого человека от скопированного сообщения.';

  @override
  String get roomVoice => 'Голос';

  @override
  String get roomWaitingReply => 'Ждём ответа';

  @override
  String roomExtendFor(int amount) {
    return 'Ещё десять минут — $amount FCFA';
  }

  @override
  String get roomBothSaidYes => 'Вы оба сказали да.';

  @override
  String get roomSaved => 'Пара сохранена. Можно предложить встречу.';

  @override
  String get roomClosedNoAnswer => 'Комната закрылась без ответа.';

  @override
  String get roomSuggestDate => 'Предложить встречу';

  @override
  String get safetyCheckin => 'Всё хорошо?';

  @override
  String get safetyCheckinBody =>
      'Если не ответите за пять минут, ваш круг безопасности получит оповещение с вашей геопозицией.';

  @override
  String get safetyAllGood => 'Да, всё хорошо';

  @override
  String get safetyCircleAlerted => 'Ваш круг оповещён.';

  @override
  String get safetyNoCircle =>
      'Тревога записана. Добавьте близких, чтобы в следующий раз их оповестили.';

  @override
  String get safetyWhoToAlert => 'Кого оповещать?';

  @override
  String get safetyWhoToAlertBody =>
      'Эти люди получат вашу геопозицию в реальном времени при тревоге.';

  @override
  String get safetyTitle => 'Безопасность';

  @override
  String get safetySubtitle => 'Кого оповестят, если что-то пойдёт не так';

  @override
  String get safetyQuietAlert => 'Тихая тревога';

  @override
  String get safetyQuietAlertBody =>
      'Оповещает ваш круг с геопозицией. На экране телефона ничего не появляется.';

  @override
  String get safetyTrigger => 'Поднять тревогу';

  @override
  String get safetyMyCircle => 'Мой круг';

  @override
  String get safetyThreeEnough => 'Трёх человек достаточно';

  @override
  String get safetyNobodyYet =>
      'Пока никого. Без круга тревога записывается, но никого не оповещает.';

  @override
  String get safetyAddSomeone => 'Добавить человека';

  @override
  String get wingmanTitle => 'Мнение друзей';

  @override
  String get wingmanAnon => 'Ваше мнение анонимно';

  @override
  String get wingmanUnavailable => 'Запросы недоступны';

  @override
  String get wingmanNothing => 'Нечего оценивать';

  @override
  String get wingmanNothingBody =>
      'Когда друг спросит ваше мнение о профиле, он появится здесь.';

  @override
  String wingmanAsksYou(String name) {
    return '$name спрашивает ваше мнение';
  }

  @override
  String get wingmanMeh => 'Так себе';

  @override
  String get wingmanWorthIt => 'Стоит того';

  @override
  String get wingmanPrivacy =>
      'Ваш друг увидит лишь одобрение группы, но не кто что сказал.';

  @override
  String get marketLocationOff => 'Службы геолокации отключены.';

  @override
  String get marketGpsDenied => 'Доступ к GPS запрещён.';

  @override
  String get marketGpsApplied => 'GPS-позиция применена.';

  @override
  String get marketGpsFailed => 'Не удалось получить местоположение.';

  @override
  String get marketYourArea => 'Ваш район';

  @override
  String get marketCityOrArea => 'Город или район';

  @override
  String get marketLocationCleared => 'Геолокация отключена.';

  @override
  String get marketUseGps => 'Использовать мою GPS-позицию';

  @override
  String get marketApply => 'Применить';

  @override
  String marketRemoveProduct(String name) {
    return 'Убрать «$name»?';
  }

  @override
  String get marketProductUnavailable => 'Товар недоступен.';

  @override
  String get marketPaymentUnavailable => 'Оплата Mobile Money недоступна.';

  @override
  String get marketCheckoutUnreachable => 'Оплата Mobile Money недоступна.';

  @override
  String get marketBoostDone => 'Оплачено: объявление продвигается.';

  @override
  String get marketBoostPending => 'Оплата продвижения ожидается.';

  @override
  String get marketBoostFailed => 'Сейчас продвинуть нельзя.';

  @override
  String get marketTitle => 'Assimé';

  @override
  String get marketBecomeSeller => 'Стать проверенным продавцом';

  @override
  String get marketAddProduct => 'Добавить товар';

  @override
  String get marketAroundYou => 'Рядом с вами';

  @override
  String get marketMyGps => 'Моя GPS-позиция';

  @override
  String get marketPickArea => 'Выбрать район';

  @override
  String get marketNearYou => 'Товары рядом';

  @override
  String get marketUnavailable => 'Маркет недоступен.';

  @override
  String get marketNoProduct => 'Товаров пока нет.';

  @override
  String get marketNoMatch => 'Ничего не найдено по этому запросу.';

  @override
  String get marketAllShown => 'Показаны все товары';

  @override
  String get marketMyCatalogue => 'Мой каталог';

  @override
  String get marketSwipeCatalogue => 'Проведите, чтобы увидеть все товары';

  @override
  String get marketCatalogueEmpty => 'Ваш каталог пуст';

  @override
  String get marketCatalogueEmptyBody =>
      'Добавьте первый товар, чтобы начать продавать!';

  @override
  String get marketBoosted => 'Спонсорское';

  @override
  String get vitrineSeeProduct => 'Открыть товар';

  @override
  String get vitrineHint => 'Коснитесь товара, чтобы открыть его';

  @override
  String get vitrineTitle => 'Витрина Маркета';

  @override
  String get versesMorning => 'Утренний стих';

  @override
  String get versesEvening => 'Вечерний стих';

  @override
  String get versesChannel => 'Стихи дня';

  @override
  String get versesChannelDesc => 'Стихи в 6:00 и 18:00';

  @override
  String get versesSchedule => 'Каждый день в 6:00 и 18:00';

  @override
  String get versesThisMorning => 'Сегодня утром';

  @override
  String get versesThisEvening => 'Сегодня вечером';

  @override
  String get versesBibleTitle => 'Библейские стихи';

  @override
  String get versesQuranTitle => 'Аяты Корана';

  @override
  String get versesShare => 'Поделиться';

  @override
  String get versesOfflineHint =>
      'Стихи приходят даже без интернета: они уже на вашем телефоне.';

  @override
  String get marketBoosted48h => 'Спонсорское';

  @override
  String get marketBoost => 'Продвинуть';

  @override
  String get marketRemove => 'Убрать';

  @override
  String get marketGpsSaved => 'GPS-позиция сохранена.';

  @override
  String get marketNameAndPrice => 'Нужны название и цена.';

  @override
  String get marketEditProduct => 'Изменить товар';

  @override
  String get marketMainPhoto => 'Главное фото';

  @override
  String get marketOtherPhotos => 'Другие фото';

  @override
  String get marketDescription => 'Описание';

  @override
  String get marketCurrency => 'Валюта';

  @override
  String get marketCategory => 'Категория';

  @override
  String get marketPickCategory => 'Выберите категорию';

  @override
  String get marketSpecifyCategory => 'Уточните категорию';

  @override
  String marketGpsCoords(String lat, String lon) {
    return 'Координаты GPS: $lat, $lon';
  }

  @override
  String get marketUploadingPhoto => 'Загрузка фото…';

  @override
  String get marketAddPhoto => 'Добавить фото';

  @override
  String get groupEditName => 'Изменить название';

  @override
  String get groupAddPhoto => 'Добавить фото';

  @override
  String get groupChangePhoto => 'Изменить фото';

  @override
  String get groupRemovePhoto => 'Убрать фото';

  @override
  String get groupNoLink => 'Нет активной ссылки';

  @override
  String get groupLinkActive => 'Ссылка активна';

  @override
  String get groupCreator => 'Создатель';

  @override
  String get groupAdmin => 'Администратор';

  @override
  String get groupAddMembers => 'Добавить участников';

  @override
  String get groupLeave => 'Покинуть группу';

  @override
  String get groupName => 'Название группы';

  @override
  String get groupCopyLink => 'Скопировать ссылку';

  @override
  String get groupRegenLink => 'Пересоздать ссылку';

  @override
  String get groupDisableLink => 'Отключить ссылку';

  @override
  String get groupLinkCopied => 'Ссылка скопирована.';

  @override
  String get groupLinkDisabled => 'Ссылка отключена.';

  @override
  String get groupAllContactsIn => 'Все ваши контакты Pokou уже в этой группе.';

  @override
  String get groupAddToGroup => 'Добавить в группу';

  @override
  String groupMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено $count участника.',
      many: 'Добавлено $count участников.',
      few: 'Добавлено $count участника.',
      one: 'Добавлен $count участник.',
    );
    return '$_temp0';
  }

  @override
  String get groupLeaveTitle => 'Покинуть группу?';

  @override
  String groupLeaveBody(String name) {
    return 'Вы перестанете получать сообщения из «$name».';
  }

  @override
  String get groupLeaveAction => 'Выйти';

  @override
  String get groupNoMessage => 'Сообщений нет. Начните разговор.';

  @override
  String get groupNotEncryptedNotice =>
      'Сквозное шифрование: читать могут только участники.';

  @override
  String get botLabel => 'Бот';

  @override
  String get botConversationNotice =>
      'Вы пишете боту компании. Эти сообщения не защищены сквозным шифрованием: компания читает то, что вы отправляете.';

  @override
  String get groupAdminsOnly => 'Только администраторы';

  @override
  String get groupCallOngoing => 'Идёт звонок';

  @override
  String get communityEdit => 'Изменить сообщество';

  @override
  String get commonName => 'Название';

  @override
  String get communityEditFailed => 'Не удалось изменить.';

  @override
  String get communityAddGroup => 'Добавить группу';

  @override
  String get communityNewGroup => 'Создать новую группу';

  @override
  String get communityAttachGroup => 'Прикрепить существующую группу';

  @override
  String communityDetachTitle(String name) {
    return 'Открепить «$name»?';
  }

  @override
  String get communityDetachBody =>
      'Группа покидает сообщество, но продолжает существовать: её чат и участники не меняются.';

  @override
  String get communityDetach => 'Открепить';

  @override
  String get communityDetachFailed => 'Не удалось открепить группу.';

  @override
  String get communityLinkNote =>
      'Обладатель ссылки вступает в сообщество и его группу «Объявления» — остальные группы добавляются по одной.';

  @override
  String get communityActionFailed => 'Не получилось.';

  @override
  String get communityLeaveTitle => 'Покинуть сообщество?';

  @override
  String get communityLeaveBody =>
      'Вы перестанете получать её объявления. Группы, куда вы вступили, останутся вашими.';

  @override
  String get communityLeave => 'Покинуть сообщество';

  @override
  String get communityLeaveFailed => 'Не удалось покинуть сообщество.';

  @override
  String get communityOne => 'Сообщество';

  @override
  String get communityUnavailable =>
      'Сообщество недоступно — проверьте соединение.';

  @override
  String get communityGroups => 'ГРУППЫ';

  @override
  String get communityAnnouncements =>
      'Объявления · только для администраторов';

  @override
  String get communityOnlyAdminGroups =>
      'В сообщество могут войти только группы, которыми вы управляете.';

  @override
  String get channelPostsUnavailable => 'Публикации недоступны.';

  @override
  String get channelReactionFailed => 'Реакция не сохранена.';

  @override
  String get channelPostFailed => 'Не удалось опубликовать.';

  @override
  String get channelEditPost => 'Изменить публикацию';

  @override
  String get channelEditTooOld =>
      'Изменить нельзя — публикация слишком старая.';

  @override
  String get channelDeletePost => 'Удалить публикацию?';

  @override
  String get channelDeleteBody => 'Она исчезнет у всех подписчиков.';

  @override
  String get channelDeleteFailed => 'Не удалось удалить.';

  @override
  String get channelLinkCopied => 'Ссылка на канал скопирована.';

  @override
  String get channelLinkUnavailable => 'Ссылка недоступна.';

  @override
  String get channelEdit => 'Изменить канал';

  @override
  String get channelPublish => 'Опубликовать';

  @override
  String channelFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подписчика',
      many: '$count подписчиков',
      few: '$count подписчика',
      one: '$count подписчик',
    );
    return '$_temp0';
  }

  @override
  String get channelFollowing => 'Подписан';

  @override
  String get channelEdited => '· изменено';

  @override
  String get channelImageFailed => 'Изображение не отправлено.';

  @override
  String get channelNewPost => 'Новая публикация';

  @override
  String get channelPostHint => 'Ваше объявление…';

  @override
  String pollAnswerN(int index) {
    return 'Ответ $index';
  }

  @override
  String get pollAddAnswer => 'Добавить ответ';

  @override
  String get pollMultiple => 'Можно несколько ответов';

  @override
  String get pollAddImage => 'Добавить изображение';

  @override
  String get pollRemove => 'Убрать опрос';

  @override
  String get pollOne => 'Опрос';

  @override
  String get pollQuestion => 'Ваш вопрос';

  @override
  String get commonSending => 'Отправка…';

  @override
  String channelPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count публикации',
      many: '$count публикаций',
      few: '$count публикации',
      one: '$count публикация',
    );
    return '$_temp0';
  }

  @override
  String get lockChooseCode => 'Выберите код';

  @override
  String get lockCodeRule =>
      'От 4 до 8 цифр. Код никогда не покидает это устройство и не может быть восстановлен — если вы его забудете, блокировка снимается подтверждением номера телефона.';

  @override
  String get lockCode => 'Код';

  @override
  String get lockConfirmCode => 'Подтвердите код';

  @override
  String get lockTooShort => 'Код должен содержать не менее 4 цифр.';

  @override
  String get lockMismatch => 'Коды не совпадают.';

  @override
  String get lockCurrentCode => 'Текущий код';

  @override
  String get lockValidate => 'Подтвердить';

  @override
  String get lockEnabledToast => 'Блокировка включена.';

  @override
  String get lockSaveFailed => 'Не удалось сохранить код.';

  @override
  String get lockEnterCurrent => 'Введите текущий код';

  @override
  String get lockWrongCode => 'Неверный код.';

  @override
  String get lockCodeChanged => 'Код изменён.';

  @override
  String get lockEnterToDisable => 'Введите код, чтобы отключить';

  @override
  String get lockDisabledToast => 'Блокировка отключена.';

  @override
  String get lockTitle => 'Блокировка приложения';

  @override
  String get lockByCode => 'Блокировать кодом';

  @override
  String get lockOn => 'Включено';

  @override
  String get lockOff => 'Выключено';

  @override
  String get lockChangeCode => 'Изменить код';

  @override
  String get lockFootnoteKeystore =>
      'Pokou запрашивает код при каждом возврате на передний план. Код хранится в защищённом хранилище системы (Keystore) и не отправляется на сервер: он защищает экран, а не данные на самом устройстве.';

  @override
  String get lockFootnoteBiometrics =>
      'Разблокировка по отпечатку пока недоступна — она требует изменения конфигурации Android (FlutterFragmentActivity и разрешение USE_BIOMETRIC).';

  @override
  String get lockScreenTitle => 'Pokou заблокирован';

  @override
  String get lockEnterToContinue => 'Введите код, чтобы продолжить.';

  @override
  String get lockUnlock => 'Разблокировать';

  @override
  String get lockForgotQuestion => 'Забыли код?';

  @override
  String get lockSendFailed => 'Не удалось отправить — проверьте соединение.';

  @override
  String get lockRemovedToast =>
      'Блокировка снята. Новый код можно задать в профиле.';

  @override
  String get lockVerifyFailed => 'Не удалось проверить — проверьте соединение.';

  @override
  String get lockLogoutQuestion => 'Выйти из аккаунта?';

  @override
  String get lockLogoutBody =>
      'Используйте это, если у вас больше нет доступа к этому номеру. Переписки останутся на сервере, но для повторного входа понадобится доступный номер.';

  @override
  String get lockLogout => 'Выйти';

  @override
  String get lockForgotTitle => 'Забытый код';

  @override
  String get lockNoPhoneOnDevice =>
      'Не удалось найти ваш номер на этом устройстве.';

  @override
  String lockEnterSentCode(String phone) {
    return 'Введите код, отправленный на $phone по SMS и в WhatsApp.';
  }

  @override
  String lockForgotExplain(String phone) {
    return 'Код блокировки хранится только на этом устройстве и не может быть восстановлен. Чтобы снять блокировку, подтвердите свой номер $phone.';
  }

  @override
  String get lockLift => 'Снять блокировку';

  @override
  String get lockSendCode => 'Отправить код';

  @override
  String get lockResendCode => 'Отправить код ещё раз';

  @override
  String get lockNoAccessToNumber => 'У меня больше нет доступа к этому номеру';

  @override
  String get notifInApp => 'В приложении';

  @override
  String get notifMessages => 'Сообщения';

  @override
  String get notifMessagesSub => 'Личные переписки';

  @override
  String get notifMessagesSemantic => 'Уведомления о сообщениях';

  @override
  String get notifGroups => 'Группы';

  @override
  String get notifGroupsSub => 'Групповые переписки';

  @override
  String get notifGroupsSemantic => 'Уведомления о группах';

  @override
  String get notifCallsSub => 'Входящие аудио- и видеозвонки';

  @override
  String get notifCallsSemantic => 'Уведомления о звонках';

  @override
  String get notifSound => 'Звук и вибрация';

  @override
  String get notifSoundSemantic => 'Звук уведомлений';

  @override
  String get notifCallsFootnote =>
      'Отключение звонков здесь убирает только баннер, который показывается при открытом Pokou: входящий звонок по-прежнему звонит на весь экран, иначе вы пропускали бы звонки, не зная об этом.';

  @override
  String get notifSystem => 'Система';

  @override
  String get notifWebEnable => 'Включить уведомления браузера';

  @override
  String get notifWebEnableSub =>
      'Разрешить этому браузеру получать уведомления Pokou.';

  @override
  String get notifWebEnabled => 'Уведомления браузера включены.';

  @override
  String get notifWebEnableFailed =>
      'Не удалось включить уведомления. Проверьте настройки сайта в браузере.';

  @override
  String get notifAndroidSettings => 'Настройки Android';

  @override
  String get notifAndroidSettingsSub => 'Разрешение, каналы, звук по каналам';

  @override
  String get notifSystemFootnote =>
      'Когда Pokou закрыт, полученные уведомления показывает сам Android, не обращаясь к приложению: изменить их можно только в системных настройках выше.';

  @override
  String get devicesRemoveTitle => 'Убрать это устройство?';

  @override
  String get devicesRemoveCurrentBody =>
      'Это устройство перестанет получать уведомления, пока вы снова не откроете Pokou.';

  @override
  String get devicesRemoveOtherBody =>
      'Это устройство перестанет получать уведомления. Оно останется в аккаунте до следующего выхода.';

  @override
  String get devicesRemove => 'Убрать';

  @override
  String get devicesRemoveFailed => 'Не удалось убрать это устройство.';

  @override
  String get devicesTitle => 'Подключённые устройства';

  @override
  String get devicesUnavailable =>
      'Список недоступен — проверьте соединение и потяните, чтобы обновить.';

  @override
  String get devicesEmpty =>
      'Нет устройств, зарегистрированных для уведомлений. Они включаются при первом открытии Pokou на устройстве.';

  @override
  String get devicesThisDevice => ' · это устройство';

  @override
  String devicesLastSeen(String date, String hint) {
    return 'Активно $date · …$hint';
  }

  @override
  String get devicesFootnote =>
      'Устройство появляется здесь, как только регистрируется для push-уведомлений. Его удаление отключает уведомления; сессию это не закрывает — она истекает сама.';

  @override
  String get devicesBrowser => 'Браузер';

  @override
  String devicesTodayAt(String time) {
    return 'сегодня в $time';
  }

  @override
  String get storageNoCachedMedia => 'Нет медиа в кэше.';

  @override
  String storageFilesCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла удалено из кэша.',
      many: '$count файлов удалено из кэша.',
      few: '$count файла удалены из кэша.',
      one: '$count файл удалён из кэша.',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Хранилище и данные';

  @override
  String get storageCachedMedia => 'Медиа в кэше';

  @override
  String get storageMediaLabel => 'Фото, видео и голосовые сообщения';

  @override
  String get storageComputing => 'Подсчёт…';

  @override
  String get storageNoFile => 'Нет файлов';

  @override
  String storageFileCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла',
      many: '$count файлов',
      few: '$count файла',
      one: '$count файл',
    );
    return '$_temp0 · $size';
  }

  @override
  String get storageClearCache => 'Очистить кэш';

  @override
  String get storageClearFootnote =>
      'Очищенные файлы скачиваются заново по требованию, когда вы снова открываете переписку: ничего не теряется, только освобождается место.';

  @override
  String get storageMobileData => 'Мобильные данные';

  @override
  String get storageDataSaver => 'Экономия трафика';

  @override
  String get storageDataSaverSub => 'Не загружать медиа автоматически';

  @override
  String get storageDataSaverFootnote =>
      'Когда включено, полученные фото и видео скачиваются только после нажатия, а отправляемые фото сжимаются сильнее.';

  @override
  String get profileAvatarFailed => 'Не удалось обновить фото профиля.';

  @override
  String get profileChooseMonitor => 'Выберите монитор';

  @override
  String get profileBabaMessaging => 'Чат Baba';

  @override
  String profileMonitorAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Оповещения от $count монитора',
      many: 'Оповещения от $count мониторов',
      few: 'Оповещения от $count мониторов',
      one: 'Оповещения от $count монитора',
    );
    return '$_temp0';
  }

  @override
  String get profileBabaAssistant => 'Ассистент Baba';

  @override
  String get profileShieldModeBody =>
      'Удерживает звонки и приглушает неприоритетные переписки, пока вы сосредоточены. Контакты с метками «Business», «Клиент», «Поставщик» или «Босс» проходят всегда.';

  @override
  String get contactConnectFailed => 'Не удалось подключиться.';

  @override
  String get contactCallFailed => 'Сейчас нельзя позвонить.';

  @override
  String contactBlockTitle(String name) {
    return 'Заблокировать $name?';
  }

  @override
  String get contactBlockBody =>
      'Этот человек больше не сможет писать вам и звонить. Он об этом не узнает.';

  @override
  String get contactActionFailed => 'Сейчас действие недоступно.';

  @override
  String get contactSavedToast => 'Контакт сохранён';

  @override
  String get contactCall => 'Звонок';

  @override
  String get contactSharedTitle => 'Общие материалы';

  @override
  String get contactSharedMedia => 'Медиа';

  @override
  String get contactSharedDocuments => 'Документы';

  @override
  String get contactSharedLinks => 'Ссылки';

  @override
  String get contactNoMedia => 'Фото и видео не пересылались.';

  @override
  String get contactNoDocuments => 'Документы не пересылались.';

  @override
  String get contactNoLinks => 'Ссылки не пересылались.';

  @override
  String contactCommonGroups(int count) {
    return 'Общие группы ($count)';
  }

  @override
  String contactCatalog(int count) {
    return 'Каталог ($count)';
  }

  @override
  String contactUnblockName(String name) {
    return 'Разблокировать $name';
  }

  @override
  String contactBlockName(String name) {
    return 'Заблокировать $name';
  }

  @override
  String get contactUnblockHint =>
      'Этот человек снова сможет писать вам и звонить.';

  @override
  String get contactBlockHint =>
      'Он больше не сможет писать вам и звонить и не узнает об этом.';

  @override
  String get adNeedTitleBody => 'Укажите заголовок и текст объявления.';

  @override
  String get adSendFailed => 'Не удалось отправить запрос.';

  @override
  String get adCreateTitle => 'Создать рекламу';

  @override
  String get adWhoSeesTitle => 'Кто её увидит';

  @override
  String get adWhoSeesBody =>
      'Все пользователи Pokou Messenger во вкладке «Рынок» или между двумя статусами — на ваш выбор.';

  @override
  String get adReviewTitle => 'Проверка перед показом';

  @override
  String get adReviewBody =>
      'Наша команда читает каждую кампанию перед запуском. Рассчитывайте на несколько часов.';

  @override
  String get adCountdownTitle => 'Отсчёт начинается с одобрения';

  @override
  String get adCountdownBody =>
      'Дни показа начинаются после принятия кампании, а не в момент оплаты.';

  @override
  String get adRefundTitle => 'Отклонена? Деньги вернутся';

  @override
  String get adRefundBody =>
      'Если кампанию нельзя показать, свяжитесь с нами: сумма будет возвращена.';

  @override
  String get adTitleHint => 'Напр.: цемент CIMTOGO со скидкой';

  @override
  String get adBodyHint => 'Что вы предлагаете и как с вами связаться.';

  @override
  String get adMediaLabel => 'Фото или видео (необязательно)';

  @override
  String get adMediaHint =>
      'Видео не длиннее 30 секунд. Без изображения показывается только текст.';

  @override
  String get adVideo30s => 'Видео 30 с';

  @override
  String get adPlacement => 'Размещение';

  @override
  String get adPlacementMarket => 'Вкладка «Рынок»';

  @override
  String get adPlacementStatus => 'Между статусами';

  @override
  String get adDuration => 'Длительность';

  @override
  String get adOneWeek => '1 неделя';

  @override
  String get adTwoWeeks => '2 недели';

  @override
  String get adOneMonth => '1 месяц';

  @override
  String get adPayCaption => 'Оплата через Mobile Money';

  @override
  String get adPayAction => 'Оплатить и отправить';

  @override
  String productInterestedMessage(String name, String price, String currency) {
    return 'Здравствуйте, меня интересует ваш товар $name за $price $currency. Он в наличии?';
  }

  @override
  String get productWriteFailed => 'Сейчас нельзя написать продавцу.';

  @override
  String get productCallFirstWrite => 'Позвонить нельзя — сначала напишите.';

  @override
  String get productRateSeller => 'Оценить продавца';

  @override
  String get productEditReview => 'Изменить мой отзыв';

  @override
  String get productReviewScope =>
      'Отзыв касается ПРОДАВЦА, а не товара: важно доверие к человеку, и оно сохраняется, даже если товар исчезнет из каталога.';

  @override
  String get productReviewHint => 'Ваш комментарий (необязательно)';

  @override
  String get productDeleteReview => 'Удалить мой отзыв';

  @override
  String get productReviewFailed => 'Отзыв не сохранён.';

  @override
  String get productTitle => 'Товар';

  @override
  String get productOpening => 'Открывается…';

  @override
  String get productDiscuss => 'Написать';

  @override
  String get productCallAction => 'Позвонить';

  @override
  String get productReviews => 'Отзывы';

  @override
  String get productNoReviewYet => 'Пока нет отзывов';

  @override
  String productRatingSummary(String rating, int reviews) {
    String _temp0 = intl.Intl.pluralLogic(
      reviews,
      locale: localeName,
      other: '$reviews отзыва',
      many: '$reviews отзывов',
      few: '$reviews отзыва',
      one: '$reviews отзыв',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String productCountSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      many: '$count товаров',
      few: '$count товара',
      one: '$count товар',
    );
    return ' · $_temp0';
  }

  @override
  String get productCertified => 'Аккаунт проверен командой Pokou.';

  @override
  String get productReviewMine => 'Вы';

  @override
  String get verifNeedDocument => 'Добавьте фотографию удостоверения личности.';

  @override
  String get verifTitle => 'Стать проверенным продавцом';

  @override
  String get verifBadgeTitle => 'Синий значок на ваших объявлениях';

  @override
  String get verifBadgeBody =>
      'Покупатели видят, что вашу личность проверила наша команда.';

  @override
  String get verifWhyTitle => 'Почему это решает всё';

  @override
  String get verifWhyBody =>
      'Покупатель охотнее отправит деньги через Mobile Money человеку с подтверждённой личностью, чем незнакомцу.';

  @override
  String get verifNeedTitle => 'Что нужно предоставить';

  @override
  String get verifNeedBody =>
      'Чёткое фото удостоверения, паспорта или прав. Имя должно быть читаемым.';

  @override
  String get verifUseTitle => 'Что мы с этим делаем';

  @override
  String get verifUseBody =>
      'Её читает только наша команда для проверки; она никогда не появляется в вашем профиле и не показывается покупателям.';

  @override
  String get verifOneYearTitle => 'Действует один год';

  @override
  String get verifOneYearBody =>
      'Значок действует двенадцать месяцев. На рассмотрение уйдёт несколько дней.';

  @override
  String get verifDocumentLabel => 'Ваше удостоверение личности';

  @override
  String get verifPayCaption => 'Оплата через Mobile Money · 1 год';

  @override
  String get verifChoosePhoto => 'Выбрать фото';

  @override
  String get verifChange => 'Изменить';

  @override
  String get marketRemoveBody =>
      'Объявление исчезает с рынка. Переписки о нём остаются читаемыми, а покупатели, уже получившие его, сохраняют свою историю.';

  @override
  String get marketRemoveFailed => 'Не удалось снять объявление.';

  @override
  String get marketImageFailed =>
      'Изображение не отправлено — попробуйте ещё раз.';

  @override
  String get marketMainPhotoHint => 'Именно она представляет товар в списке.';

  @override
  String get marketName => 'Название';

  @override
  String get marketPrice => 'Цена';

  @override
  String get marketNoReviewYet => 'пока нет отзывов';

  @override
  String get marketSearchHint => 'Найти товар…';

  @override
  String get callLogEmpty => 'Пока нет звонков.';

  @override
  String get callLogUnknownUser => 'Пользователь';

  @override
  String get callStatusMissed => 'Пропущен';

  @override
  String get callStatusNoAnswer => 'Без ответа';

  @override
  String get callStatusDeclined => 'Отклонён';

  @override
  String get callStatusReceived => 'Принят';

  @override
  String get callStatusEnded => 'Завершён';

  @override
  String get callStatusOngoing => 'Идёт';

  @override
  String get callStatusOutgoing => 'Исходящий';

  @override
  String get callVideoTitle => 'Видеозвонок';

  @override
  String get callAudioTitle => 'Аудиозвонок';

  @override
  String callRedialQuestion(String name) {
    return 'Перезвонить $name?';
  }

  @override
  String get callJoinFailed => 'Не удалось подключиться к звонку.';

  @override
  String get callNobodyToAdd => 'Больше некого добавить.';

  @override
  String get callAddToCall => 'Добавить к звонку';

  @override
  String get callAdd => 'Добавить';

  @override
  String get callAddFailed => 'Не удалось добавить участника.';

  @override
  String get callReactionFailed => 'Не удалось отправить реакцию.';

  @override
  String get callLeaveConfirmTitle => 'Выйти из звонка?';

  @override
  String get callLeaveConfirmBody =>
      'Остальные участники могут продолжать разговор. Можно закрыть этот экран, не завершая звонок, и вернуться через панель звонка.';

  @override
  String get callYou => 'Вы';

  @override
  String get callContact => 'Контакт';

  @override
  String get callConnecting => 'Подключение к звонку…';

  @override
  String get callPreparing => 'Звонок подготавливается';

  @override
  String get callWaiting => 'Ожидание…';

  @override
  String get callJoinImpossible => 'Не удалось присоединиться к звонку.';

  @override
  String get callEncryptedJoinFailed =>
      'Не удалось открыть этот зашифрованный звонок на этом телефоне. Звонящий уведомлён.';

  @override
  String get callIncoming => 'Входящий звонок';

  @override
  String callIncomingFrom(String name) {
    return '$name звонит вам';
  }

  @override
  String get callIncomingGroup => 'Входящий групповой звонок';

  @override
  String get streakSubtitle =>
      'Пропущенный день — несколько минут, чтобы его наверстать';

  @override
  String get streakUnavailable => 'Серии недоступны';

  @override
  String get streakCheckConnection =>
      'Проверьте соединение и попробуйте снова.';

  @override
  String get streakEmptyTitle => 'Пока нет серий';

  @override
  String get streakEmptyBody =>
      'Обменивайтесь сообщением каждый день с одним и тем же человеком: серия начинается с первого обмена.';

  @override
  String get streakToRescue => 'Спасти сейчас';

  @override
  String get streakToRescueSub =>
      'После истечения срока серия начинается с нуля';

  @override
  String get streakMine => 'Мои серии';

  @override
  String get streakRunning => 'Идут';

  @override
  String streakRecord(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return 'Рекорд: $_temp0';
  }

  @override
  String get streakLongest => 'Ваша самая длинная серия';

  @override
  String get streakRestorePending =>
      'Ваша серия возобновится, как только подтвердится оплата.';

  @override
  String get streakDeadlinePassed => 'Возможно, срок уже прошёл.';

  @override
  String streakBroken(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Серия из $days дней прервана',
      many: 'Серия из $days дней прервана',
      few: 'Серия из $days дней прервана',
      one: 'Серия из $days дня прервана',
    );
    return '$_temp0';
  }

  @override
  String get streakExpired => 'Срок истёк. Серия начинается с нуля.';

  @override
  String streakCountdown(String time) {
    return 'Осталось $time, чтобы её спасти';
  }

  @override
  String streakRescueAction(int amount) {
    return 'Спасти серию — $amount FCFA';
  }

  @override
  String get leagueSubtitle =>
      'Ваша лига растёт вместе с тем, что вы получаете';

  @override
  String get leagueUnavailable => 'Рейтинг недоступен';

  @override
  String get leagueRanking => 'Рейтинг';

  @override
  String get leagueProtectPending =>
      'Защита включится сразу после подтверждения оплаты.';

  @override
  String get leaguePaymentFailed => 'Не удалось начать оплату.';

  @override
  String get leagueAtTop => 'Вы на вершине рейтинга.';

  @override
  String leaguePointsNeeded(int points, String label) {
    return 'Ещё $points очков до $label.';
  }

  @override
  String get leagueProtected =>
      'Ваши очки защищены. На этой неделе ничего не уменьшится.';

  @override
  String get leagueDecayNow => 'Ваши очки уменьшатся при следующем пересчёте.';

  @override
  String leagueDecayIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Ваши очки уменьшатся через $days дня без активности.',
      many: 'Ваши очки уменьшатся через $days дней без активности.',
      few: 'Ваши очки уменьшатся через $days дня без активности.',
      one: 'Ваши очки уменьшатся через $days день без активности.',
    );
    return '$_temp0';
  }

  @override
  String get leagueProtectAction => 'Защитить очки — 500 FCFA';

  @override
  String get leagueNobodyRanked => 'Пока никого нет в рейтинге. Будьте первым.';

  @override
  String leagueMyRank(int rank, int points) {
    return 'Вы на $rank-м месте с $points очками.';
  }

  @override
  String get reactWith => 'Отреагировать…';

  @override
  String get reactPickEmoji => 'Выберите эмодзи на клавиатуре';

  @override
  String get reactAction => 'Отреагировать';

  @override
  String get mediaPoll => 'Опрос';

  @override
  String get mediaContact => 'Контакт';

  @override
  String get mediaSharedContact => 'Пересланный контакт';

  @override
  String get convEdited => '· изменено';

  @override
  String get convFallbackName => 'Переписка';

  @override
  String get convSomeone => 'Кто-то';

  @override
  String get contactsTagFailed => 'Не удалось обновить метку.';

  @override
  String get contactsTag => 'Пометить';

  @override
  String get contactsTitle => 'Контакты';

  @override
  String get contactsTyping => 'печатает…';

  @override
  String contactsTypingNamed(String name) {
    return '$name печатает…';
  }

  @override
  String contactsPreviewMine(String preview) {
    return 'Вы: $preview';
  }

  @override
  String contactsPreviewSender(String name, String preview) {
    return '$name: $preview';
  }

  @override
  String contactsNotInContacts(String preview) {
    return '$preview · нет в ваших контактах';
  }

  @override
  String get contactsAssistantSub => 'Ваш ИИ-ассистент';

  @override
  String get addContactTitle => 'Добавить контакт';

  @override
  String get addContactName => 'Имя';

  @override
  String get addContactAction => 'Добавить';

  @override
  String get joinLinkTitle => 'Присоединиться по ссылке';

  @override
  String get joinLinkBody =>
      'Вставьте присланную ссылку. Группа или сообщество — мы распознаем сами.';

  @override
  String get joinLinkContinue => 'Продолжить';

  @override
  String get joinLinkUnreadable => 'Не удалось прочитать ссылку-приглашение.';

  @override
  String joinAlreadyMember(String name) {
    return 'Вы уже в «$name».';
  }

  @override
  String joinGroupQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0. Присоединиться к этой группе?';
  }

  @override
  String get joinAction => 'Присоединиться';

  @override
  String get joinGroupFailed => 'Не удалось присоединиться к группе.';

  @override
  String joinCommunityCounts(int members, int groups) {
    String _temp0 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members участника',
      many: '$members участников',
      few: '$members участника',
      one: '$members участник',
    );
    String _temp1 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups группы',
      many: '$groups групп',
      few: '$groups группы',
      one: '$groups группа',
    );
    return '$_temp0 · $_temp1.';
  }

  @override
  String get joinCommunityBody =>
      'Вы будете получать её объявления. К остальным группам придётся присоединяться по одной.';

  @override
  String get joinCommunityFailed => 'Не удалось присоединиться к сообществу.';

  @override
  String get newChatOwnNumber => 'Это ваш собственный номер.';

  @override
  String get phoneLookupFailed =>
      'Неверный номер или его не удалось проверить.';

  @override
  String get phoneNotOnPokou => 'Этот номер пока не пользуется Pokou.';

  @override
  String get phoneInviteWhatsApp => 'Пригласить через WhatsApp';

  @override
  String get phoneInviteText =>
      'Привет! Приглашаю тебя попробовать Pokou — приватный мессенджер. Скачай приложение и добавь меня.';

  @override
  String get contactCardTitle => 'Визитка';

  @override
  String get viewOnceSeen => 'Просмотрено';

  @override
  String get viewOnceTapToSee =>
      'Одноразовый просмотр — нажмите, чтобы увидеть';

  @override
  String get audioPlayFailed => 'Не удалось воспроизвести';

  @override
  String mediaPhotoSize(Object size) {
    return 'Фото · $size';
  }

  @override
  String get mediaTapToDownload => 'Нажмите, чтобы скачать';

  @override
  String get mediaVideoUnavailable => 'Видео недоступно';

  @override
  String get mediaOpenDocFailed => 'Не удалось открыть документ.';

  @override
  String get mediaOpenRetry => 'Не удалось открыть — нажмите, чтобы повторить';

  @override
  String get dayToday => 'Сегодня';

  @override
  String get dayYesterday => 'Вчера';

  @override
  String get weekdayMonday => 'понедельник';

  @override
  String get weekdayTuesday => 'вторник';

  @override
  String get weekdayWednesday => 'среда';

  @override
  String get weekdayThursday => 'четверг';

  @override
  String get weekdayFriday => 'пятница';

  @override
  String get weekdaySaturday => 'суббота';

  @override
  String get weekdaySunday => 'воскресенье';

  @override
  String liveHoursLeft(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'осталось $hours ч',
      many: 'осталось $hours ч',
      few: 'осталось $hours ч',
      one: 'осталось $hours ч',
    );
    return '$_temp0';
  }

  @override
  String liveMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'осталось $minutes мин',
      many: 'осталось $minutes мин',
      few: 'осталось $minutes мин',
      one: 'осталась $minutes мин',
    );
    return '$_temp0';
  }

  @override
  String get liveAlmostOver => 'скоро закончится';

  @override
  String liveLocation(String remaining) {
    return 'В реальном времени · $remaining';
  }

  @override
  String get openInMaps => 'Открыть в Картах';

  @override
  String get composerEditPhoto => 'Изменить фото';

  @override
  String get composerEditorFailed => 'Не удалось открыть редактор.';

  @override
  String get composerCropRotate => 'Обрезать или повернуть';

  @override
  String get composerCaptionHint => 'Добавить подпись…';

  @override
  String composerTo(String name) {
    return 'для $name';
  }

  @override
  String get composerSend => 'Отправить';

  @override
  String get convOfflineNotCached =>
      'Нет сети — эта переписка ещё не сохранена локально.';

  @override
  String get convLoadFailed => 'Не удалось загрузить переписку.';

  @override
  String get convEmptyEdit => 'Пустое сообщение не может заменить текст.';

  @override
  String get convEditFailed => 'Не удалось изменить — проверьте соединение.';

  @override
  String get convOrderUpdateFailed => 'Не удалось обновить заказ.';

  @override
  String get convDeleteFailed => 'Не удалось удалить сообщение.';

  @override
  String get convForwardFailedMsg => 'Не удалось переслать сообщение.';

  @override
  String get convOfflineAttachment =>
      'Нет сети — для вложений нужно подключение.';

  @override
  String get convAttachmentFailed =>
      'Вложение не отправлено — попробуйте ещё раз.';

  @override
  String get groupOfflineNotCached =>
      'Нет сети — эта группа ещё не сохранена локально.';

  @override
  String get groupLoadFailed => 'Не удалось загрузить группу.';

  @override
  String get groupRenameFailed => 'Не удалось переименовать группу.';

  @override
  String get groupPhotoFailed => 'Фото группы не сохранено.';

  @override
  String get groupClearPhotoFailed => 'Не удалось убрать фото.';

  @override
  String get groupRoleFailed => 'Не удалось изменить роль.';

  @override
  String get groupInviteCreateFailed =>
      'Не удалось создать ссылку-приглашение.';

  @override
  String get groupInviteRevokeFailed => 'Не удалось отключить ссылку.';

  @override
  String get groupLeaveFailed => 'Не удалось покинуть группу.';

  @override
  String get groupRemoveMemberFailed => 'Не удалось удалить участника.';

  @override
  String get apiNetworkSilent => 'Сеть не отвечает';

  @override
  String apiError(int code) {
    return 'Ошибка ($code)';
  }

  @override
  String get orderProductDiscussed => 'Обсуждаемый товар';

  @override
  String get orderValidate => 'Подтвердить заказ';

  @override
  String get orderMarkShipped => 'Отметить как отправленный';

  @override
  String get orderMarkDelivered => 'Отметить как доставленный';

  @override
  String get orderBuyerWaiting => 'Этот покупатель ждёт вашего ответа.';

  @override
  String get orderNextStep => 'Следующий шаг заказа.';

  @override
  String get msgNotSentRetry => 'Не отправлено — нажмите, чтобы повторить';

  @override
  String get msgPendingSend => 'Ожидает отправки';

  @override
  String convSearchHint(String name) {
    return 'Поиск в $name…';
  }

  @override
  String get convSearchPrompt =>
      'Введите слово, чтобы найти сообщение в этой переписке.';

  @override
  String get convSearchEmpty => 'Сообщений не найдено.';

  @override
  String get commonUnknownName => 'Неизвестный';

  @override
  String get groupInviteLink => 'Ссылка-приглашение';

  @override
  String get groupDemoteAdmin => 'Снять права администратора';

  @override
  String get groupPromoteAdmin => 'Назначить администратором';

  @override
  String get groupInviteLinkBody =>
      'Любой, кто откроет эту ссылку, сразу войдёт в группу, без дополнительных шагов. Создайте новую, чтобы старая перестала работать.';

  @override
  String get groupNewLinkCreated =>
      'Создана новая ссылка — старая больше не работает.';

  @override
  String get groupAddFailed => 'Не удалось добавить.';

  @override
  String get groupCreateFailed => 'Не удалось создать группу.';

  @override
  String get groupNewTitle => 'Новая группа';

  @override
  String get groupCreateAction => 'Создать';

  @override
  String get groupNameHint => 'Название группы';

  @override
  String get groupPickParticipants => 'Выберите участников';

  @override
  String groupSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'выбрано $count участника',
      many: 'выбрано $count участников',
      few: 'выбрано $count участника',
      one: 'выбран $count участник',
    );
    return '$_temp0';
  }

  @override
  String get pushIncomingVideoCall => 'Входящий видеозвонок';

  @override
  String get pushIncomingAudioCall => 'Входящий аудиозвонок';

  @override
  String get pushAnswer => 'Ответить';

  @override
  String get pushDecline => 'Отклонить';

  @override
  String get pushMessagesChannel => 'Сообщения';

  @override
  String get pushMessagesChannelDesc => 'Уведомления о новых сообщениях Pokou';

  @override
  String get pushCallsChannel => 'Звонки';

  @override
  String get pushCallsChannelDesc => 'Уведомления о входящих звонках Pokou';

  @override
  String get pushGroupFallback => 'Группа';

  @override
  String get notifNewMessage => 'Новое сообщение';

  @override
  String get notifPhoto => '📷 Фото';

  @override
  String get notifVideo => '🎥 Видео';

  @override
  String get notifVoice => '🎤 Голосовое сообщение';

  @override
  String get notifDocument => '📄 Документ';

  @override
  String get notifSticker => 'Стикер';

  @override
  String get notifLocation => '📍 Местоположение';

  @override
  String get notifContact => '👤 Контакт';

  @override
  String get notifPoll => '📊 Опрос';

  @override
  String get notifMe => 'Я';

  @override
  String get notifReply => 'Ответить';

  @override
  String get notifReplyHint => 'Ваше сообщение';

  @override
  String get notifMarkRead => 'Отметить как прочитанное';

  @override
  String get notifReplyQueued => 'отправится при открытии Pokou';

  @override
  String get notifReplyFailed =>
      'Ответ не отправлен — откройте Pokou, чтобы повторить';

  @override
  String notifSummary(int count, int conversations) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сообщения',
      many: '$count сообщений',
      few: '$count сообщения',
      one: '1 сообщение',
    );
    String _temp1 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations беседы',
      many: '$conversations бесед',
      few: '$conversations беседы',
      one: '1 беседа',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get audienceContacts => 'Мои контакты';

  @override
  String get audienceNobody => 'Никто';

  @override
  String get audienceExcept => 'Мои контакты, кроме…';

  @override
  String get audienceOnly => 'Только…';

  @override
  String get audienceContactsDesc =>
      'Все, кто есть в вашей адресной книге Pokou';

  @override
  String get audienceNobodyDesc => 'Ваши статусы будете видеть только вы';

  @override
  String get audienceExceptDesc => 'Ваши контакты, кроме выбранных вами';

  @override
  String get audienceOnlyDesc => 'Только выбранные вами люди';

  @override
  String get statusViewerFallback => 'Пользователь';

  @override
  String get statusPrivacySaved => 'Настройка видимости сохранена.';

  @override
  String get statusPrivacySaveFailed =>
      'Не удалось сохранить — проверьте соединение.';

  @override
  String get statusPrivacyTitle => 'Видимость статусов';

  @override
  String get statusExcludePeople => 'Кого исключить';

  @override
  String get statusAllowedPeople => 'Кому разрешено';

  @override
  String get statusNoContactToOffer => 'Пока нет контактов Pokou для выбора.';

  @override
  String get statusExceptFootnote =>
      'Эти люди не увидят ваши статусы, даже если они есть в ваших контактах.';

  @override
  String get statusOnlyFootnote =>
      'Ваши статусы увидят только эти люди. Им необязательно иметь вас в контактах.';

  @override
  String get status24hFootnote =>
      'Статус в любом случае исчезает через 24 часа — для всех.';

  @override
  String get statusGallery => 'Галерея';

  @override
  String get statusCamera => 'Камера';

  @override
  String get statusNewTitle => 'Новый статус';

  @override
  String get statusText => 'Текст';

  @override
  String get statusTypeHint => 'Введите свой статус…';

  @override
  String get statusPublish => 'Опубликовать';

  @override
  String get statusFeedTitle => 'Новости';

  @override
  String get statusFeedUnavailable => 'Статусы недоступны — повторить';

  @override
  String get statusSection => 'Статусы';

  @override
  String get statusMine => 'Я';

  @override
  String get channelsSection => 'Каналы';

  @override
  String get bcastNeedName => 'Дайте этому списку название.';

  @override
  String get bcastNeedRecipient => 'Выберите хотя бы одного получателя.';

  @override
  String get bcastSaveFailed => 'Не удалось сохранить.';

  @override
  String get bcastNewTitle => 'Новая рассылка';

  @override
  String get bcastEditTitle => 'Изменить список';

  @override
  String get bcastNameHint => 'Название списка (видно только вам)';

  @override
  String get bcastNoRecipient => 'Нет получателей';

  @override
  String bcastRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count получателя',
      many: '$count получателей',
      few: '$count получателя',
      one: '$count получатель',
    );
    return '$_temp0';
  }

  @override
  String get bcastContactsUnavailable => 'Контакты недоступны.';

  @override
  String get bcastNobodyOnPokou =>
      'Никого из ваших контактов пока нет в Pokou Messenger.';

  @override
  String get bcastNewList => 'Новый список';

  @override
  String get bcastListsTitle => 'Списки рассылки';

  @override
  String get bcastListsUnavailable => 'Списки недоступны.';

  @override
  String bcastDeleteTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get bcastDeleteBody =>
      'Уже отправленные сообщения останутся у получателей. Исчезнет только список.';

  @override
  String get bcastEmptyTitle => 'Объявите один раз — многим';

  @override
  String get bcastEmptyBody =>
      'Каждый получатель получает сообщение в своей личной переписке. Он не видит остальных и отвечает только вам — в отличие от группы, где все видят всех.';

  @override
  String bcastSentTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправлено $count получателям.',
      many: 'Отправлено $count получателям.',
      few: 'Отправлено $count получателям.',
      one: 'Отправлено $count получателю.',
    );
    return '$_temp0';
  }

  @override
  String bcastSentPartly(int sent, int total, int skipped) {
    return 'Отправлено $sent из $total — $skipped больше не получают ваши сообщения.';
  }

  @override
  String get bcastSendFailed => 'Отправка не удалась.';

  @override
  String get bcastEditRecipients => 'Изменить получателей';

  @override
  String get bcastHistoryUnavailable => 'История недоступна.';

  @override
  String get bcastNothingSent => 'Пока ничего не рассылалось.';

  @override
  String get bcastMessageHint => 'Сообщение для рассылки';

  @override
  String get bcastPrivacyNotice =>
      'Каждый получатель получает это сообщение лично. Он не видит остальных, а его ответ придёт вам в переписке с ним.';

  @override
  String get channelNameRequired => 'Название канала обязательно.';

  @override
  String get channelSaveFailed => 'Не удалось сохранить канал.';

  @override
  String get channelEditTitle => 'Изменить канал';

  @override
  String get channelNewTitle => 'Новый канал';

  @override
  String get channelAddImage => 'Добавить изображение';

  @override
  String get channelChangeImage => 'Изменить изображение';

  @override
  String get channelRemoveImage => 'Убрать изображение';

  @override
  String get channelNameLabel => 'Название канала';

  @override
  String get channelNameHint => 'Напр.: новости моей компании';

  @override
  String get channelDescriptionLabel => 'Описание';

  @override
  String get channelDescriptionHint => 'Представьте свой канал';

  @override
  String get channelSaveChanges => 'Сохранить изменения';

  @override
  String get channelCreateAction => 'Создать канал';

  @override
  String get channelLinkCopiedClipboard => 'Ссылка скопирована в буфер обмена.';

  @override
  String get channelLinkUnavailableShort => 'Ссылка недоступна.';

  @override
  String get channelSearchTooltip => 'Найти канал';

  @override
  String get channelCreateTooltip => 'Создать канал';

  @override
  String get channelEmptyHint => 'Создайте канал, чтобы делиться новостями.';

  @override
  String get channelGenerateLink => 'Создать ссылку';

  @override
  String get channelEditTooltip => 'Изменить';

  @override
  String get channelSearchHint => 'Найти канал…';

  @override
  String get channelSearchPrompt =>
      'Ищите по названию или описанию. Проверенные каналы показываются первыми.';

  @override
  String get channelSearchEmpty => 'Каналы не найдены.';

  @override
  String get channelNothingPublishedAdmin =>
      'Пока ничего не опубликовано — нажмите +, чтобы создать первую публикацию.';

  @override
  String get channelNothingPublished =>
      'Этот канал пока ничего не опубликовал.';

  @override
  String get channelFollow => 'Подписаться';

  @override
  String get channelFallbackName => 'Канал';

  @override
  String get communityNewTitle => 'Новое сообщество';

  @override
  String get communityNewBody =>
      'Сообщество объединяет несколько групп вокруг одних и тех же людей. Вместе с ним создаётся группа «Объявления»: писать в ней можете только вы, читают все участники.';

  @override
  String get communityNameHint => 'Название сообщества';

  @override
  String get communityDescriptionHint => 'Описание (необязательно)';

  @override
  String get communityCreateAction => 'Создать';

  @override
  String get communityCreateFailed => 'Не удалось создать.';

  @override
  String get communityNoGroupToAttach =>
      'У вас нет других групп для присоединения. К сообществу могут присоединиться только группы, которыми вы управляете.';

  @override
  String get communityAddGroupFailed => 'Не удалось добавить группу.';

  @override
  String get communityLinkFailed => 'Не удалось создать ссылку.';

  @override
  String get communityCreateLink => 'Создать ссылку';

  @override
  String get sparkOpenRoomsSub => 'Они закрываются сами';

  @override
  String get sparkMore => 'Далее';

  @override
  String sparkRoomOpen(String time) {
    return 'Комната открыта — $time';
  }

  @override
  String get sparkBothYes => 'Вы оба сказали «да»';

  @override
  String get sparkMatchSaved => 'Совпадение сохранено';

  @override
  String get sparkRoomClosed => 'Комната закрыта';

  @override
  String get sparkMatch => 'Совпадение';

  @override
  String get sparkUnavailable => 'Spark недоступен';

  @override
  String get sparkTodaysDate => 'Сегодняшнее свидание';

  @override
  String get sparkTabOutings => 'Свидания';

  @override
  String sparkPersonAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String get aiSuggestSummary => 'Сводка';

  @override
  String get aiSuggestSummarySub => 'Быстрый обзор';

  @override
  String get aiSuggestSummaryPrompt => 'Сделай сводку текущей ситуации.';

  @override
  String get aiSuggestTrend => 'Тренд';

  @override
  String get aiSuggestTrendSub => 'Проанализировать динамику';

  @override
  String get aiSuggestTrendPrompt => 'Какая динамика за последние 7 дней?';

  @override
  String get aiSuggestAlerts => 'Оповещения';

  @override
  String get aiSuggestAlertsSub => 'Последние сигналы';

  @override
  String get aiSuggestAlertsPrompt =>
      'Есть ли недавние оповещения, о которых стоит знать?';

  @override
  String get aiSuggestAdvice => 'Совет';

  @override
  String get aiSuggestAdviceSub => 'Попросить идею';

  @override
  String get aiSuggestAdvicePrompt => 'Посоветуй, как организовать мой день.';

  @override
  String get aiSuggestWrite => 'Написать';

  @override
  String get aiSuggestWriteSub => 'Составить текст';

  @override
  String get aiSuggestWritePrompt => 'Помоги написать сообщение.';

  @override
  String get aiSuggestQuestion => 'Вопрос';

  @override
  String get aiSuggestQuestionSub => 'Что угодно';

  @override
  String get aiSuggestQuestionPrompt => 'У меня есть к тебе вопрос.';

  @override
  String get aiMessageHint => 'Сообщение…';

  @override
  String get aiHowCanIHelp => 'Чем я могу помочь?';

  @override
  String get aiAskAnything => 'Спросите меня о чём угодно.';

  @override
  String get aiAskAboutData => 'Задайте вопрос о подключённых данных.';

  @override
  String get aiThinking => 'Baba думает';

  @override
  String aiHelloIm(String name) {
    return 'Привет, я $name';
  }

  @override
  String get aiPartner => 'Ваш цифровой партнёр';

  @override
  String get aiGreetMorning => 'Доброе утро';

  @override
  String get aiGreetAfternoon => 'Добрый день';

  @override
  String get aiGreetEvening => 'Добрый вечер';

  @override
  String get aiNewChat => 'Новый чат';

  @override
  String get aiCopy => 'Копировать';

  @override
  String get aiCopied => 'Скопировано';

  @override
  String get aiGenerated => 'Создано ИИ';

  @override
  String get aiVoiceListening => 'Слушаю вас…';

  @override
  String get aiVoiceTranscribing => 'Расшифровка…';

  @override
  String get aiVoiceFailed => 'Не удалось вас расслышать. Попробуйте ещё раз.';

  @override
  String get aiVoiceSpeak => 'Говорить с ассистентом';

  @override
  String get aiVoiceRestart => 'Начать заново';

  @override
  String get aiVoiceSend => 'Отправить';

  @override
  String get aiVoiceStop => 'Готово';

  @override
  String get aiSendFailed => 'Сообщение не отправлено — попробуйте ещё раз.';

  @override
  String get digestTitle => 'Итоги дня';

  @override
  String get digestUnread => 'Непрочитанные сообщения:';

  @override
  String get digestMissedCalls => 'Пропущенные звонки:';

  @override
  String get digestVideoSuffix => ' (видео)';

  @override
  String digestShieldDeferred(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сообщения задержано режимом «Щит».',
      many: '$count сообщений задержано режимом «Щит».',
      few: '$count сообщения задержаны режимом «Щит».',
      one: '$count сообщение задержано режимом «Щит».',
    );
    return '$_temp0';
  }

  @override
  String digestMonitorSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сигнала от ваших мониторов для просмотра.',
      many: '$count сигналов от ваших мониторов для просмотра.',
      few: '$count сигнала от ваших мониторов для просмотра.',
      one: '$count сигнал от ваших мониторов для просмотра.',
    );
    return '$_temp0';
  }

  @override
  String get digestNothing => 'Сегодня нечего отметить — хорошего вечера!';

  @override
  String get shieldUnknownNumber => 'Неизвестный номер';

  @override
  String shieldFlushSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сообщения задержано во время встречи.',
      many: '$count сообщений задержано во время встречи.',
      few: '$count сообщения задержаны во время встречи.',
      one: '$count сообщение задержано во время встречи.',
    );
    return '$_temp0';
  }

  @override
  String get shieldPendingMessages => 'Задержанные сообщения';

  @override
  String shieldHandleSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count сообщения задержано режимом «Щит» — потяните вниз, чтобы показать',
      many:
          '$count сообщений задержано режимом «Щит» — потяните вниз, чтобы показать',
      few:
          '$count сообщения задержаны режимом «Щит» — потяните вниз, чтобы показать',
      one:
          '$count сообщение задержано режимом «Щит» — потяните вниз, чтобы показать',
    );
    return '$_temp0';
  }

  @override
  String shieldCallFrom(Object name) {
    return 'Звонок от $name';
  }

  @override
  String get shieldCallHeld => 'Удержан — режим «Щит»';

  @override
  String get statusViewersUnavailable => 'Список просмотров недоступен.';

  @override
  String statusSeenBy(int count) {
    return 'Просмотрели: $count';
  }

  @override
  String get statusNobodySeen => 'Пока никто не посмотрел.';

  @override
  String get statusBoostFailed => 'Не удалось продвинуть статус.';

  @override
  String get statusDeleteTitle => 'Удалить этот статус?';

  @override
  String get statusDeleteBody => 'Он исчезнет для всех, кто может его видеть.';

  @override
  String get statusDeleteFailed =>
      'Не удалось удалить — проверьте подключение.';

  @override
  String get statusPublishFailed =>
      'Не удалось опубликовать — проверьте подключение и повторите.';

  @override
  String get statusBoostAction => 'Продвинуть статус · 1 000 FCFA';

  @override
  String get modulesSubtitle =>
      'Добавьте то, что вам полезно, остальное оставьте';

  @override
  String get modulePaymentFailed => 'Не удалось начать оплату.';

  @override
  String deeplinkFollowedChannel(String name) {
    return 'Вы подписались на канал «$name»';
  }

  @override
  String get deeplinkOpenFailed =>
      'Сейчас не удалось открыть эту ссылку-приглашение.';

  @override
  String get cropTitle => 'Обрезать';

  @override
  String get cropHint =>
      'Сведите пальцы для масштаба, перетащите для кадрирования';

  @override
  String get cropConfirm => 'Подтвердить';

  @override
  String get inviteJoinMe => 'Присоединяйся ко мне в Pokou Messenger';

  @override
  String inviteJoinMeNamed(String name) {
    return '$name, присоединяйся ко мне в Pokou Messenger';
  }

  @override
  String get otpNoCodeReceived => 'Не получили код?';

  @override
  String get countryDialCode => 'Код страны';

  @override
  String get countrySearchHint => 'Страна или код (напр. Бенин, 229)';

  @override
  String get countryNoneFound => 'Страны не найдены.';

  @override
  String get presenceSomeone => 'Кто-то';

  @override
  String atTime(String time) {
    return 'в $time';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date в $time';
  }

  @override
  String truthAskedTo(String name) {
    return 'Для $name';
  }

  @override
  String get devicesNoPushHere => 'Это устройство не получает уведомления.';

  @override
  String get devicesNoPushHereBody =>
      'Оно не смогло зарегистрироваться в службе уведомлений. Нажмите, чтобы повторить.';

  @override
  String get devicesRetryDone => 'Теперь это устройство получает уведомления.';

  @override
  String get devicesRetryFailed =>
      'Зарегистрироваться по-прежнему не удалось — попробуйте позже.';

  @override
  String get chatsProfileMissing =>
      'Профиль недоступен — проверьте соединение и попробуйте снова.';

  @override
  String get recSlideToCancel => 'Проведите, чтобы отменить';

  @override
  String get recReleaseToCancel => 'Отпустите, чтобы отменить';

  @override
  String get recLocked => 'Закреплено';

  @override
  String get recSlideUpToLock => 'Проведите вверх, чтобы закрепить';

  @override
  String get recDelete => 'Удалить запись';

  @override
  String get recHoldToRecord => 'Удерживайте, чтобы записать';

  @override
  String get composerViewOnce => 'Одноразовый просмотр';

  @override
  String get composerViewOnceOn =>
      'Одноразовый просмотр включён — фото исчезнет после открытия.';

  @override
  String get composerViewOnceOff => 'Одноразовый просмотр выключен.';

  @override
  String get channelSuggestedTitle => 'Каналы, на которые стоит подписаться';

  @override
  String get channelSuggestedBody =>
      'Вы пока ни на один не подписаны. Вот несколько.';

  @override
  String get channelSuggestedNone => 'Пока нечего предложить.';

  @override
  String channelFollowed(String name) {
    return 'Вы подписались на «$name»';
  }

  @override
  String get channelFollowFailed =>
      'Не удалось подписаться — проверьте соединение.';

  @override
  String get certifyTitle => 'Подтверждённый канал';

  @override
  String get certifyWhyTitle => 'Значок и первое место в рекомендациях';

  @override
  String get certifyWhyBody =>
      'Подтверждённые каналы показываются первыми тем, кто ищет, на что подписаться, и значок виден на каждой публикации.';

  @override
  String get certifyReviewTitle => 'Проверка, а не покупка';

  @override
  String get certifyReviewBody =>
      'Наша команда читает ваш канал, прежде чем выдать значок. Значок, который просто покупается, не стоил бы ничего — именно в этом его ценность.';

  @override
  String get certifyRefundTitle => 'Отклонена? Деньги вернутся';

  @override
  String get certifyRefundBody =>
      'Если значок не может быть выдан, свяжитесь с нами: сумма будет возвращена.';

  @override
  String get certifyRenewTitle => 'Подписка, а не навсегда';

  @override
  String get certifyRenewBody =>
      'Значок действует столько, сколько выбранный тариф. Продление до истечения срока добавляет время, ничего не теряя.';

  @override
  String get certifyPlanMonthly => 'Ежемесячно — 3 000 FCFA';

  @override
  String get certifyPlanAnnual =>
      'Ежегодно — 30 000 FCFA (два месяца в подарок)';

  @override
  String get certifyAction => 'Оплатить и отправить заявку';

  @override
  String get certifyPending =>
      'Ваша заявка поступит команде сразу после подтверждения оплаты.';

  @override
  String get certifyFailed =>
      'Не удалось отправить заявку — попробуйте ещё раз.';

  @override
  String get certifyAlready => 'Этот канал подтверждён';

  @override
  String get certifyTooltip => 'Подтвердить этот канал';

  @override
  String get chatsStartTitle => 'Начните переписку';

  @override
  String get chatsStartBody =>
      'Ваши контакты уже в Pokou. Нажмите на имя, чтобы написать.';

  @override
  String get chatsSeeAllContacts => 'Показать все контакты';

  @override
  String get chatsNoNetworkTitle => 'Вашего круга пока нет в Pokou';

  @override
  String get chatsNoNetworkBody =>
      'Пригласите кого-нибудь или подпишитесь на канал, пока ждёте ответа.';

  @override
  String get chatsInviteContacts => 'Пригласить контакты';

  @override
  String get chatsDiscoverChannels => 'Открыть каналы';

  @override
  String get e2eeEncrypted => 'Сквозное шифрование';

  @override
  String get e2eeNotEncrypted => 'Без шифрования';

  @override
  String get e2eeNotEncryptedBody =>
      'Этому человеку нужно обновить Pokou для шифрования.';

  @override
  String get e2eeIdentityChangedTitle =>
      'Сведения о безопасности этого контакта изменились';

  @override
  String e2eeIdentityChangedBody(String name) {
    return 'Ключ безопасности $name изменился (новый телефон или переустановка). Если сомневаешься, уточни у $name.';
  }

  @override
  String get e2eeIdentityAccept => 'Я проверил, продолжить';

  @override
  String get e2eeBlockedTitle => 'Сообщение не отправлено';

  @override
  String get e2eeBlockedLookup =>
      'Не удалось получить ключ шифрования. Сообщение не отправлено — Pokou никогда не отправит его открыто без вашего ведома.';

  @override
  String get e2eeBlockedInvalid =>
      'Полученный ключ непригоден. Сообщение не отправлено из предосторожности.';

  @override
  String get e2eeBlockedIdentity =>
      'Ключ этого контакта изменился. Проверьте его личность перед отправкой.';

  @override
  String get e2eeBlockedCrypto =>
      'Шифрование не удалось. Сообщение не отправлено.';

  @override
  String get e2eeRetry => 'Повторить';

  @override
  String get profileTheme => 'Оформление';

  @override
  String get themeSystem => 'Как на телефоне';

  @override
  String get themeLight => 'Светлое';

  @override
  String get themeDark => 'Тёмное';

  @override
  String get themeHint =>
      'Тёмная тема меньше утомляет глаза вечером и экономит заряд на OLED-экранах.';

  @override
  String get a11yBack => 'Назад';

  @override
  String get a11yRefresh => 'Обновить';

  @override
  String get a11yMoreOptions => 'Ещё';

  @override
  String get a11yVoiceCall => 'Голосовой вызов';

  @override
  String get a11yVideoCall => 'Видеозвонок';

  @override
  String get a11yAttach => 'Прикрепить файл';

  @override
  String get a11yRate => 'Оценить';

  @override
  String get a11yAudioLevel => 'Уровень звука';

  @override
  String get marketCreateAd => 'Создать объявление';

  @override
  String get adSponsored => 'Реклама';

  @override
  String get adYours => 'Ваша реклама';

  @override
  String get adContact => 'Связаться';

  @override
  String get adContactFailed => 'Не удалось связаться с рекламодателем.';

  @override
  String get mediaSaveToPhone => 'Сохранить в телефон';

  @override
  String get mediaUndecryptable =>
      'Зашифрованное вложение нельзя открыть на этом телефоне.';

  @override
  String get mediaSaved => 'Сохранено в галерее';

  @override
  String get mediaExported => 'Выберите, куда сохранить';

  @override
  String get mediaSavePermission =>
      'Pokou нужен доступ к фото, чтобы сохранить этот файл.';

  @override
  String get mediaSaveNoSpace => 'На телефоне недостаточно места.';

  @override
  String get mediaSaveFailed => 'Не удалось сохранить.';

  @override
  String get composerEmoji => 'Эмодзи';

  @override
  String get convAttachGif => 'GIF';

  @override
  String get stickerTabEmoji => 'Эмодзи';

  @override
  String get stickerTabStickers => 'Стикеры';

  @override
  String get stickerSearchHint => 'Найти стикер';

  @override
  String get stickerRecents => 'Недавние';

  @override
  String get stickerFavorites => 'Избранное';

  @override
  String get stickerNoResult => 'Стикеры не найдены';

  @override
  String get stickerEmptyPanel => 'Пока нет стикеров';

  @override
  String get stickerBrowsePacks => 'Посмотреть наборы';

  @override
  String get stickerManagePacks => 'Управление наборами';

  @override
  String get stickerPacksTitle => 'Наборы стикеров';

  @override
  String get stickerPackAdd => 'Добавить';

  @override
  String get stickerPackAdded => 'Добавлен';

  @override
  String get stickerPackRemove => 'Убрать';

  @override
  String get stickerPackDelete => 'Удалить набор';

  @override
  String get stickerPackDeleteConfirm =>
      'Удалить этот набор и все его стикеры?';

  @override
  String get stickerMyPackName => 'Мои стикеры';

  @override
  String get stickerCreateFromPhoto => 'Создать из фото';

  @override
  String get stickerCreated => 'Стикер добавлен в ваши стикеры';

  @override
  String get stickerLimitReached => 'Ваш личный набор заполнен';

  @override
  String get stickerSendFailed => 'Стикер не отправлен — попробуйте ещё раз';

  @override
  String get stickerLabel => 'Стикер';

  @override
  String get stickerFavoriteAdded => 'Добавлено в избранное';

  @override
  String get stickerFavoriteRemoved => 'Убрано из избранного';

  @override
  String get stickerStoreEmpty => 'Пока нет доступных наборов';

  @override
  String get stickerSaveToMine => 'Добавить в мои стикеры';

  @override
  String get stickerSaved => 'Стикер добавлен в ваши стикеры';

  @override
  String get navBaba => 'Баба';

  @override
  String get appBarOnline => 'В сети';

  @override
  String get appBarOffline => 'Не в сети';

  @override
  String get marketNegotiate => 'Обсудить';

  @override
  String get callsCallBack => 'Перезвонить';

  @override
  String get callsFilterMissed => 'Пропущенные';

  @override
  String get callsFilterAll => 'Все';

  @override
  String get chatsFilterAll => 'Все';

  @override
  String get chatsFilterUnread => 'Непрочитанные';

  @override
  String get chatsFilterGroups => 'Группы';

  @override
  String get chatsSearchOrAsk => 'Найти или спросить Баба…';

  @override
  String get convEncryptedHint => 'Зашифрованное сообщение…';

  @override
  String get chatsArchivedSection => 'Архив';

  @override
  String get statusMineTitle => 'Моя новость';

  @override
  String get statusMineBody => 'Нажмите, чтобы опубликовать (24 ч)';

  @override
  String get statusMineVisibility => 'Видно моим контактам';

  @override
  String get callLeaveConference => 'Покинуть конференцию';

  @override
  String get callQualityExcellent => 'Отличное';

  @override
  String get callQualityGood => 'Хорошее';

  @override
  String get callQualityPoor => 'Слабое';

  @override
  String get callYouShort => 'Вы';

  @override
  String get callMutedShort => 'Без звука';

  @override
  String get callMuteLabel => 'Микрофон';

  @override
  String get callCameraLabel => 'Камера';

  @override
  String get callSpeakerLabel => 'Динамик';

  @override
  String get callFlipCamera => 'Сменить камеру';

  @override
  String get callFlipCameraFailed => 'Не удалось сменить камеру.';

  @override
  String get callNoAnswer => 'Нет ответа.';

  @override
  String callOngoingBanner(String duration) {
    return 'Идёт звонок · $duration — нажмите, чтобы вернуться';
  }

  @override
  String get callOngoingBannerRinging =>
      'Идёт звонок — нажмите, чтобы вернуться';

  @override
  String get callHangUp => 'Завершить';

  @override
  String get callInviteLabel => 'Пригласить';

  @override
  String get e2eeReassurance =>
      'Сквозное шифрование: никто, даже Pokou, не может читать эти сообщения.';

  @override
  String get chatsEncryptionFooter =>
      'Твои чаты защищены сквозным шифрованием.';

  @override
  String get callsRecentSection => 'НЕДАВНИЕ';

  @override
  String get callsGroupChip => 'Группа';

  @override
  String get callGroupNotEncrypted =>
      'Обычный групповой звонок — без сквозного шифрования';

  @override
  String get marketCatalogueSeeAll => 'Показать все';

  @override
  String get marketCatalogueOpen => 'Открыть мой каталог';

  @override
  String get marketCatalogueTotal => 'Объявления';

  @override
  String get marketCatalogueOnline => 'Опубликовано';

  @override
  String get marketCatalogueBoostedLabel => 'С продвижением';

  @override
  String get marketCatalogueWithdrawn => 'Снятые';

  @override
  String get marketFilterAll => 'Все';

  @override
  String get marketCertifiedSellers => 'Сертифицированные продавцы';

  @override
  String get marketCatalogueNoneInFilter => 'Нет объявлений по этому фильтру.';

  @override
  String get marketStatusModerated => 'Снято с площадки';

  @override
  String get marketStatusModeratedBody =>
      'Покупатели больше его не видят. Напишите в поддержку, если считаете это ошибкой.';

  @override
  String get callsFilterDirect => 'Один на один';

  @override
  String get profileMyAccount => 'Мой аккаунт';

  @override
  String get profileVerifyAccount => 'Подтвердить аккаунт';

  @override
  String get profileVerifyAccountBody =>
      'Получите значок проверенного продавца на Рынке';

  @override
  String get profileCertificationPending => 'Проверка выполняется';

  @override
  String get profileCertificationPendingBody =>
      'Ваша заявка находится на рассмотрении.';

  @override
  String get profileCertificationActive => 'Аккаунт подтверждён';

  @override
  String get profileCertificationActiveBody =>
      'Значок подтверждения отображается рядом с вашим именем.';

  @override
  String get profileSellerCertified => 'Проверенный продавец';

  @override
  String profileSellerCertifiedUntil(String date) {
    return 'Значок продавца действует до $date.';
  }

  @override
  String get verifPlanLabel => 'Выберите тариф';

  @override
  String get callEventAudio => 'Аудиозвонок';

  @override
  String get callEventVideo => 'Видеозвонок';

  @override
  String get callEventGroup => 'Групповой звонок';

  @override
  String get callEventMissed => 'Пропущенный звонок';

  @override
  String get callEventNoAnswer => 'Без ответа';

  @override
  String get callEventDeclined => 'Отклонён';

  @override
  String get callEventYouDeclined => 'Вы отклонили';

  @override
  String get callEventEnded => 'Завершён';

  @override
  String callEventSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count с',
      one: '$count с',
    );
    return '$_temp0';
  }

  @override
  String callEventMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мин',
      one: '$count мин',
    );
    return '$_temp0';
  }

  @override
  String callEventHours(Object hours, Object minutes) {
    return '$hours ч $minutes';
  }

  @override
  String callEventParticipants(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get mediaCall => 'Звонок';

  @override
  String get mediaSticker => 'Стикер';

  @override
  String get identityVerifiedAccount => 'Подтверждённый аккаунт';

  @override
  String get privacyTitle => 'Конфиденциальность';

  @override
  String get privacyIntro =>
      'Эти настройки применяет сервер: скрытое вами не отправляется другим, а не просто прячется в приложении.';

  @override
  String get privacySectionWhoSees => 'Кто видит мои данные';

  @override
  String get privacySectionMessages => 'Сообщения';

  @override
  String get privacySectionGroups => 'Группы';

  @override
  String get privacyLastSeen => 'Был(а) в сети';

  @override
  String get privacyLastSeenBody => 'Когда вы были подключены в последний раз.';

  @override
  String get privacyOnline => 'Присутствие в сети';

  @override
  String get privacyOnlineBody =>
      'Зелёная точка: вы доступны сейчас. Не связано с «был(а) в сети».';

  @override
  String get privacyProfilePhoto => 'Фото профиля';

  @override
  String get privacyProfilePhotoBody => 'Ваше фото везде, где оно появляется.';

  @override
  String get privacyProfileInfo => 'Сведения профиля';

  @override
  String get privacyProfileInfoBody =>
      'Ваше описание и то, что вы о себе указали.';

  @override
  String get privacyReadReceipts => 'Отчёты о прочтении';

  @override
  String get privacyReadReceiptsBody =>
      'Отключив их, вы не увидите и чужие. Отметки о доставке останутся.';

  @override
  String get privacyGroupInvites => 'Кто может пригласить меня в группу';

  @override
  String get privacyGroupInvitesBody =>
      'Разрешить — не значит принять: последнее слово остаётся за вами.';

  @override
  String get privacyGroupMembership => 'Видимость моего участия в группах';

  @override
  String get privacyGroupMembershipBody =>
      'Кто видит, в каких вы группах. Участники группы по-прежнему знают друг друга.';

  @override
  String get privacyEveryone => 'Все';

  @override
  String get privacyMyContacts => 'Мои контакты';

  @override
  String get privacyNobody => 'Никто';

  @override
  String get privacySaveFailed =>
      'Настройка не сохранена — попробуйте ещё раз.';

  @override
  String get privacyUnavailable => 'Настройки конфиденциальности недоступны.';

  @override
  String get privacyStatusesNote =>
      'Конфиденциальность статусов настраивается во вкладке «Новости», там же можно исключить отдельных людей.';

  @override
  String groupInvitesSent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправлено приглашений: $count',
      one: 'Приглашение отправлено',
      zero: 'Приглашения не отправлены',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationTitle => 'Приглашение в группу';

  @override
  String groupInvitationFrom(Object name) {
    return '$name приглашает вас';
  }

  @override
  String groupInvitationMembers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationAccept => 'Вступить';

  @override
  String get groupInvitationReject => 'Отклонить';

  @override
  String groupInvitationExpires(Object hours) {
    return 'Истекает через $hours ч';
  }

  @override
  String get groupInvitationExpiresSoon => 'Скоро истекает';

  @override
  String groupInvitationsHeader(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count приглашений',
      few: '$count приглашения',
      one: '$count приглашение',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationFailed =>
      'Не удалось — приглашение могло стать недействительным.';

  @override
  String get mediaStatePreparing => 'Подготовка…';

  @override
  String get mediaStateSending => 'Отправка…';

  @override
  String mediaStateSendingPercent(Object percent) {
    return 'Отправка · $percent %';
  }

  @override
  String get mediaStateWaitingNetwork => 'Ожидание соединения';

  @override
  String get mediaStateFailed => 'Не удалось отправить';

  @override
  String get mediaStateFileGone => 'Файла больше нет на устройстве';

  @override
  String get channelPrivateLabel => 'Закрытый канал';

  @override
  String get channelPrivateBody =>
      'Не находится через поиск. Присоединиться и читать публикации могут только те, кому вы дали ссылку. Это нельзя изменить позже.';

  @override
  String get channelPrivateBadge => 'Закрытый';

  @override
  String get mahizuConnectTitle => 'Подключите аккаунт Mahizu';

  @override
  String mahizuConnectBody(String phone) {
    return 'Ассистент — это сервис Mahizu, отдельный от Pokou. Чтобы им пользоваться, привяжите аккаунт Mahizu: код будет отправлен на номер $phone.';
  }

  @override
  String get mahizuSendCode => 'Получить код';

  @override
  String get mahizuCodeLabel => 'Полученный код';

  @override
  String get mahizuPinLabel => 'PIN-код аккаунта Mahizu';

  @override
  String get mahizuConfirm => 'Подключить';

  @override
  String get mahizuRestart => 'Начать заново';

  @override
  String get navHome => 'Главная';

  @override
  String get navKory => 'Kory';

  @override
  String get navMore => 'Ещё';

  @override
  String homeGreeting(String name) {
    return 'Здравствуйте, $name';
  }

  @override
  String get homeSeeAll => 'Все';

  @override
  String get homeNoChats => 'Пока нет чатов';

  @override
  String get homeKoryEmpty => 'Нет активных сборов';

  @override
  String get homeSearchHint => 'Найти чат';

  @override
  String get moreCertifiedTitle => 'Pokou certifié';

  @override
  String get moreCertifiedBody =>
      'Подтверждённая личность и режим доказательства: скоро.';

  @override
  String get moreSectionServices => 'Сервисы';

  @override
  String get moreSectionSettings => 'Настройки';

  @override
  String get moreAccount => 'Аккаунт и безопасность';

  @override
  String get moreEdit => 'Изменить';

  @override
  String get koryTitle => 'Kory';

  @override
  String get korySubtitle => 'Сборы и тонтины';

  @override
  String get koryMyPots => 'Мои сборы';

  @override
  String get koryMonthTotal => 'Мои подтверждённые взносы за месяц';

  @override
  String get koryNoMoney =>
      'Pokou не касается денег: они идут напрямую с вашего кошелька на кошелёк сборщика.';

  @override
  String get koryCreate => 'Создать сбор';

  @override
  String get koryJoin => 'Присоединиться';

  @override
  String get koryJournalTab => 'Журнал';

  @override
  String get koryJoinTitle => 'Присоединиться по коду';

  @override
  String get koryJoinHint => 'Код сбора';

  @override
  String get koryJoinUnknown => 'Неизвестный код или сбор закрыт.';

  @override
  String get koryNone => 'Нет активных сборов';

  @override
  String get koryNoneBody =>
      'Создайте сбор на свадьбу, крестины или регулярный взнос либо присоединитесь к сбору по коду.';

  @override
  String get koryUnavailable => 'Kory недоступен';

  @override
  String get koryKindCagnotte => 'Сбор';

  @override
  String get koryKindCotisation => 'Взнос';

  @override
  String get koryTotalConfirmed => 'Подтверждено всего';

  @override
  String koryGoal(String amount) {
    return 'Цель: $amount';
  }

  @override
  String koryDue(String date) {
    return 'Срок: $date';
  }

  @override
  String koryMyShare(String amount) {
    return 'Моя подтверждённая доля: $amount';
  }

  @override
  String koryToReview(String count) {
    return 'Ждут подтверждения: $count';
  }

  @override
  String get koryClosed => 'Закрыт';

  @override
  String get koryOpen => 'Открыт';

  @override
  String koryCollector(String name) {
    return 'Сборщик: $name';
  }

  @override
  String koryPayTo(String phone) {
    return 'Отправьте взнос со своего кошелька на номер $phone, затем отметьте его здесь.';
  }

  @override
  String koryPerMember(String amount, String period) {
    return '$amount с участника, $period';
  }

  @override
  String get koryDeclare => 'Я внёс';

  @override
  String get koryDeclareTitle => 'Отметить взнос';

  @override
  String get koryAmount => 'Сумма (FCFA)';

  @override
  String get koryWalletRef => 'Номер транзакции (необязательно)';

  @override
  String get koryWalletRefHelp =>
      'Он указан в SMS оператора. Его видите только вы и сборщик.';

  @override
  String get koryNote => 'Сообщение (необязательно)';

  @override
  String get koryPeriodLabel => 'Период (напр. 2026-11)';

  @override
  String get koryJournal => 'Журнал взносов';

  @override
  String get koryJournalEmpty => 'Пока нет отмеченных взносов.';

  @override
  String get koryStatusDeclared => 'Ждёт сборщика';

  @override
  String get koryStatusConfirmed => 'Подтверждён';

  @override
  String get koryStatusRejected => 'Оспорен';

  @override
  String get koryConfirm => 'Получено';

  @override
  String get koryReject => 'Не получено';

  @override
  String get koryCloseAction => 'Закрыть';

  @override
  String get koryCloseConfirm =>
      'Закрыть сбор? Больше никто не сможет отметить взнос.';

  @override
  String koryShareCode(String code) {
    return 'Код: $code';
  }

  @override
  String koryShareText(String title, String code) {
    return 'Присоединяйтесь к сбору «$title» в Pokou по коду $code.';
  }

  @override
  String get koryCreateTitle => 'Новый сбор';

  @override
  String get koryFieldTitle => 'Название';

  @override
  String get koryFieldDescription => 'Описание (необязательно)';

  @override
  String get koryFieldGoal => 'Цель в FCFA (необязательно)';

  @override
  String get koryFieldPerMember => 'Сумма с участника (FCFA)';

  @override
  String get koryPeriodMonthly => 'каждый месяц';

  @override
  String get koryPeriodWeekly => 'каждую неделю';

  @override
  String get koryFieldDue => 'Срок (необязательно)';

  @override
  String get koryNeedTitle => 'Укажите название (не менее 3 символов).';

  @override
  String get koryNeedAmount => 'Укажите сумму не менее 100 FCFA.';

  @override
  String get koryCollectorIsYou =>
      'Вы сборщик: взносы приходят на ваш кошелёк, и вы их подтверждаете.';

  @override
  String get koryYou => 'Вы';

  @override
  String get koryTontinePlus => 'Тонтина по очереди: скоро в Kory Plus';

  @override
  String get koryDeclared => 'Взнос отмечен. Сборщик его подтвердит.';

  @override
  String get koryCopyPhone => 'Скопировать номер';

  @override
  String get koryCopied => 'Скопировано';

  @override
  String get koryActionFailed => 'Не удалось. Попробуйте ещё раз.';

  @override
  String get welcomePromise => 'Больше, чем мессенджер, — сообщество.';

  @override
  String get welcomeSignature => 'Вместе мы сильнее.';

  @override
  String get welcomeServiceChats => 'Чаты, группы и звонки';

  @override
  String get welcomeServiceKory => 'Сборы и тонтины';

  @override
  String get legalPrivacy => 'Конфиденциальность';

  @override
  String get legalTerms => 'Условия использования';

  @override
  String get legalUnavailable => 'Документ пока недоступен.';

  @override
  String onbStep(String step) {
    return 'Шаг $step из 3';
  }

  @override
  String get onbProfileTitle => 'Ваш профиль';

  @override
  String get onbProfileBody => 'Это имя увидят ваши контакты.';

  @override
  String get onbDisplayName => 'Отображаемое имя';

  @override
  String get onbNameRequired => 'Укажите имя (не менее 2 символов).';

  @override
  String get onbPhotoLater => 'Фото можно добавить позже в профиле.';

  @override
  String get onbContinue => 'Продолжить';

  @override
  String get onbTermsTitle => 'Перед началом';

  @override
  String get onbAcceptTerms =>
      'Я прочитал(а) и принимаю условия использования и политику конфиденциальности.';

  @override
  String get onbAge => 'Я достиг(ла) возраста, необходимого для Pokou.';

  @override
  String get onbOptional => 'Необязательно, можно изменить в настройках';

  @override
  String get onbAnalytics =>
      'Делиться статистикой использования, чтобы улучшать Pokou';

  @override
  String get onbMarketing => 'Получать новости и предложения Pokou';

  @override
  String get onbFinish => 'Готово';

  @override
  String get onbFailed => 'Не удалось сохранить. Попробуйте ещё раз.';

  @override
  String get moreConsents => 'Статистика и рассылки';

  @override
  String get navHonam => 'Honam';

  @override
  String get honamSubtitle => 'Аптеки и доставка';

  @override
  String get honamIntro =>
      'Ближайшая аптека пришлёт вам смету. Оплатите её из кошелька, и курьер доставит заказ.';

  @override
  String get honamSend => 'Отправить рецепт';

  @override
  String get honamPhotograph => 'Сфотографировать рецепт';

  @override
  String get honamFromGallery => 'Выбрать фото';

  @override
  String get honamUrgent => 'Экстренный вызов';

  @override
  String get honamNotEmergency => 'Pokou не является экстренной службой.';

  @override
  String get honamNearby => 'Аптеки рядом';

  @override
  String get honamOnDuty => 'Дежурная';

  @override
  String get honamNoPharmacy => 'Пока нет аптек-партнёров.';

  @override
  String get honamCurrentOrder => 'Текущий заказ';

  @override
  String get honamMyOrders => 'Мои заказы';

  @override
  String get honamChoosePharmacy => 'Выберите аптеку';

  @override
  String get honamAddress => 'Адрес доставки';

  @override
  String get honamNote => 'Комментарий для фармацевта (необязательно)';

  @override
  String get honamSubmit => 'Отправить в аптеку';

  @override
  String get honamNeedPhoto => 'Добавьте фото рецепта.';

  @override
  String get honamNeedAddress => 'Укажите адрес доставки.';

  @override
  String get honamFailed => 'Не удалось. Попробуйте ещё раз.';

  @override
  String honamOrderTitle(String id) {
    return 'Заказ № $id';
  }

  @override
  String get honamStSubmitted => 'Отправлен, ждёт фармацевта';

  @override
  String get honamStQuoted => 'Получена смета';

  @override
  String get honamStAccepted => 'Смета принята, к оплате';

  @override
  String get honamStPaid => 'Оплачен, готовится';

  @override
  String get honamStReady => 'Готов, ждёт курьера';

  @override
  String get honamStInDelivery => 'В пути';

  @override
  String get honamStDelivered => 'Доставлен';

  @override
  String get honamStRejected => 'Рецепт отклонён';

  @override
  String get honamStExpired => 'Смета истекла';

  @override
  String get honamStCancelled => 'Отменён';

  @override
  String get honamQuote => 'Смета';

  @override
  String get honamUnavailableItem => 'Нет в наличии';

  @override
  String get honamMedicines => 'Лекарства';

  @override
  String get honamDelivery => 'Доставка';

  @override
  String get honamTotal => 'Итого к оплате';

  @override
  String get honamAcceptQuote => 'Принять смету';

  @override
  String honamPayTo(String amount, String phone) {
    return 'Отправьте $amount со своего кошелька на $phone (аптека), затем подтвердите.';
  }

  @override
  String get honamDeclarePaid => 'Я оплатил(а) аптеке';

  @override
  String get honamPaidDeclared => 'Оплата отмечена: аптека подтвердит её.';

  @override
  String get honamPaymentNotReceived =>
      'Аптека не получила оплату. Проверьте номер и сумму.';

  @override
  String get honamCode => 'Код получения';

  @override
  String get honamCodeHelp =>
      'Назовите код курьеру только когда посылка у вас в руках.';

  @override
  String get honamOriginal => 'Курьер заберёт оригинал рецепта.';

  @override
  String honamRefundDue(String amount, String reason) {
    return 'Аптека должна вам $amount: $reason';
  }

  @override
  String get honamRefundReceived => 'Я получил(а) возврат';

  @override
  String get honamCancel => 'Отменить заказ';

  @override
  String get honamResend => 'Отправить в другую аптеку';

  @override
  String honamReason(String reason) {
    return 'Причина: $reason';
  }

  @override
  String get honamTimeline => 'Отслеживание';

  @override
  String get honamOrderMessages => 'Сообщения о заказе';

  @override
  String get honamWriteMessage => 'Написать сообщение';

  @override
  String get honamCourierMode => 'Режим курьера';

  @override
  String get honamCourierJoin => 'Стать курьером Win Pokou';

  @override
  String get honamCourierJoinBody =>
      '5 пробных доставок без комиссии на месяц. Затем — членство Win Pokou и предоплаченный пакет.';

  @override
  String honamRidesLeft(String count) {
    return 'Осталось доставок: $count';
  }

  @override
  String get honamUnlimited => 'Безлимитные доставки';

  @override
  String honamMembership(String amount) {
    return 'Членство Win Pokou: $amount без НДС / мес';
  }

  @override
  String get honamPayMembership => 'Оплатить членство';

  @override
  String get honamPacks => 'Пакеты доставок';

  @override
  String honamPackPrice(String amount) {
    return '$amount без НДС';
  }

  @override
  String get honamAvailableRides => 'Доступные доставки';

  @override
  String get honamMyRides => 'Мои доставки';

  @override
  String get honamNoRides => 'Пока нет доставок.';

  @override
  String get honamAcceptRide => 'Принять доставку';

  @override
  String get honamPickup => 'Посылка получена';

  @override
  String get honamDeliver => 'Подтвердить вручение';

  @override
  String get honamEnterCode => 'Код от пациента';

  @override
  String get honamCoursePaid => 'Я получил(а) оплату доставки';

  @override
  String get honamPaymentLinkOpened =>
      'Завершите оплату на открывшейся странице.';

  @override
  String get honamCourierSuspended =>
      'Аккаунт курьера приостановлен после 3 срывов доставки. Обратитесь в поддержку.';

  @override
  String get honamPriceNote => 'Цены без НДС; НДС страны добавляется.';

  @override
  String get certTitle => 'Pokou certifié';

  @override
  String get certPitch =>
      'Значок подтверждает, что имя действительно ваше. Режим доказательства оставляет удалённые сообщения группы видимыми, зачёркнутыми.';

  @override
  String get certHowItWorks =>
      'Личность подтверждается именем владельца кошелька, с которого идёт оплата.';

  @override
  String certStartTrial(String days) {
    return 'Попробовать $days дн.';
  }

  @override
  String get certTrialNote =>
      'Во время пробного периода доступен режим доказательства; значок появится после первой оплаты.';

  @override
  String certPlanPrice(String ht, String ttc) {
    return '$ht без НДС · $ttc с НДС';
  }

  @override
  String get certSubscribe => 'Выбрать';

  @override
  String get certActive => 'Значок активен';

  @override
  String certTrialUntil(String date) {
    return 'Пробный период до $date';
  }

  @override
  String certActiveUntil(String date) {
    return 'Активен до $date';
  }

  @override
  String get certExpired => 'Подписка истекла';

  @override
  String get certMismatchTitle => 'Имена не совпадают';

  @override
  String get certMismatchBody =>
      'Введённое имя не совпадает с именем владельца кошелька, с которого оплачено. Исправьте его как в документе.';

  @override
  String get proofModeTitle => 'Режим доказательства';

  @override
  String get proofModeOnBanner =>
      'Режим доказательства включён: удалённое сообщение остаётся видимым, зачёркнутым, для всех.';

  @override
  String get proofModeEnable => 'Включить режим доказательства';

  @override
  String get proofModeDisable => 'Выключить режим доказательства';

  @override
  String get proofModeNeedsCert =>
      'Режиму доказательства нужен Pokou certifié (есть бесплатный пробный период).';

  @override
  String get deleteForAll => 'Удалить у всех';

  @override
  String get deleteProofWarning =>
      'Включён режим доказательства: сообщение останется видимым, зачёркнутым, для всех участников.';

  @override
  String get deletedKept =>
      'Удалённое сообщение, сохранено режимом доказательства';

  @override
  String get certCorrectName => 'Полное имя владельца';

  @override
  String get certRetryName => 'Проверить имя';

  @override
  String get certStillMismatch => 'Имя по-прежнему не совпадает.';

  @override
  String get proofExport => 'Экспортировать чат (PDF)';

  @override
  String proofModeOn(String name) {
    return '$name включил(а) режим доказательства';
  }

  @override
  String proofModeOff(String name) {
    return '$name выключил(а) режим доказательства';
  }

  @override
  String proofOriginal(String text) {
    return 'Исходная версия: $text';
  }

  @override
  String get proofDisableReserved =>
      'Выключить может только тот, кто включил, или администратор с оплаченным значком.';

  @override
  String get marketBoost3 => '3 дня · 600 FCFA';

  @override
  String get marketBoost7 => '7 дней · 1 300 FCFA';

  @override
  String get marketUseHonam =>
      'Лекарства не продаются в Assimé: используйте Honam.';

  @override
  String get honamMissingTitle => 'Не хватает товара';

  @override
  String honamMissingBody(String amount, String reason) {
    return 'Не хватает на $amount: $reason. Что выберете?';
  }

  @override
  String get honamKeepRest => 'Получить остальное';

  @override
  String get honamCancelAll => 'Отменить всё';

  @override
  String get honamRefundDelay =>
      'Аптека вернёт деньги в течение 2 часов на номер, с которого платили.';

  @override
  String get honamZones => 'Районы и время (напр. Бе, Токоин — вечер)';

  @override
  String get honamWallet => 'Номер кошелька для оплаты доставок';

  @override
  String get honamRules =>
      'Принимаю золотые правила: отдаю посылку только по коду, не смотрю рецепты, вежлив(а).';

  @override
  String get honamApply => 'Отправить заявку';

  @override
  String get honamPending => 'Заявка отправлена: команда Pokou её проверяет.';

  @override
  String get honamLaunch => 'Период запуска: доставки без членства и пакета.';

  @override
  String get honamQueenLocked =>
      'Queen Pokou открывается после месяца без срывов доставки.';

  @override
  String koryDeclaredTotal(String amount) {
    return 'Заявлено всего: $amount';
  }

  @override
  String koryRemaining(String amount) {
    return 'Осталось собрать: $amount';
  }

  @override
  String get onbBabaWelcome => 'Я Baba, ассистент Pokou. Как к вам обращаться?';

  @override
  String get onbContactsTitle => 'Найти близких';

  @override
  String get onbContactsBody =>
      'Baba может найти ваших контактов, которые уже в Pokou. Можно отказаться — спросим позже.';

  @override
  String get onbContactsAllow => 'Разрешить';

  @override
  String get onbLater => 'Позже';

  @override
  String get proofModeDirectHint =>
      'Всё написанное остаётся доказуемым: удалённое сообщение остаётся зачёркнутым, правка сохраняет оригинал. Отключить сможете только вы.';

  @override
  String get proofDisableReservedDirect =>
      'Отключить режим доказательства может только тот, кто его включил.';

  @override
  String get proofExportMe => 'Я';

  @override
  String get proofExportTitle => 'Pokou — экспорт режима доказательства';

  @override
  String proofExportBetween(String me, String contact) {
    return 'Переписка между $me и $contact';
  }

  @override
  String proofExportPeriod(String since, String now) {
    return 'Режим доказательства включён с $since · экспортировано $now с этого телефона';
  }

  @override
  String proofExportFooter(String page, String pages) {
    return 'Страница $page из $pages — создано на устройстве: сервер Pokou не имеет доступа к зашифрованным сообщениям.';
  }

  @override
  String get proofExportAttachment => '[вложение]';

  @override
  String proofExportEdited(String at) {
    return 'Изменено $at';
  }

  @override
  String proofExportDeleted(String at) {
    return 'Удалено $at, сохранено режимом доказательства';
  }

  @override
  String get proTitle => 'Pokou certified Pro';

  @override
  String get proTeaser => 'Для бизнеса: торговое название и «Управляет»';

  @override
  String get proPitch =>
      'Ваше торговое название показывается первым, с пометкой «Управляет» и вашим подтверждённым именем. В профиле Pro будут ваши объявления Assimé.';

  @override
  String proSteps(String hours) {
    return '1. Вы отправляете документ. 2. Поддержка проверяет его в течение $hours ч. 3. Оплата только после одобрения.';
  }

  @override
  String proPending(String due) {
    return 'Идёт проверка. Ответ не позднее $due.';
  }

  @override
  String get proApproved =>
      'Документ одобрен: можно подключить Pokou certified Pro.';

  @override
  String get proPay => 'Оплатить Pokou certified Pro';

  @override
  String get proCorrection => 'Документ нужно исправить';

  @override
  String get proRejected => 'Заявка отклонена';

  @override
  String get proActivity => 'Ваша деятельность';

  @override
  String get proBusinessName => 'Торговое название';

  @override
  String get proActivityField =>
      'Вид деятельности (пошив, магазин, перевозки…)';

  @override
  String get proDocument => 'Добавить документ';

  @override
  String get proDocumentChosen => 'Документ добавлен — нажмите, чтобы заменить';

  @override
  String get proDocumentNote =>
      'Выписка из реестра, профессиональная карта или патент. Видит только поддержка, нигде не показывается.';

  @override
  String get proSend => 'Отправить на проверку';

  @override
  String proManagedBy(String name) {
    return 'Управляет: $name';
  }

  @override
  String get proProfileNote => 'Так другие видят ваш профиль Pro.';

  @override
  String get honamCity => 'Город';

  @override
  String get honamOtherCity => 'Другой город';

  @override
  String get honamYourCity => 'Ваш город';

  @override
  String get honamNotServed =>
      'Honam пока не доставляет в этот город. Запишитесь — мы сообщим об открытии.';

  @override
  String get honamJoinWaitlist => 'Записаться в лист ожидания';

  @override
  String honamWaitlistDone(String city) {
    return 'Вы в списке: $city';
  }

  @override
  String get honamWaitlistBody =>
      'Мы сообщим, как только Honam начнёт доставку в вашем городе. И всё.';

  @override
  String get honamReferralCodeField => 'Код приглашения (необязательно)';

  @override
  String get honamReferralTitle => 'Пригласите курьера';

  @override
  String honamReferralBody(String rides) {
    return '$rides бесплатных поездки после первой доставки приглашённого.';
  }

  @override
  String get honamReferralShare => 'Поделиться кодом';

  @override
  String honamReferralMessage(String code) {
    return 'Доставляйте для Honam с Pokou: введите мой код $code в режиме курьера.';
  }

  @override
  String honamReferralCount(String count) {
    return 'Приглашено: $count';
  }

  @override
  String get honamTrialEnded => 'Пробный период закончился';

  @override
  String honamRecommendedPack(String pack) {
    return 'По вашим поездкам за месяц вам хватит пакета $pack.';
  }

  @override
  String get honamNavigate => 'Маршрут в моём приложении карт';

  @override
  String get honamLocationShared =>
      'Ваше местоположение передаётся каждые 15 с во время поездки и никогда после.';

  @override
  String get honamLocationDenied =>
      'Разрешите геолокацию, чтобы пациент видел доставку.';

  @override
  String get honamCourier => 'курьер';

  @override
  String honamTrackingTitle(String name) {
    return '$name в пути';
  }

  @override
  String get honamTrackingWaiting => 'Местоположение ещё не получено.';

  @override
  String honamTrackingDistance(String km) {
    return 'В $km км от вас';
  }

  @override
  String honamTrackingUpdated(String minutes) {
    return 'Обновлено $minutes мин назад';
  }

  @override
  String get honamTrackingStale => 'Местоположение устарело';

  @override
  String get honamTrackingShowMap => 'Показать на карте';

  @override
  String get honamTrackingMapDataSaver =>
      'Показать на карте (расходует трафик)';

  @override
  String get assimeFavoritesAlerts => 'Избранное и оповещения';

  @override
  String get assimeFavorites => 'Избранное';

  @override
  String get assimeAlerts => 'Оповещения';

  @override
  String get assimeNoFavorites => 'Нет избранного';

  @override
  String get assimeFavoritesHint =>
      'Нажмите на сердечко объявления, чтобы сохранить его здесь.';

  @override
  String get assimeAddFavorite => 'В избранное';

  @override
  String get assimeRemoveFavorite => 'Убрать из избранного';

  @override
  String get assimeNewAlert => 'Новое оповещение';

  @override
  String get assimeAlertQuery => 'Что вы ищете';

  @override
  String get assimeAlertMaxPrice => 'Максимальная цена (необязательно)';

  @override
  String get assimeAlertNote =>
      'Мы сообщим, когда появится подходящее объявление. Оповещение читает только объявления, не ваши сообщения.';

  @override
  String get assimeNoAlerts => 'Оповещений пока нет.';

  @override
  String assimeAlertUpTo(String price) {
    return 'до $price FCFA';
  }

  @override
  String assimeAlertMatches(String count) {
    return 'Найдено объявлений: $count';
  }

  @override
  String get assimeSponsored => 'Реклама';

  @override
  String get assimeWhyTitle => 'Почему я это вижу';

  @override
  String get assimeWhyNotSponsored => 'Это объявление больше не продвигается.';

  @override
  String get assimeReportTitle => 'Итоги продвижения';

  @override
  String get assimeReportEmpty => 'Это объявление ещё не продвигалось.';

  @override
  String assimeReportPeriod(String days, String start, String end) {
    return '$days дн. · с $start по $end';
  }

  @override
  String assimeReportImpressions(String count) {
    return 'Показано вверху результатов: $count раз';
  }

  @override
  String assimeReportStatusViews(String count) {
    return 'Просмотрено в статусах: $count раз';
  }

  @override
  String assimeReportContacts(String count) {
    return 'Связались с вами: $count';
  }

  @override
  String get assimeStatusPending => 'Место в статусах: на проверке модерацией';

  @override
  String get assimeStatusRejected => 'Место в статусах отклонено модерацией';

  @override
  String get koryKindTontine => 'Тонтина';

  @override
  String get koryFieldStake => 'Взнос каждого за круг (FCFA)';

  @override
  String get koryRotation => 'Порядок кругов';

  @override
  String get koryRotationHint =>
      'Перетащите для упорядочивания. Порядок фиксируется при открытии и больше не меняется.';

  @override
  String get koryRemoveFromRotation => 'Убрать из тонтины';

  @override
  String get koryNeedRotation => 'Для тонтины нужно минимум два участника.';

  @override
  String get koryTontineNote =>
      'Каждый круг все отправляют взнос на кошелёк получателя, который подтверждает полученное. Pokou никогда не касается денег.';

  @override
  String get koryRounds => 'Круги';

  @override
  String koryRoundNumber(String number) {
    return 'Круг $number';
  }

  @override
  String koryRoundConfirmed(String confirmed, String expected) {
    return 'Подтверждено $confirmed из $expected';
  }

  @override
  String get koryNextRound => 'Следующий круг';

  @override
  String get koryNextRoundBody =>
      'Текущий круг завершается. Уже заявленные взносы подтвердит его получатель.';

  @override
  String get koryLastRoundBody =>
      'Это был последний круг: тонтина будет закрыта. Журнал останется доступен.';

  @override
  String get welcomeStart => 'Начать';

  @override
  String get authAcceptAndContinue => 'Принять и продолжить';

  @override
  String get authAcceptNotice =>
      'Нажимая «Принять и продолжить», вы принимаете условия использования и политику конфиденциальности и подтверждаете, что достигли нужного возраста.';

  @override
  String get deleteAccountTitle => 'Удалить мой аккаунт';

  @override
  String get deleteAccountWarning => 'Это действие необратимо.';

  @override
  String get deleteAccountRemovedTitle => 'Что будет удалено';

  @override
  String get deleteAccountRemovedProfile =>
      'Твой профиль, фото и резервная копия';

  @override
  String get deleteAccountRemovedChats => 'Твои чаты на этом телефоне';

  @override
  String get deleteAccountRemovedBadge =>
      'Твой значок, без возврата за текущий месяц';

  @override
  String get deleteAccountKeptTitle => 'Что останется';

  @override
  String get deleteAccountKeptMessages =>
      'Сообщения, уже полученные твоими контактами';

  @override
  String get deleteAccountKeptProof =>
      'Записи режима доказательства у других участников';

  @override
  String get deleteAccountKeptKory =>
      'Журнал копилок Kory, который не удаляется';

  @override
  String get deleteAccountConfirmLabel => 'Подтверди свой номер';

  @override
  String get deleteAccountMismatch =>
      'Этот номер не совпадает с твоим аккаунтом.';

  @override
  String get deleteAccountFailed => 'Не удалось удалить. Попробуй ещё раз.';

  @override
  String get helpTitle => 'Помощь и поддержка';

  @override
  String get helpSearchHint => 'Поиск в справке';

  @override
  String get helpAskBaba => 'Спросить Бабу';

  @override
  String get helpAskBabaSub => 'ИИ-помощник отвечает сразу';

  @override
  String get helpFaqTitle => 'Частые вопросы';

  @override
  String get helpQMoney => 'Касается ли Pokou моих денег?';

  @override
  String get helpAMoney =>
      'Нет. Копилки, аптеки и курьеры оплачиваются с кошелька на кошелёк. Pokou никогда не хранит твои деньги.';

  @override
  String get helpQProof => 'Как работает режим доказательства?';

  @override
  String get helpAProof =>
      'Включается владельцем Pokou certifié: удалённые или изменённые сообщения остаются видны, зачёркнутыми. Это всегда указано вверху чата.';

  @override
  String get helpQSms => 'Я не получаю SMS-код';

  @override
  String get helpASms =>
      'Проверь номер и сеть, затем дождись окончания отсчёта, чтобы запросить новый код. Pokou никогда не попросит этот код ни в сообщении, ни по звонку.';

  @override
  String get helpQCourier => 'Как стать курьером Honam?';

  @override
  String get helpACourier =>
      'В разделе «Ещё» нажми «Стать курьером Honam»: личность, зоны, кошелёк и золотые правила. Honam открывается город за городом.';

  @override
  String get helpQScam => 'Как распознать мошенничество?';

  @override
  String get helpAScam =>
      'Остерегайся тех, кто просит SMS-код, PIN или срочный платёж. Pokou так никогда не делает. Заблокируй контакт и пожалуйся.';

  @override
  String get helpSupport => 'Написать в поддержку';

  @override
  String get helpSupportSub => 'Ответ в приложении';

  @override
  String get helpReport => 'Сообщить о проблеме';

  @override
  String get helpNoResult => 'Нет подходящих вопросов. Спроси Бабу.';

  @override
  String get aboutTitle => 'О Pokou';

  @override
  String aboutVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get aboutNamesTitle => 'Смысл наших названий';

  @override
  String get aboutPokou => 'имя на языке бауле';

  @override
  String get aboutKory => 'раковина каури';

  @override
  String get aboutHonam => '«помоги мне» на эве';

  @override
  String get aboutAssime => '«на рынке» на эве';

  @override
  String get aboutWetri => '«месяц» на эве';

  @override
  String get aboutEpe => '«год» на эве';

  @override
  String get aboutNextNames =>
      'Наши следующие сервисы тоже получат названия из африканских языков.';

  @override
  String get aboutLicenses => 'Лицензии свободного ПО';

  @override
  String get legalEssentials => 'Главное';

  @override
  String get legalFullText => 'Полный текст';

  @override
  String get termsE1 =>
      'Pokou никогда не касается денег: копилки, аптеки и курьеры оплачиваются с кошелька на кошелёк.';

  @override
  String get termsE2 =>
      'Режим доказательства сохраняет след удалённых сообщений, и это всегда видно.';

  @override
  String get termsE3 => 'Honam — не служба экстренной помощи.';

  @override
  String get termsE4 => 'Платные значки можно отменить в любой момент.';

  @override
  String get privacyE1 =>
      'Твой номер никогда не показывается продавцу или курьеру.';

  @override
  String get privacyE2 =>
      'Pokou не читает твои сообщения. Жалоба отправляет в поддержку только 5 последних.';

  @override
  String get privacyE3 => 'Местоположение курьера не хранится после доставки.';

  @override
  String get privacyE4 =>
      'Спонсорские объявления таргетируются по городу, никогда по твоим сообщениям.';

  @override
  String get languageNote =>
      'Язык приложения не меняет язык твоих сообщений. Названия Pokou, Kory, Honam и Assimé одинаковы на всех языках.';

  @override
  String get securityPinWarning =>
      'Pokou никогда не попросит твой PIN или SMS-код — ни в сообщении, ни по звонку.';

  @override
  String get statusReplyPrivate =>
      'Твой ответ придёт лично, в ваш чат на двоих.';

  @override
  String get statusViewersNote =>
      'Этот список видишь только ты. Ответы приходят лично, в ваши чаты.';

  @override
  String get statusWhoSees => 'Кто видит мои статусы';

  @override
  String get attachCompressNote =>
      'Фото и видео сжимаются перед отправкой, чтобы экономить трафик.';

  @override
  String get otpTitle => 'Введи код';

  @override
  String get pinForgot => 'Забыл PIN?';

  @override
  String get pinTitle => 'Твой PIN';

  @override
  String statusReplyHint(String name) {
    return 'Ответить $name…';
  }

  @override
  String get statusReplyQuote => '↩ Ответ на твой статус';

  @override
  String get statusReplySent => 'Ответ отправлен лично.';

  @override
  String get changeNumberTitle => 'Сменить номер';

  @override
  String get changeNumberOld => 'Старый номер';

  @override
  String get changeNumberNew => 'Новый номер';

  @override
  String get changeNumberNotify => 'Предупредить контакты';

  @override
  String get changeNumberNotifyAll => 'Все мои контакты';

  @override
  String get changeNumberNotifyChatted => 'Те, с кем я переписывался';

  @override
  String get changeNumberNotifyNone => 'Никого';

  @override
  String get changeNumberNotifyNoneSub => 'Твои группы всегда предупреждаются';

  @override
  String get changeNumberInfo =>
      'Аккаунт, чаты, значок Pokou certifié и копилки Kory переходят с тобой. Код отправляется на новый номер.';

  @override
  String get changeNumberKoryWarning =>
      'Если ты сборщик копилки, номер для сбора не меняется сам: измени его в Kory, участники будут уведомлены.';

  @override
  String get changeNumberSendCode => 'Отправить код';

  @override
  String get changeNumberCodeLabel => 'Код из SMS';

  @override
  String get changeNumberConfirm => 'Подтвердить смену';

  @override
  String get changeNumberDone => 'Твой номер изменён.';

  @override
  String get pinForgotIntro => 'Два способа вернуть аккаунт:';

  @override
  String get pinForgotEmail => 'По e-mail';

  @override
  String get pinForgotEmailSub =>
      'Если ты добавил адрес: тебе придёт ссылка для сброса';

  @override
  String get pinForgotWait => 'Подождать 7 дней';

  @override
  String get pinForgotWaitSub =>
      'Затем входишь без PIN по SMS-коду, если сохранишь номер';

  @override
  String get pinForgotWarning =>
      '7-дневная задержка не даёт укравшему SIM-карту сразу захватить аккаунт.';

  @override
  String get pinForgotMeanwhile =>
      'Пока ждёшь, контакты видят тебя, а сообщения ждут.';

  @override
  String get pinForgotContinue => 'Продолжить';

  @override
  String pinForgotScheduled(String date) {
    return 'Принято. С $date для входа хватит SMS-кода.';
  }

  @override
  String get groupDelete => 'Удалить группу';

  @override
  String groupDeleteTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get groupDeleteBody =>
      'Группа исчезнет у всех участников вместе с сообщениями. Это необратимо.';

  @override
  String get groupDeleteFailed => 'Не удалось удалить — попробуй ещё раз.';

  @override
  String get groupManageTitle => 'Управление группой';

  @override
  String get groupManageSubtitle =>
      'Права, новые участники, исчезающие сообщения';

  @override
  String get groupPermissions => 'Права';

  @override
  String get groupEditInfoSetting => 'Изменять название и фото';

  @override
  String get groupSendSetting => 'Отправлять сообщения';

  @override
  String get groupApproveSetting => 'Одобрять новых участников';

  @override
  String get groupApproveSettingSub =>
      'Администратор одобряет каждый вход по ссылке';

  @override
  String get groupAllMembers => 'Все участники';

  @override
  String get groupDisappearing => 'Исчезающие сообщения';

  @override
  String get groupDisappearingOff => 'Выключены';

  @override
  String get groupDisappearing24h => '24 часа';

  @override
  String get groupDisappearing7d => '7 дней';

  @override
  String get groupDisappearing90d => '90 дней';

  @override
  String get groupJoinRequests => 'Заявки на вступление';

  @override
  String get groupNoJoinRequest => 'Нет ожидающих заявок.';

  @override
  String get groupApprove => 'Принять';

  @override
  String get groupReject => 'Отклонить';

  @override
  String get groupJoinPending =>
      'Заявка отправлена: администратор должен одобрить вход.';

  @override
  String get groupSettingsSaveFailed =>
      'Настройка не сохранена — попробуй снова.';

  @override
  String get groupLeaveKoryNote =>
      'Выход из группы не удаляет текущую копилку: твои взносы остаются в журнале Kory.';

  @override
  String get messageWaiting => 'Ожидание сообщения…';

  @override
  String get callWaitingNotice =>
      'Ты уже в звонке. Отклони, чтобы продолжить; прими, чтобы завершить его.';

  @override
  String get callEndAndAccept => 'Завершить и принять';

  @override
  String get homeHelloOverline => 'Здравствуй';

  @override
  String get koryOverline => 'Солидарные сбережения';

  @override
  String koryActiveCount(String count) {
    return 'активных: $count';
  }

  @override
  String get searchIntro => 'Ищи в сообщениях, каналах и объявлениях Assimé.';

  @override
  String get searchRecent => 'Недавние запросы';

  @override
  String get homeTagline => 'Всё важное — в одном месте.';

  @override
  String get homeWhatToDo => 'Что ты хочешь сделать?';

  @override
  String get homeInProgress => 'В процессе';

  @override
  String get homeKoryPitch =>
      'Собирайте деньги вместе на проект, событие или тонтину.';

  @override
  String get homeHonamPitch =>
      'Отправь рецепт и получи предложения ближайших аптек.';

  @override
  String get homeAssimeTitle => 'Assimé';

  @override
  String get homeAssimeSubtitle => 'Объявления';

  @override
  String get homeAssimePitch =>
      'Покупай и продавай рядом с домом — с доверием.';

  @override
  String get homeAssimeCta => 'Смотреть объявления';

  @override
  String get koryPledgeTitle => 'Я обязуюсь';

  @override
  String koryPledgeSubtitleDue(Object date, Object title) {
    return '$title · закрытие $date';
  }

  @override
  String get koryPledgeStart => 'Начальная сумма';

  @override
  String get koryPledgeDailyToggle => 'Добавлять сумму каждый день';

  @override
  String get koryPledgeDailyToggleSub =>
      'Добавляется к обязательству каждый день до закрытия';

  @override
  String get koryPledgePerDay => 'Сумма в день';

  @override
  String get koryPledgeStartRow => 'Начало';

  @override
  String koryPledgeDailyRow(Object amount, Object days) {
    return '$amount × $days дн.';
  }

  @override
  String koryPledgeTotalAt(Object date) {
    return 'Всего обещано к $date';
  }

  @override
  String get koryPledgeEditableNotice =>
      'Обязательство можно изменить в течение 8 часов. Затем оно становится твёрдым: попадает в журнал и его видит сборщик.';

  @override
  String get koryPledgeConfirm => 'Подтвердить обязательство';

  @override
  String get koryPledgeNeedDue => 'Для ежедневной суммы нужна дата окончания.';

  @override
  String get koryMyPledgeTitle => 'Моё обязательство';

  @override
  String koryEditableFor(Object duration) {
    return 'Можно изменить ещё $duration';
  }

  @override
  String koryFirmToday(Object time) {
    return 'Станет твёрдым сегодня в $time';
  }

  @override
  String koryFirmOn(Object date, Object time) {
    return 'Станет твёрдым $date в $time';
  }

  @override
  String get koryDailyRow => 'Ежедневная сумма';

  @override
  String koryPerDay(Object amount) {
    return '$amount в день';
  }

  @override
  String get koryPledgeEdit => 'Изменить обязательство';

  @override
  String get koryTimelineSaved => 'Обязательство сохранено';

  @override
  String get koryTimelineEditable => 'Можно изменить в течение 8 часов';

  @override
  String koryTimelineUntil(Object time) {
    return 'До $time · сборщик его пока не видит';
  }

  @override
  String get koryTimelineFirm => 'Твёрдое обязательство';

  @override
  String get koryTimelineFirmSub => 'В журнале, виден сборщику';

  @override
  String get koryPayNowOrLater =>
      'Можно внести сейчас или дождаться закрытия: Pokou напомнит, сколько осталось.';

  @override
  String get koryPayNow => 'Внести сейчас';

  @override
  String koryFirmSince(Object date) {
    return 'Твёрдое с $date';
  }

  @override
  String get koryPaidConfirmed => 'Внесено и подтверждено';

  @override
  String get koryRemainingToPay => 'Осталось внести';

  @override
  String koryNextDailyAdd(Object amount) {
    return 'Следующее ежедневное добавление: завтра, +$amount';
  }

  @override
  String get koryFirmNotice =>
      'Твёрдое обязательство больше не меняется. Если что-то случилось, напиши сборщику: только он может его отменить, и это записывается в журнал.';

  @override
  String koryPayAmount(Object amount) {
    return 'Внести $amount';
  }

  @override
  String koryWriteTo(Object name) {
    return 'Написать $name';
  }

  @override
  String koryMyPledgeTotal(Object amount) {
    return 'Обещано: $amount';
  }

  @override
  String get koryContestedTitle => 'Оспоренный взнос';

  @override
  String koryContestedHead(Object name) {
    return '$name не обнаружил твой перевод';
  }

  @override
  String koryContestedDeclared(Object amount, Object time) {
    return '$amount заявлено в $time';
  }

  @override
  String koryContestedReason(Object reason) {
    return 'Причина: «$reason»';
  }

  @override
  String get koryCheckReference => 'Проверить номер операции';

  @override
  String get koryAddSmsCapture => 'Добавить снимок SMS';

  @override
  String get koryContestedOperatorNotice =>
      'Если ты отправил на другой номер, вернуть деньги может только оператор: они никогда не проходят через Pokou.';

  @override
  String get koryResubmitted => 'Отправлено сборщику на повторную проверку.';

  @override
  String get koryRejectReasonTitle => 'Почему ты не получил перевод?';

  @override
  String get koryRejectReasonHint =>
      'Напр. Ничего не пришло на кошелёк в это время.';

  @override
  String get koryFinishTitle => 'Конец сбора';

  @override
  String koryFinishSubtitle(Object title) {
    return '$title · вид сборщика';
  }

  @override
  String get koryFinishDueNotice =>
      'Дата окончания наступила: тебе решать — закрыть или продлить.';

  @override
  String get koryEngaged => 'Обещано';

  @override
  String koryParticipantsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участников',
      few: '$count участника',
      one: '1 участник',
    );
    return '$_temp0';
  }

  @override
  String get koryConfirmedLabel => 'Подтверждено';

  @override
  String koryOnGoal(Object amount) {
    return 'из $amount';
  }

  @override
  String get koryToConfirmLabel => 'К подтверждению';

  @override
  String koryDeclarationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заявлений',
      few: '$count заявления',
      one: '1 заявление',
    );
    return '$_temp0';
  }

  @override
  String get koryWhatDoYouDo => 'Что ты сделаешь?';

  @override
  String get koryCloseCollect => 'Закрыть сбор';

  @override
  String get koryCloseCollectSub =>
      'Каждый получит, сколько ему осталось внести, и ссылку на свой кошелёк';

  @override
  String get koryExtend => 'Продлить';

  @override
  String koryExtendSub(Object date) {
    return 'Новая дата окончания: $date · обязательства остаются твёрдыми';
  }

  @override
  String get koryFinishJournalNote =>
      'Участники получат уведомление. Журнал сохранит дату и твой выбор.';

  @override
  String koryCloseAndNotify(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Закрыть и уведомить участников ($count)',
      one: 'Закрыть и уведомить участника',
    );
    return '$_temp0';
  }

  @override
  String koryExtendTo(Object date) {
    return 'Продлить до $date';
  }

  @override
  String get koryFinishCta => 'Закрыть или продлить';

  @override
  String get koryClosedTitle => 'Сбор закрыт';

  @override
  String koryClosedSubtitle(Object title) {
    return '$title · вид участника';
  }

  @override
  String koryClosedBody(Object date, Object name) {
    return '$name закрыл сбор $date. Тебе осталось внести остаток обязательства.';
  }

  @override
  String get koryAlreadyConfirmed => 'Уже подтверждено';

  @override
  String get koryToPay => 'К оплате';

  @override
  String get korySendTo => 'Отправь';

  @override
  String koryReferenceToGive(Object reference) {
    return 'Укажи номер $reference';
  }

  @override
  String get koryCopyReference => 'Скопировать номер';

  @override
  String koryPayFromWallet(Object amount) {
    return 'Внести $amount со своего кошелька';
  }

  @override
  String get koryAlreadySent => 'Я уже отправил';

  @override
  String get notifCenterTitle => 'Уведомления';

  @override
  String get notifReadAll => 'Прочитать все';

  @override
  String get notifToday => 'Сегодня';

  @override
  String get notifYesterday => 'Вчера';

  @override
  String get notifEarlier => 'Ранее';

  @override
  String get notifMessagesElsewhere =>
      'Сообщения здесь не появляются: они остаются в разделе «Чаты».';

  @override
  String get notifEmpty => 'Пока нет уведомлений.';

  @override
  String get notifServiceCertified => 'Pokou certifié';

  @override
  String get notifSettings => 'Настройки уведомлений';

  @override
  String get certPausedTitle => 'Значок приостановлен';

  @override
  String certPausedBody(Object days, Object due, Object since) {
    return 'Платёж от $due не прошёл. Значок скрыт с $since, после $days дней отсрочки.';
  }

  @override
  String get certWhatRemains => 'Что остаётся';

  @override
  String get certRemainsChats => 'Твои чаты и контакты';

  @override
  String get certRemainsTraces =>
      'Записи, уже сохранённые режимом доказательств';

  @override
  String get certWhatPaused => 'Что приостановлено';

  @override
  String get certPausedBadge => 'Значок и проверенное имя';

  @override
  String get certPausedProof =>
      'Режим доказательств для новых сообщений и экспорт с датой';

  @override
  String get certPausedWallet =>
      'Оплата идёт с твоего кошелька. Если не хватило средств, пополни его и попробуй снова.';

  @override
  String certPausedPay(Object amount) {
    return 'Оплатить $amount и вернуть значок';
  }

  @override
  String get certChangePlan => 'Сменить тариф';
}
