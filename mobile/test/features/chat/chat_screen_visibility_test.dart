import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/mahizu/mahizu_session.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:pokou/l10n/app_localizations.dart';
import 'package:pokou/l10n/app_localizations_fr.dart';
import 'package:pokou/features/chat/data/chat_message_model.dart';
import 'package:pokou/features/chat/data/chat_repository.dart';
import 'package:pokou/features/chat/data/minou_repository.dart';
import 'package:pokou/features/chat/presentation/chat_controller.dart';
import 'package:pokou/features/chat/presentation/ai_style.dart';
import 'package:pokou/features/chat/presentation/chat_screen.dart';

/// Cet écran a été conçu sur fond SOMBRE puis passé en fond blanc. Les textes
/// restés en `Colors.white` sont alors devenus invisibles — dont le champ de
/// saisie : on tapait un message qu'on ne voyait qu'au moment de son envoi,
/// dans la bulle. Ces tests interdisent le retour de cette classe de bug :
/// un texte ne doit jamais avoir la couleur de la surface qui le porte.
class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ChatMessage>> loadHistory(int monitorId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMinouRepository implements MinouRepository {
  @override
  Future<MinouThread> thread({int limit = 50}) async =>
      const MinouThread(mode: MinouMode.messaging, items: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      // Un compte Mahizu rattaché : sans lui, l'écran montre le panneau de
      // connexion et non la conversation qu'on teste ici.
      mahizuSessionProvider.overrideWith(
        (ref) => MahizuSessionController(
          ApiClient(baseUrl: 'https://mahizu.test/api/v1'),
          SecureTokenStorage(namespace: 'test'),
          initial: const MahizuLinkState(MahizuLinkStatus.connected),
        ),
      ),
      chatControllerProvider(kNoMonitor).overrideWith(
        (ref) => ChatController(
          _FakeChatRepository(),
          _FakeMinouRepository(),
          kNoMonitor,
          LFr(),
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      locale: const Locale('fr'),
      home: const ChatScreen(monitorId: kNoMonitor, contactName: 'Minou'),
    ),
  );
}

/// Deux couleurs sont-elles assez distinctes pour que l'une se lise sur
/// l'autre ? Test volontairement grossier (écart de luminance) : il ne juge
/// pas l'esthétique, il attrape le blanc-sur-blanc.
void _expectReadable(Color foreground, Color background, String what) {
  final contrast =
      (foreground.computeLuminance() - background.computeLuminance()).abs();
  expect(
    contrast,
    greaterThan(0.2),
    reason:
        '$what : ${foreground.toARGB32().toRadixString(16)} sur '
        '${background.toARGB32().toRadixString(16)} — illisible',
  );
}

void main() {
  testWidgets('ce qu\'on tape est visible avant l\'envoi', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    final textColor = field.style?.color;
    expect(
      textColor,
      isNotNull,
      reason: 'le champ doit fixer sa couleur de texte',
    );
    // Le composeur est posé sur la surface de l'assistant — c'est CETTE
    // surface qui compte, pas le fond de l'écran.
    final style = AiStyle.of(tester.element(find.byType(ChatScreen)));
    _expectReadable(textColor!, style.surface, 'texte saisi');

    // Et la frappe arrive bien dans le champ (le bug était visuel, mais
    // c'est la promesse complète : je tape, je vois).
    await tester.enterText(find.byType(TextField), 'Bonjour Minou');
    expect(find.text('Bonjour Minou'), findsOneWidget);
  });

  testWidgets('le titre et l\'accueil de la conversation sont lisibles', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    final style = AiStyle.of(tester.element(find.byType(ChatScreen)));

    // L'accueil, affiché tant que la conversation est vide, sur le fond de
    // l'écran.
    // Toujours Baba, avec son badge — pas le nom du moniteur ouvert.
    final title = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.textSpan?.toPlainText() ?? w.data ?? '').contains(
              'Bonjour, je suis Baba',
            ),
      ),
    );
    _expectReadable(title.style!.color!, style.background, 'accueil');
    final subtitle = tester.widget<Text>(
      find.text('Votre partenaire numérique'),
    );
    _expectReadable(subtitle.style!.color!, style.background, 'sous-titre');
  });
}
