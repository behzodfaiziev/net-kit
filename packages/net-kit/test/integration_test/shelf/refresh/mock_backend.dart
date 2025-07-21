import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

// Simple in-memory backend state for one test case.
class TestBackendState {
  TestBackendState({
    this.accessToken = 'ACCESS_1',
    this.refreshToken = 'REFRESH_1',
    this.refreshCallCount = 0,
    Set<String>? usedRefreshTokens,
    Set<String>? revokedAccessTokens,
    this.refreshDelayMs = 0,
    this.simulateRefreshFailure = false,
  })  : usedRefreshTokens = usedRefreshTokens ?? <String>{},
        revokedAccessTokens = revokedAccessTokens ?? <String>{},
        _refreshTokenCounter = 1;
  String accessToken;
  String refreshToken;
  int refreshCallCount;
  final Set<String> usedRefreshTokens;
  final Set<String> revokedAccessTokens;
  int refreshDelayMs;
  bool simulateRefreshFailure;
  int _refreshTokenCounter;

  void reset() {
    accessToken = 'ACCESS_1';
    refreshToken = 'REFRESH_1';
    refreshCallCount = 0;
    usedRefreshTokens.clear();
    revokedAccessTokens.clear();
    refreshDelayMs = 0;
    simulateRefreshFailure = false;
    _refreshTokenCounter = 1;
  }

  void rotateTokens() {
    _refreshTokenCounter++;
    accessToken = 'ACCESS_$_refreshTokenCounter';
    refreshToken = 'REFRESH_$_refreshTokenCounter';
  }
}

// Build the backend handler for shelf.
Handler buildBackendHandler(TestBackendState state) {
  return (Request req) async {
    // --- Refresh Endpoint ---
    if (req.url.path == 'api/refresh') {
      if (state.refreshDelayMs > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: state.refreshDelayMs),
        );
      }
      if (state.simulateRefreshFailure) {
        return Response.internalServerError(
          body: jsonEncode({'message': 'Simulated network error'}),
        );
      }
      final body = await req.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final refreshToken = data['refreshToken'] as String?;
      if (refreshToken == null) {
        return Response(
          400,
          body: jsonEncode({'message': 'Refresh token is required'}),
        );
      }

      if (state.usedRefreshTokens.contains(refreshToken) ||
          refreshToken != state.refreshToken) {
        return Response(
          400,
          body:
              jsonEncode({'message': 'Refresh token invalid or already used'}),
        );
      }

      state.usedRefreshTokens.add(refreshToken);
      state
        ..rotateTokens()
        ..refreshCallCount += 1;
      return Response.ok(
        jsonEncode(
          {
            'data': {
              'accessToken': state.accessToken,
              'refreshToken': state.refreshToken,
            },
          },
        ),
        headers: {'content-type': 'application/json'},
      );
    }
    // --- Protected Endpoints ---
    if (req.url.path == 'api/user/current' ||
        req.url.path == 'api/posts/all' ||
        req.url.path == 'api/posts/likes' ||
        req.url.path == 'api/messages/all') {
      final authHeader = req.headers['authorization'];
      if (authHeader != 'Bearer ${state.accessToken}' ||
          state.revokedAccessTokens.contains(authHeader)) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }
      return Response.ok(
        jsonEncode(
          {
            'data': {'result': 'ok', 'path': req.url.path},
          },
        ),
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.notFound('Not found');
  };
}
