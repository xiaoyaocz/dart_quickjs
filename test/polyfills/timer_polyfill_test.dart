import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:test/test.dart';

void main() {
  group('TimerPolyfill', () {
    late JsRuntime runtime;

    setUp(() {
      runtime = JsRuntime(config: JsRuntimeConfig(enableTimer: true));
    });

    tearDown(() {
      runtime.dispose();
    });

    group('setTimeout', () {
      test('setTimeout returns an id', () async {
        final result = await runtime.evalAsync('''
          const id = setTimeout(() => {}, 100);
          clearTimeout(id); // Cancel the timer to avoid async issues
          return typeof id === 'number' && id > 0;
        ''');
        expect(result, isTrue);
      });

      test('setTimeout executes callback after delay', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            let called = false;
            setTimeout(() => {
              called = true;
              resolve(called);
            }, 10);
          });
        ''');
        expect(result, isTrue);
      });

      test('setTimeout with zero delay executes immediately', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            setTimeout(() => resolve('done'), 0);
          });
        ''');
        expect(result, equals('done'));
      });

      test('setTimeout passes arguments to callback', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            setTimeout((a, b, c) => {
              resolve([a, b, c]);
            }, 10, 1, 2, 3);
          });
        ''');
        expect(result, equals([1, 2, 3]));
      });

      test('multiple setTimeouts execute in correct order', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            const order = [];
            setTimeout(() => { order.push('A'); if (order.length === 3) resolve(order); }, 90);
            setTimeout(() => { order.push('B'); if (order.length === 3) resolve(order); }, 30);
            setTimeout(() => { order.push('C'); if (order.length === 3) resolve(order); }, 60);
          });
        ''');
        expect(result, equals(['B', 'C', 'A']));
      });

      test('setTimeout throws on non-function callback', () async {
        try {
          await runtime.evalAsync('''
            setTimeout("not a function", 100);
          ''');
          fail('Should have thrown');
        } catch (e) {
          expect(
            e.toString().toLowerCase(),
            anyOf(
              contains('typeerror'),
              contains('callback'),
              contains('function'),
            ),
          );
        }
      });
    });

    group('clearTimeout', () {
      test('clearTimeout cancels pending timeout', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            let wasCalled = false;
            const id = setTimeout(() => { wasCalled = true; }, 50);
            clearTimeout(id);
            setTimeout(() => resolve(wasCalled), 100);
          });
        ''');
        expect(result, isFalse);
      });

      test('clearTimeout with null or undefined does not throw', () async {
        await runtime.evalAsync('''
          clearTimeout(null);
          clearTimeout(undefined);
          return true;
        ''');
        // Should not throw
      });

      test('clearTimeout with invalid id does not throw', () async {
        await runtime.evalAsync('''
          clearTimeout(99999);
          return true;
        ''');
        // Should not throw
      });
    });

    group('setInterval', () {
      test('setInterval returns an id', () async {
        final result = await runtime.evalAsync('''
          const id = setInterval(() => {}, 100);
          clearInterval(id);
          return typeof id === 'number' && id > 0;
        ''');
        expect(result, isTrue);
      });

      test('setInterval executes callback multiple times', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            let count = 0;
            const id = setInterval(() => {
              count++;
              if (count >= 3) {
                clearInterval(id);
                resolve(count);
              }
            }, 20);
          });
        ''');
        expect(result, equals(3));
      });

      test('setInterval passes arguments to callback', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            let calls = 0;
            const id = setInterval((x, y) => {
              calls++;
              if (calls >= 2) {
                clearInterval(id);
                resolve(x + y);
              }
            }, 20, 10, 20);
          });
        ''');
        expect(result, equals(30));
      });

      test('setInterval throws on non-function callback', () async {
        try {
          await runtime.evalAsync('''
            setInterval(123, 100);
          ''');
          fail('Should have thrown');
        } catch (e) {
          expect(
            e.toString().toLowerCase(),
            anyOf(
              contains('typeerror'),
              contains('callback'),
              contains('function'),
            ),
          );
        }
      });
    });

    group('clearInterval', () {
      test('clearInterval stops interval execution', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            let count = 0;
            const id = setInterval(() => {
              count++;
              if (count === 2) {
                clearInterval(id);
              }
            }, 20);
            setTimeout(() => resolve(count), 200);
          });
        ''');
        expect(result, equals(2));
      });

      test('clearInterval with null or undefined does not throw', () async {
        await runtime.evalAsync('''
          clearInterval(null);
          clearInterval(undefined);
          return true;
        ''');
        // Should not throw
      });
    });

    group('integration', () {
      test('delay helper function works', () async {
        runtime.eval('''
          globalThis.delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));
        ''');

        final start = DateTime.now();
        await runtime.evalAsync('''
          await delay(50);
          return 'done';
        ''');
        final elapsed = DateTime.now().difference(start).inMilliseconds;

        expect(elapsed, greaterThanOrEqualTo(40)); // Allow some margin
      });

      test('setTimeout and setInterval work together', () async {
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            const events = [];
            const intervalId = setInterval(() => {
              events.push('interval');
            }, 30);
            
            setTimeout(() => {
              events.push('timeout');
              clearInterval(intervalId);
              resolve(events);
            }, 100);
          });
        ''');

        expect(result, contains('timeout'));
        expect(result, contains('interval'));
      });

      test('timers can be created and tracked', () async {
        // Create timers and verify they work
        final result = await runtime.evalAsync('''
          return new Promise((resolve) => {
            const id1 = setTimeout(() => {}, 1000);
            const id2 = setInterval(() => {}, 1000);
            // Both should have valid IDs
            clearTimeout(id1);
            clearInterval(id2);
            resolve(id1 > 0 && id2 > 0);
          });
        ''');
        expect(result, isTrue);
      });
    });

    test('timer polyfill is not available when disabled', () {
      final runtimeNoTimer = JsRuntime(
        config: JsRuntimeConfig(enableTimer: false),
      );

      // setTimeout should not be defined as a function
      final result = runtimeNoTimer.eval('typeof setTimeout');
      expect(result, equals('undefined'));

      runtimeNoTimer.dispose();
    });
  });
}
