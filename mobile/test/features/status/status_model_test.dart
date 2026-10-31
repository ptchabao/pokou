import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/status/data/status_model.dart';

void main() {
  group('PokouStatus.fromJson', () {
    test('parses a text status', () {
      final status = PokouStatus.fromJson({
        'id': 'abc',
        'user_id': 1,
        'content_type': 'TEXT',
        'text_content': 'Bonne journée !',
        'media': null,
        'created_at': '2026-08-12T10:00:00',
        'expires_at': '2026-08-13T10:00:00',
        'viewed_by_me': false,
        'view_count': 0,
      });

      expect(status.contentType, 'TEXT');
      expect(status.textContent, 'Bonne journée !');
      expect(status.media, isNull);
      expect(status.viewedByMe, isFalse);
      expect(status.viewCount, 0);
    });

    test('parses a media status with nested media metadata', () {
      final status = PokouStatus.fromJson({
        'id': 'abc',
        'user_id': 1,
        'content_type': 'IMAGE',
        'text_content': 'légende',
        'media': {'id': 7, 'mime_type': 'image/jpeg', 'size_bytes': 1024, 'original_filename': 'photo.jpg'},
        'created_at': '2026-08-12T10:00:00',
        'expires_at': '2026-08-13T10:00:00',
        'viewed_by_me': true,
        'view_count': 3,
      });

      expect(status.media?.id, 7);
      expect(status.media?.originalFilename, 'photo.jpg');
      expect(status.viewedByMe, isTrue);
      expect(status.viewCount, 3);
    });
  });

  group('StatusFeedItem', () {
    StatusFeedItem itemWith(List<bool> viewedFlags) {
      return StatusFeedItem(
        userId: 1,
        displayName: 'Alice',
        statuses: [
          for (final viewed in viewedFlags)
            PokouStatus(
              id: 'x',
              userId: 1,
              contentType: 'TEXT',
              textContent: 'salut',
              media: null,
              createdAt: DateTime(2026, 8, 12),
              expiresAt: DateTime(2026, 8, 13),
              viewedByMe: viewed,
              viewCount: 0,
            ),
        ],
      );
    }

    test('allViewed is true only when every status has been viewed', () {
      expect(itemWith([true, true]).allViewed, isTrue);
      expect(itemWith([true, false]).allViewed, isFalse);
      expect(itemWith([]).allViewed, isTrue); // vacuous truth, matches List.every semantics
    });

    test('fromJson parses a list of statuses for one author', () {
      final item = StatusFeedItem.fromJson({
        'user_id': 2,
        'display_name': 'Bob',
        'statuses': [
          {
            'id': 'a',
            'user_id': 2,
            'content_type': 'TEXT',
            'text_content': 'un',
            'media': null,
            'created_at': '2026-08-12T10:00:00',
            'expires_at': '2026-08-13T10:00:00',
            'viewed_by_me': false,
            'view_count': 0,
          },
        ],
      });

      expect(item.userId, 2);
      expect(item.displayName, 'Bob');
      expect(item.statuses, hasLength(1));
    });
  });
}
