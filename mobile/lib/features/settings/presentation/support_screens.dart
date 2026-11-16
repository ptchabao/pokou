import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../data/support_repository.dart';
import 'settings_widgets.dart';

/// Le texte d'erreur d'un envoi refusé : trop de demandes (429), ou le
/// réseau. Le reste du détail serveur n'est pas traduit, on ne l'affiche pas.
String _sendError(L l, Object error) =>
    error is ApiException && error.statusCode == 429
    ? l.supportTooMany
    : l.supportFailed;

/// REG-10 · « Écrire au support » : un message libre à l'équipe Pokou — et
/// non à Baba —, puis la liste de mes demandes, leur état et la réponse de
/// l'équipe, qui arrive ici (« Réponse dans l'application »).
class SupportContactScreen extends ConsumerStatefulWidget {
  const SupportContactScreen({super.key});

  @override
  ConsumerState<SupportContactScreen> createState() =>
      _SupportContactScreenState();
}

class _SupportContactScreenState extends ConsumerState<SupportContactScreen> {
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _message.text.trim();
    if (text.length < 10) {
      messenger.showSnackBar(SnackBar(content: Text(l.supportTooShort)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .create(kind: 'SUPPORT', description: text);
      _message.clear();
      ref.invalidate(mySupportTicketsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l.supportSent)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_sendError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tickets = ref.watch(mySupportTicketsProvider);
    return SettingsScaffold(
      title: l.helpSupport,
      onRefresh: () async {
        ref.invalidate(mySupportTicketsProvider);
        await ref.read(mySupportTicketsProvider.future);
      },
      children: [
        SettingsFootnote(l.supportContactIntro),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l.supportMessageHint,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SendButton(
            label: l.supportSend,
            busy: _busy,
            onPressed: _send,
          ),
        ),
        SettingsSectionTitle(l.supportMyRequests),
        tickets.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SettingsFootnote(l.supportLoadFailed),
          data: (items) => items.isEmpty
              ? SettingsFootnote(l.supportNoRequests)
              : SettingsCard(
                  children: [for (final t in items) _TicketTile(ticket: t)],
                ),
        ),
      ],
    );
  }
}

/// Une demande dans « Mes demandes » : sa nature, son état, son texte et,
/// s'il y en a une, la réponse de l'équipe.
class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (statusLabel, statusColor) = switch (ticket.status) {
      'ANSWERED' => (l.supportStatusAnswered, AppColors.feedbackSuccess),
      'CLOSED' => (l.supportStatusClosed, AppColors.textMuted),
      _ => (l.supportStatusOpen, AppColors.accentPrimary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ticket.isProblem
                    ? Icons.flag_outlined
                    : Icons.chat_bubble_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ticket.isProblem
                      ? l.supportKindProblem
                      : l.supportKindQuestion,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.supportSentOn(
              DateFormat.yMMMMd(locale).format(ticket.createdAt.toLocal()),
            ),
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (ticket.description != null) ...[
            const SizedBox(height: 8),
            Text(
              ticket.description!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (ticket.reply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.supportReplyLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(ticket.reply!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// REG-10 · « Signaler un problème » : une catégorie, une description, une
/// capture d'écran facultative ; la version de l'application et le système
/// du téléphone sont joints. Rien des discussions : elles sont chiffrées.
class ReportProblemScreen extends ConsumerStatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  ConsumerState<ReportProblemScreen> createState() =>
      _ReportProblemScreenState();
}

class _ReportProblemScreenState extends ConsumerState<ReportProblemScreen> {
  final _description = TextEditingController();
  String? _category;
  XFile? _screenshot;
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (photo != null && mounted) setState(() => _screenshot = photo);
  }

  Future<void> _send() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _description.text.trim();
    if (text.length < 10) {
      messenger.showSnackBar(SnackBar(content: Text(l.supportTooShort)));
      return;
    }
    setState(() => _busy = true);
    try {
      int? mediaId;
      final shot = _screenshot;
      if (shot != null) {
        // La capture part en clair vers l'équipe : ce n'est pas un message.
        final upload = await ref
            .read(mediaRepositoryProvider)
            .upload(
              bytes: await File(shot.path).readAsBytes(),
              filename: 'capture.jpg',
              mimeType: 'image/jpeg',
              messageType: 'IMAGE',
              memoriser: false,
            );
        mediaId = upload.id;
      }
      await ref
          .read(supportRepositoryProvider)
          .create(
            kind: 'PROBLEM',
            category: _category!,
            description: text,
            screenshotMediaId: mediaId,
          );
      ref.invalidate(mySupportTicketsProvider);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_sendError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (_sent) return _ProblemSent(title: l.helpReport);
    final categories = {
      'ACCOUNT': l.supportCategoryAccount,
      'MESSAGES': l.supportCategoryMessages,
      'CALLS': l.supportCategoryCalls,
      'NOTIFICATIONS': l.supportCategoryNotifications,
      'CRASH': l.supportCategoryCrash,
      'OTHER': l.supportCategoryOther,
    };
    final shot = _screenshot;
    return SettingsScaffold(
      title: l.helpReport,
      children: [
        SettingsFootnote(l.supportProblemIntro),
        SettingsSectionTitle(l.supportCategoryLabel),
        SettingsCard(
          children: [
            RadioGroup<String>(
              groupValue: _category,
              onChanged: (v) => setState(() => _category = v),
              // Un Material à elles : sans lui, le fond de la carte
              // masquerait l'effet du toucher.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (final code in supportProblemCategories)
                      RadioListTile<String>(
                        value: code,
                        title: Text(categories[code]!),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SettingsSectionTitle(l.supportDescriptionLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _description,
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.supportDescriptionHint,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.add_photo_alternate_outlined,
              label: l.supportScreenshotAdd,
              subtitle: shot == null ? l.supportScreenshotOptional : shot.name,
              onTap: _busy ? null : _pickScreenshot,
              trailing: shot == null
                  ? null
                  : TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _screenshot = null),
                      child: Text(l.supportScreenshotRemove),
                    ),
            ),
            if (shot != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(shot.path),
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsNote(text: l.supportDiagnosticsNote),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SendButton(
            label: l.supportSend,
            busy: _busy,
            onPressed: _category == null || _description.text.trim().isEmpty
                ? null
                : _send,
          ),
        ),
      ],
    );
  }
}

/// La confirmation, à la place du formulaire : ce qui a été envoyé et où
/// en suivre l'état.
class _ProblemSent extends StatelessWidget {
  const _ProblemSent({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SettingsScaffold(
      title: title,
      children: [
        const SizedBox(height: 40),
        const Icon(
          Icons.check_circle_outline,
          size: 56,
          color: AppColors.feedbackSuccess,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l.supportProblemSentTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l.supportProblemSentBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SendButton(
            label: l.supportDone,
            busy: false,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
