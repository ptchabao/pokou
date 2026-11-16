import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/time/server_time.dart';

/// Version de l'application jointe à une demande : celle passée au build
/// (`--dart-define=POKOU_VERSION=…`, voir build-production.sh). Vide en
/// développement — on n'envoie alors rien plutôt qu'un numéro inventé.
const _appVersion = String.fromEnvironment('POKOU_VERSION');

/// Catégories proposées par « Signaler un problème », dans l'ordre affiché.
/// Les valeurs sont celles du serveur (app/api/v1/support/support.py).
const supportProblemCategories = [
  'ACCOUNT',
  'MESSAGES',
  'CALLS',
  'NOTIFICATIONS',
  'CRASH',
  'OTHER',
];

/// Une demande au support (« Écrire au support ») ou un problème signalé
/// (« Signaler un problème »), telle que la personne la voit : son texte,
/// son état et la réponse de l'équipe.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.kind,
    required this.category,
    required this.status,
    required this.createdAt,
    this.description,
    this.reply,
    this.repliedAt,
  });

  final int id;

  /// SUPPORT | PROBLEM
  final String kind;
  final String category;

  /// OPEN | ANSWERED | CLOSED
  final String status;
  final DateTime createdAt;

  /// Nuls si le serveur ne peut plus les déchiffrer (clé changée).
  final String? description;
  final String? reply;
  final DateTime? repliedAt;

  bool get isProblem => kind == 'PROBLEM';

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id'] as int,
    kind: json['kind'] as String? ?? 'SUPPORT',
    category: json['category'] as String? ?? 'OTHER',
    status: json['status'] as String? ?? 'OPEN',
    createdAt: parseServerTime(json['created_at'] as String),
    description: json['description'] as String?,
    reply: json['reply'] as String?,
    repliedAt: json['replied_at'] == null
        ? null
        : parseServerTime(json['replied_at'] as String),
  );
}

class SupportRepository {
  SupportRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Le système du téléphone, en un mot (« android », « ios »).
  static String get platform => defaultTargetPlatform.name;

  Future<SupportTicket> create({
    required String kind,
    required String description,
    String category = 'OTHER',
    int? screenshotMediaId,
  }) async {
    final response = await _api.post(
      '/support/tickets',
      body: {
        'kind': kind,
        'category': category,
        'description': description,
        if (_appVersion.isNotEmpty) 'app_version': _appVersion,
        'platform': platform,
        'screenshot_media_id': ?screenshotMediaId,
      },
    );
    return SupportTicket.fromJson(response as Map<String, dynamic>);
  }

  Future<List<SupportTicket>> mine() async {
    final response = await _api.get('/support/tickets');
    final items = ((response as Map<String, dynamic>)['items'] as List)
        .cast<Map<String, dynamic>>();
    return items.map(SupportTicket.fromJson).toList();
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(apiClient: ref.watch(apiClientProvider));
});

/// MES demandes, la plus récente d'abord.
final mySupportTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicket>>((ref) {
      return ref.watch(supportRepositoryProvider).mine();
    });
