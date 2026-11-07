import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/calls/native_call_bridge.dart';
import '../../../core/crypto/call_keys.dart';
import '../../../core/ws/ws_client.dart';
import '../data/call_repository.dart';
import 'ringtone_player.dart';

/// Sonnerie sans réponse : l'appel abandonne au bout de ce délai. C'est la
/// durée de la sonnerie native Android (CallManager.RING_TIMEOUT_MS) — au-delà,
/// le téléphone d'en face a déjà cessé de sonner.
///
/// ── Les quatre délais d'un appel, et pourquoi ils diffèrent ──────────────
///
/// | Où                                  | Délai | Rôle                                   |
/// |-------------------------------------|-------|----------------------------------------|
/// | CallManager.RING_TIMEOUT_MS (natif) | 45 s  | sonnerie de l'appelé, app fermée       |
/// | [kNoAnswerTimeout] (ici)            | 45 s  | l'appelant abandonne, envoie `end`     |
/// | IncomingCallScreen (Flutter)        | 60 s  | filet si `end` n'arrive jamais         |
/// | calls.py `_RINGING_TTL` (serveur)   | 90 s  | un appel « qui sonne » reste joignable |
///
/// Les « harmoniser » casserait la chaîne : l'écran entrant doit attendre
/// PLUS que l'appelant (sinon il coupe un appel encore vivant), et le
/// serveur plus que les deux (sinon un appel décroché à la dernière seconde
/// ne trouverait plus son salon).
const kNoAnswerTimeout = Duration(seconds: 45);

/// Faut-il quitter l'appel quand un autre participant envoie `end` ou
/// `decline` ?
///
/// [gone] contient TOUS ceux qui sont partis ou ont refusé, celui-ci compris.
///
/// - Quelqu'un a déjà rejoint : on reste tant qu'il reste quelqu'un dans le
///   salon, en écartant le partant (LiveKit l'a peut-être déjà retiré,
///   peut-être pas encore).
/// - Personne n'a encore rejoint : on ne part que si TOUS les invités ont
///   refusé ou raccroché. Auparavant le premier refus suffisait : dans un
///   appel de groupe, l'appelant quittait l'appel sans rien dire alors que
///   les autres invités sonnaient encore, et celui qui décrochait ensuite
///   entrait dans une salle vide. En 1:1 il n'y a qu'un invité : son refus
///   termine l'appel, comme avant.
bool shouldLeaveOnRemoteSignal({
  required bool someoneJoined,
  required int? fromUserId,
  required Iterable<int?> remoteInRoom,
  required List<int> invitees,
  required Set<int> gone,
}) {
  if (someoneJoined) {
    return remoteInRoom.where((id) => id != fromUserId).isEmpty;
  }
  return invitees.every(gone.contains);
}

/// À qui envoyer `end` en raccrochant.
///
/// En 1:1, à l'autre. Dans un appel de groupe qui CONTINUE sans nous (au
/// moins deux personnes restent dans le salon), seulement à ceux qui sont
/// dans le salon : un invité qui sonne encore doit pouvoir décrocher et
/// rejoindre la conversation en cours. Auparavant tout le monde recevait
/// `end`, et la sonnerie des retardataires s'arrêtait alors que l'appel
/// continuait. Si l'appel se termine avec nous, tous les participants sont
/// prévenus — c'est ce qui fait taire les téléphones qui sonnent encore.
List<int> endSignalTargets({
  required List<int> participantIds,
  required Iterable<int> inRoom,
  required bool isGroup,
}) {
  final stillInRoom = inRoom.toSet();
  if (isGroup && stillInRoom.length >= 2) {
    return participantIds.where(stillInRoom.contains).toList();
  }
  return List.of(participantIds);
}

/// Ce que la session signale à l'écran, qui seul sait l'afficher.
enum CallNotice { noAnswer, flipFailed, inviteFailed, reactionFailed }

class CallReaction {
  const CallReaction({required this.emoji, required this.senderId});

  final String emoji;
  final int? senderId;
}

const callReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '👏'];

/// L'appel en cours dans l'application — un seul à la fois.
///
/// Le bandeau « Appel en cours » l'écoute, et `CallScreen` s'y rattache au
/// lieu d'ouvrir un second salon quand on revient à l'appel.
final ValueNotifier<CallSession?> activeCall = ValueNotifier<CallSession?>(
  null,
);

