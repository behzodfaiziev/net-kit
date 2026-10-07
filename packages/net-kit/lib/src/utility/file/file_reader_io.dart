import 'dart:io';

/// Opens a fresh read stream over the file at [path].
Stream<List<int>> openFileRead(String path) => File(path).openRead();

/// Returns the size of the file at [path] in bytes.
Future<int> fileLength(String path) => File(path).length();

/// Last path segment of [path], used as a default multipart filename.
String fileBaseName(String path) => Uri.file(path).pathSegments.last;
