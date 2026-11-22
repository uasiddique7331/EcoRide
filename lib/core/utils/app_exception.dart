import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A user-presentable failure (FR-104, FR-105).
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  static const network = AppException(
      'No internet connection or the server is unreachable. Please check your network and try again.');

  @override
  String toString() => message;
}

/// Converts any thrown object into a message safe to show to users.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  if (error is TimeoutException || error is SocketException) return AppException.network.message;
  if (error is FirebaseAuthException) return _authMessage(error.code);
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return AppException.network.message;
      case 'permission-denied':
      case 'unauthorized':
        return 'You do not have permission to perform this action.';
      case 'not-found':
      case 'object-not-found':
        return 'The requested record could not be found.';
      case 'canceled':
        return 'The operation was cancelled.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Please contact support.';
      default:
        return 'Something went wrong (${error.code}). Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}

String _authMessage(String code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-login-credentials':
      return 'Incorrect email or password, or no account exists for this email.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'email-already-in-use':
      return 'An account with this email already exists. Please log in instead.';
    case 'weak-password':
      return 'This password is too weak. Use at least 8 characters with letters and numbers.';
    case 'user-disabled':
      return 'This account has been disabled. Please contact support.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return AppException.network.message;
    case 'requires-recent-login':
      return 'Please log in again to continue.';
    default:
      return 'Authentication failed ($code). Please try again.';
  }
}

/// Runs [action] with a timeout and converts failures into [AppException].
/// Firestore writes wait indefinitely while offline, so every write is
/// wrapped with this helper (FR-105).
Future<T> guarded<T>(Future<T> Function() action,
    {Duration timeout = const Duration(seconds: 15)}) async {
  try {
    return await action().timeout(timeout);
  } on AppException {
    rethrow;
  } catch (e) {
    throw AppException(friendlyError(e));
  }
}
