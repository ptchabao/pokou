import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/e2ee_outcome.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';
import 'package:pokou/features/messaging/data/messaging_repository.dart';
import 'package:pokou/features/messaging/data/sealed_rich_content.dart';
import 'package:pokou/features/messaging/presentation/attach_sheet.dart';
import 'package:pokou/features/messaging/presentation/conversation_media_screen.dart';
import 'package:pokou/features/messaging/presentation/conversation_search_screen.dart';
import 'package:pokou/features/messaging/presentation/share_sheets.dart';
import 'package:pokou/features/profile/data/contact_profile_model.dart';
import 'package:pokou/features/settings/data/privacy_repository.dart';

import '../../helpers/localized_harness.dart';

/// Retour de l'équipe de test sur la messagerie : partage de contact et de
/// position chiffrés, numéro masqué, recherche locale, médias.

class _Sealer extends E2EEService {
  _Sealer(this.outcome) : super(apiClient: ApiClient(baseUrl: 'https://x'));

  final SealOutcome outcome;
  final List<String> sealed = [];

  @override
  Future<SealOutcome> seal({
    required int peerUserId,
    required String plaintext,
  }) async {
    sealed.add(plaintext);
    return outcome;
  }
}

class _RecordingApi extends ApiClient {
  _RecordingApi() : super(baseUrl: 'https://inutilise');

  final List<({String path, Map<String, dynamic> body})> posted = [];

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    posted.add((path: path, body: Map<String, dynamic>.from(body!)));
    return {
      'id': 'srv-1',
      'sender_id': 1,
      'recipient_id': body['recipient_id'] ?? body['target_id'] ?? 2,
      'message_type': body['message_type'] ?? 'LOCATION',
      'content': null,
      'status': 'SENT',
      'created_at': DateTime.now().toIso8601String(),
      if (body.containsKey('encryption')) 'encryption': body['encryption'],
      if (body.containsKey('ciphertext')) 'ciphertext': body['ciphertext'],
      if (body.containsKey('envelope')) 'envelope': body['envelope'],
    };
  }
}

DirectMessage _message({
  required String id,
  String type = 'TEXT',
  String? content,
  int sender = 1,
  DateTime? at,
  Map<String, dynamic>? json,
}) => DirectMessage.fromJson({
  'id': id,
  'sender_id': sender,
  'recipient_id': sender == 1 ? 2 : 1,
  'message_type': type,
  'content': content,
  'status': 'SENT',
  'created_at': (at ?? DateTime(2026, 11, 1)).toIso8601String(),
  ...?json,
});

