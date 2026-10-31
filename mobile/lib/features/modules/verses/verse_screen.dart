import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/l10n_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'verse_data.dart';

/// L'écran d'un module de versets : le verset de ce matin et celui de ce
/// soir — les mêmes que les notifications.
///
/// Ouvert depuis le catalogue des modules, ou en touchant une notification ;
/// dans ce cas, le verset de la notification est mis en avant.
class VerseScreen extends ConsumerStatefulWidget {
  const VerseScreen({super.key, required this.kind, this.focusSlot});

  final VerseKind kind;

  /// 0 (matin) ou 1 (soir) : le verset de la notification touchée.
  final int? focusSlot;

  @override
  ConsumerState<VerseScreen> createState() => _VerseScreenState();
}

class _VerseScreenState extends ConsumerState<VerseScreen> {
  Future<List<Verse>>? _verses;
  String? _language;

  Color get _accent => widget.kind == VerseKind.bible
      ? const Color(0xFF7C3AED)
      : const Color(0xFF0F766E);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = ref.read(appL10nProvider).localeName.split('_').first;
    if (language != _language) {
      _language = language;
      _verses = loadVerses(widget.kind, language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final title = widget.kind == VerseKind.bible
        ? l.versesBibleTitle
        : l.versesQuranTitle;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: FutureBuilder<List<Verse>>(
        future: _verses,
        builder: (context, snapshot) {
          final verses = snapshot.data;
          if (verses == null || verses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          Verse at(int slot) =>
              verses[verseIndexFor(today, slot, verses.length)];
          final cards = [
            _VerseCard(
              label: l.versesThisMorning,
              icon: Icons.wb_sunny_outlined,
              verse: at(0),
              accent: _accent,
              focused: widget.focusSlot == 0,
            ),
            _VerseCard(
              label: l.versesThisEvening,
              icon: Icons.nightlight_outlined,
              verse: at(1),
              accent: _accent,
              focused: widget.focusSlot == 1,
            ),
          ];
          // Le verset de la notification touchée passe en premier.
          if (widget.focusSlot == 1) cards.insert(0, cards.removeAt(1));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.kind == VerseKind.bible
                          ? Icons.menu_book
                          : Icons.auto_stories,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.versesSchedule,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.versesOfflineHint,
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
              const SizedBox(height: 20),
              for (final card in cards) ...[card, const SizedBox(height: 16)],
            ],
          );
        },
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({
    required this.label,
    required this.icon,
    required this.verse,
    required this.accent,
    required this.focused,
  });

  final String label;
  final IconData icon;
  final Verse verse;
  final Color accent;
  final bool focused;

  String get _shareText => [
    if (verse.arabic != null) verse.arabic!,
    verse.text,
    '— ${verse.reference}',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: focused ? accent : AppColors.border,
          width: focused ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // L'arabe d'abord, à droite, en grand : c'est le texte ; la
          // traduction l'accompagne.
          if (verse.arabic != null) ...[
            Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  verse.arabic!,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.8,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            verse.text,
            style: TextStyle(
              fontSize: 18,
              height: 1.5,
              fontFamily: 'serif',
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            verse.reference,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: l.aiCopy,
                icon: Icon(Icons.copy_rounded, color: AppColors.textSecondary),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _shareText));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.aiCopied),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: l.versesShare,
                icon: Icon(
                  Icons.share_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Share.share(_shareText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
