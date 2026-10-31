import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../providers.dart';

/// L'identité d'une personne, telle qu'elle s'affiche partout.
///
/// ── Pourquoi une couche, et pas trois réglages par écran ──────────────
///
/// Trois informations différentes se superposent sur une même photo :
///
///     ◯ [ photo ] •        Nom ✓
///     │            │            │
///     │            │            └─ compte certifié
///     │            └────────────── en ligne maintenant
///     └─────────────────────────── a un statut que je n'ai pas vu
///
/// Elles ne veulent pas dire la même chose et n'ont pas les mêmes sources.
/// Laissées à chaque écran, elles auraient divergé : un écran montrerait le
/// point vert et pas l'autre, un troisième dessinerait l'anneau dès qu'un
/// statut EXISTE — alors qu'il doit dire « non vu par moi », ce qui est une
/// question tout à fait différente.
///
/// D'où cette couche : une seule source par information, lue par un seul
/// widget ([IdentityAvatar]).

/// Présence d'une personne, telle que le serveur accepte de la révéler.
///
/// `null` sur les deux champs ne veut pas dire « hors ligne » : ça veut dire
/// « cette personne ne partage pas sa présence », ce que le serveur exprime
/// en renvoyant `null` plutôt qu'une erreur — un 403 apprendrait au
/// demandeur que quelqu'un se cache, exactement ce qu'il ne veut pas dire
/// (voir api/app/routes/presence.py).
class Presence {
  const Presence({this.isOnline, this.lastSeenAt});

  final bool? isOnline;
  final DateTime? lastSeenAt;

  /// Faut-il dessiner le point vert ? Seulement sur un « oui » franc.
  bool get afficherLePoint => isOnline == true;

  factory Presence.fromJson(Map<String, dynamic> json) => Presence(
    isOnline: json['is_online'] as bool?,
    lastSeenAt: json['last_seen_at'] == null
        ? null
        : DateTime.tryParse(json['last_seen_at'] as String),
  );

  static const inconnue = Presence();
}

/// La présence de plusieurs personnes, demandée EN UNE FOIS.
///
/// Une liste de discussions affiche trente photos. Trente requêtes de
/// présence à l'ouverture d'un écran seraient trente allers-retours sur un
/// réseau mobile — c'est exactement ce que la route groupée du serveur
/// existe pour éviter.
///
/// Le regroupement se fait ici, dans un `Notifier` unique : les widgets
/// demandent une présence, on accumule les demandes d'une même image de
/// rendu, et on part chercher le lot.
class PresenceNotifier extends StateNotifier<Map<int, Presence>> {
  PresenceNotifier(this._api) : super(const {});

  final ApiClient _api;

  /// Au plus ce que la route accepte par appel (voir MAX_BATCH_IDS).
  static const _maxParLot = 50;

  /// Au-delà, on redemande : quelqu'un peut s'être déconnecté entre-temps.
  static const _peremption = Duration(seconds: 45);

  final Set<int> _enAttente = {};
  final Map<int, DateTime> _demandeLe = {};
  Timer? _minuteur;

  /// Demande la présence de [userId] si on ne l'a pas, ou plus.
  ///
  /// Appelable depuis un `build` : rien n'est modifié sur place, la requête
  /// part au prochain tour de boucle.
  void demander(int userId) {
    final demande = _demandeLe[userId];
    if (demande != null && DateTime.now().difference(demande) < _peremption) {
      return;
    }
    _demandeLe[userId] = DateTime.now();
    _enAttente.add(userId);
    // Un seul minuteur pour toute l'image de rendu : trente widgets qui
    // demandent en même temps produisent UNE requête.
    _minuteur ??= Timer(const Duration(milliseconds: 60), _vider);
  }

  Future<void> _vider() async {
    _minuteur = null;
    if (_enAttente.isEmpty) return;
    final lot = _enAttente.take(_maxParLot).toList();
    _enAttente.removeAll(lot);
    if (_enAttente.isNotEmpty) {
      _minuteur = Timer(const Duration(milliseconds: 60), _vider);
    }
    try {
      final reponse = await _api.get('/presence?user_ids=${lot.join(',')}');
      final items = (reponse['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>();
      final nouveau = {...state};
      for (final item in items) {
        final id = item['user_id'] as int?;
        if (id != null) nouveau[id] = Presence.fromJson(item);
      }
      if (mounted) state = nouveau;
    } catch (_) {
      // Hors ligne, ou route absente d'un serveur plus ancien. On ne
      // dessine simplement aucun point — une présence inconnue vaut mieux
      // qu'une présence inventée.
      for (final id in lot) {
        _demandeLe.remove(id);
      }
    }
  }

  /// Quelqu'un vient de se connecter ou de se déconnecter — appelé par le
  /// flux temps réel, pour que le point s'allume sans attendre la
  /// péremption.
  void appliquer(int userId, {required bool enLigne}) {
    _demandeLe[userId] = DateTime.now();
    state = {...state, userId: Presence(isOnline: enLigne)};
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }
}

final presenceProvider =
    StateNotifierProvider<PresenceNotifier, Map<int, Presence>>(
      (ref) => PresenceNotifier(ref.watch(apiClientProvider)),
    );

/// Les personnes dont j'ai au moins un statut NON VU.
///
/// « Non vu », et non « existe » : l'anneau doit disparaître dès que j'ai
/// fini de regarder, et réapparaître si la personne publie de nouveau. C'est
/// la seule lecture qui rende l'indicateur utile — un anneau permanent
/// autour de quelqu'un qui publie tous les jours ne dit plus rien.
///
/// Alimenté par le fil des statuts, qui porte déjà `viewed_by_me` par
/// statut. Rien de nouveau côté serveur : l'information existait, aucun
/// écran hors de l'onglet Actus ne la lisait.
final unseenStatusUsersProvider = StateProvider<Set<int>>((ref) => const {});