/// Un appel, de la connexion au raccroché — SANS l'écran.
///
/// Le salon LiveKit vivait dans l'état de `CallScreen` : appuyer sur
/// « retour » fermait l'écran, et l'écran fermé coupait l'appel. Il vit
/// désormais ici, et l'écran n'en est qu'une vue : on le quitte pour lire un
/// message pendant qu'on parle, on y revient par le bandeau, et l'appel ne
/// s'arrête que lorsqu'on raccroche — ou que l'autre le fait.
class CallSession extends ChangeNotifier {
  CallSession({
    required this.livekitUrl,
    required this.token,
    required this.roomName,
    required List<int> otherParticipantIds,
    required this.startWithVideo,
    required CallRepository repository,
    required WsClient ws,
    this.groupId,
    this.groupMembers = const [],
    this.joiningExistingCall = false,
    this.pendingJoin,
    RingtonePlayer? ringtonePlayer,
    NativeCallBridge? nativeBridge,
  }) : _nativeBridge = nativeBridge,
       _repository = repository,
       _ws = ws,
       _ringtonePlayer = ringtonePlayer ?? RingtonePlayer(),
       _ownsRingtonePlayer = ringtonePlayer == null,
       participantIds = List.of(otherParticipantIds),
       cameraEnabled = startWithVideo,
       speakerOn = startWithVideo;

  /// Adresse et jeton du salon. Vides tant que [pendingJoin] n'a pas
  /// répondu : on DÉCROCHE d'abord (l'écran d'appel s'ouvre aussitôt), on
  /// obtient le jeton ensuite, pendant que l'écran affiche « Connexion… ».
  String livekitUrl;
  String token;

  /// Le jeton demandé au moment où l'on décroche (voir
  /// IncomingCallScreen._accept). `null` : il est déjà dans [token].
  final Future<CallToken>? pendingJoin;
  final String roomName;
  final bool startWithVideo;
  final int? groupId;
  final List<({int userId, String displayName})> groupMembers;
  final bool joiningExistingCall;

  final CallRepository _repository;
  final WsClient _ws;

  /// Le natif Android : tient l'appel en cours au premier plan. Absent dans
  /// les tests ; sans effet sur iOS (canal absent).
  final NativeCallBridge? _nativeBridge;
  final RingtonePlayer _ringtonePlayer;
  final bool _ownsRingtonePlayer;

  final Room lkRoom = Room();

  /// Chiffré de bout en bout : la clé de ce salon est connue (tirée par
  /// nous, ou ouverte à l'arrivée — voir CallRepository), et rien de ce que
  /// l'on reçoit n'arrive en clair.
  bool get encrypted => CallKeys.of(roomName) != null && !encryptionDowngraded;

  /// Un appel censé être chiffré, où l'autre côté publie pourtant en clair —
  /// son application n'a pas reçu la clé, ou quelqu'un l'en a privé. LiveKit
  /// joue alors ces pistes sans les déchiffrer : l'écran doit cesser de dire
  /// « chiffré », sinon il affirmerait ce qui n'est plus vrai.
  bool encryptionDowngraded = false;
  EventsListener<RoomEvent>? _listener;
  StreamSubscription<Map<String, dynamic>>? _signalSubscription;
  Timer? _noAnswerTimer;
  final _notices = StreamController<CallNotice>.broadcast();
  final _reactions = StreamController<CallReaction>.broadcast();

  bool connecting = true;
  bool joinFailed = false;
  bool micEnabled = true;
  bool cameraEnabled;

  /// Haut-parleur ou écouteur. LiveKit préfère le haut-parleur par défaut :
  /// un appel AUDIO sortait donc sur le haut-parleur, sans moyen de porter
  /// le téléphone à l'oreille. Même règle que WhatsApp — haut-parleur pour
  /// la vidéo, écouteur pour la voix — et la personne tranche ensuite.
  bool speakerOn;

  /// La caméra en cours. Gardée ici, et non relue sur la piste : couper puis
  /// rallumer la caméra recrée la piste, et la ferait repartir sur l'avant
  /// au milieu d'une démonstration de produit.
  CameraPosition cameraPosition = CameraPosition.front;
  bool flipping = false;
  bool inviting = false;

