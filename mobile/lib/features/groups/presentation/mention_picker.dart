import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../data/group_model.dart';

/// Le mot en cours de frappe s'il commence par « @ » — `null` sinon.
///
/// Seul le texte AVANT le curseur compte : corriger un mot plus haut dans
/// le message ne doit pas ouvrir le sélecteur.
String? mentionQueryAt(TextEditingValue value) {
  final cursor = value.selection.baseOffset;
  if (cursor < 0 || cursor > value.text.length) return null;
  final before = value.text.substring(0, cursor);
  final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(before);
  return match?.group(1);
}

/// Remplace « @début » au curseur par « @Nom » suivi d'une espace.
TextEditingValue insertMention(TextEditingValue value, String name) {
  final cursor = value.selection.baseOffset;
  final before = value.text.substring(0, cursor);
  final at = before.lastIndexOf('@');
  final replaced = '${before.substring(0, at)}@$name ';
  final text = replaced + value.text.substring(cursor);
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: replaced.length),
  );
}

/// Discussions · 20 — « Mentionner », au-dessus de la saisie, dès qu'on tape
/// « @ » dans un groupe. Les membres dont le nom contient ce qui suit le
/// « @ », moi exclu, cinq au plus.
class MentionPicker extends StatelessWidget {
  const MentionPicker({
    super.key,
    required this.query,
    required this.members,
    required this.myUserId,
    required this.onPick,
  });

  final String query;
  final List<GroupMember> members;
  final int myUserId;
  final ValueChanged<GroupMember> onPick;

  @override
  Widget build(BuildContext context) {
    final needle = query.toLowerCase();
    final candidates = members
        .where(
          (m) =>
              m.userId != myUserId &&
              m.displayName.toLowerCase().contains(needle),
        )
        .take(5)
        .toList();
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              L.of(context).mentionPickerTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          for (final member in candidates)
            ListTile(
              dense: true,
              leading: ContactAvatar(
                avatar: null,
                displayName: member.displayName,
                size: 28,
              ),
              title: Text(
                member.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => onPick(member),
            ),
        ],
      ),
    );
  }
}
