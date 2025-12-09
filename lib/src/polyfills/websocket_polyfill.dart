// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:web_socket_channel/io.dart';

import '../bridge.dart';
import '../runtime.dart';

/// A polyfill for the JavaScript WebSocket API using Dart's web_socket_channel package.
///
/// This provides a `WebSocket` class in the JavaScript context that
/// uses Dart's web_socket_channel package to establish WebSocket connections.
///
/// Example usage:
/// ```dart
/// final runtime = JsRuntime(
///   config: JsRuntimeConfig(enableWebSocket: true),
/// );
///
/// // Now in JavaScript you can use WebSocket:
/// final result = await runtime.evalAsync('''
///   const ws = new WebSocket('wss://echo.websocket.org/');
///   ws.onopen = () => {
///     console.log('Connected');
///     ws.send('Hello WebSocket!');
///   };
///   ws.onmessage = (event) => {
///     console.log('Received:', event.data);
///     ws.close();
///   };
/// ''');
/// ```
class WebSocketPolyfill {
  final JsRuntime _runtime;
  late final JsBridge _bridge;
  final Map<int, IOWebSocketChannel> _connections = {};
  final Map<int, StreamSubscription> _subscriptions = {};
  int _nextId = 1;

  /// Creates a new WebSocketPolyfill.
  ///
  /// [runtime] is the JavaScript runtime to install the polyfill into.
  /// [bridge] is an optional existing bridge to use. If not provided, a new bridge will be created.
  WebSocketPolyfill(this._runtime, {JsBridge? bridge}) {
    _bridge = bridge ?? JsBridge(_runtime);
    _bridge.registerHandler('websocket', _handleWebSocketCall);
  }

  /// Gets the underlying JsBridge instance.
  JsBridge get bridge => _bridge;

  /// Handles WebSocket-related calls from JavaScript.
  Future<dynamic> _handleWebSocketCall(
    String method,
    List<dynamic> args,
  ) async {
    switch (method) {
      case 'connect':
        return await _connectAsync(
          args[0] as String,
          args[1] as List<dynamic>?,
          args.length > 2 ? args[2] as Map<String, dynamic>? : null,
        );
      case 'send':
        return _send(args[0] as int, args[1]);
      case 'close':
        return _close(args[0] as int, args[1] as int?, args[2] as String?);
      default:
        throw Exception('Unknown WebSocket method: $method');
    }
  }

