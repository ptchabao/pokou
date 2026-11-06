import 'dart:async';

/// Un message reçu qu'on n'a pas pu ouvrir. Écouté par E2EERetryService,
/// qui demande à l'expéditeur de le re-livrer (reçu de nouvel essai).
///
/// Un flux global plutôt qu'une dépendance injectée : les dépôts de
/// messages sont aussi construits hors de Riverpod (notifications en
/// arrière-plan), où personne n'écoute — l'événement s'y perd sans dommage,
/// l'application le redemandera à la prochaine lecture.
final StreamController<({String kind, String messageId})> _reports =
    StreamController.broadcast();

Stream<({String kind, String messageId})> get undecryptableReports =>
    _reports.stream;

void reportUndecryptable(String kind, String messageId) =>
    _reports.add((kind: kind, messageId: messageId));
