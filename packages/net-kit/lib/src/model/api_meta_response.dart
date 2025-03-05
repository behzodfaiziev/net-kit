/// A class representing a response with metadata.
class ApiMetaResponse<T, M> {
  /// Creates an instance of [ApiMetaResponse].
  ///
  /// [data] is the main data of the response.
  /// [metadata] is additional information about the response.
  ApiMetaResponse({
    required this.data,
    required this.metadata,
  });

  /// The main data of the response.
  final T data;

  /// Additional information about the response.
  final M metadata;
}
