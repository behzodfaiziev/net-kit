import 'package:logger/logger.dart';

enum LogLevel { all, trace, debug, info, warning, error, fatal, off }

extension LogLevelExtension on LogLevel {
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
