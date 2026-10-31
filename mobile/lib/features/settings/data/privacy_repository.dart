import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

/// Qui peut voir quoi — les trois seules réponses possibles.
///
/// Le même vocabulaire que le serveur (`PrivacyAudience`), et pas une
/// traduction approximative : le code qui part sur le réseau est celui-ci,
/// et une chaîne recopiée à la main aurait fini par diverger d'une lettre.
enum PrivacyAudience {
  everyone('EVERYONE'),
  contacts('CONTACTS'),
  nobody('NOBODY');

  const PrivacyAudience(this.wire);

  final String wire;

  static PrivacyAudience parse(String? valeur) {
    for (final a in PrivacyAudience.values) {
      if (a.wire == valeur) return a;
    }
    // Une valeur inconnue — serveur plus récent que l'application — retombe
    // sur le plus restrictif des choix plausibles. Se tromper vers « mes
    // contacts » se corrige d'un réglage ; se tromper vers « tout le monde »
    // ne se rattrape pas.
    return PrivacyAudience.contacts;
  }
}

/// L'état complet de l'écran « Confidentialité ».
///
/// Un seul objet, un seul aller-retour. Les réglages existaient éparpillés
/// sur trois routes ; une page qui fait trois appels pour s'afficher montre
/// un état incohérent dès que l'un des trois échoue.
class PrivacySettings {
  const PrivacySettings({
    required this.lastSeen,
    required this.online,
    required this.profilePhoto,
    required this.profileInfo,
    required this.groupMembership,
    required this.groupInvites,
    required this.readReceipts,
    required this.presenceReciprocal,
  });

  final PrivacyAudience lastSeen;
  final PrivacyAudience online;
  final PrivacyAudience profilePhoto;
  final PrivacyAudience profileInfo;
  final PrivacyAudience groupMembership;
  final PrivacyAudience groupInvites;

  /// Booléens, et non une audience à trois valeurs : ces deux-là portent une
  /// RÉCIPROCITÉ — les couper me prive de ceux des autres — qu'une audience
  /// ne saurait pas exprimer.
  final bool readReceipts;
  final bool presenceReciprocal;

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        lastSeen: PrivacyAudience.parse(json['last_seen'] as String?),
        online: PrivacyAudience.parse(json['online'] as String?),
        profilePhoto: PrivacyAudience.parse(json['profile_photo'] as String?),
        profileInfo: PrivacyAudience.parse(json['profile_info'] as String?),
        groupMembership: PrivacyAudience.parse(
          json['group_membership'] as String?,
        ),
        groupInvites: PrivacyAudience.parse(json['group_invites'] as String?),
        readReceipts: json['read_receipts'] as bool? ?? true,
        presenceReciprocal: json['presence_reciprocal'] as bool? ?? true,
      );
}

class PrivacyRepository {
  PrivacyRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<PrivacySettings> get() async {
    final reponse = await _api.get('/account-privacy/privacy');
    return PrivacySettings.fromJson(reponse as Map<String, dynamic>);
  }

  /// N'envoie QUE ce qui change.
  ///
  /// Le serveur applique une sémantique de PATCH : les champs absents
  /// restent tels quels. Envoyer l'objet entier fonctionnerait aussi, mais
  /// écraserait un réglage modifié entre-temps depuis un autre appareil —
  /// et on ne remet pas en silence quelque chose que quelqu'un vient de
  /// fermer.
  Future<PrivacySettings> update({
    PrivacyAudience? lastSeen,
    PrivacyAudience? online,
    PrivacyAudience? profilePhoto,
    PrivacyAudience? profileInfo,
    PrivacyAudience? groupMembership,
    PrivacyAudience? groupInvites,
    bool? readReceipts,
    bool? presenceReciprocal,
  }) async {
    final reponse = await _api.put(
      '/account-privacy/privacy',
      body: {
        if (lastSeen != null) 'last_seen': lastSeen.wire,
        if (online != null) 'online': online.wire,
        if (profilePhoto != null) 'profile_photo': profilePhoto.wire,
        if (profileInfo != null) 'profile_info': profileInfo.wire,
        if (groupMembership != null) 'group_membership': groupMembership.wire,
        if (groupInvites != null) 'group_invites': groupInvites.wire,
        if (readReceipts != null) 'read_receipts': readReceipts,
        if (presenceReciprocal != null)
          'presence_reciprocal': presenceReciprocal,
      },
    );
    return PrivacySettings.fromJson(reponse as Map<String, dynamic>);
  }
}

final privacyRepositoryProvider = Provider<PrivacyRepository>(
  (ref) => PrivacyRepository(apiClient: ref.watch(apiClientProvider)),
);

final privacySettingsProvider = FutureProvider.autoDispose<PrivacySettings>(
  (ref) => ref.watch(privacyRepositoryProvider).get(),
);
