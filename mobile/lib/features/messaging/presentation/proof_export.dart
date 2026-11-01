import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/direct_message_model.dart';

/// L'export daté d'une discussion à deux en mode preuve (maquettes 8 et 9).
///
/// Produit SUR le téléphone, et c'est la seule façon de le faire : les
/// messages sont chiffrés de bout en bout, le serveur n'en a jamais lu le
/// texte. Le PDF reprend ce que cet appareil a gardé — messages, versions
/// d'origine, suppressions — depuis l'activation.
///
/// Inter, embarquée dans l'application, et non la police par défaut du
/// PDF : celle-ci ne couvre que le latin de base, et un « ɛ » ou un « ɔ »
/// éwé disparaîtrait de la preuve.
Future<File> exportDirectProof({
  required String contactName,
  required String myName,
  required int myUserId,
  required DateTime since,
  required List<DirectMessage> messages,
  required ProofExportLabels labels,
}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'));
  final stamp = DateFormat('dd/MM/yyyy HH:mm');
  final now = DateTime.now();
  final kept = [
    for (final m in messages)
      if (!m.createdAt.isBefore(since) && (m.payload?['kind']) != 'proof_mode') m,
  ];

  final doc = pw.Document(title: labels.title, author: 'Pokou');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(labels.title, style: pw.TextStyle(font: bold, fontSize: 16)),
          pw.Text(labels.between(myName, contactName), style: const pw.TextStyle(fontSize: 11)),
          pw.Text(labels.period(stamp.format(since.toLocal()), stamp.format(now)),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Text(
        labels.footer(context.pageNumber, context.pagesCount),
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
      build: (_) => [
        for (final m in kept)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${stamp.format(m.createdAt.toLocal())} · ${m.senderId == myUserId ? myName : contactName}',
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
                pw.Text(
                  m.content ?? labels.attachment,
                  style: pw.TextStyle(
                    fontSize: 10,
                    decoration: m.deletedAt != null ? pw.TextDecoration.lineThrough : null,
                  ),
                ),
                if (m.originalContent != null)
                  pw.Text(labels.original(m.originalContent!),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (m.editedAt != null)
                  pw.Text(labels.edited(stamp.format(m.editedAt!.toLocal())),
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                if (m.deletedAt != null)
                  pw.Text(labels.deleted(stamp.format(m.deletedAt!.toLocal())),
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700)),
              ],
            ),
          ),
      ],
    ),
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/pokou-preuve-${DateFormat('yyyyMMdd-HHmm').format(now)}.pdf');
  return file.writeAsBytes(await doc.save(), flush: true);
}

/// Les textes du PDF, traduits par l'écran qui l'appelle : ce fichier ne
/// dépend pas du contexte Flutter.
class ProofExportLabels {
  const ProofExportLabels({
    required this.title,
    required this.between,
    required this.period,
    required this.footer,
    required this.attachment,
    required this.original,
    required this.edited,
    required this.deleted,
  });

  final String title;
  final String Function(String me, String contact) between;
  final String Function(String since, String now) period;
  final String Function(int page, int pages) footer;
  final String attachment;
  final String Function(String text) original;
  final String Function(String at) edited;
  final String Function(String at) deleted;
}
