import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_harness.dart';
import 'package:pokou/features/messaging/presentation/location_bubble.dart';

Widget _wrap(Widget child) => localizedHarness(child);

void main() {
  testWidgets('affiche l\'étiquette, les coordonnées et le bouton Maps', (tester) async {
    await tester.pumpWidget(_wrap(const LocationBubble(
      payload: {'latitude': 6.1319, 'longitude': 1.2228, 'label': 'Grand marché', 'live_until': null},
    )));

    expect(find.text('Grand marché'), findsOneWidget);
    expect(find.text('6.13190, 1.22280'), findsOneWidget);
    expect(find.text('Ouvrir dans Maps'), findsOneWidget);
    expect(find.textContaining('En direct'), findsNothing);
  });

  testWidgets('affiche le badge "En direct" quand live_until est dans le futur', (tester) async {
    final liveUntil = DateTime.now().add(const Duration(hours: 2)).toIso8601String();
    await tester.pumpWidget(_wrap(LocationBubble(
      payload: {'latitude': 6.1319, 'longitude': 1.2228, 'label': null, 'live_until': liveUntil},
    )));

    expect(find.textContaining('En direct'), findsOneWidget);
  });

  testWidgets('ne montre pas "En direct" quand live_until est déjà passé', (tester) async {
    final expired = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
    await tester.pumpWidget(_wrap(LocationBubble(
      payload: {'latitude': 6.1319, 'longitude': 1.2228, 'label': null, 'live_until': expired},
    )));

    expect(find.textContaining('En direct'), findsNothing);
  });
}
