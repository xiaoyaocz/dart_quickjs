// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'runtime.dart';

/// A bridge handler function type.
///
/// The handler receives:
/// - [method]: The method name being called
/// - [args]: Arguments passed from JavaScript
///
/// Returns a value that will be passed back to JavaScript.
/// Can return a [Future] for async operations.
typedef BridgeHandler =
    FutureOr<dynamic> Function(String method, List<dynamic> args);

/// A bridge for bidirectional Dart <-> JavaScript communication.
///
/// This provides a generic mechanism to:
/// 1. Register Dart functions that can be called from JavaScript
/// 2. Call JavaScript functions from Dart
/// 3. Handle async operations using Promises
///
/// Example usage:
/// ```dart
/// final runtime = JsRuntime();
/// final bridge = JsBridge(runtime);
///
/// // Register a Dart handler
/// bridge.registerHandler('myModule', (method, args) {
///   switch (method) {
///     case 'add':
///       return args[0] + args[1];
///     case 'fetchData':
///       return http.get(Uri.parse(args[0])).then((r) => r.body);
///     default:
///       throw Exception('Unknown method: $method');
///   }
/// });
///
/// // Now in JS you can call:
/// // await __dart_bridge__.call('moduleName', 'methodName', [args])
/// ```
class JsBridge {
  final JsRuntime _runtime;
  final Map<String, BridgeHandler> _handlers = {};
  final Map<int, Completer<dynamic>> _pendingJsCalls = {};
  int _jsCallId = 0;
  bool _initialized = false;

  JsBridge(this._runtime);

  /// Registers a handler for a module.
  ///
  /// The [moduleName] is used to identify the handler when called from JS.
  /// The [handler] function receives the method name and arguments.
  void registerHandler(String moduleName, BridgeHandler handler) {
    _handlers[moduleName] = handler;
    _ensureInitialized();
  }

  /// Removes a registered handler.
  void unregisterHandler(String moduleName) {
    _handlers.remove(moduleName);
  }

  /// Calls a JavaScript function and returns the result.
  ///
  /// [functionPath] is the path to the function (e.g., 'myObj.myFunc')
  /// [args] are the arguments to pass to the function
  dynamic callJs(String functionPath, [List<dynamic>? args]) {
    _ensureInitialized();
    final argsJson = jsonEncode(args ?? []);
    return _runtime.eval('''
      (function() {
        const path = ${jsonEncode(functionPath)};
        const args = $argsJson;
        const parts = path.split('.');
        let func = globalThis;
        for (const part of parts) {
          func = func[part];
          if (func === undefined) {
            throw new Error('Function not found: ' + path);
          }
        }
        return func.apply(null, args);
      })()
    ''');
  }

  /// Calls a JavaScript async function and returns a Future.
  ///
  /// This handles Promise resolution properly.
  Future<dynamic> callJsAsync(
    String functionPath, [
    List<dynamic>? args,
  ]) async {
    _ensureInitialized();
    final callId = _jsCallId++;
    final completer = Completer<dynamic>();
    _pendingJsCalls[callId] = completer;

    final argsJson = jsonEncode(args ?? []);
    _runtime.eval('''
      (async function() {
        const callId = $callId;
        const path = ${jsonEncode(functionPath)};
        const args = $argsJson;
        try {
          const parts = path.split('.');
          let func = globalThis;
          for (const part of parts) {
            func = func[part];
            if (func === undefined) {
              throw new Error('Function not found: ' + path);
            }
          }
          const result = await func.apply(null, args);
          globalThis.__dart_bridge__.__jsCallResults__[$callId] = { success: true, value: result };
        } catch (e) {
          globalThis.__dart_bridge__.__jsCallResults__[$callId] = { success: false, error: e.message || String(e) };
        }
      })();
    ''');

    // Execute pending jobs to process the Promise
    _runtime.executePendingJobs();

    // Check for result
    _processJsCallResults();

    return completer.future;
  }

