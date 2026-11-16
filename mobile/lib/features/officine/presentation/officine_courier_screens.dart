import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/sharing/invite_sharing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/data/honam_models.dart' show HonamOrderMessage;
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_ui.dart';

/// Officine · 6. Vos coursiers : les livreurs habituels, à qui les courses
/// de l'officine sont proposées en premier.
class OfficineCouriersScreen extends ConsumerWidget {
  const OfficineCouriersScreen({super.key});

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final phone = await showModuleSheet<String>(
      context: context,
      builder: (_) => const _PhoneSheet(),
    );
    if (phone == null || phone.isEmpty) return;
    try {
      await ref.read(officineRepositoryProvider).attachCourier(phone);
      HapticFeedback.lightImpact();
      ref.invalidate(officineCouriersProvider);
      messenger.showSnackBar(SnackBar(content: Text(l.offiCourierAttached)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    }
  }

  Future<void> _detach(
    BuildContext context,
    WidgetRef ref,
    AttachedCourier courier,
  ) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = courier.name ?? courier.phone ?? l.honamCourier;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.offiDetachTitle(name)),
        content: Text(l.offiDetachBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.offiDetach),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(officineRepositoryProvider).detachCourier(courier.userId);
      ref.invalidate(officineCouriersProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    }
  }

  Future<void> _share(BuildContext context, String pharmacy) async {
    final l = L.of(context);
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      '${l.offiCourierInviteText(pharmacy)} : ${InviteSharing.playStoreUrl}',
      sharePositionOrigin: box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final me = ref.watch(officineMeProvider).valueOrNull;
    final async = ref.watch(officineCouriersProvider);
    final data = async.valueOrNull;
    final pharmacy = me?.pharmacy.name ?? '';
    return OfficinePage(
      title: l.offiCouriersTitle,
      subtitle: me == null
          ? null
          : '${me.pharmacy.name} · ${me.pharmacy.address}',
      onRefresh: () async => ref.invalidate(officineCouriersProvider),
      children: [
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficineCardTitle(l.offiInviteYourCouriers),
              Text(
                l.offiInviteYourCouriersBody(data?.priorityMinutes ?? 5),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        officineGap,
        if (data == null && async.isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data == null)
          ModuleCallout(
            tone: CalloutTone.red,
            text: officineError(l, async.error ?? ''),
          )
        else if (data.items.isEmpty)
          Text(
            l.offiNoAttachedCourier,
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ModuleCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, courier) in data.items.indexed) ...[
                  if (i > 0) const HonamHairline(indent: 12),
                  ListTile(
                    onLongPress: () => _detach(context, ref, courier),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.terracottaTint,
                      child: Text(
                        officineInitials(courier.name ?? courier.phone),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onTerracottaTint,
                        ),
                      ),
                    ),
                    title: Text(
                      courier.name ?? courier.phone ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (courier.zones != null && courier.zones!.isNotEmpty)
                          courier.zones!,
                        l.offiDefaults(courier.defaultsCount),
                        if (courier.unpaidCount > 0)
                          l.offiUnpaidCourses(courier.unpaidCount),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l.offiCoursesCount(courier.deliveredCount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        OfficineTag(
                          courier.status == 'SUSPENDED'
                              ? l.offiCourierSuspended
                              : l.offiAttached,
                          tone: courier.status == 'SUSPENDED'
                              ? OfficineTone.danger
                              : OfficineTone.success,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        officineGap,
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) => HonamPrimaryButton(
                  label: l.offiShareLink,
                  icon: Icons.share_outlined,
                  onPressed: () => _share(context, pharmacy),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OfficineOutlineButton(
                label: l.offiAttachByNumber,
                icon: Icons.person_add_alt,
                onPressed: () => _attach(context, ref),
              ),
            ),
          ],
        ),
        OfficineNote(l.offiCouriersNote),
        if (data != null && data.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.offiDetachHint,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _PhoneSheet extends StatefulWidget {
  const _PhoneSheet();

  @override
  State<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<_PhoneSheet> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleSheetTitle(l.offiAttachByNumber, subtitle: l.offiAttachHint),
        const SizedBox(height: 14),
        TextField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l.offiCourierNumber,
            hintText: '+228 90 00 00 00',
          ),
        ),
        const SizedBox(height: 14),
        HonamPrimaryButton(
          label: l.offiAttach,
          onPressed: () => Navigator.of(context).pop(_phone.text.trim()),
        ),
      ],
    );
  }
}

/// Officine · 10. Écrire au coursier (canal `coursier`), et la même
/// discussion avec la patiente (canal `patient`).
///
/// Deux fils distincts : la patiente ne lit pas ce que l'officine dit au
/// coursier, ni l'inverse ; aucun numéro n'est montré.
class OfficineCourierChatScreen extends ConsumerStatefulWidget {
  const OfficineCourierChatScreen({
    super.key,
    required this.order,
    this.channel = 'coursier',
  });

  final OfficineOrder order;

  /// `coursier` ou `patient`.
  final String channel;

  bool get withPatient => channel == 'patient';

  ({int id, String channel}) get threadKey => (id: order.id, channel: channel);

  @override
  ConsumerState<OfficineCourierChatScreen> createState() =>
      _OfficineCourierChatScreenState();
}

