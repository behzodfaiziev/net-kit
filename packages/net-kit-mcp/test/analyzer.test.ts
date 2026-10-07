import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { analyzeWorkspace, managerConfigurations } from '../src/analyzer/engine.js';
import { parseDartFile } from '../src/analyzer/model.js';
import { RULES } from '../src/analyzer/rules/index.js';
import type { Finding, ProjectFacts } from '../src/analyzer/types.js';
import { tokenize } from '../src/dart/lexer.js';
import { redactCode } from '../src/util/redactCode.js';
import { DEFAULT_LIMITS } from '../src/workspace/limits.js';
import { authorizeRoots } from '../src/workspace/roots.js';
import { WorkspaceSession } from '../src/workspace/session.js';
import * as F from './fixtures/dart.js';
import { tempTree } from './helpers.js';

const V6_FACTS: ProjectFacts = {
  netKitConstraint: '^6.0.0-dev.1',
  resolvedNetKitVersion: null,
  targetMajor: 6,
  apiHosts: ['api.example.com'],
  usesRefresh: true,
};

function run(source: string, facts: ProjectFacts = V6_FACTS): Finding[] {
  const files = [parseDartFile('lib/sample.dart', source)];
  return RULES.flatMap((rule) => rule.run({ files, facts }));
}

function ids(findings: readonly Finding[]): string[] {
  return findings.map((f) => f.ruleId).sort();
}

function only(findings: readonly Finding[], ruleId: string): Finding[] {
  return findings.filter((f) => f.ruleId === ruleId);
}

describe('lexer', () => {
  it('keeps code inside comments and strings out of the token stream', () => {
    const tokens = tokenize(F.LEXER_TRAPS).filter((t) => t.kind === 'ident');
    assert.ok(!tokens.some((t) => t.text === 'uploadRawData'));
    assert.ok(!tokens.some((t) => t.text === 'allowCrossOriginRequests'));
    assert.equal(tokens.filter((t) => t.text === 'NetKitManager').length, 0);
  });

  it('produces no findings for code that only appears in comments or strings', () => {
    assert.deepEqual(run(F.LEXER_TRAPS), []);
  });

  it('reads string values, raw strings, and triple quotes', () => {
    const strings = tokenize(`var a = 'x\\'y'; var b = r'\\d+'; var c = """multi\nline""";`).filter(
      (t) => t.kind === 'string',
    );
    assert.deepEqual(
      strings.map((s) => s.value),
      ["x\\'y", '\\d+', 'multi\nline'],
    );
  });
});

describe('semantic rules: correct code is not flagged', () => {
  for (const [name, source] of Object.entries({
    GOOD_AUTH: F.GOOD_AUTH,
    SIGNED_UPLOAD_GOOD: F.SIGNED_UPLOAD_GOOD,
    STREAMING_GOOD: F.STREAMING_GOOD,
    LOGGING_GOOD: F.LOGGING_GOOD,
    DIO_ONLY: F.DIO_ONLY,
  })) {
    it(name, () => {
      assert.deepEqual(
        run(source).map((f) => `${f.ruleId} line ${f.range.startLine}: ${f.message}`),
        [],
      );
    });
  }
});

describe('semantic rules: unsafe code is flagged', () => {
  it('auth and configuration problems', () => {
    const findings = run(F.BAD_AUTH);
    assert.deepEqual(ids(findings), [
      'NK002',
      'NK003',
      'NK007',
      'NK007',
      'NK007',
      'NK011',
      'NK012',
      'NK014',
      'NK015',
      'NK016',
    ]);
    assert.equal(only(findings, 'NK003')[0]?.severity, 'error');
    const signOut = only(findings, 'NK007')
      .map((f) => f.confidence)
      .sort();
    assert.deepEqual(signOut, ['high', 'medium', 'medium']);
    assert.ok(
      only(findings, 'NK007').every((f) => f.suggestion?.label === 'SUGGESTED — NOT APPLIED'),
    );
  });

  it('signed-upload and upload problems', () => {
    const findings = run(F.SIGNED_UPLOAD_BAD);
    assert.deepEqual(ids(findings), [
      'NK001',
      'NK004',
      'NK004',
      'NK008',
      'NK008',
      'NK009',
      'NK013',
    ]);
    assert.equal(only(findings, 'NK001')[0]?.confidence, 'medium');
    assert.equal(only(findings, 'NK009')[0]?.confidence, 'high');
    assert.ok(only(findings, 'NK008').every((f) => f.confidence === 'low'));
  });

  it('a signed URL literal through the manager is high confidence', () => {
    const findings = run(`
import 'package:net_kit/net_kit.dart';
Future<void> f(NetKitManager manager) => manager.requestVoid(
  path: 'https://storage.example.com/o?X-Amz-Signature=deadbeef&X-Amz-Credential=key',
  method: RequestMethod.put,
);`);
    const nk001 = only(findings, 'NK001');
    assert.equal(nk001.length, 1);
    const first = nk001[0];
    assert.ok(first !== undefined);
    assert.equal(first.confidence, 'high');
    assert.ok(
      first.suggestion !== undefined && !first.suggestion.currentPattern.includes('deadbeef'),
      'signature redacted',
    );
    assert.equal(only(findings, 'NK003').length, 0, 'no duplicate external-origin finding');
  });

  it('buffered large download', () => {
    const findings = run(F.STREAMING_BAD);
    assert.deepEqual(ids(findings), ['NK010']);
    assert.equal(findings[0]?.confidence, 'high');
  });

  it('body logging without sanitizer', () => {
    assert.deepEqual(ids(run(F.LOGGING_BAD, { ...V6_FACTS, usesRefresh: false })), ['NK012']);
  });

  it('direct Dio next to net_kit is a low/medium review hint only', () => {
    const findings = run(F.DIO_DIRECT);
    assert.deepEqual(ids(findings), ['NK006', 'NK006']);
    assert.ok(findings.every((f) => f.severity === 'info'));
  });

  it('net_kit 5.x usage', () => {
    const findings = only(run(F.LEGACY_V5), 'NK005');
    const details = findings.map((f) => f.message.split(':')[0] ?? '');
    for (const expected of [
      'requestVoid(containsAccessToken',
      'requestVoid(skipTokenRefresh',
      'requestVoid(cancelToken',
      'requestVoid(options',
      'NetKitManager(baseOptions',
      'NetKitManager(testMode',
      'NetKitManager(onRefreshFailed',
      'uploadFormData(formData',
      'CancelToken',
      'Options',
      'BaseOptions',
      'FormData',
      'DioException',
    ]) {
      assert.ok(
        details.some((d) => d.startsWith(expected)),
        `missing ${expected}`,
      );
    }
    assert.ok(
      findings.every((f) => f.severity === 'error'),
      'project targets v6',
    );
    assert.ok(findings.some((f) => f.message.startsWith('DioRawHttpClient()')));
  });

  it('5.x usage in a project still on 5.x is reported as a migration item', () => {
    const findings = only(run(F.LEGACY_V5, { ...V6_FACTS, targetMajor: 5 }), 'NK005');
    assert.ok(findings.some((f) => f.severity === 'info'));
    assert.ok(
      findings
        .filter((f) => f.message.includes('runtime behavior'))
        .every((f) => f.severity === 'warning'),
    );
  });

  it('a sign-out inside onRefreshFailed is flagged as transient handling', () => {
    const nk007 = only(run(F.LEGACY_V5), 'NK007');
    assert.equal(nk007.length, 1);
    assert.equal(nk007[0]?.confidence, 'high');
  });
});

