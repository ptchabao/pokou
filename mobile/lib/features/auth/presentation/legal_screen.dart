import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/country/country_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../../../core/widgets/skeleton.dart';

/// Un document légal tel que l'API le sert : le Markdown, et sa version
/// (« 2026-10 », la même que celle acceptée à l'inscription).
typedef LegalDocument = ({String title, String body, String? version});

/// Les documents légaux, lus DANS l'application (section 8.1), servis par
/// l'API pour qu'une correction n'attende pas une revue de store.
final legalDocumentProvider = FutureProvider.autoDispose
    .family<LegalDocument, String>((ref, name) async {
      final json =
          await ref
                  .watch(apiClientProvider)
                  .get('/legal/$name', authenticated: false)
              as Map<String, dynamic>;
      return (
        title: json['title'] as String,
        body: json['body'] as String,
        version: json['version'] as String?,
      );
    });

/// Un chapitre du texte complet : un titre `## …` et ses lignes.
class LegalChapter {
  const LegalChapter(this.title, this.lines);

  /// Sans son numéro d'origine : la liste est renumérotée à l'affichage,
  /// une fois retirés les chapitres des services fermés.
  final String title;
  final List<String> lines;
}

/// Les modules dont un chapitre ou une ligne peut parler — retirés au
/// lot 1, où ces services ne sont pas ouverts.
const _moduleWords = ['kory', 'honam', 'assimé', 'assime'];

bool _mentionsModule(String text) {
  final lower = text.toLowerCase();
  return _moduleWords.any(lower.contains);
}

/// Découpe le Markdown : le préambule (avant le premier `##`), puis les
/// chapitres. Au lot 1, les chapitres et les puces consacrés aux services
/// fermés disparaissent — le texte ne parle que de ce qui est ouvert.
({List<String> preamble, List<LegalChapter> chapters}) parseLegal(
  String body, {
  required bool lot1,
}) {
  final preamble = <String>[];
  final chapters = <LegalChapter>[];
  String? title;
  var lines = <String>[];
  void close() {
    final current = title;
    if (current != null && !(lot1 && _mentionsModule(current))) {
      chapters.add(LegalChapter(current, lines));
    }
  }

  for (final line in body.split('\n').skip(1)) {
    if (line.startsWith('## ')) {
      close();
      title = line.substring(3).replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
      lines = <String>[];
    } else if (title == null) {
      preamble.add(line);
    } else if (!(lot1 && line.startsWith('- ') && _mentionsModule(line))) {
      lines.add(line);
    }
  }
  close();
  return (preamble: preamble, chapters: chapters);
}

