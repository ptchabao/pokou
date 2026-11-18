import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';

/// Messages épinglés en haut d'une discussion (à deux ou de groupe), comme
/// WhatsApp : visibles de TOUS les participants, au plus trois, chacun pour
/// 24 h, 7 jours ou 30 jours.
///
/// Le serveur ne connaît que des IDENTIFIANTS de messages : le contenu est
/// chiffré de bout en bout. L'extrait affiché dans le bandeau vient toujours
/// du message déjà déchiffré sur ce téléphone (voir PinnedMessagesBanner).

/// Durées proposées, en secondes — les mêmes que côté serveur
/// (`messages.py::PIN_DURATIONS`), qui refuse toute autre valeur.
const pinDurations = <int>[86400, 604800, 2592000];

/// Au-delà, le serveur remplace la plus ancienne épingle.
const maxPins = 3;

class MessagePin {
  const MessagePin({
    required this.messageId,
    required this.expiresAt,
    this.pinnedBy,
    this.pinnedAt,
  });

  factory MessagePin.fromJson(Map<String, dynamic> json) => MessagePin(
    messageId: json['message_id'] as String,
    pinnedBy: json['pinned_by'] as int?,
    pinnedAt: _date(json['pinned_at']),
    expiresAt: _date(json['expires_at']) ?? DateTime.utc(1970),
  );

  final String messageId;
  final int? pinnedBy;
  final DateTime? pinnedAt;
  final DateTime expiresAt;

  bool isActive(DateTime now) => expiresAt.isAfter(now);

  /// Le serveur écrit des dates UTC sans fuseau : sans le « Z », Dart les
  /// lirait comme locales et une épingle de 24 h finirait décalée.
  static DateTime? _date(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    final hasZone =
        raw.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(raw);
    return DateTime.tryParse(hasZone ? raw : '${raw}Z');
  }
}

List<MessagePin> pinsFromJson(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is Map<String, dynamic>) MessagePin.fromJson(item),
];

/// Une discussion : à deux (l'autre personne) ou un groupe.
class PinScope {
  const PinScope.direct(int contactUserId)
    : isGroup = false,
      id = contactUserId;
  const PinScope.group(int groupId) : isGroup = true, id = groupId;

  final bool isGroup;
  final int id;

  @override
  bool operator ==(Object other) =>
      other is PinScope && other.isGroup == isGroup && other.id == id;

  @override
  int get hashCode => Object.hash(isGroup, id);
}

/// Les routes d'épinglage. Une interface pour que le contrôleur se teste
/// sans réseau.
abstract class PinsApi {
  Future<List<MessagePin>> list(PinScope scope);
  Future<List<MessagePin>> pin(PinScope scope, String messageId, int seconds);
  Future<List<MessagePin>> unpin(PinScope scope, String messageId);
}

class HttpPinsApi implements PinsApi {
  HttpPinsApi(this._api);

  final ApiClient _api;

  String _messagePath(PinScope scope, String messageId) => scope.isGroup
      ? '/groups/${scope.id}/messages/$messageId/pin'
      : '/messages/$messageId/pin';

  List<MessagePin> _items(dynamic response) =>
      pinsFromJson((response as Map<String, dynamic>)['items']);

  @override
  Future<List<MessagePin>> list(PinScope scope) async => _items(
    await _api.get(
      scope.isGroup ? '/groups/${scope.id}/pins' : '/messages/${scope.id}/pins',
    ),
  );

  @override
  Future<List<MessagePin>> pin(
    PinScope scope,
    String messageId,
    int seconds,
  ) async => _items(
    await _api.put(
      _messagePath(scope, messageId),
      body: {'duration_seconds': seconds},
    ),
  );

  @override
  Future<List<MessagePin>> unpin(PinScope scope, String messageId) async =>
      _items(await _api.delete(_messagePath(scope, messageId)));
}

enum PinOutcome { done, forbidden, failed }

