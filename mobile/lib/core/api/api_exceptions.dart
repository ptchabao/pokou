/// Raised by [ApiClient] for any non-2xx response. `statusCode` lets
/// callers branch on specific cases (e.g. 429 for OTP rate-limiting)
/// without parsing the message string.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code, this.attemptsLeft});

  final int statusCode;
  final String message;

  /// Le `code` d'un refus structuré `{code, message}` (« use_honam »,
  /// « waitlist »…), pour brancher sans lire le texte.
  final String? code;

  /// Essais restants d'un refus `otp_wrong` (voir otp_verify_screen.dart) :
  /// l'écran « Code incorrect » (maquette Inscription 2b) l'affiche sans
  /// avoir à l'extraire du texte, déjà traduit par le serveur ou l'app.
  final int? attemptsLeft;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
