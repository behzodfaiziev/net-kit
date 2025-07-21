import 'package:net_kit/net_kit.dart';

/// Logger for network operations
class RefreshLogger implements INetKitLogger {
  /// Logs the trace event
  @override
  void trace(String message) {
    // print('TRACE: $message');
  }

  /// Logs the debug event
  @override
  void debug(String message) {
    // print('DEBUG: $message');
  }

  /// Logs the warning event
  @override
  void warning(String message) {
    // print('WARNING: $message');
  }

  /// Logs the info event
  @override
  void info(String message) {
    // print('INFO: $message');
  }

  /// Logs the error event
  @override
  void error(String? message) {
    // print('ERROR: $message');
  }

  /// Logs fatal error event
  @override
  void fatal(String? message) {
    // print('FATAL: $message');
  }
}