class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.name});

  /// `conditions` ou `confidentialite`.
  final String name;

  bool get _terms => name == 'conditions';

  /// « 2026-10 » → « octobre 2026 ». La version EST la date de mise à
  /// jour : c'est elle qu'on accepte à l'inscription.
  static String? updatedOn(String? version, String locale) {
    final match = RegExp(r'^(\d{4})-(\d{2})').firstMatch(version ?? '');
    if (match == null) return null;
    final date = DateTime(int.parse(match[1]!), int.parse(match[2]!));
    return DateFormat.yMMMM(locale).format(date);
  }

  /// REG-12 / REG-13 : « L'essentiel », en quelques phrases et chacune avec
  /// son icône. Au lot 1, sans argent, coursier ni annonce.
  List<(IconData, String)> _essentials(L l, bool lot1) {
    if (_terms) {
      return lot1
          ? [
              (Icons.history, l.termsE2),
              (Icons.chat_bubble_outline, l.termsLot1Messaging),
              (Icons.receipt_long_outlined, l.termsE4),
            ]
          : [
              (Icons.savings_outlined, l.termsE1),
              (Icons.history, l.termsE2),
              (Icons.warning_amber_rounded, l.termsE3),
              (Icons.receipt_long_outlined, l.termsE4),
            ];
    }
    return lot1
        ? [
            (Icons.phone_outlined, l.privacyLot1Numbers),
            (Icons.shield_outlined, l.privacyE2),
            (Icons.map_outlined, l.privacyLot1Codes),
          ]
        : [
            (Icons.phone_outlined, l.privacyE1),
            (Icons.shield_outlined, l.privacyE2),
            (Icons.map_outlined, l.privacyE3),
            (Icons.shopping_bag_outlined, l.privacyE4),
          ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final lot1 = isLot1(ref.watch(currentCountryConfigProvider).modules);
    final doc = ref.watch(legalDocumentProvider(name));
    final updated = updatedOn(doc.valueOrNull?.version, locale);
    return ModuleScaffold(
      title: _terms ? l.legalTerms : l.legalPrivacy,
      subtitle: updated == null ? null : l.legalUpdatedOn(updated),
      child: doc.when(
        loading: () => const SkeletonCards(),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.description_outlined,
          title: l.legalUnavailable,
          message: l.modulesCheckNetwork,
        ),
        data: (doc) {
          final parsed = parseLegal(doc.body, lot1: lot1);
          final preamble = parsed.preamble
              .where((line) => line.trim().isNotEmpty)
              .map((line) => line.replaceFirst(RegExp(r'^>\s?'), ''))
              .join(' ')
              .replaceAll('**', '')
              .trim();
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _SectionTitle(l.legalEssentials),
                    _Essentials(lines: _essentials(l, lot1)),
                    const SizedBox(height: 20),
                    _SectionTitle(l.legalFullText),
                    _Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < parsed.chapters.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: AppColors.border),
                            ListTile(
                              title: Text(
                                '${i + 1}. ${parsed.chapters[i].title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _ChapterScreen(
                                    title:
                                        '${i + 1}. ${parsed.chapters[i].title}',
                                    lines: parsed.chapters[i].lines,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (preamble.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        preamble,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l.legalDownloadPdf),
                  onPressed: () => _sharePdf(
                    context,
                    title: doc.title,
                    updated: updated == null ? null : l.legalUpdatedOn(updated),
                    chapters: parsed.chapters,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Le PDF est produit SUR le téléphone à partir du texte servi par l'API
  /// — le même que celui affiché — puis confié à la feuille de partage.
  /// Inter embarquée : la police par défaut du PDF perdrait les accents.
  Future<void> _sharePdf(
    BuildContext context, {
    required String title,
    required String? updated,
    required List<LegalChapter> chapters,
  }) async {
    final failed = L.of(context).legalPdfFailed;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'),
      );
      final doc = pw.Document(title: title, author: 'Pokou');
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          build: (_) => [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if (updated != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4, bottom: 12),
                child: pw.Text(updated, style: const pw.TextStyle(fontSize: 10)),
              ),
            for (var i = 0; i < chapters.length; i++) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
                child: pw.Text(
                  '${i + 1}. ${chapters[i].title}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              for (final line in chapters[i].lines)
                if (line.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      line.startsWith('- ')
                          ? '•  ${line.substring(2).replaceAll('**', '')}'
                          : line.replaceAll('**', ''),
                      style: const pw.TextStyle(fontSize: 10.5),
                    ),
                  ),
            ],
          ],
        ),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pokou-$name.pdf');
      await file.writeAsBytes(await doc.save(), flush: true);
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/pdf'),
      ], subject: title);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

/// Un chapitre, en entier.
class _ChapterScreen extends StatelessWidget {
  const _ChapterScreen({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [for (final line in lines) _MarkdownLine(line)],
      ),
    );
  }
}

/// Le strict nécessaire du Markdown de ces documents : titres, citations,
/// listes, gras. Une dépendance de rendu Markdown pour deux pages de texte
/// ne se justifiait pas.
class _MarkdownLine extends StatelessWidget {
  const _MarkdownLine(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    final text = line.replaceAll('**', '');
    if (line.trim().isEmpty) return const SizedBox(height: 8);
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          text.substring(4),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (line.startsWith('> ')) {
      return Container(
        padding: const EdgeInsets.all(10),
        color: AppColors.surfaceElevated,
        child: Text(text.substring(2), style: const TextStyle(fontSize: 14)),
      );
    }
    if (line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 4),
        child: Text(
          '•  ${text.substring(2)}',
          style: const TextStyle(fontSize: 15),
        ),
      );
    }
    return Text(text, style: const TextStyle(fontSize: 15, height: 1.45));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
      width: double.infinity,
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

class _Essentials extends StatelessWidget {
  const _Essentials({required this.lines});

  final List<(IconData, String)> lines;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icon, line) in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        icon,
                        size: 17,
                        color: AppColors.accentPrimaryDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
