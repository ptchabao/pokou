import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/groups/data/group_model.dart';

void main() {
  group('Group.fromJson', () {
    test('parses the detail payload with its members', () {
      final parsed = Group.fromJson({
        'id': 7,
        'name': 'Dépôt Adidogomé',
        'created_by': 1,
        'member_count': 3,
        'members': [
          {'user_id': 1, 'role': 'OWNER', 'display_name': 'Kodjo'},
          {'user_id': 2, 'role': 'MEMBER', 'display_name': 'Ama'},
          {'user_id': 3, 'role': 'MEMBER', 'display_name': 'Yao'},
        ],
      });

      expect(parsed.id, 7);
      expect(parsed.name, 'Dépôt Adidogomé');
      expect(parsed.members.length, 3);
      expect(parsed.members.first.isOwner, isTrue);
      expect(parsed.members.last.isOwner, isFalse);
      expect(parsed.isOwnedBy(1), isTrue);
      expect(parsed.isOwnedBy(2), isFalse);
    });

    test('list payload has no members but keeps the server member_count', () {
      // GET /groups renvoie une charge utile allégée : sans ce repli, le
      // compteur affiché dans la liste tomberait à 0.
      final parsed = Group.fromJson({
        'id': 7,
        'name': 'Fournisseurs ciment',
        'created_by': 1,
        'member_count': 4,
      });

      expect(parsed.members, isEmpty);
      expect(parsed.memberCount, 4);
    });

    test('nameFor resolves a sender and falls back for an unknown one', () {
      final parsed = Group.fromJson({
        'id': 7,
        'name': 'Chantier',
        'created_by': 1,
        'members': [
          {'user_id': 2, 'role': 'MEMBER', 'display_name': 'Ama'},
        ],
      });

      expect(parsed.nameFor(2), 'Ama');
      // Un membre retiré reste l'auteur de ses anciens messages : l'étiquette
      // doit dégrader proprement au lieu de lever une StateError.
      expect(parsed.nameFor(99), 'Inconnu');
    });
  });

  group('GroupMessage.fromJson', () {
    test('parses a text message', () {
      final parsed = GroupMessage.fromJson({
        'id': 'm-1',
        'group_id': 7,
        'sender_id': 2,
        'sender_name': 'Ama',
        'message_type': 'TEXT',
        'content': 'Le camion arrive à 9h',
        'media_asset_id': null,
        'created_at': '2026-09-03T09:00:00',
      });

      expect(parsed.senderName, 'Ama');
      expect(parsed.content, 'Le camion arrive à 9h');
      expect(parsed.isMedia, isFalse);
      expect(parsed.media, isNull);
    });

    test('parses a media message with its nested metadata', () {
      final parsed = GroupMessage.fromJson({
        'id': 'm-2',
        'group_id': 7,
        'sender_id': 3,
        'sender_name': 'Yao',
        'message_type': 'IMAGE',
        'content': null,
        'media_asset_id': 42,
        'media': {
          'id': 42,
          'mime_type': 'image/jpeg',
          'size_bytes': 12345,
          'original_filename': 'facture.jpg',
        },
        'created_at': '2026-09-03T09:05:00',
      });

      expect(parsed.isMedia, isTrue);
      expect(parsed.media!.id, 42);
      expect(parsed.media!.mimeType, 'image/jpeg');
    });

    test('falls back when the server omits sender_name or message_type', () {
      final parsed = GroupMessage.fromJson({
        'id': 'm-3',
        'group_id': 7,
        'sender_id': 4,
        'created_at': '2026-09-03T09:10:00',
      });

      expect(parsed.senderName, 'Inconnu');
      expect(parsed.messageType, 'TEXT');
    });
  });
  group('administration', () {
    test('les droits viennent du serveur, pas du nom de rôle', () {
      final parsed = Group.fromJson({
        'id': 7,
        'name': 'Chantier',
        'created_by': 1,
        'member_count': 2,
        'my_role': 'ADMIN',
        'can_manage': true,
        'invite_code': 'abc123',
      });

      expect(parsed.myRole, 'ADMIN');
      expect(parsed.canManage, isTrue);
      // Admin sans être créateur : il ne peut pas nommer d'autres admins.
      expect(parsed.isOwner, isFalse);
      expect(parsed.inviteCode, 'abc123');
    });

    test('un membre simple ne voit pas de lien et ne gère rien', () {
      final parsed = Group.fromJson({
        'id': 7,
        'name': 'Chantier',
        'created_by': 1,
        'member_count': 2,
        'my_role': 'MEMBER',
        'can_manage': false,
        'invite_code': null,
      });

      expect(parsed.canManage, isFalse);
      expect(parsed.inviteCode, isNull);
    });

    test('la charge utile allégée de GET /groups n\'a pas de rôle', () {
      final parsed = Group.fromJson({
        'id': 7,
        'name': 'Chantier',
        'created_by': 1,
        'member_count': 3,
      });

      expect(parsed.myRole, isNull);
      // Défaut prudent : pas de droits tant que le serveur ne les accorde pas.
      expect(parsed.canManage, isFalse);
    });

    test('le rôle d\'un membre distingue créateur, admin et membre', () {
      final owner = GroupMember.fromJson({'user_id': 1, 'role': 'OWNER', 'display_name': 'Kodjo'});
      final admin = GroupMember.fromJson({'user_id': 2, 'role': 'ADMIN', 'display_name': 'Ama'});
      final member = GroupMember.fromJson({'user_id': 3, 'role': 'MEMBER', 'display_name': 'Yao'});

      expect((owner.isOwner, owner.isAdmin, owner.canManage), (true, false, true));
      expect((admin.isOwner, admin.isAdmin, admin.canManage), (false, true, true));
      expect((member.isOwner, member.isAdmin, member.canManage), (false, false, false));
    });

    test('la photo du groupe arrive avec sa métadonnée', () {
      final parsed = Group.fromJson({
        'id': 7,
        'name': 'Chantier',
        'created_by': 1,
        'member_count': 2,
        'avatar_media_id': 42,
        'avatar': {
          'id': 42,
          'mime_type': 'image/png',
          'size_bytes': 8192,
          'original_filename': 'logo.png',
        },
      });

      // L'identifiant seul ne suffirait pas : le cache local nomme son
      // fichier d'après le type MIME.
      expect(parsed.avatar?.id, 42);
      expect(parsed.avatar?.mimeType, 'image/png');
    });
  });

  group('lien d\'invitation', () {
    test('un lien complet se réduit à son code', () {
      expect(inviteCodeFrom('https://pok.app/invite/AbC123xyz'), 'AbC123xyz');
    });

    test('un code seul est accepté tel quel', () {
      expect(inviteCodeFrom('  AbC123xyz  '), 'AbC123xyz');
    });

    test('la ponctuation d\'URL après le code est écartée', () {
      // Un lien collé depuis une messagerie traîne souvent un paramètre ou
      // une ancre.
      expect(inviteCodeFrom('https://pok.app/invite/AbC123?utm=wa'), 'AbC123');
      expect(inviteCodeFrom('https://pok.app/invite/AbC123#x'), 'AbC123');
      expect(inviteCodeFrom('https://pok.app/invite/AbC123/'), 'AbC123');
    });

    test('le lien partageable se construit depuis le code', () {
      expect(inviteLinkFor('AbC123'), 'https://pok.app/invite/group/AbC123');
      expect(inviteCodeFrom(inviteLinkFor('AbC123')), 'AbC123');
    });
  });
}
