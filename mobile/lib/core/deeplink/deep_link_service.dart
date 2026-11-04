import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/channels/presentation/channel_controller.dart';
import '../../features/channels/presentation/channel_screen.dart';
import '../../features/communities/presentation/community_controller.dart';
import '../../features/communities/presentation/community_detail_screen.dart';
import '../../features/groups/presentation/group_controller.dart';
import '../../features/groups/presentation/group_conversation_screen.dart';
import '../../features/honam/presentation/honam_order_screen.dart';
import '../../features/kory/presentation/kory_pot_screen.dart';
import '../../features/messaging/presentation/conversation_screen.dart';
import '../api/api_exceptions.dart';
import '../providers.dart';
import '../router/app_router.dart';
import 'invite_link_parser.dart';

/// Écoute globale des liens entrants (Android App Links / iOS
/// Universal Links, voir AndroidManifest.xml et — si présent — Info.plist)
/// pour toute la durée de vie de l'app, watché une seule fois depuis
/// PokouApp (voir main.dart), même schéma que callSignalingProvider /
/// pushServiceProvider / shieldControllerProvider.
///
/// Rejoint DIRECTEMENT le groupe/la communauté au clic sur le lien plutôt
/// que d'afficher un aperçu à confirmer : c'est la demande explicite qui a
/// motivé ce ticket (supprimer l'étape manuelle « coller le code puis
/// Rejoindre »), et l'endpoint de jonction est déjà idempotent côté API
/// (toucher deux fois le même lien renvoie le groupe/la communauté sans
/// erreur) — un aperçu préalable n'aurait fait qu'ajouter un aller-retour
/// réseau et un appui de confirmation, contrairement au but recherché.
class DeepLinkService {
  DeepLinkService(this._ref) {
    unawaited(_init());
  }

  final Ref _ref;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Lien reçu avant que l'utilisateur soit connecté (lien ouvert au
  /// premier lancement, ou pendant que la session précédente a expiré).
  /// Une seule intention suffit — pas une file : si plusieurs liens
  /// arrivent avant la connexion, le plus récent est celui qu'on honore.
  PendingInvite? _pendingInvite;

  Future<void> _init() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) await _handleUri(initialLink);
    } catch (exc) {
      // Best-effort — l'absence de lien de démarrage n'est pas une erreur,
      // et une plateforme qui ne supporte pas l'appel ne doit pas empêcher
      // le reste de l'app de démarrer.
      debugPrint('[DeepLink] Lien de démarrage illisible: $exc');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleUri(uri)),
      onError: (exc) => debugPrint('[DeepLink] Flux de liens en erreur: $exc'),
    );

    // Rejoue l'intention mémorisée dès qu'une connexion aboutit — le lien
    // a pu arriver avant que l'utilisateur soit authentifié.
    _ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final justAuthenticated =
          next.status == AuthStatus.authenticated &&
          previous?.status != AuthStatus.authenticated;
      if (justAuthenticated) unawaited(_consumePendingInvite());
    });
  }

  Future<void> _handleUri(Uri uri) async {
    final invite = parseInviteLink(uri);
    if (invite == null) return; // Lien étranger ou mal formé : ignoré.

    if (_ref.read(authControllerProvider).status != AuthStatus.authenticated) {
      _pendingInvite = invite;
      return;
    }
    await _joinAndNavigate(invite);
  }

  Future<void> _consumePendingInvite() async {
    final invite = _pendingInvite;
    if (invite == null) return;
    _pendingInvite = null;
    await _joinAndNavigate(invite);
  }

  Future<void> _joinAndNavigate(PendingInvite invite) async {
    final myUserId = _ref.read(authControllerProvider).user?.id;
    if (myUserId == null) return;

    try {
      if (invite.kind == DeepLinkInviteKind.koryPot) {
        final potId = invite.resourceId;
        if (potId == null) return;
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => KoryPotScreen(potId: potId)),
        );
        return;
      }
      if (invite.kind == DeepLinkInviteKind.honamOrder) {
        final orderId = invite.resourceId;
        if (orderId == null) return;
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => HonamOrderScreen(orderId: orderId)),
        );
        return;
      }
      if (invite.kind == DeepLinkInviteKind.bot) {
        final bot =
            await _ref.read(apiClientProvider).get('/bots/${invite.code}')
                as Map<String, dynamic>;
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              myUserId: myUserId,
              contactUserId: bot['user_id'] as int,
              contactName: bot['name'] as String? ?? invite.code,
            ),
          ),
        );
        return;
      }
      if (invite.kind == DeepLinkInviteKind.channel) {
        final channel = await _ref
            .read(channelRepositoryProvider)
            .joinByInvite(invite.code);
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                ChannelScreen(channel: channel, targetPostId: invite.postId),
          ),
        );
        return;
      }
      if (invite.kind == DeepLinkInviteKind.group) {
        final group = await _ref
            .read(groupRepositoryProvider)
            .joinByInvite(invite.code);
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => GroupConversationScreen(
              myUserId: myUserId,
              groupId: group.id,
              groupName: group.name,
            ),
          ),
        );
      } else {
        final community = await _ref
            .read(communityRepositoryProvider)
            .joinByInvite(invite.code);
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(
              communityId: community.id,
              myUserId: myUserId,
            ),
          ),
        );
      }
    } catch (exc) {
      // Code expiré/invalide, déjà membre en erreur (rare, l'API est
      // idempotente sur ce cas), ou panne réseau — jamais un plantage,
      // juste un message clair.
      final serverMessage = exc is ApiException ? exc.message : null;
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        final message = serverMessage ?? L.of(context).deeplinkOpenFailed;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  ref.onDispose(service.dispose);
  return service;
});
