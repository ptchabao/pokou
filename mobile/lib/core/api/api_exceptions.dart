/// Raised by [ApiClient] for any non-2xx response. `statusCode` lets
/// callers branch on specific cases (e.g. 429 for OTP rate-limiting)
/// without parsing the message string.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
