/// Helper function to sanitize and validate human real names for order pickups.
///
/// Returns [false] if the name:
/// - Contains emojis, numbers, or special symbols.
/// - Is a single word (does not contain at least one space).
/// - Is entirely lowercase.
/// - Fails standard capitalization (each name word must start with an uppercase letter).
///
/// Returns [true] only for standard human names (letters, spaces, hyphens, and standard capitalization).
bool isValidRealName(String? name) {
  if (name == null) return false;
  final trimmed = name.trim();
  if (trimmed.isEmpty) return false;

  // 1. Check for allowed characters: Unicode letters (\p{L}), spaces, hyphens, apostrophes, periods.
  // Excludes numbers, emojis, and special symbols (@, #, $, %, !, _, *, etc.).
  final allowedCharsRegex = RegExp(r"^[\p{L}\s\-'\.]+$", unicode: true);
  if (!allowedCharsRegex.hasMatch(trimmed)) return false;

  // 2. Single word check: must contain at least one space separating first and last name.
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length < 2) return false;

  // 3. Entirely lowercase check: e.g., "john doe" is invalid.
  if (trimmed == trimmed.toLowerCase()) return false;

  // 4. Standard capitalization check: each word must start with a capital letter.
  for (final word in words) {
    if (word.isEmpty) return false;
    final firstChar = word[0];
    if (firstChar != firstChar.toUpperCase() ||
        firstChar == firstChar.toLowerCase()) {
      return false;
    }
  }

  return true;
}
