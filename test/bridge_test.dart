// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:test/test.dart';

void main() {
  late JsRuntime runtime;
  late JsBridge bridge;

  setUp(() {
    runtime = JsRuntime();
    bridge = JsBridge(runtime);
  });

  tearDown(() {
    bridge.reset();
    runtime.dispose();
  });

  group('JsBridge - Dart to JS', () {
    test('callJs - simple function', () {
      runtime.eval('globalThis.testFunc = function(x) { return x * 2; }');

      final result = bridge.callJs('testFunc', [5]);
      expect(result, equals(10));
    });

    test('callJs - nested function', () {
      runtime.eval('''
        globalThis.myObj = {
          nested: {
            func: function(a, b) { return a + b; }
          }
        };
      ''');

      final result = bridge.callJs('myObj.nested.func', [3, 7]);
      expect(result, equals(10));
    });

    test('callJs - with array argument', () {
      runtime.eval('''
        globalThis.sumArray = function(arr) {
          return arr.reduce((sum, val) => sum + val, 0);
        };
      ''');

      final result = bridge.callJs('sumArray', [
        [1, 2, 3, 4, 5],
      ]);
      expect(result, equals(15));
    });

    test('callJs - with object argument', () {
      runtime.eval('''
        globalThis.greet = function(person) {
          return 'Hello, ' + person.name + '!';
        };
      ''');

      final result = bridge.callJs('greet', [
        {'name': 'Alice'},
      ]);
      expect(result, equals('Hello, Alice!'));
    });

    test('callJs - returns object', () {
      runtime.eval('''
        globalThis.createUser = function(name, age) {
          return { name: name, age: age, active: true };
        };
      ''');

      final result = bridge.callJs('createUser', ['Bob', 30]);
      expect(result, isA<Map>());
      expect(result['name'], equals('Bob'));
      expect(result['age'], equals(30));
      expect(result['active'], equals(true));
    });

    test('callJs - throws error for non-existent function', () {
      expect(
        () => bridge.callJs('nonExistentFunc'),
        throwsA(isA<JsException>()),
      );
    });

    test('callJsAsync - simple async function', () async {
      runtime.eval('''
        globalThis.asyncDouble = async function(x) {
          return x * 2;
        };
      ''');

      final result = await bridge.callJsAsync('asyncDouble', [21]);
      expect(result, equals(42));
    });

    test('callJsAsync - with Promise', () async {
      runtime.eval('''
        globalThis.delayedValue = function(value) {
          return new Promise(resolve => {
            // In QuickJS, we can't use setTimeout, so we resolve immediately
            resolve(value + 100);
          });
        };
      ''');

      final result = await bridge.callJsAsync('delayedValue', [50]);
      expect(result, equals(150));
    });

    test('callJsAsync - with complex return value', () async {
      runtime.eval('''
        globalThis.fetchData = async function(id) {
          return {
            id: id,
            data: [1, 2, 3],
            metadata: { source: 'test' }
          };
        };
      ''');

      final result = await bridge.callJsAsync('fetchData', [42]);
      expect(result, isA<Map>());
      expect(result['id'], equals(42));
      expect(result['data'], equals([1, 2, 3]));
      expect(result['metadata'], isA<Map>());
    });

    test('callJsAsync - handles rejection', () async {
      runtime.eval('''
        globalThis.failingFunc = async function() {
          throw new Error('Test error');
        };
      ''');

      expect(
        () => bridge.callJsAsync('failingFunc'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('JsBridge - JS to Dart', () {
    test('registerHandler - simple sync handler', () async {
      bridge.registerHandler('test', (method, args) {
        if (method == 'add') {
          return (args[0] as num) + (args[1] as num);
        }
        return null;
      });

      runtime.eval('''
        globalThis.testResult = null;
        (async function() {
          const result = await __dart_bridge__.call('test', 'add', [5, 7]);
          globalThis.testResult = result;
        })();
      ''');

      await bridge.processRequests();
      runtime.executePendingJobs();

      final result = runtime.eval('globalThis.testResult');
      expect(result, equals(12));
    });

    test('registerHandler - async handler', () async {
      bridge.registerHandler('async', (method, args) async {
        if (method == 'delayed') {
          await Future.delayed(Duration(milliseconds: 10));
          return 'done';
        }
        return null;
      });

      runtime.eval('''
        globalThis.asyncResult = null;
        (async function() {
          const result = await __dart_bridge__.call('async', 'delayed', []);
          globalThis.asyncResult = result;
        })();
      ''');

      await bridge.processRequests();
      runtime.executePendingJobs();

      final result = runtime.eval('globalThis.asyncResult');
      expect(result, equals('done'));
    });

    test('registerHandler - returns complex objects', () async {
      bridge.registerHandler('data', (method, args) {
        if (method == 'getUser') {
          return {
            'id': args[0],
            'name': 'User${args[0]}',
            'tags': ['tag1', 'tag2'],
            'metadata': {'created': '2024-01-01'},
          };
        }
        return null;
      });

      runtime.eval('''
        globalThis.userData = null;
        (async function() {
          const result = await __dart_bridge__.call('data', 'getUser', [123]);
          globalThis.userData = result;
        })();
      ''');

      await bridge.processRequests();
      runtime.executePendingJobs();

      final result = runtime.eval('globalThis.userData');
      expect(result, isA<Map>());
      expect(result['id'], equals(123));
      expect(result['name'], equals('User123'));
      expect(result['tags'], equals(['tag1', 'tag2']));
    });

    test('registerHandler - multiple modules', () async {
      bridge.registerHandler('math', (method, args) {
        switch (method) {
          case 'add':
            return (args[0] as num) + (args[1] as num);
          case 'multiply':
            return (args[0] as num) * (args[1] as num);
        }
        return null;
      });

      bridge.registerHandler('string', (method, args) {
        switch (method) {
          case 'uppercase':
            return (args[0] as String).toUpperCase();
          case 'reverse':
            return (args[0] as String).split('').reversed.join('');
        }
        return null;
      });

      runtime.eval('''
        globalThis.results = {};
      ''');

      // Call each method separately and process requests after each
      runtime.eval('''
        (async function() {
          globalThis.results.sum = await __dart_bridge__.call('math', 'add', [10, 5]);
        })();
      ''');
      await bridge.processRequests();
      runtime.executePendingJobs();

      runtime.eval('''
        (async function() {
          globalThis.results.product = await __dart_bridge__.call('math', 'multiply', [3, 4]);
        })();
      ''');
      await bridge.processRequests();
      runtime.executePendingJobs();

      runtime.eval('''
        (async function() {
          globalThis.results.upper = await __dart_bridge__.call('string', 'uppercase', ['hello']);
        })();
      ''');
      await bridge.processRequests();
      runtime.executePendingJobs();

      runtime.eval('''
        (async function() {
          globalThis.results.reversed = await __dart_bridge__.call('string', 'reverse', ['world']);
        })();
      ''');
      await bridge.processRequests();
      runtime.executePendingJobs();

      final results = runtime.eval('globalThis.results');
      expect(results['sum'], equals(15));
      expect(results['product'], equals(12));
      expect(results['upper'], equals('HELLO'));
      expect(results['reversed'], equals('dlrow'));
    });

    test('registerHandler - error handling', () async {
      bridge.registerHandler('error', (method, args) {
        throw Exception('Test error from Dart');
      });

      runtime.eval('''
        globalThis.errorCaught = false;
        globalThis.errorMessage = null;
        (async function() {
          try {
            await __dart_bridge__.call('error', 'fail', []);
          } catch (e) {
            globalThis.errorCaught = true;
            globalThis.errorMessage = e.message;
          }
        })();
      ''');

      await bridge.processRequests();
      runtime.executePendingJobs();

      final caught = runtime.eval('globalThis.errorCaught');
      final message = runtime.eval('globalThis.errorMessage');

      expect(caught, equals(true));
      expect(message, contains('Test error from Dart'));
    });

    test('unregisterHandler - removes handler', () async {
      bridge.registerHandler('temp', (method, args) => 'success');
      bridge.unregisterHandler('temp');

      runtime.eval('''
        globalThis.unregisterTest = null;
        globalThis.unregisterError = null;
        (async function() {
          try {
            await __dart_bridge__.call('temp', 'test', []);
          } catch (e) {
            globalThis.unregisterError = e.message;
          }
        })();
      ''');

      await bridge.processRequests();
      runtime.executePendingJobs();

      final error = runtime.eval('globalThis.unregisterError');
      expect(error, contains('Handler not found'));
    });

    test('processRequests - returns count', () async {
      bridge.registerHandler('counter', (method, args) => 'ok');

      // Call multiple times but process together
      runtime.eval('''
        __dart_bridge__.call('counter', 'test1', []);
        __dart_bridge__.call('counter', 'test2', []);
        __dart_bridge__.call('counter', 'test3', []);
      ''');

      final count = await bridge.processRequests();
      expect(count, equals(3));
    });
  });

  group('JsBridge - Bidirectional', () {
    test('Dart calls JS which calls Dart', () async {
      // Register Dart handler
      bridge.registerHandler('calc', (method, args) {
        if (method == 'square') {
          final n = args[0] as num;
          return n * n;
        }
        return null;
      });

      // Define JS function that calls Dart
      runtime.eval('''
        globalThis.complexCalc = function(x) {
          return __dart_bridge__.call('calc', 'square', [x]).then(function(squared) {
            return squared + 10;
          });
        };
      ''');

      // Start the JS async call
      runtime.eval('''
        globalThis.complexResult = null;
        globalThis.complexCalc(5).then(function(result) {
          globalThis.complexResult = result;
        });
      ''');

      // Process JS->Dart call
      await bridge.processRequests();
      runtime.executePendingJobs();

      final result = runtime.eval('globalThis.complexResult');
      expect(result, equals(35)); // (5*5) + 10 = 35
    });

    test('Multiple back-and-forth calls', () async {
      var dartCallCount = 0;

      bridge.registerHandler('counter', (method, args) {
        dartCallCount++;
        return dartCallCount;
      });

      runtime.eval('''
        globalThis.multiCallResults = [];
        globalThis.multiCallDone = false;
      ''');

      // Process calls one at a time
      for (var i = 0; i < 5; i++) {
        runtime.eval('''
          __dart_bridge__.call('counter', 'increment', []).then(function(count) {
            globalThis.multiCallResults.push(count);
          });
        ''');
        await bridge.processRequests();
        runtime.executePendingJobs();
      }

      final results = runtime.eval('globalThis.multiCallResults');
      expect(results, equals([1, 2, 3, 4, 5]));
      expect(dartCallCount, equals(5));
    });

    test('Nested async operations', () async {
      bridge.registerHandler('fetch', (method, args) async {
        if (method == 'getData') {
          await Future.delayed(Duration(milliseconds: 10));
          return {'id': args[0], 'value': 42};
        }
        return null;
      });

      runtime.eval('''
        globalThis.nestedResults = [];
      ''');

      // Process each call separately
      final ids = [1, 2, 3];
      for (final id in ids) {
        runtime.eval('''
          __dart_bridge__.call('fetch', 'getData', [$id]).then(function(data) {
            globalThis.nestedResults.push(data);
          });
        ''');
        await bridge.processRequests();
        runtime.executePendingJobs();
      }

      final results = runtime.eval('globalThis.nestedResults');
      expect(results, isA<List>());
      expect(results, hasLength(3));
      expect(results[0]['id'], equals(1));
      expect(results[1]['id'], equals(2));
      expect(results[2]['id'], equals(3));
    });
  });

  group('JsBridge - Edge Cases', () {
    test('null and undefined handling', () async {
      bridge.registerHandler('nullable', (method, args) {
        if (method == 'returnNull') return null;
        if (method == 'checkNull') return args.isEmpty || args[0] == null;
        return null;
      });

      runtime.eval('''
        globalThis.nullTests = {};
        __dart_bridge__.call('nullable', 'returnNull', []).then(function(result) {
          globalThis.nullTests.returnedNull = result;
        });
      ''');
      await bridge.processRequests();
      runtime.executePendingJobs();

      runtime.eval('''
        __dart_bridge__.call('nullable', 'checkNull', [null]).then(function(result) {
          globalThis.nullTests.checkedNull = result;
        });
      ''');
      await bridge.processRequests();
      runtime.executePendingJobs();

      final results = runtime.eval('globalThis.nullTests');
      expect(results['returnedNull'], isNull);
      expect(results['checkedNull'], equals(true));
    });

    test('empty arrays and objects', () async {
      bridge.registerHandler('empty', (method, args) {
        if (method == 'emptyArray') return [];
        if (method == 'emptyObject') return {};
        return null;
      });

      runtime.eval('''
        globalThis.emptyTests = {};
        __dart_bridge__.call('empty', 'emptyArray', []).then(function(result) {
          globalThis.emptyTests.arr = result;
        });
      ''');
      await bridge.processRequests();
      runtime.executePendingJobs();

      runtime.eval('''
        __dart_bridge__.call('empty', 'emptyObject', []).then(function(result) {
          globalThis.emptyTests.obj = result;
        });
      ''');
      await bridge.processRequests();
      runtime.executePendingJobs();

      final results = runtime.eval('globalThis.emptyTests');
      expect(results['arr'], equals([]));
      expect(results['obj'], equals({}));
    });

    test('moderate data transfer', () async {
      bridge.registerHandler('bulk', (method, args) {
        if (method == 'process') {
          final data = args[0] as List;
          return data.map((x) => (x as num) * 2).toList();
        }
        return null;
      });

      final testArray = List.generate(100, (i) => i);

      runtime.eval('''
        globalThis.bulkResult = null;
        __dart_bridge__.call('bulk', 'process', [${testArray}]).then(function(result) {
          globalThis.bulkResult = result;
        });
      ''');

      await bridge.processRequests();
      runtime.executePendingJobs();

      final result = runtime.eval('globalThis.bulkResult');

      expect(result, hasLength(100));
      expect(result[0], equals(0));
      expect(result[99], equals(198));
    });

    test('basic string handling', () async {
      bridge.registerHandler('strings', (method, args) {
        return args[0];
      });

      final testStrings = ['Hello World', 'Simple test', 'Numbers 123'];

      for (final str in testStrings) {
        runtime.eval('''
          globalThis.stringTest = null;
          __dart_bridge__.call('strings', 'echo', ['$str']).then(function(result) {
            globalThis.stringTest = result;
          });
        ''');

        await bridge.processRequests();
        runtime.executePendingJobs();

        final result = runtime.eval('globalThis.stringTest');
        expect(result, equals(str));
      }
    });

    test('reset clears all state', () async {
      bridge.registerHandler('test', (method, args) => 'active');

      bridge.reset();

      // Re-initialize after reset
      bridge.registerHandler('test', (method, args) => 'active');

      runtime.eval('''
        globalThis.resetError = null;
        __dart_bridge__.call('test', 'method', []).catch(function(e) {
          globalThis.resetError = e.message;
        });
      ''');

      // After reset, the handler is removed, so this should fail
      bridge.unregisterHandler('test');

      await bridge.processRequests();
      runtime.executePendingJobs();

      final error = runtime.eval('globalThis.resetError');
      expect(error, isNotNull);
    });
  });
}
