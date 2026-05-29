/// Stub implementation for platforms without dart:io (e.g. web).
Future<List<int>> readFileAsBytes(String path) {
  throw UnsupportedError(
    'uploadFile is not supported on this platform. '
    'Use uploadRawData with bytes instead.',
  );
}
