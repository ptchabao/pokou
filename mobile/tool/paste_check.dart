// Outil de diagnostic : le champ de saisie des discussions, seul, pour
// vérifier copier-coller sur un appareil.  flutter run -t tool/paste_check.dart
import 'package:flutter/material.dart';
import 'package:pokou/features/messaging/presentation/composer/composer_input.dart';
import 'package:pokou/l10n/app_localizations.dart';

void main() => runApp(const _App());

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final controller = TextEditingController();
  final focus = FocusNode();
  String inserted = '';

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: TextField(key: Key('source'), decoration: InputDecoration(labelText: 'source')),
            ),
            Text('inséré: $inserted'),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ComposerInputPill(
                controller: controller,
                focusNode: focus,
                hintText: 'Message',
                emojiOpen: false,
                enabled: true,
                onAttach: () {},
                onToggleEmoji: () {},
                onCamera: () {},
                onSubmitted: (_) {},
                onContentInserted: (c) => setState(() => inserted = c.mimeType),
                attachTooltip: 'a',
                emojiTooltip: 'e',
                cameraTooltip: 'c',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
