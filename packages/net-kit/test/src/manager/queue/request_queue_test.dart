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
      var wasProcessed = false;

      requestQueue.enqueueDuringRefresh(
        request: () async {
          wasProcessed = true;
        },
        onReject: (_) {},
      );

      await requestQueue.processQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(wasProcessed, isTrue);
    });

    test('should process requests in the order they were added', () async {
      final processedOrder = <int>[];

      for (var i = 0; i < 3; i++) {
        requestQueue.enqueueDuringRefresh(
          request: () async => processedOrder.add(i + 1),
          onReject: (_) {},
        );
      }

      await requestQueue.processQueue();

      expect(processedOrder, [1, 2, 3]);
    });

    test('should return null when dequeue is called on an empty queue', () {
      final result = requestQueue.dequeue();
      expect(result, isNull);
    });

    test('should dequeue the first request from the queue', () async {
      var counter = 0;

      requestQueue.enqueueDuringRefresh(
        request: () async => counter++,
        onReject: (_) {},
      );

      final dequeuedRequest = requestQueue.dequeue();
      await dequeuedRequest?.call();

      expect(counter, 1);
    });

    test('should reject all queued requests', () async {
      final rejected = <String>[];

      for (var i = 0; i < 3; i++) {
        requestQueue.enqueueDuringRefresh(
          request: () async {},
          onReject: (e) => rejected.add('rejected $i'),
        );
      }

      requestQueue.rejectQueuedRequests();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(rejected, ['rejected 0', 'rejected 1', 'rejected 2']);
    });

    test('should handle multiple enqueueDuringRefresh calls safely', () async {
      final results = <int>[];

      for (var i = 0; i < 10; i++) {
        requestQueue.enqueueDuringRefresh(
          request: () async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
            results.add(i);
          },
          onReject: (_) {},
        );
      }

      await requestQueue.processQueue();
      expect(results, List.generate(10, (i) => i));
    });

    test('should not allow reentrant processing', () async {
      var count = 0;

      requestQueue.enqueueDuringRefresh(
        request: () async {
          count++;
          await requestQueue.processQueue();
        },
        onReject: (_) {},
      );

      await requestQueue.processQueue();
      expect(count, 1);
    });

    test('should reject requests before processing begins', () async {
      var executed = false;

      requestQueue
        ..enqueueDuringRefresh(
          request: () async => executed = true,
          onReject: (_) {},
        )
        ..rejectQueuedRequests();

      await requestQueue.processQueue();
      expect(executed, isFalse);
    });

    test('should continue processing if a queued request throws', () async {
      final output = <String>[];

      requestQueue
        ..enqueueDuringRefresh(
          request: () async => output.add('start'),
          onReject: (_) {},
        )
        ..enqueueDuringRefresh(
          request: () async => throw Exception('fail'),
          onReject: (_) {},
        )
        ..enqueueDuringRefresh(
          request: () async => output.add('end'),
          onReject: (_) {},
        );

      await requestQueue.processQueue();

      expect(output, ['start', 'end']);
    });

    test('should handle large number of queued requests', () async {
      final results = <int>[];

      for (var i = 0; i < 100; i++) {
        requestQueue.enqueueDuringRefresh(
          request: () async => results.add(i),
          onReject: (_) {},
        );
      }

      await requestQueue.processQueue();

      expect(results.length, 100);
      expect(results.first, 0);
      expect(results.last, 99);
    });

    test('should not process a request more than once', () async {
      var count = 0;

      requestQueue.enqueueDuringRefresh(
        request: () async => count++,
        onReject: (_) {},
      );

      await requestQueue.processQueue();
      await requestQueue.processQueue();

      expect(count, 1);
    });
  });
}
