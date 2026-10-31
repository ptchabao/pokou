import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/calls/native_call_bridge.dart';

/// Le pont entre la couche d'appel native et Flutter.
///
/// Ce que ces tests protègent : Flutter ne doit JAMAIS supposer qu'ouvrir
/// l'écran d'appel signifie que l'appel est connecté. Il observe l'état
/// annoncé par le natif, qui est la source de vérité — et il doit survivre
/// aux deux cas où ce natif n'existe pas : iOS, et une installation
/// antérieure à cette version.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('test/call');

  void respond(Object? Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async => handler(call));
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  NativeCallBridge bridge() => NativeCallBridge(methods: methodChannel);

  group('la lecture de l\'état natif', () {
    test('chaque état connu se traduit', () {
      expect(NativeCallState.parse('RINGING'), NativeCallState.ringing);
      expect(NativeCallState.parse('ANSWERING'), NativeCallState.answering);
      expect(NativeCallState.parse('CONNECTING'), NativeCallState.connecting);
      expect(NativeCallState.parse('CONNECTED'), NativeCallState.connected);
      expect(NativeCallState.parse('MISSED'), NativeCallState.missed);
      expect(NativeCallState.parse('FAILED'), NativeCallState.failed);
      expect(NativeCallState.parse('ENDED'), NativeCallState.ended);
    });

    test('un état inconnu devient « terminé », il ne lève pas', () {
      // Une couche native plus récente que ce Dart — le cas d'une mise à
      // jour partielle. Un écran bloqué sur un état illisible serait pire
      // que la fin de l'appel.
      expect(NativeCallState.parse('TÉLÉPORTATION'), NativeCallState.ended);
      expect(NativeCallState.parse(null), NativeCallState.ended);
    });

    test('seuls les états vivants comptent comme actifs', () {
      expect(NativeCallState.ringing.isActive, isTrue);
      expect(NativeCallState.connected.isActive, isTrue);
      expect(NativeCallState.ended.isActive, isFalse);
      expect(NativeCallState.missed.isActive, isFalse);
      expect(NativeCallState.failed.isActive, isFalse);
    });
  });

  group('l\'appel en cours au démarrage', () {
    test('un appel qui sonne est rendu', () async {
      // Le natif peut avoir décroché AVANT que Flutter existe : sans cette
      // interrogation, l'application n'apprendrait jamais qu'un appel est en
      // cours.
      respond((_) => {
            'state': 'RINGING',
            'room': 'r-1',
            'from_user_id': '43',
            'caller_name': 'Kodjo',
            'is_video': true,
          });

      final call = await bridge().currentCall();

      expect(call, isNotNull);
      expect(call!.room, 'r-1');
      expect(call.fromUserId, 43);
      expect(call.isVideo, isTrue);
    });

    test('un appel terminé n\'est PAS rendu', () async {
      // Sinon l'application ouvrirait un écran d'appel sur un appel fini.
      respond((_) => {'state': 'ENDED', 'room': 'r-1'});

      expect(await bridge().currentCall(), isNull);
    });

    test('sans couche native, on ne plante pas — on dit « aucun appel »',
        () async {
      // iOS, ou une installation antérieure à cette version : le canal
      // n'existe pas. C'est le repli, et il doit être silencieux.
      respond((_) => throw MissingPluginException('pas de canal'));

      expect(await bridge().currentCall(), isNull);
    });
  });

  group('les réponses rapides en attente de chiffrement', () {
    test('la file est lue et transformée', () async {
      // Le natif ne peut pas chiffrer : il met en file, Flutter reprend.
      respond((_) => jsonEncode([
            {'contact_user_id': '43', 'text': 'Oui', 'reply_token': 'rt_1'},
            {'contact_user_id': '44', 'text': 'Je arrive'},
          ]));

      final replies = await bridge().drainPendingReplies();

      expect(replies, hasLength(2));
      expect(replies.first.contactUserId, 43);
      expect(replies.first.replyToken, 'rt_1');
      expect(replies.last.replyToken, isNull);
    });

    test('une entrée abîmée est ignorée, pas propagée', () async {
      // Un texte vide ou un identifiant illisible viendrait d'une écriture
      // interrompue. L'ignorer vaut mieux qu'envoyer un message vide.
      respond((_) => jsonEncode([
            {'contact_user_id': '43', 'text': '   '},
            {'contact_user_id': 'pas-un-nombre', 'text': 'Oui'},
            {'contact_user_id': '45', 'text': 'Bonjour'},
          ]));

      final replies = await bridge().drainPendingReplies();

      expect(replies, hasLength(1));
      expect(replies.single.contactUserId, 45);
    });

    test('sans couche native, la file est vide', () async {
      respond((_) => throw MissingPluginException('pas de canal'));

      expect(await bridge().drainPendingReplies(), isEmpty);
    });

    test('un JSON illisible ne fait pas échouer le démarrage', () async {
      respond((_) => 'ceci n\'est pas du JSON');

      expect(await bridge().drainPendingReplies(), isEmpty);
    });
  });

  group('ce que Flutter annonce au natif', () {
    test('le média établi et la fin remontent', () async {
      final appels = <String>[];
      respond((call) {
        appels.add(call.method);
        return null;
      });

      await bridge().reportConnected();
      await bridge().reportEnded();

      expect(appels, ['onConnected', 'onEnded']);
    });

    test('sans couche native, annoncer ne lève pas', () async {
      respond((_) => throw MissingPluginException('pas de canal'));

      // Aucune exception : l'ancien chemin Flutter reste en place.
      await bridge().reportConnected();
      await bridge().reportEnded();
    });

    test('l\'URL de l\'API est transmise, pas codée deux fois', () async {
      // La coder en Kotlin donnerait deux constantes à tenir d'accord.
      Object? recu;
      respond((call) {
        if (call.method == 'setApiBaseUrl') recu = call.arguments;
        return null;
      });

      await bridge().setApiBaseUrl('https://api.test/api/v1');

      expect(recu, 'https://api.test/api/v1');
    });
  });
}
