import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../shared/module_payment.dart';
import '../shared/module_ui.dart';
import 'truth_market_controller.dart';
import 'truth_market_model.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// La couleur du module — pastilles seulement.
const _sky = Color(0xFF0EA5E9);

const _amounts = [200, 500, 1000, 2000, 5000];

/// Truth Market — les questions reçues, et celles que j'ai posées.
class TruthMarketScreen extends ConsumerStatefulWidget {
  const TruthMarketScreen({super.key});

  @override
  ConsumerState<TruthMarketScreen> createState() => _TruthMarketScreenState();
}

class _TruthMarketScreenState extends ConsumerState<TruthMarketScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: 'Truth Market',
      subtitle: L.of(context).truthSubtitle,
      floatingActionButton: FloatingActionButton.extended(
        // Le vert d'action, comme partout : « poser une question » est un
        // verbe, et tous les verbes de Pokou portent la même couleur.
        backgroundColor: AppColors.accentPrimaryDark,
        foregroundColor: Colors.white,
        onPressed: () => _pickTargetAndAsk(context, ref),
        icon: const Icon(Icons.add),
        label: Text(L.of(context).truthAsk),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          ModuleSegmented(
            labels: [L.of(context).truthForMe, L.of(context).truthMine],
            index: _tab,
            onChanged: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 4),
          Expanded(child: _tab == 0 ? const _ReceivedTab() : const _SentTab()),
        ],
      ),
    );
  }
}

class _ReceivedTab extends ConsumerWidget {
  const _ReceivedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(truthReceivedProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ModuleEmptyState(
        icon: Icons.cloud_off,
        title: L.of(context).truthUnavailable,
        message: L.of(context).modulesCheckNetwork,
      ),
      data: (items) {
        if (items.isEmpty) {
          return ModuleEmptyState(
            icon: Icons.help_outline,
            title: L.of(context).truthEmptyTitle,
            message: L.of(context).truthEmptyBody,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(truthReceivedProvider);
            await ref.read(truthReceivedProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _ReceivedCard(question: items[index]),
          ),
        );
      },
    );
  }
}

class _ReceivedCard extends ConsumerStatefulWidget {
  const _ReceivedCard({required this.question});

  final TruthQuestion question;

  @override
  ConsumerState<_ReceivedCard> createState() => _ReceivedCardState();
}

class _ReceivedCardState extends ConsumerState<_ReceivedCard> {
  bool _busy = false;

