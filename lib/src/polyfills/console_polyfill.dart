// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import '../runtime.dart';

/// A log entry captured from JavaScript console.
class JsConsoleLog {
  /// The log level (log, error, warn, info, debug).
  final String level;

  /// The formatted log message.
  final String message;

  /// The timestamp when the log was created.
  final DateTime timestamp;

  const JsConsoleLog({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  @override
  String toString() => '[$level] $message';
}

/// A callback function for console log events.
typedef ConsoleLogCallback = void Function(JsConsoleLog log);

/// A polyfill for JavaScript console APIs.
///
/// This provides `console.log()`, `console.error()`, etc. in the JavaScript context
/// and allows capturing logs in Dart.
///
/// Example usage:
/// ```dart
/// final runtime = JsRuntime(
///   config: JsRuntimeConfig(enableConsole: true),
/// );
///
/// runtime.eval('''
///   console.log('Hello from JavaScript!');
///   console.error('An error occurred');
/// ''');
///
/// // Get captured logs
/// for (final log in runtime.consoleLogs) {
///   print('[${log.level}] ${log.message}');
/// }
/// ```
class ConsolePolyfill {
  final JsRuntime _runtime;

  /// Console logs captured from JavaScript.
  final List<JsConsoleLog> _logs = [];

  /// Callback for real-time log events.
  final ConsoleLogCallback? _onLog;

  /// Flag to prevent recursive calls during sync.
  bool _syncing = false;

  /// Creates a new ConsolePolyfill.
  ///
  /// [runtime] is the JavaScript runtime to install the polyfill into.
  /// [onLog] is an optional callback that will be invoked for each log event.
  ConsolePolyfill(this._runtime, {ConsoleLogCallback? onLog}) : _onLog = onLog;

  /// Returns captured console logs.
  ///
  /// This automatically syncs logs from JavaScript before returning.
  List<JsConsoleLog> get logs {
    syncLogs();
    return List.unmodifiable(_logs);
  }

  /// Clears all captured console logs.
  void clearLogs() {
    _logs.clear();
    // Also clear logs in JavaScript
    if (!_runtime.isDisposed) {
      _runtime.eval('console.clear();');
    }
  }

  /// Installs the console polyfill into the JavaScript context.
  void install() {
    _runtime.eval('''
      globalThis.console = {
        _logs: [],
        _format: function(...args) {
          return args.map(arg => {
            if (arg === null) return 'null';
            if (arg === undefined) return 'undefined';
            if (typeof arg === 'object') {
              try {
                return JSON.stringify(arg);
              } catch (e) {
                return String(arg);
              }
            }
            return String(arg);
          }).join(' ');
        },
        log: function(...args) {
          const msg = this._format(...args);
          this._logs.push({ level: 'log', message: msg, timestamp: Date.now() });
        },
        error: function(...args) {
          const msg = this._format(...args);
          this._logs.push({ level: 'error', message: msg, timestamp: Date.now() });
        },
        warn: function(...args) {
          const msg = this._format(...args);
          this._logs.push({ level: 'warn', message: msg, timestamp: Date.now() });
        },
        info: function(...args) {
          const msg = this._format(...args);
          this._logs.push({ level: 'info', message: msg, timestamp: Date.now() });
        },
        debug: function(...args) {
          const msg = this._format(...args);
          this._logs.push({ level: 'debug', message: msg, timestamp: Date.now() });
        },
        clear: function() {
          this._logs = [];
        },
        _getLogs: function() {
          return this._logs;
        }
      };
    ''');
  }

  /// Synchronizes console logs from JavaScript to Dart.
  void syncLogs() {
    // Prevent recursive calls
    if (_syncing) return;
    _syncing = true;

    try {
      final logsJson = _runtime.eval('JSON.stringify(console._getLogs())');
      if (logsJson is String) {
        try {
          final logs = jsonDecode(logsJson) as List;
          final previousLogCount = _logs.length;

          // Only process new logs (logs after previousLogCount)
          for (int i = previousLogCount; i < logs.length; i++) {
            final log = logs[i];
            if (log is Map) {
              final consoleLog = JsConsoleLog(
                level: log['level']?.toString() ?? 'log',
                message: log['message']?.toString() ?? '',
                timestamp: log['timestamp'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                        log['timestamp'] as int,
                      )
                    : DateTime.now(),
              );
              _logs.add(consoleLog);

              // Emit new log to callback immediately
              if (_onLog != null) {
                _onLog(consoleLog);
              }
            }
          }
        } catch (_) {
          // Ignore JSON parsing errors
        }
      }
    } finally {
      _syncing = false;
    }
  }
}
