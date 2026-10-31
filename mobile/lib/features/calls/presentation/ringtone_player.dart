import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Sons d'appel — ringback côté appelant (voir call_screen.dart) et sonnerie
/// côté appelé (voir incoming_call_screen.dart). Enveloppe `just_audio`, déjà
/// utilisé pour les notes vocales (voir media_bubble.dart), plutôt que
/// d'ajouter un second package audio pour le même besoin.
///
/// Les fichiers sont générés (pas téléchargés) par
/// pokou/tool/generate_ringtones.py — chacun ne contient qu'UN cycle du
/// motif sonore, bouclé ici via `LoopMode.one`.
///
/// Best-effort volontaire : un émulateur sans sortie audio ou une init audio
/// qui échoue ne doit JAMAIS faire planter un écran d'appel, au pire il
/// reste silencieux — même posture que PushService pour ses propres échecs
/// (voir core/push/push_service.dart, qui avale ses erreurs d'init derrière
/// un debugPrint).
///
/// ── Le flux audio de la sonnerie ────────────────────────────────────────
///
/// `just_audio` joue par défaut sur le flux MÉDIA. La sonnerie d'un appel
/// entrant, application ouverte, sonnait donc en mode silencieux, au volume
/// des médias, et ne vibrait jamais — l'inverse exact de la couche native
/// (RingtoneService), si bien que le même appel se comportait autrement
/// selon que Pokou était ouvert ou non. Elle passe désormais sur le flux
/// SONNERIE, qu'Android coupe lui-même en silencieux, et vibre avec le même
/// motif que le natif (voir RingVibration.kt).
///
/// La tonalité de retour, elle, reste sur le flux média : c'est l'appelant
/// qui vient de la déclencher, le mode silencieux n'a pas à la couper.
class RingtonePlayer {
  RingtonePlayer()
    : _player = AudioPlayer(
        // Les attributs globaux d'audio_session (posés par les notes
        // vocales, par exemple) écraseraient sinon ceux de la sonnerie.
        androidApplyAudioAttributes: false,
        // Pas de prise de focus audio : elle interromprait la musique avant
        // même que l'appel soit décroché, et LiveKit gère la sienne.
        handleAudioSessionActivation: false,
      );

  static const _channel = MethodChannel('com.pokou.pokou/call');

  static const _ringtoneAttributes = AndroidAudioAttributes(
    usage: AndroidAudioUsage.notificationRingtone,
    contentType: AndroidAudioContentType.sonification,
  );

  static const _ringbackAsset = 'assets/audio/ringback.wav';
  static const _ringtoneAsset = 'assets/audio/ringtone.wav';

  final AudioPlayer _player;
  bool _disposed = false;
  bool _vibrating = false;

  /// Incrémenté à chaque [stop]. Un démarrage encore en cours (chargement
  /// du fichier) qui voit la génération changer renonce : sans ça, décrocher
  /// pendant le chargement laissait la sonnerie partir APRÈS la réponse.
  int _generation = 0;

  /// Tonalité de retour d'appel, côté appelant, tant que personne n'a
  /// décroché.
  Future<void> playRingback() => _playLooping(_ringbackAsset, _generation);

  /// Sonnerie d'appel entrant, côté appelé, avant qu'il ne réponde — sur le
  /// flux sonnerie, et avec vibration hors mode silencieux.
  Future<void> playRingtone() async {
    if (_disposed) return;
    final generation = _generation;
    try {
      await _player.setAndroidAudioAttributes(_ringtoneAttributes);
    } catch (exc) {
      debugPrint('[Call] Flux sonnerie indisponible: $exc');
    }
    await _playLooping(_ringtoneAsset, generation);
    if (generation != _generation || _disposed) return;
    await _startVibration();
  }

  Future<void> _startVibration() async {
    if (_disposed || _vibrating) return;
    // Posé AVANT l'appel natif : un stop() arrivé pendant cet appel doit
    // envoyer son arrêt — le canal les livre dans l'ordre, l'arrêt passera
    // donc bien après le démarrage.
    _vibrating = true;
    try {
      await _channel.invokeMethod<void>('startRingVibration');
    } catch (exc) {
      // iOS (pas de canal), tests : on sonne sans vibrer.
      _vibrating = false;
      debugPrint('[Call] Vibration indisponible: $exc');
    }
  }

  Future<void> _stopVibration() async {
    if (!_vibrating) return;
    _vibrating = false;
    try {
      await _channel.invokeMethod<void>('stopRingVibration');
    } catch (exc) {
      debugPrint('[Call] Arrêt de la vibration impossible: $exc');
    }
  }

  Future<void> _playLooping(String assetPath, int generation) async {
    if (_disposed) return;
    try {
      await _player.setLoopMode(LoopMode.one);
      await _player.setAsset(assetPath);
      if (generation != _generation || _disposed) return;
      // `play()` ne rend la main qu'à l'ARRÊT de la lecture — jamais, en
      // boucle. L'attendre bloquerait tout ce qui suit, vibration comprise.
      unawaited(
        _player.play().catchError((Object exc) {
          debugPrint('[Call] Lecture du son d’appel impossible: $exc');
        }),
      );
    } catch (exc) {
      // Best-effort : pas de son plutôt qu'un écran d'appel qui plante
      // (émulateur sans sortie audio, asset manquant sur ce build, etc.).
      debugPrint('[Call] Lecture du son d’appel impossible: $exc');
    }
  }

  /// Coupe le son en cours immédiatement — appelé dès que quelqu'un décroche
  /// (le ringback/la sonnerie n'a alors plus de sens), au raccroché, ou à la
  /// fermeture de l'écran.
  Future<void> stop() async {
    if (_disposed) return;
    _generation++;
    await _stopVibration();
    try {
      await _player.stop();
    } catch (exc) {
      debugPrint('[Call] Arrêt du son d’appel impossible: $exc');
    }
  }

  /// Libère le lecteur natif — à appeler une seule fois, quand l'écran qui
  /// possède cette instance se ferme pour de bon (jamais sur une instance
  /// injectée depuis un test, qui n'en est pas propriétaire).
  Future<void> dispose() async {
    if (_disposed) return;
    await _stopVibration();
    _disposed = true;
    try {
      await _player.dispose();
    } catch (exc) {
      debugPrint('[Call] Libération du lecteur audio impossible: $exc');
    }
  }
}
