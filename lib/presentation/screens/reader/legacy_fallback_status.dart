enum LegacyFallbackStatusKind { loading, error, empty, available }

class LegacyFallbackStatus {
  const LegacyFallbackStatus.loading()
    : kind = LegacyFallbackStatusKind.loading,
      contentCount = null,
      error = null;

  const LegacyFallbackStatus.error(this.error)
    : kind = LegacyFallbackStatusKind.error,
      contentCount = null;

  const LegacyFallbackStatus.empty()
    : kind = LegacyFallbackStatusKind.empty,
      contentCount = 0,
      error = null;

  const LegacyFallbackStatus.available(int count)
    : assert(count > 0),
      kind = LegacyFallbackStatusKind.available,
      contentCount = count,
      error = null;

  final LegacyFallbackStatusKind kind;
  final int? contentCount;
  final Object? error;

  String get drawerHeaderMessage {
    switch (kind) {
      case LegacyFallbackStatusKind.loading:
        return 'Checking legacy fallback content for this session.';
      case LegacyFallbackStatusKind.error:
        return 'Legacy fallback content failed to load for this session.';
      case LegacyFallbackStatusKind.empty:
        return 'Legacy fallback mode is active, but this book has no persisted fallback content for this session.';
      case LegacyFallbackStatusKind.available:
        return 'Legacy fallback mode keeps continuous reading available while document navigation is unavailable.';
    }
  }

  String get drawerContentSummary {
    switch (kind) {
      case LegacyFallbackStatusKind.loading:
        return 'Checking legacy fallback content';
      case LegacyFallbackStatusKind.error:
        return 'Legacy fallback load failed';
      case LegacyFallbackStatusKind.empty:
        return 'No legacy fallback content';
      case LegacyFallbackStatusKind.available:
        return '$contentCount legacy content items';
    }
  }

  String get panelTitle {
    switch (kind) {
      case LegacyFallbackStatusKind.loading:
        return 'Checking legacy fallback';
      case LegacyFallbackStatusKind.error:
        return 'Legacy fallback failed';
      case LegacyFallbackStatusKind.empty:
        return 'Legacy fallback unavailable';
      case LegacyFallbackStatusKind.available:
        return 'Navigation unavailable';
    }
  }

  String get panelMessage {
    switch (kind) {
      case LegacyFallbackStatusKind.loading:
        return 'Loading persisted legacy fallback content for this session.';
      case LegacyFallbackStatusKind.error:
        return 'Failed to load persisted legacy fallback content for this session.';
      case LegacyFallbackStatusKind.empty:
        return 'This session has no persisted legacy fallback content. Reopen the book after a successful rebuild or reimport the book.';
      case LegacyFallbackStatusKind.available:
        return 'This session is using legacy fallback content. Reopen the book after a successful rebuild to use document navigation.';
    }
  }

  String get bottomBarTitle {
    switch (kind) {
      case LegacyFallbackStatusKind.loading:
        return 'Checking legacy fallback';
      case LegacyFallbackStatusKind.error:
        return 'Legacy fallback failed';
      case LegacyFallbackStatusKind.empty:
        return 'Legacy fallback unavailable';
      case LegacyFallbackStatusKind.available:
        return 'Legacy fallback mode';
    }
  }

  String get bottomBarSubtitle {
    switch (kind) {
      case LegacyFallbackStatusKind.loading:
        return 'Loading persisted legacy fallback content for this session...';
      case LegacyFallbackStatusKind.error:
        return 'Failed to load persisted legacy fallback content for this session.';
      case LegacyFallbackStatusKind.empty:
        return 'This session has no persisted legacy fallback content. Reopen after a successful rebuild or reimport the book.';
      case LegacyFallbackStatusKind.available:
        return 'Continuous reading stays available in this session while document navigation is unavailable.';
    }
  }

  String? get diagnosticDetails => error?.toString();
}
