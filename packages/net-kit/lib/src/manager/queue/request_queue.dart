class RequestQueue {
  final List<Function> _queue = [];
  bool _isProcessing = false;

  void add(Function request) {
    _queue.add(request);
    processQueue();
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      await request();
    }

    _isProcessing = false;
  }

  bool get isNotEmpty => _queue.isNotEmpty;
}
