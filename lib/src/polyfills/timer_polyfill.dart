// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../runtime.dart';

/// A polyfill for JavaScript Timer APIs (setTimeout, setInterval, clearTimeout, clearInterval).
///
/// This implementation uses a pure JavaScript timer queue that is processed
/// during the evalAsync loop, avoiding platform-specific Dart Timer issues.
///
/// Example usage:
/// ```dart
/// final runtime = JsRuntime(
///   config: JsRuntimeConfig(enableTimer: true),
/// );
///
/// // Now in JavaScript you can use timers:
/// await runtime.evalAsync('''
///   await new Promise(resolve => setTimeout(resolve, 1000));
///   console.log('1 second passed');
/// ''');
/// ```
class TimerPolyfill {
  final JsRuntime _runtime;

  /// Creates a new TimerPolyfill.
  ///
  /// [runtime] is the JavaScript runtime to install the polyfill into.
  TimerPolyfill(this._runtime);

  /// Installs the timer polyfill into the JavaScript context.
  void install() {
    _runtime.eval('''
      // Timer implementation using a queue processed by Dart
      globalThis.__timerQueue__ = {
        timers: new Map(),
        nextId: 1,
        startTime: Date.now()
      };

      // Get current timestamp in ms
      globalThis.__timerQueue__.now = function() {
        return Date.now() - globalThis.__timerQueue__.startTime;
      };

      // setTimeout implementation
      globalThis.setTimeout = function(callback, delay, ...args) {
        if (typeof callback !== 'function') {
          throw new TypeError('Callback must be a function');
        }
        
        const timerId = globalThis.__timerQueue__.nextId++;
        const timeout = globalThis.__timerQueue__.now() + (delay || 0);
        
        globalThis.__timerQueue__.timers.set(timerId, {
          callback,
          args,
          timeout,
          interval: 0,  // 0 means one-shot
          cleared: false
        });
        
        return timerId;
      };

      // clearTimeout implementation
      globalThis.clearTimeout = function(timerId) {
        if (timerId === undefined || timerId === null) return;
        const timer = globalThis.__timerQueue__.timers.get(timerId);
        if (timer) {
          timer.cleared = true;
          globalThis.__timerQueue__.timers.delete(timerId);
        }
      };

      // setInterval implementation
      globalThis.setInterval = function(callback, delay, ...args) {
        if (typeof callback !== 'function') {
          throw new TypeError('Callback must be a function');
        }
        
        const timerId = globalThis.__timerQueue__.nextId++;
        const interval = Math.max(delay || 0, 1);  // Minimum 1ms interval
        const timeout = globalThis.__timerQueue__.now() + interval;
        
        globalThis.__timerQueue__.timers.set(timerId, {
          callback,
          args,
          timeout,
          interval,
          cleared: false
        });
        
        return timerId;
      };

      // clearInterval implementation
      globalThis.clearInterval = function(timerId) {
        if (timerId === undefined || timerId === null) return;
        const timer = globalThis.__timerQueue__.timers.get(timerId);
        if (timer) {
          timer.cleared = true;
          globalThis.__timerQueue__.timers.delete(timerId);
        }
      };

      // Process expired timers - called from Dart
      globalThis.__processTimers__ = function() {
        const now = globalThis.__timerQueue__.now();
        const toExecute = [];
        
        // Find all expired timers
        for (const [id, timer] of globalThis.__timerQueue__.timers) {
          if (timer.cleared) {
            globalThis.__timerQueue__.timers.delete(id);
            continue;
          }
          if (timer.timeout <= now) {
            toExecute.push({ id, timer });
          }
        }
        
        // Execute expired timers
        for (const { id, timer } of toExecute) {
          if (timer.cleared) continue;
          
          try {
            timer.callback.apply(null, timer.args);
          } catch (e) {
            console.error('Timer callback error:', e);
          }
          
          if (timer.interval > 0 && !timer.cleared) {
            // Reschedule interval timer
            timer.timeout = now + timer.interval;
          } else {
            // Remove one-shot timer
            globalThis.__timerQueue__.timers.delete(id);
          }
        }
        
        return toExecute.length;
      };

      // Check if any timers are pending
      globalThis.__hasTimers__ = function() {
        return globalThis.__timerQueue__.timers.size > 0;
      };

      // Get minimum delay until next timer fires
      globalThis.__getNextTimerDelay__ = function() {
        const now = globalThis.__timerQueue__.now();
        let minDelay = -1;
        
        for (const timer of globalThis.__timerQueue__.timers.values()) {
          if (timer.cleared) continue;
          const delay = timer.timeout - now;
          if (minDelay < 0 || delay < minDelay) {
            minDelay = delay;
          }
        }
        
        return minDelay;
      };
    ''');
  }

  /// Processes expired timers in the JavaScript context.
  ///
  /// Returns the number of timers that were executed.
  int processTimers() {
    final result = _runtime.eval('globalThis.__processTimers__()');
    _runtime.executePendingJobs();
    return result is int ? result : 0;
  }

  /// Returns true if there are any pending timers.
  bool get hasPendingTimers {
    final result = _runtime.eval('globalThis.__hasTimers__()');
    return result == true;
  }

  /// Gets the delay in milliseconds until the next timer fires.
  ///
  /// Returns -1 if there are no pending timers.
  int getNextTimerDelay() {
    final result = _runtime.eval('globalThis.__getNextTimerDelay__()');
    return result is int ? result : (result is double ? result.toInt() : -1);
  }

  /// Returns the number of active timers.
  int get activeTimerCount {
    final result = _runtime.eval('globalThis.__timerQueue__.timers.size');
    return result is int ? result : 0;
  }

  /// Clears all timers.
  void dispose() {
    if (!_runtime.isDisposed) {
      _runtime.eval('globalThis.__timerQueue__.timers.clear();');
    }
  }
}