/// Les épingles d'une discussion, tenues à jour par le temps réel.
///
/// Le serveur pousse la liste ENTIÈRE à chaque changement
/// (`message:pinned` / `group:message:pinned`) : on la remplace telle
/// quelle, sans rien recalculer. Un message supprimé pour tous perd son
/// épingle ici aussi, sans attendre le prochain chargement.
class PinsController extends StateNotifier<List<MessagePin>> {
  PinsController({
    required this.scope,
    required PinsApi api,
    required Stream<Map<String, dynamic>> events,
    Stream<bool>? connectionChanges,
    DateTime Function()? clock,
  }) : _api = api,
       _clock = clock ?? DateTime.now,
       super(const []) {
    _events = events.listen(_onEvent);
    _connection = connectionChanges?.listen((connected) {
      if (connected) unawaited(refresh());
    });
    unawaited(refresh());
  }

  final PinScope scope;
  final PinsApi _api;
  final DateTime Function() _clock;
  late final StreamSubscription<Map<String, dynamic>> _events;
  StreamSubscription<bool>? _connection;

  /// Les épingles encore valables, la plus récente d'abord. L'échéance se
  /// filtre ici aussi : une discussion restée ouverte ne doit pas garder
  /// en haut un message dont l'épingle a expiré.
  List<MessagePin> get active {
    final now = _clock().toUtc();
    return [
      for (final pin in state)
        if (pin.isActive(now)) pin,
    ];
  }

  bool isPinned(String messageId) =>
      active.any((pin) => pin.messageId == messageId);

  Future<void> refresh() async {
    try {
      final pins = await _api.list(scope);
      if (mounted) state = pins;
    } catch (_) {
      // Hors ligne : on garde ce qu'on a. Le retour du réseau relira.
    }
  }

  Future<PinOutcome> pin(String messageId, int seconds) =>
      _apply(() => _api.pin(scope, messageId, seconds));

  Future<PinOutcome> unpin(String messageId) =>
      _apply(() => _api.unpin(scope, messageId));

  Future<PinOutcome> _apply(Future<List<MessagePin>> Function() call) async {
    try {
      final pins = await call();
      if (mounted) state = pins;
      return PinOutcome.done;
    } on ApiException catch (error) {
      return error.statusCode == 403 ? PinOutcome.forbidden : PinOutcome.failed;
    } catch (_) {
      return PinOutcome.failed;
    }
  }

  void _drop(String? messageId) {
    if (messageId == null) return;
    if (state.any((pin) => pin.messageId == messageId)) {
      state = [
        for (final pin in state)
          if (pin.messageId != messageId) pin,
      ];
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type'];
    if (scope.isGroup) {
      if (event['group_id'] != scope.id) return;
      switch (type) {
        case 'group:message:pinned':
          state = pinsFromJson(event['pins']);
        case 'group:message:deleted':
          _drop(event['message_id'] as String?);
        case 'group:message:edited':
          // Mode preuve : la suppression marque le message au lieu de
          // l'effacer, et arrive comme une modification.
          final message = event['message'];
          if (message is Map<String, dynamic> &&
              message['deleted_at'] != null) {
            _drop(message['id'] as String?);
          }
      }
      return;
    }
    switch (type) {
      case 'message:pinned':
        if (event['peer_id'] == scope.id) state = pinsFromJson(event['pins']);
      case 'message:deleted':
        // Identifiant unique : retirer l'épingle correspondante, s'il y en
        // a une, ne peut toucher aucune autre discussion.
        _drop(event['message_id'] as String?);
    }
  }

  @override
  void dispose() {
    _events.cancel();
    _connection?.cancel();
    super.dispose();
  }
}

final pinsApiProvider = Provider<PinsApi>(
  (ref) => HttpPinsApi(ref.watch(apiClientProvider)),
);

final pinsControllerProvider = StateNotifierProvider.autoDispose
    .family<PinsController, List<MessagePin>, PinScope>((ref, scope) {
      final ws = ref.watch(wsClientProvider);
      return PinsController(
        scope: scope,
        api: ref.watch(pinsApiProvider),
        events: ws.events,
        connectionChanges: ws.connectionChanges,
      );
    });
