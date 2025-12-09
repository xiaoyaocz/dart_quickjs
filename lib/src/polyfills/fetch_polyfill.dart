// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart' as http;

import '../bridge.dart';
import '../runtime.dart';

/// A polyfill for the JavaScript Fetch API using Dart's http package.
///
/// This provides a `fetch()` function in the JavaScript context that
/// uses Dart's http package to make HTTP requests.
///
/// Example usage:
/// ```dart
/// final runtime = JsRuntime(
///   config: JsRuntimeConfig(enableFetch: true),
/// );
///
/// // Now in JavaScript you can use fetch:
/// final result = await runtime.evalAsync('''
///   const response = await fetch('https://api.example.com/data');
///   return await response.json();
/// ''');
/// ```
class FetchPolyfill {
  final JsRuntime _runtime;
  late final JsBridge _bridge;
  final http.Client? _client;

  /// Creates a new FetchPolyfill.
  ///
  /// [runtime] is the JavaScript runtime to install the polyfill into.
  /// [client] is an optional http.Client to use for requests (useful for testing).
  FetchPolyfill(this._runtime, {http.Client? client}) : _client = client {
    _bridge = JsBridge(_runtime);
    _bridge.registerHandler('fetch', _handleFetchCall);
  }

  /// Gets the underlying JsBridge instance.
  JsBridge get bridge => _bridge;

  /// Installs the fetch polyfill into the JavaScript context.
  void install() {
    // Install the fetch API polyfill
    _runtime.eval('''
      // Response class
      globalThis.Response = class Response {
        constructor(body, init) {
          this._body = body;
          this._bodyUsed = false;
          this.ok = init.ok;
          this.status = init.status;
          this.statusText = init.statusText || '';
          this.headers = new Headers(init.headers || {});
          this.url = init.url || '';
          this.type = 'basic';
          this.redirected = init.redirected || false;
        }
        
        get bodyUsed() {
          return this._bodyUsed;
        }
        
        async text() {
          if (this._bodyUsed) {
            throw new Error('Body has already been consumed');
          }
          this._bodyUsed = true;
          return this._body;
        }
        
        async json() {
          const text = await this.text();
          return JSON.parse(text);
        }
        
        async blob() {
          throw new Error('Blob not supported in this environment');
        }
        
        async arrayBuffer() {
          throw new Error('ArrayBuffer not supported in this environment');
        }
        
        async formData() {
          throw new Error('FormData not supported in this environment');
        }
        
        clone() {
          if (this._bodyUsed) {
            throw new Error('Cannot clone a Response whose body has already been consumed');
          }
          return new Response(this._body, {
            ok: this.ok,
            status: this.status,
            statusText: this.statusText,
            headers: this.headers,
            url: this.url,
            redirected: this.redirected
          });
        }
      };
      
      // Headers class
      globalThis.Headers = class Headers {
        constructor(init) {
          this._headers = {};
          if (init) {
            if (init instanceof Headers) {
              init.forEach((value, key) => {
                this.set(key, value);
              });
            } else if (Array.isArray(init)) {
              for (const [key, value] of init) {
                this.append(key, value);
              }
            } else if (typeof init === 'object') {
              for (const [key, value] of Object.entries(init)) {
                this.set(key, value);
              }
            }
          }
        }
        
        append(name, value) {
          const key = name.toLowerCase();
          if (this._headers[key]) {
            this._headers[key] += ', ' + value;
          } else {
            this._headers[key] = String(value);
          }
        }
        
        delete(name) {
          delete this._headers[name.toLowerCase()];
        }
        
        get(name) {
          return this._headers[name.toLowerCase()] || null;
        }
        
        has(name) {
          return name.toLowerCase() in this._headers;
        }
        
        set(name, value) {
          this._headers[name.toLowerCase()] = String(value);
        }
        
        forEach(callback) {
          for (const [key, value] of Object.entries(this._headers)) {
            callback(value, key, this);
          }
        }
        
        keys() {
          return Object.keys(this._headers)[Symbol.iterator]();
        }
        
        values() {
          return Object.values(this._headers)[Symbol.iterator]();
        }
        
        entries() {
          return Object.entries(this._headers)[Symbol.iterator]();
        }
        
        [Symbol.iterator]() {
          return this.entries();
        }
      };
      
      // AbortController class (basic implementation)
      globalThis.AbortController = class AbortController {
        constructor() {
          this.signal = { aborted: false, reason: undefined };
        }
        
        abort(reason) {
          this.signal.aborted = true;
          this.signal.reason = reason || new Error('The operation was aborted');
        }
      };
      
      // fetch function
      globalThis.fetch = function(url, options) {
        options = options || {};
        
        const method = (options.method || 'GET').toUpperCase();
        const headers = {};
        
        // Process headers
        if (options.headers) {
          if (options.headers instanceof Headers) {
            options.headers.forEach((value, key) => {
              headers[key] = value;
            });
          } else if (Array.isArray(options.headers)) {
            for (const [key, value] of options.headers) {
              headers[key.toLowerCase()] = value;
            }
          } else if (typeof options.headers === 'object') {
            for (const [key, value] of Object.entries(options.headers)) {
              headers[key.toLowerCase()] = value;
            }
          }
        }
        
        // Process body
        let body = null;
        if (options.body !== undefined && options.body !== null) {
          if (typeof options.body === 'string') {
            body = options.body;
          } else if (typeof options.body === 'object') {
            body = JSON.stringify(options.body);
            if (!headers['content-type']) {
              headers['content-type'] = 'application/json';
            }
          }
        }
        
        // Make the request via Dart bridge
        return __dart_bridge__.call('fetch', 'request', [{
          url: String(url),
          method: method,
          headers: headers,
          body: body,
          credentials: options.credentials || 'same-origin',
          redirect: options.redirect || 'follow',
          timeout: options.timeout || 30000
        }]).then(function(result) {
          // result is already parsed JSON from Dart
          return new Response(result.body, {
            ok: result.ok,
            status: result.status,
            statusText: result.statusText,
            headers: result.headers,
            url: result.url,
            redirected: result.redirected
          });
        });
      };
    ''');
  }

