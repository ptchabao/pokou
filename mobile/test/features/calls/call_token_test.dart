import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/calls/data/call_repository.dart';

void main() {
  group('CallToken.fromJson', () {
    test('parses room, token and livekit_url', () {
      final callToken = CallToken.fromJson({
        'room': 'pokou-call-abc123',
        'token': 'jwt-token-value',
        'livekit_url': 'wss://example.livekit.cloud',
      });

      expect(callToken.room, 'pokou-call-abc123');
      expect(callToken.token, 'jwt-token-value');
      expect(callToken.livekitUrl, 'wss://example.livekit.cloud');
    });
  });

  group('CallLogEntry.fromJson', () {
    test('parses an outgoing ended call with duration and others', () {
      final entry = CallLogEntry.fromJson({
        'id': 'call-1',
        'direction': 'outgoing',
        'call_type': '1:1',
        'is_video': true,
        'status': 'ended',
        'created_at': '2026-08-13T10:00:00',
        'ended_at': '2026-08-13T10:05:00',
        'duration_seconds': 240,
        'others': [
          {'id': 7, 'display_name': 'Bob'},
        ],
      });

      expect(entry.direction, 'outgoing');
      expect(entry.status, 'ended');
      expect(entry.durationSeconds, 240);
      expect(entry.others, hasLength(1));
      expect(entry.others.first.displayName, 'Bob');
      expect(entry.isMissedOrDeclined, isFalse);
    });

    test('parses a missed incoming call with no duration', () {
      final entry = CallLogEntry.fromJson({
        'id': 'call-2',
        'direction': 'incoming',
        'call_type': '1:1',
        'is_video': false,
        'status': 'missed',
        'created_at': '2026-08-13T10:00:00',
        'ended_at': '2026-08-13T10:00:20',
        'duration_seconds': null,
        'others': [
          {'id': 3, 'display_name': 'Alice'},
        ],
      });

      expect(entry.durationSeconds, isNull);
      expect(entry.isMissedOrDeclined, isTrue);
    });
  });

  group('CallToken — appel de groupe', () {
    test('parses participant_ids and joined_existing', () {
      final callToken = CallToken.fromJson({
        'room': 'pokou-call-abc123',
        'token': 'jwt',
        'livekit_url': 'wss://example.livekit.cloud',
        'participant_ids': [2, 3, 4],
        'joined_existing': true,
      });

      expect(callToken.participantIds, [2, 3, 4]);
      expect(callToken.joinedExisting, isTrue);
    });

    test('older payloads without the group fields still parse', () {
      // Le champ manque pour un appel 1:1 servi par une version antérieure
      // de l'API — la valeur par défaut évite un crash au décrochage.
      final callToken = CallToken.fromJson({
        'room': 'pokou-call-abc123',
        'token': 'jwt',
        'livekit_url': 'wss://example.livekit.cloud',
      });

      expect(callToken.participantIds, isEmpty);
      expect(callToken.joinedExisting, isFalse);
    });
  });

  group('ActiveGroupCall.fromJson', () {
    test('returns null when no call is in progress', () {
      // L'absence d'appel est le cas NORMAL, pas une erreur.
      expect(ActiveGroupCall.fromJson({'active': false}), isNull);
    });

    test('parses the ongoing call', () {
      final call = ActiveGroupCall.fromJson({
        'active': true,
        'room': 'pokou-call-xyz',
        'is_video': false,
        'started_at': '2026-09-03T10:00:00',
        'caller_id': 7,
        'participant_ids': [8, 9],
      });

      expect(call, isNotNull);
      expect(call!.room, 'pokou-call-xyz');
      expect(call.isVideo, isFalse);
      expect(call.callerId, 7);
      expect(call.participantIds, [8, 9]);
    });
  });

  group('CallLogEntry — appel de groupe', () {
    test('carries the group name', () {
      final entry = CallLogEntry.fromJson({
        'id': 'call-9',
        'direction': 'outgoing',
        'call_type': 'group',
        'group_id': 3,
        'group_name': 'Dépôt Adidogomé',
        'is_video': false,
        'status': 'ended',
        'created_at': '2026-09-03T10:00:00',
        'ended_at': '2026-09-03T10:10:00',
        'duration_seconds': 600,
        'others': [
          {'id': 2, 'display_name': 'Ama'},
          {'id': 3, 'display_name': 'Yao'},
        ],
      });

      expect(entry.groupName, 'Dépôt Adidogomé');
      expect(entry.callType, 'group');
    });

    test('group_name is null for a 1:1 call', () {
      final entry = CallLogEntry.fromJson({
        'id': 'call-10',
        'direction': 'incoming',
        'call_type': '1:1',
        'is_video': true,
        'status': 'accepted',
        'created_at': '2026-09-03T10:00:00',
        'ended_at': null,
        'duration_seconds': null,
        'others': [
          {'id': 2, 'display_name': 'Ama'},
        ],
      });

      expect(entry.groupName, isNull);
    });
  });
}
