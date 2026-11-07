// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Pokou';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionContinue => 'Continuar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionShare => 'Compartir';

  @override
  String get actionSearch => 'Buscar';

  @override
  String get actionAdd => 'Añadir';

  @override
  String get actionRemove => 'Quitar';

  @override
  String get actionSend => 'Enviar';

  @override
  String get actionJoin => 'Unirse';

  @override
  String get actionCreate => 'Crear';

  @override
  String get navChats => 'Chats';

  @override
  String get navStatus => 'Novedades';

  @override
  String get navCalls => 'Llamadas';

  @override
  String get navMarket => 'Mercado';

  @override
  String get chatsEmptyTitle => 'Sin chats';

  @override
  String get chatsEmptyBody => 'Tus conversaciones aparecerán aquí.';

  @override
  String get chatsSearchHint => 'Buscar';

  @override
  String get chatsTyping => 'escribiendo…';

  @override
  String chatsTypingNamed(String name) {
    return '$name está escribiendo…';
  }

  @override
  String get chatsUnknownContact => 'no está en tus contactos';

  @override
  String get chatsNoMessageYet => 'Aún no hay mensajes';

  @override
  String chatsYouPrefix(String message) {
    return 'Tú: $message';
  }

  @override
  String chatsGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grupos',
      one: '1 grupo',
      zero: 'Ningún grupo',
    );
    return '$_temp0';
  }

  @override
  String get newChatTitle => 'Nuevo chat';

  @override
  String get newChatSearchHint => 'Buscar un contacto';

  @override
  String get newChatNewGroup => 'Nuevo grupo';

  @override
  String get newChatNewCommunity => 'Nueva comunidad';

  @override
  String get newChatJoinByLink => 'Unirse con un enlace';

  @override
  String get newChatOnPokou => 'En Pokou Messenger';

  @override
  String get newChatInvite => 'Invitar a Pokou Messenger';

  @override
  String get newChatNoMatch => 'Ningún contacto coincide.';

  @override
  String get newChatNoRegisteredContact =>
      'Ninguno de tus contactos usa Pokou todavía.';

  @override
  String conversationSayHello(String name) {
    return 'Saluda a $name.';
  }

  @override
  String get conversationMessageHint => 'Mensaje';

  @override
  String get conversationEdit => 'Editar';

  @override
  String get conversationForward => 'Reenviar';

  @override
  String get conversationReply => 'Responder';

  @override
  String get conversationEditWindowOver =>
      'Este mensaje ya no se puede editar.';

  @override
  String get mediaPhoto => 'Foto';

  @override
  String get mediaVideo => 'Vídeo';

  @override
  String get mediaVoice => 'Mensaje de voz';

  @override
  String get mediaDocument => 'Documento';

  @override
  String get mediaLocation => 'Ubicación';

  @override
  String get offlineTitle => 'Sin conexión';

  @override
  String get offlineBody =>
      'Verás lo que ya está en este dispositivo. El resto llegará cuando vuelva la red.';

  @override
  String get offlineNothingCached =>
      'Todavía no hay nada guardado en este dispositivo.';

  @override
  String get offlineSending => 'Pendiente de envío';

  @override
  String get errorNetwork => 'No se puede conectar. Revisa tu red.';

  @override
  String get twoStepTitle => 'Verificación en dos pasos';

  @override
  String get twoStepBody =>
      'Esta cuenta está protegida por un código. Introdúcelo para terminar de iniciar sesión.';

  @override
  String get twoStepHint => 'Código de la cuenta';

  @override
  String get errorGeneric => 'Algo salió mal.';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileLanguage => 'Idioma';

  @override
  String get profileLanguageSystem => 'Idioma del teléfono';

  @override
  String get profileLanguageSubtitle => 'Elige el idioma de la aplicación';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageRussian => 'Ruso';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get sparkTitle => 'Spark';

  @override
  String get sparkSubtitle => 'La cita de hoy';

  @override
  String get sparkTabDiscover => 'Descubrir';

  @override
  String get sparkTabMatches => 'Coincidencias';

  @override
  String get sparkTabDates => 'Citas';

  @override
  String get sparkTabMe => 'Yo';

  @override
  String get sparkAddPhoto => 'Añadir una foto';

  @override
  String get sparkNoPhotoWarning =>
      'Añade una foto — sin ella casi nadie da like';

  @override
  String sparkPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String get sparkLike => 'Me gusta';

  @override
  String get sparkPass => 'Pasar';

  @override
  String get sparkAgeRestricted => 'Spark es solo para mayores de 18 años.';

  @override
  String get navProfile => 'Perfil';

  @override
  String get authWelcome => 'Bienvenido a Pokou';

  @override
  String get authSubtitle =>
      'Introduce tu número y te enviamos un código. ¿Nuevo en Pokou? Tu cuenta se crea en este paso.';

  @override
  String get authPhoneHint => 'Tu número';

  @override
  String get authPrivacyNote =>
      'Inicio de sesión seguro. Tu número solo sirve para verificar tu identidad.';

  @override
  String get authVerifyTitle => 'Verificación';

  @override
  String authCodeSentTo(String phone) {
    return 'Introduce el código de 6 dígitos enviado al $phone';
  }

  @override
  String get authChangeNumber => 'Cambiar número';

  @override
  String authResendIn(String time) {
    return 'Reenviar el código en $time';
  }

  @override
  String get authResendSms => 'Reenviar por SMS';

  @override
  String get authResendWhatsapp => 'Reenviar por WhatsApp';

  @override
  String get authCodeSentSms => 'Se envió un nuevo código por SMS.';

  @override
  String get authCodeSentWhatsapp => 'Se envió un nuevo código por WhatsApp.';

  @override
  String get chatsPin => 'Fijar';

  @override
  String get chatsUnpin => 'No fijar';

  @override
  String get chatsArchive => 'Archivar';

  @override
  String get chatsUnarchive => 'Desarchivar';

  @override
  String get chatsMute => 'Silenciar';

  @override
  String get chatsUnmute => 'Reactivar sonido';

  @override
  String get chatsTag => 'Etiquetar';

  @override
  String chatsTagNamed(String name) {
    return 'Etiquetar a $name';
  }

  @override
  String get chatsBlock => 'Bloquear';

  @override
  String chatsBlockTitle(String name) {
    return '¿Bloquear a $name?';
  }

  @override
  String get chatsBlockBody =>
      'Esta persona ya no podrá escribirte ni llamarte. No se le avisará.';

  @override
  String get chatsPinLimit => 'Ya hay tres chats fijados, que es el máximo.';

  @override
  String get chatsMute8h => '8 horas';

  @override
  String get chatsMute1w => '1 semana';

  @override
  String get chatsMuteAlways => 'Siempre';

  @override
  String get chatsAddContact => 'Añadir a mis contactos';

  @override
  String get chatsActionFailed => 'No se pudo hacer ahora mismo.';

  @override
  String get chatsNoResult => 'Sin resultados.';

  @override
  String get chatsConnectFailed => 'No se puede conectar.';

  @override
  String get navModules => 'Módulos';

  @override
  String get navBroadcasts => 'Listas de difusión';

  @override
  String get navYou => 'Tú';

  @override
  String get convProductFallback => 'Producto';

  @override
  String get convOrderUpdated => 'Pedido actualizado';

  @override
  String get convReactionFailed => 'No se pudo reaccionar.';

  @override
  String get convPermissionDenied => 'Permiso denegado.';

  @override
  String get convAttachDocument => 'Documento';

  @override
  String get convAttachGallery => 'Foto (galería)';

  @override
  String get convAttachVideo => 'Vídeo (galería)';

  @override
  String get convAttachCamera => 'Cámara';

  @override
  String get convEditTitle => 'Editar mensaje';

  @override
  String get convEditHint => 'Tu mensaje';

  @override
  String convForwarded(String name) {
    return 'Mensaje reenviado a $name.';
  }

  @override
  String get convForwardFailed => 'No se pudo reenviar.';

  @override
  String get convRecordVoice => 'Grabar una nota de voz';

  @override
  String get mediaVoiceNote => 'Nota de voz';

  @override
  String get mediaMessage => 'Mensaje';

  @override
  String get newChatInviteAction => 'Invitar';

  @override
  String get profileGallery => 'Galería';

  @override
  String get profileCamera => 'Cámara';

  @override
  String get profileEdit => 'Editar perfil';

  @override
  String get profileFullName => 'Nombre completo';

  @override
  String get profileAbout => 'Acerca de';

  @override
  String get profileUpdateFailed => 'No se pudo actualizar.';

  @override
  String get profileVerifiedPhone => 'Identidad verificada por teléfono';

  @override
  String get profilePrivacySecurity => 'Privacidad y seguridad';

  @override
  String get profileShieldMode => 'Modo Escudo';

  @override
  String get profileShieldOn => 'Modo Escudo activado';

  @override
  String get profileShieldOff => 'Modo Escudo desactivado';

  @override
  String get profileConnection => 'Conexión';

  @override
  String get profileEncryptedTls => 'Cifrada (TLS)';

  @override
  String get profileStatusVisibility => 'Visibilidad de los estados';

  @override
  String get commonEnabled => 'Activado';

  @override
  String get commonDisabled => 'Desactivado';

  @override
  String get commonLoading => 'Cargando…';

  @override
  String get profileDevices => 'Dispositivos vinculados';

  @override
  String get profileNotifications => 'Notificaciones';

  @override
  String get profileStorage => 'Almacenamiento y datos';

  @override
  String get profileDataSaver => 'Ahorro de datos';

  @override
  String get profileSystemPrefs => 'Preferencias del sistema';

  @override
  String get profileSignOut => 'Cerrar sesión';

  @override
  String modulesActivated(String name) {
    return '$name está activado.';
  }

  @override
  String get modulesUnavailable => 'Módulos no disponibles';

  @override
  String get modulesCheckNetwork =>
      'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get modulesEmptyTitle => 'Nada que añadir por ahora';

  @override
  String get modulesEmptyBody =>
      'Los nuevos módulos aparecerán aquí. No tienes que hacer nada mientras tanto.';

  @override
  String get modulesMine => 'Mis apps';

  @override
  String get modulesRecommended => 'Recomendados';

  @override
  String get modulesRecommendedBy => 'Elegidos por nuestro equipo';

  @override
  String get modulesPopular => 'Populares';

  @override
  String get modulesPopularSub => 'Los más activados ahora mismo';

  @override
  String get modulesEnable => 'Activar';

  @override
  String get modulesDisable => 'Desactivar';

  @override
  String get modulesEnableFailed => 'No se pudo activar.';

  @override
  String modulesComingSoon(String name) {
    return '$name llegará pronto. Actualiza la app para tenerlo en cuanto salga.';
  }

  @override
  String modulesUserCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas lo usan',
      one: '1 persona lo usa',
    );
    return '$_temp0';
  }

  @override
  String get sparkEnableLocation => 'Activa la ubicación en tu teléfono.';

  @override
  String get sparkLocationNeeded =>
      'Sin ubicación, Spark no puede saber quién está cerca de ti.';

  @override
  String get sparkLocationFailed => 'No se pudo obtener tu ubicación.';

  @override
  String get sparkFeedUnavailable => 'Flujo no disponible';

  @override
  String get sparkPickIntentTitle => 'Elige tu carta del momento';

  @override
  String get sparkPickIntentBody =>
      'Di qué buscas hoy para ver quién busca lo mismo.';

  @override
  String get sparkLocationStale => 'Tu ubicación no está actualizada';

  @override
  String get sparkLocationStaleBody =>
      'Spark solo muestra gente a menos de 5 km. Sin ubicación reciente no puede mostrar nada.';

  @override
  String get sparkShareLocation => 'Compartir mi ubicación';

  @override
  String get sparkQuotaTitle => 'Ya viste los perfiles de hoy';

  @override
  String get sparkQuotaBody =>
      'Vuelve mañana o consigue Spark+ para ver sin límite.';

  @override
  String get sparkNobodyTitle => 'Nadie por ahora';

  @override
  String get sparkNobodyBody =>
      'Poca gente busca lo mismo aquí y ahora. Inténtalo más tarde o cambia de carta.';

  @override
  String get sparkPickCard => 'Elige tu carta';

  @override
  String get sparkTodayLooking => 'Lo que buscas hoy';

  @override
  String get sparkCardExpired => 'Tu carta ha expirado';

  @override
  String sparkHoursLeft(int hours) {
    return 'Quedan $hours h';
  }

  @override
  String sparkMinutesLeft(int minutes) {
    return 'Quedan $minutes min';
  }

  @override
  String get sparkIntentSheetTitle => 'Hoy busco';

  @override
  String get sparkIntentSheetBody =>
      'Tu carta expira en 24 h. Solo verás gente que eligió lo mismo.';

  @override
  String get sparkLikesExhausted =>
      'Se acabaron tus likes de hoy. Consigue un paquete en «Yo».';

  @override
  String get sparkMatchesUnavailable => 'Coincidencias no disponibles';

  @override
  String get sparkNoMatchTitle => 'Todavía ninguna coincidencia';

  @override
  String get sparkNoMatchBody =>
      'Cuando os gustáis los dos, se abre una sala de diez minutos. Ahí es donde se juega todo.';

  @override
  String get sparkOpenRooms => 'Salas abiertas';

  @override
  String get sparkRoomsClose => 'Se cierran solas';

  @override
  String get sparkMyMatches => 'Mis coincidencias';

  @override
  String get sparkNext => 'Siguiente';

  @override
  String get sparkPhotoFailed => 'No se pudo añadir la foto.';

  @override
  String get sparkGoFaster => 'Ir más rápido';

  @override
  String get sparkNoExpiry => 'Sin caducidad';

  @override
  String get sparkPlusActive => 'Activo — amplía tu suscripción';

  @override
  String get sparkPlusPitch => 'Perfiles ilimitados, un mes';

  @override
  String get sparkBoost => 'Perfil destacado';

  @override
  String get sparkBoostPitch => 'En lo alto del flujo durante una hora';

  @override
  String get sparkAroundMe => 'A mi alrededor';

  @override
  String get sparkSafety => 'Seguridad';

  @override
  String get sparkSafetyPitch => 'Alerta discreta y círculo de confianza';

  @override
  String get sparkWingman => 'La opinión de mis amigos';

  @override
  String get sparkWingmanPitch => 'Perfiles sobre los que te piden opinión';

  @override
  String get sparkUploading => 'Enviando…';

  @override
  String get sparkKarma => 'Street Cred';

  @override
  String get sparkCanInvite => 'Puedes invitar';

  @override
  String get sparkCannotInvite =>
      'Demasiado bajo para invitar. Cumple tus citas.';

  @override
  String sparkLikersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas te dieron like',
      one: 'Una persona te dio like',
    );
    return '$_temp0';
  }

  @override
  String get sparkSeeWho => 'Ver quién';

  @override
  String get sparkFindInDiscover => 'Encuéntralos en Descubrir.';

  @override
  String get sparkPaymentPendingLikers =>
      'La lista se abrirá en cuanto se confirme el pago.';

  @override
  String get sparkPaymentPendingLikes =>
      'Tus likes llegarán en cuanto se confirme el pago.';

  @override
  String get sparkPaymentPendingPlus =>
      'Spark+ se activará en cuanto se confirme el pago.';

  @override
  String get sparkPaymentPendingBoost =>
      'Tu perfil subirá en cuanto se confirme el pago.';

  @override
  String get sparkBirthDateLabel => 'Tu fecha de nacimiento';

  @override
  String get sparkNameAndBirthNeeded =>
      'Un nombre y una fecha de nacimiento, como mínimo.';

  @override
  String get sparkProfileFailed => 'No se pudo crear el perfil.';

  @override
  String get sparkCreateProfile => 'Crea tu perfil';

  @override
  String get sparkStep1Title => 'Dices qué buscas, hoy';

  @override
  String get sparkStep1Body =>
      'Tu carta caduca en 24 h. Solo ves gente que busca lo mismo, a menos de 5 km.';

  @override
  String get sparkStep2Title => 'Diez minutos de voz antes de escribir';

  @override
  String get sparkStep2Body =>
      'Tras un match se abre una sala: solo voz y stickers. Los perfiles falsos no la superan.';

  @override
  String get sparkStep3Title => 'Tus allegados saben dónde estás';

  @override
  String get sparkStep3Body =>
      'Un gesto discreto avisa a tu círculo con tu ubicación. También te preguntamos si todo va bien durante la cita.';

  @override
  String get sparkSeparateTitle => 'Tu perfil está separado de Pokou';

  @override
  String get sparkSeparateBody =>
      'Tu nombre y número de Pokou nunca se muestran aquí. Elige qué quieres mostrar.';

  @override
  String get sparkDisplayName => 'Nombre visible';

  @override
  String get sparkNameExample => 'Ej.: Ama';

  @override
  String get sparkBirthDate => 'Fecha de nacimiento';

  @override
  String get sparkBirthDateLocked => 'No podrá cambiarse después.';

  @override
  String get sparkChoose => 'Elegir';

  @override
  String get sparkYouAre => 'Eres';

  @override
  String get sparkWoman => 'Una mujer';

  @override
  String get sparkMan => 'Un hombre';

  @override
  String get sparkOther => 'Otro';

  @override
  String get sparkBioLabel => 'Dos palabras sobre ti (opcional)';

  @override
  String get sparkBioHint => 'Lo que conviene saber antes de conocerte';

  @override
  String get sparkCreateAction => 'Crear mi perfil';

  @override
  String get truthSubtitle => 'Una pregunta pagada, una respuesta libre';

  @override
  String get truthAsk => 'Hacer una pregunta';

  @override
  String get truthForMe => 'Para mí';

  @override
  String get truthMine => 'Mis preguntas';

  @override
  String get truthUnavailable => 'Preguntas no disponibles';

  @override
  String get truthEmptyTitle => 'Sin preguntas por ahora';

  @override
  String get truthEmptyBody =>
      'Cuando alguien pague por hacerte una pregunta, aparecerá aquí. Seguirás siendo libre de rechazar.';

  @override
  String get truthYourAnswer => 'Tu respuesta';

  @override
  String get truthAnswerPrivacy =>
      'Solo va a la persona que pagó. Pokou no la republica en ningún sitio.';

  @override
  String get truthWhatToSay => 'Lo que quieres decir';

  @override
  String get truthSendAnswer => 'Enviar mi respuesta';

  @override
  String get truthAskedAnon => 'Preguntado de forma anónima';

  @override
  String get truthDecline => 'Rechazar';

  @override
  String get truthAnswer => 'Responder';

  @override
  String get truthDeclineFree =>
      'Rechazar no te cuesta nada. Solo cobras si respondes.';

  @override
  String get truthHistoryUnavailable => 'Historial no disponible';

  @override
  String get truthNothingAsked => 'Todavía no has preguntado nada';

  @override
  String get truthNothingAskedBody =>
      'Pregunta a alguien: verá el importe y la pregunta, nunca tu nombre.';

  @override
  String get truthAnswered => 'Respondida';

  @override
  String get truthDeclined => 'Rechazada';

  @override
  String get truthPending => 'Pendiente';

  @override
  String truthToSomeone(String name) {
    return 'A $name';
  }

  @override
  String get truthSomeone => 'alguien';

  @override
  String get truthPreferredNot => 'Prefirió no responder.';

  @override
  String get truthAwaitingAnswer => 'Esperando una respuesta.';

  @override
  String get truthToWhom => '¿A quién?';

  @override
  String truthQuestionTo(String name) {
    return 'Una pregunta para $name';
  }

  @override
  String get truthAnonTitle => 'Tu nombre no se muestra';

  @override
  String get truthAnonBody =>
      'Ve el importe y la pregunta, nunca quién los envió.';

  @override
  String get truthFreeTitle => 'Sigue siendo libre de rechazar';

  @override
  String get truthFreeBody =>
      'Rechazar no le reporta nada: solo cobra si responde.';

  @override
  String get truthPrivateTitle => 'La respuesta solo va a ti';

  @override
  String get truthPrivateBody =>
      'Pokou no la republica en ningún sitio y caduca a los siete días sin respuesta.';

  @override
  String get truthYourQuestion => 'Tu pregunta';

  @override
  String get truthQuestionHint => 'Lo que de verdad te gustaría saber';

  @override
  String get truthHowMuch => 'Cuánto ofreces';

  @override
  String truthAskForAmount(int amount) {
    return 'Hacer la pregunta — $amount FCFA';
  }

  @override
  String get truthWriteFirst => 'Escribe primero tu pregunta.';

  @override
  String get truthPaymentPending =>
      'Tu pregunta saldrá en cuanto se confirme el pago.';

  @override
  String get hypeFinished => 'Terminado';

  @override
  String get hypeSubtitle => 'Un objetivo, toda la sala';

  @override
  String get hypeLaunch => 'Lanzar un objetivo';

  @override
  String get hypeOngoing => 'En curso';

  @override
  String get hypeMine => 'Los míos';

  @override
  String get hypeNoneTitle => 'Ningún objetivo en curso';

  @override
  String get hypeNoneBody =>
      'Cuando un creador lanza un objetivo, aparece aquí hasta que se alcanza.';

  @override
  String get hypeMineEmpty => 'Nada por ahora';

  @override
  String get hypeMineEmptyBody =>
      'Tus objetivos y los que has apoyado aparecerán aquí.';

  @override
  String get hypeUnavailable => 'Objetivos no disponibles';

  @override
  String get hypeCreator => 'Creador';

  @override
  String get hypeTierReached => 'Meta alcanzada';

  @override
  String get hypeGoal => 'Objetivo';

  @override
  String get hypeNotFound => 'Objetivo no encontrado';

  @override
  String get hypeMaybeRemoved => 'Puede que se haya retirado.';

  @override
  String get hypeUnlocked =>
      'Se alcanzó la meta. La promesa está desbloqueada.';

  @override
  String get hypeContribute => 'Hacer avanzar la barra';

  @override
  String get hypePushers => 'Quiénes empujan';

  @override
  String get hypeBeFirst => 'Nadie todavía. Sé el primero.';

  @override
  String get hypeContributor => 'Contribuidor';

  @override
  String commonDueToYou(int amount) {
    return 'Te corresponde: $amount FCFA';
  }

  @override
  String get commonManualPayout =>
      'El pago lo realiza el equipo de Pokou, a petición.';

  @override
  String get hypeStepTogetherTitle => 'Todos empujan juntos';

  @override
  String get hypeStepTogetherBody =>
      'Cada aportación sube la barra, y todos ven alcanzarla a la vez.';

  @override
  String get hypeStepPromiseTitle => 'Lo que prometes';

  @override
  String get hypeStepPromiseBody =>
      'Visible antes de que nadie pague. Es tu compromiso si se alcanza el objetivo.';

  @override
  String get hypeStepOneTitle => 'Un solo objetivo a la vez';

  @override
  String get hypeStepOneBody =>
      'Dos objetivos a la vez pondrían a tus contribuidores a competir consigo mismos.';

  @override
  String get commonTitle => 'Título';

  @override
  String get hypeTitleExample => 'Ej.: 100 000 y canto';

  @override
  String get hypePromiseLabel => 'Lo que desbloqueas si se alcanza el objetivo';

  @override
  String get hypePromiseHint =>
      'Sé concreto: es lo que compran tus contribuidores.';

  @override
  String get hypeGoalAmount => 'Objetivo en FCFA';

  @override
  String get commonDuration => 'Duración';

  @override
  String get hypeLaunchAction => 'Lanzar';

  @override
  String get hypeFieldsNeeded => 'Se necesitan título, promesa y objetivo.';

  @override
  String get hypeAlreadyRunning => 'Ya tienes un objetivo en curso.';

  @override
  String get hypeContributeNote =>
      'Tu aportación hace avanzar la barra y desbloquea contenido. No es reembolsable.';

  @override
  String get commonAmount => 'Importe';

  @override
  String hypeJoinForAmount(int amount) {
    return 'Participar — $amount FCFA';
  }

  @override
  String get hypePaymentPending =>
      'La barra avanzará en cuanto se confirme el pago.';

  @override
  String get ceremonyWedding => 'Boda';

  @override
  String get ceremonyBaptism => 'Bautizo';

  @override
  String get ceremonyFuneral => 'Duelo';

  @override
  String get ceremonyOther => 'Otro';

  @override
  String get ceremonyTitle => 'Botes';

  @override
  String get ceremonySubtitle => 'Las aportaciones, sin insistir';

  @override
  String get ceremonyNew => 'Nuevo bote';

  @override
  String get ceremonyUnavailable => 'Botes no disponibles';

  @override
  String get ceremonyNone => 'Sin botes';

  @override
  String get ceremonyNoneBody =>
      'Boda, bautizo, duelo: crea el bote, invita, y cada uno aporta lo que puede.';

  @override
  String ceremonyGoalHint(int amount) {
    return 'Objetivo orientativo: $amount FCFA';
  }

  @override
  String get ceremonyOne => 'Bote';

  @override
  String get ceremonyNotFound => 'Bote no encontrado';

  @override
  String get ceremonyMaybeClosed => 'Puede que se haya cerrado.';

  @override
  String get ceremonyJoin => 'Participar';

  @override
  String get ceremonyClose => 'Cerrar el bote';

  @override
  String get ceremonyContributions => 'Aportaciones';

  @override
  String get ceremonyNobodyYet => 'Nadie ha aportado todavía.';

  @override
  String get ceremonyAnonGift => 'Aportación anónima';

  @override
  String get ceremonyContributor => 'Contribuidor';

  @override
  String get ceremonyCollected => 'recaudados';

  @override
  String get ceremonyYouOrganize => 'tú organizas';

  @override
  String get ceremonyNewSubtitle =>
      'Tú sigues las aportaciones. Pokou no insiste a quien no ha dado.';

  @override
  String get ceremonyOccasion => 'Ocasión';

  @override
  String get ceremonyTitleExample => 'Ej.: Boda de Kossi y Ama';

  @override
  String get ceremonyFewWords => 'Unas palabras (opcional)';

  @override
  String get ceremonyFewWordsHint =>
      'La fecha, el lugar, para qué será el dinero.';

  @override
  String get ceremonyGoalOptional => 'Objetivo en FCFA (opcional)';

  @override
  String get ceremonyGoalNote =>
      'Orientativo: el bote sigue aceptando más allá.';

  @override
  String get ceremonyCreate => 'Crear el bote';

  @override
  String get ceremonyNeedTitle => 'Ponle un título al bote.';

  @override
  String ceremonyJoinTo(String title) {
    return 'Participar — $title';
  }

  @override
  String get ceremonyOtherAmount => 'O otro importe';

  @override
  String get ceremonyWordOptional => 'Unas palabras (opcional)';

  @override
  String get ceremonyWordHint => 'Lo que quieres decirles';

  @override
  String get ceremonyAnonToggle => 'Aportar de forma anónima';

  @override
  String get ceremonyAnonNote =>
      'Tu nombre se oculta. El importe sigue en el total.';

  @override
  String ceremonyJoinAmount(int amount) {
    return 'Participar — $amount FCFA';
  }

  @override
  String get ceremonyMinimum => 'El mínimo son 100 FCFA.';

  @override
  String get ceremonyPaymentPending =>
      'Tu aportación aparecerá en cuanto se confirme el pago.';

  @override
  String get vipSubtitle => 'Tus suscriptores, tu espacio';

  @override
  String get vipDiscover => 'Descubrir';

  @override
  String get vipMySubs => 'Mis suscripciones';

  @override
  String get vipMyRoom => 'Mi sala';

  @override
  String get vipNoRoomOpen => 'Ninguna sala abierta';

  @override
  String get vipNoRoomOpenBody =>
      'Las salas que abran los creadores aparecerán aquí.';

  @override
  String get vipNoSub => 'Sin suscripciones';

  @override
  String get vipNoSubBody =>
      'Suscríbete a una sala para encontrar aquí todo lo que publica su creador.';

  @override
  String get vipUnavailable => 'Salas no disponibles';

  @override
  String get vipCreator => 'Creador';

  @override
  String vipUntil(String date) {
    return 'Hasta el $date';
  }

  @override
  String get vipPaymentPending =>
      'La sala se abrirá en cuanto se confirme el pago.';

  @override
  String get vipRoom => 'Sala';

  @override
  String get vipNotFound => 'Sala no encontrada';

  @override
  String get vipMaybeClosed => 'Puede que se haya cerrado.';

  @override
  String get vipStepAllTitle => 'Todo lo que se publica aquí';

  @override
  String get vipStepAllBody =>
      'Ves de inmediato lo ya publicado, y todo lo que venga.';

  @override
  String get vipStepDaysTitle => 'Treinta días';

  @override
  String get vipStepDaysBody =>
      'El acceso termina solo al vencimiento. Nada continúa si no lo decides.';

  @override
  String get vipStepNoRenewTitle => 'Sin renovación automática';

  @override
  String get vipStepNoRenewBody =>
      'Pokou no guarda tu método de pago. Para continuar, pagas otra vez, una sola.';

  @override
  String vipSubscribeFor(int amount) {
    return 'Suscribirse — $amount FCFA';
  }

  @override
  String get vipLockedTitle => 'Contenido solo para suscriptores';

  @override
  String get vipLockedBody =>
      'El resto de la sala se abre en cuanto se confirme el pago.';

  @override
  String get vipNothingYet => 'Nada todavía';

  @override
  String get vipNothingYetBody => 'Esta sala aún no tiene publicaciones.';

  @override
  String get vipPosts => 'Publicaciones';

  @override
  String get vipRoomUnavailable => 'Sala no disponible';

  @override
  String get vipOpenYourRoom => 'Abre tu sala';

  @override
  String get vipOpenYourRoomBody =>
      'Tus suscriptores pagan una vez por treinta días y ven todo lo que publicas. Tú pones el precio.';

  @override
  String get vipOpenAction => 'Abrir mi sala';

  @override
  String get vipPublish => 'Publicar';

  @override
  String get vipSeeMyRoom => 'Ver mi sala';

  @override
  String get vipOpen => 'Abierta';

  @override
  String get vipClosed => 'Cerrada';

  @override
  String get vipEarnings => 'Tus ingresos';

  @override
  String vipCollected(int amount) {
    return '$amount FCFA recaudados';
  }

  @override
  String get vipDueNote =>
      'El importe que te corresponde. El pago lo hace el equipo de Pokou, a petición.';

  @override
  String get vipEditRoom => 'Editar mi sala';

  @override
  String get vipPriceNote =>
      'Un precio nuevo solo se aplica a las suscripciones siguientes: cada uno pagó la suya por adelantado.';

  @override
  String get vipRoomName => 'Nombre de la sala';

  @override
  String get vipRoomNameHint => 'Ej.: Entre bastidores';

  @override
  String get vipPitchLabel => 'Lo que encontrarán tus suscriptores';

  @override
  String get vipPitchNote =>
      'Visible antes de pagar: es lo que da ganas de suscribirse.';

  @override
  String get vipPitchHint => 'Fotos, anuncios, mensajes de voz…';

  @override
  String get vipMonthlyPrice => 'Precio mensual en FCFA';

  @override
  String get vipAcceptNew => 'Aceptar nuevos suscriptores';

  @override
  String get vipAcceptNewNote =>
      'Tus suscriptores actuales conservan el acceso hasta el vencimiento.';

  @override
  String get vipFieldsNeeded => 'Se necesitan nombre, descripción y precio.';

  @override
  String get vipPublishTitle => 'Publicar en mi sala';

  @override
  String get vipPublishNote => 'Visible solo para tus suscriptores actuales.';

  @override
  String get vipYourMessage => 'Tu mensaje';

  @override
  String get vipShareHint => 'Lo que quieres compartir';

  @override
  String vipEarningsSummary(int count, int amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suscripciones',
      one: '1 suscripción',
    );
    return '$_temp0 • $amount FCFA recaudados';
  }

  @override
  String get datesUnavailable => 'Salidas no disponibles';

  @override
  String get datesNone => 'Ninguna salida prevista';

  @override
  String get datesNoneBody =>
      'Tras la sala, propón un sitio. Pagas por adelantado y el dinero solo se libera cuando ambos confirmáis.';

  @override
  String get datesNotNow => 'No es el momento para eso.';

  @override
  String get datesCancelTitle => '¿Cancelar la salida?';

  @override
  String get datesCancelFree =>
      'Faltan más de 24 h: se te reembolsará íntegramente.';

  @override
  String get datesCancelLate =>
      'Quedan menos de 24 h. El local ya ha reservado; tu pago queda para él.';

  @override
  String get datesKeep => 'Mantener';

  @override
  String get datesCancelAction => 'Cancelar la salida';

  @override
  String get datesAwaitingPayment => 'Pendiente de pago';

  @override
  String get datesPaidToConfirm => 'Pagado — por confirmar';

  @override
  String get datesDone => 'Terminado';

  @override
  String get datesRefunded => 'Reembolsado';

  @override
  String get datesNoShow => 'Plantón reportado';

  @override
  String get datesCancelled => 'Cancelado';

  @override
  String get datesOne => 'Salida';

  @override
  String datesWithPeer(String venue, String name) {
    return '$venue • con $name';
  }

  @override
  String get datesYourMatch => 'tu match';

  @override
  String get datesWentWell => 'Fue bien';

  @override
  String get datesYouConfirmed =>
      'Has confirmado. Esperamos la confirmación de la otra parte.';

  @override
  String get datesNoShowAction => 'No vino';

  @override
  String get datesVoucher => 'Tu vale, para dar en el sitio';

  @override
  String get datesPickBoth => 'Elige una fórmula y una hora.';

  @override
  String get datesVoucherPending =>
      'Tu vale se emitirá en cuanto se confirme el pago.';

  @override
  String get datesBookingFailed => 'La reserva no se completó.';

  @override
  String get datesWhereTo => '¿Adónde vais?';

  @override
  String get datesStepPayTitle => 'Pagas por adelantado, nada se libera';

  @override
  String get datesStepPayBody =>
      'El dinero queda retenido. Solo llega al local si ambos confirmáis.';

  @override
  String get datesStepCancelTitle => 'Cancelación libre con más de 24 h';

  @override
  String get datesStepCancelBody =>
      'Reembolso íntegro. Por debajo, el local ya ha reservado y se queda tu pago.';

  @override
  String get datesStepNoShowTitle => 'Si la otra persona no viene';

  @override
  String get datesStepNoShowBody =>
      'La mitad vuelve a ti. La app no cobra nada por una cita fallida.';

  @override
  String get datesThePackage => 'La fórmula';

  @override
  String get datesPacksUnavailable =>
      'Las fórmulas no están disponibles ahora mismo.';

  @override
  String get datesNoPackNearby => 'Todavía no hay fórmulas cerca de ti.';

  @override
  String get datesWhen => '¿Cuándo?';

  @override
  String get datesPickWhen => 'Elegir la fecha y la hora';

  @override
  String get datesBook => 'Reservar';

  @override
  String datesBookAmount(int amount) {
    return 'Reservar — $amount FCFA';
  }

  @override
  String get roomNeedMic =>
      'Sin micrófono solo hay stickers: la sala es de voz.';

  @override
  String get roomVoiceFailed => 'La nota de voz no se envió.';

  @override
  String get roomBothYes => 'Adelante. Ya puedes proponer una salida.';

  @override
  String get roomWaitingOther =>
      'Anotado. Esperamos su respuesta antes de que acabe la cuenta atrás.';

  @override
  String get roomExtendPending =>
      'Diez minutos más en cuanto se confirme el pago.';

  @override
  String get roomTitle => 'Sala de entrada';

  @override
  String get roomNotFound => 'Sala no encontrada';

  @override
  String get roomMaybeClosed => 'Puede que se haya cerrado.';

  @override
  String get roomVoiceOnly => 'Solo voz y stickers';

  @override
  String get roomTimeUp => 'Se acabó el tiempo.';

  @override
  String roomTimeLeft(String clock) {
    return 'Quedan $clock para decidir juntos';
  }

  @override
  String get roomSaySomething => 'Di algo';

  @override
  String get roomNoTextBody =>
      'Aquí no hay texto: una nota de voz o un sticker. Eso distingue a una persona real de un mensaje copiado.';

  @override
  String get roomVoice => 'Voz';

  @override
  String get roomWaitingReply => 'Esperando su respuesta';

  @override
  String roomExtendFor(int amount) {
    return 'Diez minutos más — $amount FCFA';
  }

  @override
  String get roomBothSaidYes => 'Ambos habéis dicho que sí.';

  @override
  String get roomSaved => 'El match está salvado. Puedes proponer una salida.';

  @override
  String get roomClosedNoAnswer => 'La sala se cerró sin respuesta.';

  @override
  String get roomSuggestDate => 'Proponer una salida';

  @override
  String get safetyCheckin => '¿Todo bien?';

  @override
  String get safetyCheckinBody =>
      'Si no respondes en cinco minutos, se avisará a tu círculo de seguridad con tu ubicación.';

  @override
  String get safetyAllGood => 'Sí, todo bien';

  @override
  String get safetyCircleAlerted => 'Se ha avisado a tu círculo.';

  @override
  String get safetyNoCircle =>
      'Alerta registrada. Añade allegados para que se les avise la próxima vez.';

  @override
  String get safetyWhoToAlert => '¿A quién avisar?';

  @override
  String get safetyWhoToAlertBody =>
      'Estas personas recibirán tu ubicación en directo si lanzas una alerta.';

  @override
  String get safetyTitle => 'Seguridad';

  @override
  String get safetySubtitle => 'Quién se entera si algo va mal';

  @override
  String get safetyQuietAlert => 'Alerta discreta';

  @override
  String get safetyQuietAlertBody =>
      'Avisa a tu círculo con tu ubicación. No aparece nada en la pantalla de tu teléfono.';

  @override
  String get safetyTrigger => 'Lanzar una alerta';

  @override
  String get safetyMyCircle => 'Mi círculo';

  @override
  String get safetyThreeEnough => 'Con tres personas basta';

  @override
  String get safetyNobodyYet =>
      'Nadie por ahora. Sin círculo, una alerta se registra pero no avisa a nadie.';

  @override
  String get safetyAddSomeone => 'Añadir a alguien';

  @override
  String get wingmanTitle => 'Opinión de amigos';

  @override
  String get wingmanAnon => 'Tu opinión es anónima';

  @override
  String get wingmanUnavailable => 'Solicitudes no disponibles';

  @override
  String get wingmanNothing => 'Nada que valorar';

  @override
  String get wingmanNothingBody =>
      'Cuando un amigo te pregunte qué opinas de un perfil, aparecerá aquí.';

  @override
  String wingmanAsksYou(String name) {
    return '$name pide tu opinión';
  }

  @override
  String get wingmanMeh => 'Meh';

  @override
  String get wingmanWorthIt => 'Vale la pena';

  @override
  String get wingmanPrivacy =>
      'Tu amigo solo verá si el grupo aprueba, nunca quién dijo qué.';

  @override
  String get marketLocationOff => 'El servicio de ubicación está desactivado.';

  @override
  String get marketGpsDenied => 'Permiso de GPS denegado.';

  @override
  String get marketGpsApplied => 'Ubicación GPS aplicada.';

  @override
  String get marketGpsFailed => 'No se pudo obtener tu ubicación.';

  @override
  String get marketYourArea => 'Tu zona';

  @override
  String get marketCityOrArea => 'Ciudad o barrio';

  @override
  String get marketLocationCleared => 'Ubicación desactivada.';

  @override
  String get marketUseGps => 'Usar mi ubicación GPS';

  @override
  String get marketApply => 'Aplicar';

  @override
  String marketRemoveProduct(String name) {
    return '¿Retirar «$name»?';
  }

  @override
  String get marketProductUnavailable => 'Producto no disponible.';

  @override
  String get marketPaymentUnavailable => 'Pago con Mobile Money no disponible.';

  @override
  String get marketCheckoutUnreachable =>
      'Checkout de Mobile Money inaccesible.';

  @override
  String get marketBoostDone => 'Pago realizado: anuncio patrocinado.';

  @override
  String get marketBoostPending => 'Pago del impulso pendiente.';

  @override
  String get marketBoostFailed => 'No se puede impulsar ahora mismo.';

  @override
  String get marketTitle => 'Assimé';

  @override
  String get marketBecomeSeller => 'Hazte vendedor verificado';

  @override
  String get marketAddProduct => 'Añadir un producto';

  @override
  String get marketAroundYou => 'A tu alrededor';

  @override
  String get marketMyGps => 'Mi ubicación GPS';

  @override
  String get marketPickArea => 'Elegir una zona';

  @override
  String get marketNearYou => 'Productos cerca de ti';

  @override
  String get marketUnavailable => 'Marketplace no disponible.';

  @override
  String get marketNoProduct => 'Ningún producto publicado.';

  @override
  String get marketNoMatch => 'Ningún producto coincide con esta búsqueda.';

  @override
  String get marketAllShown => 'Se muestran todos los productos';

  @override
  String get marketMyCatalogue => 'Mi catálogo';

  @override
  String get marketSwipeCatalogue => 'Desliza para ver todos tus productos';

  @override
  String get marketCatalogueEmpty => 'Tu catálogo está vacío';

  @override
  String get marketCatalogueEmptyBody =>
      '¡Añade tu primer producto para empezar a vender!';

  @override
  String get marketBoosted => 'Patrocinado';

  @override
  String get vitrineSeeProduct => 'Ver artículo';

  @override
  String get vitrineHint => 'Toca el artículo para abrirlo';

  @override
  String get vitrineTitle => 'Escaparate del Mercado';

  @override
  String get versesMorning => '☀️ Versículo de la mañana';

  @override
  String get versesEvening => '🌙 Versículo de la tarde';

  @override
  String get versesChannel => 'Versículos del día';

  @override
  String get versesChannelDesc => 'Tus versículos de las 6 h y las 18 h';

  @override
  String get versesSchedule => 'Cada día a las 6 h y a las 18 h';

  @override
  String get versesThisMorning => 'Esta mañana';

  @override
  String get versesThisEvening => 'Esta tarde';

  @override
  String get versesBibleTitle => 'Versículos bíblicos';

  @override
  String get versesQuranTitle => 'Versículos coránicos';

  @override
  String get versesShare => 'Compartir';

  @override
  String get versesOfflineHint =>
      'Los versículos llegan incluso sin conexión: ya están en tu teléfono.';

  @override
  String get marketBoosted48h => 'Patrocinado';

  @override
  String get marketBoost => 'Destacar';

  @override
  String get marketRemove => 'Retirar';

  @override
  String get marketGpsSaved => 'Ubicación GPS guardada.';

  @override
  String get marketNameAndPrice => 'Se necesitan un nombre y un precio.';

  @override
  String get marketEditProduct => 'Editar producto';

  @override
  String get marketMainPhoto => 'Foto principal';

  @override
  String get marketOtherPhotos => 'Otras fotos';

  @override
  String get marketDescription => 'Descripción';

  @override
  String get marketCurrency => 'Moneda';

  @override
  String get marketCategory => 'Categoría';

  @override
  String get marketPickCategory => 'Elegir una categoría';

  @override
  String get marketSpecifyCategory => 'Especificar la categoría';

  @override
  String marketGpsCoords(String lat, String lon) {
    return 'Coordenadas GPS: $lat, $lon';
  }

  @override
  String get marketUploadingPhoto => 'Enviando la foto…';

  @override
  String get marketAddPhoto => 'Añadir una foto';

  @override
  String get groupEditName => 'Editar nombre';

  @override
  String get groupAddPhoto => 'Añadir una foto';

  @override
  String get groupChangePhoto => 'Cambiar la foto';

  @override
  String get groupRemovePhoto => 'Quitar la foto';

  @override
  String get groupNoLink => 'Ningún enlace activo';

  @override
  String get groupLinkActive => 'Hay un enlace activo';

  @override
  String get groupCreator => 'Creador';

  @override
  String get groupAdmin => 'Administrador';

  @override
  String get groupAddMembers => 'Añadir participantes';

  @override
  String get groupLeave => 'Salir del grupo';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get groupCopyLink => 'Copiar el enlace';

  @override
  String get groupRegenLink => 'Regenerar el enlace';

  @override
  String get groupDisableLink => 'Desactivar el enlace';

  @override
  String get groupLinkCopied => 'Enlace copiado.';

  @override
  String get groupLinkDisabled => 'Enlace desactivado.';

  @override
  String get groupAllContactsIn =>
      'Todos tus contactos de Pokou ya están en este grupo.';

  @override
  String get groupAddToGroup => 'Añadir al grupo';

  @override
  String groupMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participantes añadidos.',
      one: 'Participante añadido.',
    );
    return '$_temp0';
  }

  @override
  String get groupLeaveTitle => '¿Salir del grupo?';

  @override
  String groupLeaveBody(String name) {
    return 'Dejarás de recibir los mensajes de «$name».';
  }

  @override
  String get groupLeaveAction => 'Salir';

  @override
  String get groupNoMessage => 'Sin mensajes. Empieza la conversación.';

  @override
  String get groupNotEncryptedNotice =>
      '🔒 Cifrado de extremo a extremo: solo los miembros pueden leerlos.';

  @override
  String get botLabel => 'Bot';

  @override
  String get botConversationNotice =>
      'Estás escribiendo al bot de una empresa. Estos mensajes no están cifrados de extremo a extremo: la empresa lee lo que le envías.';

  @override
  String get groupAdminsOnly => 'Solo administradores';

  @override
  String get groupCallOngoing => 'Llamada en curso';

  @override
  String get communityEdit => 'Editar la comunidad';

  @override
  String get commonName => 'Nombre';

  @override
  String get communityEditFailed => 'No se pudo modificar.';

  @override
  String get communityAddGroup => 'Añadir un grupo';

  @override
  String get communityNewGroup => 'Crear un grupo nuevo';

  @override
  String get communityAttachGroup => 'Vincular un grupo existente';

  @override
  String communityDetachTitle(String name) {
    return '¿Desvincular «$name»?';
  }

  @override
  String get communityDetachBody =>
      'El grupo sale de la comunidad pero sigue existiendo: su chat y sus miembros no cambian.';

  @override
  String get communityDetach => 'Desvincular';

  @override
  String get communityDetachFailed => 'No se pudo desvincular este grupo.';

  @override
  String get communityLinkNote =>
      'Quien tenga este enlace entra en la comunidad y su grupo Anuncios, no en los demás, que se unen uno a uno.';

  @override
  String get communityActionFailed => 'No se pudo hacer.';

  @override
  String get communityLeaveTitle => '¿Salir de la comunidad?';

  @override
  String get communityLeaveBody =>
      'Dejarás de recibir sus anuncios. Los grupos a los que te uniste siguen siendo tuyos.';

  @override
  String get communityLeave => 'Salir de la comunidad';

  @override
  String get communityLeaveFailed => 'No se pudo salir de la comunidad.';

  @override
  String get communityOne => 'Comunidad';

  @override
  String get communityUnavailable =>
      'Comunidad no disponible: comprueba tu conexión.';

  @override
  String get communityGroups => 'GRUPOS';

  @override
  String get communityAnnouncements => 'Anuncios · solo administradores';

  @override
  String get communityOnlyAdminGroups =>
      'Solo los grupos que administras pueden unirse a una comunidad.';

  @override
  String get channelPostsUnavailable => 'Publicaciones no disponibles.';

  @override
  String get channelReactionFailed => 'Reacción no registrada.';

  @override
  String get channelPostFailed => 'No se pudo publicar.';

  @override
  String get channelEditPost => 'Editar la publicación';

  @override
  String get channelEditTooOld =>
      'No se puede editar: la publicación es demasiado antigua.';

  @override
  String get channelDeletePost => '¿Eliminar la publicación?';

  @override
  String get channelDeleteBody => 'Desaparecerá para todos los suscriptores.';

  @override
  String get channelDeleteFailed => 'No se pudo eliminar.';

  @override
  String get channelLinkCopied => 'Enlace del canal copiado.';

  @override
  String get channelLinkUnavailable => 'Enlace no disponible.';

  @override
  String get channelEdit => 'Editar el canal';

  @override
  String get channelPublish => 'Publicar';

  @override
  String channelFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suscriptores',
      one: '1 suscriptor',
    );
    return '$_temp0';
  }

  @override
  String get channelFollowing => 'Suscrito';

  @override
  String get channelEdited => '· editado';

  @override
  String get channelImageFailed => 'Imagen no enviada.';

  @override
  String get channelNewPost => 'Nueva publicación';

  @override
  String get channelPostHint => 'Tu anuncio…';

  @override
  String pollAnswerN(int index) {
    return 'Respuesta $index';
  }

  @override
  String get pollAddAnswer => 'Añadir una respuesta';

  @override
  String get pollMultiple => 'Se permiten varias respuestas';

  @override
  String get pollAddImage => 'Añadir una imagen';

  @override
  String get pollRemove => 'Quitar la encuesta';

  @override
  String get pollOne => 'Encuesta';

  @override
  String get pollQuestion => 'Tu pregunta';

  @override
  String get commonSending => 'Enviando…';

  @override
  String channelPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count publicaciones',
      one: '1 publicación',
    );
    return '$_temp0';
  }

  @override
  String get lockChooseCode => 'Elegir un código';

  @override
  String get lockCodeRule =>
      'De 4 a 8 dígitos. El código nunca sale de este dispositivo y no se puede recuperar; si lo olvidas, el bloqueo se levanta verificando tu número de teléfono.';

  @override
  String get lockCode => 'Código';

  @override
  String get lockConfirmCode => 'Confirmar el código';

  @override
  String get lockTooShort => 'El código debe tener al menos 4 dígitos.';

  @override
  String get lockMismatch => 'Los dos códigos no coinciden.';

  @override
  String get lockCurrentCode => 'Código actual';

  @override
  String get lockValidate => 'Validar';

  @override
  String get lockEnabledToast => 'Bloqueo activado.';

  @override
  String get lockSaveFailed => 'No se pudo guardar el código.';

  @override
  String get lockEnterCurrent => 'Introduce el código actual';

  @override
  String get lockWrongCode => 'Código incorrecto.';

  @override
  String get lockCodeChanged => 'Código modificado.';

  @override
  String get lockEnterToDisable => 'Introduce el código para desactivar';

  @override
  String get lockDisabledToast => 'Bloqueo desactivado.';

  @override
  String get lockTitle => 'Bloqueo de la aplicación';

  @override
  String get lockByCode => 'Bloquear con un código';

  @override
  String get lockOn => 'Activado';

  @override
  String get lockOff => 'Desactivado';

  @override
  String get lockChangeCode => 'Cambiar el código';

  @override
  String get lockFootnoteKeystore =>
      'Pokou pide el código cada vez que vuelve a primer plano. El código se guarda en el almacén seguro del sistema (Keystore), no se envía al servidor: protege la pantalla, no los datos del propio dispositivo.';

  @override
  String get lockFootnoteBiometrics =>
      'El desbloqueo por huella aún no está disponible: requiere un cambio de configuración de Android (FlutterFragmentActivity y el permiso USE_BIOMETRIC).';

  @override
  String get lockScreenTitle => 'Pokou está bloqueado';

  @override
  String get lockEnterToContinue => 'Introduce tu código para continuar.';

  @override
  String get lockUnlock => 'Desbloquear';

  @override
  String get lockForgotQuestion => '¿Olvidaste el código?';

  @override
  String get lockSendFailed => 'No se pudo enviar: comprueba tu conexión.';

  @override
  String get lockRemovedToast =>
      'Bloqueo eliminado. Puedes elegir un nuevo código en Perfil.';

  @override
  String get lockVerifyFailed => 'No se pudo verificar: comprueba tu conexión.';

  @override
  String get lockLogoutQuestion => '¿Cerrar sesión?';

  @override
  String get lockLogoutBody =>
      'Úsalo si ya no tienes acceso a este número. Tus conversaciones siguen en el servidor, pero necesitarás un número localizable para volver a entrar.';

  @override
  String get lockLogout => 'Cerrar sesión';

  @override
  String get lockForgotTitle => 'Código olvidado';

  @override
  String get lockNoPhoneOnDevice =>
      'No se pudo encontrar tu número en este dispositivo.';

  @override
  String lockEnterSentCode(String phone) {
    return 'Introduce el código enviado a $phone por SMS y WhatsApp.';
  }

  @override
  String lockForgotExplain(String phone) {
    return 'El código de bloqueo solo se guarda en este dispositivo y no se puede recuperar. Para quitar el bloqueo, verifica tu número $phone.';
  }

  @override
  String get lockLift => 'Quitar el bloqueo';

  @override
  String get lockSendCode => 'Enviar un código';

  @override
  String get lockResendCode => 'Reenviar el código';

  @override
  String get lockNoAccessToNumber => 'Ya no tengo acceso a este número';

  @override
  String get notifInApp => 'En la aplicación';

  @override
  String get notifMessages => 'Mensajes';

  @override
  String get notifMessagesSub => 'Conversaciones individuales';

  @override
  String get notifMessagesSemantic => 'Notificaciones de mensajes';

  @override
  String get notifGroups => 'Grupos';

  @override
  String get notifGroupsSub => 'Conversaciones de grupo';

  @override
  String get notifGroupsSemantic => 'Notificaciones de grupos';

  @override
  String get notifCallsSub => 'Llamadas de audio y vídeo entrantes';

  @override
  String get notifCallsSemantic => 'Notificaciones de llamadas';

  @override
  String get notifSound => 'Sonido y vibración';

  @override
  String get notifSoundSemantic => 'Sonido de las notificaciones';

  @override
  String get notifCallsFootnote =>
      'Desactivar las llamadas aquí solo quita el aviso que se muestra con Pokou abierto: una llamada entrante sigue sonando a pantalla completa, de lo contrario perderías llamadas sin saberlo.';

  @override
  String get notifSystem => 'Sistema';

  @override
  String get notifWebEnable => 'Activar notificaciones del navegador';

  @override
  String get notifWebEnableSub =>
      'Permite que este navegador reciba notificaciones de Pokou.';

  @override
  String get notifWebEnabled => 'Notificaciones del navegador activadas.';

  @override
  String get notifWebEnableFailed =>
      'No se pudieron activar. Revisa los ajustes del sitio en el navegador.';

  @override
  String get notifAndroidSettings => 'Ajustes de Android';

  @override
  String get notifAndroidSettingsSub => 'Permiso, canales, sonido por canal';

  @override
  String get notifSystemFootnote =>
      'Cuando Pokou está cerrado, es Android quien muestra las notificaciones recibidas, sin pasar por la aplicación: solo los ajustes del sistema de arriba pueden modificarlas.';

  @override
  String get devicesRemoveTitle => '¿Quitar este dispositivo?';

  @override
  String get devicesRemoveCurrentBody =>
      'Este dispositivo dejará de recibir notificaciones hasta que vuelvas a abrir Pokou.';

  @override
  String get devicesRemoveOtherBody =>
      'Este dispositivo dejará de recibir notificaciones. Sigue conectado hasta que cierre sesión.';

  @override
  String get devicesRemove => 'Quitar';

  @override
  String get devicesRemoveFailed => 'No se pudo quitar este dispositivo.';

  @override
  String get devicesTitle => 'Dispositivos conectados';

  @override
  String get devicesUnavailable =>
      'Lista no disponible: comprueba tu conexión y desliza para actualizar.';

  @override
  String get devicesEmpty =>
      'Ningún dispositivo registrado para las notificaciones. Se activan la primera vez que se abre Pokou en un dispositivo.';

  @override
  String get devicesThisDevice => ' · este dispositivo';

  @override
  String devicesLastSeen(String date, String hint) {
    return 'Activo el $date · …$hint';
  }

  @override
  String get devicesFootnote =>
      'Un dispositivo aparece aquí en cuanto se registra para las notificaciones push. Quitarlo corta sus notificaciones; no cierra su sesión, que caduca por sí sola.';

  @override
  String get devicesBrowser => 'Navegador';

  @override
  String devicesTodayAt(String time) {
    return 'hoy a las $time';
  }

  @override
  String get storageNoCachedMedia => 'No hay archivos en caché.';

  @override
  String storageFilesCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos eliminados de la caché.',
      one: '1 archivo eliminado de la caché.',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Almacenamiento y datos';

  @override
  String get storageCachedMedia => 'Archivos en caché';

  @override
  String get storageMediaLabel => 'Fotos, vídeos y notas de voz';

  @override
  String get storageComputing => 'Calculando…';

  @override
  String get storageNoFile => 'Ningún archivo';

  @override
  String storageFileCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
    );
    return '$_temp0 · $size';
  }

  @override
  String get storageClearCache => 'Vaciar la caché';

  @override
  String get storageClearFootnote =>
      'Los archivos borrados se vuelven a descargar cuando reabres la conversación: no se pierde nada, solo se libera espacio.';

  @override
  String get storageMobileData => 'Datos móviles';

  @override
  String get storageDataSaver => 'Ahorro de datos';

  @override
  String get storageDataSaverSub => 'No descargar los archivos automáticamente';

  @override
  String get storageDataSaverFootnote =>
      'Activado, las fotos y vídeos recibidos esperan a que los toques para descargarse, y las fotos que envías se comprimen más.';

  @override
  String get profileAvatarFailed => 'No se pudo actualizar la foto de perfil.';

  @override
  String get profileChooseMonitor => 'Elegir un monitor';

  @override
  String get profileBabaMessaging => 'Mensajería Baba';

  @override
  String profileMonitorAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alertas de $count monitores',
      one: 'Alertas de 1 monitor',
    );
    return '$_temp0';
  }

  @override
  String get profileBabaAssistant => 'Asistente Baba';

  @override
  String get profileShieldModeBody =>
      'Pone las llamadas en espera y silencia las conversaciones no prioritarias mientras estás concentrado. Tus contactos etiquetados como Business, Cliente, Proveedor o Jefe siempre pasan.';

  @override
  String get contactConnectFailed => 'No se pudo conectar.';

  @override
  String get contactCallFailed => 'No se puede llamar ahora mismo.';

  @override
  String contactBlockTitle(String name) {
    return '¿Bloquear a $name?';
  }

  @override
  String get contactBlockBody =>
      'Esta persona ya no podrá escribirte ni llamarte. No se le informará.';

  @override
  String get contactActionFailed => 'Acción no disponible ahora mismo.';

  @override
  String get contactSavedToast => 'Contacto guardado';

  @override
  String get contactCall => 'Llamada';

  @override
  String get contactSharedTitle => 'Elementos compartidos';

  @override
  String get contactSharedMedia => 'Archivos';

  @override
  String get contactSharedDocuments => 'Documentos';

  @override
  String get contactSharedLinks => 'Enlaces';

  @override
  String get contactNoMedia => 'No se han compartido fotos ni vídeos.';

  @override
  String get contactNoDocuments => 'No se han compartido documentos.';

  @override
  String get contactNoLinks => 'No se han compartido enlaces.';

  @override
  String contactCommonGroups(int count) {
    return 'Grupos en común ($count)';
  }

  @override
  String contactCatalog(int count) {
    return 'Catálogo ($count)';
  }

  @override
  String contactUnblockName(String name) {
    return 'Desbloquear a $name';
  }

  @override
  String contactBlockName(String name) {
    return 'Bloquear a $name';
  }

  @override
  String get contactUnblockHint =>
      'Esta persona puede volver a escribirte y llamarte.';

  @override
  String get contactBlockHint =>
      'Ya no podrá escribirte ni llamarte, y no se le informará.';

  @override
  String get adNeedTitleBody => 'Ponle un título y un mensaje a tu anuncio.';

  @override
  String get adSendFailed => 'No se pudo enviar la solicitud.';

  @override
  String get adCreateTitle => 'Crear un anuncio';

  @override
  String get adWhoSeesTitle => 'Quién lo verá';

  @override
  String get adWhoSeesBody =>
      'Todos los usuarios de Pokou Messenger en la pestaña Mercado, o entre dos estados: tú eliges.';

  @override
  String get adReviewTitle => 'Una revisión antes de publicarse';

  @override
  String get adReviewBody =>
      'Nuestro equipo lee cada campaña antes de publicarla. Cuenta con unas horas.';

  @override
  String get adCountdownTitle => 'La cuenta atrás empieza con la aprobación';

  @override
  String get adCountdownBody =>
      'Tus días de publicación empiezan cuando se acepta la campaña, no al pagar.';

  @override
  String get adRefundTitle => '¿Rechazada? Te devolvemos el dinero';

  @override
  String get adRefundBody =>
      'Si la campaña no puede publicarse, contáctanos: te devolvemos el importe.';

  @override
  String get adTitleHint => 'Ej.: Cemento CIMTOGO en promoción';

  @override
  String get adBodyHint => 'Lo que ofreces y cómo contactarte.';

  @override
  String get adMediaLabel => 'Foto o vídeo (opcional)';

  @override
  String get adMediaHint =>
      'Un vídeo de 30 segundos como máximo. Sin imagen, solo se publica el texto.';

  @override
  String get adVideo30s => 'Vídeo 30 s';

  @override
  String get adPlacement => 'Ubicación';

  @override
  String get adPlacementMarket => 'Pestaña Mercado';

  @override
  String get adPlacementStatus => 'Entre los estados';

  @override
  String get adDuration => 'Duración';

  @override
  String get adOneWeek => '1 semana';

  @override
  String get adTwoWeeks => '2 semanas';

  @override
  String get adOneMonth => '1 mes';

  @override
  String get adPayCaption => 'Pago con Mobile Money';

  @override
  String get adPayAction => 'Pagar y enviar';

  @override
  String productInterestedMessage(String name, String price, String currency) {
    return 'Hola, me interesa tu $name a $price $currency. ¿Está disponible?';
  }

  @override
  String get productWriteFailed =>
      'No se puede escribir al vendedor ahora mismo.';

  @override
  String get productCallFirstWrite => 'No se puede llamar: escríbele primero.';

  @override
  String get productRateSeller => 'Valorar a este vendedor';

  @override
  String get productEditReview => 'Editar mi valoración';

  @override
  String get productReviewScope =>
      'La valoración es sobre el VENDEDOR, no sobre un producto: lo que cuenta es la confianza en la persona, y permanece aunque el artículo salga del catálogo.';

  @override
  String get productReviewHint => 'Tu comentario (opcional)';

  @override
  String get productDeleteReview => 'Eliminar mi valoración';

  @override
  String get productReviewFailed => 'Valoración no guardada.';

  @override
  String get productTitle => 'Producto';

  @override
  String get productOpening => 'Abriendo…';

  @override
  String get productDiscuss => 'Chatear';

  @override
  String get productCallAction => 'Llamar';

  @override
  String get productReviews => 'Valoraciones';

  @override
  String get productNoReviewYet => 'Todavía sin valoraciones';

  @override
  String productRatingSummary(String rating, int reviews) {
    String _temp0 = intl.Intl.pluralLogic(
      reviews,
      locale: localeName,
      other: '$reviews valoraciones',
      one: '1 valoración',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String productCountSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count productos',
      one: '1 producto',
    );
    return ' · $_temp0';
  }

  @override
  String get productCertified => 'Cuenta verificada por el equipo de Pokou.';

  @override
  String get productReviewMine => 'Tú';

  @override
  String get verifNeedDocument =>
      'Añade una foto de tu documento de identidad.';

  @override
  String get verifTitle => 'Ser vendedor verificado';

  @override
  String get verifBadgeTitle => 'Una insignia azul en tus anuncios';

  @override
  String get verifBadgeBody =>
      'Los compradores ven que nuestro equipo ha verificado tu identidad.';

  @override
  String get verifWhyTitle => 'Por qué lo cambia todo';

  @override
  String get verifWhyBody =>
      'Un comprador envía dinero por Mobile Money con más facilidad a alguien con identidad confirmada que a un desconocido.';

  @override
  String get verifNeedTitle => 'Qué hay que aportar';

  @override
  String get verifNeedBody =>
      'Una foto nítida de tu DNI, pasaporte o permiso. El nombre debe leerse bien.';

  @override
  String get verifUseTitle => 'Qué hacemos con ello';

  @override
  String get verifUseBody =>
      'Solo la lee nuestro equipo para la verificación, nunca aparece en tu perfil y no se muestra a ningún comprador.';

  @override
  String get verifOneYearTitle => 'Válido un año';

  @override
  String get verifOneYearBody =>
      'La insignia dura doce meses. Cuenta con unos días para la revisión.';

  @override
  String get verifDocumentLabel => 'Tu documento de identidad';

  @override
  String get verifPayCaption => 'Pago con Mobile Money · 1 año';

  @override
  String get verifChoosePhoto => 'Elegir una foto';

  @override
  String get verifChange => 'Cambiar';

  @override
  String get marketRemoveBody =>
      'El anuncio desaparece del mercado. Tus conversaciones sobre él siguen siendo legibles, y los compradores que ya lo recibieron conservan su historial.';

  @override
  String get marketRemoveFailed => 'No se pudo retirar el anuncio.';

  @override
  String get marketImageFailed => 'Imagen no enviada: inténtalo de nuevo.';

  @override
  String get marketMainPhotoHint =>
      'Es la que ilustra el producto en la lista.';

  @override
  String get marketName => 'Nombre';

  @override
  String get marketPrice => 'Precio';

  @override
  String get marketNoReviewYet => 'todavía sin valoraciones';

  @override
  String get marketSearchHint => 'Buscar un producto…';

  @override
  String get callLogEmpty => 'Todavía no hay llamadas.';

  @override
  String get callLogUnknownUser => 'Usuario';

  @override
  String get callStatusMissed => 'Perdida';

  @override
  String get callStatusNoAnswer => 'Sin respuesta';

  @override
  String get callStatusDeclined => 'Rechazada';

  @override
  String get callStatusReceived => 'Recibida';

  @override
  String get callStatusEnded => 'Finalizada';

  @override
  String get callStatusOngoing => 'En curso';

  @override
  String get callStatusOutgoing => 'Llamada realizada';

  @override
  String get callVideoTitle => 'Videollamada';

  @override
  String get callAudioTitle => 'Llamada de audio';

  @override
  String callRedialQuestion(String name) {
    return '¿Volver a llamar a $name?';
  }

  @override
  String get callJoinFailed => 'No se pudo conectar a la llamada.';

  @override
  String get callNobodyToAdd => 'No hay nadie más para añadir.';

  @override
  String get callAddToCall => 'Añadir a la llamada';

  @override
  String get callAdd => 'Añadir';

  @override
  String get callAddFailed => 'No se pudo añadir a este participante.';

  @override
  String get callReactionFailed => 'No se pudo enviar esta reacción.';

  @override
  String get callLeaveConfirmTitle => '¿Salir de la llamada?';

  @override
  String get callLeaveConfirmBody =>
      'Los demás participantes pueden seguir hablando. Puedes cerrar esta pantalla sin colgar y volver desde el aviso de llamada.';

  @override
  String get callYou => 'Tú';

  @override
  String get callContact => 'Contacto';

  @override
  String get callConnecting => 'Conectando a la llamada…';

  @override
  String get callPreparing => 'La llamada se está preparando';

  @override
  String get callWaiting => 'Esperando…';

  @override
  String get callJoinImpossible => 'No se pudo unir a la llamada.';

  @override
  String get callEncryptedJoinFailed =>
      'Esta llamada cifrada no se pudo abrir en este teléfono. Se ha avisado a quien llama.';

  @override
  String get callIncoming => 'Llamada entrante';

  @override
  String callIncomingFrom(String name) {
    return '$name te está llamando';
  }

  @override
  String get callIncomingGroup => 'Llamada de grupo entrante';

  @override
  String get streakSubtitle => 'Un día perdido, unos minutos para recuperarlo';

  @override
  String get streakUnavailable => 'Rachas no disponibles';

  @override
  String get streakCheckConnection =>
      'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get streakEmptyTitle => 'Todavía ninguna racha';

  @override
  String get streakEmptyBody =>
      'Intercambia un mensaje cada día con la misma persona: la racha empieza en la primera ida y vuelta.';

  @override
  String get streakToRescue => 'Para salvar ahora';

  @override
  String get streakToRescueSub => 'Pasado el plazo, la racha vuelve a cero';

  @override
  String get streakMine => 'Mis rachas';

  @override
  String get streakRunning => 'En curso';

  @override
  String streakRecord(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return 'Récord: $_temp0';
  }

  @override
  String get streakLongest => 'Tu racha más larga';

  @override
  String get streakRestorePending =>
      'Tu racha se reanudará en cuanto se confirme el pago.';

  @override
  String get streakDeadlinePassed => 'Puede que el plazo haya vencido.';

  @override
  String streakBroken(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Racha de $days días rota',
      one: 'Racha de 1 día rota',
    );
    return '$_temp0';
  }

  @override
  String get streakExpired => 'El plazo ha vencido. La racha vuelve a cero.';

  @override
  String streakCountdown(String time) {
    return 'Quedan $time para salvarla';
  }

  @override
  String streakRescueAction(int amount) {
    return 'Salvar la racha — $amount FCFA';
  }

  @override
  String get leagueSubtitle => 'Tu liga sube con lo que recibes';

  @override
  String get leagueUnavailable => 'Clasificación no disponible';

  @override
  String get leagueRanking => 'Clasificación';

  @override
  String get leagueProtectPending =>
      'Tu protección se activará en cuanto se confirme el pago.';

  @override
  String get leaguePaymentFailed => 'No se pudo iniciar el pago.';

  @override
  String get leagueAtTop => 'Estás en lo más alto de la clasificación.';

  @override
  String leaguePointsNeeded(int points, String label) {
    return 'Faltan $points puntos para $label.';
  }

  @override
  String get leagueProtected =>
      'Tus puntos están protegidos. Nada baja esta semana.';

  @override
  String get leagueDecayNow => 'Tus puntos bajan en la próxima pasada.';

  @override
  String leagueDecayIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Tus puntos bajan en $days días sin actividad.',
      one: 'Tus puntos bajan en 1 día sin actividad.',
    );
    return '$_temp0';
  }

  @override
  String get leagueProtectAction => 'Proteger mis puntos — 500 FCFA';

  @override
  String get leagueNobodyRanked =>
      'Todavía no hay nadie clasificado. Sé el primero.';

  @override
  String leagueMyRank(int rank, int points) {
    return 'Estás en el puesto $rank con $points puntos.';
  }

  @override
  String get reactWith => 'Reaccionar con…';

  @override
  String get reactPickEmoji => 'Elige un emoji en el teclado';

  @override
  String get reactAction => 'Reaccionar';

  @override
  String get mediaPoll => 'Encuesta';

  @override
  String get mediaContact => 'Contacto';

  @override
  String get mediaSharedContact => 'Contacto compartido';

  @override
  String get convEdited => '· editado';

  @override
  String get convFallbackName => 'Conversación';

  @override
  String get convSomeone => 'Alguien';

  @override
  String get contactsTagFailed => 'No se pudo actualizar la etiqueta.';

  @override
  String get contactsTag => 'Etiquetar';

  @override
  String get contactsTitle => 'Contactos';

  @override
  String get contactsTyping => 'escribiendo…';

  @override
  String contactsTypingNamed(String name) {
    return '$name está escribiendo…';
  }

  @override
  String contactsPreviewMine(String preview) {
    return 'Tú: $preview';
  }

  @override
  String contactsPreviewSender(String name, String preview) {
    return '$name: $preview';
  }

  @override
  String contactsNotInContacts(String preview) {
    return '$preview · no está en tus contactos';
  }

  @override
  String get contactsAssistantSub => 'Tu asistente de IA';

  @override
  String get addContactTitle => 'Añadir un contacto';

  @override
  String get addContactName => 'Nombre';

  @override
  String get addContactAction => 'Añadir';

  @override
  String get joinLinkTitle => 'Unirse con un enlace';

  @override
  String get joinLinkBody =>
      'Pega el enlace que te han enviado. Grupo o comunidad, lo reconocemos.';

  @override
  String get joinLinkContinue => 'Continuar';

  @override
  String get joinLinkUnreadable => 'Enlace de invitación ilegible.';

  @override
  String joinAlreadyMember(String name) {
    return 'Ya estás en «$name».';
  }

  @override
  String joinGroupQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participantes',
      one: '1 participante',
    );
    return '$_temp0. ¿Unirse a este grupo?';
  }

  @override
  String get joinAction => 'Unirse';

  @override
  String get joinGroupFailed => 'No se pudo unir a este grupo.';

  @override
  String joinCommunityCounts(int members, int groups) {
    String _temp0 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members miembros',
      one: '1 miembro',
    );
    String _temp1 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups grupos',
      one: '1 grupo',
    );
    return '$_temp0 · $_temp1.';
  }

  @override
  String get joinCommunityBody =>
      'Recibirás sus anuncios. A los demás grupos hay que unirse uno por uno.';

  @override
  String get joinCommunityFailed => 'No se pudo unir a esta comunidad.';

  @override
  String get newChatOwnNumber => 'Es tu propio número.';

  @override
  String get phoneLookupFailed => 'Número no válido o no se pudo verificar.';

  @override
  String get phoneNotOnPokou => 'Este número todavía no usa Pokou.';

  @override
  String get phoneInviteWhatsApp => 'Invitar por WhatsApp';

  @override
  String get phoneInviteText =>
      '¡Hola! Te invito a probar Pokou, una mensajería privada: descarga la app y añádeme.';

  @override
  String get contactCardTitle => 'Tarjeta de contacto';

  @override
  String get viewOnceSeen => 'Vista';

  @override
  String get viewOnceTapToSee => 'Vista única: toca para ver';

  @override
  String get audioPlayFailed => 'No se puede reproducir';

  @override
  String mediaPhotoSize(Object size) {
    return 'Foto · $size';
  }

  @override
  String get mediaTapToDownload => 'Toca para descargar';

  @override
  String get mediaVideoUnavailable => 'Vídeo no disponible';

  @override
  String get mediaOpenDocFailed => 'No se pudo abrir este documento.';

  @override
  String get mediaOpenRetry => 'Fallo al abrir: toca para reintentar';

  @override
  String get dayToday => 'Hoy';

  @override
  String get dayYesterday => 'Ayer';

  @override
  String get weekdayMonday => 'lunes';

  @override
  String get weekdayTuesday => 'martes';

  @override
  String get weekdayWednesday => 'miércoles';

  @override
  String get weekdayThursday => 'jueves';

  @override
  String get weekdayFriday => 'viernes';

  @override
  String get weekdaySaturday => 'sábado';

  @override
  String get weekdaySunday => 'domingo';

  @override
  String liveHoursLeft(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'quedan $hours h',
      one: 'queda 1 h',
    );
    return '$_temp0';
  }

  @override
  String liveMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'quedan $minutes min',
      one: 'queda 1 min',
    );
    return '$_temp0';
  }

  @override
  String get liveAlmostOver => 'casi termina';

  @override
  String liveLocation(String remaining) {
    return 'En directo · $remaining';
  }

  @override
  String get openInMaps => 'Abrir en Maps';

  @override
  String get composerEditPhoto => 'Editar la foto';

  @override
  String get composerEditorFailed => 'No se pudo abrir el editor.';

  @override
  String get composerCropRotate => 'Recortar o girar';

  @override
  String get composerCaptionHint => 'Añadir un pie de foto…';

  @override
  String composerTo(String name) {
    return 'a $name';
  }

  @override
  String get composerSend => 'Enviar';

  @override
  String get convOfflineNotCached =>
      'Sin conexión: esta conversación todavía no está en memoria.';

  @override
  String get convLoadFailed => 'No se pudo cargar la conversación.';

  @override
  String get convEmptyEdit => 'Un mensaje vacío no puede sustituir a un texto.';

  @override
  String get convEditFailed => 'No se pudo editar: comprueba tu conexión.';

  @override
  String get convOrderUpdateFailed => 'No se pudo actualizar el pedido.';

  @override
  String get convDeleteFailed => 'No se pudo eliminar el mensaje.';

  @override
  String get convForwardFailedMsg => 'No se pudo reenviar el mensaje.';

  @override
  String get convOfflineAttachment =>
      'Sin conexión: los archivos adjuntos necesitan conexión.';

  @override
  String get convAttachmentFailed =>
      'Archivo adjunto no enviado: inténtalo de nuevo.';

  @override
  String get groupOfflineNotCached =>
      'Sin conexión: este grupo todavía no está en memoria.';

  @override
  String get groupLoadFailed => 'No se pudo cargar el grupo.';

  @override
  String get groupRenameFailed => 'No se pudo renombrar el grupo.';

  @override
  String get groupPhotoFailed => 'No se guardó la foto del grupo.';

  @override
  String get groupClearPhotoFailed => 'No se pudo quitar la foto.';

  @override
  String get groupRoleFailed => 'No se pudo cambiar este rol.';

  @override
  String get groupInviteCreateFailed =>
      'No se pudo crear el enlace de invitación.';

  @override
  String get groupInviteRevokeFailed => 'No se pudo desactivar el enlace.';

  @override
  String get groupLeaveFailed => 'No se pudo salir del grupo.';

  @override
  String get groupRemoveMemberFailed => 'No se pudo quitar a este miembro.';

  @override
  String get apiNetworkSilent => 'La red no responde';

  @override
  String apiError(int code) {
    return 'Error ($code)';
  }

  @override
  String get orderProductDiscussed => 'Artículo tratado';

  @override
  String get orderValidate => 'Validar el pedido';

  @override
  String get orderMarkShipped => 'Marcar como enviado';

  @override
  String get orderMarkDelivered => 'Marcar como entregado';

  @override
  String get orderBuyerWaiting => 'Este comprador espera tu respuesta.';

  @override
  String get orderNextStep => 'Siguiente paso del pedido.';

  @override
  String get msgNotSentRetry => 'No enviado: toca para reintentar';

  @override
  String get msgPendingSend => 'Pendiente de envío';

  @override
  String convSearchHint(String name) {
    return 'Buscar en $name…';
  }

  @override
  String get convSearchPrompt =>
      'Escribe una palabra para encontrar un mensaje de esta conversación.';

  @override
  String get convSearchEmpty => 'No se encontró ningún mensaje.';

  @override
  String get commonUnknownName => 'Desconocido';

  @override
  String get groupInviteLink => 'Enlace de invitación';

  @override
  String get groupDemoteAdmin => 'Quitar la administración';

  @override
  String get groupPromoteAdmin => 'Nombrar administrador';

  @override
  String get groupInviteLinkBody =>
      'Cualquiera que abra este enlace se une al grupo directamente, sin más pasos. Regenéralo para invalidar el que ya compartiste.';

  @override
  String get groupNewLinkCreated =>
      'Nuevo enlace creado: el anterior ya no funciona.';

  @override
  String get groupAddFailed => 'No se pudo añadir.';

  @override
  String get groupCreateFailed => 'No se pudo crear el grupo.';

  @override
  String get groupNewTitle => 'Nuevo grupo';

  @override
  String get groupCreateAction => 'Crear';

  @override
  String get groupNameHint => 'Nombre del grupo';

  @override
  String get groupPickParticipants => 'Elige los participantes';

  @override
  String groupSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participantes seleccionados',
      one: '1 participante seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get pushIncomingVideoCall => 'Videollamada entrante';

  @override
  String get pushIncomingAudioCall => 'Llamada de audio entrante';

  @override
  String get pushAnswer => 'Responder';

  @override
  String get pushDecline => 'Rechazar';

  @override
  String get pushMessagesChannel => 'Mensajes';

  @override
  String get pushMessagesChannelDesc =>
      'Notificaciones de nuevos mensajes de Pokou';

  @override
  String get pushCallsChannel => 'Llamadas';

  @override
  String get pushCallsChannelDesc =>
      'Notificaciones de llamadas entrantes de Pokou';

  @override
  String get pushGroupFallback => 'Grupo';

  @override
  String get notifNewMessage => 'Nuevo mensaje';

  @override
  String get notifPhoto => '📷 Foto';

  @override
  String get notifVideo => '🎥 Vídeo';

  @override
  String get notifVoice => '🎤 Mensaje de voz';

  @override
  String get notifDocument => '📄 Documento';

  @override
  String get notifSticker => 'Sticker';

  @override
  String get notifLocation => '📍 Ubicación';

  @override
  String get notifContact => '👤 Contacto';

  @override
  String get notifPoll => '📊 Encuesta';

  @override
  String get notifMe => 'Yo';

  @override
  String get notifReply => 'Responder';

  @override
  String get notifReplyHint => 'Tu mensaje';

  @override
  String get notifMarkRead => 'Marcar como leído';

  @override
  String get notifReplyQueued => 'se envía al abrir Pokou';

  @override
  String get notifReplyFailed =>
      'Respuesta no enviada: abre Pokou para reintentar';

  @override
  String notifSummary(int count, int conversations) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes',
      one: '1 mensaje',
    );
    String _temp1 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations conversaciones',
      one: '1 conversación',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get audienceContacts => 'Mis contactos';

  @override
  String get audienceNobody => 'Nadie';

  @override
  String get audienceExcept => 'Mis contactos excepto…';

  @override
  String get audienceOnly => 'Solo…';

  @override
  String get audienceContactsDesc => 'Todas las personas de tu agenda de Pokou';

  @override
  String get audienceNobodyDesc => 'Tus estados solo serán visibles para ti';

  @override
  String get audienceExceptDesc => 'Tus contactos, salvo los que elijas';

  @override
  String get audienceOnlyDesc => 'Solo las personas que elijas';

  @override
  String get statusViewerFallback => 'Usuario';

  @override
  String get statusPrivacySaved => 'Visibilidad guardada.';

  @override
  String get statusPrivacySaveFailed =>
      'No se pudo guardar: comprueba tu conexión.';

  @override
  String get statusPrivacyTitle => 'Visibilidad de los estados';

  @override
  String get statusExcludePeople => 'Personas a excluir';

  @override
  String get statusAllowedPeople => 'Personas autorizadas';

  @override
  String get statusNoContactToOffer =>
      'Ningún contacto de Pokou que proponer por ahora.';

  @override
  String get statusExceptFootnote =>
      'Estas personas no verán tus estados, aunque estén en tus contactos.';

  @override
  String get statusOnlyFootnote =>
      'Solo estas personas verán tus estados. No hace falta que te tengan como contacto.';

  @override
  String get status24hFootnote =>
      'Un estado desaparece de todos modos al cabo de 24 horas, para todos.';

  @override
  String get statusGallery => 'Galería';

  @override
  String get statusCamera => 'Cámara';

  @override
  String get statusNewTitle => 'Nuevo estado';

  @override
  String get statusText => 'Texto';

  @override
  String get statusTypeHint => 'Escribe tu estado…';

  @override
  String get statusPublish => 'Publicar';

  @override
  String get statusFeedTitle => 'Novedades';

  @override
  String get statusFeedUnavailable => 'Estados no disponibles: reintentar';

  @override
  String get statusSection => 'Estados';

  @override
  String get statusMine => 'Yo';

  @override
  String get channelsSection => 'Canales';

  @override
  String get bcastNeedName => 'Ponle un nombre a esta lista.';

  @override
  String get bcastNeedRecipient => 'Elige al menos un destinatario.';

  @override
  String get bcastSaveFailed => 'No se pudo guardar.';

  @override
  String get bcastNewTitle => 'Nueva difusión';

  @override
  String get bcastEditTitle => 'Editar la lista';

  @override
  String get bcastNameHint => 'Nombre de la lista (visible solo para ti)';

  @override
  String get bcastNoRecipient => 'Ningún destinatario';

  @override
  String bcastRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destinatarios',
      one: '1 destinatario',
    );
    return '$_temp0';
  }

  @override
  String get bcastContactsUnavailable => 'Contactos no disponibles.';

  @override
  String get bcastNobodyOnPokou =>
      'Ninguno de tus contactos está todavía en Pokou Messenger.';

  @override
  String get bcastNewList => 'Nueva lista';

  @override
  String get bcastListsTitle => 'Listas de difusión';

  @override
  String get bcastListsUnavailable => 'Listas no disponibles.';

  @override
  String bcastDeleteTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get bcastDeleteBody =>
      'Los mensajes ya enviados permanecen con sus destinatarios. Solo desaparece la lista.';

  @override
  String get bcastEmptyTitle => 'Anuncia una vez, a varios';

  @override
  String get bcastEmptyBody =>
      'Cada destinatario recibe el mensaje en su conversación privada. No ve a los demás y solo te responde a ti, a diferencia de un grupo, donde todos se ven.';

  @override
  String bcastSentTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviado a $count destinatarios.',
      one: 'Enviado a 1 destinatario.',
    );
    return '$_temp0';
  }

  @override
  String bcastSentPartly(int sent, int total, int skipped) {
    return 'Enviado a $sent de $total: $skipped ya no reciben tus mensajes.';
  }

  @override
  String get bcastSendFailed => 'El envío falló.';

  @override
  String get bcastEditRecipients => 'Editar los destinatarios';

  @override
  String get bcastHistoryUnavailable => 'Historial no disponible.';

  @override
  String get bcastNothingSent => 'Todavía no se ha difundido nada.';

  @override
  String get bcastMessageHint => 'Mensaje a difundir';

  @override
  String get bcastPrivacyNotice =>
      'Cada destinatario recibe este mensaje en privado. No ve a los demás, y su respuesta te llega en tu conversación con él.';

  @override
  String get channelNameRequired => 'El nombre del canal es obligatorio.';

  @override
  String get channelSaveFailed => 'No se pudo guardar el canal.';

  @override
  String get channelEditTitle => 'Editar el canal';

  @override
  String get channelNewTitle => 'Nuevo canal';

  @override
  String get channelAddImage => 'Añadir una imagen';

  @override
  String get channelChangeImage => 'Cambiar la imagen';

  @override
  String get channelRemoveImage => 'Quitar la imagen';

  @override
  String get channelNameLabel => 'Nombre del canal';

  @override
  String get channelNameHint => 'Ej.: Novedades de mi empresa';

  @override
  String get channelDescriptionLabel => 'Descripción';

  @override
  String get channelDescriptionHint => 'Presenta tu canal';

  @override
  String get channelSaveChanges => 'Guardar los cambios';

  @override
  String get channelCreateAction => 'Crear el canal';

  @override
  String get channelLinkCopiedClipboard => 'Enlace copiado al portapapeles.';

  @override
  String get channelLinkUnavailableShort => 'Enlace no disponible.';

  @override
  String get channelSearchTooltip => 'Buscar un canal';

  @override
  String get channelCreateTooltip => 'Crear un canal';

  @override
  String get channelEmptyHint => 'Crea un canal para compartir tus novedades.';

  @override
  String get channelGenerateLink => 'Generar un enlace';

  @override
  String get channelEditTooltip => 'Editar';

  @override
  String get channelSearchHint => 'Buscar un canal…';

  @override
  String get channelSearchPrompt =>
      'Busca por nombre o descripción. Los canales verificados aparecen primero.';

  @override
  String get channelSearchEmpty => 'No se encontró ningún canal.';

  @override
  String get channelNothingPublishedAdmin =>
      'Nada publicado todavía: toca + para tu primera publicación.';

  @override
  String get channelNothingPublished => 'Este canal aún no ha publicado nada.';

  @override
  String get channelFollow => 'Seguir';

  @override
  String get channelFallbackName => 'Canal';

  @override
  String get communityNewTitle => 'Nueva comunidad';

  @override
  String get communityNewBody =>
      'Una comunidad reúne varios grupos en torno a las mismas personas. Con ella se crea un grupo «Anuncios»: solo tú escribes allí, todos sus miembros leen.';

  @override
  String get communityNameHint => 'Nombre de la comunidad';

  @override
  String get communityDescriptionHint => 'Descripción (opcional)';

  @override
  String get communityCreateAction => 'Crear';

  @override
  String get communityCreateFailed => 'No se pudo crear.';

  @override
  String get communityNoGroupToAttach =>
      'No tienes ningún otro grupo que adjuntar. Solo los grupos que administras pueden unirse a una comunidad.';

  @override
  String get communityAddGroupFailed => 'No se pudo añadir este grupo.';

  @override
  String get communityLinkFailed => 'No se pudo crear el enlace.';

  @override
  String get communityCreateLink => 'Crear un enlace';

  @override
  String get sparkOpenRoomsSub => 'Se cierran solas';

  @override
  String get sparkMore => 'Más';

  @override
  String sparkRoomOpen(String time) {
    return 'Sala abierta — $time';
  }

  @override
  String get sparkBothYes => 'Los dos dijisteis que sí';

  @override
  String get sparkMatchSaved => 'Coincidencia salvada';

  @override
  String get sparkRoomClosed => 'Sala cerrada';

  @override
  String get sparkMatch => 'Coincidencia';

  @override
  String get sparkUnavailable => 'Spark no está disponible';

  @override
  String get sparkTodaysDate => 'La cita de hoy';

  @override
  String get sparkTabOutings => 'Salidas';

  @override
  String sparkPersonAge(String name, int age) {
    return '$name, $age';
  }

  @override
  String get aiSuggestSummary => 'Resumen';

  @override
  String get aiSuggestSummarySub => 'Una visión general rápida';

  @override
  String get aiSuggestSummaryPrompt =>
      'Hazme un resumen de la situación actual.';

  @override
  String get aiSuggestTrend => 'Tendencia';

  @override
  String get aiSuggestTrendSub => 'Analizar una evolución';

  @override
  String get aiSuggestTrendPrompt =>
      '¿Cuál es la tendencia de los últimos 7 días?';

  @override
  String get aiSuggestAlerts => 'Alertas';

  @override
  String get aiSuggestAlertsSub => 'Últimas señales';

  @override
  String get aiSuggestAlertsPrompt =>
      '¿Hay alertas recientes que deba conocer?';

  @override
  String get aiSuggestAdvice => 'Consejo';

  @override
  String get aiSuggestAdviceSub => 'Pedir una idea';

  @override
  String get aiSuggestAdvicePrompt => 'Dame un consejo para organizar mi día.';

  @override
  String get aiSuggestWrite => 'Redactar';

  @override
  String get aiSuggestWriteSub => 'Escribir un texto';

  @override
  String get aiSuggestWritePrompt => 'Ayúdame a redactar un mensaje.';

  @override
  String get aiSuggestQuestion => 'Pregunta';

  @override
  String get aiSuggestQuestionSub => 'Lo que sea';

  @override
  String get aiSuggestQuestionPrompt => 'Tengo una pregunta para ti.';

  @override
  String get aiMessageHint => 'Mensaje…';

  @override
  String get aiHowCanIHelp => '¿En qué puedo ayudarte?';

  @override
  String get aiAskAnything => 'Pregúntame lo que quieras.';

  @override
  String get aiAskAboutData => 'Haz una pregunta sobre tus datos conectados.';

  @override
  String get aiThinking => 'Baba está pensando';

  @override
  String aiHelloIm(String name) {
    return 'Hola, soy $name';
  }

  @override
  String get aiPartner => 'Tu socio digital';

  @override
  String get aiGreetMorning => 'Buenos días';

  @override
  String get aiGreetAfternoon => 'Buenas tardes';

  @override
  String get aiGreetEvening => 'Buenas noches';

  @override
  String get aiNewChat => 'Nueva conversación';

  @override
  String get aiCopy => 'Copiar';

  @override
  String get aiCopied => 'Copiado';

  @override
  String get aiGenerated => 'Generado por IA';

  @override
  String get aiVoiceListening => 'Te escucho…';

  @override
  String get aiVoiceTranscribing => 'Transcribiendo…';

  @override
  String get aiVoiceFailed => 'No pude oírte. Inténtalo de nuevo.';

  @override
  String get aiVoiceSpeak => 'Hablar con el asistente';

  @override
  String get aiVoiceRestart => 'Volver a empezar';

  @override
  String get aiVoiceSend => 'Enviar';

  @override
  String get aiVoiceStop => 'Terminar';

  @override
  String get aiSendFailed => 'Mensaje no enviado: inténtalo de nuevo.';

  @override
  String get digestTitle => 'Resumen del día';

  @override
  String get digestUnread => 'Mensajes sin leer:';

  @override
  String get digestMissedCalls => 'Llamadas perdidas:';

  @override
  String get digestVideoSuffix => ' (vídeo)';

  @override
  String digestShieldDeferred(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes retenidos por el Modo Escudo.',
      one: '1 mensaje retenido por el Modo Escudo.',
    );
    return '$_temp0';
  }

  @override
  String digestMonitorSignals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count señales de tus monitores por revisar.',
      one: '1 señal de tus monitores por revisar.',
    );
    return '$_temp0';
  }

  @override
  String get digestNothing => 'Nada que señalar hoy: ¡buenas noches!';

  @override
  String get shieldUnknownNumber => 'Número desconocido';

  @override
  String shieldFlushSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes retenidos durante tu reunión.',
      one: '1 mensaje retenido durante tu reunión.',
    );
    return '$_temp0';
  }

  @override
  String get shieldPendingMessages => 'Mensajes en espera';

  @override
  String shieldHandleSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count mensajes retenidos por el Modo Escudo: desliza hacia abajo para verlos',
      one:
          '1 mensaje retenido por el Modo Escudo: desliza hacia abajo para verlo',
    );
    return '$_temp0';
  }

  @override
  String shieldCallFrom(Object name) {
    return 'Llamada de $name';
  }

  @override
  String get shieldCallHeld => 'En espera: Modo Escudo';

  @override
  String get statusViewersUnavailable => 'Lista de vistas no disponible.';

  @override
  String statusSeenBy(int count) {
    return 'Visto por $count';
  }

  @override
  String get statusNobodySeen => 'Todavía no lo ha visto nadie.';

  @override
  String get statusBoostFailed => 'No se pudo impulsar el estado.';

  @override
  String get statusDeleteTitle => '¿Eliminar este estado?';

  @override
  String get statusDeleteBody =>
      'Desaparecerá para todos los que pueden verlo.';

  @override
  String get statusDeleteFailed => 'No se pudo eliminar: revisa tu conexión.';

  @override
  String get statusPublishFailed =>
      'No se pudo publicar: revisa tu conexión e inténtalo de nuevo.';

  @override
  String get statusBoostAction => 'Impulsar este estado · 1 000 FCFA';

  @override
  String get modulesSubtitle => 'Añade lo que te sirva, deja el resto';

  @override
  String get modulePaymentFailed => 'No se pudo iniciar el pago.';

  @override
  String deeplinkFollowedChannel(String name) {
    return 'Suscrito al canal «$name»';
  }

  @override
  String get deeplinkOpenFailed =>
      'Este enlace de invitación no se pudo abrir por ahora.';

  @override
  String get cropTitle => 'Recortar';

  @override
  String get cropHint => 'Pellizca para acercar, arrastra para encuadrar';

  @override
  String get cropConfirm => 'Validar';

  @override
  String get inviteJoinMe => 'Únete a mí en Pokou Messenger';

  @override
  String inviteJoinMeNamed(String name) {
    return '$name, únete a mí en Pokou Messenger';
  }

  @override
  String get otpNoCodeReceived => '¿No has recibido el código?';

  @override
  String get countryDialCode => 'Prefijo del país';

  @override
  String get countrySearchHint => 'País o prefijo (p. ej. Benín, 229)';

  @override
  String get countryNoneFound => 'No se encontró ningún país.';

  @override
  String get presenceSomeone => 'Alguien';

  @override
  String atTime(String time) {
    return 'a las $time';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date a las $time';
  }

  @override
  String truthAskedTo(String name) {
    return 'A $name';
  }

  @override
  String get devicesNoPushHere => 'Este dispositivo no recibe notificaciones.';

  @override
  String get devicesNoPushHereBody =>
      'No pudo registrarse en el servicio de notificaciones. Toca para reintentar.';

  @override
  String get devicesRetryDone => 'Este dispositivo ya recibe notificaciones.';

  @override
  String get devicesRetryFailed =>
      'Todavía no se pudo registrar: inténtalo más tarde.';

  @override
  String get chatsProfileMissing =>
      'Perfil no disponible: comprueba tu conexión y vuelve a intentarlo.';

  @override
  String get recSlideToCancel => 'Desliza para cancelar';

  @override
  String get recReleaseToCancel => 'Suelta para cancelar';

  @override
  String get recLocked => 'Bloqueado';

  @override
  String get recSlideUpToLock => 'Desliza hacia arriba para bloquear';

  @override
  String get recDelete => 'Eliminar la grabación';

  @override
  String get recHoldToRecord => 'Mantén pulsado para grabar';

  @override
  String get composerViewOnce => 'Vista única';

  @override
  String get composerViewOnceOn =>
      'Vista única activada: la foto desaparecerá tras abrirse.';

  @override
  String get composerViewOnceOff => 'Vista única desactivada.';

  @override
  String get channelSuggestedTitle => 'Canales para seguir';

  @override
  String get channelSuggestedBody =>
      'Todavía no sigues ninguno. Aquí tienes algunos.';

  @override
  String get channelSuggestedNone => 'Ningún canal que proponer por ahora.';

  @override
  String channelFollowed(String name) {
    return 'Ahora sigues «$name»';
  }

  @override
  String get channelFollowFailed => 'No se pudo seguir: comprueba tu conexión.';

  @override
  String get certifyTitle => 'Canal verificado';

  @override
  String get certifyWhyTitle =>
      'Una insignia, y el primer puesto en las sugerencias';

  @override
  String get certifyWhyBody =>
      'Los canales verificados aparecen primero ante quien busca qué seguir, y la insignia se ve en cada publicación.';

  @override
  String get certifyReviewTitle => 'Un examen, no una compra';

  @override
  String get certifyReviewBody =>
      'Nuestro equipo lee tu canal antes de conceder la insignia. Una insignia que se compra sin más no valdría nada: eso es lo que le da valor.';

  @override
  String get certifyRefundTitle => '¿Rechazada? Te devolvemos el dinero';

  @override
  String get certifyRefundBody =>
      'Si no se puede conceder la insignia, contáctanos: te devolvemos el importe.';

  @override
  String get certifyRenewTitle => 'Una suscripción, no algo definitivo';

  @override
  String get certifyRenewBody =>
      'La insignia dura lo que dure la fórmula elegida. Renovar antes del vencimiento la prolonga sin perder nada.';

  @override
  String get certifyPlanMonthly => 'Mensual — 3 000 FCFA';

  @override
  String get certifyPlanAnnual => 'Anual — 30 000 FCFA (dos meses gratis)';

  @override
  String get certifyAction => 'Pagar y enviar la solicitud';

  @override
  String get certifyPending =>
      'Tu solicitud llega al equipo en cuanto se confirme el pago.';

  @override
  String get certifyFailed => 'Solicitud imposible: inténtalo de nuevo.';

  @override
  String get certifyAlready => 'Este canal está verificado';

  @override
  String get certifyTooltip => 'Verificar este canal';

  @override
  String get chatsStartTitle => 'Empieza una conversación';

  @override
  String get chatsStartBody =>
      'Tus contactos ya están en Pokou. Toca un nombre para escribirle.';

  @override
  String get chatsSeeAllContacts => 'Ver todos mis contactos';

  @override
  String get chatsNoNetworkTitle => 'Tu red todavía no está en Pokou';

  @override
  String get chatsNoNetworkBody =>
      'Invita a alguien o sigue un canal mientras esperas respuesta.';

  @override
  String get chatsInviteContacts => 'Invitar contactos';

  @override
  String get chatsDiscoverChannels => 'Descubrir canales';

  @override
  String get e2eeEncrypted => 'Cifrado de extremo a extremo';

  @override
  String get e2eeNotEncrypted => 'Sin cifrar';

  @override
  String get e2eeNotEncryptedBody =>
      'Esta persona debe actualizar Pokou para el cifrado.';

  @override
  String get e2eeIdentityChangedTitle =>
      'La información de seguridad de este contacto ha cambiado';

  @override
  String e2eeIdentityChangedBody(String name) {
    return 'La clave de seguridad de $name cambió (teléfono nuevo o reinstalación). Si dudas, compruébalo con $name.';
  }

  @override
  String get e2eeIdentityAccept => 'Lo he verificado, continuar';

  @override
  String get e2eeBlockedTitle => 'Mensaje no enviado';

  @override
  String get e2eeBlockedLookup =>
      'No se pudo obtener la clave de cifrado. El mensaje no se envió: Pokou nunca lo enviará sin cifrar sin avisarte.';

  @override
  String get e2eeBlockedInvalid =>
      'La clave recibida no es utilizable. El mensaje no se envió, por precaución.';

  @override
  String get e2eeBlockedIdentity =>
      'La clave de este contacto ha cambiado. Verifica su identidad antes de enviar.';

  @override
  String get e2eeBlockedCrypto => 'El cifrado falló. El mensaje no se envió.';

  @override
  String get e2eeRetry => 'Reintentar';

  @override
  String get profileTheme => 'Apariencia';

  @override
  String get themeSystem => 'Como el teléfono';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeHint =>
      'El modo oscuro descansa la vista por la noche y ahorra batería en pantallas OLED.';

  @override
  String get a11yBack => 'Atrás';

  @override
  String get a11yRefresh => 'Actualizar';

  @override
  String get a11yMoreOptions => 'Más opciones';

  @override
  String get a11yVoiceCall => 'Llamada de voz';

  @override
  String get a11yVideoCall => 'Videollamada';

  @override
  String get a11yAttach => 'Adjuntar un archivo';

  @override
  String get a11yRate => 'Valorar';

  @override
  String get a11yAudioLevel => 'Nivel de audio';

  @override
  String get marketCreateAd => 'Crear un anuncio';

  @override
  String get adSponsored => 'Patrocinado';

  @override
  String get adYours => 'Tu anuncio';

  @override
  String get adContact => 'Contactar';

  @override
  String get adContactFailed => 'No se pudo contactar con el anunciante.';

  @override
  String get mediaSaveToPhone => 'Guardar en el teléfono';

  @override
  String get mediaUndecryptable => 'Archivo cifrado ilegible en este teléfono.';

  @override
  String get mediaSaved => 'Guardado en tu galería';

  @override
  String get mediaExported => 'Elige dónde guardarlo';

  @override
  String get mediaSavePermission =>
      'Pokou necesita acceso a tus fotos para guardar este archivo.';

  @override
  String get mediaSaveNoSpace => 'No hay espacio suficiente en el teléfono.';

  @override
  String get mediaSaveFailed => 'No se pudo guardar.';

  @override
  String get composerEmoji => 'Emojis';

  @override
  String get convAttachGif => 'GIF';

  @override
  String get stickerTabEmoji => 'Emoji';

  @override
  String get stickerTabStickers => 'Stickers';

  @override
  String get stickerSearchHint => 'Buscar un sticker';

  @override
  String get stickerRecents => 'Recientes';

  @override
  String get stickerFavorites => 'Favoritos';

  @override
  String get stickerNoResult => 'No se encontró ningún sticker';

  @override
  String get stickerEmptyPanel => 'Aún no hay stickers';

  @override
  String get stickerBrowsePacks => 'Explorar paquetes';

  @override
  String get stickerManagePacks => 'Gestionar paquetes';

  @override
  String get stickerPacksTitle => 'Paquetes de stickers';

  @override
  String get stickerPackAdd => 'Añadir';

  @override
  String get stickerPackAdded => 'Añadido';

  @override
  String get stickerPackRemove => 'Quitar';

  @override
  String get stickerPackDelete => 'Eliminar el paquete';

  @override
  String get stickerPackDeleteConfirm =>
      '¿Eliminar este paquete y todos sus stickers?';

  @override
  String get stickerMyPackName => 'Mis stickers';

  @override
  String get stickerCreateFromPhoto => 'Crear desde una foto';

  @override
  String get stickerCreated => 'Sticker añadido a tus stickers';

  @override
  String get stickerLimitReached => 'Tu paquete personal está lleno';

  @override
  String get stickerSendFailed => 'Sticker no enviado — inténtalo de nuevo';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get stickerFavoriteAdded => 'Añadido a favoritos';

  @override
  String get stickerFavoriteRemoved => 'Quitado de favoritos';

  @override
  String get stickerStoreEmpty => 'Todavía no hay paquetes disponibles';

  @override
  String get stickerSaveToMine => 'Añadir a mis stickers';

  @override
  String get stickerSaved => 'Sticker añadido a tus stickers';

  @override
  String get navBaba => 'Baba';

  @override
  String get appBarOnline => 'En línea';

  @override
  String get appBarOffline => 'Sin conexión';

  @override
  String get marketNegotiate => 'Negociar';

  @override
  String get callsCallBack => 'Devolver la llamada';

  @override
  String get callsFilterMissed => 'Perdidas';

  @override
  String get callsFilterAll => 'Todas';

  @override
  String get chatsFilterAll => 'Todas';

  @override
  String get chatsFilterUnread => 'No leídas';

  @override
  String get chatsFilterGroups => 'Grupos';

  @override
  String get chatsSearchOrAsk => 'Buscar o preguntar a Baba…';

  @override
  String get convEncryptedHint => 'Mensaje cifrado…';

  @override
  String get chatsArchivedSection => 'Chats archivados';

  @override
  String get statusMineTitle => 'Mi novedad';

  @override
  String get statusMineBody => 'Toca para publicar una novedad (24 h)';

  @override
  String get statusMineVisibility => 'Visible para mis contactos';

  @override
  String get callLeaveConference => 'Salir de la conferencia';

  @override
  String get callQualityExcellent => 'Excelente';

  @override
  String get callQualityGood => 'Correcta';

  @override
  String get callQualityPoor => 'Débil';

  @override
  String get callYouShort => 'Tú';

  @override
  String get callMutedShort => 'Silenciado';

  @override
  String get callMuteLabel => 'Micro';

  @override
  String get callCameraLabel => 'Cámara';

  @override
  String get callSpeakerLabel => 'Altavoz';

  @override
  String get callFlipCamera => 'Girar la cámara';

  @override
  String get callFlipCameraFailed => 'No se pudo cambiar de cámara.';

  @override
  String get callNoAnswer => 'Sin respuesta.';

  @override
  String callOngoingBanner(String duration) {
    return 'Llamada en curso · $duration — toca para volver';
  }

  @override
  String get callOngoingBannerRinging => 'Llamada en curso — toca para volver';

  @override
  String get callHangUp => 'Colgar';

  @override
  String get callInviteLabel => 'Invitar';

  @override
  String get e2eeReassurance =>
      '🔒 Cifrado de extremo a extremo: nadie más, ni siquiera Pokou, puede leer estos mensajes.';

  @override
  String get chatsEncryptionFooter =>
      '🔒 Tus chats están cifrados de extremo a extremo.';

  @override
  String get callsRecentSection => 'RECIENTES';

  @override
  String get callsGroupChip => 'Grupo';

  @override
  String get callGroupNotEncrypted =>
      'Llamada de grupo estándar — sin cifrado de extremo a extremo';

  @override
  String get marketCatalogueSeeAll => 'Ver todo';

  @override
  String get marketCatalogueOpen => 'Abrir mi catálogo';

  @override
  String get marketCatalogueTotal => 'Anuncios';

  @override
  String get marketCatalogueOnline => 'En línea';

  @override
  String get marketCatalogueBoostedLabel => 'Impulsados';

  @override
  String get marketCatalogueWithdrawn => 'Retirados';

  @override
  String get marketFilterAll => 'Todos';

  @override
  String get marketCertifiedSellers => 'Vendedores certificados';

  @override
  String get marketCatalogueNoneInFilter =>
      'Ningún anuncio coincide con este filtro.';

  @override
  String get marketStatusModerated => 'Retirado del mercado';

  @override
  String get marketStatusModeratedBody =>
      'Los compradores ya no pueden verlo. Escribe al soporte si crees que es un error.';

  @override
  String get callsFilterDirect => 'Cara a cara';

  @override
  String get profileMyAccount => 'Mi cuenta';

  @override
  String get profileVerifyAccount => 'Verificar mi cuenta';

  @override
  String get profileVerifyAccountBody =>
      'Consigue la insignia de vendedor verificado del Mercado';

  @override
  String get profileCertificationPending => 'Certificación pendiente';

  @override
  String get profileCertificationPendingBody =>
      'Tu solicitud está siendo revisada.';

  @override
  String get profileCertificationActive => 'Cuenta certificada';

  @override
  String get profileCertificationActiveBody =>
      'La insignia de certificación aparece junto a tu nombre.';

  @override
  String get profileSellerCertified => 'Vendedor verificado';

  @override
  String profileSellerCertifiedUntil(String date) {
    return 'Insignia de vendedor activa hasta el $date.';
  }

  @override
  String get verifPlanLabel => 'Elige tu plan';

  @override
  String get callEventAudio => 'Llamada de voz';

  @override
  String get callEventVideo => 'Videollamada';

  @override
  String get callEventGroup => 'Llamada de grupo';

  @override
  String get callEventMissed => 'Llamada perdida';

  @override
  String get callEventNoAnswer => 'Sin respuesta';

  @override
  String get callEventDeclined => 'Rechazada';

  @override
  String get callEventYouDeclined => 'La rechazaste';

  @override
  String get callEventEnded => 'Finalizada';

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
      other: '$count participantes',
      one: '1 participante',
    );
    return '$_temp0';
  }

  @override
  String get mediaCall => '📞 Llamada';

  @override
  String get mediaSticker => 'Sticker';

  @override
  String get identityVerifiedAccount => 'Cuenta verificada';

  @override
  String get privacyTitle => 'Privacidad';

  @override
  String get privacyIntro =>
      'Estos ajustes los aplica el servidor: lo que ocultas no se envía a los demás, no solo se oculta en la aplicación.';

  @override
  String get privacySectionWhoSees => 'Quién puede ver mi información';

  @override
  String get privacySectionMessages => 'Mensajes';

  @override
  String get privacySectionGroups => 'Grupos';

  @override
  String get privacyLastSeen => 'Última actividad';

  @override
  String get privacyLastSeenBody => 'Cuándo te conectaste por última vez.';

  @override
  String get privacyOnline => 'Presencia en línea';

  @override
  String get privacyOnlineBody =>
      'El punto verde que indica que estás disponible ahora. Independiente de la última actividad.';

  @override
  String get privacyProfilePhoto => 'Foto de perfil';

  @override
  String get privacyProfilePhotoBody =>
      'Tu foto, en todos los lugares donde aparece.';

  @override
  String get privacyProfileInfo => 'Información del perfil';

  @override
  String get privacyProfileInfoBody =>
      'Tu descripción y lo que has indicado sobre ti.';

  @override
  String get privacyReadReceipts => 'Confirmaciones de lectura';

  @override
  String get privacyReadReceiptsBody =>
      'Desactivarlas también te priva de las de los demás. Las marcas de entrega siguen visibles.';

  @override
  String get privacyGroupInvites => 'Quién puede invitarme a un grupo';

  @override
  String get privacyGroupInvitesBody =>
      'Permitir no es aceptar: conservas la última palabra sobre cada invitación.';

  @override
  String get privacyGroupMembership => 'Visibilidad de mis grupos';

  @override
  String get privacyGroupMembershipBody =>
      'Quién puede ver en qué grupos estás. Los miembros de un grupo siguen conociéndose entre sí.';

  @override
  String get privacyEveryone => 'Todos';

  @override
  String get privacyMyContacts => 'Mis contactos';

  @override
  String get privacyNobody => 'Nadie';

  @override
  String get privacySaveFailed => 'Ajuste no guardado — inténtalo de nuevo.';

  @override
  String get privacyUnavailable => 'Ajustes de privacidad no disponibles.';

  @override
  String get privacyStatusesNote =>
      'La privacidad de los estados se ajusta desde la pestaña Novedades, donde también puedes excluir a personas concretas.';

  @override
  String groupInvitesSent(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitaciones enviadas',
      one: 'Invitación enviada',
      zero: 'Ninguna invitación enviada',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationTitle => 'Invitación a un grupo';

  @override
  String groupInvitationFrom(Object name) {
    return '$name te invita';
  }

  @override
  String groupInvitationMembers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationAccept => 'Unirse';

  @override
  String get groupInvitationReject => 'Rechazar';

  @override
  String groupInvitationExpires(Object hours) {
    return 'Caduca en $hours h';
  }

  @override
  String get groupInvitationExpiresSoon => 'Caduca pronto';

  @override
  String groupInvitationsHeader(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitaciones',
      one: '1 invitación',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationFailed =>
      'Acción imposible — puede que la invitación ya no sea válida.';

  @override
  String get mediaStatePreparing => 'Preparando…';

  @override
  String get mediaStateSending => 'Enviando…';

  @override
  String mediaStateSendingPercent(Object percent) {
    return 'Enviando · $percent %';
  }

  @override
  String get mediaStateWaitingNetwork => 'Esperando conexión';

  @override
  String get mediaStateFailed => 'No se pudo enviar';

  @override
  String get mediaStateFileGone => 'El archivo ya no está en este dispositivo';

  @override
  String get channelPrivateLabel => 'Canal privado';

  @override
  String get channelPrivateBody =>
      'No aparece en la búsqueda. Solo quienes reciban el enlace pueden unirse y leer sus publicaciones. Esto no se podrá cambiar después.';

  @override
  String get channelPrivateBadge => 'Privado';

  @override
  String get mahizuConnectTitle => 'Conecta tu cuenta Mahizu';

  @override
  String mahizuConnectBody(String phone) {
    return 'El asistente es un servicio de Mahizu, independiente de Pokou. Para usarlo, vincula tu cuenta Mahizu: se enviará un código al $phone.';
  }

  @override
  String get mahizuSendCode => 'Recibir el código';

  @override
  String get mahizuCodeLabel => 'Código recibido';

  @override
  String get mahizuPinLabel => 'PIN de tu cuenta Mahizu';

  @override
  String get mahizuConfirm => 'Conectar';

  @override
  String get mahizuRestart => 'Empezar de nuevo';

  @override
  String get navHome => 'Inicio';

  @override
  String get navKory => 'Kory';

  @override
  String get navMore => 'Más';

  @override
  String homeGreeting(String name) {
    return 'Hola $name';
  }

  @override
  String get homeSeeAll => 'Ver todo';

  @override
  String get homeNoChats => 'Aún no hay chats';

  @override
  String get homeKoryEmpty => 'Ninguna colecta en curso';

  @override
  String get homeSearchHint => 'Buscar un chat';

  @override
  String get moreCertifiedTitle => 'Pokou certificado';

  @override
  String get moreCertifiedBody =>
      'Identidad verificada y modo prueba: próximamente.';

  @override
  String get moreSectionServices => 'Servicios';

  @override
  String get moreSectionSettings => 'Ajustes';

  @override
  String get moreAccount => 'Cuenta y seguridad';

  @override
  String get moreEdit => 'Editar';

  @override
  String get koryTitle => 'Kory';

  @override
  String get korySubtitle => 'Colectas y tontinas';

  @override
  String get koryMyPots => 'Mis colectas';

  @override
  String get koryMonthTotal => 'Mis contribuciones confirmadas este mes';

  @override
  String get koryNoMoney =>
      'Pokou no toca el dinero: va directamente de tu monedero al del recaudador.';

  @override
  String get koryCreate => 'Crear una colecta';

  @override
  String get koryJoin => 'Unirse';

  @override
  String get koryJournalTab => 'Registro';

  @override
  String get koryJoinTitle => 'Unirse con un código';

  @override
  String get koryJoinHint => 'Código de la colecta';

  @override
  String get koryJoinUnknown => 'Código desconocido o colecta cerrada.';

  @override
  String get koryNone => 'Ninguna colecta en curso';

  @override
  String get koryNoneBody =>
      'Crea una colecta para una boda, un bautizo o una cotización, o únete a una con su código.';

  @override
  String get koryUnavailable => 'Kory no está disponible';

  @override
  String get koryKindCagnotte => 'Colecta';

  @override
  String get koryKindCotisation => 'Cotización';

  @override
  String get koryTotalConfirmed => 'Total confirmado';

  @override
  String koryGoal(String amount) {
    return 'Objetivo: $amount';
  }

  @override
  String koryDue(String date) {
    return 'Vencimiento: $date';
  }

  @override
  String koryMyShare(String amount) {
    return 'Mi parte confirmada: $amount';
  }

  @override
  String koryToReview(String count) {
    return 'Por confirmar: $count';
  }

  @override
  String get koryClosed => 'Cerrada';

  @override
  String get koryOpen => 'Abierta';

  @override
  String koryCollector(String name) {
    return 'Recaudador: $name';
  }

  @override
  String koryPayTo(String phone) {
    return 'Envía tu contribución desde tu monedero al $phone y luego declárala aquí.';
  }

  @override
  String koryPerMember(String amount, String period) {
    return '$amount por miembro, $period';
  }

  @override
  String get koryDeclare => 'He contribuido';

  @override
  String get koryDeclareTitle => 'Declarar una contribución';

  @override
  String get koryAmount => 'Importe (FCFA)';

  @override
  String get koryWalletRef => 'Referencia de la transacción (opcional)';

  @override
  String get koryWalletRefHelp =>
      'Aparece en el SMS de tu operador. Solo tú y el recaudador la veis.';

  @override
  String get koryNote => 'Mensaje (opcional)';

  @override
  String get koryPeriodLabel => 'Periodo cubierto (p. ej. 2026-11)';

  @override
  String get koryJournal => 'Registro de contribuciones';

  @override
  String get koryJournalEmpty => 'Aún no se ha declarado ninguna contribución.';

  @override
  String get koryStatusDeclared => 'Esperando al recaudador';

  @override
  String get koryStatusConfirmed => 'Confirmada';

  @override
  String get koryStatusRejected => 'Impugnada';

  @override
  String get koryConfirm => 'Recibido';

  @override
  String get koryReject => 'No recibido';

  @override
  String get koryCloseAction => 'Cerrar';

  @override
  String get koryCloseConfirm =>
      '¿Cerrar la colecta? Nadie podrá declarar más contribuciones.';

  @override
  String koryShareCode(String code) {
    return 'Código: $code';
  }

  @override
  String koryShareText(String title, String code) {
    return 'Únete a la colecta «$title» en Pokou con el código $code.';
  }

  @override
  String get koryCreateTitle => 'Nueva colecta';

  @override
  String get koryFieldTitle => 'Título';

  @override
  String get koryFieldDescription => 'Descripción (opcional)';

  @override
  String get koryFieldGoal => 'Objetivo en FCFA (opcional)';

  @override
  String get koryFieldPerMember => 'Importe por miembro (FCFA)';

  @override
  String get koryPeriodMonthly => 'cada mes';

  @override
  String get koryPeriodWeekly => 'cada semana';

  @override
  String get koryFieldDue => 'Vencimiento (opcional)';

  @override
  String get koryNeedTitle => 'Pon un título (al menos 3 caracteres).';

  @override
  String get koryNeedAmount => 'Indica un importe de al menos 100 FCFA.';

  @override
  String get koryCollectorIsYou =>
      'Eres el recaudador: las contribuciones llegan a tu monedero y tú las confirmas.';

  @override
  String get koryYou => 'Tú';

  @override
  String get koryTontinePlus => 'Tontina rotativa: pronto con Kory Plus';

  @override
  String get koryDeclared =>
      'Contribución declarada. El recaudador la confirmará.';

  @override
  String get koryCopyPhone => 'Copiar el número';

  @override
  String get koryCopied => 'Copiado';

  @override
  String get koryActionFailed =>
      'La operación no se completó. Inténtalo de nuevo.';

  @override
  String get welcomePromise => 'Más que una mensajería, una comunidad.';

  @override
  String get welcomeSignature => 'Juntos, más fuertes.';

  @override
  String get welcomeServiceChats => 'Chats, grupos y llamadas';

  @override
  String get welcomeServiceKory => 'Colectas y tontinas';

  @override
  String get legalPrivacy => 'Privacidad';

  @override
  String get legalTerms => 'Condiciones de uso';

  @override
  String get legalUnavailable => 'Documento no disponible por ahora.';

  @override
  String onbStep(String step) {
    return 'Paso $step de 3';
  }

  @override
  String get onbProfileTitle => 'Tu perfil';

  @override
  String get onbProfileBody => 'Es el nombre que verán tus contactos.';

  @override
  String get onbDisplayName => 'Nombre visible';

  @override
  String get onbNameRequired => 'Indica un nombre (al menos 2 caracteres).';

  @override
  String get onbPhotoLater =>
      'Podrás añadir una foto más tarde desde tu perfil.';

  @override
  String get onbContinue => 'Continuar';

  @override
  String get onbTermsTitle => 'Antes de empezar';

  @override
  String get onbAcceptTerms =>
      'He leído y acepto las condiciones de uso y la política de privacidad.';

  @override
  String get onbAge => 'Tengo la edad requerida para usar Pokou.';

  @override
  String get onbOptional =>
      'Opcional, modificable en cualquier momento en los ajustes';

  @override
  String get onbAnalytics => 'Compartir estadísticas de uso para mejorar Pokou';

  @override
  String get onbMarketing => 'Recibir novedades y ofertas de Pokou';

  @override
  String get onbFinish => 'Terminar';

  @override
  String get onbFailed => 'No se pudo guardar. Inténtalo de nuevo.';

  @override
  String get moreConsents => 'Estadísticas y comunicaciones';

  @override
  String get navHonam => 'Honam';

  @override
  String get honamSubtitle => 'Farmacias y entrega';

  @override
  String get honamIntro =>
      'Una farmacia cercana te envía un presupuesto. Págalo desde tu billetera y un mensajero te lo entrega.';

  @override
  String get honamSend => 'Enviar una receta';

  @override
  String get honamPhotograph => 'Fotografiar la receta';

  @override
  String get honamFromGallery => 'Elegir una foto';

  @override
  String get honamUrgent => 'Urgencia';

  @override
  String get honamNotEmergency => 'Pokou no es un servicio de urgencias.';

  @override
  String get honamNearby => 'Farmacias cercanas';

  @override
  String get honamOnDuty => 'De guardia';

  @override
  String get honamNoPharmacy => 'Aún no hay farmacias asociadas.';

  @override
  String get honamCurrentOrder => 'Pedido en curso';

  @override
  String get honamMyOrders => 'Mis pedidos';

  @override
  String get honamChoosePharmacy => 'Elegir la farmacia';

  @override
  String get honamAddress => 'Dirección de entrega';

  @override
  String get honamNote => 'Nota para el farmacéutico (opcional)';

  @override
  String get honamSubmit => 'Enviar a la farmacia';

  @override
  String get honamNeedPhoto => 'Añade la foto de la receta.';

  @override
  String get honamNeedAddress => 'Indica la dirección de entrega.';

  @override
  String get honamFailed => 'No se pudo completar. Inténtalo de nuevo.';

  @override
  String honamOrderTitle(String id) {
    return 'Pedido n.º $id';
  }

  @override
  String get honamStSubmitted => 'Enviada, esperando al farmacéutico';

  @override
  String get honamStQuoted => 'Presupuesto recibido';

  @override
  String get honamStAccepted => 'Presupuesto aceptado, por pagar';

  @override
  String get honamStPaid => 'Pagado, en preparación';

  @override
  String get honamStReady => 'Listo, esperando al repartidor';

  @override
  String get honamStInDelivery => 'En camino';

  @override
  String get honamStDelivered => 'Entregado';

  @override
  String get honamStRejected => 'Receta rechazada';

  @override
  String get honamStExpired => 'Presupuesto caducado';

  @override
  String get honamStCancelled => 'Cancelado';

  @override
  String get honamQuote => 'Presupuesto';

  @override
  String get honamUnavailableItem => 'No disponible';

  @override
  String get honamMedicines => 'Medicamentos';

  @override
  String get honamDelivery => 'Entrega';

  @override
  String get honamTotal => 'Total a pagar';

  @override
  String get honamAcceptQuote => 'Aceptar el presupuesto';

  @override
  String honamPayTo(String amount, String phone) {
    return 'Envía $amount desde tu monedero al $phone (la farmacia) y luego confirma.';
  }

  @override
  String get honamDeclarePaid => 'He pagado a la farmacia';

  @override
  String get honamPaidDeclared => 'Pago indicado: la farmacia lo confirmará.';

  @override
  String get honamPaymentNotReceived =>
      'La farmacia no ha recibido tu pago. Verifica el número y el importe.';

  @override
  String get honamCode => 'Código de entrega';

  @override
  String get honamCodeHelp =>
      'Da este código al repartidor solo cuando tengas el paquete en la mano.';

  @override
  String get honamOriginal => 'El repartidor recogerá la receta original.';

  @override
  String honamRefundDue(String amount, String reason) {
    return 'La farmacia te debe $amount: $reason';
  }

  @override
  String get honamRefundReceived => 'He recibido el reembolso';

  @override
  String get honamCancel => 'Cancelar el pedido';

  @override
  String get honamResend => 'Enviar a otra farmacia';

  @override
  String honamReason(String reason) {
    return 'Motivo: $reason';
  }

  @override
  String get honamTimeline => 'Seguimiento';

  @override
  String get honamOrderMessages => 'Mensajes del pedido';

  @override
  String get honamWriteMessage => 'Escribe un mensaje';

  @override
  String get honamCourierMode => 'Modo repartidor';

  @override
  String get honamCourierJoin => 'Ser repartidor Win Pokou';

  @override
  String get honamCourierJoinBody =>
      '5 entregas de prueba sin comisión durante un mes. Después: membresía Win Pokou y un paquete prepagado.';

  @override
  String honamRidesLeft(String count) {
    return 'Entregas restantes: $count';
  }

  @override
  String get honamUnlimited => 'Entregas ilimitadas';

  @override
  String honamMembership(String amount) {
    return 'Membresía Win Pokou: $amount sin IVA / mes';
  }

  @override
  String get honamPayMembership => 'Pagar la membresía';

  @override
  String get honamPacks => 'Paquetes de entregas';

  @override
  String honamPackPrice(String amount) {
    return '$amount sin IVA';
  }

  @override
  String get honamAvailableRides => 'Entregas disponibles';

  @override
  String get honamMyRides => 'Mis entregas';

  @override
  String get honamNoRides => 'No hay entregas por ahora.';

  @override
  String get honamAcceptRide => 'Aceptar la entrega';

  @override
  String get honamPickup => 'Paquete recogido';

  @override
  String get honamDeliver => 'Validar la entrega';

  @override
  String get honamEnterCode => 'Código dado por el paciente';

  @override
  String get honamCoursePaid => 'He recibido el pago de la entrega';

  @override
  String get honamPaymentLinkOpened =>
      'Completa el pago en la página que se abre.';

  @override
  String get honamCourierSuspended =>
      'Cuenta suspendida tras 3 fallos de entrega. Contacta con soporte para recurrir.';

  @override
  String get honamPriceNote => 'Precios sin IVA; se añade el IVA del país.';

  @override
  String get certTitle => 'Pokou certificado';

  @override
  String get certPitch =>
      'La insignia demuestra que tu nombre es el tuyo. El modo prueba mantiene visibles, tachados, los mensajes borrados de un grupo.';

  @override
  String get certHowItWorks =>
      'Tu identidad se verifica con el nombre del titular del monedero que paga.';

  @override
  String certStartTrial(String days) {
    return 'Probar $days días';
  }

  @override
  String get certTrialNote =>
      'Durante la prueba, el modo prueba está disponible; la insignia aparece con el primer pago.';

  @override
  String certPlanPrice(String ht, String ttc) {
    return '$ht sin IVA · $ttc con IVA';
  }

  @override
  String get certSubscribe => 'Elegir';

  @override
  String get certActive => 'Insignia activa';

  @override
  String certTrialUntil(String date) {
    return 'Prueba hasta el $date';
  }

  @override
  String certActiveUntil(String date) {
    return 'Activo hasta el $date';
  }

  @override
  String get certExpired => 'Suscripción caducada';

  @override
  String get certMismatchTitle => 'Los nombres no coinciden';

  @override
  String get certMismatchBody =>
      'El nombre no coincide con el del titular del monedero que pagó. Corrígelo tal como figura en su documento.';

  @override
  String get proofModeTitle => 'Modo prueba';

  @override
  String get proofModeOnBanner =>
      'Modo prueba activo: un mensaje borrado sigue visible, tachado, para todos.';

  @override
  String get proofModeEnable => 'Activar el modo prueba';

  @override
  String get proofModeDisable => 'Desactivar el modo prueba';

  @override
  String get proofModeNeedsCert =>
      'El modo prueba requiere Pokou certificado (prueba gratuita disponible).';

  @override
  String get deleteForAll => 'Eliminar para todos';

  @override
  String get deleteProofWarning =>
      'El modo prueba está activo: el mensaje seguirá visible, tachado, para todos los miembros.';

  @override
  String get deletedKept => 'Mensaje borrado, conservado por el modo prueba';

  @override
  String get certCorrectName => 'Nombre completo del titular';

  @override
  String get certRetryName => 'Verificar este nombre';

  @override
  String get certStillMismatch => 'Este nombre sigue sin coincidir.';

  @override
  String get proofExport => 'Exportar la conversación (PDF)';

  @override
  String proofModeOn(String name) {
    return '$name activó el modo prueba';
  }

  @override
  String proofModeOff(String name) {
    return '$name desactivó el modo prueba';
  }

  @override
  String proofOriginal(String text) {
    return 'Versión original: $text';
  }

  @override
  String get proofDisableReserved =>
      'Solo quien lo activó, o un administrador con insignia de pago, puede desactivarlo.';

  @override
  String get marketBoost3 => '3 días · 600 FCFA';

  @override
  String get marketBoost7 => '7 días · 1 300 FCFA';

  @override
  String get marketUseHonam =>
      'Los medicamentos no se venden en Assimé: usa Honam.';

  @override
  String get honamMissingTitle => 'Falta un producto';

  @override
  String honamMissingBody(String amount, String reason) {
    return 'Faltan $amount: $reason. ¿Qué prefieres?';
  }

  @override
  String get honamKeepRest => 'Recibir el resto';

  @override
  String get honamCancelAll => 'Cancelar todo';

  @override
  String get honamRefundDelay =>
      'La farmacia te reembolsa en 2 h, al número que pagó.';

  @override
  String get honamZones => 'Zonas y horarios (p. ej. Bè, Tokoin — tardes)';

  @override
  String get honamWallet => 'Número del monedero que recibe el pago';

  @override
  String get honamRules =>
      'Acepto las reglas de oro: entrego el paquete solo con el código, no miro las recetas, soy cortés.';

  @override
  String get honamApply => 'Enviar mi candidatura';

  @override
  String get honamPending => 'Candidatura enviada: el equipo Pokou la revisa.';

  @override
  String get honamLaunch =>
      'Periodo de lanzamiento: entregas sin membresía ni paquete.';

  @override
  String get honamQueenLocked =>
      'Queen Pokou se desbloquea tras un mes sin fallos de entrega.';

  @override
  String koryDeclaredTotal(String amount) {
    return 'Total declarado: $amount';
  }

  @override
  String koryRemaining(String amount) {
    return 'Falta por recaudar: $amount';
  }

  @override
  String get onbBabaWelcome =>
      'Soy Baba, el asistente de Pokou. ¿Cómo quieres que te llamemos?';

  @override
  String get onbContactsTitle => 'Encuentra a los tuyos';

  @override
  String get onbContactsBody =>
      'Baba puede encontrar a tus contactos que ya están en Pokou. Puedes negarte: te lo volveremos a pedir.';

  @override
  String get onbContactsAllow => 'Permitir';

  @override
  String get onbLater => 'Más tarde';

  @override
  String get proofModeDirectHint =>
      'Todo lo escrito queda demostrable: un mensaje eliminado queda tachado, una edición conserva el original. Solo tú podrás desactivarlo.';

  @override
  String get proofDisableReservedDirect =>
      'Solo quien activó el modo prueba puede desactivarlo.';

  @override
  String get proofExportMe => 'Yo';

  @override
  String get proofExportTitle => 'Pokou — exportación del modo prueba';

  @override
  String proofExportBetween(String me, String contact) {
    return 'Conversación entre $me y $contact';
  }

  @override
  String proofExportPeriod(String since, String now) {
    return 'Modo prueba activo desde el $since · exportado el $now desde este teléfono';
  }

  @override
  String proofExportFooter(String page, String pages) {
    return 'Página $page de $pages — generado en el dispositivo: el servidor de Pokou no accede a los mensajes cifrados.';
  }

  @override
  String get proofExportAttachment => '[archivo adjunto]';

  @override
  String proofExportEdited(String at) {
    return 'Editado el $at';
  }

  @override
  String proofExportDeleted(String at) {
    return 'Eliminado el $at, conservado por el modo prueba';
  }

  @override
  String get proTitle => 'Pokou certificado Pro';

  @override
  String get proTeaser =>
      'Para una actividad: nombre comercial y «Gestionado por»';

  @override
  String get proPitch =>
      'Tu nombre comercial aparece primero, con «Gestionado por» y tu nombre verificado. El perfil Pro alojará tus anuncios de Assimé.';

  @override
  String proSteps(String hours) {
    return '1. Envías tu justificante. 2. El soporte lo verifica en $hours h. 3. Solo pagas tras la validación.';
  }

  @override
  String proPending(String due) {
    return 'Verificación en curso. Respuesta a más tardar el $due.';
  }

  @override
  String get proApproved =>
      'Justificante validado: puedes activar Pokou certificado Pro.';

  @override
  String get proPay => 'Pagar Pokou certificado Pro';

  @override
  String get proCorrection => 'Justificante por corregir';

  @override
  String get proRejected => 'Solicitud rechazada';

  @override
  String get proActivity => 'Tu actividad';

  @override
  String get proBusinessName => 'Nombre comercial';

  @override
  String get proActivityField => 'Actividad (costura, tienda, transporte…)';

  @override
  String get proDocument => 'Añadir el justificante';

  @override
  String get proDocumentChosen => 'Justificante añadido — toca para cambiar';

  @override
  String get proDocumentNote =>
      'Registro mercantil, tarjeta profesional o licencia. Solo lo ve el soporte, nunca se muestra.';

  @override
  String get proSend => 'Enviar para verificación';

  @override
  String proManagedBy(String name) {
    return 'Gestionado por $name';
  }

  @override
  String get proProfileNote => 'Así ven los demás tu perfil Pro.';

  @override
  String get honamCity => 'Ciudad';

  @override
  String get honamOtherCity => 'Otra ciudad';

  @override
  String get honamYourCity => 'Tu ciudad';

  @override
  String get honamNotServed =>
      'Honam aún no entrega en esta ciudad. Apúntate: te avisaremos cuando abra.';

  @override
  String get honamJoinWaitlist => 'Apuntarme a la lista de espera';

  @override
  String honamWaitlistDone(String city) {
    return 'Apuntado para $city';
  }

  @override
  String get honamWaitlistBody =>
      'Te avisaremos en cuanto Honam entregue en tu ciudad. Nada más.';

  @override
  String get honamReferralCodeField => 'Código de referido (opcional)';

  @override
  String get honamReferralTitle => 'Recomienda a un repartidor';

  @override
  String honamReferralBody(String rides) {
    return '$rides entregas gratis en la primera entrega de tu referido.';
  }

  @override
  String get honamReferralShare => 'Compartir mi código';

  @override
  String honamReferralMessage(String code) {
    return 'Reparte para Honam con Pokou: usa mi código $code en el modo repartidor.';
  }

  @override
  String honamReferralCount(String count) {
    return 'Referidos: $count';
  }

  @override
  String get honamTrialEnded => 'Tu prueba ha terminado';

  @override
  String honamRecommendedPack(String pack) {
    return 'Según tus entregas del mes, te basta el pack $pack.';
  }

  @override
  String get honamNavigate => 'Ruta en mi app de mapas';

  @override
  String get honamLocationShared =>
      'Tu ubicación se comparte cada 15 s durante la entrega, nunca después.';

  @override
  String get honamLocationDenied =>
      'Permite la ubicación para que el paciente siga la entrega.';

  @override
  String get honamCourier => 'el repartidor';

  @override
  String honamTrackingTitle(String name) {
    return '$name está en camino';
  }

  @override
  String get honamTrackingWaiting => 'Ubicación aún no recibida.';

  @override
  String honamTrackingDistance(String km) {
    return 'A $km km de ti';
  }

  @override
  String honamTrackingUpdated(String minutes) {
    return 'Actualizado hace $minutes min';
  }

  @override
  String get honamTrackingStale => 'Ubicación no actualizada';

  @override
  String get honamTrackingShowMap => 'Ver en el mapa';

  @override
  String get honamTrackingMapDataSaver => 'Ver en el mapa (consume datos)';

  @override
  String get assimeFavoritesAlerts => 'Favoritos y alertas';

  @override
  String get assimeFavorites => 'Favoritos';

  @override
  String get assimeAlerts => 'Alertas';

  @override
  String get assimeNoFavorites => 'Ningún favorito';

  @override
  String get assimeFavoritesHint =>
      'Toca el corazón de un anuncio para guardarlo aquí.';

  @override
  String get assimeAddFavorite => 'Añadir a favoritos';

  @override
  String get assimeRemoveFavorite => 'Quitar de favoritos';

  @override
  String get assimeNewAlert => 'Nueva alerta';

  @override
  String get assimeAlertQuery => 'Lo que buscas';

  @override
  String get assimeAlertMaxPrice => 'Precio máximo (opcional)';

  @override
  String get assimeAlertNote =>
      'Te avisamos cuando un anuncio coincida. La alerta solo lee anuncios, nunca tus mensajes.';

  @override
  String get assimeNoAlerts => 'Aún no hay alertas.';

  @override
  String assimeAlertUpTo(String price) {
    return 'hasta $price FCFA';
  }

  @override
  String assimeAlertMatches(String count) {
    return '$count anuncio(s) encontrado(s)';
  }

  @override
  String get assimeSponsored => 'Patrocinado';

  @override
  String get assimeWhyTitle => 'Por qué veo esto';

  @override
  String get assimeWhyNotSponsored => 'Este anuncio ya no está destacado.';

  @override
  String get assimeReportTitle => 'Balance de la promoción';

  @override
  String get assimeReportEmpty => 'Aún no hay promoción para este anuncio.';

  @override
  String assimeReportPeriod(String days, String start, String end) {
    return '$days días · del $start al $end';
  }

  @override
  String assimeReportImpressions(String count) {
    return 'Mostrado arriba en resultados: $count veces';
  }

  @override
  String assimeReportStatusViews(String count) {
    return 'Visto en estados: $count veces';
  }

  @override
  String assimeReportContacts(String count) {
    return 'Personas que te contactaron: $count';
  }

  @override
  String get assimeStatusPending =>
      'Lugar en estados: en revisión por moderación';

  @override
  String get assimeStatusRejected =>
      'Lugar en estados rechazado por moderación';

  @override
  String get koryKindTontine => 'Tontina';

  @override
  String get koryFieldStake => 'Aporte de cada uno por turno (FCFA)';

  @override
  String get koryRotation => 'Orden de los turnos';

  @override
  String get koryRotationHint =>
      'Arrastra para ordenar. El orden se fija al abrir y no cambia.';

  @override
  String get koryRemoveFromRotation => 'Quitar de la tontina';

  @override
  String get koryNeedRotation =>
      'Una tontina necesita al menos dos participantes.';

  @override
  String get koryTontineNote =>
      'En cada turno, cada uno envía su aporte al wallet del beneficiario, que confirma lo recibido. Pokou nunca toca el dinero.';

  @override
  String get koryRounds => 'Los turnos';

  @override
  String koryRoundNumber(String number) {
    return 'Turno $number';
  }

  @override
  String koryRoundConfirmed(String confirmed, String expected) {
    return '$confirmed confirmados de $expected';
  }

  @override
  String get koryNextRound => 'Pasar al siguiente turno';

  @override
  String get koryNextRoundBody =>
      'El turno actual termina. Las contribuciones declaradas siguen pendientes de confirmar por su beneficiario.';

  @override
  String get koryLastRoundBody =>
      'Era el último turno: la tontina se cerrará. El registro sigue disponible.';

  @override
  String get welcomeStart => 'Empezar';

  @override
  String get authAcceptAndContinue => 'Aceptar y continuar';

  @override
  String get authAcceptNotice =>
      'Al tocar «Aceptar y continuar», aceptas las condiciones de uso y la política de privacidad, y declaras tener la edad requerida.';

  @override
  String get deleteAccountTitle => 'Eliminar mi cuenta';

  @override
  String get deleteAccountWarning => 'Esta acción es definitiva.';

  @override
  String get deleteAccountRemovedTitle => 'Lo que se elimina';

  @override
  String get deleteAccountRemovedProfile =>
      'Tu perfil, tu foto y tu copia de seguridad';

  @override
  String get deleteAccountRemovedChats => 'Tus conversaciones en este teléfono';

  @override
  String get deleteAccountRemovedBadge =>
      'Tu insignia, sin reembolso del mes en curso';

  @override
  String get deleteAccountKeptTitle => 'Lo que permanece';

  @override
  String get deleteAccountKeptMessages =>
      'Los mensajes ya recibidos por tus contactos';

  @override
  String get deleteAccountKeptProof =>
      'Los registros del modo prueba de los demás participantes';

  @override
  String get deleteAccountKeptKory =>
      'El registro de las colectas Kory, que no se borra';

  @override
  String get deleteAccountConfirmLabel => 'Confirma tu número';

  @override
  String get deleteAccountMismatch => 'Este número no corresponde a tu cuenta.';

  @override
  String get deleteAccountFailed => 'La eliminación falló. Inténtalo de nuevo.';

  @override
  String get helpTitle => 'Ayuda y soporte';

  @override
  String get helpSearchHint => 'Buscar en la ayuda';

  @override
  String get helpAskBaba => 'Preguntar a Baba';

  @override
  String get helpAskBabaSub => 'El asistente de IA responde al instante';

  @override
  String get helpFaqTitle => 'Preguntas frecuentes';

  @override
  String get helpQMoney => '¿Pokou toca mi dinero?';

  @override
  String get helpAMoney =>
      'No. Colectas, farmacias y repartidores se pagan de monedero a monedero. Pokou nunca guarda tu dinero.';

  @override
  String get helpQProof => '¿Cómo funciona el modo prueba?';

  @override
  String get helpAProof =>
      'Activado por un titular de Pokou certificado, mantiene visibles, tachados, los mensajes borrados o editados. Siempre se indica al inicio del chat.';

  @override
  String get helpQSms => 'No recibo el código SMS';

  @override
  String get helpASms =>
      'Comprueba el número y la red, y espera a que termine la cuenta atrás para pedir otro código. Pokou nunca te pedirá este código, ni por mensaje ni por llamada.';

  @override
  String get helpQCourier => '¿Cómo ser repartidor de Honam?';

  @override
  String get helpACourier =>
      'En Más, toca «Ser repartidor de Honam»: identidad, zonas, monedero y reglas de oro. Honam abre ciudad por ciudad.';

  @override
  String get helpQScam => '¿Cómo detectar una estafa?';

  @override
  String get helpAScam =>
      'Desconfía de quien pida un código SMS, tu PIN o un pago urgente. Pokou nunca lo hace. Bloquea y denuncia al contacto.';

  @override
  String get helpSupport => 'Escribir al soporte';

  @override
  String get helpSupportSub => 'Respuesta en la aplicación';

  @override
  String get helpReport => 'Informar de un problema';

  @override
  String get helpNoResult => 'Ninguna pregunta coincide. Pregunta a Baba.';

  @override
  String get aboutTitle => 'Acerca de Pokou';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get aboutNamesTitle => 'El sentido de nuestros nombres';

  @override
  String get aboutPokou => 'un nombre baulé';

  @override
  String get aboutKory => 'el cauri';

  @override
  String get aboutHonam => '«ayúdame», en ewe';

  @override
  String get aboutAssime => '«en el mercado», en ewe';

  @override
  String get aboutWetri => '«mes», en ewe';

  @override
  String get aboutEpe => '«año», en ewe';

  @override
  String get aboutNextNames =>
      'Nuestros próximos servicios también llevarán nombres de lenguas africanas.';

  @override
  String get aboutLicenses => 'Licencias de software libre';

  @override
  String get legalEssentials => 'Lo esencial';

  @override
  String get legalFullText => 'Texto completo';

  @override
  String get termsE1 =>
      'Pokou nunca toca el dinero: colectas, farmacias y repartidores se pagan de monedero a monedero.';

  @override
  String get termsE2 =>
      'El modo prueba conserva el rastro de los mensajes borrados, y siempre se indica.';

  @override
  String get termsE3 => 'Honam no es un servicio de urgencias.';

  @override
  String get termsE4 =>
      'Las insignias de pago se cancelan en cualquier momento.';

  @override
  String get privacyE1 =>
      'Tu número nunca se muestra a un vendedor ni a un repartidor.';

  @override
  String get privacyE2 =>
      'Pokou no lee tus mensajes. Una denuncia solo envía los 5 últimos al soporte.';

  @override
  String get privacyE3 =>
      'La ubicación del repartidor no se conserva tras la entrega.';

  @override
  String get privacyE4 =>
      'Los anuncios patrocinados se dirigen por ciudad, nunca a partir de tus mensajes.';

  @override
  String get languageNote =>
      'El idioma de la aplicación no cambia el de tus mensajes. Los nombres Pokou, Kory, Honam y Assimé no cambian en ningún idioma.';

  @override
  String get securityPinWarning =>
      'Pokou nunca te pedirá tu PIN ni el código SMS, ni por mensaje ni por llamada.';

  @override
  String get statusReplyPrivate =>
      'Tu respuesta llega en privado, en vuestro chat a dos.';

  @override
  String get statusViewersNote =>
      'Solo tú ves esta lista. Las respuestas llegan en privado, en tus chats.';

  @override
  String get statusWhoSees => 'Quién ve mis estados';

  @override
  String get attachCompressNote =>
      'Las fotos y vídeos se comprimen antes de enviarse para ahorrar datos.';

  @override
  String get otpTitle => 'Introduce el código';

  @override
  String get pinForgot => '¿Olvidaste tu PIN?';

  @override
  String get pinTitle => 'Tu PIN';

  @override
  String statusReplyHint(String name) {
    return 'Responder a $name…';
  }

  @override
  String get statusReplyQuote => '↩ En respuesta a tu estado';

  @override
  String get statusReplySent => 'Respuesta enviada en privado.';

  @override
  String get changeNumberTitle => 'Cambiar de número';

  @override
  String get changeNumberOld => 'Número anterior';

  @override
  String get changeNumberNew => 'Número nuevo';

  @override
  String get changeNumberNotify => 'Avisar a mis contactos';

  @override
  String get changeNumberNotifyAll => 'Todos mis contactos';

  @override
  String get changeNumberNotifyChatted => 'Con quienes he chateado';

  @override
  String get changeNumberNotifyNone => 'Nadie';

  @override
  String get changeNumberNotifyNoneSub => 'Tus grupos siempre son avisados';

  @override
  String get changeNumberInfo =>
      'Tu cuenta, tus chats, tu insignia Pokou certificado y tus colectas Kory te siguen. Se envía un código al número nuevo.';

  @override
  String get changeNumberKoryWarning =>
      'Si recaudas una colecta, tu número de cobro no cambia solo: cámbialo en Kory, los miembros serán avisados.';

  @override
  String get changeNumberSendCode => 'Enviar el código';

  @override
  String get changeNumberCodeLabel => 'Código recibido por SMS';

  @override
  String get changeNumberConfirm => 'Confirmar el cambio';

  @override
  String get changeNumberDone => 'Tu número ha cambiado.';

  @override
  String get pinForgotIntro => 'Dos formas de recuperar tu cuenta:';

  @override
  String get pinForgotEmail => 'Por correo';

  @override
  String get pinForgotEmailSub =>
      'Si añadiste una dirección: se te envía un enlace de restablecimiento';

  @override
  String get pinForgotWait => 'Esperar 7 días';

  @override
  String get pinForgotWaitSub =>
      'Después entras sin PIN con el código SMS, siempre que conserves tu número';

  @override
  String get pinForgotWarning =>
      'El plazo de 7 días impide que quien robe tu tarjeta SIM se quede con tu cuenta de inmediato.';

  @override
  String get pinForgotMeanwhile =>
      'Mientras esperas, tus contactos te siguen viendo y tus mensajes te esperan.';

  @override
  String get pinForgotContinue => 'Continuar';

  @override
  String pinForgotScheduled(String date) {
    return 'Anotado. A partir del $date, bastará el código SMS para entrar.';
  }

  @override
  String get groupDelete => 'Eliminar el grupo';

  @override
  String groupDeleteTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get groupDeleteBody =>
      'El grupo desaparece para todos sus miembros, con sus mensajes. Es definitivo.';

  @override
  String get groupDeleteFailed => 'No se pudo eliminar — inténtalo de nuevo.';

  @override
  String get groupManageTitle => 'Gestionar el grupo';

  @override
  String get groupManageSubtitle =>
      'Permisos, nuevos miembros, mensajes temporales';

  @override
  String get groupPermissions => 'Permisos';

  @override
  String get groupEditInfoSetting => 'Editar nombre y foto';

  @override
  String get groupSendSetting => 'Enviar mensajes';

  @override
  String get groupApproveSetting => 'Aprobar nuevos miembros';

  @override
  String get groupApproveSettingSub =>
      'Un administrador valida cada entrada por enlace';

  @override
  String get groupAllMembers => 'Todos los miembros';

  @override
  String get groupDisappearing => 'Mensajes temporales';

  @override
  String get groupDisappearingOff => 'Desactivados';

  @override
  String get groupDisappearing24h => '24 horas';

  @override
  String get groupDisappearing7d => '7 días';

  @override
  String get groupDisappearing90d => '90 días';

  @override
  String get groupJoinRequests => 'Solicitudes de entrada';

  @override
  String get groupNoJoinRequest => 'No hay solicitudes pendientes.';

  @override
  String get groupApprove => 'Aceptar';

  @override
  String get groupReject => 'Rechazar';

  @override
  String get groupJoinPending =>
      'Solicitud enviada: un administrador debe aprobar tu entrada.';

  @override
  String get groupSettingsSaveFailed =>
      'Ajuste no guardado — inténtalo de nuevo.';

  @override
  String get groupLeaveKoryNote =>
      'Salir del grupo no elimina la colecta en curso: tus aportes quedan en el registro Kory.';

  @override
  String get messageWaiting => 'Esperando este mensaje…';

  @override
  String get callWaitingNotice =>
      'Ya estás en una llamada. Rechazar la mantiene; aceptar la termina.';

  @override
  String get callEndAndAccept => 'Terminar y aceptar';

  @override
  String get homeHelloOverline => 'Hola';

  @override
  String get koryOverline => 'Ahorro solidario';

  @override
  String koryActiveCount(String count) {
    return '$count activas';
  }
}
