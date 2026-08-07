// lib/app_exception.dart

/// Base class for all application-specific exceptions.
abstract class AppException implements Exception {
  final String message;
  final String prefix;

  // Fixed constructor syntax
  AppException(this.message, this.prefix);

  @override
  String toString() => '$prefix: $message';
}

class DatabaseException extends AppException {
  DatabaseException(String message) : super(message, 'Database Error');
}

class ExternalServiceException extends AppException {
  ExternalServiceException(String message) : super(message, 'External Service Error');
}

class ValidationException extends AppException {
  ValidationException(String message) : super(message, 'Validation Error');
}