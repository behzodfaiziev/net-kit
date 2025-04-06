import '../../../net_kit.dart';

/// A type alias for a function that returns a `Future<void>`.
typedef QueuedRequest = Future<void> Function();

/// A type alias for a function that handles rejection of a request.
typedef RejectionHandler = void Function(DioException e);

/// A class that manages a queue of asynchronous requests.
///
/// The `RequestQueue` class allows adding asynchronous requests to a queue
/// and processes them sequentially. Each request is expected to be a function
/// that returns a `Future<void>`.
///
/// This class is used internally by `NetKit` to handle refresh token requests
/// while ensuring that only one refresh token request is processed at a time.
class RequestQueue {
  /// Creates a new `RequestQueue` with an optional list of requests.
  RequestQueue({
    required INetKitLogger? logger,
    List<QueuedRequest>? queue,
    List<RejectionHandler>? rejections,
  })  : _queue = queue ?? [],
        _rejections = rejections ?? [],
        _logger = logger;

  final List<QueuedRequest> _queue;
  final List<RejectionHandler> _rejections;

  final INetKitLogger? _logger;

  bool _isProcessing = false;

  /// Adds a request to the queue.
  void enqueueDuringRefresh({
    required QueuedRequest request,
    required RejectionHandler onReject,
  }) {
    _queue.add(request);
    _rejections.add(onReject);
  }

  /// Processes the queue of requests.
  ///
  /// This method is called internally to process the queue. It will process
  /// each request in the order it was added, waiting for each request to
  /// complete before moving on to the next one.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      _logger?.info('Processing request queue: ${_queue.length} requests');

      final request = _queue.removeAt(0);
      _rejections.removeAt(0); // Remove its reject handler since it's executing

      try {
        await request();
      } on Exception catch (e, s) {
        _logger?.error('Error processing queued request: $e\n$s');
        // Don't rethrow — keep processing the remaining queue
      }
    }

    _isProcessing = false;
  }

  /// Rejects all queued requests.
  void rejectQueuedRequests() {
    _logger?.info('Rejecting all queued requests');

    while (_rejections.isNotEmpty) {
      final reject = _rejections.removeAt(0);
      reject(
        DioException(
          requestOptions: RequestOptions(),
          message: 'Request was rejected before processing.',
          type: DioExceptionType.cancel,
        ),
      );
    }

    _queue.clear();
  }

  /// Dequeues the first request from the queue.
  Future<void> Function()? dequeue() {
    if (_queue.isNotEmpty) {
      _rejections.removeAt(0); // also clean up the rejection
      return _queue.removeAt(0);
    }
    return null;
  }
}