  // Mutable : quelqu'un ajouté en cours d'appel doit aussi recevoir le
  // signal `end` quand on raccroche, sinon son journal d'appels reste
  // bloqué sur « en cours ».
  List<int> participantIds;

  // Quelqu'un a-t-il DÉJÀ rejoint le salon ? Sans ça, le raccrochage
  // automatique se déclencherait pendant la sonnerie, avant même que le
  // correspondant ait pu décrocher.
  bool someoneJoined = false;

  /// Le salon se reconnecte (changement de réseau, coupure brève) : LiveKit
  /// fait alors « partir » puis revenir les autres participants. Rien ne
  /// doit raccrocher pendant ce temps.
  bool reconnecting = false;

  /// Les autres ont disparu du salon : on attend un peu avant de conclure
  /// que l'appel est fini — c'est peut-être EUX qui se reconnectent.
  Timer? _emptyRoomTimer;
  static const _emptyRoomGrace = Duration(seconds: 25);

  /// Vrai quand quelqu'un est attendu de retour : l'écran l'affiche
  /// (« Reconnexion… ») au lieu de laisser croire à un appel coupé.
  bool get waitingForReturn => reconnecting || _emptyRoomTimer != null;

  /// Le début de la conversation (quelqu'un a décroché) — pour la durée
  /// affichée dans le bandeau.
  DateTime? connectedAt;

  bool _leaving = false;
  bool ended = false;

  /// Ceux qui ont refusé ou raccroché — pour savoir, avant que quiconque ait
  /// rejoint, s'il reste un invité qui sonne encore.
  final Set<int> _gone = {};

  bool get _isGroup => groupId != null || participantIds.length > 1;

  Iterable<int> get _remoteIds => lkRoom.remoteParticipants.values
      .map((participant) => int.tryParse(participant.identity))
      .whereType<int>();

  /// Combien d'écrans d'appel montrent cette session. Le bandeau ne
  /// s'affiche que lorsqu'aucun ne la montre.
  int attachedScreens = 0;

  Stream<CallNotice> get notices => _notices.stream;
  Stream<CallReaction> get reactions => _reactions.stream;

  bool canInvite(int userId) =>
      !_remoteIds.contains(userId) &&
      (!participantIds.contains(userId) || _gone.contains(userId));

  bool get canSwitchSpeaker => AudioManager.instance.canSwitchSpeakerphone;

  /// REG-2 · « Économiser les données pendant les appels » : vidéo en 360p.
  bool callDataSaver = true;

  CameraCaptureOptions get _cameraOptions => CameraCaptureOptions(
    cameraPosition: cameraPosition,
    params: callDataSaver
        ? VideoParametersPresets.h360_169
        : VideoParametersPresets.h720_169,
  );

  void _changed() {
    _syncPip();
    if (!ended) notifyListeners();
  }

  bool _pipEligible = false;

  /// Picture-in-Picture système : seulement pour un appel VIDÉO établi,
  /// affiché en plein écran. Un état d'INTERFACE, pas de session : il ne
  /// change rien à l'appel lui-même.
  void _syncPip() {
    final eligible =
        !ended && cameraEnabled && someoneJoined && attachedScreens > 0;
    if (eligible == _pipEligible) return;
    _pipEligible = eligible;
    unawaited(_nativeBridge?.setPipEligible(eligible));
  }

  void _markJoined() {
    someoneJoined = true;
    connectedAt ??= DateTime.now();
    _noAnswerTimer?.cancel();
    unawaited(_ringtonePlayer.stop());
  }

  void attachScreen() {
    attachedScreens++;
    // Le bandeau écoute aussi la session : il se cache dès qu'un écran la
    // montre, et réapparaît quand on le quitte.
    _changed();
  }

  /// Appelé depuis `dispose` de l'écran : prévenir le bandeau à cet
  /// instant le reconstruirait pendant que l'arbre est verrouillé — d'où le
  /// tour de boucle.
  void detachScreen() {
    if (attachedScreens > 0) attachedScreens--;
    scheduleMicrotask(_changed);
  }

