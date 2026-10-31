import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/contacts/data/contact_sync_service.dart';

/// Ces déclencheurs sont invisibles : quand ils cessent de partir, rien ne
/// casse à l'écran — le carnet vieillit simplement en silence, et l'ancien
/// symptôme revient (« il faut tirer pour rafraîchir »). D'où ce test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le retour au premier plan relance la synchronisation', () async {
    var calls = 0;
    final connection = StreamController<bool>.broadcast();
    final triggers = ContactSyncTriggers(onTrigger: () async => calls++);
    triggers.start(connectionChanges: connection.stream);
    addTearDown(() {
      triggers.dispose();
      connection.close();
    });

    // Passer en arrière-plan ne déclenche rien : c'est au RETOUR qu'un
    // numéro a pu être ajouté dans l'application Contacts du téléphone.
    WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(calls, 0);

    WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(calls, 1);
  });

  test('la reconnexion du temps réel relance la synchronisation, pas la coupure', () async {
    var calls = 0;
    final connection = StreamController<bool>.broadcast();
    final triggers = ContactSyncTriggers(onTrigger: () async => calls++);
    triggers.start(connectionChanges: connection.stream);
    addTearDown(() {
      triggers.dispose();
      connection.close();
    });

    // Une coupure n'apprend rien de neuf ; c'est le retour du réseau qui
    // ouvre la fenêtre pendant laquelle on a pu rater une arrivée.
    connection.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);

    connection.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });

  test('rien ne part plus une fois les déclencheurs relâchés', () async {
    var calls = 0;
    final connection = StreamController<bool>.broadcast();
    final triggers = ContactSyncTriggers(onTrigger: () async => calls++);
    triggers.start(connectionChanges: connection.stream);
    addTearDown(connection.close);

    triggers.dispose();

    // Un observateur de cycle de vie laissé accroché survit à l'écran qui
    // l'a posé, et continue de lire le répertoire entier pour personne.
    WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    connection.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);
  });
}
