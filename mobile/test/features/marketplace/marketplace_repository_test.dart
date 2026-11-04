import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/features/marketplace/data/marketplace_repository.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'https://inutilise');

  String? requestedPath;

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) async {
    requestedPath = path;
    return {'items': [], 'has_more': false};
  }
}

void main() {
  test('transmet le filtre des vendeurs certifiés au serveur', () async {
    final api = _FakeApi();
    final repository = MarketplaceRepository(apiClient: api);

    await repository.list(certifiedOnly: true);

    expect(api.requestedPath, contains('certified_only=true'));
  });

  test('n’ajoute pas le filtre au catalogue sans restriction', () async {
    final api = _FakeApi();
    final repository = MarketplaceRepository(apiClient: api);

    await repository.list();

    expect(api.requestedPath, isNot(contains('certified_only')));
  });
}
