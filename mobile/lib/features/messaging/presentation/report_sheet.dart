import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/data/conversations_repository.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../contacts/presentation/discussions_controller.dart';

/// Les motifs proposés, dans l'ordre de la maquette (Discussions · 16).
enum ReportReason { scam, impersonation, spam, shocking, other }

extension ReportReasonLabel on ReportReason {
  String labelOf(L l) => switch (this) {
    ReportReason.scam => l.reportReasonScam,
    ReportReason.impersonation => l.reportReasonImpersonation,
    ReportReason.spam => l.reportReasonSpam,
    ReportReason.shocking => l.reportReasonShocking,
    ReportReason.other => l.reportReasonOther,
  };
}

/// Ce que le signalement a produit.
typedef ReportOutcome = ({bool blocked});

/// Discussions · 16 — Signaler une personne ou un groupe.
///
/// ── Ce qui part, et rien d'autre ─────────────────────────────────────
///
/// Le motif choisi — et, SEULEMENT si la personne coche la case prévue
/// (décochée par défaut), les 5 derniers messages de la discussion
/// ([recentMessages]) tels que CET appareil les a déchiffrés. Le serveur
/// les chiffre au repos et ne les rend lisibles qu'à l'équipe qui traite le
/// signalement. Sans la case, aucun message ne part.
///
/// « Bloquer aussi ce numéro » n'est proposé que pour une personne
/// ([contactUserId]) : un groupe se quitte, il ne se bloque pas.
Future<ReportOutcome?> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  int? contactUserId,
  int? groupId,
  List<ReportedMessage> recentMessages = const [],
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = L.of(context);
  final choice =
      await showModalBottomSheet<
        ({ReportReason reason, bool block, bool attach})
      >(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.bottomSheet,
        ),
        builder: (_) => _ReportSheet(
          title: title,
          offerBlock: contactUserId != null,
          offerMessages: recentMessages.isNotEmpty,
        ),
      );
  if (choice == null) return null;
  try {
    await ref
        .read(conversationsRepositoryProvider)
        .report(
          contactUserId: contactUserId,
          groupId: groupId,
          // Le libellé FRANÇAIS du motif, quelle que soit la langue de
          // l'écran : c'est l'équipe Pokou qui le lit.
          reason: _reasonForSupport(choice.reason),
          alsoBlock: choice.block,
          // Rien sans la case cochée — le serveur le refuserait de toute
          // façon.
          recentMessages: choice.attach ? recentMessages : const [],
          consent: choice.attach,
        );
  } on ApiException catch (exc) {
    messenger.showSnackBar(SnackBar(content: Text(exc.message)));
    return null;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.reportFailed)));
    return null;
  }
  if (choice.block) {
    ref.invalidate(discussionsProvider);
    ref.invalidate(contactsProvider);
  }
  messenger.showSnackBar(
    SnackBar(content: Text(choice.block ? l.reportSentBlocked : l.reportSent)),
  );
  return (blocked: choice.block);
}

/// Les 5 derniers messages LISIBLES d'une discussion à deux, relus du cache
/// local (où ils sont déjà déchiffrés). Un message resté chiffré ou un média
/// sans légende part sous son type : le support voit qu'il y avait quelque
/// chose, sans plus.
Future<List<ReportedMessage>> recentDirectForReport(
  WidgetRef ref, {
  required int myUserId,
  required int contactUserId,
  required String contactName,
}) async {
  try {
    final cached = await ref
        .read(pokouMessageStoreProvider)
        .directConversation(myUserId: myUserId, contactUserId: contactUserId);
    final messages = cached.messages
        .where((m) => !PokouMessageStore.isLocalId(m.id))
        .toList();
    return [
      for (final m in messages.skip(
        messages.length > 5 ? messages.length - 5 : 0,
      ))
        ReportedMessage(
          // Pour l'équipe Pokou, qui lit en français.
          sender: m.senderId == myUserId ? 'Moi' : contactName,
          text: _readable(m.content, m.messageType, locked: m.isEncrypted),
          sentAt: m.createdAt,
        ),
    ];
  } catch (_) {
    // Sans cache lisible, le signalement part quand même — avec le motif.
    return const [];
  }
}

/// La même chose pour un groupe.
Future<List<ReportedMessage>> recentGroupForReport(
  WidgetRef ref, {
  required int groupId,
  required int myUserId,
}) async {
  try {
    final cached = await ref
        .read(pokouMessageStoreProvider)
        .groupConversation(groupId);
    final messages = cached.messages
        .where((m) => !PokouMessageStore.isLocalId(m.id))
        .toList();
    return [
      for (final m in messages.skip(
        messages.length > 5 ? messages.length - 5 : 0,
      ))
        ReportedMessage(
          sender: m.senderId == myUserId ? 'Moi' : m.senderName,
          text: _readable(m.content, m.messageType, locked: m.isEncrypted),
          sentAt: m.createdAt,
        ),
    ];
  } catch (_) {
    return const [];
  }
}

String _readable(String? content, String messageType, {required bool locked}) {
  final text = content?.trim() ?? '';
  if (!locked && text.isNotEmpty) return text;
  return '[$messageType]';
}

String _reasonForSupport(ReportReason reason) => switch (reason) {
  ReportReason.scam => "Arnaque ou demande d'argent",
  ReportReason.impersonation => "Se fait passer pour quelqu'un",
  ReportReason.spam => 'Spam ou publicité',
  ReportReason.shocking => 'Contenu choquant',
  ReportReason.other => 'Autre',
};

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.title,
    required this.offerBlock,
    required this.offerMessages,
  });

  final String title;
  final bool offerBlock;

  /// Il y a des messages à joindre : la case de consentement s'affiche.
  final bool offerMessages;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason _reason = ReportReason.scam;

  /// Coché par défaut : l'immense majorité des signalements s'accompagne
  /// d'un blocage, et c'est le choix le plus protecteur.
  bool _block = true;

  /// Le consentement à joindre les messages : DÉCOCHÉ par défaut.
  bool _attach = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: RadioGroup<ReportReason>(
                  groupValue: _reason,
                  onChanged: (value) {
                    if (value != null) setState(() => _reason = value);
                  },
                  child: Column(
                    children: [
                      for (final reason in ReportReason.values) ...[
                        if (reason != ReportReason.values.first)
                          Divider(height: 1, color: AppColors.border),
                        RadioListTile<ReportReason>(
                          value: reason,
                          activeColor: AppColors.accentPrimary,
                          title: Text(
                            reason.labelOf(l),
                            style: const TextStyle(fontSize: 14.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.accentPrimaryDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.reportNote,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.offerMessages)
                CheckboxListTile(
                  value: _attach,
                  onChanged: (value) =>
                      setState(() => _attach = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.accentPrimary,
                  title: Text(
                    l.reportAttachConsent,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              if (widget.offerBlock)
                CheckboxListTile(
                  value: _block,
                  onChanged: (value) => setState(() => _block = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.accentPrimary,
                  title: Text(
                    l.reportAlsoBlock,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.semanticError,
                  ),
                  onPressed: () => Navigator.pop(context, (
                    reason: _reason,
                    block: widget.offerBlock && _block,
                    attach: widget.offerMessages && _attach,
                  )),
                  child: Text(l.reportSend),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.actionCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