  /// Connects to a WebSocket server asynchronously.
  Future<int> _connectAsync(
    String url,
    List<dynamic>? protocols,
    Map<String, dynamic>? headers,
  ) async {
    final wsId = _nextId++;

    try {
      // Create WebSocket connection
      final channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        protocols: protocols?.cast<String>(),
        headers: headers?.map((key, value) => MapEntry(key, value.toString())),
      );

      _connections[wsId] = channel;

      // Listen to messages
      _subscriptions[wsId] = channel.stream.listen(
        (message) {
          // Notify JavaScript about incoming message
          try {
            _runtime.eval('''
              (function() {
                const ws = globalThis.__websockets__.get($wsId);
                if (ws && ws._onmessage) {
                  ws._onmessage({ data: ${_encodeValue(message)} });
                }
              })();
            ''');
          } catch (e) {
            // Ignore if runtime is disposed
          }
        },
        onError: (error) {
          // Notify JavaScript about error
          try {
            _runtime.eval('''
              (function() {
                const ws = globalThis.__websockets__.get($wsId);
                if (ws && ws._onerror) {
                  ws._onerror({ message: ${_encodeValue(error.toString())} });
                }
              })();
            ''');
          } catch (e) {
            // Ignore if runtime is disposed
          }
        },
        onDone: () {
          // Notify JavaScript about close
          try {
            _runtime.eval('''
              (function() {
                const ws = globalThis.__websockets__.get($wsId);
                if (ws) {
                  ws._readyState = 3; // CLOSED
                  if (ws._onclose) {
                    ws._onclose({ code: 1000, reason: 'Connection closed', wasClean: true });
                  }
                }
              })();
            ''');
          } catch (e) {
            // Ignore if runtime is disposed
          }
          _cleanup(wsId);
        },
        cancelOnError: false,
      );

      // Wait for connection to be ready
      await channel.ready;

      // Return the WebSocket ID
      // The JavaScript side will set readyState and call onopen after storing the ws in the Map
      return wsId;
    } catch (e) {
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  /// Sends data through the WebSocket.
  void _send(int wsId, dynamic data) {
    final channel = _connections[wsId];
    if (channel == null) {
      throw Exception('WebSocket not found: $wsId');
    }

    channel.sink.add(data);
  }

  /// Closes the WebSocket connection.
  void _close(int wsId, int? code, String? reason) {
    final channel = _connections[wsId];
    if (channel == null) {
      return; // Already closed
    }

    channel.sink.close(code ?? 1000, reason);
    _cleanup(wsId);
  }

  /// Cleans up resources for a WebSocket connection.
  void _cleanup(int wsId) {
    _subscriptions[wsId]?.cancel();
    _subscriptions.remove(wsId);
    _connections.remove(wsId);
  }

  /// Encodes a value for JavaScript consumption.
  String _encodeValue(dynamic value) {
    if (value is String) {
      // Escape special characters for JavaScript string
      final escaped = value
          .replaceAll('\\', '\\\\')
          .replaceAll('\'', '\\\'')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
      return "'$escaped'";
    } else if (value is num || value is bool) {
      return value.toString();
    } else if (value == null) {
      return 'null';
    } else {
      // For other types, convert to string and escape
      final str = value.toString();
      final escaped = str
          .replaceAll('\\', '\\\\')
          .replaceAll('\'', '\\\'')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
      return "'$escaped'";
    }
  }

  /// Installs the WebSocket polyfill into the JavaScript context.
  void install() {
    // Install the WebSocket API polyfill
    _runtime.eval('''
      // Initialize WebSocket storage
      if (!globalThis.__websockets__) {
        globalThis.__websockets__ = new Map();
      }
      
      // WebSocket state constants
      globalThis.WebSocket = class WebSocket {
        static get CONNECTING() { return 0; }
        static get OPEN() { return 1; }
        static get CLOSING() { return 2; }
        static get CLOSED() { return 3; }
        
        constructor(url, protocols, options) {
          this._url = url;
          this._protocols = protocols || [];
          this._readyState = 0; // CONNECTING
          this._bufferedAmount = 0;
          this._extensions = '';
          this._protocol = '';
          this._binaryType = 'blob';
          
          // Event handlers
          this._onopen = null;
          this._onmessage = null;
          this._onerror = null;
          this._onclose = null;
          
          // Extract headers from options
          const headers = options?.headers || null;
          
          // Connect through Dart bridge (async)
          const connectPromise = __dart_bridge__.call('websocket', 'connect', [url, this._protocols, headers]);
          connectPromise.then(wsId => {
            this._wsId = wsId;
            globalThis.__websockets__.set(wsId, this);
            // Connection established, update state and call onopen
            this._readyState = 1; // OPEN
            if (this._onopen) {
              this._onopen({});
            }
          }).catch(error => {
            // Connection failed during setup
            this._readyState = 3; // CLOSED
            if (this._onerror) {
              this._onerror({ message: error.message || String(error) });
            }
            if (this._onclose) {
              this._onclose({ code: 1006, reason: error.message || String(error), wasClean: false });
            }
          });
        }
        
        get url() { return this._url; }
        get readyState() { return this._readyState; }
        get bufferedAmount() { return this._bufferedAmount; }
        get extensions() { return this._extensions; }
        get protocol() { return this._protocol; }
        get binaryType() { return this._binaryType; }
        
        set binaryType(value) {
          if (value !== 'blob' && value !== 'arraybuffer') {
            throw new Error('Invalid binaryType: ' + value);
          }
          this._binaryType = value;
        }
        
        // Event handler properties
        get onopen() { return this._onopen; }
        set onopen(handler) { this._onopen = handler; }
        
        get onmessage() { return this._onmessage; }
        set onmessage(handler) { this._onmessage = handler; }
        
        get onerror() { return this._onerror; }
        set onerror(handler) { this._onerror = handler; }
        
        get onclose() { return this._onclose; }
        set onclose(handler) { this._onclose = handler; }
        
        send(data) {
          if (this._readyState !== 1) {
            throw new Error('WebSocket is not open: readyState ' + this._readyState);
          }
          
          __dart_bridge__.call('websocket', 'send', [this._wsId, data]);
        }
        
        close(code, reason) {
          if (this._readyState === 2 || this._readyState === 3) {
            return; // Already closing or closed
          }
          
          this._readyState = 2; // CLOSING
          __dart_bridge__.call('websocket', 'close', [this._wsId, code, reason]);
        }
        
        // EventTarget interface methods
        addEventListener(type, listener) {
          // Simple implementation - just set the handler
          switch (type) {
            case 'open':
              this._onopen = listener;
              break;
            case 'message':
              this._onmessage = listener;
              break;
            case 'error':
              this._onerror = listener;
              break;
            case 'close':
              this._onclose = listener;
              break;
          }
        }
        
        removeEventListener(type, listener) {
          // Simple implementation - clear the handler if it matches
          switch (type) {
            case 'open':
              if (this._onopen === listener) this._onopen = null;
              break;
            case 'message':
              if (this._onmessage === listener) this._onmessage = null;
              break;
            case 'error':
              if (this._onerror === listener) this._onerror = null;
              break;
            case 'close':
              if (this._onclose === listener) this._onclose = null;
              break;
          }
        }
        
        dispatchEvent(event) {
          // Simple implementation - just call the appropriate handler
          switch (event.type) {
            case 'open':
              if (this._onopen) this._onopen(event);
              break;
            case 'message':
              if (this._onmessage) this._onmessage(event);
              break;
            case 'error':
              if (this._onerror) this._onerror(event);
              break;
            case 'close':
              if (this._onclose) this._onclose(event);
              break;
          }
          return true;
        }
      };
    ''');
  }

  /// Disposes the WebSocket polyfill and closes all connections.
  void dispose() {
    for (final wsId in _connections.keys.toList()) {
      _close(wsId, 1000, 'Going away');
    }
    _connections.clear();
    _subscriptions.clear();
  }
}
