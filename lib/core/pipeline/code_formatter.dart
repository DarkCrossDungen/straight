class CodeFormatter {
  String process(String text) {
    if (text.isEmpty) return text;

    var result = text;

    // 1. camelCase: "camel case user authentication token" -> "userAuthenticationToken"
    result = result.replaceAllMapped(
      RegExp(r'\b(?:camel\s*case)\s+([a-zA-Z0-9\s]+?)(?=[,\.\?!]|\b(?:and|or|then)\b|$)', caseSensitive: false),
      (m) => _toCamelCase(m[1]!.trim()),
    );

    // 2. snake_case: "snake case user authentication token" -> "user_authentication_token"
    result = result.replaceAllMapped(
      RegExp(r'\b(?:snake\s*case)\s+([a-zA-Z0-9\s]+?)(?=[,\.\?!]|\b(?:and|or|then)\b|$)', caseSensitive: false),
      (m) => _toSnakeCase(m[1]!.trim()),
    );

    // 3. kebab-case: "kebab case user authentication token" -> "user-authentication-token"
    result = result.replaceAllMapped(
      RegExp(r'\b(?:kebab\s*case)\s+([a-zA-Z0-9\s]+?)(?=[,\.\?!]|\b(?:and|or|then)\b|$)', caseSensitive: false),
      (m) => _toKebabCase(m[1]!.trim()),
    );

    // 4. SCREAMING_CASE: "screaming case max retry count" -> "MAX_RETRY_COUNT"
    result = result.replaceAllMapped(
      RegExp(r'\b(?:screaming\s*case)\s+([a-zA-Z0-9\s]+?)(?=[,\.\?!]|\b(?:and|or|then)\b|$)', caseSensitive: false),
      (m) => _toScreamingCase(m[1]!.trim()),
    );

    // 5. PascalCase: "pascal case user authentication token" -> "UserAuthenticationToken"
    result = result.replaceAllMapped(
      RegExp(r'\b(?:pascal\s*case)\s+([a-zA-Z0-9\s]+?)(?=[,\.\?!]|\b(?:and|or|then)\b|$)', caseSensitive: false),
      (m) => _toPascalCase(m[1]!.trim()),
    );

    return result;
  }

  String _toCamelCase(String phrase) {
    final words = phrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return phrase;
    final first = words.first.toLowerCase();
    final rest = words.skip(1).map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}');
    return '$first${rest.join()}';
  }

  String _toPascalCase(String phrase) {
    final words = phrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join();
  }

  String _toSnakeCase(String phrase) {
    final words = phrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.map((w) => w.toLowerCase()).join('_');
  }

  String _toKebabCase(String phrase) {
    final words = phrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.map((w) => w.toLowerCase()).join('-');
  }

  String _toScreamingCase(String phrase) {
    final words = phrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.map((w) => w.toUpperCase()).join('_');
  }
}