void main() {
  group('position et fiche contact chiffrées', () {
    test('le scellé se rouvre à l’identique', () {
      final payload = SealedRichContent.location(
        latitude: 6.13,
        longitude: 1.22,
        label: 'Bè, Lomé',
      );
      final opened = SealedRichContent.open(
        SealedRichContent.seal(content: 'Bè, Lomé', payload: payload),
      );
      expect(opened?.content, 'Bè, Lomé');
      expect(opened?.payload['latitude'], 6.13);
      expect(SealedRichContent.open('bonjour'), isNull);
      expect(SealedRichContent.open('{"format":"autre"}'), isNull);
    });

    test('la légende d’une fiche est la liste des noms', () {
      final payload = SealedRichContent.contacts([
        (displayName: 'Awa', phone: '+22890000001'),
        (displayName: 'Kossi', phone: '+22890000002'),
      ]);
      expect(SealedRichContent.captionOf('CONTACT', payload), 'Awa, Kossi');
    });

    test('rien de la fiche ne part en clair', () async {
      final api = _RecordingApi();
      final sealer = _Sealer(
        const SealEncrypted(
          encryption: 'v1',
          ciphertext: 'AAAA',
          envelope: {'sid': 's'},
        ),
      );
      final repository = MessagingRepository(
        apiClient: api,
        store: PokouMessageStore(),
        e2ee: sealer,
      );
      final payload = SealedRichContent.contacts([
        (displayName: 'Awa', phone: '+22890000001'),
      ]);
      final sent = await repository.sendRich(
        recipientId: 2,
        messageType: 'CONTACT',
        payload: payload,
      );

      final body = api.posted.single;
      expect(body.path, '/messages');
      expect(body.body['message_type'], 'CONTACT');
      expect(jsonEncode(body.body), isNot(contains('22890000001')));
      expect(jsonEncode(body.body), isNot(contains('Awa')));
      expect(sealer.sealed.single, contains('22890000001'));
      // L'expéditeur voit sa propre fiche.
      expect(sent.payload?['contacts'], isNotEmpty);
      expect(sent.isEncrypted, isFalse);
    });

    test('un refus de chiffrer n’envoie rien', () async {
      final api = _RecordingApi();
      final repository = MessagingRepository(
        apiClient: api,
        store: PokouMessageStore(),
        e2ee: _Sealer(const SealRefused(SealFailure.keyLookupFailed)),
      );
      await expectLater(
        repository.sendRich(
          recipientId: 2,
          messageType: 'LOCATION',
          payload: SealedRichContent.location(latitude: 1, longitude: 2),
        ),
        throwsA(isA<EncryptionUnavailableException>()),
      );
      expect(api.posted, isEmpty);
    });

    test('un clair reçu redevient une position lisible', () {
      final repository = MessagingRepository(
        apiClient: _RecordingApi(),
        store: PokouMessageStore(),
      );
      final incoming = _message(id: 'm1', type: 'LOCATION');
      final payload = SealedRichContent.location(
        latitude: 6.13,
        longitude: 1.22,
        label: 'Bè',
      );
      final opened = repository.resolveDirectPlaintext(
        incoming,
        SealedRichContent.seal(content: 'Bè', payload: payload),
      );
      expect(opened.payload?['longitude'], 1.22);
      expect(opened.content, 'Bè');
      // Et se re-scelle à l'identique pour une re-livraison.
      final again = SealedRichContent.open(
        MessagingRepository.directPlaintextOf(opened),
      );
      expect(again?.payload['latitude'], 6.13);
    });
  });

  group('partager un contact', () {
    testWidgets('la confirmation dit exactement ce qui était demandé', (
      tester,
    ) async {
      bool? answer;
      await tester.pumpWidget(
        localizedHarness(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  answer = await confirmShareContact(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Partager ce contact ?'), findsOneWidget);
      expect(
        find.textContaining(
          "Tu t'apprêtes à partager le numéro d'une autre personne. "
          "Assure-toi qu'elle est d'accord avant de l'envoyer. Tu es "
          'responsable des informations que tu partages sur Pokou.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('En savoir plus', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Annuler'), findsOneWidget);

      await tester.tap(find.text('Partager'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });

    testWidgets(
      'la fiche contact n’est proposée qu’à deux, la position partout',
      (tester) async {
        Future<void> open({required bool contact}) async {
          await tester.pumpWidget(
            ProviderScope(
              child: localizedHarness(
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showAttachSheet(
                      context,
                      targetName: 'Awa',
                      offerContact: contact,
                    ),
                    child: const Text('joindre'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('joindre'));
          await tester.pumpAndSettle();
        }

        await open(contact: true);
        expect(find.text('Position'), findsOneWidget);
        expect(find.text('Contact'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        await open(contact: false);
        expect(find.text('Position'), findsOneWidget);
        expect(find.text('Contact'), findsNothing);
      },
    );
  });

  group('numéro masqué', () {
    test('la fiche sait que le numéro est masqué', () {
      final profile = ContactProfile.fromJson({
        'id': 3,
        'full_name': 'Carla',
        'phone': null,
        'phone_hidden': true,
        'is_blocked': false,
      });
      expect(profile.phone, isNull);
      expect(profile.phoneHidden, isTrue);
    });

    test('le réglage se lit et se lit prudemment', () {
      expect(
        PrivacySettings.fromJson({'phone_number': 'HIDDEN'}).phoneHidden,
        isTrue,
      );
      expect(
        PrivacySettings.fromJson({'phone_number': 'CONTACTS'}).phoneHidden,
        isFalse,
      );
      expect(PrivacySettings.fromJson({}).phoneHidden, isFalse);
      expect(
        PrivacySettings.fromJson({'phone_number': 'INCONNU'}).phoneHidden,
        isTrue,
      );
    });
  });

  group('recherche dans la conversation', () {
    test('cherche dans le clair déchiffré, jamais dans le chiffré', () {
      final messages = [
        _message(
          id: 'a',
          content: 'Rendez-vous au Marché',
          at: DateTime(2026, 1, 1),
        ),
        _message(
          id: 'b',
          content: null,
          json: {
            'encryption': 'v1',
            'ciphertext': 'marché',
            'envelope': {'v': 1},
          },
        ),
        _message(id: 'c', content: 'marché demain ?', at: DateTime(2026, 1, 2)),
        _message(id: 'd', content: 'autre chose'),
      ];
      final results = searchDecrypted(messages, 'MARCHÉ');
      expect(results.map((m) => m.id), ['c', 'a']);
      expect(searchDecrypted(messages, '  '), isEmpty);
    });
  });

  group('voir les médias', () {
    test('photos, documents et liens, sans doublon ni chiffré', () {
      Map<String, dynamic> media(int id, String mime) => {
        'media_asset_id': id,
        'media': {
          'id': id,
          'mime_type': mime,
          'size_bytes': 10,
          'original_filename': 'f',
        },
      };
      final index = indexConversationMedia([
        _message(id: '1', type: 'IMAGE', json: media(1, 'image/jpeg')),
        _message(id: '2', type: 'DOCUMENT', json: media(2, 'application/pdf')),
        _message(id: '3', content: 'voir https://pokou.app et www.exemple.tg'),
        _message(id: '4', content: 'encore https://pokou.app'),
        _message(
          id: '5',
          type: 'IMAGE',
          json: {...media(5, 'image/jpeg'), 'view_once': true},
        ),
      ]);
      expect(index.visuals.map((m) => m.id), ['1']);
      expect(index.documents.map((m) => m.id), ['2']);
      expect(index.links.map((l) => l.url), [
        'https://pokou.app',
        'https://www.exemple.tg',
      ]);
    });
  });
}
