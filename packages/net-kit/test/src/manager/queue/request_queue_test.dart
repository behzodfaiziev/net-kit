import 'dart:async';

import 'package:net_kit/src/manager/queue/request_queue.dart';
import 'package:test/test.dart';

void main() {
  late RequestQueue requestQueue;

  setUp(() {
    requestQueue = RequestQueue();
  });

  group('RequestQueue', () {
    test('should add a request to the queue and process it', () async {
      // Arrange

      // ignore: omit_local_variable_types
      bool wasProcessed = false;

      // Act
      requestQueue.add(() async {
        wasProcessed = true;
      });

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
        ..add(() async {
          processedOrder.add(1);
        })
        ..add(() async {
          processedOrder.add(2);
        })
        ..add(() async {
          processedOrder.add(3);
        });

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

      // ignore: omit_local_variable_types
      int counter = 0;
      requestQueue.add(() async {
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
        ..add(() async {
          rejectedRequests.add(1);
        })
        ..add(() async {
          rejectedRequests.add(2);
        })
        ..add(() async {
          rejectedRequests.add(3);
        })

        // Act
        ..rejectQueuedRequests();

      // Wait for any potential asynchronous processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(rejectedRequests, [1, 2, 3]);
    });
  });
}
