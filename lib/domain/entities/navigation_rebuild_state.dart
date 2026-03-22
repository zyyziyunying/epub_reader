enum NavigationRebuildState {
  legacyPending('legacy_pending'),
  rebuilding('rebuilding'),
  ready('ready'),
  failed('failed');

  const NavigationRebuildState(this.dbValue);

  final String dbValue;

  static NavigationRebuildState fromDbValue(String? value) {
    return NavigationRebuildState.values.firstWhere(
      (state) => state.dbValue == value,
      orElse: () => NavigationRebuildState.legacyPending,
    );
  }
}
