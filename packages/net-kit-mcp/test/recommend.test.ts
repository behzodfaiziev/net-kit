import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { recommend } from '../src/patterns/recommend.js';

describe('recommend_netkit_pattern logic', () => {
  it('external signed upload goes through the transport, never with the app token', () => {
    const r = recommend({
      authenticated: true,
      externalUrl: true,
      largeRequestBody: true,
      requiresReplay: false,
      streamResponse: false,
    });
    assert.equal(r.client, 'RawHttpClient (NetKitTransport)');
    assert.equal(r.requestBody, 'FileRawHttpBody(filePath)');
    assert.equal(r.authPolicy, null);
    assert.ok(r.patterns.includes('signed-external-upload'));
    assert.ok(r.warnings.some((w) => w.includes('access token')));
  });

  it('large upload to the API streams and replays through NetKitManager', () => {
    const r = recommend({ destination: 'api', bodySource: 'file', httpMethod: 'PUT' });
    assert.equal(r.client, 'NetKitManager');
    assert.match(r.call, /uploadFile/);
    assert.equal(r.authPolicy, 'AuthPolicy.inherit');
    assert.ok(r.patterns.includes('replayable-authenticated-upload'));
  });

  it('public endpoints use AuthPolicy.none', () => {
    assert.equal(
      recommend({ publicEndpoint: true, bodySource: 'json' }).authPolicy,
      'AuthPolicy.none',
    );
  });

  it('a POST that must survive a refresh opts in to the retry with an idempotency key', () => {
    const r = recommend({ bodySource: 'json', httpMethod: 'POST', requiresReplay: true });
    assert.ok(r.options.includes('allowRetryOn401: true'));
    assert.ok(r.options.some((o) => o.startsWith('idempotencyKey')));
  });

  it('a replayable external stream uses ReplayableRawHttpBody', () => {
    const r = recommend({ externalUrl: true, bodySource: 'stream', requiresReplay: true });
    assert.match(r.requestBody ?? '', /ReplayableRawHttpBody/);
  });

  it('streaming downloads use sendStreamed; the manager says it cannot stream', () => {
    assert.match(recommend({ externalUrl: true, streamResponse: true }).call, /sendStreamed/);
    assert.ok(
      recommend({ destination: 'api', streamResponse: true }).warnings.some((w) =>
        w.includes('signed download URL'),
      ),
    );
  });

  it('is deterministic', () => {
    const input = {
      externalUrl: true,
      bodySource: 'file',
      needsCancellation: true,
      needsProgress: true,
    } as const;
    assert.deepEqual(recommend(input), recommend(input));
  });
});
