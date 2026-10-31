import '../../../core/api/api_client.dart';
import 'community_model.dart';

class CommunityRepository {
  CommunityRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Voir contacts_repository.dart::listRaw.
  Future<List<dynamic>> listMineRaw() async {
    final response = await _api.get('/communities');
    return response['items'] as List;
  }

  Future<List<Community>> listMine() async => (await listMineRaw())
      .cast<Map<String, dynamic>>()
      .map(Community.fromJson)
      .toList();

  Future<Community> get(int communityId) async {
    final response = await _api.get('/communities/$communityId');
    return Community.fromJson(response as Map<String, dynamic>);
  }

  Future<Community> create({
    required String name,
    String? description,
    List<int> groupIds = const [],
  }) async {
    final response = await _api.post(
      '/communities',
      body: {'name': name, 'description': ?description, 'group_ids': groupIds},
    );
    return Community.fromJson(response as Map<String, dynamic>);
  }

  Future<Community> update({
    required int communityId,
    String? name,
    String? description,
    int? avatarMediaId,
    bool clearAvatar = false,
  }) async {
    final response = await _api.patch(
      '/communities/$communityId',
      body: {
        'name': ?name,
        'description': ?description,
        'avatar_media_id': ?avatarMediaId,
        if (clearAvatar) 'clear_avatar': true,
      },
    );
    return Community.fromJson(response as Map<String, dynamic>);
  }

  /// Rattache un groupe existant, ou en crée un dans la communauté.
  Future<CommunityGroup> addGroup({
    required int communityId,
    int? groupId,
    String? name,
  }) async {
    final response = await _api.post(
      '/communities/$communityId/groups',
      body: {'group_id': ?groupId, 'name': ?name},
    );
    return CommunityGroup.fromJson(response as Map<String, dynamic>);
  }

  Future<void> removeGroup({required int communityId, required int groupId}) =>
      _api.delete('/communities/$communityId/groups/$groupId');

  Future<void> setMemberRole({
    required int communityId,
    required int userId,
    required String role,
  }) => _api.put(
    '/communities/$communityId/members/$userId/role',
    body: {'role': role},
  );

  /// Sert aussi à quitter (en passant son propre userId) — même endpoint,
  /// seule l'autorisation diffère.
  Future<void> removeMember({required int communityId, required int userId}) =>
      _api.delete('/communities/$communityId/members/$userId');

  Future<String> createInviteLink(int communityId) async {
    final response = await _api.post(
      '/communities/$communityId/invite-link',
      body: const {},
    );
    return response['invite_code'] as String;
  }

  Future<void> revokeInviteLink(int communityId) =>
      _api.delete('/communities/$communityId/invite-link');

  Future<CommunityInvitePreview> previewInvite(String code) async {
    final response = await _api.get('/communities/invite/$code');
    return CommunityInvitePreview.fromJson(response as Map<String, dynamic>);
  }

  Future<Community> joinByInvite(String code) async {
    final response = await _api.post(
      '/communities/invite/$code/join',
      body: const {},
    );
    return Community.fromJson(response as Map<String, dynamic>);
  }
}
