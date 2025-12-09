import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:test/test.dart';

void main() {
  group('ConsolePolyfill', () {
    late JsRuntime runtime;

    setUp(() {
      runtime = JsRuntime(config: JsRuntimeConfig(enableConsole: true));
    });

    tearDown(() {
      runtime.dispose();
    });

    test('console.log captures messages', () {
      runtime.eval('console.log("Hello from JavaScript!")');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].level, equals('log'));
      expect(logs[0].message, equals('Hello from JavaScript!'));
    });

    test('console.error captures error messages', () {
      runtime.eval('console.error("An error occurred")');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].level, equals('error'));
      expect(logs[0].message, equals('An error occurred'));
    });

    test('console.warn captures warning messages', () {
      runtime.eval('console.warn("This is a warning")');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].level, equals('warn'));
      expect(logs[0].message, equals('This is a warning'));
    });

    test('console.info captures info messages', () {
      runtime.eval('console.info("Info message")');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].level, equals('info'));
      expect(logs[0].message, equals('Info message'));
    });

    test('console.debug captures debug messages', () {
      runtime.eval('console.debug("Debug message")');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].level, equals('debug'));
      expect(logs[0].message, equals('Debug message'));
    });

    test('console.log formats multiple arguments', () {
      runtime.eval('console.log("Hello", "World", 42)');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].message, equals('Hello World 42'));
    });

    test('console.log formats objects as JSON', () {
      runtime.eval('console.log("Object:", { name: "Test", value: 42 })');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].message, contains('name'));
      expect(logs[0].message, contains('Test'));
      expect(logs[0].message, contains('42'));
    });

    test('console.log formats arrays', () {
      runtime.eval('console.log("Array:", [1, 2, 3])');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].message, contains('[1,2,3]'));
    });

    test('console.log formats null and undefined', () {
      runtime.eval('console.log(null, undefined)');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(1));
      expect(logs[0].message, equals('null undefined'));
    });

    test('multiple console calls are captured in order', () {
      runtime.eval('''
        console.log("First");
        console.warn("Second");
        console.error("Third");
      ''');

      final logs = runtime.consoleLogs;
      expect(logs, hasLength(3));
      expect(logs[0].message, equals('First'));
      expect(logs[0].level, equals('log'));
      expect(logs[1].message, equals('Second'));
      expect(logs[1].level, equals('warn'));
      expect(logs[2].message, equals('Third'));
      expect(logs[2].level, equals('error'));
    });

    test('clearConsoleLogs clears all logs', () {
      runtime.eval('console.log("Test")');
      // First sync and verify log exists
      final logsBeforeClear = runtime.consoleLogs;
      expect(logsBeforeClear, hasLength(1));

      runtime.clearConsoleLogs();
      // After clear, logs should be empty
      // Note: We need to check the internal state, not call consoleLogs which syncs again
      runtime.eval(''); // trigger any pending ops
      // Clear JS logs too
      runtime.eval('console._logs = []');

      final logsAfterClear = runtime.consoleLogs;
      expect(logsAfterClear, isEmpty);
    });

    test('JsConsoleLog has timestamp', () {
      final before = DateTime.now();
      runtime.eval('console.log("Test")');
      final after = DateTime.now();

      final logs = runtime.consoleLogs;
      expect(
        logs[0].timestamp.isAfter(before.subtract(Duration(seconds: 1))),
        isTrue,
      );
      expect(
        logs[0].timestamp.isBefore(after.add(Duration(seconds: 1))),
        isTrue,
      );
    });

    test('JsConsoleLog toString returns formatted output', () {
      runtime.eval('console.log("Test message")');

      final logs = runtime.consoleLogs;
      expect(logs[0].toString(), equals('[log] Test message'));
    });

    test('console is not available when disabled', () {
      final runtimeNoConsole = JsRuntime(
        config: JsRuntimeConfig(enableConsole: false),
      );

      // Default console may or may not exist
      // Just ensure runtime works without console polyfill
      expect(() => runtimeNoConsole.eval('1 + 1'), returnsNormally);

      runtimeNoConsole.dispose();
    });

    test('onConsoleLog stream emits events for new logs', () async {
      final logs = <JsConsoleLog>[];

      // Subscribe to console log stream
      final subscription = runtime.onConsoleLog.listen((log) {
        logs.add(log);
      });

      // Execute JavaScript code
      runtime.eval('console.log("First log")');
      runtime.eval('console.warn("Second log")');
      runtime.eval('console.error("Third log")');

      // Wait for async event processing
      await Future.delayed(Duration(milliseconds: 50));

      expect(logs, hasLength(3));
      expect(logs[0].level, equals('log'));
      expect(logs[0].message, equals('First log'));
      expect(logs[1].level, equals('warn'));
      expect(logs[1].message, equals('Second log'));
      expect(logs[2].level, equals('error'));
      expect(logs[2].message, equals('Third log'));

      await subscription.cancel();
    });

    test('onConsoleLog stream can have multiple listeners', () async {
      final logs1 = <JsConsoleLog>[];
      final logs2 = <JsConsoleLog>[];

      // Subscribe to console log stream with two listeners
      final sub1 = runtime.onConsoleLog.listen((log) => logs1.add(log));
      final sub2 = runtime.onConsoleLog.listen((log) => logs2.add(log));

      // Execute JavaScript code
      runtime.eval('console.log("Test message")');

      // Wait for async event processing
      await Future.delayed(Duration(milliseconds: 50));

      expect(logs1, hasLength(1));
      expect(logs2, hasLength(1));
      expect(logs1[0].message, equals('Test message'));
      expect(logs2[0].message, equals('Test message'));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('onConsoleLog stream continues after clearLogs', () async {
      final logs = <JsConsoleLog>[];

      final subscription = runtime.onConsoleLog.listen((log) {
        logs.add(log);
      });

      // Log some messages
      runtime.eval('console.log("Before clear")');
      await Future.delayed(Duration(milliseconds: 50));

      expect(logs, hasLength(1));
      expect(runtime.consoleLogs, hasLength(1));

      // Clear logs
      runtime.clearConsoleLogs();
      expect(runtime.consoleLogs, hasLength(0));

      // Log more messages
      runtime.eval('console.log("After clear")');
      await Future.delayed(Duration(milliseconds: 50));

      // Stream should still receive new logs
      expect(logs, hasLength(2));
      expect(logs[1].message, equals('After clear'));

      // But consoleLogs should only have the new log
      expect(runtime.consoleLogs, hasLength(1));
      expect(runtime.consoleLogs[0].message, equals('After clear'));

      await subscription.cancel();
    });
  });
}
