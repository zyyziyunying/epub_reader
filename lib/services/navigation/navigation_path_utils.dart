class NavigationPathUtils {
  const NavigationPathUtils._();

  static String? normalizePackagePath(String rawPath) {
    return _normalizeSegments(_splitSegments(rawPath), const <String>[]);
  }

  static String? resolvePackagePath({
    required String rawPath,
    required String baseDir,
  }) {
    return _normalizeSegments(_splitSegments(rawPath), _splitSegments(baseDir));
  }

  static String dirname(String? filePath) {
    final normalized = filePath == null ? null : normalizePackagePath(filePath);
    if (normalized == null) {
      return '';
    }

    final index = normalized.lastIndexOf('/');
    if (index < 0) {
      return '';
    }

    return normalized.substring(0, index);
  }

  static String basenameWithoutExtension(String filePath) {
    final normalized = normalizePackagePath(filePath);
    if (normalized == null) {
      return '';
    }

    final slashIndex = normalized.lastIndexOf('/');
    final name = slashIndex >= 0 ? normalized.substring(slashIndex + 1) : normalized;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0) {
      return name;
    }

    return name.substring(0, dotIndex);
  }

  static List<String> _splitSegments(String rawPath) {
    if (rawPath.trim().isEmpty) {
      return const <String>[];
    }

    final decoded = _decodePercent(rawPath).replaceAll('\\', '/');
    return decoded.split('/');
  }

  static String? _normalizeSegments(
    List<String> pathSegments,
    List<String> baseSegments,
  ) {
    final segments = <String>[...baseSegments];

    for (final segment in pathSegments) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }

      if (segment == '..') {
        if (segments.isNotEmpty) {
          segments.removeLast();
        }
        continue;
      }

      segments.add(segment);
    }

    if (segments.isEmpty) {
      return null;
    }

    return segments.join('/');
  }

  static String _decodePercent(String value) {
    try {
      return Uri.decodeFull(value);
    } on FormatException {
      return value;
    }
  }
}
