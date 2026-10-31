import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_harness.dart';
import 'package:pokou/features/messaging/presentation/link_preview_card.dart';

class _FakeRepository implements LinkPreviewRepository {
  _FakeRepository(this._result);

  final Future<LinkPreview> Function(String url) _result;

  @override
  Future<LinkPreview> fetch(String url) => _result(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child, LinkPreviewRepository repository) {
  return ProviderScope(
    overrides: [linkPreviewRepositoryProvider.overrideWithValue(repository)],
    child: localizedHarness(child),
  );
}

void main() {
  testWidgets('affiche le titre et la description une fois récupérés', (tester) async {
    final repository = _FakeRepository(
      (url) async => LinkPreview(url: url, title: 'Super article', description: 'Un aperçu', image: null),
    );
    await tester.pumpWidget(_wrap(const LinkPreviewCard(url: 'https://exemple.com'), repository));
    await tester.pumpAndSettle();

    expect(find.text('Super article'), findsOneWidget);
    expect(find.text('Un aperçu'), findsOneWidget);
  });

  testWidgets('reste invisible (pas d\'erreur affichée) quand la récupération échoue', (tester) async {
    final repository = _FakeRepository((url) async => throw Exception('réseau indisponible'));
    await tester.pumpWidget(_wrap(const LinkPreviewCard(url: 'https://mort.example'), repository));
    await tester.pumpAndSettle();

    // Aucun texte d'erreur, aucune carte — juste rien, comme documenté.
    expect(find.byType(Container), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reste invisible quand la réponse ne contient aucun champ exploitable', (tester) async {
    final repository = _FakeRepository(
      (url) async => LinkPreview(url: url, title: null, description: null, image: null),
    );
    await tester.pumpWidget(_wrap(const LinkPreviewCard(url: 'https://vide.example'), repository));
    await tester.pumpAndSettle();

    expect(find.byType(Container), findsNothing);
  });
}
