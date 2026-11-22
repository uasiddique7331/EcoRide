import '../config/app_config.dart';

/// Form validators (FR-03, FR-39, FR-60). All return `null` when valid.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[\w.+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');
  static final _pkMobile = RegExp(r'^(?:\+92|0092|92|0)?(3\d{9})$');

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? fullName(String? v) {
    final r = required(v, 'Full name');
    if (r != null) return r;
    if (v!.trim().length < 3) return 'Please enter your full name';
    return null;
  }

  static String? email(String? v) {
    final r = required(v, 'Email');
    if (r != null) return r;
    return _email.hasMatch(v!.trim()) ? null : 'Enter a valid email address';
  }

  static String? phone(String? v) {
    final r = required(v, 'Mobile number');
    if (r != null) return r;
    final cleaned = v!.replaceAll(RegExp(r'[\s\-()]'), '');
    return _pkMobile.hasMatch(cleaned) ? null : 'Enter a valid Pakistani mobile (e.g. 0300 1234567)';
  }

  /// Normalises a valid Pakistani mobile to +923XXXXXXXXX.
  static String normalizePhone(String v) {
    final cleaned = v.replaceAll(RegExp(r'[\s\-()]'), '');
    final m = _pkMobile.firstMatch(cleaned);
    return m == null ? cleaned : '+92${m.group(1)}';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < AppConfig.minPasswordLength) {
      return 'Use at least ${AppConfig.minPasswordLength} characters';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include both letters and numbers';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) =>
      (v) => (v != original()) ? 'Passwords do not match' : null;

  static String? plate(String? v) {
    final r = required(v, 'Registration number');
    if (r != null) return r;
    return RegExp(r'^[A-Za-z0-9\- ]{4,12}$').hasMatch(v!.trim())
        ? null
        : 'Enter a valid registration number (e.g. LEA-1234)';
  }

  static String? capacity(String? v, {int max = AppConfig.maxVehicleCapacity}) {
    final r = required(v, 'Capacity');
    if (r != null) return r;
    final n = int.tryParse(v!.trim());
    if (n == null || n < 1 || n > max) return 'Enter a number between 1 and $max';
    return null;
  }

  /// Validates a picked upload (FR-21).
  static String? upload({required String fileName, required int sizeBytes}) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!AppConfig.allowedUploadExtensions.contains(ext)) {
      return 'Unsupported file type. Allowed: ${AppConfig.allowedUploadExtensions.join(', ').toUpperCase()}';
    }
    if (sizeBytes > AppConfig.maxUploadBytes) {
      return 'File is too large. Maximum size is ${AppConfig.maxUploadBytes ~/ (1024 * 1024)} MB';
    }
    if (sizeBytes <= 0) return 'The selected file is empty';
    return null;
  }
}
