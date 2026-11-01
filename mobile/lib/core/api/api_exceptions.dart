/// Raised by [ApiClient] for any non-2xx response. `statusCode` lets
/// callers branch on specific cases (e.g. 429 for OTP rate-limiting)
/// without parsing the message string.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code});

  final int statusCode;
  final String message;

  /// Le `code` d'un refus structuré `{code, message}` (« use_honam »,
  /// « waitlist »…), pour brancher sans lire le texte.
  final String? code;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
