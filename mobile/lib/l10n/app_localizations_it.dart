// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class LIt extends L {
  LIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Pokou';

  @override
  String get actionCancel => 'Annulla';

  @override
  String get actionConfirm => 'Conferma';

  @override
  String get actionSave => 'Salva';

  @override
  String get actionDelete => 'Elimina';

  @override
  String get actionRetry => 'Riprova';

  @override
  String get actionContinue => 'Continua';

  @override
  String get actionClose => 'Chiudi';

  @override
  String get actionShare => 'Condividi';

  @override
  String get actionSearch => 'Cerca';

  @override
  String get actionAdd => 'Aggiungi';

  @override
  String get actionRemove => 'Rimuovi';

  @override
  String get actionSend => 'Invia';

  @override
  String get actionJoin => 'Unisciti';

  @override
  String get actionCreate => 'Crea';

  @override
  String get navChats => 'Chat';

  @override
  String get navStatus => 'Aggiornamenti';

  @override
  String get navCalls => 'Chiamate';

  @override
  String get navMarket => 'Mercato';

  @override
  String get chatsEmptyTitle => 'Nessuna chat';

  @override
  String get chatsEmptyBody => 'Le tue conversazioni appariranno qui.';

  @override
  String get chatsSearchHint => 'Cerca';

  @override
  String get chatsTyping => 'sta scrivendo…';

  @override
  String chatsTypingNamed(String name) {
    return '$name sta scrivendo…';
  }

  @override
  String get chatsUnknownContact => 'non è nei tuoi contatti';

  @override
  String get chatsNoMessageYet => 'Ancora nessun messaggio';

  @override
  String chatsYouPrefix(String message) {
    return 'Tu: $message';
  }

  @override
  String chatsGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gruppi',
      one: '1 gruppo',
      zero: 'Nessun gruppo',
    );
    return '$_temp0';
  }

  @override
  String get newChatTitle => 'Nuova chat';

  @override
  String get newChatSearchHint => 'Cerca un contatto';

  @override
  String get newChatNewGroup => 'Nuovo gruppo';

  @override
  String get newChatNewCommunity => 'Nuova comunità';

  @override
  String get newChatJoinByLink => 'Entra con un link';

  @override
  String get newChatOnPokou => 'Su Pokou Messenger';

  @override
  String get newChatInvite => 'Invita su Pokou Messenger';

  @override
  String get newChatNoMatch => 'Nessun contatto corrisponde.';

  @override
  String get newChatNoRegisteredContact =>
      'Nessuno dei tuoi contatti usa ancora Pokou.';

  @override
  String conversationSayHello(String name) {
    return 'Saluta $name.';
  }

  @override
  String get conversationMessageHint => 'Messaggio';

  @override
  String get conversationEdit => 'Modifica';

  @override
  String get conversationForward => 'Inoltra';

  @override
  String get conversationReply => 'Rispondi';

  @override
  String get conversationEditWindowOver =>
      'Questo messaggio non può più essere modificato.';

  @override
  String get mediaPhoto => 'Foto';

  @override
  String get mediaVideo => 'Video';

  @override
  String get mediaVoice => 'Messaggio vocale';

  @override
  String get mediaDocument => 'Documento';

  @override
  String get mediaLocation => 'Posizione';

  @override
  String get offlineTitle => 'Offline';

  @override
  String get offlineBody =>
      'Vedrai ciò che è già su questo dispositivo. Il resto arriverà al ritorno della rete.';

  @override
  String get offlineNothingCached =>
      'Non c\'è ancora nulla salvato su questo dispositivo.';

  @override
  String get offlineSending => 'In attesa di invio';

  @override
  String get errorNetwork => 'Connessione impossibile. Controlla la rete.';

  @override
  String get twoStepTitle => 'Verifica in due passaggi';

  @override
  String get twoStepBody =>
      'Questo account è protetto da un codice. Inseriscilo per completare l\'accesso.';

  @override
  String get twoStepHint => 'Codice dell\'account';

  @override
  String get errorGeneric => 'Qualcosa non ha funzionato.';

  @override
  String get profileTitle => 'Profilo';

  @override
  String get profileLanguage => 'Lingua';

  @override
  String get profileLanguageSystem => 'Lingua del telefono';

  @override
  String get profileLanguageSubtitle => 'Scegli la lingua dell\'applicazione';

  @override
  String get languageFrench => 'Francese';

  @override
  String get languageEnglish => 'Inglese';

  @override
  String get languageSpanish => 'Spagnolo';

  @override
  String get languageRussian => 'Russo';

  @override
  String get languageArabic => 'Arabo';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get sparkTitle => 'Spark';

  @override
  String get sparkSubtitle => 'L\'appuntamento di oggi';

  @override
  String get sparkTabDiscover => 'Scopri';

  @override
  String get sparkTabMatches => 'Match';

  @override
  String get sparkTabDates => 'Uscite';

  @override
  String get sparkTabMe => 'Io';

  @override
  String get sparkAddPhoto => 'Aggiungi una foto';

  @override
  String get sparkNoPhotoWarning =>
      'Aggiungi una foto — senza, quasi nessuno mette like';

  @override
  String sparkPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String get sparkLike => 'Mi piace';

  @override
  String get sparkPass => 'Passa';

  @override
  String get sparkAgeRestricted => 'Spark è riservato ai maggiori di 18 anni.';

  @override
  String get navProfile => 'Profilo';

  @override
  String get authWelcome => 'Benvenuto su Pokou';

  @override
  String get authSubtitle =>
      'Inserisci il tuo numero: ti inviamo un codice. Nuovo su Pokou? Il tuo account si crea in questo passaggio.';

  @override
  String get authPhoneHint => 'Il tuo numero';

  @override
  String get authPrivacyNote =>
      'Accesso sicuro. Il tuo numero serve solo a verificare la tua identità.';

  @override
  String get authVerifyTitle => 'Verifica';

  @override
  String authCodeSentTo(String phone) {
    return 'Inserisci il codice a 6 cifre inviato al $phone';
  }

  @override
  String get authChangeNumber => 'Cambia numero';

  @override
  String authResendIn(String time) {
    return 'Reinvia il codice tra $time';
  }

  @override
  String get authResendSms => 'Reinvia via SMS';

  @override
  String get authResendWhatsapp => 'Reinvia via WhatsApp';

  @override
  String get authCodeSentSms => 'Nuovo codice inviato via SMS.';

  @override
  String get authCodeSentWhatsapp => 'Nuovo codice inviato su WhatsApp.';

  @override
  String get chatsPin => 'Fissa';

  @override
  String get chatsUnpin => 'Rimuovi';

  @override
  String get chatsArchive => 'Archivia';

  @override
  String get chatsUnarchive => 'Rimuovi dall\'archivio';

  @override
  String get chatsMute => 'Silenzia';

  @override
  String get chatsUnmute => 'Riattiva audio';

  @override
  String get chatsTag => 'Etichetta';

  @override
  String chatsTagNamed(String name) {
    return 'Etichetta $name';
  }

  @override
  String get chatsBlock => 'Blocca';

  @override
  String chatsBlockTitle(String name) {
    return 'Bloccare $name?';
  }

  @override
  String get chatsBlockBody =>
      'Questa persona non potrà più scriverti né chiamarti. Non le verrà detto.';

  @override
  String get chatsPinLimit => 'Ci sono già tre chat fissate, il massimo.';

  @override
  String get chatsMute8h => '8 ore';

  @override
  String get chatsMute1w => '1 settimana';

  @override
  String get chatsMuteAlways => 'Sempre';

  @override
  String get chatsAddContact => 'Aggiungi ai contatti';

  @override
  String get chatsActionFailed => 'Operazione non riuscita al momento.';

  @override
  String get chatsNoResult => 'Nessun risultato.';

  @override
  String get chatsConnectFailed => 'Connessione impossibile.';

  @override
  String get navModules => 'Moduli';

  @override
  String get navBroadcasts => 'Liste broadcast';

  @override
  String get navYou => 'Tu';

  @override
  String get convProductFallback => 'Prodotto';

  @override
  String get convOrderUpdated => 'Ordine aggiornato';

  @override
  String get convReactionFailed => 'Reazione non riuscita.';

  @override
  String get convPermissionDenied => 'Autorizzazione negata.';

  @override
  String get convAttachDocument => 'Documento';

  @override
  String get convAttachGallery => 'Foto (galleria)';

  @override
  String get convAttachVideo => 'Video (galleria)';

  @override
  String get convAttachCamera => 'Fotocamera';

  @override
  String get convEditTitle => 'Modifica messaggio';

  @override
  String get convEditHint => 'Il tuo messaggio';

  @override
  String convForwarded(String name) {
    return 'Messaggio inoltrato a $name.';
  }

  @override
  String get convForwardFailed => 'Inoltro non riuscito.';

  @override
  String get convRecordVoice => 'Registra una nota vocale';

  @override
  String get mediaVoiceNote => 'Nota vocale';

  @override
  String get mediaMessage => 'Messaggio';

  @override
  String get newChatInviteAction => 'Invita';

  @override
  String get profileGallery => 'Galleria';

  @override
  String get profileCamera => 'Fotocamera';

  @override
  String get profileEdit => 'Modifica profilo';

  @override
  String get profileFullName => 'Nome completo';

  @override
  String get profileAbout => 'Informazioni';

  @override
  String get profileUpdateFailed => 'Aggiornamento non riuscito.';

  @override
  String get profileVerifiedPhone => 'Identità verificata tramite telefono';

  @override
  String get profilePrivacySecurity => 'Privacy e sicurezza';

  @override
  String get profileShieldMode => 'Modalità Scudo';

  @override
  String get profileShieldOn => 'Modalità Scudo attiva';

  @override
  String get profileShieldOff => 'Modalità Scudo disattivata';

  @override
  String get profileConnection => 'Connessione';

  @override
  String get profileEncryptedTls => 'Cifrata (TLS)';

  @override
  String get profileStatusVisibility => 'Visibilità degli stati';

  @override
  String get commonEnabled => 'Attivo';

  @override
  String get commonDisabled => 'Disattivo';

  @override
  String get commonLoading => 'Caricamento…';

  @override
  String get profileDevices => 'Dispositivi collegati';

  @override
  String get profileNotifications => 'Notifiche';

  @override
  String get profileStorage => 'Spazio e dati';

  @override
  String get profileDataSaver => 'Risparmio dati';

  @override
  String get profileSystemPrefs => 'Preferenze di sistema';

  @override
  String get profileSignOut => 'Esci';

  @override
  String modulesActivated(String name) {
    return '$name è attivo.';
  }

  @override
  String get modulesUnavailable => 'Moduli non disponibili';

  @override
  String get modulesCheckNetwork => 'Controlla la connessione e riprova.';

  @override
  String get modulesEmptyTitle => 'Niente da aggiungere per ora';

  @override
  String get modulesEmptyBody =>
      'I nuovi moduli appariranno qui. Nel frattempo non devi fare nulla.';

  @override
  String get modulesMine => 'Le mie app';

  @override
  String get modulesRecommended => 'Consigliati';

  @override
  String get modulesRecommendedBy => 'Scelti dal nostro team';

  @override
  String get modulesPopular => 'Popolari';

  @override
  String get modulesPopularSub => 'I più attivati in questo momento';

  @override
  String get modulesEnable => 'Attiva';

  @override
  String get modulesDisable => 'Disattiva';

  @override
  String get modulesEnableFailed => 'Attivazione non riuscita.';

  @override
  String modulesComingSoon(String name) {
    return '$name arriva presto. Aggiorna l\'app per averlo appena esce.';
  }

  @override
  String modulesUserCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count persone lo usano',
      one: '1 persona lo usa',
    );
    return '$_temp0';
  }

  @override
  String get sparkEnableLocation => 'Attiva la posizione sul telefono.';

  @override
  String get sparkLocationNeeded =>
      'Senza posizione, Spark non può sapere chi ti sta intorno.';

  @override
  String get sparkLocationFailed => 'Impossibile rilevare la posizione.';

  @override
  String get sparkFeedUnavailable => 'Flusso non disponibile';

  @override
  String get sparkPickIntentTitle => 'Scegli la tua carta del momento';

  @override
  String get sparkPickIntentBody =>
      'Di\' cosa cerchi oggi per vedere chi cerca lo stesso.';

  @override
  String get sparkLocationStale => 'La tua posizione non è aggiornata';

  @override
  String get sparkLocationStaleBody =>
      'Spark mostra solo persone entro 5 km. Senza una posizione recente non può mostrare nulla.';

  @override
  String get sparkShareLocation => 'Condividi la mia posizione';

  @override
  String get sparkQuotaTitle => 'Hai visto i profili di oggi';

  @override
  String get sparkQuotaBody =>
      'Torna domani, o prendi Spark+ per guardare senza limiti.';

  @override
  String get sparkNobodyTitle => 'Nessuno per ora';

  @override
  String get sparkNobodyBody =>
      'Poche persone cercano la stessa cosa qui e ora. Riprova più tardi o cambia carta.';

  @override
  String get sparkPickCard => 'Scegli la tua carta';

  @override
  String get sparkTodayLooking => 'Cosa cerchi oggi';

  @override
  String get sparkCardExpired => 'La tua carta è scaduta';

  @override
  String sparkHoursLeft(int hours) {
    return 'Ancora $hours h';
  }

  @override
  String sparkMinutesLeft(int minutes) {
    return 'Ancora $minutes min';
  }

  @override
  String get sparkIntentSheetTitle => 'Oggi cerco';

  @override
  String get sparkIntentSheetBody =>
      'La tua carta scade tra 24 h. Vedrai solo persone che hanno scelto lo stesso.';

  @override
  String get sparkLikesExhausted =>
      'Hai finito i like di oggi. Prendi un pacchetto in «Io».';

  @override
  String get sparkMatchesUnavailable => 'Match non disponibili';

  @override
  String get sparkNoMatchTitle => 'Ancora nessun match';

  @override
  String get sparkNoMatchBody =>
      'Quando vi piacete a vicenda, si apre una stanza di dieci minuti. È lì che si decide.';

  @override
  String get sparkOpenRooms => 'Stanze aperte';

  @override
  String get sparkRoomsClose => 'Si chiudono da sole';

  @override
  String get sparkMyMatches => 'I miei match';

  @override
  String get sparkNext => 'Seguito';

  @override
  String get sparkPhotoFailed => 'Impossibile aggiungere la foto.';

  @override
  String get sparkGoFaster => 'Andare più veloce';

  @override
  String get sparkNoExpiry => 'Senza scadenza';

  @override
  String get sparkPlusActive => 'Attivo — prolunga l\'abbonamento';

  @override
  String get sparkPlusPitch => 'Profili illimitati, un mese';

  @override
  String get sparkBoost => 'Profilo in cima';

  @override
  String get sparkBoostPitch => 'In cima al flusso per un\'ora';

  @override
  String get sparkAroundMe => 'Intorno a me';

  @override
  String get sparkSafety => 'Sicurezza';

  @override
  String get sparkSafetyPitch => 'Allerta discreta e cerchia di fiducia';

  @override
  String get sparkWingman => 'Il parere dei miei amici';

  @override
  String get sparkWingmanPitch => 'Profili su cui ti chiedono un parere';

  @override
  String get sparkUploading => 'Invio…';

  @override
  String get sparkKarma => 'Street Cred';

  @override
  String get sparkCanInvite => 'Puoi invitare';

  @override
  String get sparkCannotInvite =>
      'Troppo basso per invitare. Onora i tuoi appuntamenti.';

  @override
  String sparkLikersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count persone ti hanno messo like',
      one: 'Una persona ti ha messo like',
    );
    return '$_temp0';
  }

  @override
  String get sparkSeeWho => 'Vedi chi';

  @override
  String get sparkFindInDiscover => 'Li trovi in Scopri.';

  @override
  String get sparkPaymentPendingLikers =>
      'La lista si aprirà appena il pagamento sarà confermato.';

  @override
  String get sparkPaymentPendingLikes =>
      'I tuoi like arriveranno appena il pagamento sarà confermato.';

  @override
  String get sparkPaymentPendingPlus =>
      'Spark+ si attiverà appena il pagamento sarà confermato.';

  @override
  String get sparkPaymentPendingBoost =>
      'Il tuo profilo salirà appena il pagamento sarà confermato.';

  @override
  String get sparkBirthDateLabel => 'La tua data di nascita';

  @override
  String get sparkNameAndBirthNeeded =>
      'Un nome e una data di nascita, come minimo.';

  @override
  String get sparkProfileFailed => 'Impossibile creare il profilo.';

  @override
  String get sparkCreateProfile => 'Crea il tuo profilo';

  @override
  String get sparkStep1Title => 'Dici cosa cerchi, oggi';

  @override
  String get sparkStep1Body =>
      'La tua carta scade in 24 h. Vedi solo persone che cercano lo stesso, entro 5 km.';

  @override
  String get sparkStep2Title => 'Dieci minuti di vocale prima di scrivere';

  @override
  String get sparkStep2Body =>
      'Dopo un match si apre una stanza: solo vocali e sticker. I profili falsi non la superano.';

  @override
  String get sparkStep3Title => 'I tuoi cari sanno dove sei';

  @override
  String get sparkStep3Body =>
      'Un gesto discreto avvisa la tua cerchia con la tua posizione. Ti chiediamo anche se va tutto bene durante l\'incontro.';

  @override
  String get sparkSeparateTitle => 'Il tuo profilo è separato da Pokou';

  @override
  String get sparkSeparateBody =>
      'Il tuo nome e numero Pokou non sono mai mostrati qui. Scegli cosa mostrare.';

  @override
  String get sparkDisplayName => 'Nome visualizzato';

  @override
  String get sparkNameExample => 'Es. Ama';

  @override
  String get sparkBirthDate => 'Data di nascita';

  @override
  String get sparkBirthDateLocked => 'Non potrà più essere modificata.';

  @override
  String get sparkChoose => 'Scegli';

  @override
  String get sparkYouAre => 'Sei';

  @override
  String get sparkWoman => 'Una donna';

  @override
  String get sparkMan => 'Un uomo';

  @override
  String get sparkOther => 'Altro';

  @override
  String get sparkBioLabel => 'Due parole su di te (facoltativo)';

  @override
  String get sparkBioHint => 'Cosa vale la pena sapere prima di incontrarti';

  @override
  String get sparkCreateAction => 'Crea il mio profilo';

  @override
  String get truthSubtitle => 'Una domanda pagata, una risposta libera';

  @override
  String get truthAsk => 'Fai una domanda';

  @override
  String get truthForMe => 'Per me';

  @override
  String get truthMine => 'Le mie domande';

  @override
  String get truthUnavailable => 'Domande non disponibili';

  @override
  String get truthEmptyTitle => 'Ancora nessuna domanda';

  @override
  String get truthEmptyBody =>
      'Quando qualcuno pagherà per farti una domanda, apparirà qui. Resti libero di rifiutare.';

  @override
  String get truthYourAnswer => 'La tua risposta';

  @override
  String get truthAnswerPrivacy =>
      'Va solo a chi ha pagato. Pokou non la ripubblica da nessuna parte.';

  @override
  String get truthWhatToSay => 'Cosa vuoi dire';

  @override
  String get truthSendAnswer => 'Invia la mia risposta';

  @override
  String get truthAskedAnon => 'Chiesto in forma anonima';

  @override
  String get truthDecline => 'Rifiuta';

  @override
  String get truthAnswer => 'Rispondi';

  @override
  String get truthDeclineFree =>
      'Rifiutare non ti costa nulla. Sei pagato solo se rispondi.';

  @override
  String get truthHistoryUnavailable => 'Cronologia non disponibile';

  @override
  String get truthNothingAsked => 'Non hai ancora chiesto nulla';

  @override
  String get truthNothingAskedBody =>
      'Fai una domanda a qualcuno: vedrà l\'importo e la domanda, mai il tuo nome.';

  @override
  String get truthAnswered => 'Risposta';

  @override
  String get truthDeclined => 'Rifiutata';

  @override
  String get truthPending => 'In attesa';

  @override
  String truthToSomeone(String name) {
    return 'A $name';
  }

  @override
  String get truthSomeone => 'qualcuno';

  @override
  String get truthPreferredNot => 'Ha preferito non rispondere.';

  @override
  String get truthAwaitingAnswer => 'In attesa di una risposta.';

  @override
  String get truthToWhom => 'A chi?';

  @override
  String truthQuestionTo(String name) {
    return 'Una domanda per $name';
  }

  @override
  String get truthAnonTitle => 'Il tuo nome non viene mostrato';

  @override
  String get truthAnonBody =>
      'Vede l\'importo e la domanda, mai chi li ha inviati.';

  @override
  String get truthFreeTitle => 'Resta libera di rifiutare';

  @override
  String get truthFreeBody =>
      'Rifiutare non le frutta nulla: è pagata solo rispondendo.';

  @override
  String get truthPrivateTitle => 'La risposta va solo a te';

  @override
  String get truthPrivateBody =>
      'Pokou non la ripubblica da nessuna parte e scade dopo sette giorni senza risposta.';

  @override
  String get truthYourQuestion => 'La tua domanda';

  @override
  String get truthQuestionHint => 'Quello che vorresti davvero sapere';

  @override
  String get truthHowMuch => 'Quanto offri';

  @override
  String truthAskForAmount(int amount) {
    return 'Fai la domanda — $amount FCFA';
  }

  @override
  String get truthWriteFirst => 'Scrivi prima la tua domanda.';

  @override
  String get truthPaymentPending =>
      'La tua domanda partirà appena il pagamento sarà confermato.';

  @override
  String get hypeFinished => 'Concluso';

  @override
  String get hypeSubtitle => 'Un obiettivo, tutta la sala';

  @override
  String get hypeLaunch => 'Lancia un obiettivo';

  @override
  String get hypeOngoing => 'In corso';

  @override
  String get hypeMine => 'I miei';

  @override
  String get hypeNoneTitle => 'Nessun obiettivo in corso';

  @override
  String get hypeNoneBody =>
      'Quando un creatore lancia un obiettivo, appare qui finché non viene raggiunto.';

  @override
  String get hypeMineEmpty => 'Niente per ora';

  @override
  String get hypeMineEmptyBody =>
      'I tuoi obiettivi e quelli che hai sostenuto appariranno qui.';

  @override
  String get hypeUnavailable => 'Obiettivi non disponibili';

  @override
  String get hypeCreator => 'Creatore';

  @override
  String get hypeTierReached => 'Traguardo raggiunto';

  @override
  String get hypeGoal => 'Obiettivo';

  @override
  String get hypeNotFound => 'Obiettivo non trovato';

  @override
  String get hypeMaybeRemoved => 'Potrebbe essere stato rimosso.';

  @override
  String get hypeUnlocked =>
      'Il traguardo è raggiunto. La promessa è sbloccata.';

  @override
  String get hypeContribute => 'Fai avanzare la barra';

  @override
  String get hypePushers => 'Chi spinge';

  @override
  String get hypeBeFirst => 'Ancora nessuno. Sii il primo.';

  @override
  String get hypeContributor => 'Sostenitore';

  @override
  String commonDueToYou(int amount) {
    return 'Ti spetta: $amount FCFA';
  }

  @override
  String get commonManualPayout =>
      'Il versamento è effettuato dal team Pokou, su richiesta.';

  @override
  String get hypeStepTogetherTitle => 'Tutti spingono insieme';

  @override
  String get hypeStepTogetherBody =>
      'Ogni contributo alza la barra, e tutti vedono il traguardo cadere insieme.';

  @override
  String get hypeStepPromiseTitle => 'Cosa prometti';

  @override
  String get hypeStepPromiseBody =>
      'Visibile prima che qualcuno paghi. È il tuo impegno se l\'obiettivo è raggiunto.';

  @override
  String get hypeStepOneTitle => 'Un solo obiettivo alla volta';

  @override
  String get hypeStepOneBody =>
      'Due obiettivi insieme metterebbero i tuoi sostenitori in concorrenza con sé stessi.';

  @override
  String get commonTitle => 'Titolo';

  @override
  String get hypeTitleExample => 'Es. 100.000 e canto';

  @override
  String get hypePromiseLabel => 'Cosa sblocchi se l\'obiettivo è raggiunto';

  @override
  String get hypePromiseHint =>
      'Sii preciso: è ciò che i tuoi sostenitori comprano.';

  @override
  String get hypeGoalAmount => 'Obiettivo in FCFA';

  @override
  String get commonDuration => 'Durata';

  @override
  String get hypeLaunchAction => 'Lancia';

  @override
  String get hypeFieldsNeeded => 'Titolo, promessa e obiettivo sono necessari.';

  @override
  String get hypeAlreadyRunning => 'Hai già un obiettivo in corso.';

  @override
  String get hypeContributeNote =>
      'Il tuo contributo fa avanzare la barra e sblocca un contenuto. Non è rimborsabile.';

  @override
  String get commonAmount => 'Importo';

  @override
  String hypeJoinForAmount(int amount) {
    return 'Partecipa — $amount FCFA';
  }

  @override
  String get hypePaymentPending =>
      'La barra avanzerà appena il pagamento sarà confermato.';

  @override
  String get ceremonyWedding => 'Matrimonio';

  @override
  String get ceremonyBaptism => 'Battesimo';

  @override
  String get ceremonyFuneral => 'Lutto';

  @override
  String get ceremonyOther => 'Altro';

  @override
  String get ceremonyTitle => 'Raccolte';

  @override
  String get ceremonySubtitle => 'Le quote, senza solleciti';

  @override
  String get ceremonyNew => 'Nuova raccolta';

  @override
  String get ceremonyUnavailable => 'Raccolte non disponibili';

  @override
  String get ceremonyNone => 'Nessuna raccolta';

  @override
  String get ceremonyNoneBody =>
      'Matrimonio, battesimo, lutto: crea la raccolta, invita, e ognuno dà quel che può.';

  @override
  String ceremonyGoalHint(int amount) {
    return 'Obiettivo indicativo: $amount FCFA';
  }

  @override
  String get ceremonyOne => 'Raccolta';

  @override
  String get ceremonyNotFound => 'Raccolta non trovata';

  @override
  String get ceremonyMaybeClosed => 'Potrebbe essere stata chiusa.';

  @override
  String get ceremonyJoin => 'Partecipa';

  @override
  String get ceremonyClose => 'Chiudi la raccolta';

  @override
  String get ceremonyContributions => 'Contributi';

  @override
  String get ceremonyNobodyYet => 'Nessuno ha ancora contribuito.';

  @override
  String get ceremonyAnonGift => 'Contributo anonimo';

  @override
  String get ceremonyContributor => 'Contributore';

  @override
  String get ceremonyCollected => 'raccolti';

  @override
  String get ceremonyYouOrganize => 'organizzi tu';

  @override
  String get ceremonyNewSubtitle =>
      'Segui i contributi. Pokou non sollecita chi non ha dato.';

  @override
  String get ceremonyOccasion => 'Occasione';

  @override
  String get ceremonyTitleExample => 'Es. Matrimonio di Kossi e Ama';

  @override
  String get ceremonyFewWords => 'Qualche parola (facoltativo)';

  @override
  String get ceremonyFewWordsHint =>
      'La data, il luogo, a cosa servirà il denaro.';

  @override
  String get ceremonyGoalOptional => 'Obiettivo in FCFA (facoltativo)';

  @override
  String get ceremonyGoalNote =>
      'Indicativo: la raccolta continua ad accettare oltre.';

  @override
  String get ceremonyCreate => 'Crea la raccolta';

  @override
  String get ceremonyNeedTitle => 'Dai un titolo alla raccolta.';

  @override
  String ceremonyJoinTo(String title) {
    return 'Partecipa — $title';
  }

  @override
  String get ceremonyOtherAmount => 'O un altro importo';

  @override
  String get ceremonyWordOptional => 'Un messaggio (facoltativo)';

  @override
  String get ceremonyWordHint => 'Cosa vuoi dire loro';

  @override
  String get ceremonyAnonToggle => 'Contribuisci in forma anonima';

  @override
  String get ceremonyAnonNote =>
      'Il tuo nome è nascosto. L\'importo resta nel totale.';

  @override
  String ceremonyJoinAmount(int amount) {
    return 'Partecipa — $amount FCFA';
  }

  @override
  String get ceremonyMinimum => 'Il minimo è 100 FCFA.';

  @override
  String get ceremonyPaymentPending =>
      'Il tuo contributo apparirà appena il pagamento sarà confermato.';

  @override
  String get vipSubtitle => 'I tuoi abbonati, il tuo spazio';

  @override
  String get vipDiscover => 'Scopri';

  @override
  String get vipMySubs => 'I miei abbonamenti';

  @override
  String get vipMyRoom => 'La mia stanza';

  @override
  String get vipNoRoomOpen => 'Nessuna stanza aperta';

  @override
  String get vipNoRoomOpenBody =>
      'Le stanze aperte dai creatori appariranno qui.';

  @override
  String get vipNoSub => 'Nessun abbonamento';

  @override
  String get vipNoSubBody =>
      'Abbonati a una stanza per trovare qui tutto ciò che pubblica il creatore.';

  @override
  String get vipUnavailable => 'Stanze non disponibili';

  @override
  String get vipCreator => 'Creatore';

  @override
  String vipUntil(String date) {
    return 'Fino al $date';
  }

  @override
  String get vipPaymentPending =>
      'La stanza si aprirà appena il pagamento sarà confermato.';

  @override
  String get vipRoom => 'Stanza';

  @override
  String get vipNotFound => 'Stanza non trovata';

  @override
  String get vipMaybeClosed => 'Potrebbe essere stata chiusa.';

  @override
  String get vipStepAllTitle => 'Tutto ciò che è pubblicato qui';

  @override
  String get vipStepAllBody =>
      'Vedi subito ciò che è già pubblicato, e tutto ciò che seguirà.';

  @override
  String get vipStepDaysTitle => 'Trenta giorni';

  @override
  String get vipStepDaysBody =>
      'L\'accesso finisce da solo alla scadenza. Nulla continua senza la tua decisione.';

  @override
  String get vipStepNoRenewTitle => 'Nessun rinnovo automatico';

  @override
  String get vipStepNoRenewBody =>
      'Pokou non conserva il tuo metodo di pagamento. Per continuare, paghi di nuovo, una volta.';

  @override
  String vipSubscribeFor(int amount) {
    return 'Abbonati — $amount FCFA';
  }

  @override
  String get vipLockedTitle => 'Contenuto riservato agli abbonati';

  @override
  String get vipLockedBody =>
      'Il resto della stanza si apre appena il pagamento sarà confermato.';

  @override
  String get vipNothingYet => 'Ancora nulla';

  @override
  String get vipNothingYetBody => 'Questa stanza non ha ancora post.';

  @override
  String get vipPosts => 'Pubblicazioni';

  @override
  String get vipRoomUnavailable => 'Stanza non disponibile';

  @override
  String get vipOpenYourRoom => 'Apri la tua stanza';

  @override
  String get vipOpenYourRoomBody =>
      'I tuoi abbonati pagano una volta per trenta giorni e vedono tutto ciò che pubblichi. Decidi tu il prezzo.';

  @override
  String get vipOpenAction => 'Apri la mia stanza';

  @override
  String get vipPublish => 'Pubblica';

  @override
  String get vipSeeMyRoom => 'Vedi la mia stanza';

  @override
  String get vipOpen => 'Aperta';

  @override
  String get vipClosed => 'Chiusa';

  @override
  String get vipEarnings => 'I tuoi guadagni';

  @override
  String vipCollected(int amount) {
    return '$amount FCFA raccolti';
  }

  @override
  String get vipDueNote =>
      'L\'importo che ti spetta. Il versamento è effettuato dal team Pokou, su richiesta.';

  @override
  String get vipEditRoom => 'Modifica la mia stanza';

  @override
  String get vipPriceNote =>
      'Un nuovo prezzo vale solo per gli abbonamenti successivi: ognuno ha pagato il suo in anticipo.';

  @override
  String get vipRoomName => 'Nome della stanza';

  @override
  String get vipRoomNameHint => 'Es. Il dietro le quinte';

  @override
  String get vipPitchLabel => 'Cosa vi troveranno i tuoi abbonati';

  @override
  String get vipPitchNote =>
      'Visibile prima di pagare — è ciò che invoglia ad abbonarsi.';

  @override
  String get vipPitchHint => 'Foto, annunci, messaggi vocali…';

  @override
  String get vipMonthlyPrice => 'Prezzo mensile in FCFA';

  @override
  String get vipAcceptNew => 'Accetta nuovi abbonati';

  @override
  String get vipAcceptNewNote =>
      'Gli abbonati attuali mantengono l\'accesso fino alla scadenza.';

  @override
  String get vipFieldsNeeded => 'Nome, descrizione e prezzo sono necessari.';

  @override
  String get vipPublishTitle => 'Pubblica nella mia stanza';

  @override
  String get vipPublishNote => 'Visibile solo ai tuoi abbonati attuali.';

  @override
  String get vipYourMessage => 'Il tuo messaggio';

  @override
  String get vipShareHint => 'Cosa vuoi condividere';

  @override
  String vipEarningsSummary(int count, int amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abbonamenti',
      one: '1 abbonamento',
    );
    return '$_temp0 • $amount FCFA raccolti';
  }

  @override
  String get datesUnavailable => 'Uscite non disponibili';

  @override
  String get datesNone => 'Nessuna uscita prevista';

  @override
  String get datesNoneBody =>
      'Passata la stanza, proponi un posto. Paghi in anticipo, e il denaro esce solo quando confermate entrambi.';

  @override
  String get datesNotNow => 'Non è il momento per questo.';

  @override
  String get datesCancelTitle => 'Annullare l\'uscita?';

  @override
  String get datesCancelFree =>
      'Mancano più di 24 h: sarai rimborsato per intero.';

  @override
  String get datesCancelLate =>
      'Mancano meno di 24 h. Il locale ha già prenotato; il pagamento resta suo.';

  @override
  String get datesKeep => 'Mantieni';

  @override
  String get datesCancelAction => 'Annulla l\'uscita';

  @override
  String get datesAwaitingPayment => 'In attesa di pagamento';

  @override
  String get datesPaidToConfirm => 'Pagato — da confermare';

  @override
  String get datesDone => 'Concluso';

  @override
  String get datesRefunded => 'Rimborsato';

  @override
  String get datesNoShow => 'Assenza segnalata';

  @override
  String get datesCancelled => 'Annullato';

  @override
  String get datesOne => 'Uscita';

  @override
  String datesWithPeer(String venue, String name) {
    return '$venue • con $name';
  }

  @override
  String get datesYourMatch => 'il tuo match';

  @override
  String get datesWentWell => 'È andata bene';

  @override
  String get datesYouConfirmed =>
      'Hai confermato. Aspettiamo la conferma dell\'altro.';

  @override
  String get datesNoShowAction => 'Non si è presentato';

  @override
  String get datesVoucher => 'Il tuo buono, da dare sul posto';

  @override
  String get datesPickBoth => 'Scegli una formula e un orario.';

  @override
  String get datesVoucherPending =>
      'Il tuo buono sarà emesso appena il pagamento sarà confermato.';

  @override
  String get datesBookingFailed => 'La prenotazione non è andata a buon fine.';

  @override
  String get datesWhereTo => 'Dove andate?';

  @override
  String get datesStepPayTitle => 'Paghi in anticipo, nulla viene versato';

  @override
  String get datesStepPayBody =>
      'Il denaro è bloccato. Arriva al locale solo se confermate entrambi.';

  @override
  String get datesStepCancelTitle => 'Cancellazione libera oltre 24 h';

  @override
  String get datesStepCancelBody =>
      'Rimborso totale. Sotto, il locale ha già prenotato e trattiene il pagamento.';

  @override
  String get datesStepNoShowTitle => 'Se l\'altro non viene';

  @override
  String get datesStepNoShowBody =>
      'Metà torna a te. L\'app non trattiene nulla su un appuntamento mancato.';

  @override
  String get datesThePackage => 'La formula';

  @override
  String get datesPacksUnavailable =>
      'Le formule non sono disponibili al momento.';

  @override
  String get datesNoPackNearby =>
      'Nessuna formula proposta vicino a te per ora.';

  @override
  String get datesWhen => 'Quando?';

  @override
  String get datesPickWhen => 'Scegli data e ora';

  @override
  String get datesBook => 'Prenota';

  @override
  String datesBookAmount(int amount) {
    return 'Prenota — $amount FCFA';
  }

  @override
  String get roomNeedMic =>
      'Senza microfono restano solo gli sticker — la stanza è vocale.';

  @override
  String get roomVoiceFailed => 'Il vocale non è partito.';

  @override
  String get roomBothYes => 'Ci siamo. Ora puoi proporre un\'uscita.';

  @override
  String get roomWaitingOther =>
      'Annotato. Aspettiamo la sua risposta prima della fine del conto alla rovescia.';

  @override
  String get roomExtendPending =>
      'Dieci minuti in più appena il pagamento sarà confermato.';

  @override
  String get roomTitle => 'Stanza d\'ingresso';

  @override
  String get roomNotFound => 'Stanza non trovata';

  @override
  String get roomMaybeClosed => 'Potrebbe essersi chiusa.';

  @override
  String get roomVoiceOnly => 'Solo vocali e sticker';

  @override
  String get roomTimeUp => 'Il tempo è scaduto.';

  @override
  String roomTimeLeft(String clock) {
    return 'Restano $clock per decidere insieme';
  }

  @override
  String get roomSaySomething => 'Di\' qualcosa';

  @override
  String get roomNoTextBody =>
      'Niente testo qui: un vocale o uno sticker. È ciò che distingue una persona vera da un messaggio copiato.';

  @override
  String get roomVoice => 'Vocale';

  @override
  String get roomWaitingReply => 'In attesa della sua risposta';

  @override
  String roomExtendFor(int amount) {
    return 'Dieci minuti in più — $amount FCFA';
  }

  @override
  String get roomBothSaidYes => 'Avete detto sì entrambi.';

  @override
  String get roomSaved => 'Il match è salvo. Puoi proporre un\'uscita.';

  @override
  String get roomClosedNoAnswer => 'La stanza si è chiusa senza risposta.';

  @override
  String get roomSuggestDate => 'Proponi un\'uscita';

  @override
  String get safetyCheckin => 'Tutto bene?';

  @override
  String get safetyCheckinBody =>
      'Senza una tua risposta entro cinque minuti, la tua cerchia di sicurezza sarà avvisata con la tua posizione.';

  @override
  String get safetyAllGood => 'Sì, tutto bene';

  @override
  String get safetyCircleAlerted => 'La tua cerchia è stata avvisata.';

  @override
  String get safetyNoCircle =>
      'Allerta registrata. Aggiungi persone care perché siano avvisate la prossima volta.';

  @override
  String get safetyWhoToAlert => 'Chi avvisare?';

  @override
  String get safetyWhoToAlertBody =>
      'Queste persone riceveranno la tua posizione in diretta se lanci un\'allerta.';

  @override
  String get safetyTitle => 'Sicurezza';

  @override
  String get safetySubtitle => 'Chi viene avvisato se qualcosa va storto';

  @override
  String get safetyQuietAlert => 'Allerta discreta';

  @override
  String get safetyQuietAlertBody =>
      'Avvisa la tua cerchia con la tua posizione. Sullo schermo del telefono non appare nulla.';

  @override
  String get safetyTrigger => 'Lancia un\'allerta';

  @override
  String get safetyMyCircle => 'La mia cerchia';

  @override
  String get safetyThreeEnough => 'Tre persone bastano';

  @override
  String get safetyNobodyYet =>
      'Nessuno per ora. Senza cerchia, un\'allerta viene registrata ma non avvisa nessuno.';

  @override
  String get safetyAddSomeone => 'Aggiungi qualcuno';

  @override
  String get wingmanTitle => 'Parere degli amici';

  @override
  String get wingmanAnon => 'Il tuo parere resta anonimo';

  @override
  String get wingmanUnavailable => 'Richieste non disponibili';

  @override
  String get wingmanNothing => 'Niente da valutare';

  @override
  String get wingmanNothingBody =>
      'Quando un amico ti chiederà cosa pensi di un profilo, apparirà qui.';

  @override
  String wingmanAsksYou(String name) {
    return '$name chiede il tuo parere';
  }

  @override
  String get wingmanMeh => 'Mah';

  @override
  String get wingmanWorthIt => 'Ne vale la pena';

  @override
  String get wingmanPrivacy =>
      'Il tuo amico vedrà solo se il gruppo approva, mai chi ha detto cosa.';

  @override
  String get marketLocationOff =>
      'Il servizio di localizzazione è disattivato.';

  @override
  String get marketGpsDenied => 'Autorizzazione GPS negata.';

  @override
  String get marketGpsApplied => 'Posizione GPS applicata.';

  @override
  String get marketGpsFailed => 'Impossibile ottenere la posizione.';

  @override
  String get marketYourArea => 'La tua zona';

  @override
  String get marketCityOrArea => 'Città o quartiere';

  @override
  String get marketLocationCleared => 'Localizzazione disattivata.';

  @override
  String get marketUseGps => 'Usa la mia posizione GPS';

  @override
  String get marketApply => 'Applica';

  @override
  String marketRemoveProduct(String name) {
    return 'Rimuovere «$name»?';
  }

  @override
  String get marketProductUnavailable => 'Prodotto non disponibile.';

  @override
  String get marketPaymentUnavailable =>
      'Pagamento Mobile Money non disponibile.';

  @override
  String get marketCheckoutUnreachable =>
      'Checkout Mobile Money irraggiungibile.';

  @override
  String get marketBoostDone => 'Pagamento effettuato: annuncio sponsorizzato.';

  @override
  String get marketBoostPending => 'Pagamento della promozione in attesa.';

  @override
  String get marketBoostFailed => 'Promozione non possibile al momento.';

  @override
  String get marketTitle => 'Assimé';

  @override
  String get marketBecomeSeller => 'Diventa venditore verificato';

  @override
  String get marketAddProduct => 'Aggiungi un prodotto';

  @override
  String get marketAroundYou => 'Intorno a te';

  @override
  String get marketMyGps => 'La mia posizione GPS';

  @override
  String get marketPickArea => 'Scegli una zona';

  @override
  String get marketNearYou => 'Prodotti vicino a te';

  @override
  String get marketUnavailable => 'Marketplace non disponibile.';

  @override
  String get marketNoProduct => 'Nessun prodotto pubblicato.';

  @override
  String get marketNoMatch => 'Nessun prodotto corrisponde a questa ricerca.';

  @override
  String get marketAllShown => 'Tutti i prodotti sono mostrati';

  @override
  String get marketMyCatalogue => 'Il mio catalogo';

  @override
  String get marketSwipeCatalogue => 'Scorri per vedere tutti i tuoi prodotti';

  @override
  String get marketCatalogueEmpty => 'Il tuo catalogo è vuoto';

  @override
  String get marketCatalogueEmptyBody =>
      'Aggiungi il tuo primo prodotto per iniziare a vendere!';

  @override
  String get marketBoosted => 'Sponsorizzato';

  @override
  String get vitrineSeeProduct => 'Vedi articolo';

  @override
  String get vitrineHint => 'Tocca l\'articolo per aprirlo';

  @override
  String get vitrineTitle => 'Vetrina del Mercato';

  @override
  String get versesMorning => 'Versetto del mattino';

  @override
  String get versesEvening => 'Versetto della sera';

  @override
  String get versesChannel => 'Versetti del giorno';

  @override
  String get versesChannelDesc => 'I versetti delle 6 e delle 18';

  @override
  String get versesSchedule => 'Ogni giorno alle 6 e alle 18';

  @override
  String get versesThisMorning => 'Stamattina';

  @override
  String get versesThisEvening => 'Stasera';

  @override
  String get versesBibleTitle => 'Versetti biblici';

  @override
  String get versesQuranTitle => 'Versetti coranici';

  @override
  String get versesShare => 'Condividi';

  @override
  String get versesOfflineHint =>
      'I versetti arrivano anche senza connessione: sono già sul tuo telefono.';

  @override
  String get marketBoosted48h => 'Sponsorizzato';

  @override
  String get marketBoost => 'Metti in evidenza';

  @override
  String get marketRemove => 'Rimuovi';

  @override
  String get marketGpsSaved => 'Posizione GPS salvata.';

  @override
  String get marketNameAndPrice => 'Servono un nome e un prezzo.';

  @override
  String get marketEditProduct => 'Modifica prodotto';

  @override
  String get marketMainPhoto => 'Foto principale';

  @override
  String get marketOtherPhotos => 'Altre foto';

  @override
  String get marketDescription => 'Descrizione';

  @override
  String get marketCurrency => 'Valuta';

  @override
  String get marketCategory => 'Categoria';

  @override
  String get marketPickCategory => 'Scegli una categoria';

  @override
  String get marketSpecifyCategory => 'Specifica la categoria';

  @override
  String marketGpsCoords(String lat, String lon) {
    return 'Coordinate GPS: $lat, $lon';
  }

  @override
  String get marketUploadingPhoto => 'Invio della foto…';

  @override
  String get marketAddPhoto => 'Aggiungi una foto';

  @override
  String get groupEditName => 'Modifica nome';

  @override
  String get groupAddPhoto => 'Aggiungi una foto';

  @override
  String get groupChangePhoto => 'Cambia foto';

  @override
  String get groupRemovePhoto => 'Rimuovi foto';

  @override
  String get groupNoLink => 'Nessun link attivo';

  @override
  String get groupLinkActive => 'Un link è attivo';

  @override
  String get groupCreator => 'Creatore';

  @override
  String get groupAdmin => 'Amministratore';

  @override
  String get groupAddMembers => 'Aggiungi partecipanti';

  @override
  String get groupLeave => 'Esci dal gruppo';

  @override
  String get groupName => 'Nome del gruppo';

  @override
  String get groupCopyLink => 'Copia il link';

  @override
  String get groupRegenLink => 'Rigenera il link';

  @override
  String get groupDisableLink => 'Disattiva il link';

  @override
  String get groupLinkCopied => 'Link copiato.';

  @override
  String get groupLinkDisabled => 'Link disattivato.';

  @override
  String get groupAllContactsIn =>
      'Tutti i tuoi contatti Pokou sono già in questo gruppo.';

  @override
  String get groupAddToGroup => 'Aggiungi al gruppo';

  @override
  String groupMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partecipanti aggiunti.',
      one: 'Partecipante aggiunto.',
    );
    return '$_temp0';
  }

  @override
  String get groupLeaveTitle => 'Uscire dal gruppo?';

  @override
  String groupLeaveBody(String name) {
    return 'Non riceverai più i messaggi di «$name».';
  }

  @override
  String get groupLeaveAction => 'Esci';

  @override
  String get groupNoMessage => 'Nessun messaggio. Avvia la conversazione.';

  @override
  String get groupNotEncryptedNotice =>
      'Crittografia end-to-end: solo i membri possono leggerli.';

  @override
  String get botLabel => 'Bot';

  @override
  String get botConversationNotice =>
      'Stai scrivendo al bot di un\'azienda. Questi messaggi non sono crittografati end-to-end: l\'azienda legge ciò che invii.';

  @override
  String get groupAdminsOnly => 'Solo amministratori';

  @override
  String get groupCallOngoing => 'Chiamata in corso';

  @override
  String get communityEdit => 'Modifica la comunità';

  @override
  String get commonName => 'Nome';

  @override
  String get communityEditFailed => 'Modifica non riuscita.';

  @override
  String get communityAddGroup => 'Aggiungi un gruppo';

  @override
  String get communityNewGroup => 'Crea un nuovo gruppo';

  @override
  String get communityAttachGroup => 'Collega un gruppo esistente';

  @override
  String communityDetachTitle(String name) {
    return 'Scollegare «$name»?';
  }

  @override
  String get communityDetachBody =>
      'Il gruppo lascia la comunità ma continua a esistere: chat e partecipanti non cambiano.';

  @override
  String get communityDetach => 'Scollega';

  @override
  String get communityDetachFailed => 'Impossibile scollegare questo gruppo.';

  @override
  String get communityLinkNote =>
      'Chi ha questo link entra nella comunità e nel gruppo Annunci — non negli altri, che si uniscono uno a uno.';

  @override
  String get communityActionFailed => 'Operazione non riuscita.';

  @override
  String get communityLeaveTitle => 'Uscire dalla comunità?';

  @override
  String get communityLeaveBody =>
      'Non riceverai più i suoi annunci. I gruppi a cui ti sei unito restano tuoi.';

  @override
  String get communityLeave => 'Esci dalla comunità';

  @override
  String get communityLeaveFailed => 'Impossibile uscire dalla comunità.';

  @override
  String get communityOne => 'Comunità';

  @override
  String get communityUnavailable =>
      'Comunità non disponibile — controlla la connessione.';

  @override
  String get communityGroups => 'GRUPPI';

  @override
  String get communityAnnouncements => 'Annunci · solo amministratori';

  @override
  String get communityOnlyAdminGroups =>
      'Solo i gruppi che amministri possono unirsi a una comunità.';

  @override
  String get channelPostsUnavailable => 'Pubblicazioni non disponibili.';

  @override
  String get channelReactionFailed => 'Reazione non registrata.';

  @override
  String get channelPostFailed => 'Pubblicazione non riuscita.';

  @override
  String get channelEditPost => 'Modifica la pubblicazione';

  @override
  String get channelEditTooOld =>
      'Modifica impossibile — pubblicazione troppo vecchia.';

  @override
  String get channelDeletePost => 'Eliminare la pubblicazione?';

  @override
  String get channelDeleteBody => 'Sparirà per tutti gli abbonati.';

  @override
  String get channelDeleteFailed => 'Eliminazione non riuscita.';

  @override
  String get channelLinkCopied => 'Link del canale copiato.';

  @override
  String get channelLinkUnavailable => 'Link non disponibile.';

  @override
  String get channelEdit => 'Modifica il canale';

  @override
  String get channelPublish => 'Pubblica';

  @override
  String channelFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abbonati',
      one: '1 abbonato',
    );
    return '$_temp0';
  }

  @override
  String get channelFollowing => 'Seguito';

  @override
  String get channelEdited => '· modificato';

  @override
  String get channelImageFailed => 'Immagine non inviata.';

  @override
  String get channelNewPost => 'Nuova pubblicazione';

  @override
  String get channelPostHint => 'Il tuo annuncio…';

  @override
  String pollAnswerN(int index) {
    return 'Risposta $index';
  }

  @override
  String get pollAddAnswer => 'Aggiungi una risposta';

  @override
  String get pollMultiple => 'Più risposte possibili';

  @override
  String get pollAddImage => 'Aggiungi un\'immagine';

  @override
  String get pollRemove => 'Rimuovi il sondaggio';

  @override
  String get pollOne => 'Sondaggio';

  @override
  String get pollQuestion => 'La tua domanda';

  @override
  String get commonSending => 'Invio…';

  @override
  String channelPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count post',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String get lockChooseCode => 'Scegli un codice';

  @override
  String get lockCodeRule =>
      'Da 4 a 8 cifre. Il codice non lascia mai questo dispositivo e non può essere recuperato: se lo dimentichi, il blocco si toglie verificando il tuo numero di telefono.';

  @override
  String get lockCode => 'Codice';

  @override
  String get lockConfirmCode => 'Conferma il codice';

  @override
  String get lockTooShort => 'Il codice deve avere almeno 4 cifre.';

  @override
  String get lockMismatch => 'I due codici non corrispondono.';

  @override
  String get lockCurrentCode => 'Codice attuale';

  @override
  String get lockValidate => 'Conferma';

  @override
  String get lockEnabledToast => 'Blocco attivato.';

  @override
  String get lockSaveFailed => 'Impossibile salvare il codice.';

  @override
  String get lockEnterCurrent => 'Inserisci il codice attuale';

  @override
  String get lockWrongCode => 'Codice errato.';

  @override
  String get lockCodeChanged => 'Codice modificato.';

  @override
  String get lockEnterToDisable => 'Inserisci il codice per disattivare';

  @override
  String get lockDisabledToast => 'Blocco disattivato.';

  @override
  String get lockTitle => 'Blocco dell\'app';

  @override
  String get lockByCode => 'Blocca con un codice';

  @override
  String get lockOn => 'Attivo';

  @override
  String get lockOff => 'Disattivo';

  @override
  String get lockChangeCode => 'Cambia il codice';

  @override
  String get lockFootnoteKeystore =>
      'Pokou chiede il codice ogni volta che torna in primo piano. Il codice è conservato nell\'archivio sicuro del sistema (Keystore), non inviato al server: protegge lo schermo, non i dati del dispositivo.';

  @override
  String get lockFootnoteBiometrics =>
      'L\'impronta digitale non è ancora disponibile: richiede una modifica alla configurazione Android (FlutterFragmentActivity e il permesso USE_BIOMETRIC).';

  @override
  String get lockScreenTitle => 'Pokou è bloccato';

  @override
  String get lockEnterToContinue => 'Inserisci il codice per continuare.';

  @override
  String get lockUnlock => 'Sblocca';

  @override
  String get lockForgotQuestion => 'Codice dimenticato?';

  @override
  String get lockSendFailed => 'Invio impossibile: controlla la connessione.';

  @override
  String get lockRemovedToast =>
      'Blocco rimosso. Puoi scegliere un nuovo codice nel Profilo.';

  @override
  String get lockVerifyFailed =>
      'Verifica impossibile: controlla la connessione.';

  @override
  String get lockLogoutQuestion => 'Disconnettersi?';

  @override
  String get lockLogoutBody =>
      'Da usare se non hai più accesso a questo numero. Le conversazioni restano sul server, ma servirà un numero raggiungibile per rientrare.';

  @override
  String get lockLogout => 'Disconnetti';

  @override
  String get lockForgotTitle => 'Codice dimenticato';

  @override
  String get lockNoPhoneOnDevice =>
      'Impossibile trovare il tuo numero su questo dispositivo.';

  @override
  String lockEnterSentCode(String phone) {
    return 'Inserisci il codice inviato a $phone via SMS e WhatsApp.';
  }

  @override
  String lockForgotExplain(String phone) {
    return 'Il codice di blocco è memorizzato solo su questo dispositivo e non può essere recuperato. Per togliere il blocco, verifica il tuo numero $phone.';
  }

  @override
  String get lockLift => 'Togli il blocco';

  @override
  String get lockSendCode => 'Invia un codice';

  @override
  String get lockResendCode => 'Invia di nuovo il codice';

  @override
  String get lockNoAccessToNumber => 'Non ho più accesso a questo numero';

  @override
  String get notifInApp => 'Nell\'app';

  @override
  String get notifMessages => 'Messaggi';

  @override
  String get notifMessagesSub => 'Conversazioni individuali';

  @override
  String get notifMessagesSemantic => 'Notifiche dei messaggi';

  @override
  String get notifGroups => 'Gruppi';

  @override
  String get notifGroupsSub => 'Conversazioni di gruppo';

  @override
  String get notifGroupsSemantic => 'Notifiche dei gruppi';

  @override
  String get notifCallsSub => 'Chiamate audio e video in arrivo';

  @override
  String get notifCallsSemantic => 'Notifiche delle chiamate';

  @override
  String get notifSound => 'Suono e vibrazione';

  @override
  String get notifSoundSemantic => 'Suono delle notifiche';

  @override
  String get notifCallsFootnote =>
      'Disattivare le chiamate qui rimuove solo il banner mostrato quando Pokou è aperto: una chiamata in arrivo continua a squillare a schermo intero, altrimenti perderesti chiamate senza saperlo.';

  @override
  String get notifSystem => 'Sistema';

  @override
  String get notifWebEnable => 'Attiva le notifiche del browser';

  @override
  String get notifWebEnableSub =>
      'Consenti a questo browser di ricevere le notifiche di Pokou.';

  @override
  String get notifWebEnabled => 'Notifiche del browser attivate.';

  @override
  String get notifWebEnableFailed =>
      'Impossibile attivarle. Controlla le impostazioni del sito nel browser.';

  @override
  String get notifAndroidSettings => 'Impostazioni Android';

  @override
  String get notifAndroidSettingsSub =>
      'Autorizzazione, canali, suono per canale';

  @override
  String get notifSystemFootnote =>
      'Quando Pokou è chiuso, è Android a mostrare le notifiche ricevute, senza passare dall\'app: solo le impostazioni di sistema qui sopra possono modificarle.';

  @override
  String get devicesRemoveTitle => 'Rimuovere questo dispositivo?';

  @override
  String get devicesRemoveCurrentBody =>
      'Questo dispositivo non riceverà più notifiche finché non riaprirai Pokou.';

  @override
  String get devicesRemoveOtherBody =>
      'Questo dispositivo non riceverà più notifiche. Resta connesso fino alla prossima disconnessione.';

  @override
  String get devicesRemove => 'Rimuovi';

  @override
  String get devicesRemoveFailed => 'Impossibile rimuovere questo dispositivo.';

  @override
  String get devicesTitle => 'Dispositivi connessi';

  @override
  String get devicesUnavailable =>
      'Elenco non disponibile: controlla la connessione, poi tira per aggiornare.';

  @override
  String get devicesEmpty =>
      'Nessun dispositivo registrato per le notifiche. Si attivano alla prima apertura di Pokou su un dispositivo.';

  @override
  String get devicesThisDevice => ' · questo dispositivo';

  @override
  String devicesLastSeen(String date, String hint) {
    return 'Attivo il $date · …$hint';
  }

  @override
  String get devicesFootnote =>
      'Un dispositivo compare qui non appena si registra per le notifiche push. Rimuoverlo interrompe le sue notifiche; non chiude la sessione, che scade da sola.';

  @override
  String get devicesBrowser => 'Browser';

  @override
  String devicesTodayAt(String time) {
    return 'oggi alle $time';
  }

  @override
  String get storageNoCachedMedia => 'Nessun media in cache.';

  @override
  String storageFilesCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file rimossi dalla cache.',
      one: '1 file rimosso dalla cache.',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Archiviazione e dati';

  @override
  String get storageCachedMedia => 'Media in cache';

  @override
  String get storageMediaLabel => 'Foto, video e note vocali';

  @override
  String get storageComputing => 'Calcolo in corso…';

  @override
  String get storageNoFile => 'Nessun file';

  @override
  String storageFileCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
      one: '1 file',
    );
    return '$_temp0 · $size';
  }

  @override
  String get storageClearCache => 'Svuota la cache';

  @override
  String get storageClearFootnote =>
      'I file svuotati vengono riscaricati su richiesta quando riapri la conversazione: non si perde nulla, si libera solo spazio.';

  @override
  String get storageMobileData => 'Dati mobili';

  @override
  String get storageDataSaver => 'Risparmio dati';

  @override
  String get storageDataSaverSub => 'Non scaricare i media automaticamente';

  @override
  String get storageDataSaverFootnote =>
      'Se attivo, foto e video ricevuti aspettano che tu li tocchi per scaricarsi, e le foto che invii vengono compresse di più.';

  @override
  String get profileAvatarFailed =>
      'Impossibile aggiornare la foto del profilo.';

  @override
  String get profileChooseMonitor => 'Scegli un monitor';

  @override
  String get profileBabaMessaging => 'Messaggeria Baba';

  @override
  String profileMonitorAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avvisi di $count monitor',
      one: 'Avvisi di 1 monitor',
    );
    return '$_temp0';
  }

  @override
  String get profileBabaAssistant => 'Assistente Baba';

  @override
  String get profileShieldModeBody =>
      'Mette in attesa le chiamate e attenua le conversazioni non prioritarie mentre sei concentrato. I contatti etichettati Business, Cliente, Fornitore o Capo passano sempre.';

  @override
  String get contactConnectFailed => 'Connessione impossibile.';

  @override
  String get contactCallFailed => 'Chiamata non possibile al momento.';

  @override
  String contactBlockTitle(String name) {
    return 'Bloccare $name?';
  }

  @override
  String get contactBlockBody =>
      'Questa persona non potrà più scriverti né chiamarti. Non ne sarà informata.';

  @override
  String get contactActionFailed => 'Azione non possibile al momento.';

  @override
  String get contactSavedToast => 'Contatto salvato';

  @override
  String get contactCall => 'Chiamata';

  @override
  String get contactSharedTitle => 'Elementi condivisi';

  @override
  String get contactSharedMedia => 'Media';

  @override
  String get contactSharedDocuments => 'Documenti';

  @override
  String get contactSharedLinks => 'Link';

  @override
  String get contactNoMedia => 'Nessuna foto o video condivisi.';

  @override
  String get contactNoDocuments => 'Nessun documento condiviso.';

  @override
  String get contactNoLinks => 'Nessun link condiviso.';

  @override
  String contactCommonGroups(int count) {
    return 'Gruppi in comune ($count)';
  }

  @override
  String contactCatalog(int count) {
    return 'Catalogo ($count)';
  }

  @override
  String contactUnblockName(String name) {
    return 'Sblocca $name';
  }

  @override
  String contactBlockName(String name) {
    return 'Blocca $name';
  }

  @override
  String get contactUnblockHint =>
      'Questa persona può scriverti e chiamarti di nuovo.';

  @override
  String get contactBlockHint =>
      'Non potrà più scriverti né chiamarti, e non ne sarà informata.';

  @override
  String get adNeedTitleBody =>
      'Dai un titolo e un messaggio alla tua pubblicità.';

  @override
  String get adSendFailed => 'Impossibile inviare la richiesta.';

  @override
  String get adCreateTitle => 'Crea una pubblicità';

  @override
  String get adWhoSeesTitle => 'Chi la vedrà';

  @override
  String get adWhoSeesBody =>
      'Tutti gli utenti di Pokou Messenger nella scheda Mercato, o tra due stati: scegli tu.';

  @override
  String get adReviewTitle => 'Una revisione prima della diffusione';

  @override
  String get adReviewBody =>
      'Il nostro team legge ogni campagna prima che parta. Calcola qualche ora.';

  @override
  String get adCountdownTitle =>
      'Il conto alla rovescia parte dall\'approvazione';

  @override
  String get adCountdownBody =>
      'I giorni di diffusione iniziano quando la campagna è accettata, non al pagamento.';

  @override
  String get adRefundTitle => 'Rifiutata? Ti rimborsiamo';

  @override
  String get adRefundBody =>
      'Se la campagna non può essere diffusa, contattaci: l\'importo ti viene restituito.';

  @override
  String get adTitleHint => 'Es.: Cemento CIMTOGO in promozione';

  @override
  String get adBodyHint => 'Cosa proponi e come contattarti.';

  @override
  String get adMediaLabel => 'Foto o video (facoltativo)';

  @override
  String get adMediaHint =>
      'Un video di massimo 30 secondi. Senza immagine, viene diffuso solo il testo.';

  @override
  String get adVideo30s => 'Video 30 s';

  @override
  String get adPlacement => 'Posizionamento';

  @override
  String get adPlacementMarket => 'Scheda Mercato';

  @override
  String get adPlacementStatus => 'Tra gli stati';

  @override
  String get adDuration => 'Durata';

  @override
  String get adOneWeek => '1 settimana';

  @override
  String get adTwoWeeks => '2 settimane';

  @override
  String get adOneMonth => '1 mese';

  @override
  String get adPayCaption => 'Pagamento Mobile Money';

  @override
  String get adPayAction => 'Paga e invia';

  @override
  String productInterestedMessage(String name, String price, String currency) {
    return 'Buongiorno, sono interessato al tuo $name a $price $currency. È disponibile?';
  }

  @override
  String get productWriteFailed =>
      'Impossibile scrivere al venditore al momento.';

  @override
  String get productCallFirstWrite => 'Chiamata impossibile: scrivigli prima.';

  @override
  String get productRateSeller => 'Valuta questo venditore';

  @override
  String get productEditReview => 'Modifica la mia recensione';

  @override
  String get productReviewScope =>
      'La recensione riguarda il VENDITORE, non un prodotto: conta la fiducia nella persona, e resta anche se l\'articolo lascia il catalogo.';

  @override
  String get productReviewHint => 'Il tuo commento (facoltativo)';

  @override
  String get productDeleteReview => 'Elimina la mia recensione';

  @override
  String get productReviewFailed => 'Recensione non salvata.';

  @override
  String get productTitle => 'Prodotto';

  @override
  String get productOpening => 'Apertura…';

  @override
  String get productDiscuss => 'Chatta';

  @override
  String get productCallAction => 'Chiama';

  @override
  String get productReviews => 'Recensioni';

  @override
  String get productNoReviewYet => 'Ancora nessuna recensione';

  @override
  String productRatingSummary(String rating, int reviews) {
    String _temp0 = intl.Intl.pluralLogic(
      reviews,
      locale: localeName,
      other: '$reviews recensioni',
      one: '1 recensione',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String productCountSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prodotti',
      one: '1 prodotto',
    );
    return ' · $_temp0';
  }

  @override
  String get productCertified => 'Account verificato dal team Pokou.';

  @override
  String get productReviewMine => 'Tu';

  @override
  String get verifNeedDocument =>
      'Aggiungi una foto del tuo documento d\'identità.';

  @override
  String get verifTitle => 'Diventa venditore verificato';

  @override
  String get verifBadgeTitle => 'Un badge blu sui tuoi annunci';

  @override
  String get verifBadgeBody =>
      'Gli acquirenti vedono che la tua identità è stata verificata dal nostro team.';

  @override
  String get verifWhyTitle => 'Perché cambia tutto';

  @override
  String get verifWhyBody =>
      'Un acquirente invia denaro Mobile Money più volentieri a qualcuno con identità confermata che a uno sconosciuto.';

  @override
  String get verifNeedTitle => 'Cosa devi fornire';

  @override
  String get verifNeedBody =>
      'Una foto nitida della carta d\'identità, del passaporto o della patente. Il nome deve essere leggibile.';

  @override
  String get verifUseTitle => 'Cosa ne facciamo';

  @override
  String get verifUseBody =>
      'È letta dal nostro team solo per la verifica, non compare mai sul tuo profilo e non viene mostrata a nessun acquirente.';

  @override
  String get verifOneYearTitle => 'Valido un anno';

  @override
  String get verifOneYearBody =>
      'Il badge dura dodici mesi. Calcola qualche giorno per l\'esame della richiesta.';

  @override
  String get verifDocumentLabel => 'Il tuo documento d\'identità';

  @override
  String get verifPayCaption => 'Pagamento Mobile Money · 1 anno';

  @override
  String get verifChoosePhoto => 'Scegli una foto';

  @override
  String get verifChange => 'Cambia';

  @override
  String get marketRemoveBody =>
      'L\'annuncio sparisce dal mercato. Le conversazioni a riguardo restano leggibili e gli acquirenti che l\'hanno già ricevuto mantengono la cronologia.';

  @override
  String get marketRemoveFailed => 'Impossibile rimuovere l\'annuncio.';

  @override
  String get marketImageFailed => 'Immagine non inviata: riprova.';

  @override
  String get marketMainPhotoHint =>
      'È quella che illustra il prodotto nell\'elenco.';

  @override
  String get marketName => 'Nome';

  @override
  String get marketPrice => 'Prezzo';

  @override
  String get marketNoReviewYet => 'ancora nessuna recensione';

  @override
  String get marketSearchHint => 'Cerca un prodotto…';

  @override
  String get callLogEmpty => 'Ancora nessuna chiamata.';

  @override
  String get callLogUnknownUser => 'Utente';

  @override
  String get callStatusMissed => 'Persa';

  @override
  String get callStatusNoAnswer => 'Senza risposta';

  @override
  String get callStatusDeclined => 'Rifiutata';

  @override
  String get callStatusReceived => 'Ricevuta';

  @override
  String get callStatusEnded => 'Terminata';

  @override
  String get callStatusOngoing => 'In corso';

  @override
  String get callStatusOutgoing => 'Chiamata';

  @override
  String get callVideoTitle => 'Videochiamata';

  @override
  String get callAudioTitle => 'Chiamata audio';

  @override
  String callRedialQuestion(String name) {
    return 'Richiamare $name?';
  }

  @override
  String get callJoinFailed => 'Impossibile connettersi alla chiamata.';

  @override
  String get callNobodyToAdd => 'Nessun altro da aggiungere.';

  @override
  String get callAddToCall => 'Aggiungi alla chiamata';

  @override
  String get callAdd => 'Aggiungi';

  @override
  String get callAddFailed => 'Impossibile aggiungere questo partecipante.';

  @override
  String get callReactionFailed => 'Impossibile inviare questa reazione.';

  @override
  String get callLeaveConfirmTitle => 'Uscire dalla chiamata?';

  @override
  String get callLeaveConfirmBody =>
      'Gli altri partecipanti potrebbero stare ancora parlando. Puoi chiudere questa schermata senza riagganciare e tornare dall\'avviso della chiamata.';

  @override
  String get callYou => 'Tu';

  @override
  String get callContact => 'Contatto';

  @override
  String get callConnecting => 'Connessione alla chiamata…';

  @override
  String get callPreparing => 'La chiamata è in preparazione';

  @override
  String get callWaiting => 'In attesa…';

  @override
  String get callJoinImpossible => 'Impossibile unirsi alla chiamata.';

  @override
  String get callEncryptedJoinFailed =>
      'Questa chiamata cifrata non può essere aperta su questo telefono. Chi chiama è stato avvisato.';

  @override
  String get callIncoming => 'Chiamata in arrivo';

  @override
  String callIncomingFrom(String name) {
    return '$name ti sta chiamando';
  }

  @override
  String get callIncomingGroup => 'Chiamata di gruppo in arrivo';

  @override
  String get streakSubtitle =>
      'Un giorno saltato, pochi minuti per recuperarlo';

  @override
  String get streakUnavailable => 'Serie non disponibili';

  @override
  String get streakCheckConnection => 'Controlla la connessione e riprova.';

  @override
  String get streakEmptyTitle => 'Ancora nessuna serie';

  @override
  String get streakEmptyBody =>
      'Scambia un messaggio ogni giorno con la stessa persona: la serie parte dal primo scambio.';

  @override
  String get streakToRescue => 'Da salvare ora';

  @override
  String get streakToRescueSub =>
      'Scaduto il termine, la serie riparte da zero';

  @override
  String get streakMine => 'Le mie serie';

  @override
  String get streakRunning => 'In corso';

  @override
  String streakRecord(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: '1 giorno',
    );
    return 'Record: $_temp0';
  }

  @override
  String get streakLongest => 'La tua serie più lunga';

  @override
  String get streakRestorePending =>
      'La tua serie riprenderà non appena il pagamento sarà confermato.';

  @override
  String get streakDeadlinePassed => 'Il termine potrebbe essere scaduto.';

  @override
  String streakBroken(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Serie di $days giorni interrotta',
      one: 'Serie di 1 giorno interrotta',
    );
    return '$_temp0';
  }

  @override
  String get streakExpired => 'Il termine è scaduto. La serie riparte da zero.';

  @override
  String streakCountdown(String time) {
    return 'Restano $time per salvarla';
  }

  @override
  String streakRescueAction(int amount) {
    return 'Salva la serie — $amount FCFA';
  }

  @override
  String get leagueSubtitle => 'La tua lega sale con ciò che ricevi';

  @override
  String get leagueUnavailable => 'Classifica non disponibile';

  @override
  String get leagueRanking => 'Classifica';

  @override
  String get leagueProtectPending =>
      'La tua protezione sarà attiva non appena il pagamento sarà confermato.';

  @override
  String get leaguePaymentFailed => 'Impossibile avviare il pagamento.';

  @override
  String get leagueAtTop => 'Sei in cima alla classifica.';

  @override
  String leaguePointsNeeded(int points, String label) {
    return 'Ancora $points punti per $label.';
  }

  @override
  String get leagueProtected =>
      'I tuoi punti sono protetti. Questa settimana non cala nulla.';

  @override
  String get leagueDecayNow => 'I tuoi punti calano al prossimo passaggio.';

  @override
  String leagueDecayIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'I tuoi punti calano tra $days giorni senza attività.',
      one: 'I tuoi punti calano tra 1 giorno senza attività.',
    );
    return '$_temp0';
  }

  @override
  String get leagueProtectAction => 'Proteggi i miei punti — 500 FCFA';

  @override
  String get leagueNobodyRanked =>
      'Nessuno è ancora in classifica. Sii il primo.';

  @override
  String leagueMyRank(int rank, int points) {
    return 'Sei $rankº con $points punti.';
  }

  @override
  String get reactWith => 'Reagisci con…';

  @override
  String get reactPickEmoji => 'Scegli un\'emoji sulla tastiera';

  @override
  String get reactAction => 'Reagisci';

  @override
  String get mediaPoll => 'Sondaggio';

  @override
  String get mediaContact => 'Contatto';

  @override
  String get mediaSharedContact => 'Contatto condiviso';

  @override
  String get convEdited => '· modificato';

  @override
  String get convFallbackName => 'Conversazione';

  @override
  String get convSomeone => 'Qualcuno';

  @override
  String get contactsTagFailed => 'Impossibile aggiornare l\'etichetta.';

  @override
  String get contactsTag => 'Etichetta';

  @override
  String get contactsTitle => 'Contatti';

  @override
  String get contactsTyping => 'sta scrivendo…';

  @override
  String contactsTypingNamed(String name) {
    return '$name sta scrivendo…';
  }

  @override
  String contactsPreviewMine(String preview) {
    return 'Tu: $preview';
  }

  @override
  String contactsPreviewSender(String name, String preview) {
    return '$name: $preview';
  }

  @override
  String contactsNotInContacts(String preview) {
    return '$preview · non è nei tuoi contatti';
  }

  @override
  String get contactsAssistantSub => 'Il tuo assistente IA';

  @override
  String get addContactTitle => 'Aggiungi un contatto';

  @override
  String get addContactName => 'Nome';

  @override
  String get addContactAction => 'Aggiungi';

  @override
  String get joinLinkTitle => 'Unisciti tramite link';

  @override
  String get joinLinkBody =>
      'Incolla il link che ti è stato inviato. Gruppo o comunità, lo riconosciamo.';

  @override
  String get joinLinkContinue => 'Continua';

  @override
  String get joinLinkUnreadable => 'Link d\'invito illeggibile.';

  @override
  String joinAlreadyMember(String name) {
    return 'Sei già in «$name».';
  }

  @override
  String joinGroupQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partecipanti',
      one: '1 partecipante',
    );
    return '$_temp0. Unirsi a questo gruppo?';
  }

  @override
  String get joinAction => 'Unisciti';

  @override
  String get joinGroupFailed => 'Impossibile unirsi a questo gruppo.';

  @override
  String joinCommunityCounts(int members, int groups) {
    String _temp0 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members membri',
      one: '1 membro',
    );
    String _temp1 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups gruppi',
      one: '1 gruppo',
    );
    return '$_temp0 · $_temp1.';
  }

  @override
  String get joinCommunityBody =>
      'Riceverai i suoi annunci. Agli altri gruppi devi unirti uno per uno.';

  @override
  String get joinCommunityFailed => 'Impossibile unirsi a questa comunità.';

  @override
  String get newChatOwnNumber => 'È il tuo stesso numero.';

  @override
  String get phoneLookupFailed => 'Numero non valido o verifica impossibile.';

  @override
  String get phoneNotOnPokou => 'Questo numero non usa ancora Pokou.';

  @override
  String get phoneInviteWhatsApp => 'Invita su WhatsApp';

  @override
  String get phoneInviteText =>
      'Ciao! Ti invito a provare Pokou, una messaggeria privata: scarica l\'app e aggiungimi.';

  @override
  String get contactCardTitle => 'Biglietto da visita';

  @override
  String get viewOnceSeen => 'Visualizzata';

  @override
  String get viewOnceTapToSee => 'Visualizzazione unica: tocca per vedere';

  @override
  String get audioPlayFailed => 'Riproduzione impossibile';

  @override
  String mediaPhotoSize(Object size) {
    return 'Foto · $size';
  }

  @override
  String get mediaTapToDownload => 'Tocca per scaricare';

  @override
  String get mediaVideoUnavailable => 'Video non disponibile';

  @override
  String get mediaOpenDocFailed => 'Impossibile aprire questo documento.';

  @override
  String get mediaOpenRetry => 'Apertura fallita: tocca per riprovare';

  @override
  String get dayToday => 'Oggi';

  @override
  String get dayYesterday => 'Ieri';

  @override
  String get weekdayMonday => 'lunedì';

  @override
  String get weekdayTuesday => 'martedì';

  @override
  String get weekdayWednesday => 'mercoledì';

  @override
  String get weekdayThursday => 'giovedì';

  @override
  String get weekdayFriday => 'venerdì';

  @override
  String get weekdaySaturday => 'sabato';

  @override
  String get weekdaySunday => 'domenica';

  @override
  String liveHoursLeft(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'mancano $hours h',
      one: 'manca 1 h',
    );
    return '$_temp0';
  }

  @override
  String liveMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'mancano $minutes min',
      one: 'manca 1 min',
    );
    return '$_temp0';
  }

  @override
  String get liveAlmostOver => 'quasi finito';

  @override
  String liveLocation(String remaining) {
    return 'In diretta · $remaining';
  }

  @override
  String get openInMaps => 'Apri in Maps';

  @override
  String get composerEditPhoto => 'Modifica la foto';

  @override
  String get composerEditorFailed => 'L\'editor non si è aperto.';

  @override
  String get composerCropRotate => 'Ritaglia o ruota';

  @override
  String get composerCaptionHint => 'Aggiungi una didascalia…';

  @override
  String composerTo(String name) {
    return 'a $name';
  }

  @override
  String get composerSend => 'Invia';

  @override
  String get convOfflineNotCached =>
      'Offline: questa conversazione non è ancora in memoria.';

  @override
  String get convLoadFailed => 'Impossibile caricare la conversazione.';

  @override
  String get convEmptyEdit => 'Un messaggio vuoto non può sostituire un testo.';

  @override
  String get convEditFailed =>
      'Modifica impossibile: controlla la connessione.';

  @override
  String get convOrderUpdateFailed => 'Impossibile aggiornare l\'ordine.';

  @override
  String get convDeleteFailed => 'Impossibile eliminare il messaggio.';

  @override
  String get convForwardFailedMsg => 'Impossibile inoltrare il messaggio.';

  @override
  String get convOfflineAttachment =>
      'Offline: gli allegati richiedono una connessione.';

  @override
  String get convAttachmentFailed => 'Allegato non inviato: riprova.';

  @override
  String get groupOfflineNotCached =>
      'Offline: questo gruppo non è ancora in memoria.';

  @override
  String get groupLoadFailed => 'Impossibile caricare il gruppo.';

  @override
  String get groupRenameFailed => 'Impossibile rinominare il gruppo.';

  @override
  String get groupPhotoFailed => 'Foto del gruppo non salvata.';

  @override
  String get groupClearPhotoFailed => 'Impossibile rimuovere la foto.';

  @override
  String get groupRoleFailed => 'Impossibile cambiare questo ruolo.';

  @override
  String get groupInviteCreateFailed => 'Impossibile creare il link d\'invito.';

  @override
  String get groupInviteRevokeFailed => 'Impossibile disattivare il link.';

  @override
  String get groupLeaveFailed => 'Impossibile lasciare il gruppo.';

  @override
  String get groupRemoveMemberFailed => 'Impossibile rimuovere questo membro.';

  @override
  String get apiNetworkSilent => 'La rete non risponde';

  @override
  String apiError(int code) {
    return 'Errore ($code)';
  }

  @override
  String get orderProductDiscussed => 'Articolo in discussione';

  @override
  String get orderValidate => 'Conferma l\'ordine';

  @override
  String get orderMarkShipped => 'Segna come spedito';

  @override
  String get orderMarkDelivered => 'Segna come consegnato';

  @override
  String get orderBuyerWaiting => 'Questo acquirente attende la tua risposta.';

  @override
  String get orderNextStep => 'Prossimo passo dell\'ordine.';

  @override
  String get msgNotSentRetry => 'Non inviato: tocca per riprovare';

  @override
  String get msgPendingSend => 'In attesa di invio';

  @override
  String convSearchHint(String name) {
    return 'Cerca in $name…';
  }

  @override
  String get convSearchPrompt =>
      'Digita una parola per ritrovare un messaggio di questa conversazione.';

  @override
  String get convSearchEmpty => 'Nessun messaggio trovato.';

  @override
  String get commonUnknownName => 'Sconosciuto';

  @override
  String get groupInviteLink => 'Link d\'invito';

  @override
  String get groupDemoteAdmin => 'Rimuovi l\'amministrazione';

  @override
  String get groupPromoteAdmin => 'Nomina amministratore';

  @override
  String get groupInviteLinkBody =>
      'Chiunque apra questo link entra direttamente nel gruppo, senza altri passaggi. Rigeneralo per invalidare quello già condiviso.';

  @override
  String get groupNewLinkCreated =>
      'Nuovo link creato: il precedente non funziona più.';

  @override
  String get groupAddFailed => 'Impossibile aggiungere.';

  @override
  String get groupCreateFailed => 'Impossibile creare il gruppo.';

  @override
  String get groupNewTitle => 'Nuovo gruppo';

  @override
  String get groupCreateAction => 'Crea';

  @override
  String get groupNameHint => 'Nome del gruppo';

  @override
  String get groupPickParticipants => 'Scegli i partecipanti';

  @override
  String groupSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partecipanti selezionati',
      one: '1 partecipante selezionato',
    );
    return '$_temp0';
  }

  @override
  String get pushIncomingVideoCall => 'Videochiamata in arrivo';

  @override
  String get pushIncomingAudioCall => 'Chiamata audio in arrivo';

  @override
  String get pushAnswer => 'Rispondi';

  @override
  String get pushDecline => 'Rifiuta';

  @override
  String get pushMessagesChannel => 'Messaggi';

  @override
  String get pushMessagesChannelDesc => 'Notifiche per i nuovi messaggi Pokou';

  @override
  String get pushCallsChannel => 'Chiamate';

  @override
  String get pushCallsChannelDesc =>
      'Notifiche per le chiamate Pokou in arrivo';

  @override
  String get pushGroupFallback => 'Gruppo';

  @override
  String get notifNewMessage => 'Nuovo messaggio';

  @override
  String get notifPhoto => '📷 Foto';

  @override
  String get notifVideo => '🎥 Video';

  @override
  String get notifVoice => '🎤 Messaggio vocale';

  @override
  String get notifDocument => '📄 Documento';

  @override
  String get notifSticker => 'Sticker';

  @override
  String get notifLocation => '📍 Posizione';

  @override
  String get notifContact => '👤 Contatto';

  @override
  String get notifPoll => '📊 Sondaggio';

  @override
  String get notifMe => 'Io';

  @override
  String get notifReply => 'Rispondi';

  @override
  String get notifReplyHint => 'Il tuo messaggio';

  @override
  String get notifMarkRead => 'Segna come letto';

  @override
  String get notifReplyQueued => 'invio all\'apertura di Pokou';

  @override
  String get notifReplyFailed =>
      'Risposta non inviata: apri Pokou per riprovare';

  @override
  String notifSummary(int count, int conversations) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messaggi',
      one: '1 messaggio',
    );
    String _temp1 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations conversazioni',
      one: '1 conversazione',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get audienceContacts => 'I miei contatti';

  @override
  String get audienceNobody => 'Nessuno';

  @override
  String get audienceExcept => 'I miei contatti tranne…';

  @override
  String get audienceOnly => 'Solo…';

  @override
  String get audienceContactsDesc => 'Tutte le persone della tua rubrica Pokou';

  @override
  String get audienceNobodyDesc => 'I tuoi stati saranno visibili solo a te';

  @override
  String get audienceExceptDesc => 'I tuoi contatti, tranne quelli che scegli';

  @override
  String get audienceOnlyDesc => 'Solo le persone che scegli';

  @override
  String get statusViewerFallback => 'Utente';

  @override
  String get statusPrivacySaved => 'Visibilità salvata.';

  @override
  String get statusPrivacySaveFailed =>
      'Salvataggio impossibile: controlla la connessione.';

  @override
  String get statusPrivacyTitle => 'Visibilità degli stati';

  @override
  String get statusExcludePeople => 'Persone da escludere';

  @override
  String get statusAllowedPeople => 'Persone autorizzate';

  @override
  String get statusNoContactToOffer =>
      'Nessun contatto Pokou da proporre al momento.';

  @override
  String get statusExceptFootnote =>
      'Queste persone non vedranno i tuoi stati, anche se sono nei tuoi contatti.';

  @override
  String get statusOnlyFootnote =>
      'Solo queste persone vedranno i tuoi stati. Non serve che ti abbiano tra i contatti.';

  @override
  String get status24hFootnote =>
      'Uno stato sparisce comunque dopo 24 ore, per tutti.';

  @override
  String get statusGallery => 'Galleria';

  @override
  String get statusCamera => 'Fotocamera';

  @override
  String get statusNewTitle => 'Nuovo stato';

  @override
  String get statusText => 'Testo';

  @override
  String get statusTypeHint => 'Scrivi il tuo stato…';

  @override
  String get statusPublish => 'Pubblica';

  @override
  String get statusFeedTitle => 'Novità';

  @override
  String get statusFeedUnavailable => 'Stati non disponibili: riprova';

  @override
  String get statusSection => 'Stati';

  @override
  String get statusMine => 'Io';

  @override
  String get channelsSection => 'Canali';

  @override
  String get bcastNeedName => 'Dai un nome a questa lista.';

  @override
  String get bcastNeedRecipient => 'Scegli almeno un destinatario.';

  @override
  String get bcastSaveFailed => 'Salvataggio impossibile.';

  @override
  String get bcastNewTitle => 'Nuova diffusione';

  @override
  String get bcastEditTitle => 'Modifica la lista';

  @override
  String get bcastNameHint => 'Nome della lista (visibile solo a te)';

  @override
  String get bcastNoRecipient => 'Nessun destinatario';

  @override
  String bcastRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destinatari',
      one: '1 destinatario',
    );
    return '$_temp0';
  }

  @override
  String get bcastContactsUnavailable => 'Contatti non disponibili.';

  @override
  String get bcastNobodyOnPokou =>
      'Nessuno dei tuoi contatti è ancora su Pokou Messenger.';

  @override
  String get bcastNewList => 'Nuova lista';

  @override
  String get bcastListsTitle => 'Liste di diffusione';

  @override
  String get bcastListsUnavailable => 'Liste non disponibili.';

  @override
  String bcastDeleteTitle(String name) {
    return 'Eliminare «$name»?';
  }

  @override
  String get bcastDeleteBody =>
      'I messaggi già inviati restano ai destinatari. Sparisce solo la lista.';

  @override
  String get bcastEmptyTitle => 'Annuncia una volta, a molti';

  @override
  String get bcastEmptyBody =>
      'Ogni destinatario riceve il messaggio nella sua conversazione privata. Non vede gli altri e risponde solo a te, al contrario di un gruppo, dove tutti si vedono.';

  @override
  String bcastSentTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Inviato a $count destinatari.',
      one: 'Inviato a 1 destinatario.',
    );
    return '$_temp0';
  }

  @override
  String bcastSentPartly(int sent, int total, int skipped) {
    return 'Inviato a $sent su $total: $skipped non ricevono più i tuoi messaggi.';
  }

  @override
  String get bcastSendFailed => 'L\'invio è fallito.';

  @override
  String get bcastEditRecipients => 'Modifica i destinatari';

  @override
  String get bcastHistoryUnavailable => 'Cronologia non disponibile.';

  @override
  String get bcastNothingSent => 'Non è stato ancora diffuso nulla.';

  @override
  String get bcastMessageHint => 'Messaggio da diffondere';

  @override
  String get bcastPrivacyNotice =>
      'Ogni destinatario riceve questo messaggio in privato. Non vede gli altri, e la sua risposta ti arriva nella conversazione con lui.';

  @override
  String get channelNameRequired => 'Il nome del canale è obbligatorio.';

  @override
  String get channelSaveFailed => 'Impossibile salvare il canale.';

  @override
  String get channelEditTitle => 'Modifica il canale';

  @override
  String get channelNewTitle => 'Nuovo canale';

  @override
  String get channelAddImage => 'Aggiungi un\'immagine';

  @override
  String get channelChangeImage => 'Cambia l\'immagine';

  @override
  String get channelRemoveImage => 'Rimuovi l\'immagine';

  @override
  String get channelNameLabel => 'Nome del canale';

  @override
  String get channelNameHint => 'Es.: Novità della mia azienda';

  @override
  String get channelDescriptionLabel => 'Descrizione';

  @override
  String get channelDescriptionHint => 'Presenta il tuo canale';

  @override
  String get channelSaveChanges => 'Salva le modifiche';

  @override
  String get channelCreateAction => 'Crea il canale';

  @override
  String get channelLinkCopiedClipboard => 'Link copiato negli appunti.';

  @override
  String get channelLinkUnavailableShort => 'Link non disponibile.';

  @override
  String get channelSearchTooltip => 'Cerca un canale';

  @override
  String get channelCreateTooltip => 'Crea un canale';

  @override
  String get channelEmptyHint =>
      'Crea un canale per condividere le tue novità.';

  @override
  String get channelGenerateLink => 'Genera un link';

  @override
  String get channelEditTooltip => 'Modifica';

  @override
  String get channelSearchHint => 'Cerca un canale…';

  @override
  String get channelSearchPrompt =>
      'Cerca per nome o descrizione. I canali verificati compaiono per primi.';

  @override
  String get channelSearchEmpty => 'Nessun canale trovato.';

  @override
  String get channelNothingPublishedAdmin =>
      'Ancora nulla pubblicato: tocca + per il tuo primo post.';

  @override
  String get channelNothingPublished =>
      'Questo canale non ha ancora pubblicato nulla.';

  @override
  String get channelFollow => 'Segui';

  @override
  String get channelFallbackName => 'Canale';

  @override
  String get communityNewTitle => 'Nuova comunità';

  @override
  String get communityNewBody =>
      'Una comunità riunisce più gruppi attorno alle stesse persone. Con essa nasce un gruppo «Annunci»: ci scrivi solo tu, tutti i suoi membri leggono.';

  @override
  String get communityNameHint => 'Nome della comunità';

  @override
  String get communityDescriptionHint => 'Descrizione (facoltativa)';

  @override
  String get communityCreateAction => 'Crea';

  @override
  String get communityCreateFailed => 'Creazione impossibile.';

  @override
  String get communityNoGroupToAttach =>
      'Non hai altri gruppi da collegare. Solo i gruppi che amministri possono entrare in una comunità.';

  @override
  String get communityAddGroupFailed => 'Impossibile aggiungere questo gruppo.';

  @override
  String get communityLinkFailed => 'Impossibile creare il link.';

  @override
  String get communityCreateLink => 'Crea un link';

  @override
  String get sparkOpenRoomsSub => 'Si chiudono da sole';

  @override
  String get sparkMore => 'Altro';

  @override
  String sparkRoomOpen(String time) {
    return 'Stanza aperta — $time';
  }

  @override
  String get sparkBothYes => 'Avete detto sì entrambi';

  @override
  String get sparkMatchSaved => 'Match salvato';

  @override
  String get sparkRoomClosed => 'Stanza chiusa';

  @override
  String get sparkMatch => 'Match';

  @override
  String get sparkUnavailable => 'Spark non è disponibile';

  @override
  String get sparkTodaysDate => 'L\'appuntamento di oggi';

  @override
  String get sparkTabOutings => 'Uscite';

  @override
  String sparkPersonAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String get aiSuggestSummary => 'Riepilogo';

  @override
  String get aiSuggestSummarySub => 'Una panoramica rapida';

  @override
  String get aiSuggestSummaryPrompt =>
      'Fammi un riepilogo della situazione attuale.';

  @override
  String get aiSuggestTrend => 'Tendenza';

  @override
  String get aiSuggestTrendSub => 'Analizza un\'evoluzione';

  @override
  String get aiSuggestTrendPrompt =>
      'Qual è la tendenza degli ultimi 7 giorni?';

  @override
  String get aiSuggestAlerts => 'Avvisi';

  @override
  String get aiSuggestAlertsSub => 'Ultimi segnali';

  @override
  String get aiSuggestAlertsPrompt => 'Ci sono avvisi recenti da conoscere?';

  @override
  String get aiSuggestAdvice => 'Consiglio';

  @override
  String get aiSuggestAdviceSub => 'Chiedi un\'idea';

  @override
  String get aiSuggestAdvicePrompt =>
      'Dammi un consiglio per organizzare la giornata.';

  @override
  String get aiSuggestWrite => 'Scrivere';

  @override
  String get aiSuggestWriteSub => 'Scrivere un testo';

  @override
  String get aiSuggestWritePrompt => 'Aiutami a scrivere un messaggio.';

  @override
  String get aiSuggestQuestion => 'Domanda';

  @override
  String get aiSuggestQuestionSub => 'Qualsiasi cosa';

  @override
  String get aiSuggestQuestionPrompt => 'Ho una domanda da farti.';

  @override
  String get aiMessageHint => 'Messaggio…';

  @override
  String get aiHowCanIHelp => 'Come posso aiutarti?';

  @override
  String get aiAskAnything => 'Chiedimi qualsiasi cosa.';

  @override
  String get aiAskAboutData => 'Fai una domanda sui tuoi dati collegati.';

  @override
  String get aiThinking => 'Baba sta pensando';

  @override
  String aiHelloIm(String name) {
    return 'Ciao, sono $name';
  }

  @override
  String get aiPartner => 'Il tuo partner digitale';

  @override
  String get aiGreetMorning => 'Buongiorno';

  @override
  String get aiGreetAfternoon => 'Buon pomeriggio';

  @override
  String get aiGreetEvening => 'Buonasera';

  @override
  String get aiNewChat => 'Nuova conversazione';

  @override
  String get aiCopy => 'Copia';

  @override
  String get aiCopied => 'Copiato';

  @override
  String get aiGenerated => 'Generato dall\'IA';

  @override
  String get aiVoiceListening => 'Ti ascolto…';

  @override
  String get aiVoiceTranscribing => 'Trascrizione…';

  @override
  String get aiVoiceFailed => 'Non sono riuscito a sentirti. Riprova.';

  @override
  String get aiVoiceSpeak => 'Parla con l\'assistente';

  @override
  String get aiVoiceRestart => 'Ricomincia';

  @override
  String get aiVoiceSend => 'Invia';

  @override
  String get aiVoiceStop => 'Fine';

  @override
  String get aiSendFailed => 'Messaggio non inviato: riprova.';

  @override
  String get digestTitle => 'Riepilogo del giorno';

  @override
  String get digestUnread => 'Messaggi non letti:';

  @override
  String get digestMissedCalls => 'Chiamate perse:';

  @override
  String get digestVideoSuffix => ' (video)';

  @override
  String digestShieldDeferred(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messaggi trattenuti dalla Modalità Scudo.',
      one: '1 messaggio trattenuto dalla Modalità Scudo.',
    );
    return '$_temp0';
  }

  @override
  String digestMonitorSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segnali dai tuoi monitor da consultare.',
      one: '1 segnale dai tuoi monitor da consultare.',
    );
    return '$_temp0';
  }

  @override
  String get digestNothing => 'Niente da segnalare oggi — buona serata!';

  @override
  String get shieldUnknownNumber => 'Numero sconosciuto';

  @override
  String shieldFlushSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messaggi trattenuti durante la riunione.',
      one: '1 messaggio trattenuto durante la riunione.',
    );
    return '$_temp0';
  }

  @override
  String get shieldPendingMessages => 'Messaggi in attesa';

  @override
  String shieldHandleSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count messaggi trattenuti dalla Modalità Scudo: scorri verso il basso per mostrarli',
      one:
          '1 messaggio trattenuto dalla Modalità Scudo: scorri verso il basso per mostrarlo',
    );
    return '$_temp0';
  }

  @override
  String shieldCallFrom(Object name) {
    return 'Chiamata da $name';
  }

  @override
  String get shieldCallHeld => 'In attesa — Modalità Scudo';

  @override
  String get statusViewersUnavailable =>
      'Elenco delle visualizzazioni non disponibile.';

  @override
  String statusSeenBy(int count) {
    return 'Visto da $count';
  }

  @override
  String get statusNobodySeen => 'Nessuno l\'ha ancora visto.';

  @override
  String get statusBoostFailed => 'Impossibile mettere in evidenza lo stato.';

  @override
  String get statusDeleteTitle => 'Eliminare questo stato?';

  @override
  String get statusDeleteBody =>
      'Scomparirà per tutti quelli che possono vederlo.';

  @override
  String get statusDeleteFailed =>
      'Eliminazione impossibile: controlla la connessione.';

  @override
  String get statusPublishFailed =>
      'Pubblicazione impossibile: controlla la connessione e riprova.';

  @override
  String get statusBoostAction => 'Metti in evidenza questo stato · 1 000 FCFA';

  @override
  String get modulesSubtitle => 'Aggiungi ciò che ti serve, lascia il resto';

  @override
  String get modulePaymentFailed => 'Impossibile avviare il pagamento.';

  @override
  String deeplinkFollowedChannel(String name) {
    return 'Iscritto al canale «$name»';
  }

  @override
  String get deeplinkOpenFailed =>
      'Questo link d\'invito non è stato aperto al momento.';

  @override
  String get cropTitle => 'Ritaglia';

  @override
  String get cropHint => 'Pizzica per ingrandire, trascina per inquadrare';

  @override
  String get cropConfirm => 'Conferma';

  @override
  String get inviteJoinMe => 'Raggiungimi su Pokou Messenger';

  @override
  String inviteJoinMeNamed(String name) {
    return '$name, raggiungimi su Pokou Messenger';
  }

  @override
  String get otpNoCodeReceived => 'Non hai ricevuto il codice?';

  @override
  String get countryDialCode => 'Prefisso del paese';

  @override
  String get countrySearchHint => 'Paese o prefisso (es. Benin, 229)';

  @override
  String get countryNoneFound => 'Nessun paese trovato.';

  @override
  String get presenceSomeone => 'Qualcuno';

  @override
  String atTime(String time) {
    return 'alle $time';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date alle $time';
  }

  @override
  String truthAskedTo(String name) {
    return 'A $name';
  }

  @override
  String get devicesNoPushHere => 'Questo dispositivo non riceve notifiche.';

  @override
  String get devicesNoPushHereBody =>
      'Non è riuscito a registrarsi al servizio di notifiche. Tocca per riprovare.';

  @override
  String get devicesRetryDone => 'Questo dispositivo riceve ora le notifiche.';

  @override
  String get devicesRetryFailed =>
      'Registrazione ancora impossibile: riprova più tardi.';

  @override
  String get chatsProfileMissing =>
      'Profilo non disponibile: controlla la connessione e riprova.';

  @override
  String get recSlideToCancel => 'Scorri per annullare';

  @override
  String get recReleaseToCancel => 'Rilascia per annullare';

  @override
  String get recLocked => 'Bloccato';

  @override
  String get recSlideUpToLock => 'Scorri verso l\'alto per bloccare';

  @override
  String get recDelete => 'Elimina la registrazione';

  @override
  String get recHoldToRecord => 'Tieni premuto per registrare';

  @override
  String get composerViewOnce => 'Visualizzazione unica';

  @override
  String get composerViewOnceOn =>
      'Visualizzazione unica attiva: la foto sparirà dopo l\'apertura.';

  @override
  String get composerViewOnceOff => 'Visualizzazione unica disattivata.';

  @override
  String get channelSuggestedTitle => 'Canali da seguire';

  @override
  String get channelSuggestedBody =>
      'Non ne segui ancora nessuno. Eccone alcuni.';

  @override
  String get channelSuggestedNone => 'Nessun canale da proporre al momento.';

  @override
  String channelFollowed(String name) {
    return 'Ora segui «$name»';
  }

  @override
  String get channelFollowFailed =>
      'Impossibile seguire: controlla la connessione.';

  @override
  String get certifyTitle => 'Canale verificato';

  @override
  String get certifyWhyTitle => 'Un badge, e la testa dei suggerimenti';

  @override
  String get certifyWhyBody =>
      'I canali verificati compaiono per primi a chi cerca cosa seguire, e il badge si vede su ogni pubblicazione.';

  @override
  String get certifyReviewTitle => 'Un esame, non un acquisto';

  @override
  String get certifyReviewBody =>
      'Il nostro team legge il tuo canale prima di concedere il badge. Un badge che si compra e basta non varrebbe nulla: è questo a dargli valore.';

  @override
  String get certifyRefundTitle => 'Rifiutata? Ti rimborsiamo';

  @override
  String get certifyRefundBody =>
      'Se il badge non può essere concesso, contattaci: l\'importo ti viene restituito.';

  @override
  String get certifyRenewTitle => 'Un abbonamento, non un acquisito';

  @override
  String get certifyRenewBody =>
      'Il badge dura quanto la formula scelta. Rinnovare prima della scadenza lo prolunga senza perdere nulla.';

  @override
  String get certifyPlanMonthly => 'Mensile — 3 000 FCFA';

  @override
  String get certifyPlanAnnual => 'Annuale — 30 000 FCFA (due mesi in omaggio)';

  @override
  String get certifyAction => 'Paga e invia la richiesta';

  @override
  String get certifyPending =>
      'La tua richiesta arriva al team non appena il pagamento è confermato.';

  @override
  String get certifyFailed => 'Richiesta impossibile: riprova.';

  @override
  String get certifyAlready => 'Questo canale è verificato';

  @override
  String get certifyTooltip => 'Fai verificare questo canale';

  @override
  String get chatsStartTitle => 'Inizia una conversazione';

  @override
  String get chatsStartBody =>
      'I tuoi contatti sono già su Pokou. Tocca un nome per scrivergli.';

  @override
  String get chatsSeeAllContacts => 'Vedi tutti i miei contatti';

  @override
  String get chatsNoNetworkTitle => 'La tua rete non è ancora su Pokou';

  @override
  String get chatsNoNetworkBody =>
      'Invita qualcuno, o segui un canale mentre aspetti una risposta.';

  @override
  String get chatsInviteContacts => 'Invita contatti';

  @override
  String get chatsDiscoverChannels => 'Scopri canali';

  @override
  String get e2eeEncrypted => 'Crittografato end-to-end';

  @override
  String get e2eeNotEncrypted => 'Non crittografato';

  @override
  String get e2eeNotEncryptedBody =>
      'Questa persona deve aggiornare Pokou per la crittografia.';

  @override
  String get e2eeIdentityChangedTitle =>
      'Le informazioni di sicurezza di questo contatto sono cambiate';

  @override
  String e2eeIdentityChangedBody(String name) {
    return 'La chiave di sicurezza di $name è cambiata (nuovo telefono o reinstallazione). Nel dubbio, verifica con $name.';
  }

  @override
  String get e2eeIdentityAccept => 'Ho verificato, continua';

  @override
  String get e2eeBlockedTitle => 'Messaggio non inviato';

  @override
  String get e2eeBlockedLookup =>
      'Impossibile recuperare la chiave di crittografia. Il messaggio non è stato inviato: Pokou non lo invierà mai in chiaro a tua insaputa.';

  @override
  String get e2eeBlockedInvalid =>
      'La chiave ricevuta non è utilizzabile. Il messaggio non è stato inviato, per precauzione.';

  @override
  String get e2eeBlockedIdentity =>
      'La chiave di questo contatto è cambiata. Verifica la sua identità prima di inviare.';

  @override
  String get e2eeBlockedCrypto =>
      'La crittografia è fallita. Il messaggio non è stato inviato.';

  @override
  String get e2eeRetry => 'Riprova';

  @override
  String get profileTheme => 'Aspetto';

  @override
  String get themeSystem => 'Come il telefono';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeHint =>
      'La modalità scura affatica meno gli occhi di sera e risparmia batteria sugli schermi OLED.';

  @override
  String get a11yBack => 'Indietro';

  @override
  String get a11yRefresh => 'Aggiorna';

  @override
  String get a11yMoreOptions => 'Altre opzioni';

  @override
  String get a11yVoiceCall => 'Chiamata vocale';

  @override
  String get a11yVideoCall => 'Videochiamata';

  @override
  String get a11yAttach => 'Allega un file';

  @override
  String get a11yRate => 'Valuta';

  @override
  String get a11yAudioLevel => 'Livello audio';

  @override
  String get marketCreateAd => 'Crea un annuncio';

  @override
  String get adSponsored => 'Sponsorizzato';

  @override
  String get adYours => 'Il tuo annuncio';

  @override
  String get adContact => 'Contatta';

  @override
  String get adContactFailed => 'Impossibile contattare l\'inserzionista.';

  @override
  String get mediaSaveToPhone => 'Salva sul telefono';

  @override
  String get mediaUndecryptable =>
      'Allegato cifrato illeggibile su questo telefono.';

  @override
  String get mediaSaved => 'Salvato nella tua galleria';

  @override
  String get mediaExported => 'Scegli dove salvarlo';

  @override
  String get mediaSavePermission =>
      'Pokou ha bisogno di accedere alle tue foto per salvare questo file.';

  @override
  String get mediaSaveNoSpace => 'Spazio insufficiente sul telefono.';

  @override
  String get mediaSaveFailed => 'Impossibile salvare.';

  @override
  String get composerEmoji => 'Emoji';

  @override
  String get convAttachGif => 'GIF';

  @override
  String get stickerTabEmoji => 'Emoji';

  @override
  String get stickerTabStickers => 'Sticker';

  @override
  String get stickerSearchHint => 'Cerca uno sticker';

  @override
  String get stickerRecents => 'Recenti';

  @override
  String get stickerFavorites => 'Preferiti';

  @override
  String get stickerNoResult => 'Nessuno sticker trovato';

  @override
  String get stickerEmptyPanel => 'Ancora nessuno sticker';

  @override
  String get stickerBrowsePacks => 'Sfoglia i pacchetti';

  @override
  String get stickerManagePacks => 'Gestisci i pacchetti';

  @override
  String get stickerPacksTitle => 'Pacchetti di sticker';

  @override
  String get stickerPackAdd => 'Aggiungi';

  @override
  String get stickerPackAdded => 'Aggiunto';

  @override
  String get stickerPackRemove => 'Rimuovi';

  @override
  String get stickerPackDelete => 'Elimina il pacchetto';

  @override
  String get stickerPackDeleteConfirm =>
      'Eliminare questo pacchetto e tutti i suoi sticker?';

  @override
  String get stickerMyPackName => 'I miei sticker';

  @override
  String get stickerCreateFromPhoto => 'Crea da una foto';

  @override
  String get stickerCreated => 'Sticker aggiunto ai tuoi sticker';

  @override
  String get stickerLimitReached => 'Il tuo pacchetto personale è pieno';

  @override
  String get stickerSendFailed => 'Sticker non inviato — riprova';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get stickerFavoriteAdded => 'Aggiunto ai preferiti';

  @override
  String get stickerFavoriteRemoved => 'Rimosso dai preferiti';

  @override
  String get stickerStoreEmpty => 'Nessun pacchetto disponibile al momento';

  @override
  String get stickerSaveToMine => 'Aggiungi ai miei sticker';

  @override
  String get stickerSaved => 'Sticker aggiunto ai tuoi sticker';

  @override
  String get navBaba => 'Baba';

  @override
  String get appBarOnline => 'Online';

  @override
  String get appBarOffline => 'Offline';

  @override
  String get marketNegotiate => 'Negozia';

  @override
  String get callsCallBack => 'Richiama';

  @override
  String get callsFilterMissed => 'Perse';

  @override
  String get callsFilterAll => 'Tutte';

  @override
  String get chatsFilterAll => 'Tutte';

  @override
  String get chatsFilterUnread => 'Non lette';

  @override
  String get chatsFilterGroups => 'Gruppi';

  @override
  String get chatsSearchOrAsk => 'Cerca o chiedi a Baba…';

  @override
  String get convEncryptedHint => 'Messaggio cifrato…';

  @override
  String get chatsArchivedSection => 'Chat archiviate';

  @override
  String get statusMineTitle => 'La mia novità';

  @override
  String get statusMineBody => 'Tocca per pubblicare una novità (24 h)';

  @override
  String get statusMineVisibility => 'Visibile ai miei contatti';

  @override
  String get callLeaveConference => 'Esci dalla conferenza';

  @override
  String get callQualityExcellent => 'Eccellente';

  @override
  String get callQualityGood => 'Discreta';

  @override
  String get callQualityPoor => 'Debole';

  @override
  String get callYouShort => 'Tu';

  @override
  String get callMutedShort => 'Muto';

  @override
  String get callMuteLabel => 'Micro';

  @override
  String get callCameraLabel => 'Fotocamera';

  @override
  String get callSpeakerLabel => 'Altoparlante';

  @override
  String get callFlipCamera => 'Gira la fotocamera';

  @override
  String get callFlipCameraFailed => 'Impossibile cambiare fotocamera.';

  @override
  String get callNoAnswer => 'Nessuna risposta.';

  @override
  String callOngoingBanner(String duration) {
    return 'Chiamata in corso · $duration — tocca per tornare';
  }

  @override
  String get callOngoingBannerRinging =>
      'Chiamata in corso — tocca per tornare';

  @override
  String get callHangUp => 'Riaggancia';

  @override
  String get callInviteLabel => 'Invita';

  @override
  String get e2eeReassurance =>
      'Crittografia end-to-end: nessun altro, nemmeno Pokou, può leggere questi messaggi.';

  @override
  String get chatsEncryptionFooter =>
      'Le tue chat sono crittografate end-to-end.';

  @override
  String get callsRecentSection => 'RECENTI';

  @override
  String get callsGroupChip => 'Gruppo';

  @override
  String get callGroupNotEncrypted =>
      'Chiamata di gruppo standard — non cifrata end-to-end';

  @override
  String get marketCatalogueSeeAll => 'Vedi tutto';

  @override
  String get marketCatalogueOpen => 'Apri il mio catalogo';

  @override
  String get marketCatalogueTotal => 'Annunci';

  @override
  String get marketCatalogueOnline => 'Online';

  @override
  String get marketCatalogueBoostedLabel => 'In evidenza';

  @override
  String get marketCatalogueWithdrawn => 'Ritirati';

  @override
  String get marketFilterAll => 'Tutti';

  @override
  String get marketCertifiedSellers => 'Venditori certificati';

  @override
  String get marketCatalogueNoneInFilter => 'Nessun annuncio in questo filtro.';

  @override
  String get marketStatusModerated => 'Rimosso dal mercato';

  @override
  String get marketStatusModeratedBody =>
      'Gli acquirenti non possono più vederlo. Contatta l\'assistenza se pensi sia un errore.';

  @override
  String get callsFilterDirect => 'Uno a uno';

  @override
  String get profileMyAccount => 'Il mio account';

  @override
  String get profileVerifyAccount => 'Verifica il mio account';

  @override
  String get profileVerifyAccountBody =>
      'Ottieni il badge di venditore verificato del Mercato';

  @override
  String get profileCertificationPending => 'Certificazione in attesa';

  @override
  String get profileCertificationPendingBody =>
      'La tua richiesta è in fase di revisione.';

  @override
  String get profileCertificationActive => 'Account certificato';

  @override
  String get profileCertificationActiveBody =>
      'Il badge di certificazione appare accanto al tuo nome.';

  @override
  String get profileSellerCertified => 'Venditore verificato';

  @override
  String profileSellerCertifiedUntil(String date) {
    return 'Badge venditore attivo fino al $date.';
  }

  @override
  String get verifPlanLabel => 'Scegli la tua formula';

  @override
  String get callEventAudio => 'Chiamata vocale';

  @override
  String get callEventVideo => 'Videochiamata';

  @override
  String get callEventGroup => 'Chiamata di gruppo';

  @override
  String get callEventMissed => 'Chiamata persa';

  @override
  String get callEventNoAnswer => 'Nessuna risposta';

  @override
  String get callEventDeclined => 'Rifiutata';

  @override
  String get callEventYouDeclined => 'L\'hai rifiutata';

  @override
  String get callEventEnded => 'Terminata';

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
      other: '$count partecipanti',
      one: '1 partecipante',
    );
    return '$_temp0';
  }

  @override
  String get mediaCall => 'Chiamata';

  @override
  String get mediaSticker => 'Sticker';

  @override
  String get identityVerifiedAccount => 'Account verificato';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyIntro =>
      'Queste impostazioni sono applicate dal server: ciò che nascondi non viene inviato agli altri, non è solo nascosto nell\'app.';

  @override
  String get privacySectionWhoSees => 'Chi può vedere le mie informazioni';

  @override
  String get privacySectionMessages => 'Messaggi';

  @override
  String get privacySectionGroups => 'Gruppi';

  @override
  String get privacyLastSeen => 'Ultimo accesso';

  @override
  String get privacyLastSeenBody => 'Quando ti sei collegato l\'ultima volta.';

  @override
  String get privacyOnline => 'Presenza online';

  @override
  String get privacyOnlineBody =>
      'Il punto verde che indica che sei raggiungibile ora. Indipendente dall\'ultimo accesso.';

  @override
  String get privacyProfilePhoto => 'Foto del profilo';

  @override
  String get privacyProfilePhotoBody => 'La tua foto, ovunque appaia.';

  @override
  String get privacyProfileInfo => 'Informazioni del profilo';

  @override
  String get privacyProfileInfoBody =>
      'La tua descrizione e ciò che hai indicato su di te.';

  @override
  String get privacyReadReceipts => 'Conferme di lettura';

  @override
  String get privacyReadReceiptsBody =>
      'Disattivarle ti priva anche di quelle degli altri. Le spunte di consegna restano visibili.';

  @override
  String get privacyGroupInvites => 'Chi può invitarmi in un gruppo';

  @override
  String get privacyGroupInvitesBody =>
      'Permettere non è accettare: l\'ultima parola su ogni invito resta tua.';

  @override
  String get privacyGroupMembership =>
      'Visibilità della mia appartenenza ai gruppi';

  @override
  String get privacyGroupMembershipBody =>
      'Chi può vedere in quali gruppi sei. I membri di un gruppo continuano a conoscersi.';

  @override
  String get privacyEveryone => 'Tutti';

  @override
  String get privacyMyContacts => 'I miei contatti';

  @override
  String get privacyNobody => 'Nessuno';

  @override
  String get privacySaveFailed => 'Impostazione non salvata — riprova.';

  @override
  String get privacyUnavailable => 'Impostazioni privacy non disponibili.';

  @override
  String get privacyStatusesNote =>
      'La privacy degli stati si imposta dalla scheda Aggiornamenti, dove puoi anche escludere persone specifiche.';

  @override
  String groupInvitesSent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inviti inviati',
      one: 'Invito inviato',
      zero: 'Nessun invito inviato',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationTitle => 'Invito a un gruppo';

  @override
  String groupInvitationFrom(Object name) {
    return '$name ti invita';
  }

  @override
  String groupInvitationMembers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membri',
      one: '1 membro',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationAccept => 'Unisciti';

  @override
  String get groupInvitationReject => 'Rifiuta';

  @override
  String groupInvitationExpires(Object hours) {
    return 'Scade tra $hours h';
  }

  @override
  String get groupInvitationExpiresSoon => 'Scade a breve';

  @override
  String groupInvitationsHeader(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inviti',
      one: '1 invito',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationFailed =>
      'Azione impossibile — l\'invito potrebbe non essere più valido.';

  @override
  String get mediaStatePreparing => 'Preparazione…';

  @override
  String get mediaStateSending => 'Invio…';

  @override
  String mediaStateSendingPercent(Object percent) {
    return 'Invio · $percent %';
  }

  @override
  String get mediaStateWaitingNetwork => 'In attesa di connessione';

  @override
  String get mediaStateFailed => 'Invio non riuscito';

  @override
  String get mediaStateFileGone => 'File non più su questo dispositivo';

  @override
  String get channelPrivateLabel => 'Canale privato';

  @override
  String get channelPrivateBody =>
      'Non compare nella ricerca. Solo chi riceve il link può unirsi e leggere i post. Questa scelta non sarà modificabile.';

  @override
  String get channelPrivateBadge => 'Privato';

  @override
  String get mahizuConnectTitle => 'Collega il tuo account Mahizu';

  @override
  String mahizuConnectBody(String phone) {
    return 'L\'assistente è un servizio Mahizu, separato da Pokou. Per usarlo, collega il tuo account Mahizu: verrà inviato un codice al $phone.';
  }

  @override
  String get mahizuSendCode => 'Ricevi il codice';

  @override
  String get mahizuCodeLabel => 'Codice ricevuto';

  @override
  String get mahizuPinLabel => 'PIN del tuo account Mahizu';

  @override
  String get mahizuConfirm => 'Collega';

  @override
  String get mahizuRestart => 'Ricomincia';

  @override
  String get navHome => 'Home';

  @override
  String get navKory => 'Kory';

  @override
  String get navMore => 'Altro';

  @override
  String homeGreeting(String name) {
    return 'Ciao $name';
  }

  @override
  String get homeSeeAll => 'Vedi tutto';

  @override
  String get homeNoChats => 'Ancora nessuna chat';

  @override
  String get homeKoryEmpty => 'Nessuna colletta in corso';

  @override
  String get homeSearchHint => 'Cerca una chat';

  @override
  String get moreCertifiedTitle => 'Pokou certificato';

  @override
  String get moreCertifiedBody =>
      'Identità verificata e modalità prova: in arrivo.';

  @override
  String get moreSectionServices => 'Servizi';

  @override
  String get moreSectionSettings => 'Impostazioni';

  @override
  String get moreAccount => 'Account e sicurezza';

  @override
  String get moreEdit => 'Modifica';

  @override
  String get koryTitle => 'Kory';

  @override
  String get korySubtitle => 'Collette e tontine';

  @override
  String get koryMyPots => 'Le mie collette';

  @override
  String get koryMonthTotal => 'I miei contributi confermati questo mese';

  @override
  String get koryNoMoney =>
      'Pokou non tocca il denaro: va direttamente dal tuo wallet a quello del collettore.';

  @override
  String get koryCreate => 'Crea una colletta';

  @override
  String get koryJoin => 'Partecipa';

  @override
  String get koryJournalTab => 'Registro';

  @override
  String get koryJoinTitle => 'Partecipa con un codice';

  @override
  String get koryJoinHint => 'Codice della colletta';

  @override
  String get koryJoinUnknown => 'Codice sconosciuto o colletta chiusa.';

  @override
  String get koryNone => 'Nessuna colletta in corso';

  @override
  String get koryNoneBody =>
      'Crea una colletta per un matrimonio, un battesimo o una quota, oppure partecipa a una con il suo codice.';

  @override
  String get koryUnavailable => 'Kory non è disponibile';

  @override
  String get koryKindCagnotte => 'Colletta';

  @override
  String get koryKindCotisation => 'Quota';

  @override
  String get koryTotalConfirmed => 'Totale confermato';

  @override
  String koryGoal(String amount) {
    return 'Obiettivo: $amount';
  }

  @override
  String koryDue(String date) {
    return 'Scadenza: $date';
  }

  @override
  String koryMyShare(String amount) {
    return 'La mia parte confermata: $amount';
  }

  @override
  String koryToReview(String count) {
    return 'Da confermare: $count';
  }

  @override
  String get koryClosed => 'Chiusa';

  @override
  String get koryOpen => 'Aperta';

  @override
  String koryCollector(String name) {
    return 'Collettore: $name';
  }

  @override
  String koryPayTo(String phone) {
    return 'Invia il tuo contributo dal tuo wallet al $phone, poi dichiaralo qui.';
  }

  @override
  String koryPerMember(String amount, String period) {
    return '$amount a membro, $period';
  }

  @override
  String get koryDeclare => 'Ho contribuito';

  @override
  String get koryDeclareTitle => 'Dichiara un contributo';

  @override
  String get koryAmount => 'Importo (FCFA)';

  @override
  String get koryWalletRef => 'Riferimento della transazione (facoltativo)';

  @override
  String get koryWalletRefHelp =>
      'Si trova nell\'SMS del tuo operatore. Solo tu e il collettore lo vedete.';

  @override
  String get koryNote => 'Messaggio (facoltativo)';

  @override
  String get koryPeriodLabel => 'Periodo coperto (es. 2026-11)';

  @override
  String get koryJournal => 'Registro dei contributi';

  @override
  String get koryJournalEmpty => 'Ancora nessun contributo dichiarato.';

  @override
  String get koryStatusDeclared => 'In attesa del collettore';

  @override
  String get koryStatusConfirmed => 'Confermato';

  @override
  String get koryStatusRejected => 'Contestata';

  @override
  String get koryConfirm => 'Ricevuto';

  @override
  String get koryReject => 'Non ricevuto';

  @override
  String get koryCloseAction => 'Chiudi';

  @override
  String get koryCloseConfirm =>
      'Chiudere la colletta? Nessuno potrà più dichiarare contributi.';

  @override
  String koryShareCode(String code) {
    return 'Codice: $code';
  }

  @override
  String koryShareText(String title, String code) {
    return 'Partecipa alla colletta «$title» su Pokou con il codice $code.';
  }

  @override
  String get koryCreateTitle => 'Nuova colletta';

  @override
  String get koryFieldTitle => 'Titolo';

  @override
  String get koryFieldDescription => 'Descrizione (facoltativa)';

  @override
  String get koryFieldGoal => 'Obiettivo in FCFA (facoltativo)';

  @override
  String get koryFieldPerMember => 'Importo a membro (FCFA)';

  @override
  String get koryPeriodMonthly => 'ogni mese';

  @override
  String get koryPeriodWeekly => 'ogni settimana';

  @override
  String get koryFieldDue => 'Scadenza (facoltativa)';

  @override
  String get koryNeedTitle => 'Inserisci un titolo (almeno 3 caratteri).';

  @override
  String get koryNeedAmount => 'Indica un importo di almeno 100 FCFA.';

  @override
  String get koryCollectorIsYou =>
      'Sei il collettore: i contributi arrivano sul tuo wallet e sei tu a confermarli.';

  @override
  String get koryYou => 'Tu';

  @override
  String get koryTontinePlus => 'Tontina a rotazione: presto con Kory Plus';

  @override
  String get koryDeclared =>
      'Contributo dichiarato. Il collettore lo confermerà.';

  @override
  String get koryCopyPhone => 'Copia il numero';

  @override
  String get koryCopied => 'Copiato';

  @override
  String get koryActionFailed => 'Operazione non riuscita. Riprova.';

  @override
  String get welcomePromise => 'Più di una messaggistica, una comunità.';

  @override
  String get welcomeSignature => 'Insieme, più forti.';

  @override
  String get welcomeServiceChats => 'Chat, gruppi e chiamate';

  @override
  String get welcomeServiceKory => 'Collette e tontine';

  @override
  String get legalPrivacy => 'Privacy';

  @override
  String get legalTerms => 'Condizioni d\'uso';

  @override
  String get legalUnavailable => 'Documento al momento non disponibile.';

  @override
  String onbStep(String step) {
    return 'Passo $step di 3';
  }

  @override
  String get onbProfileTitle => 'Il tuo profilo';

  @override
  String get onbProfileBody => 'È il nome che vedranno i tuoi contatti.';

  @override
  String get onbDisplayName => 'Nome visualizzato';

  @override
  String get onbNameRequired => 'Inserisci un nome (almeno 2 caratteri).';

  @override
  String get onbPhotoLater =>
      'Potrai aggiungere una foto più tardi dal tuo profilo.';

  @override
  String get onbContinue => 'Continua';

  @override
  String get onbTermsTitle => 'Prima di iniziare';

  @override
  String get onbAcceptTerms =>
      'Ho letto e accetto le condizioni d\'uso e l\'informativa sulla privacy.';

  @override
  String get onbAge => 'Ho l\'età richiesta per usare Pokou.';

  @override
  String get onbOptional =>
      'Facoltativo, modificabile in qualsiasi momento nelle impostazioni';

  @override
  String get onbAnalytics =>
      'Condividi statistiche d\'uso per migliorare Pokou';

  @override
  String get onbMarketing => 'Ricevi novità e offerte di Pokou';

  @override
  String get onbFinish => 'Fine';

  @override
  String get onbFailed => 'Salvataggio non riuscito. Riprova.';

  @override
  String get moreConsents => 'Statistiche e comunicazioni';

  @override
  String get navHonam => 'Honam';

  @override
  String get honamSubtitle => 'Farmacie e consegna';

  @override
  String get honamIntro =>
      'Una farmacia vicina ti invia un preventivo. Pagalo dal tuo wallet e un corriere te lo consegna.';

  @override
  String get honamSend => 'Invia una ricetta';

  @override
  String get honamPhotograph => 'Fotografa la ricetta';

  @override
  String get honamFromGallery => 'Scegli una foto';

  @override
  String get honamUrgent => 'Emergenza';

  @override
  String get honamNotEmergency => 'Pokou non è un servizio di emergenza.';

  @override
  String get honamNearby => 'Farmacie vicine';

  @override
  String get honamOnDuty => 'Di turno';

  @override
  String get honamNoPharmacy => 'Ancora nessuna farmacia partner.';

  @override
  String get honamCurrentOrder => 'Ordine in corso';

  @override
  String get honamMyOrders => 'I miei ordini';

  @override
  String get honamChoosePharmacy => 'Scegli la farmacia';

  @override
  String get honamAddress => 'Indirizzo di consegna';

  @override
  String get honamNote => 'Nota per il farmacista (facoltativa)';

  @override
  String get honamSubmit => 'Invia alla farmacia';

  @override
  String get honamNeedPhoto => 'Aggiungi la foto della ricetta.';

  @override
  String get honamNeedAddress => 'Inserisci l\'indirizzo di consegna.';

  @override
  String get honamFailed => 'Operazione non riuscita. Riprova.';

  @override
  String honamOrderTitle(String id) {
    return 'Ordine n. $id';
  }

  @override
  String get honamStSubmitted => 'Inviata, in attesa del farmacista';

  @override
  String get honamStQuoted => 'Preventivo ricevuto';

  @override
  String get honamStAccepted => 'Preventivo accettato, da pagare';

  @override
  String get honamStPaid => 'Pagato, in preparazione';

  @override
  String get honamStReady => 'Pronto, in attesa del corriere';

  @override
  String get honamStInDelivery => 'In consegna';

  @override
  String get honamStDelivered => 'Consegnato';

  @override
  String get honamStRejected => 'Ricetta rifiutata';

  @override
  String get honamStExpired => 'Preventivo scaduto';

  @override
  String get honamStCancelled => 'Annullato';

  @override
  String get honamQuote => 'Preventivo';

  @override
  String get honamUnavailableItem => 'Non disponibile';

  @override
  String get honamMedicines => 'Farmaci';

  @override
  String get honamDelivery => 'Consegna';

  @override
  String get honamTotal => 'Totale da pagare';

  @override
  String get honamAcceptQuote => 'Accetta il preventivo';

  @override
  String honamPayTo(String amount, String phone) {
    return 'Invia $amount dal tuo wallet al $phone (la farmacia), poi conferma.';
  }

  @override
  String get honamDeclarePaid => 'Ho pagato la farmacia';

  @override
  String get honamPaidDeclared =>
      'Pagamento segnalato: la farmacia lo confermerà.';

  @override
  String get honamPaymentNotReceived =>
      'La farmacia non ha ricevuto il pagamento. Controlla numero e importo.';

  @override
  String get honamCode => 'Codice di consegna';

  @override
  String get honamCodeHelp =>
      'Dai questo codice al corriere solo quando hai il pacco in mano.';

  @override
  String get honamOriginal => 'Il corriere ritirerà la ricetta originale.';

  @override
  String honamRefundDue(String amount, String reason) {
    return 'La farmacia ti deve $amount: $reason';
  }

  @override
  String get honamRefundReceived => 'Ho ricevuto il rimborso';

  @override
  String get honamCancel => 'Annulla l\'ordine';

  @override
  String get honamResend => 'Invia a un\'altra farmacia';

  @override
  String honamReason(String reason) {
    return 'Motivo: $reason';
  }

  @override
  String get honamTimeline => 'Tracciamento';

  @override
  String get honamOrderMessages => 'Messaggi dell\'ordine';

  @override
  String get honamWriteMessage => 'Scrivi un messaggio';

  @override
  String get honamCourierMode => 'Modalità corriere';

  @override
  String get honamCourierJoin => 'Diventa corriere Win Pokou';

  @override
  String get honamCourierJoinBody =>
      '5 corse di prova senza commissione per un mese. Poi: adesione Win Pokou e pacchetto prepagato.';

  @override
  String honamRidesLeft(String count) {
    return 'Corse rimanenti: $count';
  }

  @override
  String get honamUnlimited => 'Corse illimitate';

  @override
  String honamMembership(String amount) {
    return 'Adesione Win Pokou: $amount IVA escl. / mese';
  }

  @override
  String get honamPayMembership => 'Paga l\'adesione';

  @override
  String get honamPacks => 'Pacchetti corse';

  @override
  String honamPackPrice(String amount) {
    return '$amount IVA escl.';
  }

  @override
  String get honamAvailableRides => 'Corse disponibili';

  @override
  String get honamMyRides => 'Le mie corse';

  @override
  String get honamNoRides => 'Nessuna corsa per ora.';

  @override
  String get honamAcceptRide => 'Accetta la corsa';

  @override
  String get honamPickup => 'Pacco ritirato';

  @override
  String get honamDeliver => 'Conferma la consegna';

  @override
  String get honamEnterCode => 'Codice fornito dal paziente';

  @override
  String get honamCoursePaid => 'Ho ricevuto il pagamento della corsa';

  @override
  String get honamPaymentLinkOpened =>
      'Completa il pagamento nella pagina che si apre.';

  @override
  String get honamCourierSuspended =>
      'Account sospeso dopo 3 mancate consegne. Contatta il supporto per un ricorso.';

  @override
  String get honamPriceNote =>
      'Prezzi IVA esclusa; si applica l\'IVA del paese.';

  @override
  String get certTitle => 'Pokou certificato';

  @override
  String get certPitch =>
      'Il badge prova che il nome è davvero il tuo. La modalità prova mantiene visibili, barrati, i messaggi eliminati di un gruppo.';

  @override
  String get certHowItWorks =>
      'La tua identità è verificata dal nome del titolare del wallet che paga.';

  @override
  String certStartTrial(String days) {
    return 'Prova $days giorni';
  }

  @override
  String get certTrialNote =>
      'Durante la prova la modalità prova è disponibile; il badge appare al primo pagamento.';

  @override
  String certPlanPrice(String ht, String ttc) {
    return '$ht IVA escl. · $ttc IVA incl.';
  }

  @override
  String get certSubscribe => 'Scegli';

  @override
  String get certActive => 'Badge attivo';

  @override
  String certTrialUntil(String date) {
    return 'Prova fino al $date';
  }

  @override
  String certActiveUntil(String date) {
    return 'Attivo fino al $date';
  }

  @override
  String get certExpired => 'Abbonamento scaduto';

  @override
  String get certMismatchTitle => 'I nomi non corrispondono';

  @override
  String get certMismatchBody =>
      'Il nome inserito non corrisponde al titolare del wallet che ha pagato. Correggilo come sul documento d\'identità.';

  @override
  String get proofModeTitle => 'Modalità prova';

  @override
  String get proofModeOnBanner =>
      'Modalità prova attiva: un messaggio eliminato resta visibile, barrato, per tutti.';

  @override
  String get proofModeEnable => 'Attiva la modalità prova';

  @override
  String get proofModeDisable => 'Disattiva la modalità prova';

  @override
  String get proofModeNeedsCert =>
      'La modalità prova richiede Pokou certificato (prova gratuita disponibile).';

  @override
  String get deleteForAll => 'Elimina per tutti';

  @override
  String get deleteProofWarning =>
      'La modalità prova è attiva: il messaggio resterà visibile, barrato, per tutti i membri.';

  @override
  String get deletedKept =>
      'Messaggio eliminato, conservato dalla modalità prova';

  @override
  String get certCorrectName => 'Nome completo del titolare';

  @override
  String get certRetryName => 'Verifica questo nome';

  @override
  String get certStillMismatch => 'Questo nome non corrisponde ancora.';

  @override
  String get proofExport => 'Esporta la chat (PDF)';

  @override
  String proofModeOn(String name) {
    return '$name ha attivato la modalità prova';
  }

  @override
  String proofModeOff(String name) {
    return '$name ha disattivato la modalità prova';
  }

  @override
  String proofOriginal(String text) {
    return 'Versione originale: $text';
  }

  @override
  String get proofDisableReserved =>
      'Solo chi l\'ha attivata, o un amministratore con badge a pagamento, può disattivarla.';

  @override
  String get marketBoost3 => '3 giorni · 600 FCFA';

  @override
  String get marketBoost7 => '7 giorni · 1.300 FCFA';

  @override
  String get marketUseHonam => 'I farmaci non si vendono su Assimé: usa Honam.';

  @override
  String get honamMissingTitle => 'Manca un prodotto';

  @override
  String honamMissingBody(String amount, String reason) {
    return 'Mancano $amount: $reason. Cosa preferisci?';
  }

  @override
  String get honamKeepRest => 'Ricevere il resto';

  @override
  String get honamCancelAll => 'Annullare tutto';

  @override
  String get honamRefundDelay =>
      'La farmacia ti rimborsa entro 2 ore, sul numero che ha pagato.';

  @override
  String get honamZones => 'Zone e orari (es. Bè, Tokoin — sere)';

  @override
  String get honamWallet => 'Numero del wallet che riceve i pagamenti';

  @override
  String get honamRules =>
      'Accetto le regole d\'oro: consegno il pacco solo con il codice, non guardo le ricette, resto cortese.';

  @override
  String get honamApply => 'Invia la candidatura';

  @override
  String get honamPending =>
      'Candidatura inviata: il team Pokou la sta verificando.';

  @override
  String get honamLaunch =>
      'Periodo di lancio: consegni senza adesione né pacchetto.';

  @override
  String get honamQueenLocked =>
      'Queen Pokou si sblocca dopo un mese senza mancate consegne.';

  @override
  String koryDeclaredTotal(String amount) {
    return 'Totale dichiarato: $amount';
  }

  @override
  String koryRemaining(String amount) {
    return 'Da raccogliere: $amount';
  }

  @override
  String get onbBabaWelcome =>
      'Sono Baba, l\'assistente di Pokou. Come vuoi che ti chiamiamo?';

  @override
  String get onbContactsTitle => 'Ritrova i tuoi cari';

  @override
  String get onbContactsBody =>
      'Baba può trovare i tuoi contatti già su Pokou. Puoi rifiutare: te lo richiederemo più tardi.';

  @override
  String get onbContactsAllow => 'Consenti';

  @override
  String get onbLater => 'Più tardi';

  @override
  String get proofModeDirectHint =>
      'Tutto ciò che si scrive resta dimostrabile: un messaggio eliminato resta barrato, una modifica conserva l\'originale. Solo tu potrai disattivarlo.';

  @override
  String get proofDisableReservedDirect =>
      'Solo chi ha attivato la modalità prova può disattivarla.';

  @override
  String get proofExportMe => 'Io';

  @override
  String get proofExportTitle => 'Pokou — esportazione della modalità prova';

  @override
  String proofExportBetween(String me, String contact) {
    return 'Conversazione tra $me e $contact';
  }

  @override
  String proofExportPeriod(String since, String now) {
    return 'Modalità prova attiva dal $since · esportata il $now da questo telefono';
  }

  @override
  String proofExportFooter(String page, String pages) {
    return 'Pagina $page di $pages — prodotto sul dispositivo: il server Pokou non ha accesso ai messaggi cifrati.';
  }

  @override
  String get proofExportAttachment => '[allegato]';

  @override
  String proofExportEdited(String at) {
    return 'Modificato il $at';
  }

  @override
  String proofExportDeleted(String at) {
    return 'Eliminato il $at, conservato dalla modalità prova';
  }

  @override
  String get proTitle => 'Pokou certificato Pro';

  @override
  String get proTeaser => 'Per un\'attività: nome commerciale e «Gestito da»';

  @override
  String get proPitch =>
      'Il tuo nome commerciale appare per primo, con «Gestito da» e il tuo nome verificato. Il profilo Pro ospiterà i tuoi annunci Assimé.';

  @override
  String proSteps(String hours) {
    return '1. Invii il documento. 2. Il supporto lo verifica entro $hours h. 3. Paghi solo dopo l\'approvazione.';
  }

  @override
  String proPending(String due) {
    return 'Verifica in corso. Risposta entro il $due.';
  }

  @override
  String get proApproved =>
      'Documento approvato: puoi attivare Pokou certificato Pro.';

  @override
  String get proPay => 'Paga Pokou certificato Pro';

  @override
  String get proCorrection => 'Documento da correggere';

  @override
  String get proRejected => 'Richiesta respinta';

  @override
  String get proActivity => 'La tua attività';

  @override
  String get proBusinessName => 'Nome commerciale';

  @override
  String get proActivityField => 'Attività (sartoria, negozio, trasporti…)';

  @override
  String get proDocument => 'Aggiungi il documento';

  @override
  String get proDocumentChosen => 'Documento aggiunto — tocca per cambiare';

  @override
  String get proDocumentNote =>
      'Registro imprese, tesserino professionale o licenza. Visto solo dal supporto, mai mostrato.';

  @override
  String get proSend => 'Invia per la verifica';

  @override
  String proManagedBy(String name) {
    return 'Gestito da $name';
  }

  @override
  String get proProfileNote => 'Così gli altri vedono il tuo profilo Pro.';

  @override
  String get honamCity => 'Città';

  @override
  String get honamOtherCity => 'Un\'altra città';

  @override
  String get honamYourCity => 'La tua città';

  @override
  String get honamNotServed =>
      'Honam non consegna ancora in questa città. Iscriviti: ti avviseremo all\'apertura.';

  @override
  String get honamJoinWaitlist => 'Iscrivimi alla lista d\'attesa';

  @override
  String honamWaitlistDone(String city) {
    return 'Iscritto per $city';
  }

  @override
  String get honamWaitlistBody =>
      'Ti avviseremo appena Honam consegna nella tua città. Nient\'altro.';

  @override
  String get honamReferralCodeField => 'Codice invito (facoltativo)';

  @override
  String get honamReferralTitle => 'Invita un corriere';

  @override
  String honamReferralBody(String rides) {
    return '$rides corse gratuite alla prima consegna del tuo invitato.';
  }

  @override
  String get honamReferralShare => 'Condividi il mio codice';

  @override
  String honamReferralMessage(String code) {
    return 'Consegna per Honam con Pokou: usa il mio codice $code nella modalità corriere.';
  }

  @override
  String honamReferralCount(String count) {
    return 'Invitati: $count';
  }

  @override
  String get honamTrialEnded => 'La tua prova è terminata';

  @override
  String honamRecommendedPack(String pack) {
    return 'In base alle corse del mese, ti basta il pacchetto $pack.';
  }

  @override
  String get honamNavigate => 'Percorso nella mia app di mappe';

  @override
  String get honamLocationShared =>
      'La tua posizione è condivisa ogni 15 s durante la corsa, mai dopo.';

  @override
  String get honamLocationDenied =>
      'Consenti la posizione perché il paziente segua la consegna.';

  @override
  String get honamCourier => 'il corriere';

  @override
  String honamTrackingTitle(String name) {
    return '$name è in arrivo';
  }

  @override
  String get honamTrackingWaiting => 'Posizione non ancora ricevuta.';

  @override
  String honamTrackingDistance(String km) {
    return 'A $km km da te';
  }

  @override
  String honamTrackingUpdated(String minutes) {
    return 'Aggiornato $minutes min fa';
  }

  @override
  String get honamTrackingStale => 'Posizione non aggiornata';

  @override
  String get honamTrackingShowMap => 'Vedi sulla mappa';

  @override
  String get honamTrackingMapDataSaver => 'Vedi sulla mappa (consuma dati)';

  @override
  String get assimeFavoritesAlerts => 'Preferiti e avvisi';

  @override
  String get assimeFavorites => 'Preferiti';

  @override
  String get assimeAlerts => 'Avvisi';

  @override
  String get assimeNoFavorites => 'Nessun preferito';

  @override
  String get assimeFavoritesHint =>
      'Tocca il cuore di un annuncio per tenerlo qui.';

  @override
  String get assimeAddFavorite => 'Aggiungi ai preferiti';

  @override
  String get assimeRemoveFavorite => 'Rimuovi dai preferiti';

  @override
  String get assimeNewAlert => 'Nuovo avviso';

  @override
  String get assimeAlertQuery => 'Cosa cerchi';

  @override
  String get assimeAlertMaxPrice => 'Prezzo massimo (facoltativo)';

  @override
  String get assimeAlertNote =>
      'Ti avvisiamo quando un annuncio corrisponde. L\'avviso legge solo gli annunci, mai i tuoi messaggi.';

  @override
  String get assimeNoAlerts => 'Nessun avviso per ora.';

  @override
  String assimeAlertUpTo(String price) {
    return 'fino a $price FCFA';
  }

  @override
  String assimeAlertMatches(String count) {
    return '$count annuncio/i trovato/i';
  }

  @override
  String get assimeSponsored => 'Sponsorizzato';

  @override
  String get assimeWhyTitle => 'Perché vedo questo';

  @override
  String get assimeWhyNotSponsored => 'Questo annuncio non è più in evidenza.';

  @override
  String get assimeReportTitle => 'Resoconto della promozione';

  @override
  String get assimeReportEmpty =>
      'Ancora nessuna promozione per questo annuncio.';

  @override
  String assimeReportPeriod(String days, String start, String end) {
    return '$days giorni · dal $start al $end';
  }

  @override
  String assimeReportImpressions(String count) {
    return 'Mostrato in cima ai risultati: $count volte';
  }

  @override
  String assimeReportStatusViews(String count) {
    return 'Visto negli stati: $count volte';
  }

  @override
  String assimeReportContacts(String count) {
    return 'Persone che ti hanno contattato: $count';
  }

  @override
  String get assimeStatusPending =>
      'Posto negli stati: in revisione dalla moderazione';

  @override
  String get assimeStatusRejected =>
      'Posto negli stati rifiutato dalla moderazione';

  @override
  String get koryKindTontine => 'Tontina';

  @override
  String get koryFieldStake => 'Quota di ciascuno per turno (FCFA)';

  @override
  String get koryRotation => 'Ordine dei turni';

  @override
  String get koryRotationHint =>
      'Trascina per ordinare. L\'ordine si fissa all\'apertura e non cambia più.';

  @override
  String get koryRemoveFromRotation => 'Rimuovi dalla tontina';

  @override
  String get koryNeedRotation =>
      'Una tontina richiede almeno due partecipanti.';

  @override
  String get koryTontineNote =>
      'A ogni turno, ciascuno invia la quota al wallet del beneficiario, che conferma quanto ricevuto. Pokou non tocca mai il denaro.';

  @override
  String get koryRounds => 'I turni';

  @override
  String koryRoundNumber(String number) {
    return 'Turno $number';
  }

  @override
  String koryRoundConfirmed(String confirmed, String expected) {
    return '$confirmed confermati su $expected';
  }

  @override
  String get koryNextRound => 'Passa al turno successivo';

  @override
  String get koryNextRoundBody =>
      'Il turno in corso termina. Le quote già dichiarate restano da confermare dal suo beneficiario.';

  @override
  String get koryLastRoundBody =>
      'Era l\'ultimo turno: la tontina sarà chiusa. Il registro resta consultabile.';

  @override
  String get welcomeStart => 'Inizia';

  @override
  String get authAcceptAndContinue => 'Accetta e continua';

  @override
  String get authAcceptNotice =>
      'Toccando «Accetta e continua», accetti le condizioni d\'uso e l\'informativa sulla privacy e dichiari di avere l\'età richiesta.';

  @override
  String get deleteAccountTitle => 'Elimina il mio account';

  @override
  String get deleteAccountWarning => 'Questa azione è definitiva.';

  @override
  String get deleteAccountRemovedTitle => 'Cosa viene eliminato';

  @override
  String get deleteAccountRemovedProfile =>
      'Il tuo profilo, la tua foto e il tuo backup';

  @override
  String get deleteAccountRemovedChats => 'Le tue chat su questo telefono';

  @override
  String get deleteAccountRemovedBadge =>
      'Il tuo badge, senza rimborso del mese in corso';

  @override
  String get deleteAccountKeptTitle => 'Cosa rimane';

  @override
  String get deleteAccountKeptMessages =>
      'I messaggi già ricevuti dai tuoi contatti';

  @override
  String get deleteAccountKeptProof =>
      'Le tracce della modalità prova presso gli altri partecipanti';

  @override
  String get deleteAccountKeptKory =>
      'Il registro delle collette Kory, che non si cancella';

  @override
  String get deleteAccountConfirmLabel => 'Conferma il tuo numero';

  @override
  String get deleteAccountMismatch =>
      'Questo numero non corrisponde al tuo account.';

  @override
  String get deleteAccountFailed => 'Eliminazione non riuscita. Riprova.';

  @override
  String get helpTitle => 'Aiuto e supporto';

  @override
  String get helpSearchHint => 'Cerca nell\'aiuto';

  @override
  String get helpAskBaba => 'Chiedi a Baba';

  @override
  String get helpAskBabaSub => 'L\'assistente IA risponde subito';

  @override
  String get helpFaqTitle => 'Domande frequenti';

  @override
  String get helpQMoney => 'Pokou tocca i miei soldi?';

  @override
  String get helpAMoney =>
      'No. Collette, farmacie e corrieri si pagano da wallet a wallet. Pokou non trattiene mai i tuoi soldi.';

  @override
  String get helpQProof => 'Come funziona la modalità prova?';

  @override
  String get helpAProof =>
      'Attivata da un titolare di Pokou certificato, mantiene visibili, barrati, i messaggi eliminati o modificati. È sempre indicata in cima alla chat.';

  @override
  String get helpQSms => 'Non ricevo il codice SMS';

  @override
  String get helpASms =>
      'Controlla il numero e la rete, poi attendi la fine del conto alla rovescia per richiedere un codice. Pokou non ti chiederà mai questo codice, né per messaggio né per chiamata.';

  @override
  String get helpQCourier => 'Come diventare corriere Honam?';

  @override
  String get helpACourier =>
      'In Altro, tocca «Diventa corriere Honam»: identità, zone, wallet e regole d\'oro. Honam apre città per città.';

  @override
  String get helpQScam => 'Come riconoscere una truffa?';

  @override
  String get helpAScam =>
      'Diffida di chi chiede un codice SMS, il tuo PIN o un pagamento urgente. Pokou non lo fa mai. Blocca e segnala il contatto.';

  @override
  String get helpSupport => 'Scrivi al supporto';

  @override
  String get helpSupportSub => 'Risposta nell\'app';

  @override
  String get helpReport => 'Segnala un problema';

  @override
  String get helpNoResult => 'Nessuna domanda corrisponde. Chiedi a Baba.';

  @override
  String get aboutTitle => 'Informazioni su Pokou';

  @override
  String aboutVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get aboutNamesTitle => 'Il senso dei nostri nomi';

  @override
  String get aboutPokou => 'un nome baoulé';

  @override
  String get aboutKory => 'la conchiglia cauri';

  @override
  String get aboutHonam => '«aiutami», in ewe';

  @override
  String get aboutAssime => '«al mercato», in ewe';

  @override
  String get aboutWetri => '«mese», in ewe';

  @override
  String get aboutEpe => '«anno», in ewe';

  @override
  String get aboutNextNames =>
      'Anche i nostri prossimi servizi porteranno nomi di lingue africane.';

  @override
  String get aboutLicenses => 'Licenze del software libero';

  @override
  String get legalEssentials => 'L\'essenziale';

  @override
  String get legalFullText => 'Testo completo';

  @override
  String get termsE1 =>
      'Pokou non tocca mai il denaro: collette, farmacie e corrieri si pagano da wallet a wallet.';

  @override
  String get termsE2 =>
      'La modalità prova conserva traccia dei messaggi eliminati, ed è sempre indicato.';

  @override
  String get termsE3 => 'Honam non è un servizio di emergenza.';

  @override
  String get termsE4 =>
      'I badge a pagamento si disdicono in qualsiasi momento.';

  @override
  String get privacyE1 =>
      'Il tuo numero non viene mai mostrato a un venditore né a un corriere.';

  @override
  String get privacyE2 =>
      'Pokou non legge i tuoi messaggi. Una segnalazione invia al supporto solo gli ultimi 5.';

  @override
  String get privacyE3 =>
      'La posizione del corriere non viene conservata dopo la consegna.';

  @override
  String get privacyE4 =>
      'Gli annunci sponsorizzati sono mirati per città, mai a partire dai tuoi messaggi.';

  @override
  String get languageNote =>
      'La lingua dell\'app non cambia quella dei tuoi messaggi. I nomi Pokou, Kory, Honam e Assimé restano gli stessi in tutte le lingue.';

  @override
  String get securityPinWarning =>
      'Pokou non ti chiederà mai il PIN né il codice SMS, né per messaggio né per chiamata.';

  @override
  String get statusReplyPrivate =>
      'La tua risposta arriva in privato, nella vostra chat a due.';

  @override
  String get statusViewersNote =>
      'Solo tu vedi questo elenco. Le risposte arrivano in privato, nelle tue chat.';

  @override
  String get statusWhoSees => 'Chi vede i miei stati';

  @override
  String get attachCompressNote =>
      'Foto e video vengono compressi prima dell\'invio per risparmiare dati.';

  @override
  String get otpTitle => 'Inserisci il codice';

  @override
  String get pinForgot => 'PIN dimenticato?';

  @override
  String get pinTitle => 'Il tuo PIN';

  @override
  String statusReplyHint(String name) {
    return 'Rispondi a $name…';
  }

  @override
  String get statusReplyQuote => '↩ In risposta al tuo stato';

  @override
  String get statusReplySent => 'Risposta inviata in privato.';

  @override
  String get changeNumberTitle => 'Cambia numero';

  @override
  String get changeNumberOld => 'Numero precedente';

  @override
  String get changeNumberNew => 'Nuovo numero';

  @override
  String get changeNumberNotify => 'Avvisa i miei contatti';

  @override
  String get changeNumberNotifyAll => 'Tutti i miei contatti';

  @override
  String get changeNumberNotifyChatted => 'Chi ha chattato con me';

  @override
  String get changeNumberNotifyNone => 'Nessuno';

  @override
  String get changeNumberNotifyNoneSub =>
      'I tuoi gruppi vengono sempre avvisati';

  @override
  String get changeNumberInfo =>
      'Il tuo account, le chat, il badge Pokou certificato e le collette Kory ti seguono. Un codice viene inviato al nuovo numero.';

  @override
  String get changeNumberKoryWarning =>
      'Se raccogli una colletta, il numero di raccolta non cambia da solo: modificalo in Kory, i membri saranno avvisati.';

  @override
  String get changeNumberSendCode => 'Invia il codice';

  @override
  String get changeNumberCodeLabel => 'Codice ricevuto via SMS';

  @override
  String get changeNumberConfirm => 'Conferma la modifica';

  @override
  String get changeNumberDone => 'Il tuo numero è stato cambiato.';

  @override
  String get pinForgotIntro => 'Due modi per recuperare il tuo account:';

  @override
  String get pinForgotEmail => 'Via e-mail';

  @override
  String get pinForgotEmailSub =>
      'Se hai aggiunto un indirizzo: ti viene inviato un link di reimpostazione';

  @override
  String get pinForgotWait => 'Attendi 7 giorni';

  @override
  String get pinForgotWaitSub =>
      'Poi accedi senza PIN con il codice SMS, purché tu mantenga il numero';

  @override
  String get pinForgotWarning =>
      'Il ritardo di 7 giorni impedisce a chi ha rubato la tua SIM di prendere subito il tuo account.';

  @override
  String get pinForgotMeanwhile =>
      'Durante l\'attesa, i tuoi contatti continuano a vederti e i messaggi ti aspettano.';

  @override
  String get pinForgotContinue => 'Continua';

  @override
  String pinForgotScheduled(String date) {
    return 'Fatto. Dal $date, basterà il codice SMS per accedere.';
  }

  @override
  String get groupDelete => 'Elimina il gruppo';

  @override
  String groupDeleteTitle(String name) {
    return 'Eliminare «$name»?';
  }

  @override
  String get groupDeleteBody =>
      'Il gruppo scompare per tutti i membri, con i suoi messaggi. È definitivo.';

  @override
  String get groupDeleteFailed => 'Eliminazione non riuscita — riprova.';

  @override
  String get groupManageTitle => 'Gestisci il gruppo';

  @override
  String get groupManageSubtitle =>
      'Autorizzazioni, nuovi membri, messaggi effimeri';

  @override
  String get groupPermissions => 'Autorizzazioni';

  @override
  String get groupEditInfoSetting => 'Modifica nome e foto';

  @override
  String get groupSendSetting => 'Invia messaggi';

  @override
  String get groupApproveSetting => 'Approva nuovi membri';

  @override
  String get groupApproveSettingSub =>
      'Un amministratore approva ogni ingresso tramite link';

  @override
  String get groupAllMembers => 'Tutti i membri';

  @override
  String get groupDisappearing => 'Messaggi effimeri';

  @override
  String get groupDisappearingOff => 'Disattivati';

  @override
  String get groupDisappearing24h => '24 ore';

  @override
  String get groupDisappearing7d => '7 giorni';

  @override
  String get groupDisappearing90d => '90 giorni';

  @override
  String get groupJoinRequests => 'Richieste di ingresso';

  @override
  String get groupNoJoinRequest => 'Nessuna richiesta in attesa.';

  @override
  String get groupApprove => 'Accetta';

  @override
  String get groupReject => 'Rifiuta';

  @override
  String get groupJoinPending =>
      'Richiesta inviata: un amministratore deve approvare il tuo ingresso.';

  @override
  String get groupSettingsSaveFailed => 'Impostazione non salvata — riprova.';

  @override
  String get groupLeaveKoryNote =>
      'Lasciare il gruppo non elimina la colletta in corso: i tuoi contributi restano nel registro Kory.';

  @override
  String get messageWaiting => 'In attesa di questo messaggio…';

  @override
  String get callWaitingNotice =>
      'Sei già in chiamata. Rifiuta per mantenerla; accetta per terminarla.';

  @override
  String get callEndAndAccept => 'Termina e accetta';

  @override
  String get homeHelloOverline => 'Ciao';

  @override
  String get koryOverline => 'Risparmio solidale';

  @override
  String koryActiveCount(String count) {
    return '$count attive';
  }

  @override
  String get searchIntro =>
      'Cerca nei tuoi messaggi, canali e annunci di Assimé.';

  @override
  String get searchRecent => 'Ricerche recenti';

  @override
  String get homeTagline => 'Tutto ciò che conta, in un unico posto.';

  @override
  String get homeWhatToDo => 'Cosa vuoi fare?';

  @override
  String get homeInProgress => 'In corso';

  @override
  String get homeKoryPitch =>
      'Raccogli con altri per un progetto, un evento o una tontina.';

  @override
  String get homeHonamPitch =>
      'Invia la ricetta e ricevi i preventivi delle farmacie vicine.';

  @override
  String get homeAssimeTitle => 'Assimé';

  @override
  String get homeAssimeSubtitle => 'Annunci';

  @override
  String get homeAssimePitch => 'Compra e vendi vicino a te, in tutta fiducia.';

  @override
  String get homeAssimeCta => 'Vedi annunci';

  @override
  String get koryPledgeTitle => 'Mi impegno';

  @override
  String koryPledgeSubtitleDue(Object date, Object title) {
    return '$title · chiude il $date';
  }

  @override
  String get koryPledgeStart => 'Importo iniziale';

  @override
  String get koryPledgeDailyToggle => 'Aggiungi un importo giornaliero';

  @override
  String get koryPledgeDailyToggleSub =>
      'Aggiunto ogni giorno al tuo impegno, fino alla chiusura';

  @override
  String get koryPledgePerDay => 'Importo al giorno';

  @override
  String get koryPledgeStartRow => 'Partenza';

  @override
  String koryPledgeDailyRow(Object amount, Object days) {
    return '$amount × $days giorni';
  }

  @override
  String koryPledgeTotalAt(Object date) {
    return 'Totale impegnato al $date';
  }

  @override
  String get koryPledgeEditableNotice =>
      'Puoi modificare il tuo impegno per 8 ore. Poi diventa definitivo: entra nel registro e il collettore lo vede.';

  @override
  String get koryPledgeConfirm => 'Conferma il mio impegno';

  @override
  String get koryPledgeNeedDue =>
      'Un importo giornaliero richiede una data di fine.';

  @override
  String get koryMyPledgeTitle => 'Il mio impegno';

  @override
  String koryEditableFor(Object duration) {
    return 'Modificabile ancora per $duration';
  }

  @override
  String koryFirmToday(Object time) {
    return 'Diventa definitivo oggi alle $time';
  }

  @override
  String koryFirmOn(Object date, Object time) {
    return 'Diventa definitivo il $date alle $time';
  }

  @override
  String get koryDailyRow => 'Importo giornaliero';

  @override
  String koryPerDay(Object amount) {
    return '$amount al giorno';
  }

  @override
  String get koryPledgeEdit => 'Modifica il mio impegno';

  @override
  String get koryTimelineSaved => 'Impegno registrato';

  @override
  String get koryTimelineEditable => 'Modificabile per 8 ore';

  @override
  String koryTimelineUntil(Object time) {
    return 'Fino alle $time · il collettore non lo vede ancora';
  }

  @override
  String get koryTimelineFirm => 'Impegno definitivo';

  @override
  String get koryTimelineFirmSub => 'Nel registro, visibile al collettore';

  @override
  String get koryPayNowOrLater =>
      'Puoi versare subito o attendere la chiusura: Pokou ti ricorderà quanto resta da versare.';

  @override
  String get koryPayNow => 'Versa ora';

  @override
  String koryFirmSince(Object date) {
    return 'Definitivo dal $date';
  }

  @override
  String get koryPaidConfirmed => 'Versato e confermato';

  @override
  String get koryRemainingToPay => 'Resta da versare';

  @override
  String koryNextDailyAdd(Object amount) {
    return 'Prossima aggiunta giornaliera: domani, +$amount';
  }

  @override
  String get koryFirmNotice =>
      'Un impegno definitivo non si modifica più. In caso di imprevisti, scrivi al collettore: solo lui può annullarlo, e viene annotato nel registro.';

  @override
  String koryPayAmount(Object amount) {
    return 'Versa $amount';
  }

  @override
  String koryWriteTo(Object name) {
    return 'Scrivi a $name';
  }

  @override
  String koryMyPledgeTotal(Object amount) {
    return 'Impegnato: $amount';
  }

  @override
  String get koryContestedTitle => 'Contributo contestato';

  @override
  String koryContestedHead(Object name) {
    return '$name non ha riscontrato il tuo invio';
  }

  @override
  String koryContestedDeclared(Object amount, Object time) {
    return '$amount dichiarati alle $time';
  }

  @override
  String koryContestedReason(Object reason) {
    return 'Motivo: «$reason»';
  }

  @override
  String get koryCheckReference => 'Verifica il riferimento';

  @override
  String get koryAddSmsCapture => 'Aggiungi uno screenshot dell’SMS';

  @override
  String get koryContestedOperatorNotice =>
      'Se hai inviato a un altro numero, solo il tuo operatore può recuperare il denaro: non passa mai da Pokou.';

  @override
  String get koryResubmitted =>
      'Rinviato al collettore per una nuova verifica.';

  @override
  String get koryRejectReasonTitle => 'Perché non l’hai ricevuto?';

  @override
  String get koryRejectReasonHint =>
      'Es. Nulla ricevuto sul mio wallet a quell’ora.';

  @override
  String get koryFinishTitle => 'Fine della raccolta';

  @override
  String koryFinishSubtitle(Object title) {
    return '$title · vista del collettore';
  }

  @override
  String get koryFinishDueNotice =>
      'La data di fine è arrivata: tocca a te chiudere o prolungare.';

  @override
  String get koryEngaged => 'Impegnato';

  @override
  String koryParticipantsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partecipanti',
      one: '1 partecipante',
    );
    return '$_temp0';
  }

  @override
  String get koryConfirmedLabel => 'Confermato';

  @override
  String koryOnGoal(Object amount) {
    return 'su $amount';
  }

  @override
  String get koryToConfirmLabel => 'Da confermare';

  @override
  String koryDeclarationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dichiarazioni',
      one: '1 dichiarazione',
    );
    return '$_temp0';
  }

  @override
  String get koryWhatDoYouDo => 'Cosa fai?';

  @override
  String get koryCloseCollect => 'Chiudi la raccolta';

  @override
  String get koryCloseCollectSub =>
      'Ognuno riceve quanto gli resta da versare, e il link al suo wallet';

  @override
  String get koryExtend => 'Prolunga';

  @override
  String koryExtendSub(Object date) {
    return 'Nuova data di fine: $date · gli impegni restano definitivi';
  }

  @override
  String get koryFinishJournalNote =>
      'I partecipanti ricevono una notifica. Il registro conserva la data e la tua scelta.';

  @override
  String koryCloseAndNotify(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chiudi e avvisa i $count partecipanti',
      one: 'Chiudi e avvisa il partecipante',
    );
    return '$_temp0';
  }

  @override
  String koryExtendTo(Object date) {
    return 'Prolunga fino al $date';
  }

  @override
  String get koryFinishCta => 'Chiudi o prolunga';

  @override
  String get koryClosedTitle => 'Raccolta chiusa';

  @override
  String koryClosedSubtitle(Object title) {
    return '$title · vista del partecipante';
  }

  @override
  String koryClosedBody(Object date, Object name) {
    return '$name ha chiuso la raccolta il $date. Ti resta da versare il resto del tuo impegno.';
  }

  @override
  String get koryAlreadyConfirmed => 'Già confermato';

  @override
  String get koryToPay => 'Da versare';

  @override
  String get korySendTo => 'Invia a';

  @override
  String koryReferenceToGive(Object reference) {
    return 'Riferimento da indicare $reference';
  }

  @override
  String get koryCopyReference => 'Copia il riferimento';

  @override
  String koryPayFromWallet(Object amount) {
    return 'Versa $amount dal mio wallet';
  }

  @override
  String get koryAlreadySent => 'Ho già inviato';

  @override
  String get notifCenterTitle => 'Notifiche';

  @override
  String get notifReadAll => 'Segna tutto come letto';

  @override
  String get notifToday => 'Oggi';

  @override
  String get notifYesterday => 'Ieri';

  @override
  String get notifEarlier => 'Prima';

  @override
  String get notifMessagesElsewhere =>
      'I messaggi non compaiono qui: restano in Chat.';

  @override
  String get notifEmpty => 'Ancora nessuna notifica.';

  @override
  String get notifServiceCertified => 'Pokou certificato';

  @override
  String get notifSettings => 'Impostazioni notifiche';

  @override
  String get certPausedTitle => 'Badge in pausa';

  @override
  String certPausedBody(Object days, Object due, Object since) {
    return 'Il pagamento del $due non è andato a buon fine. Il tuo badge è nascosto dal $since, dopo $days giorni di tolleranza.';
  }

  @override
  String get certWhatRemains => 'Cosa resta';

  @override
  String get certRemainsChats => 'Le tue chat e i tuoi contatti';

  @override
  String get certRemainsTraces =>
      'Le tracce già registrate dalla modalità prova';

  @override
  String get certWhatPaused => 'Cosa è in pausa';

  @override
  String get certPausedBadge => 'Il badge e il nome verificato';

  @override
  String get certPausedProof =>
      'La modalità prova dei nuovi messaggi e l’esportazione datata';

  @override
  String get certPausedWallet =>
      'Il pagamento avviene dal tuo wallet. Se il saldo era insufficiente, ricaricalo e riprova.';

  @override
  String certPausedPay(Object amount) {
    return 'Paga $amount e mostra di nuovo il mio badge';
  }

  @override
  String get certChangePlan => 'Cambia formula';

  @override
  String get annSoldTitle => 'Segna come venduto';

  @override
  String get annSoldWho =>
      'A chi l’hai venduto? Questa persona potrà valutare la transazione.';

  @override
  String annSoldDiscussionOf(Object date) {
    return 'Chat del $date';
  }

  @override
  String get annSoldOutside => 'Qualcuno fuori da Pokou';

  @override
  String get annSoldOutsideSub =>
      'Nessuna valutazione possibile per questa vendita';

  @override
  String get annSoldFinalPrice => 'Prezzo finale';

  @override
  String get annSoldPriceHelp => 'Visibile solo a te e all’acquirente';

  @override
  String get annSoldConfirm => 'Conferma la vendita';

  @override
  String get annSoldBadge => 'Venduto';

  @override
  String get annSoldDone => 'Vendita registrata.';

  @override
  String get annRateTitle => 'Valuta la transazione';

  @override
  String get annRateHow => 'Com’è andata la tua transazione?';

  @override
  String get annRate1 => 'Deludente';

  @override
  String get annRate2 => 'Così così';

  @override
  String get annRate3 => 'Corretto';

  @override
  String get annRate4 => 'Molto bene';

  @override
  String get annRate5 => 'Eccellente';

  @override
  String annRateStars(Object count) {
    return '$count stelle su 5';
  }

  @override
  String get annRateWentWell => 'Cosa è andato bene';

  @override
  String get annTagAsDescribed => 'Conforme all’annuncio';

  @override
  String get annTagPunctual => 'Puntuale';

  @override
  String get annTagFairPrice => 'Prezzo rispettato';

  @override
  String get annTagFriendly => 'Gentile';

  @override
  String get annTagCommunication => 'Buona comunicazione';

  @override
  String get annRateComment => 'La tua opinione (facoltativa)';

  @override
  String get annRateNotice =>
      'La tua opinione mostra il tuo nome e l’iniziale del cognome. Solo una vendita confermata dal venditore può essere valutata, una sola volta.';

  @override
  String get annRatePublish => 'Pubblica la mia opinione';

  @override
  String get annRatePublished => 'Grazie, la tua opinione è pubblicata.';

  @override
  String get annRateAlready => 'Hai già valutato questa vendita.';

  @override
  String annRateSubtitle(Object product, Object seller) {
    return '$seller · $product';
  }
}
