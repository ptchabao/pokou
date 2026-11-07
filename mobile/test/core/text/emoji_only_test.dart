import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/text/emoji_only.dart';

void main() {
  test('un message fait seulement d’emoji est reconnu (1 à 3)', () {
    expect(emojiOnlyCount('😂'), 1);
    expect(emojiOnlyCount(' ❤️👍 '), 2);
    expect(emojiOnlyCount('👨‍👩‍👧🇹🇬🔥'), 3);
  });

  test('du texte, des chiffres ou plus de trois emoji restent normaux', () {
    expect(emojiOnlyCount('ok 😂'), isNull);
    expect(emojiOnlyCount('123'), isNull);
    expect(emojiOnlyCount('😂😂😂😂'), isNull);
    expect(emojiOnlyCount(''), isNull);
  });
}
