import { API, DOC } from '../../knowledge/refs.js';
import { enclosingBlocks, identifiers, namedArg, stringValues, type DartFile } from '../model.js';
import type { Finding, Rule } from '../types.js';
import {
  callRange,
  callText,
  finding,
  hostOf,
  importsDio,
  importsNetKitDio,
  managerCalls,
  urlEvidence,
  usesNetKit,
} from './helpers.js';

/** NK001: a signed / object-storage URL sent through the authenticated manager. */
export const nk001: Rule = {
  id: 'NK001',
  title: 'External signed URL sent through NetKitManager',
  categories: ['upload', 'auth', 'transport'],
  description:
    'Signed object-storage URLs belong on the raw transport (RawHttpClient), which has no application credentials, no refresh, and no API envelope.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of managerCalls(file)) {
        const path = namedArg(call, 'path');
        if (path === undefined) continue;
        const evidence = urlEvidence(path.tokens);
        if (evidence.kind === 'none' || evidence.kind === 'external-literal') continue;
        const confidence = evidence.kind === 'signed-identifier' ? 'medium' : 'high';
        out.push(
          finding(file, {
            ruleId: 'NK001',
            title: this.title,
            severity: 'warning',
            confidence,
            range: callRange(call),
            message:
              `This appears to send an external signed/storage URL through NetKitManager.${call.name} (${evidence.detail}). ` +
              'In net_kit 6 such a request is blocked before sending unless allowCrossOriginRequests is enabled; even then the manager adds JSON/API semantics that a storage upload does not want.',
            recommendation:
              'Send it with the transport (manager.transport or a RawHttpClient): RawHttpRequest with exactly the signed headers and a FileRawHttpBody / ReplayableRawHttpBody body. Use NetKitManager only for the API call that obtains the signed URL.',
            resources: [DOC.rawTransport, DOC.rawSecurity, API.rawHttpRequest, API.fileBody],
            suggestion: {
              currentPattern: callText(file, call),
              suggestedPattern: [
                'final RawHttpClient storage = netKitManager.transport;',
                'final response = await storage.send(',
                '  RawHttpRequest(',
                `    uri: Uri.parse(${path.text}),`,
                '    method: RawHttpMethod.put,',
                '    headers: signedHeaders, // only the headers the signature covers',
                '    body: FileRawHttpBody(filePath),',
                '    cancellationToken: cancellationToken,',
                '  ),',
                ');',
                'if (!response.isSuccessful) { /* handle storage status */ }',
              ].join('\n'),
              explanation:
                'The raw transport sends exactly the given headers, never the access token, never refreshes, and returns every status for you to interpret.',
            },
          }),
        );
      }
    }
    return out;
  },
};

/** NK003: authenticated manager call to an absolute URL on another origin. */
export const nk003: Rule = {
  id: 'NK003',
  title: 'Authenticated request to an external origin',
  categories: ['auth', 'transport'],
  description:
    'AuthPolicy.inherit/required requests to an absolute URL on a different host than the configured baseUrl.',
  run({ files, facts }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of managerCalls(file)) {
        const path = namedArg(call, 'path');
        if (path === undefined) continue;
        const evidence = urlEvidence(path.tokens);
        if (evidence.kind !== 'external-literal') continue;
        const host = evidence.host;
        if (host === null || facts.apiHosts.includes(host)) continue;
        const policy = namedArg(call, 'authPolicy')?.text ?? 'AuthPolicy.inherit';
        if (policy.endsWith('.none')) continue;
        const required = policy.endsWith('.required');
        out.push(
          finding(file, {
            ruleId: 'NK003',
            title: this.title,
            severity: required ? 'error' : 'warning',
            confidence: facts.apiHosts.length > 0 ? 'high' : 'medium',
            range: callRange(call),
            message: required
              ? `AuthPolicy.required cannot target another origin (${host}); net_kit 6 rejects this request before sending.`
              : `This request targets ${host}, which is not the configured API origin${
                  facts.apiHosts.length > 0 ? ` (${facts.apiHosts.join(', ')})` : ''
                }. net_kit 6 blocks it by default; with allowCrossOriginRequests it is sent without stored credentials.`,
            recommendation:
              'Call external services through the transport (RawHttpClient) or a separate NetKitManager whose baseUrl is that service. Keep the application manager on its own origin.',
            resources: [DOC.originPolicy, DOC.rawTransport, API.authPolicy],
          }),
        );
      }
    }
    return out;
  },
};

