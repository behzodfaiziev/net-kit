import 'dart:async';

import 'package:dio/dio.dart';
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
      expect(wasProcessed, isTrue);
    });

    test('should process requests in the order they were added', () async {
      final order = <int>[];

      for (var i = 0; i < 3; i++) {
        requestQueue.enqueueDuringRefresh(
          request: () async => order.add(i + 1),
          onReject: (_) {},
        );
      }

      await requestQueue.processQueue();
      expect(order, [1, 2, 3]);
    });

    test('should return null when dequeue is called on an empty queue', () {
      expect(requestQueue.dequeue(), isNull);
    });

    test('should dequeue the first request from the queue', () async {
      var count = 0;

      requestQueue.enqueueDuringRefresh(
        request: () async => count++,
        onReject: (_) {},
      );

      final fn = requestQueue.dequeue();
      await fn?.call();

      expect(count, 1);
    });

    test('should reject all queued requests', () async {
      final rejections = <String>[];

      for (var i = 0; i < 3; i++) {
        requestQueue.enqueueDuringRefresh(
          request: () async {},
          onReject: (e) => rejections.add('Rejected $i'),
        );
      }

      requestQueue.rejectQueuedRequests();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(rejections, ['Rejected 0', 'Rejected 1', 'Rejected 2']);
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
      expect(results.length, 10);
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
      var rejected = false;

      requestQueue
        ..enqueueDuringRefresh(
          request: () async => executed = true,
          onReject: (_) => rejected = true,
        )
        ..rejectQueuedRequests();
      await requestQueue.processQueue();

      expect(executed, isFalse);
      expect(rejected, isTrue);
    });

    test('should continue processing if a queued request throws', () async {
      final log = <String>[];

      requestQueue
        ..enqueueDuringRefresh(
          request: () async => log.add('before'),
          onReject: (_) {},
        )
        ..enqueueDuringRefresh(
          request: () async => throw Exception('boom'),
          onReject: (_) {},
        )
        ..enqueueDuringRefresh(
          request: () async => log.add('after'),
          onReject: (_) {},
        );

      await requestQueue.processQueue();
      expect(log, ['before', 'after']);
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
      var callCount = 0;

      requestQueue.enqueueDuringRefresh(
        request: () async => callCount++,
        onReject: (_) {},
      );

      await requestQueue.processQueue();
      await requestQueue.processQueue(); // second call shouldn't reprocess

      expect(callCount, 1);
    });

    test('should reject each request with DioException', () async {
      final rejections = <DioException>[];

      for (var i = 0; i < 3; i++) {
        requestQueue.enqueueDuringRefresh(
          request: () async => throw Exception('Should not run'),
          onReject: rejections.add,
        );
      }

      requestQueue.rejectQueuedRequests();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(rejections.length, 3);
      for (final r in rejections) {
        expect(r, isA<DioException>());
        expect(r.message, 'Request was rejected before processing.');
      }
    });
  });
}
