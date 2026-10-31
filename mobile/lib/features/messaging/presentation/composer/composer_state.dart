import 'dart:math' as math;

/// Dans quel mode se trouve la barre d'écriture.
///
/// Une machine à états, et non un `TextField` avec des drapeaux à côté :
/// c'est la même barre qui sert à écrire, à enregistrer, à annuler et à
/// envoyer, et les transitions entre ces modes SONT l'interface. Les tenir
/// dans des booléens éparpillés (`_isRecording`, `_isLocked`, `_isCancelling`)
/// autorise des combinaisons qui n'ont pas de sens — verrouillé ET en train
/// d'annuler — et c'est ainsi qu'on se retrouve avec un enregistrement qui
/// continue après l'envoi.
enum ComposerMode {
  /// Rien d'écrit. Le micro est offert.
  empty,

  /// Du texte est en cours. Le micro cède la place à l'envoi.
  typing,

  /// Le doigt est posé sur le micro et ne l'a pas quitté.
  recording,

  /// Le doigt a glissé vers la gauche : relâcher annulera.
  cancelling,

  /// Le doigt a glissé vers le haut puis s'est levé. L'enregistrement
  /// continue sans le doigt.
  locked,
}

/// L'état complet de la barre, à un instant.
///
/// Immuable : chaque geste produit un état nouveau, ce qui rend la suite des
/// transitions lisible dans un test sans monter la moindre interface.
class ComposerState {
  const ComposerState({
    this.mode = ComposerMode.empty,
    this.dragOffset = 0,
    this.lockProgress = 0,
  });

  final ComposerMode mode;

  /// Le déplacement du doigt depuis le micro, en pixels.
  ///
  /// Négatif vers la gauche (annuler), négatif en vertical vers le haut
  /// (verrouiller) — voir [ComposerGeometry].
  final double dragOffset;

  /// À quel point le geste vers le haut approche du verrouillage, de 0 à 1.
  ///
  /// Une progression et non un booléen : l'indication doit se renforcer à
  /// mesure que le doigt monte, sinon rien ne dit que ce geste existe avant
  /// qu'il ne soit accompli — et un geste qu'on ne devine pas n'est jamais
  /// découvert.
  final double lockProgress;

  bool get isRecording =>
      mode == ComposerMode.recording ||
      mode == ComposerMode.cancelling ||
      mode == ComposerMode.locked;

  /// Le micro laisse la place à l'envoi dès qu'il y a quelque chose à
  /// envoyer. C'est la règle la plus visible de la barre : un seul bouton à
  /// droite, dont la fonction dépend du contenu.
  bool get showsSendButton =>
      mode == ComposerMode.typing || mode == ComposerMode.locked;

  ComposerState copyWith({
    ComposerMode? mode,
    double? dragOffset,
    double? lockProgress,
  }) => ComposerState(
    mode: mode ?? this.mode,
    dragOffset: dragOffset ?? this.dragOffset,
    lockProgress: lockProgress ?? this.lockProgress,
  );

  @override
  bool operator ==(Object other) =>
      other is ComposerState &&
      other.mode == mode &&
      other.dragOffset == dragOffset &&
      other.lockProgress == lockProgress;

  @override
  int get hashCode => Object.hash(mode, dragOffset, lockProgress);

  @override
  String toString() => 'ComposerState(${mode.name}, drag: $dragOffset)';
}

/// Les seuils des deux gestes, en pixels.
///
/// Séparés de la logique pour être ajustables sans la relire, et nommés
/// parce que « -80 » au milieu d'une condition ne dit pas de quel geste il
/// s'agit.
class ComposerGeometry {
  const ComposerGeometry({this.cancelThreshold = 80, this.lockThreshold = 60});

  /// Distance vers la GAUCHE au-delà de laquelle relâcher annule.
  final double cancelThreshold;

  /// Distance vers le HAUT au-delà de laquelle l'enregistrement se
  /// verrouille et continue sans le doigt.
  final double lockThreshold;
}

/// Les transitions de la barre d'écriture.
///
/// Sans widget, sans micro, sans minuteur : uniquement « quel geste mène à
/// quel mode ». C'est la partie qu'on veut pouvoir relire et tester, et
/// c'est celle qui se perd quand tout vit dans un `State` de 1 800 lignes.
class ComposerMachine {
  const ComposerMachine({this.geometry = const ComposerGeometry()});

  final ComposerGeometry geometry;

  /// Le texte a changé.
  ///
  /// Ne touche à rien pendant un enregistrement : on peut recevoir un
  /// événement de champ texte alors que le micro tourne (un collage, une
  /// suggestion du clavier), et cela ne doit pas interrompre la capture.
  ComposerState onTextChanged(ComposerState state, String text) {
    if (state.isRecording) return state;
    return state.copyWith(
      mode: text.trim().isEmpty ? ComposerMode.empty : ComposerMode.typing,
    );
  }

  /// Le doigt vient de se poser sur le micro.
  ComposerState onRecordStart(ComposerState state) =>
      const ComposerState(mode: ComposerMode.recording, dragOffset: 0);

  /// Le doigt bouge, toujours posé.
  ///
  /// [dx] est négatif vers la gauche, [dy] négatif vers le haut.
  ///
  /// Le verrouillage l'emporte sur l'annulation quand les deux seuils sont
  /// franchis : un geste en diagonale doit conserver l'enregistrement plutôt
  /// que le jeter. Se tromper dans ce sens fait perdre ce qu'on vient de
  /// dire, et c'est irrattrapable.
  ComposerState onRecordDrag(
    ComposerState state, {
    required double dx,
    required double dy,
  }) {
    if (state.mode == ComposerMode.locked) return state;
    if (!state.isRecording) return state;

    if (dy <= -geometry.lockThreshold) {
      return state.copyWith(
        mode: ComposerMode.locked,
        dragOffset: 0,
        lockProgress: 1,
      );
    }
    return state.copyWith(
      mode: dx <= -geometry.cancelThreshold
          ? ComposerMode.cancelling
          : ComposerMode.recording,
      lockProgress: (-dy / geometry.lockThreshold).clamp(0.0, 1.0),
      // Le décalage ne suit le doigt que vers la gauche : tirer vers la
      // droite ne veut rien dire ici, et laisser la barre s'y déplacer
      // donnerait l'impression d'un geste qui existe.
      dragOffset: math.min(0, dx),
    );
  }

  /// Le doigt se lève.
  ///
  /// Renvoie l'action à exécuter, et l'état qui suit.
  ({ComposerState state, ComposerRelease action}) onRecordRelease(
    ComposerState state,
  ) {
    switch (state.mode) {
      case ComposerMode.cancelling:
        return (state: const ComposerState(), action: ComposerRelease.cancel);
      case ComposerMode.locked:
        // Lever le doigt après verrouillage ne fait rien : c'est tout
        // l'intérêt du verrou.
        return (state: state, action: ComposerRelease.none);
      case ComposerMode.recording:
        return (state: const ComposerState(), action: ComposerRelease.send);
      default:
        return (state: state, action: ComposerRelease.none);
    }
  }

  /// La corbeille d'un enregistrement verrouillé.
  ComposerState onCancel(ComposerState state) => const ComposerState();

  /// Le bouton d'envoi d'un enregistrement verrouillé.
  ComposerState onSend(ComposerState state) => const ComposerState();
}

/// Ce qu'il faut faire quand le doigt se lève.
enum ComposerRelease { none, send, cancel }
