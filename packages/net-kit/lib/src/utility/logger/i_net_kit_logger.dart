import '../../enum/log_level.dart';

/// Logger for network operations
abstract class INetKitLogger {
  /// Sets the log level
  void setLogLevel(LogLevel level);

  /// Logs the trace event
  void trace(String message);

  /// Logs the debug event
  void debug(String message);

  /// Logs the warning event
  void warning(String message);

  /// Logs the info event
  void info(String message);

  /// Logs the error event
  void error(String? message);

  /// Logs fatal error event
  void fatal(String? message);
}
