import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chaque bouton-icône doit se nommer.
///
/// 30 des 49 boutons-icônes de l'application n'avaient AUCUN libellé,
/// concentrés là où ça compte le plus : sept dans l'écran de conversation,
/// six dans celui des groupes. Pour quelqu'un qui navigue au lecteur
/// d'écran, ce sont des boutons anonymes — on entend « bouton », sans savoir
/// lequel, et une messagerie devient inutilisable.
///
/// Ce test lit le CODE SOURCE plutôt que de monter des widgets. C'est
/// inhabituel, et c'est le seul moyen d'obtenir la garantie recherchée :
/// éprouver chaque bouton un par un demanderait un test par écran, qu'on
/// oublierait d'écrire pour le prochain. Ici, un bouton ajouté demain sans
/// libellé fait tomber ce test sans que personne n'ait à y penser.
void main() {
  /// Les widgets qui rendent une icône seule, sans texte à côté pour la
  /// nommer.
  const boutons = ['IconButton', 'SoftIconButton', '_ChatIconButton'];

  /// Trouve la parenthèse fermante correspondant à celle ouverte en [start].
  int? fermante(String source, int start) {
    var depth = 1;
    var i = start;
    while (i < source.length && depth > 0) {
      if (source[i] == '(') depth++;
      if (source[i] == ')') depth--;
      i++;
    }
    return depth == 0 ? i : null;
  }

  test('aucun bouton-icône sans libellé accessible', () {
    final manquants = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();

      for (final nom in boutons) {
        // `\b` pour ne pas confondre `IconButton(` avec `SoftIconButton(` —
        // le piège s'est refermé une fois pendant l'écriture de ce lot.
        for (final m in RegExp('\\b$nom\\(').allMatches(source)) {
          // La DÉCLARATION du widget, pas un appel : `const SoftIconButton({`.
          final avant = source.substring(
            (m.start - 12).clamp(0, source.length),
            m.start,
          );
          if (avant.contains('const ') && avant.trimRight().endsWith('const')) {
            continue;
          }

          final fin = fermante(source, m.end);
          if (fin == null) continue;
          final corps = source.substring(m.end, fin - 1);
          if (corps.contains('tooltip:')) continue;

          final ligne = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          manquants.add('${entity.path}:$ligne ($nom)');
        }
      }
    }

    expect(
      manquants,
      isEmpty,
      reason:
          'Boutons sans libellé — ajoutez `tooltip: L.of(context).…` :\n'
          '${manquants.join('\n')}',
    );
  });

  test('le test sait reconnaître un bouton nu', () {
    // Garde-fou : sans lui, le test précédent passerait le jour où sa
    // détection cesse de fonctionner, et non parce que tout va bien.
    const extrait = '''
      IconButton(
        onPressed: () {},
        icon: const Icon(Icons.close),
      )
    ''';

    final trouve = RegExp('\\bIconButton\\(').allMatches(extrait);

    expect(trouve, hasLength(1));
    expect(extrait.contains('tooltip:'), isFalse);
  });
}