class _OfficineCourierChatScreenState
    extends ConsumerState<OfficineCourierChatScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final body = (preset ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(officineRepositoryProvider)
          .sendMessage(widget.order.id, body, channel: widget.channel);
      if (preset == null) _text.clear();
      ref.invalidate(officineMessagesProvider(widget.threadKey));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = widget.order;
    final patient = officinePatient(context, order);
    final withPatient = widget.withPatient;
    // L'interlocuteur : la patiente, ou le coursier de la course.
    final courier = withPatient ? patient : order.courierName ?? l.honamCourier;
    final async = ref.watch(officineMessagesProvider(widget.threadKey));
    final messages = async.valueOrNull ?? const <HonamOrderMessage>[];
    final presets = withPatient
        ? const <String>[]
        : [l.offiQuickReady, l.offiQuickWhere, l.offiQuickThanks];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const PokouBackButton(),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.terracottaTint,
                    child: Text(
                      officineInitials(courier),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onTerracottaTint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courier,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          withPatient
                              ? l.offiChatPatientSubtitle
                              : l.offiChatSubtitle(patient),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const HonamHairline(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(officineMessagesProvider(widget.threadKey)),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            withPatient
                                ? l.offiChatPatientNotice(patient)
                                : l.offiChatNotice(patient),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (messages.isEmpty && async.isLoading)
                    const Center(child: CircularProgressIndicator()),
                  for (final message in messages) _Bubble(message: message),
                ],
              ),
            ),
          ),
          if (presets.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final preset in presets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(preset),
                        onPressed: () => _send(preset),
                      ),
                    ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: l.offiWriteTo(courier),
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l.offiSend,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                  ),
                  onPressed: _sending ? null : () => _send(),
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final HonamOrderMessage message;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final mine = message.senderRole == 'PHARMACY';
    final who = switch (message.senderRole) {
      'COURIER' => l.honamCourier,
      'PATIENT' => l.offiPatient,
      _ => null,
    };
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.accentPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine && who != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  message.senderName == null
                      ? who
                      : '${message.senderName} · $who',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                message.body,
                style: TextStyle(
                  color: mine ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              officineTime(context, message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white70 : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les défauts que l'officine peut signaler (maquette 11).
enum _Defect { late, damaged, originalMissing, behaviour, noShow }

/// Officine · 11. Signaler un défaut du coursier.
///
/// Le défaut est compté au coursier (règle des 3 défauts). Pendant la
/// course, la commande revient à « prête » pour un autre coursier.
class OfficineDefectScreen extends ConsumerStatefulWidget {
  const OfficineDefectScreen({super.key, required this.order});

  final OfficineOrder order;

  @override
  ConsumerState<OfficineDefectScreen> createState() =>
      _OfficineDefectScreenState();
}

class _OfficineDefectScreenState extends ConsumerState<OfficineDefectScreen> {
  _Defect? _defect;
  final _details = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send(String label) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final details = _details.text.trim();
    final reason = details.isEmpty ? label : '$label — $details';
    setState(() => _busy = true);
    try {
      await ref
          .read(officineRepositoryProvider)
          .act(
            widget.order.id,
            'courier-default',
            body: {
              'reason': reason.length > 255 ? reason.substring(0, 255) : reason,
            },
          );
      HapticFeedback.lightImpact();
      refreshOfficine(ref, widget.order.id);
      messenger.showSnackBar(SnackBar(content: Text(l.offiDefaultSent)));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = widget.order;
    final courier = order.courierName ?? l.honamCourier;
    final delivered = order.status == 'DELIVERED';
    final options = [
      if (!delivered) (_Defect.noShow, l.offiDefectNoShow),
      (_Defect.late, l.offiDefectLate),
      (_Defect.damaged, l.offiDefectDamaged),
      if (order.originalRequired)
        (_Defect.originalMissing, l.offiDefectOriginal),
      (_Defect.behaviour, l.offiDefectBehaviour),
    ];
    final selected = options.where((o) => o.$1 == _defect).firstOrNull;
    final date = order.deliveredAt ?? order.updatedAt ?? order.createdAt;
    return OfficinePage(
      title: l.offiDefectTitle,
      subtitle: l.offiCourseOf(courier, officineDate(context, date)),
      primary: HonamPrimaryButton(
        label: l.offiSendReport,
        busy: _busy,
        onPressed: selected == null ? null : () => _send(selected.$2),
      ),
      secondary: OfficineTextAction(
        label: l.actionCancel,
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        OfficineCardTitle(l.offiWhatHappened),
        for (final (value, label) in options)
          OfficineChoice<_Defect>(
            value: value,
            group: _defect,
            onChanged: (v) => setState(() => _defect = v),
            title: label,
          ),
        const SizedBox(height: 8),
        OfficineCardTitle(l.offiDetails),
        TextField(
          controller: _details,
          minLines: 2,
          maxLines: 5,
          maxLength: 200,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        OfficineNote(
          delivered
              ? l.offiDefectNoteDelivered(courier)
              : l.offiDefectNoteOngoing(courier),
          tone: CalloutTone.amber,
        ),
      ],
    );
  }
}

/// L'icône « Écrire à la patiente » de l'en-tête d'une commande (canal
/// `patient`).
class OfficinePatientChatButton extends StatelessWidget {
  const OfficinePatientChatButton({super.key, required this.order});

  final OfficineOrder order;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: L.of(context).offiChatWithPatient(officinePatient(context, order)),
    icon: const Icon(Icons.chat_bubble_outline, color: AppColors.accentPrimary),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            OfficineCourierChatScreen(order: order, channel: 'patient'),
      ),
    ),
  );
}
