import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'composer_state.dart';
import 'waveform.dart';

/// Le micro, le minuteur et les niveaux captés — sans aucune interface.
///
/// Les deux écrans de conversation (tête-à-tête et groupe) avaient chacun
/// leur copie de ce code : démarrage, minuteur, arrêt, suppression du
/// fichier. Deux copies d'une mécanique qui touche à un fichier temporaire
/// et à une permission système, c'est deux occasions de laisser un
/// enregistrement tourner ou un fichier traîner.
///
/// Séparé de la machine à états ([ComposerMachine]) : celle-ci dit ce que le
/// geste signifie, celui-ci fait tourner le matériel. On peut tester la
/// première sans micro, ce qui est précisément l'intérêt.
class VoiceRecordingController extends ChangeNotifier {
  VoiceRecordingController({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudes;
  String? _path;

  Duration _elapsed = Duration.zero;
  final List<double> _levels = [];

  Duration get elapsed => _elapsed;

  /// Les niveaux captés, du plus ancien au plus récent.
  List<double> get levels => List.unmodifiable(_levels);

  bool get isRecording => _path != null;

  /// Démarre la capture. Renvoie faux si le micro n'a pas pu s'ouvrir.
  Future<bool> start() async {
    if (isRecording) return true;
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/pokou_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _path = path;
      _elapsed = Duration.zero;
      _levels.clear();

      // Le minuteur avance de seconde en seconde ; les niveaux, eux, sont
      // lus dix fois plus souvent — une forme d'onde qui bouge une fois par
      // seconde ressemble à un affichage figé, pas à un micro qui écoute.
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed += const Duration(seconds: 1);
        notifyListeners();
      });
      _amplitudes = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amplitude) {
            _levels.add(normalizeAmplitude(amplitude.current));
            // Une borne : un enregistrement de plusieurs minutes accumulerait
            // des milliers de valeurs dont seules les dernières sont affichées.
            if (_levels.length > 240) _levels.removeAt(0);
            notifyListeners();
          });
      notifyListeners();
      return true;
    } catch (exc) {
      debugPrint('[Voix] Démarrage impossible: $exc');
      await _teardown();
      return false;
    }
  }

  /// Arrête et renvoie le fichier, ou `null` si rien n'a été capté.
  Future<File?> stop() async {
    if (!isRecording) return null;
    final path = _path;
    await _teardown();
    try {
      await _recorder.stop();
    } catch (exc) {
      debugPrint('[Voix] Arrêt imparfait: $exc');
    }
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  /// Arrête et JETTE l'enregistrement.
  ///
  /// Le fichier est supprimé ici et pas plus tard : une note vocale annulée
  /// qui reste sur le disque est un enregistrement de la voix de quelqu'un
  /// qu'il a explicitement demandé à ne pas garder.
  Future<void> cancel() async {
    final file = await stop();
    if (file != null) unawaited(file.delete());
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    await _amplitudes?.cancel();
    _amplitudes = null;
    _path = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Sans cela, quitter l'écran en cours d'enregistrement laissait le micro
    // ouvert : la pastille du système restait allumée, et l'utilisateur
    // n'avait plus aucun moyen de l'éteindre depuis l'application.
    _ticker?.cancel();
    _amplitudes?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }
}
