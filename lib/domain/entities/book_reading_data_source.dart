enum BookReadingDataSource {
  legacy,
  v2;

  bool get usesV2 => this == BookReadingDataSource.v2;
}
