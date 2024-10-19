/// A class that manages a queue of asynchronous requests.
///
/// The `RequestQueue` class allows to add asynchronous requests to a queue
/// and processes them sequentially. Each request is expected to be a function
/// that returns a `Future<void>`.
///
/// This class is used internally by `NetKit` to handle refresh token requests
/// while ensuring that only one refresh token request is processed at a time.
class RequestQueue {
  /// Creates a new `RequestQueue` with an optional list of requests.
  RequestQueue({List<Future<void> Function()>? queue}) : _queue = queue ?? [];

  final List<Future<void> Function()> _queue;

  bool _isProcessing = false;

  /// Adds a new request to the queue.
  /// This method is called internally by `NetKit` to add requests to the queue.
  /// The [request] parameter is a function that returns a `Future<void>`.
  /// The request will be added to the queue
  /// and processed in the order it was added.
  ///
  /// Example:
  /// ```dart
  /// final queue = RequestQueue();
  /// queue.add(() async {
  ///   // Your async code here
  /// });
  /// ```
  void add(Future<void> Function() request) {
    _queue.add(request);
    processQueue();
  }

  /// Processes the queue of requests.
  ///
  /// This method is called internally to process the queue. It will process
  /// each request in the order it was added,
  /// waiting for each request to complete
  /// before moving on to the next one.
  ///
  /// This method should not be called directly.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      await request();
    }

    _isProcessing = false;
  }

  /// Dequeues the first request from the queue.
  ///
  /// Returns the first request (as a `Future<void> Function()`)
  /// from the queue, or `null` if the queue is empty.
  Future<void> Function()? dequeue() {
    if (_queue.isNotEmpty) {
      return _queue.removeAt(0);
    }
    return null;
  }

  /// Rejects all queued requests.
  void rejectQueuedRequests() {
    while (_queue.isNotEmpty) {
      final queuedRequest = _queue.removeAt(0);

      queuedRequest.call();
    }
  }
}