  /// Démarre l'appel. La tonalité de retour ne joue que pour un VRAI nouvel
  /// appel sortant : rejoindre un appel déjà engagé n'a rien à voir avec
  /// « attendre que quelqu'un décroche ».
  void start() {
    if (!joiningExistingCall) {
      unawaited(_ringtonePlayer.playRingback());
      _noAnswerTimer = Timer(kNoAnswerTimeout, _onNoAnswer);
    }
    _listenForRemoteHangUp();
    unawaited(_connect());
  }

  /// L'autre a raccroché (ou refusé) : le serveur pousse `call:end` /
  /// `call:decline` (voir api/app/routes/calls.py::signal_call).
  void _listenForRemoteHangUp() {
    _signalSubscription = _ws.events.listen((event) {
      final type = event['type'];
      if (type != 'call:end' && type != 'call:decline') return;
      if (event['room'] != roomName) return;

      final from = int.tryParse('${event['from_user_id']}');
      if (from != null) _gone.add(from);
      final leave = shouldLeaveOnRemoteSignal(
        someoneJoined: someoneJoined,
        fromUserId: from,
        remoteInRoom: _remoteIds,
        invitees: participantIds,
        gone: _gone,
      );
      if (!leave) return;
      unawaited(_leaveWithoutSignalling());
    });
  }

  Future<void> _connect() async {
    _listener = lkRoom.createListener()
      ..on<RoomDisconnectedEvent>((_) => unawaited(_end()))
      ..on<ParticipantConnectedEvent>((_) {
        // Quelqu'un vient de rejoindre le salon : le correspondant a
        // décroché — le ringback n'a plus lieu d'être. Ou il revient
        // d'une reconnexion : l'attente s'arrête.
        _emptyRoomTimer?.cancel();
        _emptyRoomTimer = null;
        _markJoined();
        _changed();
      })
      ..on<RoomReconnectingEvent>((_) {
        reconnecting = true;
        _changed();
      })
      ..on<RoomReconnectedEvent>((_) {
        reconnecting = false;
        if (lkRoom.remoteParticipants.isNotEmpty) {
          _emptyRoomTimer?.cancel();
          _emptyRoomTimer = null;
        }
        _changed();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _changed();
        final userId = int.tryParse(event.participant.identity);
        if (userId != null) _gone.add(userId);
        // Filet de sécurité si le signal `end` n'arrive pas : un salon vidé
        // de tous ses pairs après en avoir eu au moins un, c'est un appel
        // terminé — mais seulement s'il le RESTE. Une reconnexion (la nôtre
        // ou la leur) vide le salon quelques secondes : raccrocher tout de
        // suite coupait l'appel à chaque changement de réseau.
        if (someoneJoined &&
            lkRoom.remoteParticipants.isEmpty &&
            _emptyRoomTimer == null) {
          _emptyRoomTimer = Timer(_emptyRoomGrace, () {
            _emptyRoomTimer = null;
            if (!ended && !reconnecting && lkRoom.remoteParticipants.isEmpty) {
              unawaited(hangUp());
            } else {
              _changed();
            }
          });
        }
      })
      ..on<TrackSubscribedEvent>((event) {
        if (CallKeys.of(roomName) != null &&
            event.publication.encryptionType == EncryptionType.kNone) {
          encryptionDowngraded = true;
          unawaited(hangUp());
        }
        _changed();
      })
      ..on<TrackUnsubscribedEvent>((_) => _changed());
    _listener!.on<DataReceivedEvent>(_onDataReceived);

    try {
      final pending = pendingJoin;
      if (pending != null) {
        final joined = await pending;
        livekitUrl = joined.livekitUrl;
        token = joined.token;
        if (joined.participantIds.isNotEmpty) {
          participantIds
            ..clear()
            ..addAll(joined.participantIds);
        }
      }
      if (_isGroup && CallKeys.of(roomName) == null) {
        throw const CallEncryptionException(
          'un appel de groupe ne peut pas rejoindre sans clé',
        );
      }
      // En PARALLÈLE : la clé de chiffrement du salon et le routage audio
      // ne dépendent pas l'un de l'autre.
      final options = _encryptedOptions();
      await _applySpeaker();
      await lkRoom.connect(
        livekitUrl,
        token,
        // Le micro est publié PENDANT la connexion, et non après : un
        // aller-retour de moins avant que l'autre nous entende.
        fastConnectOptions: FastConnectOptions(
          microphone: const TrackOption(enabled: true),
        ),
        // Le chiffrement ne peut se régler qu'ici, et non à la création de
        // `lkRoom` : la clé LiveKit se prépare de façon asynchrone, alors
        // que l'écran lit `lkRoom` dès sa première image. LiveKit marque ce
        // paramètre déprécié, mais il reste le seul point d'entrée
        // asynchrone, et le seul endroit où le SDK lit ces options.
        // ignore: deprecated_member_use
        roomOptions: await options,
      );
      // Quelqu'un était DÉJÀ dans le salon : on rejoint une conversation
      // active plutôt que d'appeler dans le vide (filet pour les points
      // d'entrée qui ne peuvent pas renseigner `joiningExistingCall`).
      if (lkRoom.remoteParticipants.isNotEmpty) _markJoined();
      // Filet : si la publication rapide n'a pas pris, on l'active ici.
      if (lkRoom.localParticipant?.isMicrophoneEnabled() != true) {
        await lkRoom.localParticipant?.setMicrophoneEnabled(true);
      }
      if (startWithVideo) {
        await lkRoom.localParticipant?.setCameraEnabled(
          true,
          cameraCaptureOptions: _cameraOptions,
        );
      }
      // Réappliqué une fois la session audio ouverte : la préférence posée
      // avant la connexion n'est pas garantie de survivre à son ouverture.
      await _applySpeaker();
      // L'application est au premier plan à cet instant : c'est la condition
      // pour qu'Android accepte un service de premier plan micro/caméra.
      unawaited(_nativeBridge?.startOngoingCall(isVideo: startWithVideo));
    } catch (_) {
      unawaited(_ringtonePlayer.stop());
      joinFailed = true;
      // L'écran affiche l'échec ; la session, elle, libère tout de suite le
      // salon (et sa minuterie interne), le micro et l'écoute des signaux.
      unawaited(_releaseAfterFailedJoin());
    } finally {
      connecting = false;
      _changed();
    }
  }

