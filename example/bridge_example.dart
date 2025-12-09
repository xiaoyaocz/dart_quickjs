// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:dart_quickjs/dart_quickjs.dart';

/// Example demonstrating the JsBridge for bidirectional Dart <-> JS communication.
///
/// This example shows:
/// 1. Calling Dart functions from JavaScript
/// 2. Calling JavaScript functions from Dart
/// 3. Handling async operations with Promises
/// 4. Managing multiple handlers/modules
void main() async {
  // Create runtime with config to automatically enable Console and Bridge
  // Note: enableFetch also creates the bridge automatically
  final runtime = JsRuntime(
    config: JsRuntimeConfig(
      enableConsole: true,
      enableFetch: true, // This also creates the bridge
      enableTimer: true,
    ),
  );

  // Bridge is automatically created when enableFetch is true
  final bridge = runtime.bridge!;

  print('=== JsBridge Example ===\n');

  // Example 1: Register Dart handlers that can be called from JS
  print('1. Registering Dart handlers...');

  // Math module
  bridge.registerHandler('math', (method, args) {
    print('   [Dart] Math.$method called with $args');
    switch (method) {
      case 'add':
        return (args[0] as num) + (args[1] as num);
      case 'multiply':
        return (args[0] as num) * (args[1] as num);
      case 'power':
        return (args[0] as num) * (args[0] as num);
      default:
        throw Exception('Unknown method: $method');
    }
  });

  // User module with async operations
  bridge.registerHandler('user', (method, args) async {
    print('   [Dart] User.$method called with $args');
    switch (method) {
      case 'getInfo':
        // Simulate async database query
        await Future.delayed(Duration(milliseconds: 100));
        return {'name': args[0], 'age': 25, 'email': '${args[0]}@example.com'};
      case 'save':
        await Future.delayed(Duration(milliseconds: 50));
        return {'success': true, 'id': 123};
      default:
        throw Exception('Unknown method: $method');
    }
  });

  // Example 2: Call Dart from JavaScript
  print('\n2. Calling Dart functions from JavaScript...');

  await runtime.evalAsync('''
    console.log('   [JS] Calling Dart math functions...');
    
    // Call sync Dart functions
    const sum = await __dart_bridge__.call('math', 'add', [5, 3]);
    console.log('   [JS] 5 + 3 =', sum);
    
    const product = await __dart_bridge__.call('math', 'multiply', [4, 7]);
    console.log('   [JS] 4 * 7 =', product);
    
    // Call async Dart functions
    console.log('   [JS] Calling async Dart user functions...');
    const userInfo = await __dart_bridge__.call('user', 'getInfo', ['Alice']);
    console.log('   [JS] User info:', JSON.stringify(userInfo));
    
    const saveResult = await __dart_bridge__.call('user', 'save', [userInfo]);
    console.log('   [JS] Save result:', JSON.stringify(saveResult));
  ''');

  // Example 3: Call JavaScript from Dart
  print('\n3. Calling JavaScript functions from Dart...');

  // Define some JS functions
  runtime.eval('''
    globalThis.jsUtils = {
      greet: function(name) {
        console.log('   [JS] greet() called with:', name);
        return 'Hello, ' + name + '!';
      },
      
      calculate: function(x, y) {
        console.log('   [JS] calculate() called with:', x, y);
        return x * y + x + y;
      },
      
      processData: function(data) {
        console.log('   [JS] processData() called with:', data);
        return {
          processed: true,
          count: data.length,
          items: data.map(item => item.toUpperCase())
        };
      }
    };
  ''');

  // Call sync JS function
  final greeting = bridge.callJs('jsUtils.greet', ['Bob']);
  print('   [Dart] Received greeting: $greeting');

  // Call JS function with calculation
  final calcResult = bridge.callJs('jsUtils.calculate', [10, 5]);
  print('   [Dart] Calculation result: $calcResult');

  // Call JS function with complex data
  final processedData = bridge.callJs('jsUtils.processData', [
    ['apple', 'banana', 'cherry'],
  ]);
  print('   [Dart] Processed data: $processedData');

  // Example 4: Error handling
  print('\n4. Error handling...');

  await runtime.evalAsync('''
    try {
      console.log('   [JS] Trying to call non-existent handler...');
      await __dart_bridge__.call('nonexistent', 'method', []);
    } catch (e) {
      console.log('   [JS] Caught error:', e.message);
    }
    
    try {
      console.log('   [JS] Trying to call non-existent method...');
      await __dart_bridge__.call('math', 'divide', [10, 2]);
    } catch (e) {
      console.log('   [JS] Caught error:', e.message);
    }
  ''');

  try {
    print('   [Dart] Trying to call non-existent JS function...');
    bridge.callJs('nonExistentFunction');
  } catch (e) {
    print('   [Dart] Caught error: $e');
  }

  // Example 5: Complex bidirectional flow
  print('\n5. Complex bidirectional flow...');

  // Register a handler that calls back to JS
  bridge.registerHandler('callback', (method, args) async {
    print('   [Dart] Callback.$method called');
    if (method == 'processWithJs') {
      final data = args[0];
      print('   [Dart] Processing data, calling back to JS...');

      // Call JS from within a Dart handler
      final jsResult = bridge.callJs('jsUtils.processData', [data]);

      // Add more processing in Dart
      final finalResult = {
        'jsProcessed': jsResult,
        'dartProcessed': (data as List).length * 2,
      };

      return finalResult;
    }
    return null;
  });

  await runtime.evalAsync('''
    console.log('   [JS] Starting complex flow...');
    const result = await __dart_bridge__.call('callback', 'processWithJs', [['one', 'two', 'three']]);
    console.log('   [JS] Final result:', JSON.stringify(result));
  ''');

  print('\n=== Example Complete ===');

  // View captured console logs
  print('\nCaptured console logs:');
  for (final log in runtime.consoleLogs) {
    print('  [${log.level}] ${log.message}');
  }

  // Cleanup
  bridge.reset();
  runtime.dispose();
}
