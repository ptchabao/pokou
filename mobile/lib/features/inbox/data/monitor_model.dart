/// A "Smart Contact" in Pokou's inbox — maps 1:1 to a backend `Monitor`
/// (an intention bound to a connected data source, e.g. "Mon Stock Excel").
class SmartContact {
  const SmartContact({
    required this.id,
    required this.name,
    required this.intention,
    required this.status,
    this.lastEvaluatedAt,
  });

  final int id;
  final String name;
  final String intention;
  final String status;
  final DateTime? lastEvaluatedAt;

  bool get isConnected => status.toUpperCase() == 'ACTIVE';

  factory SmartContact.fromJson(Map<String, dynamic> json) {
    return SmartContact(
      id: json['id'] as int,
      name: json['name'] as String,
      intention: json['intention'] as String,
      status: json['status'] as String? ?? 'INACTIVE',
      lastEvaluatedAt: json['last_evaluated_at'] != null
          ? DateTime.tryParse(json['last_evaluated_at'] as String)
          : null,
    );
  }
}
