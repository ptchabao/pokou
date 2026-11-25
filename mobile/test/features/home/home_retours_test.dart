import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/country/country_config.dart';
import 'package:pokou/features/contacts/data/conversation_summary.dart';
import 'package:pokou/features/contacts/presentation/discussions_controller.dart';
import 'package:pokou/features/home/data/home_banner.dart';
import 'package:pokou/features/home/presentation/home_screen.dart';
import 'package:pokou/features/notifications/data/service_notification.dart';
import 'package:pokou/features/notifications/presentation/notifications_center_screen.dart';

import '../../helpers/localized_harness.dart';

final _now = DateTime.now().toUtc();

ConversationSummary _chat(int id, String name, String text, {int unread = 0}) =>
    ConversationSummary.fromJson({
      'kind': 'contact',
      'id': id,
      'contact_user_id': 100 + id,
      'name': name,
      'unread_count': unread,
      'last_message': {
        'id': 'm$id',
        'content': text,
        'created_at': _now.subtract(Duration(minutes: id)).toIso8601String(),
        'sender_id': 100 + id,
      },
    });

Future<ProviderContainer> _pump(WidgetTester tester, {String? video}) async {
  final container = ProviderContainer(
    overrides: [
      currentCountryConfigProvider.overrideWithValue(
        CountryConfig(
          country: 'TG',
          modules: const {'assime'},
          discoverVideoUrl: video,
        ),
      ),
      discussionsProvider.overrideWith(
        (ref) => Stream.value([
          _chat(1, 'Ama', 'Je passe à 11 h', unread: 2),
          _chat(2, 'Kossi', 'D’accord pour 11 500'),
          _chat(3, 'Famille', 'Bonne fête'),
          _chat(4, 'Quatrième', 'Ne doit pas apparaître'),
        ]),
      ),
      serviceNotificationsProvider.overrideWith(
        (ref) async => const ServiceNotificationsPage(items: [], unread: 0),
      ),
      homeBannersProvider.overrideWith(
        (ref) => Stream.value(const <HomeBanner>[]),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedHarness(HomeScreen(onOpenTab: (_) {})),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('trois discussions, avec l’aperçu de leur dernier message', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Ama'), findsOneWidget);
    expect(find.text('Kossi'), findsOneWidget);
    expect(find.text('Famille'), findsOneWidget);
    expect(find.text('Quatrième'), findsNothing);
    expect(find.text('Je passe à 11 h'), findsOneWidget);
    // Sans vidéo réglée, pas d'entrée « Découvrir Pokou ».
    expect(find.text('Découvrir Pokou'), findsNothing);
  });

  testWidgets(
    'la pastille de non-lus disparaît une fois la discussion ouverte',
    (tester) async {
      final container = await _pump(tester);
      expect(find.text('2'), findsOneWidget);
      container.read(homeOpenedDiscussionsProvider.notifier).state = {
        'contact:101': DateTime.now().toUtc(),
      };
      await tester.pump();
      expect(find.text('2'), findsNothing);
    },
  );

  testWidgets('« Découvrir Pokou » apparaît quand la vidéo est réglée', (
    tester,
  ) async {
    await _pump(tester, video: 'https://youtu.be/presentation');
    await tester.scrollUntilVisible(find.text('Découvrir Pokou'), 200);
    expect(find.text('Découvrir Pokou'), findsOneWidget);
  });
}
