import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';
import 'package:pokou/features/messaging/presentation/messaging_controller.dart';

void main() {
  group('DirectMessage.fromJson', () {
    test('parses each status value', () {
      Map<String, dynamic> json(String status) => {
            'id': 'abc',
            'sender_id': 1,
            'recipient_id': 2,
            'message_type': 'TEXT',
            'content': 'salut',
            'status': status,
            'created_at': '2026-08-06T10:00:00',
          };

      expect(DirectMessage.fromJson(json('SENT')).status, DirectMessageStatus.sent);
      expect(DirectMessage.fromJson(json('DELIVERED')).status, DirectMessageStatus.delivered);
      expect(DirectMessage.fromJson(json('READ')).status, DirectMessageStatus.read);
    });

    test('content can be null (media message placeholder)', () {
      final message = DirectMessage.fromJson({
        'id': 'abc',
        'sender_id': 1,
        'recipient_id': 2,
        'message_type': 'TEXT',
        'content': null,
        'status': 'SENT',
        'created_at': '2026-08-06T10:00:00',
      });
      expect(message.content, isNull);
    });

    test('parses a media message with nested media metadata', () {
      final message = DirectMessage.fromJson({
        'id': 'abc',
        'sender_id': 1,
        'recipient_id': 2,
        'message_type': 'DOCUMENT',
        'content': null,
        'media_asset_id': 42,
        'media': {
          'id': 42,
          'mime_type': 'application/pdf',
          'size_bytes': 2048,
          'original_filename': 'facture.pdf',
        },
        'status': 'SENT',
        'created_at': '2026-08-06T10:00:00',
      });

      expect(message.isMedia, isTrue);
      expect(message.media?.id, 42);
      expect(message.media?.originalFilename, 'facture.pdf');
      expect(message.media?.sizeBytes, 2048);
    });

    test('media is null and isMedia is false for a plain text message', () {
      final message = DirectMessage.fromJson({
        'id': 'abc',
        'sender_id': 1,
        'recipient_id': 2,
        'message_type': 'TEXT',
        'content': 'salut',
        'status': 'SENT',
        'created_at': '2026-08-06T10:00:00',
      });

      expect(message.isMedia, isFalse);
      expect(message.media, isNull);
    });
  });

  group('DirectMessage.fromJson — contenus riches', () {
    Map<String, dynamic> baseJson(Map<String, dynamic> extra) => {
          'id': 'abc',
          'sender_id': 1,
          'recipient_id': 2,
          'message_type': 'TEXT',
          'content': 'salut',
          'status': 'SENT',
          'created_at': '2026-08-06T10:00:00',
          ...extra,
        };

    test('parses reply_to, reactions, edited_at, view_once/viewed_at', () {
      final message = DirectMessage.fromJson(baseJson({
        'reply_to_id': 'quoted-1',
        'reply_to': {
          'id': 'quoted-1',
          'sender_id': 2,
          'message_type': 'TEXT',
          'content': 'combien pour 50 sacs ?',
        },
        'reactions': [
          {'emoji': '👍', 'count': 2, 'user_ids': [1, 2], 'mine': true},
        ],
        'edited_at': '2026-08-06T10:05:00',
        'view_once': true,
        'viewed_at': '2026-08-06T10:10:00',
      }));

      expect(message.replyToId, 'quoted-1');
      expect(message.replyTo?.content, 'combien pour 50 sacs ?');
      expect(message.reactions, hasLength(1));
      expect(message.reactions.single.mine, isTrue);
      expect(message.isEdited, isTrue);
      expect(message.viewOnce, isTrue);
      expect(message.isViewed, isTrue);
    });

    test('reply_to/reactions/poll are absent by default (backward compatible)', () {
      final message = DirectMessage.fromJson(baseJson({}));
      expect(message.replyTo, isNull);
      expect(message.reactions, isEmpty);
      expect(message.isEdited, isFalse);
      expect(message.viewOnce, isFalse);
      expect(message.isViewed, isFalse);
      expect(message.payload, isNull);
      expect(message.poll, isNull);
    });

    test('parses a poll payload with vote counts', () {
      final message = DirectMessage.fromJson(baseJson({
        'message_type': 'POLL',
        'poll': {
          'id': 'poll-1',
          'question': 'On mange où ?',
          'allows_multiple': false,
          'options': [
            {'id': 1, 'text': 'Chez Fatou', 'position': 0, 'vote_count': 2, 'voters': [1, 2], 'mine': true},
            {'id': 2, 'text': 'À la maison', 'position': 1, 'vote_count': 0, 'voters': [], 'mine': false},
          ],
          'total_voters': 2,
        },
      }));

      expect(message.poll?.question, 'On mange où ?');
      expect(message.poll?.options.first.mine, isTrue);
      expect(message.poll?.totalVoters, 2);
    });

    test('parses a location payload', () {
      final message = DirectMessage.fromJson(baseJson({
        'message_type': 'LOCATION',
        'payload': {'latitude': 6.1319, 'longitude': 1.2228, 'label': 'Grand marché', 'live_until': null},
      }));

      expect(message.payload?['latitude'], 6.1319);
      expect(message.payload?['label'], 'Grand marché');
    });

    test('toJson/fromJson round-trips the new fields', () {
      final original = DirectMessage.fromJson(baseJson({
        'reactions': [
          {'emoji': '❤️', 'count': 1, 'user_ids': [1], 'mine': true},
        ],
        'edited_at': '2026-08-06T10:05:00',
      }));

      final restored = DirectMessage.fromJson(original.toJson());
      expect(restored.reactions.single.emoji, '❤️');
      expect(restored.editedAt, original.editedAt);
    });

    test('copyWith overrides only the given fields', () {
      final original = DirectMessage.fromJson(baseJson({}));
      final withReaction = original.copyWith(
        reactions: [const MessageReactionSummary(emoji: '👍', count: 1, userIds: [1], mine: true)],
      );
      expect(withReaction.reactions, hasLength(1));
      expect(withReaction.content, original.content);
      expect(withReaction.id, original.id);
    });
  });

  group('ConversationKey', () {
    test('two keys with the same ids are equal and hash the same', () {
      const a = ConversationKey(myUserId: 1, contactUserId: 2);
      const b = ConversationKey(myUserId: 1, contactUserId: 2);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('swapping ids produces a different key', () {
      const a = ConversationKey(myUserId: 1, contactUserId: 2);
      const b = ConversationKey(myUserId: 2, contactUserId: 1);
      expect(a == b, isFalse);
    });
  });

  group('Chiffrement — aller-retour par le cache', _encryptionRoundTripSuite);
}

/// L'aller-retour par le cache local, pour les champs de chiffrement.
///
/// Ce test existe parce que leur absence dans `toJson` a produit exactement
/// le symptôme qu'on cherchait à éviter : un message qui échoue au
/// déchiffrement est enregistré avec son texte d'erreur, et sans
/// `encryption` pour dire que ce n'est PAS un vrai contenu, il est relu
/// comme un message résolu. L'échec devient définitif, et il n'y a plus
/// aucun moyen de savoir que la bulle ment.
void _encryptionRoundTripSuite() {
  DirectMessage build({String? encryption, String? ciphertext, String? content}) {
    return DirectMessage.fromJson({
      'id': 'm1',
      'sender_id': 1,
      'recipient_id': 2,
      'message_type': 'TEXT',
      'content': content,
      'encryption': encryption,
      'ciphertext': ciphertext,
      'envelope': encryption == null ? null : {'v': 1, 'n': 0},
      'media_asset_id': null,
      'media': null,
      'status': 'SENT',
      'created_at': '2026-09-15T10:00:00',
    });
  }

  test('un message chiffré non résolu se relit comme chiffré', () {
    final stored = build(
      encryption: 'v1',
      ciphertext: 'Y2hpZmZyZQ==',
      content: '🔒 Message impossible à déchiffrer',
    );
    final reread = DirectMessage.fromJson(stored.toJson());

    expect(reread.isEncrypted, isTrue);
    expect(reread.ciphertext, 'Y2hpZmZyZQ==');
    expect(reread.envelope, isNotNull);
  });

  test('un message déchiffré se relit comme du clair ordinaire', () {
    final opened = build(encryption: 'v1', ciphertext: 'Y2hpZmZyZQ==')
        .copyWith(content: 'Arrivage demain', clearCiphertext: true);
    final reread = DirectMessage.fromJson(opened.toJson());

    expect(reread.isEncrypted, isFalse);
    expect(reread.content, 'Arrivage demain');
    expect(reread.ciphertext, isNull);
  });

  test("un message en clair n'acquiert pas de champs de chiffrement", () {
    final reread = DirectMessage.fromJson(build(content: 'Bonjour').toJson());
    expect(reread.isEncrypted, isFalse);
    expect(reread.content, 'Bonjour');
  });
}