  void _processJsCallResults() {
    final results = _runtime.eval(
      'JSON.parse(JSON.stringify(globalThis.__dart_bridge__.__jsCallResults__ || {}))',
    );
    if (results is Map) {
      for (final entry in results.entries) {
        final callId = int.tryParse(entry.key.toString());
        if (callId == null) continue;

        final completer = _pendingJsCalls.remove(callId);
        if (completer == null) continue;

        final result = entry.value as Map?;
        if (result?['success'] == true) {
          completer.complete(result?['value']);
        } else {
          completer.completeError(
            Exception(result?['error'] ?? 'Unknown error'),
          );
        }
      }

      // Clear processed results
      _runtime.eval('globalThis.__dart_bridge__.__jsCallResults__ = {};');
    }
  }

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    // Initialize the bridge object in JavaScript
    _runtime.eval('''
      globalThis.__dart_bridge__ = {
        // Pending requests from JS to Dart (using Map for O(1) access)
        __requests__: new Map(),
        __nextRequestId__: 0,
        
        // Results from JS async calls
        __jsCallResults__: {},
        
        // Call Dart function (returns a Promise)
        // Usage: await __dart_bridge__.call('moduleName', 'methodName', [args])
        call: function(module, method, args) {
          const requestId = this.__nextRequestId__++;
          const self = this;
          
          return new Promise(function(resolve, reject) {
            self.__requests__.set(requestId, {
              module: module,
              method: method,
              args: args || [],
              resolve: resolve,
              reject: reject
            });
          });
        },
        
        // Called by Dart to get pending requests
        __getPendingRequests__: function() {
          const requests = [];
          for (const [id, req] of this.__requests__) {
            requests.push({
              id: id,
              module: req.module,
              method: req.method,
              args: req.args
            });
          }
          return requests;
        },
        
        // Called by Dart to resolve a request
        __resolveRequest__: function(requestId, value) {
          const req = this.__requests__.get(requestId);
          if (req) {
            this.__requests__.delete(requestId);
            req.resolve(value);
          }
        },
        
        // Called by Dart to reject a request
        __rejectRequest__: function(requestId, error) {
          const req = this.__requests__.get(requestId);
          if (req) {
            this.__requests__.delete(requestId);
            req.reject(new Error(error));
          }
        }
      };
    ''');
  }

  /// Processes all pending requests from JavaScript.
  ///
  /// This method should be called periodically (e.g., in an event loop)
  /// to handle calls from JavaScript to Dart.
  ///
  /// Returns the number of requests processed.
  Future<int> processRequests() async {
    _ensureInitialized();

    // Get pending requests as a serializable format
    final requestsJson = _runtime.eval('''
      JSON.stringify(globalThis.__dart_bridge__.__getPendingRequests__())
    ''');

    if (requestsJson is! String) return 0;

    List<dynamic> requests;
    try {
      requests = jsonDecode(requestsJson) as List;
    } catch (_) {
      return 0;
    }

    if (requests.isEmpty) return 0;

    var processed = 0;
    final futures = <Future>[];

    for (final request in requests) {
      if (request is! Map) continue;

      final requestId = request['id'] as int?;
      final module = request['module'] as String?;
      final method = request['method'] as String?;
      final args = (request['args'] as List?) ?? [];

      if (requestId == null || module == null || method == null) continue;

      final handler = _handlers[module];
      if (handler == null) {
        _rejectRequest(requestId, 'Handler not found: $module');
        processed++;
        continue;
      }

      try {
        final result = handler(method, List<dynamic>.from(args));

        if (result is Future) {
          // Handle async result
          futures.add(
            result
                .then((value) {
                  _resolveRequest(requestId, value);
                })
                .catchError((error) {
                  _rejectRequest(requestId, error.toString());
                }),
          );
        } else {
          // Handle sync result
          _resolveRequest(requestId, result);
        }
      } catch (e) {
        _rejectRequest(requestId, e.toString());
      }

      processed++;
    }

    // Wait for all async handlers to complete
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    // Process any JS promises that were resolved
    _runtime.executePendingJobs();

    return processed;
  }

  void _resolveRequest(int requestId, dynamic value) {
    final jsonValue = jsonEncode(value);
    _runtime.eval('''
      globalThis.__dart_bridge__.__resolveRequest__($requestId, $jsonValue);
    ''');
  }

  void _rejectRequest(int requestId, String error) {
    // Escape the error message properly for JavaScript string
    final escapedError = error
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    _runtime.eval('''
      globalThis.__dart_bridge__.__rejectRequest__($requestId, '$escapedError');
    ''');
  }

  /// Clears all pending requests and resets the bridge state.
  void reset() {
    _pendingJsCalls.clear();
    _jsCallId = 0;
    if (_initialized) {
      _runtime.eval('''
        globalThis.__dart_bridge__.__requests__ = new Map();
        globalThis.__dart_bridge__.__nextRequestId__ = 0;
        globalThis.__dart_bridge__.__jsCallResults__ = {};
      ''');
    }
  }
}
