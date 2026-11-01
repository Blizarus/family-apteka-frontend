/// Safe parsing utilities for dealing with dynamic backend data (e.g., MySQL decimal strings).
class ParseHelper {
  /// Safely parses [val] into a [double].
  ///
  /// Handles [num], decimal strings (e.g. "10.000", "0.500", "1,5"), null and invalid strings.
  /// Returns [fallback] if parsing fails or input is empty/null.
  static double parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();

    final s = val.toString().trim();
    if (s.isEmpty) return fallback;

    final normalized = s.replaceAll(',', '.');
    return double.tryParse(normalized) ?? fallback;
  }

  /// Safely parses [val] into a nullable [double].
  ///
  /// Returns null if [val] is null, empty string, or cannot be parsed.
  static double? parseNullableDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();

    final s = val.toString().trim();
    if (s.isEmpty) return null;

    final normalized = s.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  /// Safely parses [val] into an [int].
  ///
  /// Handles [int], [num], decimal strings (e.g. "10.000", "5.7"), null and invalid strings.
  /// If [val] represents a fractional number, it is truncated via [num.toInt].
  /// Returns [fallback] if parsing fails or input is empty/null.
  static int parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();

    final s = val.toString().trim();
    if (s.isEmpty) return fallback;

    final normalized = s.replaceAll(',', '.');
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;

    final asDouble = double.tryParse(normalized);
    if (asDouble != null) return asDouble.toInt();

    return fallback;
  }

  /// Safely parses [val] into a nullable [int].
  ///
  /// Returns null if [val] is null, empty string, or cannot be parsed.
  static int? parseNullableInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();

    final s = val.toString().trim();
    if (s.isEmpty) return null;

    final normalized = s.replaceAll(',', '.');
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;

    final asDouble = double.tryParse(normalized);
    if (asDouble != null) return asDouble.toInt();

    return null;
  }

  /// Formats a quantity nicely for UI display:
  ///
  /// Displays whole numbers without ".0" (e.g. 10.0 -> "10"),
  /// and preserves fractional parts (e.g. 0.5 -> "0.5", 1.25 -> "1.25").
  static String formatQuantity(num? val, [String fallback = '0']) {
    if (val == null) return fallback;
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    final s = val.toString();
    if (s.contains('.')) {
      return s.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Formats any dynamic value (num, string, null) nicely for UI display.
  static String formatAny(dynamic val, [String fallback = '0']) {
    final d = parseNullableDouble(val);
    if (d == null) return fallback;
    return formatQuantity(d, fallback);
  }
}
