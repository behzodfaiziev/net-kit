Never _unsupported() => throw UnsupportedError(
      'File-backed request bodies are not supported on this platform. '
      'Use uploadRawData or NetKitMultipartFile.fromBytes with bytes instead.',
    );

/// Stub for platforms without `dart:io` (for example the web).
Stream<List<int>> openFileRead(String path) => _unsupported();

/// Stub for platforms without `dart:io` (for example the web).
Future<int> fileLength(String path) => _unsupported();

/// Stub for platforms without `dart:io` (for example the web).
String fileBaseName(String path) => path.split('/').last;
