/// Exception thrown when the Jobcelis API returns an error response.
class JobcelisException implements Exception {
  /// HTTP status code returned by the API.
  final int statusCode;

  /// Error detail from the API response.
  final String detail;

  JobcelisException(this.statusCode, this.detail);

  @override
  String toString() => 'JobcelisException($statusCode): $detail';
}
