import '../core/net_kit_cancellation_token.dart';

export '../core/net_kit_cancellation_token.dart';

/// Alias kept for raw-transport code written against 5.5.
///
/// `NetKitManager` and the raw transport share one token type so a single
/// token can cancel an API request and a storage upload together.
typedef RawHttpCancellationToken = NetKitCancellationToken;