  /// Handles fetch calls from JavaScript.
  FutureOr<dynamic> _handleFetchCall(String method, List<dynamic> args) async {
    if (method != 'request' || args.isEmpty) {
      throw ArgumentError('Invalid fetch call');
    }

    final options = args[0] as Map<String, dynamic>;
    final url = options['url'] as String;
    final httpMethod = options['method'] as String? ?? 'GET';
    final headers =
        (options['headers'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ??
        {};
    final body = options['body'] as String?;
    final timeout = Duration(milliseconds: options['timeout'] as int? ?? 30000);

    final client = _client ?? http.Client();
    final shouldCloseClient = _client == null;

    try {
      final uri = Uri.parse(url);

      http.Response response;

      switch (httpMethod) {
        case 'GET':
          response = await client.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await client
              .post(uri, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await client
              .put(uri, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await client
              .delete(uri, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await client
              .patch(uri, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'HEAD':
          response = await client.head(uri, headers: headers).timeout(timeout);
          break;
        default:
          throw UnsupportedError('HTTP method not supported: $httpMethod');
      }

      return {
        'body': response.body,
        'ok': response.statusCode >= 200 && response.statusCode < 300,
        'status': response.statusCode,
        'statusText': _getStatusText(response.statusCode),
        'headers': response.headers,
        'url': response.request?.url.toString() ?? url,
        'redirected': response.isRedirect,
      };
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  /// Processes pending fetch requests.
  ///
  /// Call this method in your event loop to process async fetch operations.
  Future<int> processRequests() async {
    return _bridge.processRequests();
  }

  /// Gets the status text for an HTTP status code.
  String _getStatusText(int statusCode) {
    return switch (statusCode) {
      100 => 'Continue',
      101 => 'Switching Protocols',
      200 => 'OK',
      201 => 'Created',
      202 => 'Accepted',
      203 => 'Non-Authoritative Information',
      204 => 'No Content',
      205 => 'Reset Content',
      206 => 'Partial Content',
      300 => 'Multiple Choices',
      301 => 'Moved Permanently',
      302 => 'Found',
      303 => 'See Other',
      304 => 'Not Modified',
      305 => 'Use Proxy',
      307 => 'Temporary Redirect',
      308 => 'Permanent Redirect',
      400 => 'Bad Request',
      401 => 'Unauthorized',
      402 => 'Payment Required',
      403 => 'Forbidden',
      404 => 'Not Found',
      405 => 'Method Not Allowed',
      406 => 'Not Acceptable',
      407 => 'Proxy Authentication Required',
      408 => 'Request Timeout',
      409 => 'Conflict',
      410 => 'Gone',
      411 => 'Length Required',
      412 => 'Precondition Failed',
      413 => 'Payload Too Large',
      414 => 'URI Too Long',
      415 => 'Unsupported Media Type',
      416 => 'Range Not Satisfiable',
      417 => 'Expectation Failed',
      418 => "I'm a teapot",
      422 => 'Unprocessable Entity',
      429 => 'Too Many Requests',
      500 => 'Internal Server Error',
      501 => 'Not Implemented',
      502 => 'Bad Gateway',
      503 => 'Service Unavailable',
      504 => 'Gateway Timeout',
      505 => 'HTTP Version Not Supported',
      _ => '',
    };
  }
}
