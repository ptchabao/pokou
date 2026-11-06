import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';

/// Les documents légaux, lus DANS l'application (section 8.1), servis par
/// l'API pour qu'une correction n'attende pas une revue de store.
final legalDocumentProvider = FutureProvider.autoDispose
    .family<({String title, String body}), String>((ref, name) async {
      final json =
          await ref
                  .watch(apiClientProvider)
                  .get('/legal/$name', authenticated: false)
              as Map<String, dynamic>;
      return (title: json['title'] as String, body: json['body'] as String);
    });

class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.name});

  /// `conditions` ou `confidentialite`.
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final doc = ref.watch(legalDocumentProvider(name));
    return ModuleScaffold(
      title: doc.valueOrNull?.title ??
          (name == 'conditions' ? l.legalTerms : l.legalPrivacy),
      child: doc.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.description_outlined,
          title: l.legalUnavailable,
          message: l.modulesCheckNetwork,
        ),
        data: (doc) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // REG-12 / REG-13 : « L’essentiel » d'abord, en quatre phrases,
            // puis le texte complet servi par l'API.
            _Essentials(
              lines: name == 'conditions'
                  ? [l.termsE1, l.termsE2, l.termsE3, l.termsE4]
                  : [l.privacyE1, l.privacyE2, l.privacyE3, l.privacyE4],
            ),
            const SizedBox(height: 20),
            Text(
              l.legalFullText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            for (final line in doc.body.split('\n').skip(1))
              _MarkdownLine(line),
          ],
        ),
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
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          text.substring(3),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
        child: Text('•  ${text.substring(2)}', style: const TextStyle(fontSize: 15)),
      );
    }
    return Text(text, style: const TextStyle(fontSize: 15, height: 1.45));
  }
}

class _Essentials extends StatelessWidget {
  const _Essentials({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L.of(context).legalEssentials,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
