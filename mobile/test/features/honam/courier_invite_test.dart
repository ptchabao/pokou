import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/notifications/message_notifications.dart';
import 'package:pokou/features/contacts/data/contact_model.dart';
import 'package:pokou/features/contacts/data/conversation_summary.dart';
import 'package:pokou/features/contacts/presentation/contacts_controller.dart';
import 'package:pokou/features/honam/data/courier_invite_message.dart';
import 'package:pokou/features/honam/data/honam_models.dart';
import 'package:pokou/features/honam/presentation/courier_invite_card.dart';
import 'package:pokou/features/honam/presentation/courier_join_screen.dart';
import 'package:pokou/features/honam/presentation/courier_screen.dart';
import 'package:pokou/l10n/app_localizations.dart';
import 'package:pokou/l10n/app_localizations_fr.dart';

const _offer = CourierOffer(
  honamOpen: true,
  servedCities: ['Lomé'],
  trialRides: 5,
  membershipPriceTtc: 5900,
  packs: [],
  giftRides: 2,
  deliveryPrice: 1000,
  inviterName: 'Kodjo A.',
  inviterCode: 'KODJO7',
  inviterVerified: true,
);

Widget _app(Widget child, {List<PokouContact> contacts = const []}) =>
    ProviderScope(
      overrides: [
        courierOfferProvider.overrideWith((ref, code) async => _offer),
        contactsProvider.overrideWith((ref) => Stream.value(contacts)),
      ],
      child: MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(body: child),
      ),
    );

void main() {
  final l = LFr();

  group('message d’invitation coursier', () {
    test('le code et le message font l’aller-retour, sans le lien', () {
      final sent = encodeCourierInvite(
        title: l.courierInviteCardLabel,
        code: 'KODJO7',
        text: 'Salut Komi !\nRejoins-moi.',
      );
      expect(sent, contains(courierInviteLink('KODJO7')));
      final decoded = decodeCourierInvite(sent);
      expect(decoded?.code, 'KODJO7');
      expect(decoded?.text, 'Salut Komi !\nRejoins-moi.');
    });

    test('un message ordinaire n’est pas une invitation', () {
      expect(decodeCourierInvite('Bonjour'), isNull);
      expect(decodeCourierInvite('🛵 Invitation · KODJO7\nSalut'), isNull);
      expect(decodeCourierInvite(null), isNull);
    });

    test('la liste et les notifications montrent la carte', () {
      final sent = encodeCourierInvite(
        title: l.courierInviteCardLabel,
        code: 'KODJO7',
        text: 'Salut !',
      );
      final preview = ConversationPreview(
        messageId: 'm1',
        messageType: 'TEXT',
        content: sent,
        createdAt: DateTime(2026, 11, 16),
        senderId: 2,
        senderName: 'Kodjo A.',
        isMine: false,
      );
      expect(preview.displayTextOf(l), '🛵 Invitation coursier Honam');
      expect(
        messagePreviewLabel(l, 'TEXT', sent),
        '🛵 Invitation coursier Honam',
      );
      expect(messagePreviewLabel(l, 'TEXT', 'Bonjour'), 'Bonjour');
    });
  });

  testWidgets('Coursiers 24 · la carte reçue propose « Voir l’offre »', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CourierInviteCard(
          code: 'KODJO7',
          contactName: 'Kodjo A.',
          isMine: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invitation coursier Honam'), findsOneWidget);
    expect(find.text('Kodjo A. t’invite à livrer pour Honam'), findsOneWidget);
    expect(find.textContaining('Lomé · code KODJO7'), findsOneWidget);
    expect(find.text('Voir l’offre'), findsOneWidget);
  });

  testWidgets('la carte envoyée n’a pas de bouton', (tester) async {
    await tester.pumpWidget(
      _app(
        const CourierInviteCard(
          code: 'KODJO7',
          contactName: 'Komi',
          isMine: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tu invites Komi à livrer pour Honam'), findsOneWidget);
    expect(find.text('Voir l’offre'), findsNothing);
  });

  testWidgets(
    'Coursiers 23 · cocher un contact adapte le bouton et le message',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const CourierInviteFriendScreen(code: 'KODJO7', giftRides: 2),
          contacts: const [
            PokouContact(
              id: 1,
              phone: '+22890000001',
              displayName: 'Komi A.',
              contactUserId: 11,
              isRegistered: true,
            ),
            PokouContact(
              id: 2,
              phone: '+22890000002',
              displayName: 'Séna D.',
              isRegistered: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sur Pokou'), findsOneWidget);
      expect(
        find.text('Pas encore sur Pokou · invitation par SMS'),
        findsOneWidget,
      );
      expect(find.text('Envoyer l’invitation'), findsOneWidget);
      expect(
        find.text(
          'La carte « Devenir coursier Honam » est ajoutée au message.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Komi A.'));
      await tester.pumpAndSettle();
      expect(find.text('Envoyer à Komi'), findsOneWidget);
      expect(find.textContaining('Salut Komi !'), findsOneWidget);

      await tester.tap(find.text('Séna D.'));
      await tester.pumpAndSettle();
      expect(find.text('Envoyer à 2 contacts'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Sén');
      await tester.pumpAndSettle();
      expect(find.text('Komi A.'), findsNothing);
      expect(find.text('Séna D.'), findsOneWidget);
    },
  );

  testWidgets('Coursiers 25 · l’ami invité voit les trois avantages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const CourierOfferScreen(referralCode: 'KODJO7')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invité par Kodjo A.'), findsOneWidget);
    expect(
      find.text('Coursier vérifié · code KODJO7 appliqué'),
      findsOneWidget,
    );
    expect(find.text('5 courses d’essai offertes'), findsOneWidget);
    expect(find.text('Des premières courses simples'), findsOneWidget);
    expect(find.text('Kodjo t’a recommandé'), findsOneWidget);
    expect(find.text('Je deviens coursier'), findsOneWidget);
  });
}
