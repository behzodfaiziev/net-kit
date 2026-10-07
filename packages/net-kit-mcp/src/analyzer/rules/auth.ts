import { joinTokens } from '../../dart/lexer.js';
import { API, DOC } from '../../knowledge/refs.js';
import { enclosingBlocks, namedArg, stringValues, type CallSite, type DartFile } from '../model.js';
import type { Confidence, Finding, Rule } from '../types.js';
import {
  callRange,
  callText,
  finding,
  hostOf,
  managerCalls,
  managerConstructions,
} from './helpers.js';

const PROTECTED_PATH =
  /\/(me|account|accounts\/me|profile|settings|orders|wallet|payments?|billing|cart|inbox|messages|notifications|users\/me|user\/me)(\/|\?|$)/i;
const PUBLIC_PATH =
  /(login|log-in|signin|sign-in|register|signup|sign-up|refresh|token|forgot|reset|verify|otp|public|health|status|config|version|terms|privacy|ping)/i;

/** NK002: AuthPolicy.none on an endpoint that looks user-specific. */
export const nk002: Rule = {
  id: 'NK002',
  title: 'AuthPolicy.none on an endpoint that appears to need authentication',
  categories: ['auth'],
  description:
    'AuthPolicy.none never sends the access token and never refreshes. On user-specific endpoints this usually means the request is sent anonymously by mistake.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of managerCalls(file)) {
        if (!(namedArg(call, 'authPolicy')?.text.endsWith('AuthPolicy.none') ?? false)) continue;
        const path = stringValues(namedArg(call, 'path')?.tokens ?? [])[0];
        if (path === undefined || !PROTECTED_PATH.test(path) || PUBLIC_PATH.test(path)) continue;
        out.push(
          finding(file, {
            ruleId: 'NK002',
            title: this.title,
            severity: 'info',
            confidence: /\/me(\/|\?|$)/.test(path) ? 'medium' : 'low',
            range: callRange(call),
            message: `"${path}" looks like a user-specific endpoint, but the request uses AuthPolicy.none, so no access token is sent and a 401 is never refreshed.`,
            recommendation:
              'Review recommended: use the default AuthPolicy.inherit, or AuthPolicy.required to fail fast when no token is stored. Keep AuthPolicy.none for login, registration, and other public endpoints.',
            resources: [DOC.authPolicy, API.authPolicy],
          }),
        );
      }
    }
    return out;
  },
};

const SIGN_OUT =
  /^(log_?out|sign_?out|force_?log_?out|end_?session|clear_?session|clear_?auth|clear_?tokens?|delete_?tokens?|reset_?session|invalidate_?session|delete_?all|remove_?access_?token|remove_?refresh_?token|clear_?all_?headers|go_?to_?(login|sign_?in))$/i;

interface SignOutContext {
  readonly verdict:
    | 'session-signal'
    | 'transient'
    | 'any-401'
    | 'auth-type'
    | 'catch-all'
    | 'interceptor-error'
    | 'neutral';
  readonly evidence: string;
}

/** Labels of the named arguments that contain token [index], innermost first. */
function enclosingArgumentLabels(file: DartFile, index: number): string[] {
  const labels: { label: string; span: number }[] = [];
  const target = file.tokens[index];
  if (target === undefined) return [];
  for (const outer of file.calls) {
    if (outer.openParen >= index || outer.closeParen <= index) continue;
    for (const arg of outer.args) {
      const first = arg.tokens[0];
      const last = arg.tokens[arg.tokens.length - 1];
      if (
        arg.name !== null &&
        first !== undefined &&
        last !== undefined &&
        first.start <= target.start &&
        target.end <= last.end
      ) {
        labels.push({ label: arg.name, span: last.end - first.start });
      }
    }
  }
  return labels.sort((a, b) => a.span - b.span).map((l) => l.label);
}