  Future<void> _answer() async {
    final controller = TextEditingController();
    final text = await showModuleSheet<String>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSheetTitle(
            L.of(sheetContext).truthYourAnswer,
            subtitle: L.of(sheetContext).truthAnswerPrivacy,
          ),
          FieldLabel(L.of(sheetContext).truthWhatToSay),
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: controller,
            maxLines: 5,
            maxLength: 2000,
            autofocus: true,
            decoration: InputDecoration(
              hintText: L.of(sheetContext).truthYourAnswer,
            ),
          ),
          const SizedBox(height: 4),
          ModuleActionButton(
            label: L.of(sheetContext).truthSendAnswer,
            onPressed: () =>
                Navigator.of(sheetContext).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(truthMarketRepositoryProvider)
          .answer(widget.question.id, text);
      ref.invalidate(truthReceivedProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ref.read(truthMarketRepositoryProvider).decline(widget.question.id);
      ref.invalidate(truthReceivedProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ModuleBadge(
                icon: Icons.help_outline,
                color: _sky,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.question.amount} FCFA',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      // L'anonymat de l'acheteur est ce qui rend la question
                      // posable : on le dit, plutôt que de laisser un vide
                      // là où un nom serait attendu.
                      L.of(context).truthAskedAnon,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.question.question,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ModuleQuietButton(
                  label: L.of(context).truthDecline,
                  onPressed: _busy ? null : _decline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ModuleActionButton(
                  label: L.of(context).truthAnswer,
                  busy: _busy,
                  onPressed: _answer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            // Dit explicitement, parce que c'est la question que tout le
            // monde se pose en voyant un montant.
            L.of(context).truthDeclineFree,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SentTab extends ConsumerWidget {
  const _SentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(truthSentProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ModuleEmptyState(
        icon: Icons.cloud_off,
        title: L.of(context).truthHistoryUnavailable,
        message: L.of(context).modulesCheckNetwork,
      ),
      data: (items) {
        if (items.isEmpty) {
          return ModuleEmptyState(
            icon: Icons.outbox_outlined,
            title: L.of(context).truthNothingAsked,
            message: L.of(context).truthNothingAskedBody,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(truthSentProvider);
            await ref.read(truthSentProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _SentCard(question: items[index]),
          ),
        );
      },
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.question});

  final TruthQuestion question;

  ({IconData icon, String label, Color color}) _stateOf(BuildContext context) {
    if (question.isAnswered) {
      return (
        icon: Icons.check_circle_outline,
        label: L.of(context).truthAnswered,
        color: AppColors.accentPrimaryLight,
      );
    }
    if (question.isDeclined) {
      return (
        icon: Icons.do_not_disturb_on_outlined,
        label: L.of(context).truthDeclined,
        color: AppColors.textMuted,
      );
    }
    return (
      icon: Icons.hourglass_empty,
      label: L.of(context).truthPending,
      color: _sky,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _stateOf(context);
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  L
                      .of(context)
                      .truthAskedTo(
                        question.targetName ?? L.of(context).presenceSomeone,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(state.icon, size: 15, color: state.color),
              const SizedBox(width: 5),
              Text(
                state.label,
                style: TextStyle(
                  color: state.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            style: const TextStyle(fontSize: 15, height: 1.35),
          ),
          const SizedBox(height: 10),
          if (question.isAnswered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                question.answer ?? '',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            )
          else
            Text(
              question.isDeclined
                  ? L.of(context).truthPreferredNot
                  : L.of(context).truthAwaitingAnswer,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Text(
            '${question.amount} FCFA',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Choisir à QUI poser la question, puis ouvrir la feuille.
///
/// Limité aux contacts inscrits : une question adressée à quelqu'un qui n'a
/// pas l'application ne lui arriverait jamais, et l'argent serait pris pour
/// rien.
Future<void> _pickTargetAndAsk(BuildContext context, WidgetRef ref) async {
  final contacts = await ref.read(contactsProvider.future);
  // Le filtre porte sur l'identifiant lui-même, pas seulement sur le
  // drapeau : c'est lui qu'on va déréférencer juste après.
  final registered = contacts
      .where((contact) => contact.isRegistered && contact.contactUserId != null)
      .toList();
  if (!context.mounted) return;

  if (registered.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.of(context).newChatNoRegisteredContact)),
    );
    return;
  }

  final target = await showModuleSheet<({int id, String name})>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModuleSheetTitle(L.of(sheetContext).truthToWhom),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: registered.length,
            itemBuilder: (_, index) {
              final contact = registered[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  contact.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop((id: contact.contactUserId!, name: contact.displayName)),
              );
            },
          ),
        ),
      ],
    ),
  );
  if (target == null || !context.mounted) return;

  await showAskTruthSheet(
    context,
    ref,
    targetId: target.id,
    targetName: target.name,
  );
}

/// La feuille pour poser une question.
///
/// Vit ici et non dans la conversation : c'est le module qui porte la règle
/// de prix, et la dupliquer dans l'écran de discussion la ferait diverger.
Future<void> showAskTruthSheet(
  BuildContext context,
  WidgetRef ref, {
  required int targetId,
  required String targetName,
}) async {
  final questionController = TextEditingController();
  var amount = 500;
  var busy = false;

  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSheetTitle(L.of(innerContext).truthQuestionTo(targetName)),
          const SizedBox(height: 14),
          // La même carte que « créer une publicité » et « devenir vendeur
          // vérifié » : ces trois écrans posent la même question — qu'est-ce
          // que j'achète, et qu'est-ce qui se passe ensuite.
          ExplainerCard(
            steps: [
              (
                icon: Icons.visibility_off_outlined,
                title: L.of(innerContext).truthAnonTitle,
                body: L.of(innerContext).truthAnonBody,
              ),
              (
                icon: Icons.how_to_reg_outlined,
                title: L.of(innerContext).truthFreeTitle,
                body: L.of(innerContext).truthFreeBody,
              ),
              (
                icon: Icons.lock_outline,
                title: L.of(innerContext).truthPrivateTitle,
                body: L.of(innerContext).truthPrivateBody,
              ),
            ],
          ),
          FieldLabel(L.of(innerContext).truthYourQuestion),
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: questionController,
            maxLength: 280,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: L.of(innerContext).truthQuestionHint,
            ),
          ),
          FieldLabel(L.of(innerContext).truthHowMuch),
          ModuleAmountPicker(
            amounts: _amounts,
            selected: amount,
            onChanged: (value) => setSheetState(() => amount = value),
          ),
          const SizedBox(height: 18),
          ModuleActionButton(
            label: L.of(innerContext).truthAskForAmount(amount),
            busy: busy,
            onPressed: () async {
              final text = questionController.text.trim();
              if (text.length < 3) {
                ScaffoldMessenger.of(innerContext).showSnackBar(
                  SnackBar(content: Text(L.of(innerContext).truthWriteFirst)),
                );
                return;
              }
              setSheetState(() => busy = true);
              try {
                final url = await ref
                    .read(truthMarketRepositoryProvider)
                    .ask(targetId: targetId, question: text, amount: amount);
                if (!innerContext.mounted) return;
                Navigator.of(innerContext).pop();
                if (!context.mounted) return;
                await openPaymentGateway(
                  context,
                  url,
                  pendingMessage: L.of(context).truthPaymentPending,
                );
                ref.invalidate(truthSentProvider);
              } catch (_) {
                setSheetState(() => busy = false);
              }
            },
          ),
        ],
      ),
    ),
  );
}
