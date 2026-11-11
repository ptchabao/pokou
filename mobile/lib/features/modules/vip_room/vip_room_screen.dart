import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../shared/module_payment.dart';
import '../shared/module_ui.dart';
import 'vip_room_controller.dart';
import 'vip_room_model.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// La couleur du module — pastilles seulement.
const _violet = Color(0xFF7C3AED);

String _dayMonth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// VIP Room — découvrir, mes abonnements, mon salon.
class VipRoomScreen extends ConsumerStatefulWidget {
  const VipRoomScreen({super.key});

  @override
  ConsumerState<VipRoomScreen> createState() => _VipRoomScreenState();
}

class _VipRoomScreenState extends ConsumerState<VipRoomScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: 'VIP Room',
      subtitle: L.of(context).vipSubtitle,
      child: Column(
        children: [
          const SizedBox(height: 4),
          ModuleSegmented(
            labels: [
              L.of(context).vipDiscover,
              L.of(context).vipMySubs,
              L.of(context).vipMyRoom,
            ],
            index: _tab,
            onChanged: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: switch (_tab) {
              0 => _RoomList(
                provider: openVipRoomsProvider,
                emptyIcon: Icons.workspace_premium_outlined,
                emptyTitle: L.of(context).vipNoRoomOpen,
                emptyMessage: L.of(context).vipNoRoomOpenBody,
              ),
              1 => _RoomList(
                provider: myVipSubscriptionsProvider,
                emptyIcon: Icons.bookmark_border,
                emptyTitle: L.of(context).vipNoSub,
                emptyMessage: L.of(context).vipNoSubBody,
              ),
              _ => const _MyRoomTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _RoomList extends ConsumerWidget {
  const _RoomList({
    required this.provider,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final AutoDisposeFutureProvider<List<VipRoom>> provider;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ModuleEmptyState(
        icon: Icons.cloud_off,
        title: L.of(context).vipUnavailable,
        message: L.of(context).modulesCheckNetwork,
      ),
      data: (rooms) {
        if (rooms.isEmpty) {
          return ModuleEmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            await ref.read(provider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: rooms.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _RoomCard(room: rooms[index]),
          ),
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final VipRoom room;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VipRoomFeedScreen(roomId: room.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ModuleBadge(icon: Icons.workspace_premium, color: _violet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      room.ownerName ?? L.of(context).vipCreator,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (room.isSubscribed)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.accentPrimary,
                  size: 20,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${room.monthlyPrice} F',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '/ mois',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            room.pitch,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (room.isSubscribed && room.expiresAt != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  // La date de fin est dite : un abonnement qui s'éteint
                  // sans prévenir est un abonnement qu'on ne renouvelle pas.
                  L.of(context).vipUntil(_dayMonth(room.expiresAt!)),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Le contenu d'un salon, ou son mur de paiement.
class VipRoomFeedScreen extends ConsumerStatefulWidget {
  const VipRoomFeedScreen({super.key, required this.roomId});

  final int roomId;

  @override
  ConsumerState<VipRoomFeedScreen> createState() => _VipRoomFeedScreenState();
}

class _VipRoomFeedScreenState extends ConsumerState<VipRoomFeedScreen> {
  bool _busy = false;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(vipRoomRepositoryProvider)
          .subscribe(widget.roomId);
      if (!mounted) return;
      await openPaymentGateway(
        context,
        url,
        pendingMessage: L.of(context).vipPaymentPending,
      );
      ref.invalidate(vipRoomFeedProvider(widget.roomId));
      ref.invalidate(myVipSubscriptionsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vipRoomFeedProvider(widget.roomId));

    return ModuleScaffold(
      title: L.of(context).vipRoom,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.search_off,
          title: L.of(context).vipNotFound,
          message: L.of(context).vipMaybeClosed,
        ),
        data: (feed) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            ModuleCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ModuleBadge(
                        icon: Icons.workspace_premium,
                        color: _violet,
                        size: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feed.room.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              feed.room.ownerName ?? L.of(context).vipCreator,
                              style: TextStyle(
                                color: AppColors.textSecondary,
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
                    // Toujours visible, même sans abonnement : sans lui,
                    // personne n'a de raison de payer.
                    feed.room.pitch,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                ],
              ),
            ),
            if (feed.locked) ...[
              const SizedBox(height: 14),
              ExplainerCard(
                steps: [
                  (
                    icon: Icons.lock_open_outlined,
                    title: L.of(context).vipStepAllTitle,
                    body: L.of(context).vipStepAllBody,
                  ),
                  (
                    icon: Icons.event_outlined,
                    title: L.of(context).vipStepDaysTitle,
                    body: L.of(context).vipStepDaysBody,
                  ),
                  (
                    icon: Icons.credit_card_off_outlined,
                    title: L.of(context).vipStepNoRenewTitle,
                    body: L.of(context).vipStepNoRenewBody,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ModuleActionButton(
                label: L.of(context).vipSubscribeFor(feed.room.monthlyPrice),
                busy: _busy,
                onPressed: _subscribe,
              ),
              const SizedBox(height: 22),
              ModuleEmptyState(
                icon: Icons.lock_outline,
                title: L.of(context).vipLockedTitle,
                message: L.of(context).vipLockedBody,
              ),
            ] else if (feed.posts.isEmpty) ...[
              const SizedBox(height: 22),
              ModuleEmptyState(
                icon: Icons.post_add_outlined,
                title: L.of(context).vipNothingYet,
                message: L.of(context).vipNothingYetBody,
              ),
            ] else ...[
              ModuleSectionTitle(L.of(context).vipPosts),
              ...feed.posts.map((post) => _PostCard(post: post)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final VipPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = post.media;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModuleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (media != null && media.mimeType.startsWith('image/')) ...[
              FutureBuilder<File>(
                future: ref
                    .read(mediaRepositoryProvider)
                    .resolveLocalFile(
                      media.id,
                      extension: mediaExtension(media),
                    ),
                builder: (_, snapshot) {
                  final file = snapshot.data;
                  if (file == null) {
                    return Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Image.file(file, fit: BoxFit.cover),
                  );
                },
              ),
              if (post.textContent != null) const SizedBox(height: 12),
            ],
            if (post.textContent != null)
              Text(
                post.textContent!,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyRoomTab extends ConsumerWidget {
  const _MyRoomTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(myVipRoomProvider);

    return roomAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ModuleEmptyState(
        icon: Icons.cloud_off,
        title: L.of(context).vipRoomUnavailable,
        message: L.of(context).modulesCheckNetwork,
      ),
      data: (room) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (room == null) ...[
            ModuleCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ModuleBadge(
                    icon: Icons.workspace_premium,
                    color: _violet,
                    size: 46,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    L.of(context).vipOpenYourRoom,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    L.of(context).vipOpenYourRoomBody,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ModuleActionButton(
                    label: L.of(context).vipOpenAction,
                    onPressed: () => _showRoomSheet(context, ref, null),
                  ),
                ],
              ),
            ),
          ] else ...[
            ModuleCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ModuleBadge(
                        icon: Icons.workspace_premium,
                        color: _violet,
                        size: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${room.monthlyPrice} FCFA / mois',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _OpenBadge(isOpen: room.isOpen),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ModuleQuietButton(
                          label: L.of(context).conversationEdit,
                          onPressed: () => _showRoomSheet(context, ref, room),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ModuleActionButton(
                          label: L.of(context).vipPublish,
                          onPressed: () => _showPublishSheet(context, ref),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ref
                .watch(vipEarningsProvider)
                .when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (earnings) => _EarningsCard(earnings: earnings),
                ),
            const SizedBox(height: 12),
            ModuleQuietButton(
              label: L.of(context).vipSeeMyRoom,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VipRoomFeedScreen(roomId: room.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.accentPrimaryLight : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        isOpen ? L.of(context).vipOpen : L.of(context).vipClosed,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Ce que mon salon a rapporté. « Dû », jamais « versé » : le virement n'est
/// pas automatique, et le laisser croire serait pire que de ne rien afficher.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnings});

  final VipEarnings earnings;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.of(context).vipEarnings,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '${earnings.due} FCFA',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          Text(
            L
                .of(context)
                .vipEarningsSummary(earnings.subscriptions, earnings.gross),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: AppColors.accentPrimaryDark,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    L.of(context).vipDueNote,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showRoomSheet(
  BuildContext context,
  WidgetRef ref,
  VipRoom? room,
) async {
  final titleController = TextEditingController(text: room?.title ?? '');
  final pitchController = TextEditingController(text: room?.pitch ?? '');
  final priceController = TextEditingController(
    text: (room?.monthlyPrice ?? 2000).toString(),
  );
  var isOpen = room?.isOpen ?? true;
  var busy = false;

  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleSheetTitle(
              room == null
                  ? L.of(innerContext).vipOpenAction
                  : L.of(innerContext).vipEditRoom,
              subtitle: room == null ? null : L.of(innerContext).vipPriceNote,
            ),
            FieldLabel(L.of(innerContext).vipRoomName),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: titleController,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: L.of(innerContext).vipRoomNameHint,
              ),
            ),
            FieldLabel(L.of(innerContext).vipPitchLabel),
            Text(
              L.of(innerContext).vipPitchNote,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: pitchController,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: L.of(innerContext).vipPitchHint,
              ),
            ),
            FieldLabel(L.of(innerContext).vipMonthlyPrice),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '2000'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.accentPrimary,
              value: isOpen,
              onChanged: (value) => setSheetState(() => isOpen = value),
              title: Text(
                L.of(innerContext).vipAcceptNew,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                L.of(innerContext).vipAcceptNewNote,
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            ModuleActionButton(
              label: L.of(innerContext).actionSave,
              busy: busy,
              onPressed: () async {
                final price = int.tryParse(priceController.text.trim());
                if (price == null ||
                    titleController.text.trim().length < 3 ||
                    pitchController.text.trim().length < 10) {
                  ScaffoldMessenger.of(innerContext).showSnackBar(
                    SnackBar(content: Text(L.of(innerContext).vipFieldsNeeded)),
                  );
                  return;
                }
                setSheetState(() => busy = true);
                try {
                  await ref
                      .read(vipRoomRepositoryProvider)
                      .saveRoom(
                        title: titleController.text.trim(),
                        pitch: pitchController.text.trim(),
                        monthlyPrice: price,
                        isOpen: isOpen,
                      );
                  ref.invalidate(myVipRoomProvider);
                  if (innerContext.mounted) Navigator.of(innerContext).pop();
                } catch (_) {
                  setSheetState(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showPublishSheet(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  var busy = false;

  await showModuleSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSheetTitle(
            L.of(innerContext).vipPublishTitle,
            subtitle: L.of(innerContext).vipPublishNote,
          ),
          FieldLabel(L.of(innerContext).vipYourMessage),
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: controller,
            maxLines: 5,
            maxLength: 4000,
            autofocus: true,
            decoration: InputDecoration(
              hintText: L.of(innerContext).vipShareHint,
            ),
          ),
          const SizedBox(height: 4),
          ModuleActionButton(
            label: L.of(context).vipPublish,
            busy: busy,
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              setSheetState(() => busy = true);
              try {
                await ref.read(vipRoomRepositoryProvider).publish(text: text);
                ref.invalidate(myVipRoomProvider);
                if (innerContext.mounted) Navigator.of(innerContext).pop();
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
