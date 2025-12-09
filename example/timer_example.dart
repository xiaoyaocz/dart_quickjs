// Example demonstrating Timer polyfill with setTimeout and setInterval.

import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  // Create runtime with timer polyfill enabled
  final runtime = JsRuntime(
    config: JsRuntimeConfig(enableTimer: true, enableConsole: true),
  );

  try {
    // ============================================================
    // Example 1: Basic setTimeout
    // ============================================================
    print('=== Example 1: Basic setTimeout ===\n');

    final result1 = await runtime.evalAsync('''
      console.log('Starting setTimeout test...');
      
      return new Promise(resolve => {
        setTimeout(() => {
          console.log('Timeout fired after 100ms!');
          resolve('done');
        }, 100);
      });
    ''');

    print('  Result: $result1');
    for (final log in runtime.consoleLogs) {
      print('  ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 2: setTimeout with Promise (evalAsync)
    // ============================================================
    print('\n=== Example 2: setTimeout with Promise ===\n');

    final result2 = await runtime.evalAsync('''
      return new Promise(resolve => {
        console.log('Promise started, waiting 100ms...');
        setTimeout(() => {
          console.log('Promise resolved!');
          resolve('Hello from setTimeout!');
        }, 100);
      });
    ''');

    print('  Result: $result2');
    for (final log in runtime.consoleLogs) {
      print('  ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 3: clearTimeout
    // ============================================================
    print('\n=== Example 3: clearTimeout ===\n');

    final result3 = await runtime.evalAsync('''
      const timerId = setTimeout(() => {
        console.log('This should NOT be printed!');
      }, 100);
      
      // Clear the timeout immediately
      clearTimeout(timerId);
      console.log('Timer cleared!');
      return 'Timer was cancelled';
    ''');

    print('  Result: $result3');
    for (final log in runtime.consoleLogs) {
      print('  ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 4: setInterval
    // ============================================================
    print('\n=== Example 4: setInterval ===\n');

    final result4 = await runtime.evalAsync('''
      return new Promise(resolve => {
        let count = 0;
        const intervalId = setInterval(() => {
          count++;
          console.log('Interval tick: ' + count);
          
          if (count >= 3) {
            clearInterval(intervalId);
            console.log('Interval cleared after 3 ticks');
            resolve(count);
          }
        }, 50);
      });
    ''');

    print('  Result: $result4 ticks');
    for (final log in runtime.consoleLogs) {
      print('  ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 5: Async/await with delay helper
    // ============================================================
    print('\n=== Example 5: Async delay helper ===\n');

    final delayResult = await runtime.evalAsync('''
      // Define a delay helper function
      function delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
      }
      
      async function run() {
        console.log('Step 1: Starting...');
        await delay(50);
        console.log('Step 2: After 50ms delay');
        await delay(50);
        console.log('Step 3: After another 50ms delay');
        return 'All steps completed!';
      }
      
      return await run();
    ''');

    print('  Result: $delayResult');
    for (final log in runtime.consoleLogs) {
      print('  ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 6: Multiple concurrent timers
    // ============================================================
    print('\n=== Example 6: Multiple concurrent timers ===\n');

    final concurrentResult = await runtime.evalAsync('''
      const results = [];
      
      await Promise.all([
        new Promise(resolve => setTimeout(() => {
          results.push('Timer A (100ms)');
          resolve();
        }, 100)),
        new Promise(resolve => setTimeout(() => {
          results.push('Timer B (50ms)');
          resolve();
        }, 50)),
        new Promise(resolve => setTimeout(() => {
          results.push('Timer C (75ms)');
          resolve();
        }, 75))
      ]);
      
      return results;
    ''');

    print('  Results in order of completion:');
    for (final item in concurrentResult) {
      print('    - $item');
    }

    print('\n=== Timer Examples Completed ===');
    print(
      'Active timers remaining: ${runtime.timerPolyfill!.activeTimerCount}',
    );
  } finally {
    runtime.dispose();
  }
}
