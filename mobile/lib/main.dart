import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/crypto/e2ee_retry_service.dart';
import 'core/crypto/e2ee_service.dart';
import 'core/deeplink/deep_link_service.dart';
import 'core/media/media_repository.dart';
import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/security/app_lock.dart';
import 'core/l10n/app_locales.dart';
import 'core/settings/app_settings.dart';
import 'l10n/app_localizations.dart';
import 'core/sync/outbox_service.dart';
import 'core/sync/pokou_sync_engine.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/calls/presentation/call_controller.dart';
import 'features/calls/presentation/native_call_gate.dart';
import 'features/channels/presentation/channel_controller.dart';
import 'features/contacts/presentation/contacts_controller.dart';
import 'features/contacts/presentation/discussions_controller.dart';
import 'features/presence/presentation/typing_controller.dart';
import 'features/status/presentation/status_controller.dart';
import 'features/communities/presentation/community_controller.dart';
import 'features/calls/presentation/ongoing_call_banner.dart';
import 'features/modules/verses/verse_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sans ceci, Android peint ses propres barres système (souvent teintées
  // par l'accent Material You du téléphone, pas par le thème de l'app) —
  // edge-to-edge + icônes sombres pour rester cohérent avec le fond clair.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Seulement pour la toute première image : le réglage de thème n'est pas
  // encore lu, et PokouApp.build reposera le bon style dès qu'il l'aura.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Sans configuration Firebase (iOS tant que GoogleService-Info.plist n'est
  // pas fourni), l'application démarre sans notifications push au lieu de
  // s'arrêter sur un écran noir. Le Web utilise ses options dédiées.
  try {
    await Firebase.initializeApp(
      options: kIsWeb ? DefaultFirebaseOptions.web : null,
    );
    // Doit être enregistré tôt, avant runApp — voir push_service.dart pour
    // le reste de l'initialisation FCM (permission, écoute au premier plan,
    // navigation au tap), déclenché par pushServiceProvider dans PokouApp.
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (error) {
    debugPrint(
      '[Pokou/push] Firebase indisponible, pas de notifications : $error',
    );
  }

  // Préchauffer le répertoire de cache pour accélérer la résolution synchrone des médias.
  unawaited(MediaRepository.warmup());

  runApp(const ProviderScope(child: PokouApp()));
}

class PokouApp extends ConsumerWidget {
  const PokouApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Écoute les invitations d'appel entrantes pour toute la durée de vie de
    // l'app — voir call_controller.dart::callSignalingProvider.
    ref.watch(callSignalingProvider);
    // Le pont vers la couche d'appel NATIVE. Sans cette ligne, répondre
    // depuis la notification application fermée ouvrait Pokou sur l'écran
    // d'accueil et perdait l'appel : le pont existait, rien ne l'appelait.
    ref.watch(nativeCallGateProvider);
    ref.watch(communityMembershipSyncProvider);
    // Reçus de nouvel essai : aucun message ne reste illisible — voir
    // e2ee_retry_service.dart.
    ref.watch(e2eeRetryServiceProvider);
    // Notifications push (FCM) — voir push_service.dart.
    ref.watch(pushServiceProvider);
    // Les versets de 6 h et 18 h : réserve rechargée à chaque ouverture,
    // replanifiée quand la langue change.
    ref.watch(verseSyncProvider);
    // Liens d'invitation cliquables (App Links/Universal Links) — voir
    // core/deeplink/deep_link_service.dart.
    ref.watch(deepLinkServiceProvider);
    // Réglages locaux (notifications, économie de données) — lus depuis
    // PushService et les bulles média, d'où le chargement dès le démarrage
    // plutôt qu'à l'ouverture de l'écran de réglages.
    ref.watch(appSettingsProvider);
    // Liste des discussions à jour en direct — voir discussions_controller.dart.
    // Global et non local à l'écran : une conversation doit remonter en tête
    // de liste même pendant qu'on regarde un autre onglet.
    ref.watch(discussionsRealtimeProvider);
    // « En train d'écrire » — global, pour que la liste d'accueil
    // l'affiche sur une conversation qu'on n'a pas ouverte.
    ref.watch(typingProvider);
    // Carnet d'adresses en direct : arrivée d'un contact poussée par le
    // serveur, relecture du répertoire au retour au premier plan.
    ref.watch(contactSyncProvider);
    // Trousseau de chiffrement publié et réapprovisionné — voir
    // core/crypto/e2ee_service.dart.
    ref.watch(e2eeKeyPublicationProvider);
    // Actualités et chaînes en direct : c'est ce qu'on regarde SANS rien
    // demander, donc là où l'absence de poussée se remarquait le plus.
    ref.watch(statusRealtimeProvider);
    // L'anneau « statut non vu » doit être juste dès l'ouverture, et pas
    // seulement après un passage par l'onglet Actus : il se dessine dans la
    // liste des discussions et dans les contacts.
    ref.watch(statusRingSyncProvider);
    ref.watch(channelsRealtimeProvider);
    // File d'attente des messages composés hors ligne — surveillée ici et
    // non dans l'écran de conversation : un message écrit puis l'écran
    // quitté doit partir quand même, et une file héritée du lancement
    // précédent doit se vider au démarrage (voir outbox_service.dart).
    ref.watch(outboxServiceProvider);
    // Journal local et rattrapage cursorisé des événements durables.
    ref.watch(pokouSyncEngineProvider);

