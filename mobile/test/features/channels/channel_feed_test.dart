import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/widgets/contact_avatar.dart';
import 'package:pokou/core/widgets/skeleton.dart';
import 'package:pokou/features/channels/data/channel_model.dart';
import 'package:pokou/features/channels/data/channel_repository.dart';
import 'package:pokou/features/channels/presentation/channel_avatar.dart';
import 'package:pokou/features/channels/presentation/channel_skeletons.dart';

Map<String, dynamic> _post(String id, String day) => {
      'id': id,
      'channel_id': 1,
      'author_id': 7,
      'author_name': 'Kodjo',
      'text_content': id,
      'created_at': '2026-09-${day}T10:00:00Z',
      'view_count': 0,
      'reactions': <dynamic>[],
    };

PokouChannel _channel({Map<String, dynamic>? avatar}) => PokouChannel.fromJson({
      'id': 1,
      'name': 'Marché de Lomé',
      'description': null,
      'avatar': avatar,
      'created_by': 7,
      'follower_count': 12,
      'is_verified': false,
    });

/// Un ApiClient qui ne sort pas de la machine : seule la forme de la réponse
/// nous intéresse ici.
class _FakeApi extends ApiClient {
  _FakeApi(this.items) : super(baseUrl: 'https://inutilise');

  final List<Map<String, dynamic>> items;

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) async =>
      {'items': items};
}

void main() {
  group('l\'ordre du fil', () {
    test('la plus ancienne en premier, la plus récente en dernier', () async {
      // Le serveur trie du plus RÉCENT au plus ancien — c'est ce qu'il faut
      // pour prendre les cinquante dernières, et ça n'a rien à voir avec
      // l'ordre de lecture. Une chaîne se lit comme une conversation.
      final repository = ChannelRepository(
        apiClient: _FakeApi([_post('recente', '20'), _post('ancienne', '18')]),
      );

      final posts = await repository.posts(1);

      expect(posts.map((p) => p.id), ['ancienne', 'recente']);
      expect(posts.last.createdAt.isAfter(posts.first.createdAt), isTrue);
    });

    test('un fil vide ne casse pas l\'inversion', () async {
      final repository = ChannelRepository(apiClient: _FakeApi([]));

      expect(await repository.posts(1), isEmpty);
    });
  });

  group('l\'image de la chaîne', () {
    testWidgets('sans image, un porte-voix — pas l\'initiale', (tester) async {
      // Une chaîne n'est pas une personne : son « M » ne dit rien, alors
      // qu'un porte-voix la distingue d'un contact dans une liste mêlée.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChannelAvatar(channel: _channel()))),
      );

      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
      expect(find.text('M'), findsNothing);
    });

    testWidgets('l\'image passe par ContactAvatar, qui la met en cache',
        (tester) async {
      // Le point important n'est pas le pixel affiché — il faut un fichier
      // sur le disque — mais le CHEMIN : les tuiles peignaient un porte-voix
      // en dur, sans jamais regarder `channel.avatar`. En passant par
      // ContactAvatar, l'image est résolue une fois et gardée dans son
      // `State` ; un `FutureBuilder` reconstruit à chaque `build()` repartait
      // de zéro et n'aboutissait jamais dans une liste qui défile.
      final channel = _channel(avatar: {
        'id': 42,
        'mime_type': 'image/jpeg',
        'size_bytes': 1024,
        'original_filename': 'logo.jpg',
      });

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChannelAvatar(channel: channel))),
      );

      final avatar = tester.widget<ContactAvatar>(find.byType(ContactAvatar));
      expect(avatar.avatar?.id, 42);
    });
  });

  group('les squelettes', () {
    testWidgets('la liste de chaînes a la forme d\'une liste de chaînes',
        (tester) async {
      // Un squelette qui ne ressemble pas à ce qu'il remplace ne vaut pas
      // mieux qu'un rond qui tourne : c'est la mise en page tenue d'avance
      // qui empêche le contenu de sauter à l'arrivée.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChannelListSkeleton(count: 3)),
        ),
      );

      expect(find.byType(SkeletonCircle), findsNWidgets(3));
      expect(find.byType(SkeletonBox), findsNWidgets(6));
    });

    testWidgets('« réduire les animations » fige la pulsation', (tester) async {
      // Sans ça, quelqu'un qui a demandé moins d'animations voit tout
      // l'écran palpiter pendant chaque chargement.
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: ChannelListSkeleton()),
          ),
        ),
      );

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(SkeletonPulse),
          matching: find.byType(FadeTransition),
        ),
      );
      final before = fade.opacity.value;
      await tester.pump(const Duration(milliseconds: 500));

      expect(fade.opacity.value, before, reason: 'rien ne bouge');
      expect(before, 1.0, reason: 'et les formes restent pleinement visibles');
    });

    testWidgets('sinon, elle respire', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ChannelListSkeleton())),
      );

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(SkeletonPulse),
          matching: find.byType(FadeTransition),
        ),
      );
      final before = fade.opacity.value;
      await tester.pump(const Duration(milliseconds: 450));

      expect(fade.opacity.value, isNot(before));
    });
  });
}