function classifySignOut(file: DartFile, call: CallSite): SignOutContext {
  const labels = enclosingArgumentLabels(file, call.index);
  if (labels.includes('onSessionInvalidated')) {
    return { verdict: 'session-signal', evidence: 'inside onSessionInvalidated' };
  }
  const nearest = labels[0];
  if (nearest === 'onRefreshFailed') {
    return {
      verdict: 'transient',
      evidence: 'onRefreshFailed callback (5.x: called for every refresh failure)',
    };
  }
  if (nearest === 'onError') {
    return { verdict: 'interceptor-error', evidence: 'onError callback' };
  }
  const blocks = enclosingBlocks(file, call.index);
  // Text of the statement the call is in (handles `if (...) logout();`).
  const statementStart = (() => {
    let i = call.index;
    while (i > 0) {
      const t = file.tokens[i - 1]?.text;
      if (t === ';' || t === '{' || t === '}') break;
      i--;
    }
    return i;
  })();
  const statement = joinTokens(file.tokens.slice(statementStart, call.index));
  const contexts = [statement, ...blocks.map((b) => joinTokens(b.header))];
  const all = contexts.join(' • ');

  if (/sessionInvalidated|onSessionInvalidated/.test(all)) {
    return {
      verdict: 'session-signal',
      evidence: 'inside onSessionInvalidated or a sessionInvalidated check',
    };
  }
  // Only the nearest conditional/handler context decides the verdict.
  for (const context of contexts) {
    if (
      /fromRefresh|ApiFailureType\.(transport|timeout|cancelled|response|decoding|unknown)|SocketException|TimeoutException|HandshakeException|DioExceptionType/.test(
        context,
      )
    ) {
      return { verdict: 'transient', evidence: context };
    }
    if (/statusCode\s*==\s*401|401\s*==\s*statusCode|\bunauthorized\b/i.test(context)) {
      return { verdict: 'any-401', evidence: context };
    }
    if (/ApiFailureType\.auth\b/.test(context)) {
      return { verdict: 'auth-type', evidence: context };
    }
    if (/\bonError\b|\bcatchError\b/.test(context)) {
      return { verdict: 'interceptor-error', evidence: context };
    }
    if (/\bcatch\s*\(/.test(context)) {
      return { verdict: 'catch-all', evidence: context };
    }
    if (/^\s*(if|else|switch|case)\b/.test(context) || /\bif \(/.test(context)) {
      // Another condition decides; nothing net_kit-specific to say.
      return { verdict: 'neutral', evidence: context };
    }
  }
  return { verdict: 'neutral', evidence: '' };
}

/** NK007: sign-out triggered by something other than the session-invalidated signal. */
export const nk007: Rule = {
  id: 'NK007',
  title: 'Sign-out tied to a generic failure instead of session invalidation',
  categories: ['refresh', 'auth'],
  description:
    'In net_kit 6 only a refresh-endpoint 401 ends a session (ApiFailureType.sessionInvalidated / onSessionInvalidated). Signing out on generic errors, transient refresh failures, or any 401 can log users out when they are merely offline.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of file.calls) {
        if (!SIGN_OUT.test(call.name)) continue;
        const context = classifySignOut(file, call);
        let confidence: Confidence;
        let message: string;
        switch (context.verdict) {
          case 'transient':
            confidence = 'high';
            message =
              'This appears to sign the user out on a transient or non-session failure (offline, timeout, server error, or a refresh failure that is not a refresh 401). net_kit keeps the session in these cases.';
            break;
          case 'any-401':
            confidence = 'medium';
            message =
              'This appears to sign the user out on any 401. A 401 from an ordinary request only means the access token may be stale; net_kit refreshes once by itself. Only a refresh-endpoint 401 ends the session.';
            break;
          case 'auth-type':
            confidence = 'medium';
            message =
              'This signs out on ApiFailureType.auth, which covers local conditions (missing token for AuthPolicy.required, a non-idempotent request not retried). It does not mean the session ended.';
            break;
          case 'interceptor-error':
            confidence = 'medium';
            message =
              'This signs the user out from a generic error handler. Every failure passes through it, including offline and timeout errors.';
            break;
          case 'catch-all':
            confidence = 'medium';
            message =
              'This signs the user out inside a catch block that does not check for session invalidation, so any failure (including being offline) logs the user out.';
            break;
          case 'session-signal':
          case 'neutral':
            continue;
        }
        out.push(
          finding(file, {
            ruleId: 'NK007',
            title: this.title,
            severity: 'warning',
            confidence,
            range: callRange(call),
            message,
            recommendation:
              'Move sign-out to NetKitManager(onSessionInvalidated: ...), or guard it with `error.type == ApiFailureType.sessionInvalidated`. Treat other failures (fromRefresh, transport, timeout, response) as retryable.',
            resources: [DOC.sessionRules, DOC.migrationSession, API.failureType],
            suggestion: {
              currentPattern: context.evidence === '' ? callText(file, call) : context.evidence,
              suggestedPattern: [
                'NetKitManager(',
                '  // ...',
                '  onSessionInvalidated: (exception) => authController.signOut(),',
                ');',
                '',
                '// In request error handling:',
                'on ApiException catch (error) {',
                '  if (error.type == ApiFailureType.sessionInvalidated) return; // already signed out',
                '  showRetryableError(error); // offline, timeout, 5xx, ... keep the session',
                '}',
              ].join('\n'),
              explanation: 'Only the refresh endpoint answering 401 means the session is over.',
            },
          }),
        );
      }
    }
    return out;
  },
};

