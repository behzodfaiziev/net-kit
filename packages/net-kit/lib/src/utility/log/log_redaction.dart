/// Placeholder written instead of a redacted value.
const String logRedactedValue = '[REDACTED]';

/// Query parameter names whose values are redacted from logged URLs.
///
/// Matching is case-insensitive and on the decoded parameter name.
const Set<String> defaultSensitiveQueryParameters = {
  'token',
  'access_token',
  'refresh_token',
  'id_token',
  'api_key',
  'apikey',
  'key',
  'signature',
  'sig',
  'x-goog-signature',
  'x-goog-credential',
  'x-amz-signature',
  'x-amz-credential',
  'x-amz-security-token',
  'code',
  'secret',
  'client_secret',
  'password',
};

/// Returns [uri] as text for logs.
///
/// Values of query (and fragment) parameters named in [sensitiveNames]
/// (lower-case) are replaced with [logRedactedValue], as is any user-info
/// component. Every other part of the URL is kept byte for byte, so the log
/// still shows the host, path, and non-secret parameters.
String redactUriForLog(Uri uri, Set<String> sensitiveNames) {
  var text = uri.toString();
  final userInfo = uri.userInfo;
  if (userInfo.isNotEmpty) {
    text = text.replaceFirst('$userInfo@', '$logRedactedValue@');
  }

  final fragmentStart = text.indexOf('#');
  final beforeFragment =
      fragmentStart < 0 ? text : text.substring(0, fragmentStart);
  final fragment = fragmentStart < 0 ? null : text.substring(fragmentStart + 1);

  final queryStart = beforeFragment.indexOf('?');
  var redacted = beforeFragment;
  if (queryStart >= 0) {
    final query = beforeFragment.substring(queryStart + 1);
    redacted = '${beforeFragment.substring(0, queryStart + 1)}'
        '${_redactPairs(query, sensitiveNames)}';
  }
  return fragment == null
      ? redacted
      : '$redacted#${_redactPairs(fragment, sensitiveNames)}';
}

/// [redactUriForLog] for a request path that may be relative or absolute.
String redactPathForLog(String path, Set<String> sensitiveNames) {
  final uri = Uri.tryParse(path);
  if (uri != null) {
    return redactUriForLog(uri, sensitiveNames);
  }
  final queryStart = path.indexOf('?');
  return queryStart < 0
      ? path
      : '${path.substring(0, queryStart)}?$logRedactedValue';
}

String _redactPairs(String pairs, Set<String> sensitiveNames) {
  return pairs.split('&').map((pair) {
    final equals = pair.indexOf('=');
    final rawName = equals < 0 ? pair : pair.substring(0, equals);
    String name;
    try {
      name = Uri.decodeQueryComponent(rawName);
    } on Object {
      name = rawName;
    }
    if (!sensitiveNames.contains(name.toLowerCase())) {
      return pair;
    }
    return '$rawName=$logRedactedValue';
  }).join('&');
}
