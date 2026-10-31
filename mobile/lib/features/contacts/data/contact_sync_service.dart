import 'dart:async';

import 'package:flutter/widgets.dart';

/// Déclencheurs de la synchronisation du répertoire.
///
/// Le répertoire du TÉLÉPHONE est la seule source qui sache qu'un numéro y a
/// été ajouté : aucune plateforme n'offre de flux de changements fiable, et
/// le serveur ne conserve délibérément aucun numéro non inscrit (voir
/// `/contacts/sync` côté API). Il n'y a donc rien à « pousser » — il faut
/// relire le répertoire, et la seule question est QUAND.
///
/// Trois moments, et pas un timer :
///
/// - **au retour au premier plan.** C'est là qu'on a ajouté un numéro dans
///   l'application Contacts du téléphone, juste avant de revenir. Un timer
///   qui tourne en arrière-plan raterait ce moment et brûlerait de la
///   batterie le reste du temps.
/// - **à la (re)connexion du temps réel.** Une coupure réseau est exactement
///   la fenêtre pendant laquelle on a pu rater l'annonce d'une arrivée.
/// - **au tirer-pour-rafraîchir**, conservé : c'est le geste de quelqu'un qui
///   sait que quelque chose devrait avoir changé.
///
/// Le quatrième cas — « une personne de mon carnet vient de s'inscrire » — ne
/// passe pas par ici du tout : le serveur le pousse (`contact:registered`),
/// parce que lui seul l'apprend à la seconde près.
class ContactSyncTriggers {
  ContactSyncTriggers({required this.onTrigger});

  /// Appelé à chaque déclencheur. Doit être tolérant aux appels rapprochés :
  /// la reconnexion du socket suit souvent de près le retour au premier plan.
  final Future<void> Function() onTrigger;

  _LifecycleListener? _lifecycle;
  StreamSubscription<bool>? _connection;

  void start({required Stream<bool> connectionChanges}) {
    _lifecycle = _LifecycleListener(onResumed: onTrigger);
    WidgetsBinding.instance.addObserver(_lifecycle!);
    _connection = connectionChanges.listen((connected) {
      if (connected) onTrigger();
    });
  }

  void dispose() {
    if (_lifecycle != null) {
      WidgetsBinding.instance.removeObserver(_lifecycle!);
      _lifecycle = null;
    }
    _connection?.cancel();
    _connection = null;
  }
}

class _LifecycleListener with WidgetsBindingObserver {
  _LifecycleListener({required this.onResumed});

  final Future<void> Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}
