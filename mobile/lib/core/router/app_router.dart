import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/otp_verify_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/inbox/presentation/inbox_screen.dart';

/// Clé du Navigator racine — permet de pousser un écran plein écran (appel
/// entrant) depuis un provider global, sans dépendre du BuildContext d'un
/// écran particulier (voir features/calls/presentation/call_controller.dart).
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/phone', builder: (context, state) => const PhoneEntryScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) => OtpVerifyScreen(phone: state.extra as String),
      ),
      GoRoute(path: '/inbox', builder: (context, state) => const InboxScreen()),
      GoRoute(
        path: '/chat/:monitorId',
        builder: (context, state) => ChatScreen(
          monitorId: int.parse(state.pathParameters['monitorId']!),
          contactName: state.extra as String? ?? 'Smart Contact',
        ),
      ),
    ],
  );
});