describe('privacy of analyzer output', () => {
  it('redacts secrets in code excerpts', () => {
    const redacted = redactCode(
      "headers: {'X-Api-Key': 'abcd1234secretvalue', 'Authorization': 'Bearer abcdefghijklmnop'} " +
        "uri: 'https://storage.example.com/o?X-Goog-Signature=abc&X-Goog-Date=1' " +
        'token: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTYifQ.c2lnbmF0dXJlLXZhbHVl',
    );
    assert.ok(!redacted.includes('abcd1234secretvalue'));
    assert.ok(!redacted.includes('abcdefghijklmnop'));
    assert.ok(!redacted.includes('Signature=abc'));
    assert.ok(redacted.includes('X-Goog-Date=1'));
    assert.ok(!redacted.includes('eyJzdWIiOiIxMjM0NTYifQ'));
  });

  it('reports configuration arguments that may hold secrets only as "(set)"', () => {
    const configs = managerConfigurations([parseDartFile('lib/config.dart', F.LOGGING_BAD)]);
    assert.equal(configs[0]!.arguments.headers, '(set)');
    assert.equal(configs[0]!.arguments.baseUrl, "'https://api.example.com'");
  });
});

describe('workspace analysis end to end', () => {
  it('analyzes lib/ of an authorized root with relative paths and project facts', () => {
    const tree = tempTree({
      'pubspec.yaml': F.PUBSPEC_V6,
      'pubspec.lock': F.LOCK_V6,
      'lib/auth.dart': F.BAD_AUTH,
      'lib/upload.dart': F.SIGNED_UPLOAD_BAD,
      'lib/plain.dart': 'class Plain {}\n',
      'test/ignored_by_default.dart': F.LEGACY_V5,
    });
    try {
      const [root] = authorizeRoots([{ path: tree.dir, name: 'example_app' }]);
      const session = new WorkspaceSession(root!, DEFAULT_LIMITS);
      const result = analyzeWorkspace(session);
      assert.equal(result.facts.netKitConstraint, '^6.0.0-dev.1');
      assert.equal(result.facts.resolvedNetKitVersion, '6.0.0-dev.1');
      assert.equal(result.facts.targetMajor, 6);
      assert.deepEqual(result.facts.apiHosts, ['api.example.com']);
      assert.deepEqual(result.scopes, ['lib']);
      assert.equal(result.stats.filesDiscovered, 3);
      assert.equal(result.stats.filesAnalyzed, 2);
      assert.ok(result.findings.every((f) => f.file.startsWith('lib/')));
      assert.ok(!JSON.stringify(result.findings).includes(tree.dir));
      assert.ok(
        !result.findings.some((f) => f.ruleId === 'NK005'),
        'test/ is not scanned by default',
      );

      const scoped = analyzeWorkspace(new WorkspaceSession(root!, DEFAULT_LIMITS), {
        paths: ['test'],
      });
      assert.ok(scoped.findings.some((f) => f.ruleId === 'NK005'));

      const limited = analyzeWorkspace(
        new WorkspaceSession(root!, { ...DEFAULT_LIMITS, maxDiagnostics: 2 }),
      );
      assert.equal(limited.findings.length, 2);
      assert.equal(limited.stats.diagnosticsTruncated, true);
    } finally {
      tree.cleanup();
    }
  });
});
