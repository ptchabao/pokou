import '../../../core/api/api_client.dart';

/// Minou dans Pokou — voir api/app/routes/vault_minou.py.
///
/// Ce que contient la conversation dépend d'une seule question, posée sur le
/// NUMÉRO de l'utilisateur : si son numéro est destinataire des alertes d'un
/// moniteur actif (ou s'il en possède un), le fil est celui des ALERTES de ce
/// moniteur ; sinon c'est la vraie messagerie Minou — la même conversation
/// que sur WhatsApp, au message près, puisque c'est le même journal côté
/// serveur.
///
/// C'est le serveur qui tranche, jamais l'application : la même règle sert au
/// webhook WhatsApp, et deux implémentations auraient fini par donner deux
/// Minou différents à la même personne.
enum MinouMode { alerts, messaging }

MinouMode _modeFrom(String? raw) =>
    raw == 'alerts' ? MinouMode.alerts : MinouMode.messaging;

class MinouMonitor {
  const MinouMonitor({
    required this.id,
    required this.name,
    required this.intention,
  });

  final int id;
  final String name;
  final String intention;

  factory MinouMonitor.fromJson(Map<String, dynamic> json) => MinouMonitor(
    id: json['id'] as int,
    name: json['name'] as String? ?? 'Moniteur',
    intention: json['intention'] as String? ?? '',
  );
}

class MinouStatus {
  const MinouStatus({
    required this.mode,
    required this.monitors,
    required this.phone,
    required this.hasMinouHistory,
  });

  final MinouMode mode;
  final List<MinouMonitor> monitors;
  final String? phone;

  /// Vrai dès que la personne a déjà écrit à Minou, depuis WhatsApp ou depuis
  /// l'application — l'écran peut alors afficher la conversation au lieu d'un
  /// accueil.
  final bool hasMinouHistory;

  factory MinouStatus.fromJson(Map<String, dynamic> json) => MinouStatus(
    mode: _modeFrom(json['mode'] as String?),
    monitors: ((json['monitors'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MinouMonitor.fromJson)
        .toList(),
    phone: json['phone'] as String?,
    hasMinouHistory: json['has_minou_history'] as bool? ?? false,
  );
}

/// Une ligne du fil. `direction` est déjà exprimée du point de vue de
/// l'utilisateur par le serveur : « out » = ce que J'AI écrit, « in » = ce que
/// Minou (ou le moniteur) m'envoie. Une alerte est toujours entrante.
class MinouThreadItem {
  const MinouThreadItem({
    required this.id,
    required this.isMine,
    required this.isAlert,
    required this.body,
    required this.createdAt,
    this.title,
    this.severity,
    this.severityLabel,
    this.explanation,
    this.monitorName,
  });

  final String id;
  final bool isMine;
  final bool isAlert;
  final String body;
  final DateTime createdAt;
  final String? title;
  final String? severity;
  final String? monitorName;

  /// Ce que l'alerte veut dire, en clair : ce que surveille le moniteur, le
  /// chiffre observé face à son habitude, la règle qui a déclenché, le niveau
  /// et la fiabilité. Reconstruit côté serveur à partir des chiffres du
  /// signal (voir vault_minou.py::_explain_signal), parce que le titre d'une
  /// alerte est « Alerte `nom_de_colonne` » et sa description parfois vide de
  /// sens — c'est ce qui faisait que la plupart des alertes ne disaient rien.
  final String? explanation;

  /// Niveau dit en mots (« important », « à surveiller ») plutôt qu'en enum.
  final String? severityLabel;

  /// Le texte tel qu'il doit s'afficher. Une alerte reprend la mise en forme
  /// de celle qui part par WhatsApp (voir NotificationService.build_message) —
  /// une même alerte ne doit pas se lire différemment selon le canal — puis
  /// son explication.
  String get displayBody {
    if (!isAlert) return body;
    final source = monitorName ?? 'MAHIZU';
    // Les soulignés viennent du nom de colonne surveillée : « Alerte
    // ventes_jour » se lit mieux « Alerte ventes jour ».
    final subject = title?.replaceAll('_', ' ');
    final heading = subject == null ? source : '$source — $subject';
    final parts = <String>[
      '🧠 $heading',
      if (body.trim().isNotEmpty) body.trim(),
      if ((explanation ?? '').trim().isNotEmpty) explanation!.trim(),
    ];
    return parts.join('\n\n');
  }

  factory MinouThreadItem.fromJson(Map<String, dynamic> json) =>
      MinouThreadItem(
        id: json['id'] as String,
        isMine: json['direction'] == 'out',
        isAlert: json['kind'] == 'alert',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        title: json['title'] as String?,
        severity: json['severity'] as String?,
        severityLabel: json['severity_label'] as String?,
        explanation: json['explanation'] as String?,
        monitorName: json['monitor_name'] as String?,
      );
}

class MinouThread {
  const MinouThread({required this.mode, required this.items});

  final MinouMode mode;
  final List<MinouThreadItem> items;

  factory MinouThread.fromJson(Map<String, dynamic> json) => MinouThread(
    mode: _modeFrom(json['mode'] as String?),
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MinouThreadItem.fromJson)
        .toList(),
  );
}

class MinouRepository {
  MinouRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<MinouStatus> status() async {
    final response = await _api.get('/minou/status');
    return MinouStatus.fromJson(response as Map<String, dynamic>);
  }

  Future<MinouThread> thread({int limit = 50}) async {
    final response = await _api.get('/minou/thread?limit=$limit');
    return MinouThread.fromJson(response as Map<String, dynamic>);
  }

  /// Écrire à Minou. Renvoie TOUT ce qui vient de s'ajouter au fil — l'écho de
  /// mon propre message puis la ou les réponses : Minou répond parfois en
  /// plusieurs messages (accueil, puis question de zone), et n'en afficher
  /// qu'un en perdrait.
  ///
  /// 409 si le numéro est rattaché à un moniteur : c'est /mahizu/chat qui
  /// répond dans ce cas (lui seul porte le quota et le RBAC du moniteur).
  Future<List<MinouThreadItem>> send(String text) async {
    final response = await _api.post(
      '/minou/messages',
      body: {'text': text},
      // Minou lit le message avec un modèle de langage avant de répondre :
      // c'est long, et parfois plus long que les 20 s par défaut. Expirer
      // trop tôt n'annulait rien côté serveur — ça affichait juste « non
      // envoyé » sur un message déjà traité.
      timeout: const Duration(seconds: 60),
    );
    return ((response['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MinouThreadItem.fromJson)
        .toList();
  }
}
