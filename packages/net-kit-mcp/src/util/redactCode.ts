/**
 * Masks likely secrets in code excerpts before they leave the server.
 *
 * Findings quote small pieces of the inspected source. Those pieces may
 * contain hard-coded credentials; this keeps the structure of the code but
 * replaces the secret values.
 */

const SENSITIVE_KEY =
  /(['"])(authorization|proxy-authorization|cookie|x-api-key|api-key|apikey|x-auth-token|x-refresh-token|client_secret|password|secret|token|access_token|refresh_token)\1(\s*:\s*)(['"])([^'"]*)\4/gi;
const JWT = /\b[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g;
const BEARER = /(Bearer\s+)(?!\$)[A-Za-z0-9._~+/=-]{8,}/g;
const KNOWN_KEYS =
  /\b(AKIA[0-9A-Z]{16}|sk_(live|test)_[A-Za-z0-9]{8,}|ghp_[A-Za-z0-9]{20,}|xox[abpr]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,})\b/g;
const SIGNED_PARAM =
  /([?&](?:x-amz-signature|x-amz-credential|x-amz-security-token|x-goog-signature|x-goog-credential|signature|sig|token|access_token|refresh_token|id_token|api_key|apikey|key|code|secret|client_secret|password)=)([^&'"\s#]+)/gi;

export const REDACTED = '[REDACTED]';

export function redactCode(text: string): string {
  return text
    .replace(
      SENSITIVE_KEY,
      (_m, q: string, key: string, sep: string, vq: string) =>
        `${q}${key}${q}${sep}${vq}${REDACTED}${vq}`,
    )
    .replace(SIGNED_PARAM, (_m, prefix: string) => `${prefix}${REDACTED}`)
    .replace(BEARER, (_m, prefix: string) => `${prefix}${REDACTED}`)
    .replace(JWT, REDACTED)
    .replace(KNOWN_KEYS, REDACTED);
}
