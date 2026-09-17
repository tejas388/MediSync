// lib/core/errors/app_exceptions.dart
// MediSync - Typed exception hierarchy

class AppException implements Exception {
  final String message;
  final String? code;
  const AppException(this.message, {this.code});
  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'No internet connection. Please check your network.',
  ]) : super(code: 'network');
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});

  /// Maps Firebase error codes to user-friendly messages.
  factory AuthException.fromFirebase(String code, String? rawMessage) {
    String msg;
    switch (code) {
      case 'user-not-found':
        msg = 'No account found with this email address.';
        break;
      case 'wrong-password':
      case 'invalid-credential':
        msg = 'Incorrect password. Please try again.';
        break;
      case 'email-already-in-use':
        msg = 'An account with this email already exists.';
        break;
      case 'weak-password':
        msg = 'Password is too weak. Use at least 8 characters.';
        break;
      case 'invalid-email':
        msg = 'Invalid email address format.';
        break;
      case 'too-many-requests':
        msg = 'Too many attempts. Please wait a moment and try again.';
        break;
      case 'network-request-failed':
        msg = 'Network error. Please check your internet connection.';
        break;
      case 'user-disabled':
        msg = 'This account has been disabled. Please contact support.';
        break;
      case 'google-sign-in-cancelled':
        msg = 'Google Sign-In was cancelled.';
        break;
      default:
        msg = rawMessage ?? 'Authentication failed. Please try again.';
    }
    return AuthException(msg, code: code);
  }
}

class ValidationException extends AppException {
  const ValidationException(super.message)
      : super(code: 'validation');
}

class NotFoundException extends AppException {
  const NotFoundException(super.message)
      : super(code: 'not-found');
}

class PermissionException extends AppException {
  const PermissionException(super.message)
      : super(code: 'permission-denied');
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server error. Please try again later.'])
      : super(code: 'server');
}
