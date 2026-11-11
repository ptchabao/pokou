import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/status/data/status_model.dart';
import 'package:pokou/features/status/data/status_text_style.dart';

void main() {
  test('un statut simple reste un texte simple', () {
    expect(StatusTextStyle.encode(StatusTextStyle.plain, 'Bonjour'), 'Bonjour');
    final (style, text) = StatusTextStyle.decode('Bonjour');
    expect(style.background, 0);
    expect(style.font, 0);
    expect(text, 'Bonjour');
  });

  test('le fond et la police font l\'aller-retour, pour toute la palette', () {
    for (var b = 0; b < statusBackgrounds.length; b++) {
      for (var f = 0; f < statusFonts.length; f++) {
        final sent = StatusTextStyle.encode(
          StatusTextStyle(background: b, font: f),
          'Akwaba 🎉\nà tous',
        );
        final (style, text) = StatusTextStyle.decode(sent);
        expect((style.background, style.font), (b, f));
        expect(text, 'Akwaba 🎉\nà tous');
      }
    }
  });

  test('une ancienne version ne voit que le texte : le style est invisible', () {
    final sent = StatusTextStyle.encode(
      const StatusTextStyle(background: 3, font: 1),
      'Bonne fête',
    );
    final visible = sent.replaceAll(RegExp('[⁣​‌]'), '');
    expect(visible, 'Bonne fête');
  });

  test('un style inconnu ou abîmé ne casse rien', () {
    // Indice hors palette (version future) : premier fond.
    final (style, text) = StatusTextStyle.decode(
      '⁣${'​' * 40}⁣⁣Salut',
    );
    expect(style.background, 0);
    expect(text, 'Salut');
    // Marqueur incomplet : tout est du texte.
    expect(StatusTextStyle.decode('⁣Salut').$2, '⁣Salut');
  });

  test('le modèle sépare le style du texte dès la lecture', () {
    final status = PokouStatus.fromJson({
      'id': 's1',
      'user_id': 7,
      'content_type': 'TEXT',
      'text_content': StatusTextStyle.encode(
        const StatusTextStyle(background: 4, font: 2),
        'En route',
      ),
      'created_at': '2026-11-11T08:00:00',
      'expires_at': '2026-11-12T08:00:00',
    });
    expect(status.textContent, 'En route');
    expect(status.textStyle.background, 4);
    expect(status.textStyle.font, 2);
  });

  test('un mot court s\'écrit en grand, un long texte reste lisible', () {
    expect(StatusTextStyle.fontSizeFor('Merci'), 34);
    expect(StatusTextStyle.fontSizeFor('a' * 300), 18);
  });
}