  /// Personne n'a décroché : on raccroche comme si l'appelant l'avait fait —
  /// le signal `end` arrête la sonnerie d'en face et le serveur journalise
  /// l'appel comme manqué.
  void _onNoAnswer() {
    if (ended || someoneJoined || _leaving) return;
    _notices.add(CallNotice.noAnswer);
    unawaited(hangUp());
  }

  Future<void> toggleMic() async {
    final next = !micEnabled;
    await lkRoom.localParticipant?.setMicrophoneEnabled(next);
    micEnabled = next;
    _changed();
  }

  Future<void> toggleCamera() async {
    final next = !cameraEnabled;
    await lkRoom.localParticipant?.setCameraEnabled(
      next,
      cameraCaptureOptions: _cameraOptions,
    );
    cameraEnabled = next;
    _changed();
  }

  Future<void> _applySpeaker() async {
    if (!canSwitchSpeaker) return;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(speakerOn);
    } catch (_) {
      // Le routage reste celui du système : l'appel continue.
    }
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    _changed();
    await _applySpeaker();
  }

  Future<void> sendReaction(String emoji) async {
    if (ended || !callReactionEmojis.contains(emoji)) return;
    try {
      await lkRoom.localParticipant?.publishData(
        utf8.encode(jsonEncode({'type': 'call_reaction', 'emoji': emoji})),
        reliable: true,
        topic: 'pokou.call.reaction',
      );
      _reactions.add(CallReaction(emoji: emoji, senderId: null));
    } catch (_) {
      _notices.add(CallNotice.reactionFailed);
    }
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (event.topic != 'pokou.call.reaction') return;
    try {
      final payload = jsonDecode(utf8.decode(event.data));
      if (payload is! Map<String, dynamic> ||
          payload['type'] != 'call_reaction' ||
          payload['emoji'] is! String) {
        return;
      }
      final emoji = payload['emoji'] as String;
      if (!callReactionEmojis.contains(emoji)) return;
      _reactions.add(
        CallReaction(
          emoji: emoji,
          senderId: int.tryParse(event.participant?.identity ?? ''),
        ),
      );
    } on FormatException {
      return;
    }
  }

  /// Avant ↔ arrière. C'est ce qui permet à un vendeur de MONTRER l'article
  /// pendant l'appel.
  Future<void> flipCamera() async {
    if (flipping) return;
    final track = lkRoom.localParticipant?.videoTrackPublications
        .where((publication) => publication.source == TrackSource.camera)
        .firstOrNull
        ?.track;
    if (track is! LocalVideoTrack) return;
    final next = cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    flipping = true;
    _changed();
    try {
      await track.setCameraPosition(next);
      cameraPosition = next;
    } catch (_) {
      _notices.add(CallNotice.flipFailed);
    } finally {
      flipping = false;
      _changed();
    }
  }

  /// Ajoute quelqu'un à l'appel EN COURS : le salon ne change pas, l'invité
  /// reçoit un `call:invite` sur le salon existant.
  Future<void> invite(List<int> userIds) async {
    inviting = true;
    _changed();
    try {
      participantIds = await _repository.inviteToCall(
        room: roomName,
        userIds: userIds,
      );
    } catch (_) {
      _notices.add(CallNotice.inviteFailed);
    } finally {
      inviting = false;
      _changed();
    }
  }

  /// Raccrocher : chaque autre participant reçoit `end`, puis le salon se
  /// ferme.
  Future<void> hangUp() async {
    if (_leaving) return;
    _leaving = true;
    unawaited(_ringtonePlayer.stop());
    final targets = endSignalTargets(
      participantIds: participantIds,
      inRoom: _remoteIds,
      isGroup: _isGroup,
    );
    for (final otherId in targets) {
      unawaited(
        _repository
            .signal(room: roomName, targetUserId: otherId, event: 'end')
            // Un appel déjà clos côté serveur répond 409/404 : il n'y a
            // plus rien à prévenir, et l'erreur ne doit pas remonter.
            .catchError((_) {}),
      );
    }
    await _end();
  }

  /// Sortie provoquée par l'autre bout : inutile de lui renvoyer un `end`,
  /// il vient précisément de nous l'envoyer.
  Future<void> _leaveWithoutSignalling() async {
    if (_leaving) return;
    _leaving = true;
    await _end();
  }

  /// Les options de chiffrement de bout en bout, ou `null` pour un appel
  /// standard. Chaque image et chaque échantillon audio sont chiffrés avec
  /// la clé de l'appel : le serveur de média relaie des trames qu'il ne
  /// peut ni voir ni entendre.
  Future<RoomOptions?> _encryptedOptions() async {
    final key = CallKeys.of(roomName);
    if (key == null) return null;
    final provider = await BaseKeyProvider.create();
    await provider.setSharedKey(base64.encode(key.bytes));
    return lkRoom.roomOptions.copyWith(
      encryption: E2EEOptions(keyProvider: provider),
    );
  }

  Future<void> _releaseAfterFailedJoin() async {
    _noAnswerTimer?.cancel();
    await _signalSubscription?.cancel();
    CallKeys.forget(roomName);
    if (identical(activeCall.value, this)) activeCall.value = null;
    try {
      await _listener?.dispose();
      await lkRoom.dispose();
    } catch (_) {}
  }

  Future<void> _end() async {
    if (ended) return;
    _leaving = true;
    _emptyRoomTimer?.cancel();
    _emptyRoomTimer = null;
    _noAnswerTimer?.cancel();
    await _signalSubscription?.cancel();
    unawaited(_ringtonePlayer.stop());
    try {
      // LiveKit peut attendre un ACK réseau qui n'arrivera jamais : la
      // session doit tout de même se fermer.
      await lkRoom.disconnect().timeout(const Duration(seconds: 2));
    } catch (_) {}
    ended = true;
    unawaited(_nativeBridge?.stopOngoingCall());
    _syncPip();
    CallKeys.forget(roomName);
    // Les écrans encore ouverts se ferment sur ce signal (voir CallScreen).
    notifyListeners();
    if (identical(activeCall.value, this)) activeCall.value = null;
    await _listener?.dispose();
    await lkRoom.dispose();
    if (_ownsRingtonePlayer) unawaited(_ringtonePlayer.dispose());
    await _notices.close();
    await _reactions.close();
  }
}