/** NK009: Authorization or stored headers attached to a raw request. */
export const nk009: Rule = {
  id: 'NK009',
  title: 'Raw request carries application credentials',
  categories: ['upload', 'auth', 'transport'],
  description:
    "RawHttpRequest headers that include Authorization or the manager's stored headers send the application token to whatever host the raw URL points at.",
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      for (const call of file.calls) {
        if (call.name !== 'RawHttpRequest' || call.isMember) continue;
        const headers = namedArg(call, 'headers');
        if (headers === undefined) continue;
        const keys = stringValues(headers.tokens).map((v) => v.toLowerCase());
        const names = identifiers(headers.tokens);
        const copiesStored =
          names.includes('getAllHeaders') ||
          (names.includes('headers') && names.includes('parameters'));
        const hasAuth = keys.includes('authorization') || keys.includes('proxy-authorization');
        const tokenish = names.some((n) =>
          /^(access_?token|bearer|auth_?header|jwt|id_?token)$/i.test(n),
        );
        if (!copiesStored && !hasAuth && !tokenish) continue;
        const destination = urlEvidence(namedArg(call, 'uri')?.tokens ?? []);
        const external = destination.kind !== 'none';
        out.push(
          finding(file, {
            ruleId: 'NK009',
            title: this.title,
            severity: 'warning',
            confidence: copiesStored || (hasAuth && external) ? 'high' : 'medium',
            range: callRange(call),
            message: copiesStored
              ? "This raw request copies the manager's stored headers, which include the access token, onto an arbitrary URL."
              : 'This raw request appears to send an Authorization header or access token' +
                (external ? ` to ${destination.host ?? 'an external/signed URL'}.` : '.'),
            recommendation:
              'Send only the headers the destination requires (for signed URLs: exactly the signed headers). Use NetKitManager for authenticated API calls; it attaches the token only on its own origin.',
            resources: [DOC.rawSecurity, API.rawHttpRequest],
          }),
        );
      }
    }
    return out;
  },
};

const DIO_CALL_NAMES = new Set([
  'get',
  'post',
  'put',
  'patch',
  'delete',
  'request',
  'fetch',
  'download',
  'head',
]);

/** NK006: a direct Dio client next to net_kit. */
export const nk006: Rule = {
  id: 'NK006',
  title: 'Direct Dio usage alongside net_kit',
  categories: ['transport', 'auth', 'migration'],
  description:
    'A Dio client created and used directly in code that also uses net_kit bypasses AuthPolicy, single-flight refresh, origin enforcement, and log redaction. Direct Dio is legitimate for unrelated integrations; this is a review hint.',
  run({ files }) {
    const out: Finding[] = [];
    for (const file of files) {
      if (!usesNetKit(file)) continue;
      const direct = importsDio(file) || importsNetKitDio(file);
      if (!direct) continue;
      for (const call of file.calls) {
        const isConstruction = call.name === 'Dio' && !call.isMember;
        const isDioRequest =
          call.isMember &&
          DIO_CALL_NAMES.has(call.name) &&
          call.qualifier !== null &&
          /^_?dio$|Dio$|^_?client$/.test(call.qualifier) &&
          /\bDio\(/.test(file.text);
        if (!isConstruction && !isDioRequest) continue;
        const inAuthContext = enclosingBlocks(file, call.index).some((b) =>
          identifiers(b.header).some((n) => /token|auth|refresh/i.test(n)),
        );
        out.push(
          finding(file, {
            ruleId: 'NK006',
            title: this.title,
            severity: 'info',
            confidence: inAuthContext ? 'medium' : 'low',
            range: callRange(call),
            message: isConstruction
              ? "A separate Dio client is created in a file that also uses net_kit. Requests sent through it do not get net_kit's auth policy, refresh, origin, or logging protections."
              : `Requests sent with ${call.qualifier ?? 'a Dio client'}.${call.name}() bypass net_kit's auth, refresh, and origin protections.`,
            recommendation:
              'Review recommended: use NetKitManager for application API calls and its transport (RawHttpClient) for external URLs. Keep direct Dio only for integrations that intentionally live outside net_kit.',
            resources: [DOC.architecture, API.transport],
          }),
        );
      }
    }
    return out;
  },
};

/** Hosts of literal base URLs passed to NetKitManager in [files]. */
export function literalApiHosts(files: readonly DartFile[]): string[] {
  const hosts = new Set<string>();
  for (const file of files) {
    for (const call of file.calls) {
      if (call.name !== 'NetKitManager' || call.isMember) continue;
      for (const name of ['baseUrl', 'devBaseUrl']) {
        for (const value of stringValues(namedArg(call, name)?.tokens ?? [])) {
          const host = hostOf(value);
          if (host !== null) hosts.add(host);
        }
      }
    }
  }
  return [...hosts].sort();
}
