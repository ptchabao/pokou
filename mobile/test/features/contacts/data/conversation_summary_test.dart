import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/l10n/app_localizations_fr.dart';
import 'package:pokou/features/contacts/data/conversation_summary.dart';

void main() {
  // Les libellés de repli viennent des traductions : on lit le français,
  // la langue de ces assertions.
  final l = LFr();
  group('ConversationSummary.fromJson', () {
    test(
      'lit une ligne de contact connu, telle que renvoyée par GET /conversations',
      () {
        final summary = ConversationSummary.fromJson({
          'kind': 'contact',
          'id': 12,
          'contact_user_id': 42,
          'name': 'Ama',
          'avatar': null,
          'is_pinned': true,
          'is_muted': false,
          'muted_until': null,
          'is_archived': false,
          'last_message': {
            'id': 'msg-1',
            'message_type': 'TEXT',
            'content': 'On se voit demain ?',
            'created_at': '2026-09-04T10:00:00',
            'sender_id': 42,
            'sender_name': null,
            'is_mine': false,
          },
          'unread_count': 3,
        });

        expect(summary.kind, 'contact');
        expect(summary.id, 12);
        expect(summary.contactUserId, 42);
        expect(summary.isPinned, isTrue);
        expect(summary.isUnknownContact, isFalse);
        expect(summary.unreadCount, 3);
        expect(summary.lastMessage!.displayTextOf(l), 'On se voit demain ?');
      },
    );

    test(
      'lit un inconnu qui a écrit sans figurer dans mon carnet (id null)',
      () {
        // Le cas central du correctif « façon WhatsApp » : pas de ligne
        // Contact de mon côté, donc `id` est absent côté serveur.
        final summary = ConversationSummary.fromJson({
          'kind': 'contact',
          'id': null,
          'contact_user_id': 99,
          'is_unknown_contact': true,
          'name': '+22890000000',
          'is_pinned': false,
          'is_muted': false,
          'is_archived': false,
          'last_message': {
            'id': 'msg-2',
            'message_type': 'TEXT',
            'content': 'Salut, on se connaît ?',
            'created_at': '2026-09-04T09:00:00',
            'sender_id': 99,
            'sender_name': null,
            'is_mine': false,
          },
          'unread_count': 1,
        });

        expect(summary.id, isNull);
        expect(summary.isUnknownContact, isTrue);
        expect(summary.contactUserId, 99);
      },
    );

    test(
      'un groupe sans message garde un last_message nul, pas une exception',
      () {
        final summary = ConversationSummary.fromJson({
          'kind': 'group',
          'id': 7,
          'name': 'Chantier',
          'is_pinned': false,
          'is_muted': false,
          'is_archived': false,
          'last_message': null,
          'unread_count': 0,
        });

        expect(summary.kind, 'group');
        expect(summary.lastMessage, isNull);
      },
    );
  });

  group('ConversationPreview.displayTextOf(l)', () {
    test(
      'un média sans légende affiche ce que c\'est, jamais une ligne vide',
      () {
        final preview = ConversationPreview.fromJson({
          'id': 'msg-3',
          'message_type': 'IMAGE',
          'content': null,
          'created_at': '2026-09-04T09:00:00',
          'sender_id': 1,
          'sender_name': null,
          'is_mine': true,
        });
        expect(preview.displayTextOf(l), 'Photo');
      },
    );

    test('un texte présent prime toujours sur le libellé de type', () {
      final preview = ConversationPreview.fromJson({
        'id': 'msg-4',
        'message_type': 'IMAGE',
        'content': 'regarde ça',
        'created_at': '2026-09-04T09:00:00',
        'sender_id': 1,
        'sender_name': null,
        'is_mine': true,
      });
      expect(preview.displayTextOf(l), 'regarde ça');
    });
  });

  group('Aperçus chiffrés', _encryptedPreviewSuite);
}

/// Aperçus de conversations chiffrées — la régression la plus visible que le
/// chiffrement pouvait introduire, et la plus facile à ne pas voir en test :
/// tout fonctionne, seule la liste d'accueil se vide.
void _encryptedPreviewSuite() {
  final l = LFr();
  ConversationPreview preview({
    required bool encrypted,
    String? content,
    String type = 'TEXT',
  }) {
    return ConversationPreview.fromJson({
      'id': 'm1',
      'message_type': type,
      'content': content,
      'encrypted': encrypted,
      'created_at': '2026-09-15T10:00:00',
      'sender_id': 1,
      'sender_name': 'Awa',
      'is_mine': false,
    });
  }

  test('un aperçu chiffré affiche le clair retrouvé dans le cache local', () {
    final p = preview(encrypted: true)..localContent = 'Arrivage demain';
    expect(p.displayTextOf(l), 'Arrivage demain');
  });

  test("sans cache, il dit ce que c'est plutôt que de rester vide", () {
    // Message reçu pendant que l'application était fermée : rien à
    // déchiffrer encore. Une ligne blanche donnerait l'impression que la
    // conversation est cassée.
    expect(preview(encrypted: true).displayTextOf(l), 'Message');
  });

  test('un média chiffré garde son libellé de type', () {
    expect(preview(encrypted: true, type: 'AUDIO').displayTextOf(l), 'Note vocale');
  });

  test("un message en clair n'est pas affecté", () {
    expect(
      preview(encrypted: false, content: 'Bonjour').displayTextOf(l),
      'Bonjour',
    );
  });
}
