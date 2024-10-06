import 'package:logger/logger.dart';

/// Enum for the different log levels.
enum LogLevel {
  /// All log levels.
  all,

  /// Trace log level.
  trace,

  /// Debug log level.
  debug,

  /// Info log level.
  info,

  /// Warning log level.
  warning,

  /// Error log level.
  error,

  /// Fatal log level.
  fatal,

  /// Off log level.
  off,
}

/// Extension on the [LogLevel] enum to perform some operations.
extension LogLevelExtension on LogLevel {
  /// Converts the [LogLevel] enum to a [Level] enum.
  Level toLevel() {
    switch (this) {
      case LogLevel.all:
        return Level.all;
      case LogLevel.trace:
        return Level.trace;
      case LogLevel.debug:
        return Level.debug;
      case LogLevel.info:
        return Level.info;
      case LogLevel.warning:
        return Level.warning;
      case LogLevel.error:
        return Level.error;
      case LogLevel.fatal:
        return Level.fatal;
      case LogLevel.off:
        return Level.off;
    }
  }
}
