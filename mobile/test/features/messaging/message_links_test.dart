import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/messaging/presentation/contact_card_bubble.dart';
import 'package:pokou/l10n/app_localizations.dart';
import 'package:pokou/features/messaging/presentation/message_links.dart';

List<(MessageLinkKind, String)> _found(String text) => [
  for (final l in findMessageLinks(text)) (l.kind, l.value),
];

void main() {
  test('un lien, sans la ponctuation qui le suit', () {
    expect(_found('Regarde https://pokou.app/k/AB12, c’est ici.'), [
      (MessageLinkKind.url, 'https://pokou.app/k/AB12'),
    ]);
    expect(_found('www.exemple.tg.'), [
      (MessageLinkKind.url, 'www.exemple.tg'),
    ]);
  });

  test('les codes USSD des opérateurs', () {
    expect(_found('Fais *144# puis *155*1*1#'), [
      (MessageLinkKind.ussd, '*144#'),
      (MessageLinkKind.ussd, '*155*1*1#'),
    ]);
    expect(_found('Ton solde : #100#'), [(MessageLinkKind.ussd, '#100#')]);
  });

  test('un numéro, une adresse e-mail', () {
    expect(_found('Appelle le +228 90 12 34 56 ou écris à awa@pokou.app'), [
      (MessageLinkKind.phone, '+228 90 12 34 56'),
      (MessageLinkKind.email, 'awa@pokou.app'),
    ]);
  });

  test('un numéro dans un lien reste dans le lien', () {
    expect(_found('https://wa.me/22890123456'), [
      (MessageLinkKind.url, 'https://wa.me/22890123456'),
    ]);
  });

  test('le # d’un code USSD est encodé pour le composeur', () {
    expect(ussdUri('*144*2#').toString(), 'tel:*144*2%23');
  });

  gestures();
}

// ── Gestes ──────────────────────────────────────────────────────────────

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  locale: const Locale('fr'),
  home: Scaffold(body: Center(child: child)),
);

void gestures() {
  testWidgets('appui long sur un numéro de profil : copié', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await tester.pumpWidget(_app(const CopyablePhone(phone: '+22890123456')));
    await tester.longPress(find.text('+22890123456'));
    await tester.pump();
    expect(copied, '+22890123456');
    expect(find.text('Copié'), findsOneWidget);
  });

  testWidgets('toucher un code USSD dans une bulle ouvre ses gestes, même '
      'sous le geste d’appui long de la bulle', (tester) async {
    await tester.pumpWidget(
      _app(
        GestureDetector(
          onLongPress: () {},
          onHorizontalDragEnd: (_) {},
          child: const LinkifiedText(
            text: 'Paie avec *144#',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('*144#'));
    await tester.pumpAndSettle();
    expect(find.text('Composer ce code'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
  });
}
