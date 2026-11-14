/// Capitalizes every word in a human real name (Title Case).
/// Handles spaces, hyphens, and apostrophes.
/// e.g. "juan dela cruz" -> "Juan Dela Cruz"
///      "mary-jane" -> "Mary-Jane"
///      "o'connor" -> "O'Connor"
String capitalizeName(String? name) {
  if (name == null) return '';
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';

  return trimmed.split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) return word;

    String capitalizeToken(String token) {
      if (token.isEmpty) return token;
      return token[0].toUpperCase() + token.substring(1).toLowerCase();
    }

    if (word.contains('-')) {
      return word.split('-').map(capitalizeToken).join('-');
    }

    if (word.contains("'")) {
      return word.split("'").map(capitalizeToken).join("'");
    }

    return capitalizeToken(word);
  }).join(' ');
}

/// Helper function to sanitize and validate human real names for order pickups.
///
/// Returns [false] if the name:
/// - Contains emojis, numbers, or special symbols.
/// - Is a single word (does not contain at least one space).
///
/// Automatically formats capitalization via [capitalizeName].
/// Returns [true] only for valid human names (letters, spaces, hyphens, apostrophes, periods).
bool isValidRealName(String? name) {
  if (name == null) return false;
  final formatted = capitalizeName(name);
  if (formatted.isEmpty) return false;

  // 1. Check for allowed characters: Unicode letters (\p{L}), spaces, hyphens, apostrophes, periods.
  // Excludes numbers, emojis, and special symbols (@, #, $, %, !, _, *, etc.).
  final allowedCharsRegex = RegExp(r"^[\p{L}\s\-'.]+$", unicode: true);
  if (!allowedCharsRegex.hasMatch(formatted)) return false;

  // 2. Single word check: must contain at least one space separating first and last name.
  final words = formatted.split(RegExp(r'\s+'));
  if (words.length < 2) return false;

  return true;
}
