import 'dart:developer';

/// Logger for network operations
abstract class INetKitLogger {
  /// Logs the message
  void logEvent(String message);
}

/// Implementation of the [INetKitLogger] interface
class NetKitLogger implements INetKitLogger {
  @override
  void logEvent(String message) {
    log(message);
  }
}