/** NK014: refresh configured without a session-invalidation handler. */
export const nk014: Rule = {
  id: 'NK014',
  title: 'Refresh configured without onSessionInvalidated',
  categories: ['refresh', 'configuration'],
  description:
    'When the refresh endpoint answers 401, net_kit clears the stored tokens. Without onSessionInvalidated the application is not told, so its UI may stay signed in.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of managerConstructions(file)) {
        if (namedArg(call, 'refreshTokenPath') === undefined) continue;
        if (namedArg(call, 'onSessionInvalidated') !== undefined) continue;
        if (namedArg(call, 'onRefreshFailed') !== undefined) continue; // reported by NK005
        out.push(
          finding(file, {
            ruleId: 'NK014',
            title: this.title,
            severity: 'info',
            confidence: 'high',
            range: callRange(call),
            message:
              'This manager refreshes tokens but has no onSessionInvalidated handler, so the app is not notified when the refresh endpoint rejects the session.',
            recommendation:
              'Pass onSessionInvalidated and sign the user out there (and only there).',
            resources: [DOC.sessionInvalidation, DOC.sessionRules],
          }),
        );
      }
    }
    return out;
  },
};

/** NK011: cross-origin manager requests enabled. */
export const nk011: Rule = {
  id: 'NK011',
  title: 'Cross-origin requests enabled on NetKitManager',
  categories: ['configuration', 'auth', 'transport'],
  description:
    'allowCrossOriginRequests: true lets the API client call other origins. Credentials are not sent there, but external URLs are clearer and safer on the transport.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of managerConstructions(file)) {
        const arg = namedArg(call, 'allowCrossOriginRequests');
        if (arg?.text !== 'true') continue;
        out.push(
          finding(file, {
            ruleId: 'NK011',
            title: this.title,
            severity: 'warning',
            confidence: 'high',
            range: callRange(call),
            message:
              'allowCrossOriginRequests is enabled. net_kit still strips stored headers and the access token from cross-origin requests and redirects, but the API client now accepts arbitrary absolute URLs.',
            recommendation:
              'Keep the default (false) and send external requests (signed URLs, third-party APIs) through the transport / RawHttpClient.',
            resources: [DOC.originPolicy, DOC.rawTransport],
          }),
        );
      }
    }
    return out;
  },
};

/** NK015: plain-HTTP API base URL. */
export const nk015: Rule = {
  id: 'NK015',
  title: 'API base URL uses plain HTTP',
  categories: ['configuration', 'auth'],
  description: 'Access and refresh tokens sent over http:// are readable on the network.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of managerConstructions(file)) {
        const value = stringValues(namedArg(call, 'baseUrl')?.tokens ?? [])[0];
        if (value === undefined || !/^http:\/\//i.test(value)) continue;
        const host = hostOf(value) ?? '';
        if (
          /^(localhost|127\.0\.0\.1|10\.0\.2\.2|\[::1\])$/.test(host) ||
          host.endsWith('.test') ||
          host.endsWith('.localhost')
        ) {
          continue;
        }
        out.push(
          finding(file, {
            ruleId: 'NK015',
            title: this.title,
            severity: 'warning',
            confidence: 'high',
            range: callRange(call),
            message: `baseUrl "${value}" uses plain HTTP, so tokens are sent unencrypted.`,
            recommendation: 'Use an https:// base URL outside local development.',
            resources: [DOC.authPolicy],
          }),
        );
      }
    }
    return out;
  },
};

/** NK016: development mode hard-coded on. */
export const nk016: Rule = {
  id: 'NK016',
  title: 'devMode hard-coded to true',
  categories: ['configuration'],
  description:
    'devMode switches to devBaseUrl and enables logging options. Hard-coding it to true ships development behavior in release builds.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of managerConstructions(file)) {
        if (namedArg(call, 'devMode')?.text !== 'true') continue;
        out.push(
          finding(file, {
            ruleId: 'NK016',
            title: this.title,
            severity: 'warning',
            confidence: 'medium',
            range: callRange(call),
            message:
              'devMode is the literal true, so development base URL and logging settings apply in every build.',
            recommendation: 'Derive it from the build mode, for example `devMode: kDebugMode`.',
            resources: [DOC.logging],
          }),
        );
      }
    }
    return out;
  },
};
