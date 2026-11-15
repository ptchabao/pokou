import 'package:flutter/material.dart';

import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';

/// Ce qu'on a rédigé : la question, au moins deux réponses, et si l'on peut
/// en cocher plusieurs.
typedef PollDraft = ({String question, List<String> options, bool allowsMultiple});

/// Rédiger un sondage (entrée « Sondage » de la feuille Joindre).
///
/// Deux réponses au départ, douze au plus — la borne du serveur (voir
/// api polls.py::_MAX_OPTIONS). Les réponses vides sont retirées avant
/// l'envoi, et le bouton reste sans effet tant qu'il n'y a pas une
/// question et deux vraies réponses.
Future<PollDraft?> showPollComposer(BuildContext context) async {
  final l = L.of(context);
  final questionController = TextEditingController();
  final optionControllers = [TextEditingController(), TextEditingController()];
  var allowsMultiple = false;

  final poll = await showDialog<PollDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(l.pollOne),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: questionController,
                  autofocus: true,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: l.pollQuestion,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < optionControllers.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      contextMenuBuilder: pokouContextMenuBuilder,
                      controller: optionControllers[index],
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: l.pollAnswerN(index + 1),
                        border: const OutlineInputBorder(),
                        counterText: '',
                        suffixIcon: optionControllers.length > 2
                            ? IconButton(
                                tooltip: l.actionDelete,
                                onPressed: () => setDialogState(
                                  () => optionControllers
                                      .removeAt(index)
                                      .dispose(),
                                ),
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null,
                      ),
                    ),
                  ),
                if (optionControllers.length < 12)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(
                        () => optionControllers.add(TextEditingController()),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l.pollAddAnswer),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.pollMultiple),
                  value: allowsMultiple,
                  onChanged: (value) =>
                      setDialogState(() => allowsMultiple = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () {
              final question = questionController.text.trim();
              final options = optionControllers
                  .map((controller) => controller.text.trim())
                  .where((option) => option.isNotEmpty)
                  .toList();
              if (question.isEmpty || options.length < 2) return;
              Navigator.pop(dialogContext, (
                question: question,
                options: options,
                allowsMultiple: allowsMultiple,
              ));
            },
            child: Text(l.pollOne),
          ),
        ],
      ),
    ),
  );

  questionController.dispose();
  for (final controller in optionControllers) {
    controller.dispose();
  }
  return poll;
}
