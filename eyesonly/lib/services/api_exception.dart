class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message, responseBody: $responseBody)';
  }
}