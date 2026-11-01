import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/time/server_time.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';

/// Un message envoyé à 12 h UTC (12 h à Lomé) doit s'afficher 13 h à Paris
/// en hiver : l'heure du serveur, sans indicateur, est UTC.
void main() {
  test('une heure du serveur sans fuseau est lue comme UTC, rendue en local', () {
    final at = parseServerTime('2026-11-01T12:00:00');
    expect(at.isUtc, isFalse);
    expect(at.toUtc(), DateTime.utc(2026, 11, 1, 12));
    expect(at, DateTime.utc(2026, 11, 1, 12).toLocal());
  });

  test('une heure qui porte son fuseau est respectée', () {
    expect(parseServerTime('2026-11-01T12:00:00Z').toUtc(), DateTime.utc(2026, 11, 1, 12));
    expect(parseServerTime('2026-11-01T13:00:00+01:00').toUtc(), DateTime.utc(2026, 11, 1, 12));
  });

  test('une date seule reste un jour du calendrier', () {
    expect(parseServerTime('2026-11-01'), DateTime(2026, 11, 1));
  });

  test('valeur absente ou illisible', () {
    expect(tryParseServerTime(null), isNull);
    expect(tryParseServerTime(''), isNull);
    expect(tryParseServerTime('pas une date'), isNull);
  });

  test('le paramètre envoyé au serveur est en UTC, sans indicateur', () {
    expect(toServerTime(DateTime.utc(2026, 11, 1, 12)), '2026-11-01T12:00:00.000');
  });

  test("un message garde le même instant à l'aller-retour du cache", () {
    final message = DirectMessage.fromJson({
      'id': 'm1',
      'sender_id': 1,
      'recipient_id': 2,
      'message_type': 'TEXT',
      'content': 'Bonjour',
      'status': 'SENT',
      'created_at': '2026-11-01T12:00:00',
    });
    expect(message.createdAt.toUtc(), DateTime.utc(2026, 11, 1, 12));
    final cached = DirectMessage.fromJson(message.toJson(), fromCache: true);
    expect(cached.createdAt.toUtc(), DateTime.utc(2026, 11, 1, 12));
  });
}
