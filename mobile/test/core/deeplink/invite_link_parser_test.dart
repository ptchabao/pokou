import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/deeplink/invite_link_parser.dart';

void main() {
  group('parseInviteLink — format canonique (/invite/group|community/{code})', () {
    test('lien de groupe', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/invite/group/ABC123'));
      expect(invite, isNotNull);
      expect(invite!.kind, DeepLinkInviteKind.group);
      expect(invite.code, 'ABC123');
    });

    test('lien de communauté', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/invite/community/XYZ789'));
      expect(invite, isNotNull);
      expect(invite!.kind, DeepLinkInviteKind.community);
      expect(invite.code, 'XYZ789');
    });

    test('ignore les segments superflus après le code', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/invite/group/ABC123/extra'));
      expect(invite, isNotNull);
      expect(invite!.code, 'ABC123');
    });
  });

  group('parseInviteLink — formats hérités (avant ce ticket)', () {
    test('/invite/{code} nu est traité comme un groupe', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/invite/oldCode16Chars'));
      expect(invite, isNotNull);
      expect(invite!.kind, DeepLinkInviteKind.group);
      expect(invite.code, 'oldCode16Chars');
    });

    test('/c/{code} est traité comme une communauté', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/c/oldCommunityCode'));
      expect(invite, isNotNull);
      expect(invite!.kind, DeepLinkInviteKind.community);
      expect(invite.code, 'oldCommunityCode');
    });
  });

  group('parseInviteLink — liens ignorés sans planter', () {
    test('hôte ou chemin étranger', () {
      expect(parseInviteLink(Uri.parse('https://pok.app/produit')), isNull);
      expect(parseInviteLink(Uri.parse('https://example.com/invite/group/ABC123')), isNull);
    });

    test('schéma non https', () {
      expect(parseInviteLink(Uri.parse('http://pok.app/invite/group/ABC123')), isNull);
      expect(parseInviteLink(Uri.parse('mailto:someone@example.com')), isNull);
    });

    test('chemin racine ou vide', () {
      expect(parseInviteLink(Uri.parse('https://pok.app/')), isNull);
      expect(parseInviteLink(Uri.parse('https://pok.app')), isNull);
    });

    test('code manquant après le marqueur de nature', () {
      expect(parseInviteLink(Uri.parse('https://pok.app/invite/group/')), isNull);
      expect(parseInviteLink(Uri.parse('https://pok.app/invite/community')), isNull);
    });

    test('segment de nature inconnu à deux niveaux', () {
      // Ni "group"/"community" (format canonique) ni un code nu à un seul
      // niveau : deux segments après "invite" mais le premier n'est pas une
      // nature reconnue — ambigu, donc ignoré plutôt que deviné.
      expect(parseInviteLink(Uri.parse('https://pok.app/invite/unknownKind/CODE')), isNull);
    });
  });

  test('PendingInvite implémente == par valeur (utile pour les tests futurs)', () {
    const a = PendingInvite(kind: DeepLinkInviteKind.group, code: 'ABC123');
    const b = PendingInvite(kind: DeepLinkInviteKind.group, code: 'ABC123');
    const c = PendingInvite(kind: DeepLinkInviteKind.community, code: 'ABC123');
    expect(a, equals(b));
    expect(a, isNot(equals(c)));
  });

  group('parseInviteLink — chaînes', () {
    test('format canonique /invite/channel/{code}', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/invite/channel/CHN001'));
      expect(invite, isNotNull);
      expect(invite!.kind, DeepLinkInviteKind.channel);
      expect(invite.code, 'CHN001');
    });

    test('format publication de chaîne /channel/{code}/post/{id}', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/channel/CHN002/post/42'));
      expect(invite, isNotNull);
      expect(invite!.kind, DeepLinkInviteKind.channel);
      expect(invite.code, 'CHN002');
      expect(invite.postId, 42);
    });

    test('format canonique publication de chaîne /invite/channel/{code}/post/{id}', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/invite/channel/CHN001/post/99'));
      expect(invite, isNotNull);
      expect(invite!.kind, DeepLinkInviteKind.channel);
      expect(invite.code, 'CHN001');
      expect(invite.postId, 99);
    });
  });

  group('lien de bot', () {
    test('/bot/<handle> ouvre la conversation avec le bot', () {
      final invite = parseInviteLink(Uri.parse('https://pok.app/bot/Akwaba_Service'));
      expect(invite!.kind, DeepLinkInviteKind.bot);
      expect(invite.code, 'akwaba_service');
    });

    test('un identifiant de bot mal formé est ignoré', () {
      expect(parseInviteLink(Uri.parse('https://pok.app/bot/a')), isNull);
      expect(parseInviteLink(Uri.parse('https://pok.app/bot/1abc')), isNull);
    });
  });

  group('liens de ressources', () {
    test('/kory/{id} ouvre la cagnotte identifiée', () {
      final link = parseInviteLink(Uri.parse('https://pok.app/kory/42'));
      expect(link, isNotNull);
      expect(link!.kind, DeepLinkInviteKind.koryPot);
      expect(link.resourceId, 42);
    });

    test('/honam/order/{id} ouvre la commande identifiée', () {
      final link = parseInviteLink(
        Uri.parse('https://pok.app/honam/order/314'),
      );
      expect(link, isNotNull);
      expect(link!.kind, DeepLinkInviteKind.honamOrder);
      expect(link.resourceId, 314);
    });

    test('/kory/pots/{id} ouvre la cagnotte identifiée', () {
      final link = parseInviteLink(Uri.parse('https://pok.app/kory/pots/42'));
      expect(link, isNotNull);
      expect(link!.kind, DeepLinkInviteKind.koryPot);
      expect(link.resourceId, 42);
    });

    test('/honam/orders/{id} ouvre la commande identifiée', () {
      final link = parseInviteLink(
        Uri.parse('https://pok.app/honam/orders/314'),
      );
      expect(link, isNotNull);
      expect(link!.kind, DeepLinkInviteKind.honamOrder);
      expect(link.resourceId, 314);
    });

    test('rejette les identifiants invalides et les chemins ambigus', () {
      for (final path in [
        '/kory/pots/0',
        '/kory/pots/not-an-id',
        '/kory/pots/42/extra',
        '/honam/orders/-1',
        '/honam/orders/',
        '/kory/42/extra',
        '/honam/order/314/extra',
      ]) {
        expect(
          parseInviteLink(Uri.parse('https://pok.app$path')),
          isNull,
          reason: path,
        );
      }
    });
  });
}
