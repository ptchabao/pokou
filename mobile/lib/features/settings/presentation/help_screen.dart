import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/presentation/chat_controller.dart' show kNoMonitor;
import '../../../core/widgets/pokou_context_menu.dart';

/// REG-10 · Aide et support (MSG-22).
///
/// La recherche filtre les questions fréquentes sur place : elles sont peu
/// nombreuses, et une aide qui part chercher sur le réseau ne sert à rien
/// quand c'est justement le réseau qui manque.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final faq = <(String, String)>[
      (l.helpQMoney, l.helpAMoney),
      (l.helpQProof, l.helpAProof),
      (l.helpQSms, l.helpASms),
      (l.helpQCourier, l.helpACourier),
      (l.helpQScam, l.helpAScam),
    ];
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? faq
        : faq
              .where(
                (e) =>
                    e.$1.toLowerCase().contains(q) ||
                    e.$2.toLowerCase().contains(q),
              )
              .toList();

    void openBaba() =>
        context.push('/chat/$kNoMonitor', extra: l.navBaba);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: l.helpSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: AppColors.chatAiIconColor,
              ),
              title: Text(l.helpAskBaba),
              subtitle: Text(l.helpAskBabaSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: openBaba,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.helpFaqTitle,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          _Card(
            child: shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l.helpNoResult,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: [
                      for (final (question, answer) in shown)
                        ExpansionTile(
                          title: Text(question),
                          shape: const Border(),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            14,
                          ),
                          expandedAlignment: Alignment.centerLeft,
                          children: [
                            Text(
                              answer,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: Text(l.helpSupport),
                  subtitle: Text(l.helpSupportSub),
                  trailing: const Icon(Icons.chevron_right),
                  // Le support répond dans l'application, par l'assistant,
                  // qui transmet à l'équipe ce qu'il ne sait pas résoudre.
                  onTap: openBaba,
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l.helpReport),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: openBaba,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
