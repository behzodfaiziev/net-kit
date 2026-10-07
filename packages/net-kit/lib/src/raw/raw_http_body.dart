import 'dart:convert';

import '../utility/file/file_reader.dart';

/// Request body for a transport request.
///
/// The transport does not assume JSON or any application envelope. Bodies
/// fall into two groups:
///
/// - **Replayable**: [BytesRawHttpBody], [StringRawHttpBody],
///   [ReplayableRawHttpBody], [FileRawHttpBody], and [NetKitFormData]. The
///   transport can send them any number of times, so `NetKitManager` may
///   retry such a request after an automatic token refresh or follow a
///   `307`/`308` redirect with it.
/// - **Single-shot**: [StreamRawHttpBody]. A single-subscription stream can
///   be consumed once. The transport never retries, and `NetKitManager`
///   refuses to replay it.
sealed class RawHttpBody {
  /// Creates a raw HTTP body.
  const RawHttpBody();

  /// Whether the transport may send this body more than once.
  bool get isReplayable => this is! StreamRawHttpBody;
}

/// Streaming request body that is forwarded without buffering the payload.
///
/// The transport hands [stream] to the HTTP client as-is, so memory use is
/// bounded by the client's socket buffers rather than by the payload size.
///
/// A single-subscription stream can be sent once. To let the sender retry
/// (for example `NetKitManager` after a token refresh) use
/// [ReplayableRawHttpBody] or [FileRawHttpBody] instead.
final class StreamRawHttpBody extends RawHttpBody {
  /// Creates a streaming body.
  ///
  /// [contentLength] is sent as the `Content-Length` header. The [stream]
  /// must not be fully materialized by the client.
  const StreamRawHttpBody({
    required this.stream,
    required this.contentLength,
  });

  /// Chunked request payload.
  final Stream<List<int>> stream;

  /// Exact number of bytes that [stream] will produce.
  final int contentLength;
}

/// Streaming request body that can be opened again for every send attempt.
///
/// [open] must return a **fresh** stream each time it is called. The first
/// attempt consumes one stream; a retry after a token refresh or a redirect
/// calls [open] again and consumes a new one. Nothing is buffered by
/// net_kit, so memory stays bounded regardless of [contentLength].
///
/// ```dart
/// ReplayableRawHttpBody(
///   open: () => File(path).openRead(),
///   contentLength: await File(path).length(),
/// )
/// ```
final class ReplayableRawHttpBody extends RawHttpBody {
  /// Creates a replayable streaming body.
  const ReplayableRawHttpBody({
    required this.open,
    required this.contentLength,
  });

  /// Returns a new stream over the full payload.
  final Stream<List<int>> Function() open;

  /// Exact number of bytes that each stream returned by [open] produces.
  final int contentLength;
}

/// File-backed replayable body.
///
/// The file is streamed from disk with `File.openRead()` on every send
/// attempt and its length is read with `File.length()`; the content is never
/// loaded into memory as a whole. Not supported on platforms without
/// `dart:io` (the web); sending it there throws [UnsupportedError].
final class FileRawHttpBody extends RawHttpBody {
  /// Creates a file-backed body for the file at [path].
  const FileRawHttpBody(this.path);

  /// Path of the file to upload.
  final String path;

  /// Size of the file in bytes, read from the file system.
  Future<int> length() => fileLength(path);

  /// Opens a fresh read stream over the file.
  Stream<List<int>> openRead() => openFileRead(path);
}

/// In-memory binary request body.
final class BytesRawHttpBody extends RawHttpBody {
  /// Creates a bytes body.
  const BytesRawHttpBody(this.bytes);

  /// Raw bytes to send.
  final List<int> bytes;
}

/// UTF-8 string request body.
///
/// No `Content-Type` is inferred. Supply one on the request if needed.
final class StringRawHttpBody extends RawHttpBody {
  /// Creates a string body.
  const StringRawHttpBody(this.value);

  /// String payload.
  final String value;
}

/// One file part of a [NetKitFormData] body.
///
/// The content is described by a stream factory and a length, so the
/// multipart body can be streamed and re-sent without buffering the file.
final class NetKitMultipartFile {
  /// Creates a file part from a stream factory.
  ///
  /// [open] must return a fresh stream of exactly [length] bytes on every
  /// call.
  const NetKitMultipartFile.fromStream(
    this.open,
    this.length, {
    this.filename,
    this.contentType,
  });

  /// Creates a file part from in-memory bytes.
  NetKitMultipartFile.fromBytes(
    List<int> bytes, {
    String? filename,
    String? contentType,
  }) : this.fromStream(
          () => Stream<List<int>>.value(bytes),
          bytes.length,
          filename: filename,
          contentType: contentType,
        );

  /// Creates a file part from a string, encoded as UTF-8.
  factory NetKitMultipartFile.fromString(
    String value, {
    String? filename,
    String? contentType,
  }) {
    return NetKitMultipartFile.fromBytes(
      utf8.encode(value),
      filename: filename,
      contentType: contentType ?? 'text/plain; charset=utf-8',
    );
  }

  /// Creates a file part that streams the file at [path] from disk.
  ///
  /// The length is read with `File.length()`; the content is streamed with
  /// `File.openRead()` on every send. Not supported on the web.
  static Future<NetKitMultipartFile> fromPath(
    String path, {
    String? filename,
    String? contentType,
  }) async {
    return NetKitMultipartFile.fromStream(
      () => openFileRead(path),
      await fileLength(path),
      filename: filename ?? fileBaseName(path),
      contentType: contentType,
    );
  }

  /// Returns a new stream over the part content.
  final Stream<List<int>> Function() open;

  /// Exact content length in bytes.
  final int length;

  /// File name sent in the part's `Content-Disposition`.
  final String? filename;

  /// MIME type of the part, for example `image/png`.
  final String? contentType;
}

/// `multipart/form-data` request body with text fields and file parts.
///
/// Fields and files are kept as ordered entries so a name may repeat. The
/// transport encodes the body and streams every file part; because each part
/// is described by a stream factory the body is replayable.
final class NetKitFormData extends RawHttpBody {
  /// Creates a multipart body from ordered entries.
  const NetKitFormData({
    this.fields = const [],
    this.files = const [],
  });

  /// Creates a multipart body from a map.
  ///
  /// `String`, `num`, and `bool` values become text fields,
  /// [NetKitMultipartFile] values become file parts, and a `List` value adds
  /// one entry per element under the same name. `null` values are skipped.
  factory NetKitFormData.fromMap(Map<String, Object?> map) {
    final fields = <MapEntry<String, String>>[];
    final files = <MapEntry<String, NetKitMultipartFile>>[];

    void add(String name, Object? value) {
      switch (value) {
        case null:
          return;
        case NetKitMultipartFile():
          files.add(MapEntry(name, value));
        case List():
          for (final element in value) {
            add(name, element);
          }
        case String() || num() || bool():
          fields.add(MapEntry(name, value.toString()));
        default:
          throw ArgumentError.value(
            value,
            name,
            'Unsupported form value type ${value.runtimeType}',
          );
      }
    }

    map.forEach(add);
    return NetKitFormData(fields: fields, files: files);
  }

  /// Text fields in order.
  final List<MapEntry<String, String>> fields;

  /// File parts in order.
  final List<MapEntry<String, NetKitMultipartFile>> files;
}