    // La langue : celle choisie dans le profil, ou `null` pour suivre le
    // téléphone. `null` n'est PAS « français » — Flutter résout alors la
    // locale du système contre `supportedLocales`, et retombe sur la
    // première (le français) seulement si aucune ne correspond.
    final localeCode = ref.watch(
      appSettingsProvider.select((settings) => settings.localeCode),
    );

    // Le thème choisi — clair, sombre, ou celui du téléphone.
    final themeMode = ref.watch(
      appSettingsProvider.select((settings) => settings.themeMode),
    );
    // La luminosité RÉELLEMENT en vigueur, résolue ici et posée sur la
    // palette AVANT de construire l'arbre. `AppColors` n'est pas lu à
    // travers un `BuildContext` (voir le commentaire en tête de
    // app_colors.dart) : c'est ce sélecteur global qui rend ses 952 usages
    // sensibles au thème. MaterialApp se reconstruit quand la luminosité du
    // système change, donc la descendance suit.
    final brightness = switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    AppColors.applyBrightness(brightness);
    // Les icônes des barres système suivent, elles aussi. Elles étaient
    // fixées en SOMBRE une fois pour toutes dans `main()` — ce qui donnait,
    // en mode sombre, des icônes noires sur une barre noire : invisibles.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return MaterialApp.router(
      title: 'Pokou',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      darkTheme: AppTheme.dark,
      theme: AppTheme.light,
      routerConfig: router,
      locale: localeCode == null ? null : Locale(localeCode),
      supportedLocales: L.supportedLocales,
      // Sans ce repli, un téléphone dans une langue que Pokou ne parle pas
      // tombait sur la PREMIÈRE locale déclarée — et le générateur les range
      // par ordre alphabétique, donc sur l'arabe. Quelqu'un avec un
      // téléphone en japonais aurait ouvert Pokou en arabe, aligné à droite.
      //
      // Le français est la langue de référence : c'est celle dans laquelle
      // l'application est écrite, et celle vers laquelle une clé manquante
      // retombe déjà.
      localeResolutionCallback: appLocaleResolution,
      // `GlobalWidgetsLocalizations` porte la DIRECTION du texte : c'est lui
      // qui met toute l'interface en droite-à-gauche en arabe, sans qu'aucun
      // écran n'ait à le savoir. L'omettre laisserait l'arabe traduit mais
      // aligné à gauche, ce qui est pire que pas d'arabe du tout.
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // AppLockGate en dehors de la pile : l'écran de code doit couvrir
      // aussi la bulle d'appel différé du Mode Bouclier.
      builder: (context, child) => AppLockGate(
        child: Stack(
          children: [
            // Le bandeau « Appel en cours » au-dessus de toute l'application
            // — voir OngoingCallFrame pour la structure qui ne doit jamais
            // changer.
            if (child != null) OngoingCallFrame(child: child),
          ],
        ),
      ),
    );
  }
}
