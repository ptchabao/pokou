import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mahizu/mahizu_session.dart';
import '../data/inbox_repository.dart';
import '../data/monitor_model.dart';

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  return InboxRepository(apiClient: ref.watch(mahizuApiClientProvider));
});

/// Les contacts intelligents viennent des moniteurs Mahizu : sans compte
/// Mahizu rattaché, la liste est simplement vide.
final smartContactsProvider = FutureProvider.autoDispose<List<SmartContact>>((
  ref,
) async {
  if (!ref.watch(mahizuSessionProvider).isConnected) return const [];
  return ref.watch(inboxRepositoryProvider).listSmartContacts();
});
