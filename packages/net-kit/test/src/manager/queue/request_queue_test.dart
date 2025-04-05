import 'dart:async';

import 'package:net_kit/src/manager/queue/request_queue.dart';
import 'package:test/test.dart';

void main() {
  late RequestQueue requestQueue;

  setUp(() {
    requestQueue = RequestQueue(logger: null);
  });

  group('RequestQueue', () {
    test('should add a request to the queue and process it', () async {
      // Arrange

      var wasProcessed = false;

      // Act
      requestQueue.enqueueDuringRefresh(() async {
        wasProcessed = true;
      });

      // Process the queue
      await requestQueue.processQueue();

      // Wait for the processing to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(wasProcessed, isTrue);
    });

    test('should process requests in the order they were added', () async {
      // Arrange
      final processedOrder = <int>[];

      // Act
      requestQueue
        ..enqueueDuringRefresh(() async {
          processedOrder.add(1);
        })
        ..enqueueDuringRefresh(() async {
          processedOrder.add(2);
        })
        ..enqueueDuringRefresh(() async {
          processedOrder.add(3);
        });

      await requestQueue.processQueue();

      // Wait for processing to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(processedOrder, [1, 2, 3]);
    });

    test('should return null when dequeue is called on an empty queue', () {
      // Act
      final result = requestQueue.dequeue();

      // Assert
      expect(result, isNull);
    });

    test('should dequeue the first request from the queue', () async {
      // Arrange

      var counter = 0;
      requestQueue.enqueueDuringRefresh(() async {
        counter++;
      });

      // Act
      final dequeuedRequest = requestQueue.dequeue();

      // Call the dequeued request
      await dequeuedRequest?.call();

      // Assert
      expect(counter, 1);
    });

    test('should reject all queued requests', () async {
      // Arrange
      final rejectedRequests = <int>[];
      requestQueue
        ..enqueueDuringRefresh(() async {
          rejectedRequests.add(1);
        })
        ..enqueueDuringRefresh(() async {
          rejectedRequests.add(2);
        })
        ..enqueueDuringRefresh(() async {
          rejectedRequests.add(3);
        })

        // Act
        ..rejectQueuedRequests();

      // Wait for any potential asynchronous processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(rejectedRequests, isEmpty);
    });
    test('should handle multiple enqueueDuringRefresh calls safely', () async {
      final results = <int>[];

      for (var i = 0; i < 10; i++) {
        requestQueue.enqueueDuringRefresh(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          results.add(i);
        });
      }

      await requestQueue.processQueue();

      expect(results, List.generate(10, (index) => index));
    });
    test('should not allow reentrant processing', () async {
      var processingCount = 0;

      requestQueue.enqueueDuringRefresh(() async {
        processingCount++;
        await requestQueue.processQueue(); // this should do nothing
      });

      await requestQueue.processQueue();

      expect(processingCount, 1);
    });
    test('should reject requests before processing begins', () async {
      var executed = false;

      requestQueue
        ..enqueueDuringRefresh(() async {
          executed = true;
        })
        ..rejectQueuedRequests();

      await requestQueue.processQueue();

      expect(executed, isFalse);
    });
    test('should continue processing if a queued request throws', () async {
      final results = <String>[];

      requestQueue
        ..enqueueDuringRefresh(() async {
          results.add('start');
        })
        ..enqueueDuringRefresh(() async {
          throw Exception('Oops');
        })
        ..enqueueDuringRefresh(() async {
          results.add('end');
        });

      await requestQueue.processQueue();

      expect(results, ['start', 'end']);
    });
    test('should handle large number of queued requests', () async {
      final results = <int>[];

      for (var i = 0; i < 100; i++) {
        requestQueue.enqueueDuringRefresh(() async {
          results.add(i);
        });
      }

      await requestQueue.processQueue();

      expect(results.length, 100);
      expect(results.first, 0);
      expect(results.last, 99);
    });
    test('should not process a request more than once', () async {
      var callCount = 0;

      requestQueue.enqueueDuringRefresh(() async {
        callCount++;
      });

      await requestQueue.processQueue();
      await requestQueue.processQueue(); // this should not rerun anything

      expect(callCount, 1);
    });
  });
}
