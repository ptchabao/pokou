import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_harness.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';
import 'package:pokou/features/messaging/data/messaging_repository.dart';
import 'package:pokou/features/messaging/presentation/messaging_controller.dart';
import 'package:pokou/features/messaging/presentation/poll_bubble.dart';

/// Sondage à deux options, ni voté ni multiple — le point de départ commun à
/// tous les tests ci-dessous.
PollData _poll({bool allowsMultiple = false}) => PollData(
      id: 'poll-1',
      question: 'On mange où ?',
      allowsMultiple: allowsMultiple,
      totalVoters: 1,
      options: const [
        PollOptionData(id: 1, text: 'Chez Fatou', position: 0, voteCount: 1, voterIds: [2], mine: false),
        PollOptionData(id: 2, text: 'À la maison', position: 1, voteCount: 0, voterIds: [], mine: false),
      ],
    );

/// N'appelle jamais le réseau : capture juste l'appel de vote pour vérifier
/// que le tap sur une option déclenche bien `POST /polls/{id}/vote` avec les
/// bons arguments, sans dépendre d'un serveur.
class _FakeMessagingRepository extends MessagingRepository {
  _FakeMessagingRepository({required this.onVote}) : super(apiClient: ApiClient(baseUrl: 'https://unused'));

  final Future<PollData> Function(String pollId, List<int> optionIds) onVote;
  String? lastPollId;
  List<int>? lastOptionIds;

  @override
  Future<PollData> votePoll({required String pollId, required List<int> optionIds}) async {
    lastPollId = pollId;
    lastOptionIds = optionIds;
    return onVote(pollId, optionIds);
  }
}

Widget _wrap(Widget child, MessagingRepository repository) => ProviderScope(
      overrides: [messagingRepositoryProvider.overrideWithValue(repository)],
      child: localizedHarness(child),
    );

void main() {
  testWidgets('affiche la question et les deux options avec leur pourcentage', (tester) async {
    final repo = _FakeMessagingRepository(onVote: (_, _) async => _poll());
    await tester.pumpWidget(_wrap(
      PollBubble(poll: _poll(), onVoted: (_) {}),
      repo,
    ));

    expect(find.text('On mange où ?'), findsOneWidget);
    expect(find.text('Chez Fatou'), findsOneWidget);
    expect(find.text('À la maison'), findsOneWidget);
    // 1 vote sur 2 options ne concernant qu'un total de 1 votant : 100 % pour
    // l'option votée, 0 % pour l'autre.
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('0 %'), findsOneWidget);
  });

  testWidgets('toucher une option vote pour elle et remonte le sondage mis à jour', (tester) async {
    final updated = PollData(
      id: 'poll-1',
      question: 'On mange où ?',
      allowsMultiple: false,
      totalVoters: 2,
      options: const [
        PollOptionData(id: 1, text: 'Chez Fatou', position: 0, voteCount: 1, voterIds: [2], mine: false),
        PollOptionData(id: 2, text: 'À la maison', position: 1, voteCount: 1, voterIds: [1], mine: true),
      ],
    );
    final repo = _FakeMessagingRepository(onVote: (_, _) async => updated);
    PollData? votedResult;

    await tester.pumpWidget(_wrap(
      PollBubble(poll: _poll(), onVoted: (poll) => votedResult = poll),
      repo,
    ));

    await tester.tap(find.text('À la maison'));
    await tester.pump();
    await tester.pump();

    expect(repo.lastPollId, 'poll-1');
    expect(repo.lastOptionIds, [2]);
    expect(votedResult?.totalVoters, 2);
  });

  testWidgets('retoucher son propre choix retire le vote (bascule)', (tester) async {
    final poll = PollData(
      id: 'poll-1',
      question: 'On mange où ?',
      allowsMultiple: false,
      totalVoters: 1,
      options: const [
        PollOptionData(id: 1, text: 'Chez Fatou', position: 0, voteCount: 1, voterIds: [1], mine: true),
        PollOptionData(id: 2, text: 'À la maison', position: 1, voteCount: 0, voterIds: [], mine: false),
      ],
    );
    final repo = _FakeMessagingRepository(onVote: (_, _) async => poll);

    await tester.pumpWidget(_wrap(PollBubble(poll: poll, onVoted: (_) {}), repo));

    await tester.tap(find.text('Chez Fatou'));
    await tester.pump();
    await tester.pump();

    // Le vote retiré envoie une liste d'options vide, pas la même option.
    expect(repo.lastOptionIds, isEmpty);
  });
}
