import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/deeplink/invite_link_parser.dart'
    show pokouLinkBaseUrl;
import 'package:pokou/features/communities/data/community_model.dart';
import 'package:pokou/features/groups/data/group_model.dart';

void main() {
  group('Community.fromJson', () {
    test('lit le détail avec ses groupes', () {
      final parsed = Community.fromJson({
        'id': 3,
        'name': 'Marché de Lomé',
        'description': 'Vendeurs et livreurs',
        'member_count': 12,
        'group_count': 2,
        'my_role': 'OWNER',
        'can_manage': true,
        'invite_code': 'abc123',
        'groups': [
          {
            'id': 1,
            'name': 'Annonces',
            'member_count': 12,
            'is_announcement': true,
          },
          {
            'id': 2,
            'name': 'Vendeurs',
            'member_count': 8,
            'is_announcement': false,
          },
        ],
      });

      expect(parsed.name, 'Marché de Lomé');
      expect(parsed.isOwner, isTrue);
      expect(parsed.canManage, isTrue);
      expect(parsed.groups.length, 2);
      expect(parsed.announcements?.name, 'Annonces');
    });

    test('la liste allégée n\'a pas de groupes mais garde les compteurs', () {
      final parsed = Community.fromJson({
        'id': 3,
        'name': 'Marché',
        'member_count': 12,
        'group_count': 4,
      });

      expect(parsed.groups, isEmpty);
      // Sans ce repli, la liste afficherait 0 groupe.
      expect(parsed.groupCount, 4);
      expect(parsed.announcements, isNull);
      // Défaut prudent : aucun droit tant que le serveur ne les accorde pas.
      expect(parsed.canManage, isFalse);
      expect(parsed.inviteCode, isNull);
    });
  });

  group('lien de communauté', () {
    test('aller-retour lien / code', () {
      expect(communityInviteLinkFor('AbC123'), '$pokouLinkBaseUrl/c/AbC123');
      expect(
        communityInviteCodeFrom(communityInviteLinkFor('AbC123')),
        'AbC123',
      );
    });

    test('un code seul est accepté, la ponctuation d\'URL écartée', () {
      expect(communityInviteCodeFrom('  AbC123 '), 'AbC123');
      expect(
        communityInviteCodeFrom('$pokouLinkBaseUrl/c/AbC123?x=1'),
        'AbC123',
      );
    });

    test('le préfixe des communautés est distinct de celui des groupes', () {
      // /c/ et /invite/ : un lien de communauté ne doit pas être pris pour un
      // lien de groupe, les deux endpoints étant différents.
      expect(communityInviteLinkFor('X').contains('/c/'), isTrue);
      expect(inviteLinkFor('X').contains('/g/'), isTrue);
    });
  });

  group('droit de publier dans un groupe', () {
    Group build({required bool isAnnouncement, required bool canManage}) =>
        Group.fromJson({
          'id': 1,
          'name': 'Annonces',
          'created_by': 1,
          'member_count': 3,
          'is_announcement': isAnnouncement,
          'can_manage': canManage,
        });

    test('un groupe normal est ouvert à tous ses membres', () {
      expect(build(isAnnouncement: false, canManage: false).canPost, isTrue);
    });

    test('les annonces sont fermées à un non-administrateur', () {
      expect(build(isAnnouncement: true, canManage: false).canPost, isFalse);
    });

    test('les annonces sont ouvertes à un administrateur', () {
      expect(build(isAnnouncement: true, canManage: true).canPost, isTrue);
    });
  });
}
