import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/widgets/chat_wallpaper.dart';

/// Le papier peint est une décoration : rien ne casse s'il disparaît, l'écran
/// reste parfaitement fonctionnel — juste nu. C'est exactement pour ça qu'il
/// mérite un test : une régression ici ne se signale d'aucune façon.
void main() {
  BoxDecoration decorationOf(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(ChatWallpaper), matching: find.byType(DecoratedBox)),
    );
    return box.decoration as BoxDecoration;
  }

  testWidgets('le motif est posé sur le fond de conversation, et se répète', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatWallpaper(child: SizedBox.expand())),
    );

    final decoration = decorationOf(tester);

    // Le fond crème reste peint SOUS le motif : c'est lui qu'on voit dans les
    // zones blanches de l'image, et c'est lui qui détache une bulle blanche.
    expect(decoration.color, AppColors.chatBackground);

    final image = decoration.image;
    expect(image, isNotNull, reason: 'le papier peint a disparu');
    expect(image!.repeat, ImageRepeat.repeat);
    expect((image.image as ExactAssetImage).assetName, ChatWallpaper.assetPath);
  });

  testWidgets('le motif se fond dans le canevas au lieu de le recouvrir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatWallpaper(child: SizedBox.expand())),
    );

    final image = decorationOf(tester).image!;

    // Fondu MULTIPLICATIF : l'image source a un fond blanc, et posée
    // telle quelle elle effacerait le crème. Multipliée par la couleur du
    // canevas, ses zones blanches en prennent exactement la teinte.
    expect(
      image.colorFilter,
      ColorFilter.mode(AppColors.chatBackground, BlendMode.multiply),
    );

    // Et il reste discret : un motif qui se lit est un motif qui gêne la
    // lecture des messages posés dessus.
    expect(image.opacity, lessThanOrEqualTo(0.6));
  });
}
