import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/widgets/verified_badge.dart';
import 'package:pokou/features/messaging/presentation/proof_export_screens.dart';
import 'package:pokou/features/messaging/presentation/proof_sheets.dart';
import 'package:pokou/features/messaging/presentation/proof_widgets.dart';

import '../../helpers/localized_harness.dart';

void main() {
  group('Deux badges, deux formes', () {
    testWidgets('la rosette dit « Compte certifié », l\'hexagone « Pokou certifié Pro »', (tester) async {
      await tester.pumpWidget(localizedHarness(const Row(
        children: [VerifiedBadge(size: 16), VerifiedBadge(size: 16, pro: true)],
      )));
      expect(find.bySemanticsLabel('Compte certifié'), findsOneWidget);
      expect(find.bySemanticsLabel('Pokou certifié Pro'), findsOneWidget);
    });

    testWidgets('VerifiedName passe la forme Pro au badge', (tester) async {
      await tester.pumpWidget(localizedHarness(
        const VerifiedName(name: 'Boutique Mensah', isVerified: true, isPro: true),
      ));
      final badge = tester.widget<VerifiedBadge>(find.byType(VerifiedBadge));
      expect(badge.pro, isTrue);
    });
  });

  testWidgets('le bandeau nomme qui a activé le mode preuve et ouvre « En savoir plus »', (tester) async {
    await tester.pumpWidget(localizedHarness(
      ProofModeBanner(activatedBy: 'Afi', onLearnMore: () {}),
    ));
    expect(find.textContaining('Mode preuve activé par Afi.', findRichText: true), findsOneWidget);
    expect(find.textContaining('En savoir plus', findRichText: true), findsOneWidget);
  });

  testWidgets('« Supprimer ce message ? » propose pour tous ou pour moi seulement', (tester) async {
    ProofDeleteChoice? choice;
    await tester.pumpWidget(localizedHarness(Builder(
      builder: (context) => TextButton(
        onPressed: () async => choice = await showProofDeleteSheet(
          context,
          preview: 'Merci Yao, je note pour lundi.',
          proofActive: true,
        ),
        child: const Text('ouvrir'),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Merci Yao, je note pour lundi.'), findsOneWidget);
    expect(find.text('Le mode preuve est actif.'), findsOneWidget);
    await tester.tap(find.text('Supprimer pour moi seulement'));
    await tester.pumpAndSettle();
    expect(choice, ProofDeleteChoice.forMeOnly);
  });

  testWidgets('« PDF prêt » affiche l\'empreinte SHA-256 du fichier reçu', (tester) async {
    const bytes = [37, 80, 68, 70, 45, 49];
    final expected = sha256.convert(bytes).toString();
    late Directory dir;
    // Lecture de fichier réelle : hors de l'horloge simulée du test.
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('preuve');
      final file = File('${dir.path}/preuve.pdf');
      await file.writeAsBytes(bytes);
      await tester.pumpWidget(localizedHarness(ProofReadyScreen(scopeName: 'Kodjo A.', file: file)));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final shown = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(shown.replaceAll(' ', ''), expected);
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
