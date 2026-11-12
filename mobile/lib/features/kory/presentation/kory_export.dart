import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Une ligne exportée : quand, et ce qui s'est passé.
class KoryExportLine {
  const KoryExportLine(this.at, this.text, {this.columns = const []});

  final DateTime? at;
  final String text;

  /// Les colonnes du CSV après la date (qui, montant, statut…). Vide : la
  /// seule phrase.
  final List<String> columns;
}

String _slug(String title) {
  final clean = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return clean.isEmpty ? 'kory' : clean;
}

String _stamp() => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

/// Le CSV du journal (KOR-9), produit sur le téléphone et partagé comme
/// n'importe quel fichier. Séparateur « ; » : c'est ce qu'attend un tableur
/// réglé en français.
Future<void> koryShareCsv({
  required String title,
  required List<String> header,
  required List<KoryExportLine> lines,
}) async {
  String cell(String value) => '"${value.replaceAll('"', '""')}"';
  final stamp = DateFormat('yyyy-MM-dd HH:mm');
  final buffer = StringBuffer()..writeln(header.map(cell).join(';'));
  for (final line in lines) {
    buffer.writeln(
      [
        line.at == null ? '' : stamp.format(line.at!.toLocal()),
        if (line.columns.isEmpty) line.text else ...line.columns,
      ].map(cell).join(';'),
    );
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/pokou-${_slug(title)}-${_stamp()}.csv');
  // Le BOM fait reconnaître l'UTF-8 aux tableurs (accents, « • »).
  await file.writeAsString('﻿$buffer', flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
}

/// Le PDF du journal ou du rapport (KOR-9, KOR-29). Inter, embarquée dans
/// l'application : la police par défaut du PDF ne couvre que le latin de
/// base, et un nom éwé y perdrait ses lettres.
Future<void> korySharePdf({
  required String title,
  required String subtitle,
  required String footer,
  required List<KoryExportLine> lines,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'),
  );
  final stamp = DateFormat('dd/MM/yyyy HH:mm');
  final doc = pw.Document(title: title, author: 'Pokou');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 16)),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            stamp.format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Divider(),
        ],
      ),
      footer: (_) => pw.Text(
        footer,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
      build: (_) => [
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(line.text, style: const pw.TextStyle(fontSize: 10)),
                if (line.at != null)
                  pw.Text(
                    stamp.format(line.at!.toLocal()),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/pokou-${_slug(title)}-${_stamp()}.pdf');
  await file.writeAsBytes(await doc.save(), flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
}
