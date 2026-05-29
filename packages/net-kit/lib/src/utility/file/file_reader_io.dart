import 'dart:io';

/// IO implementation that reads a file from disk as raw bytes.
Future<List<int>> readFileAsBytes(String path) {
  return File(path).readAsBytes();
}
