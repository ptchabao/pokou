import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/providers.dart';

import '../../helpers/localized_harness.dart';
import 'package:pokou/features/messaging/presentation/location_bubble.dart';
import 'package:pokou/core/time/server_time.dart';

/// Le serveur traduit la position en nom de lieu.
class _GeoApi extends ApiClient {
  _GeoApi() : super(baseUrl: 'https://unused');

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) async =>
      {'label': 'Bè, Lomé'};
}

Widget _wrap(Widget child) => ProviderScope(
  overrides: [apiClientProvider.overrideWithValue(_GeoApi())],
  child: localizedHarness(child),
);

void main() {
  testWidgets('affiche l\'étiquette, le lieu (jamais les coordonnées) et le bouton Maps', (tester) async {
    await tester.pumpWidget(_wrap(const LocationBubble(
      payload: {'latitude': 6.1319, 'longitude': 1.2228, 'label': 'Grand marché', 'live_until': null},
    )));
    await tester.pump();

    expect(find.text('Grand marché'), findsOneWidget);
    expect(find.text('Bè, Lomé'), findsOneWidget);
    expect(find.textContaining('6.13'), findsNothing);
    expect(find.text('Ouvrir dans Maps'), findsOneWidget);
    expect(find.textContaining('En direct'), findsNothing);
  });

  testWidgets('affiche le badge "En direct" quand live_until est dans le futur', (tester) async {
    // Comme le serveur l'écrit : UTC, sans indicateur de fuseau.
    final liveUntil = toServerTime(DateTime.now().add(const Duration(hours: 2)));
    await tester.pumpWidget(_wrap(LocationBubble(
      payload: {'latitude': 6.1319, 'longitude': 1.2228, 'label': null, 'live_until': liveUntil},
    )));

    expect(find.textContaining('En direct'), findsOneWidget);
  });

  testWidgets('ne montre pas "En direct" quand live_until est déjà passé', (tester) async {
    final expired = toServerTime(DateTime.now().subtract(const Duration(minutes: 5)));
    await tester.pumpWidget(_wrap(LocationBubble(
      payload: {'latitude': 6.1319, 'longitude': 1.2228, 'label': null, 'live_until': expired},
    )));

    expect(find.textContaining('En direct'), findsNothing);
  });
}
