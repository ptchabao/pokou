import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_harness.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';
import 'package:pokou/features/messaging/presentation/bubble_widgets.dart';

Widget _wrap(Widget child) => localizedHarness(child);

void main() {
  group('ReplyPreviewBanner', () {
    testWidgets('affiche le nom fourni par l\'appelant et le contenu cité', (tester) async {
      await tester.pumpWidget(_wrap(ReplyPreviewBanner(
        preview: const MessageReplyPreview(
          id: 'q1',
          senderId: 2,
          messageType: 'TEXT',
          content: 'combien pour 50 sacs ?',
        ),
        senderLabel: 'Vous',
        isMine: true,
      )));

      expect(find.text('Vous'), findsOneWidget);
      expect(find.text('combien pour 50 sacs ?'), findsOneWidget);
    });

    testWidgets('un message cité sans contenu affiche un libellé de type', (tester) async {
      await tester.pumpWidget(_wrap(ReplyPreviewBanner(
        preview: const MessageReplyPreview(id: 'q1', senderId: 2, messageType: 'IMAGE', content: null),
        senderLabel: 'Bob',
        isMine: false,
      )));

      expect(find.textContaining('Photo'), findsOneWidget);
    });

    testWidgets('le tap déclenche le callback fourni', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(ReplyPreviewBanner(
        preview: const MessageReplyPreview(id: 'q1', senderId: 2, messageType: 'TEXT', content: 'salut'),
        senderLabel: 'Bob',
        isMine: false,
        onTap: () => tapped = true,
      )));

      await tester.tap(find.byType(ReplyPreviewBanner));
      expect(tapped, isTrue);
    });
  });

  group('ReactionPillRow', () {
    testWidgets('affiche un émoji par réaction et le compteur au-delà de 1', (tester) async {
      await tester.pumpWidget(_wrap(const ReactionPillRow(reactions: [
        MessageReactionSummary(emoji: '👍', count: 3, userIds: [1, 2, 3], mine: true),
        MessageReactionSummary(emoji: '❤️', count: 1, userIds: [4], mine: false),
      ])));

      expect(find.text('👍'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
      // Une seule personne : pas de compteur affiché à côté de l'émoji.
      expect(find.text('1'), findsNothing);
    });

    testWidgets('toucher une pastille bascule cette réaction', (tester) async {
      String? tapped;
      await tester.pumpWidget(_wrap(ReactionPillRow(
        reactions: const [MessageReactionSummary(emoji: '👍', count: 1, userIds: [1], mine: true)],
        onTap: (emoji) => tapped = emoji,
      )));

      await tester.tap(find.text('👍'));
      expect(tapped, '👍');
    });

    testWidgets('rien à afficher quand il n\'y a aucune réaction', (tester) async {
      await tester.pumpWidget(_wrap(const ReactionPillRow(reactions: [])));
      expect(find.byType(Wrap), findsNothing);
    });
  });

  group('EditedLabel', () {
    testWidgets('affiche le libellé "modifié"', (tester) async {
      await tester.pumpWidget(_wrap(const EditedLabel(color: Colors.black)));
      expect(find.textContaining('modifié'), findsOneWidget);
    });
  });
}
