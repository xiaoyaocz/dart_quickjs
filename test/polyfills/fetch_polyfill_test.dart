import 'dart:convert';

import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FetchPolyfill', () {
    late JsRuntime runtime;
    late MockClient mockClient;

    setUp(() {
      // Create a mock HTTP client for testing
      mockClient = MockClient((request) async {
        // Handle different test endpoints
        switch (request.url.path) {
          case '/api/test':
            return http.Response(
              jsonEncode({'message': 'Hello from mock!', 'status': 'ok'}),
              200,
              headers: {'content-type': 'application/json'},
            );

          case '/api/echo':
            // Echo back the request body
            final body = request.body;
            return http.Response(
              jsonEncode({'echo': body, 'method': request.method}),
              200,
              headers: {'content-type': 'application/json'},
            );

          case '/api/headers':
            // Return the received headers
            return http.Response(
              jsonEncode({'headers': request.headers}),
              200,
              headers: {'content-type': 'application/json'},
            );

          case '/api/error':
            return http.Response('Internal Server Error', 500);

          case '/api/not-found':
            return http.Response('Not Found', 404);

          case '/api/text':
            return http.Response(
              'Plain text response',
              200,
              headers: {'content-type': 'text/plain'},
            );

          default:
            return http.Response('Not Found', 404);
        }
      });

      runtime = JsRuntime(
        config: JsRuntimeConfig(enableFetch: true, httpClient: mockClient),
      );
    });

    tearDown(() {
      runtime.dispose();
      mockClient.close();
    });

    group('basic GET requests', () {
      test('fetch returns Response object', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/test');
          return {
            ok: response.ok,
            status: response.status,
            type: response.type
          };
        ''');

        expect(result['ok'], isTrue);
        expect(result['status'], equals(200));
        expect(result['type'], equals('basic'));
      });

      test('response.json() parses JSON response', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/test');
          return await response.json();
        ''');

        expect(result['message'], equals('Hello from mock!'));
        expect(result['status'], equals('ok'));
      });

      test('response.text() returns plain text', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/text');
          return await response.text();
        ''');

        expect(result, equals('Plain text response'));
      });
    });

    group('HTTP methods', () {
      test('POST request with JSON body', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/echo', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: 'Test', value: 42 })
          });
          return await response.json();
        ''');

        expect(result['method'], equals('POST'));
        expect(result['echo'], contains('Test'));
      });

      test('PUT request', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/echo', {
            method: 'PUT',
            body: 'updated data'
          });
          return await response.json();
        ''');

        expect(result['method'], equals('PUT'));
        expect(result['echo'], equals('updated data'));
      });

      test('DELETE request', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/echo', {
            method: 'DELETE'
          });
          return await response.json();
        ''');

        expect(result['method'], equals('DELETE'));
      });

      test('PATCH request', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/echo', {
            method: 'PATCH',
            body: 'patch data'
          });
          return await response.json();
        ''');

        expect(result['method'], equals('PATCH'));
      });
    });

    group('custom headers', () {
      test('custom headers are sent', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/headers', {
            headers: {
              'X-Custom-Header': 'custom-value',
              'Authorization': 'Bearer token123'
            }
          });
          return await response.json();
        ''');

        expect(result['headers']['x-custom-header'], equals('custom-value'));
        expect(result['headers']['authorization'], equals('Bearer token123'));
      });

      test('Headers class works correctly', () async {
        final result = await runtime.evalAsync('''
          const headers = new Headers();
          headers.append('Content-Type', 'application/json');
          headers.set('X-Test', 'value');
          
          return {
            contentType: headers.get('Content-Type'),
            test: headers.get('X-Test'),
            hasContentType: headers.has('Content-Type'),
            hasNonExistent: headers.has('Non-Existent')
          };
        ''');

        expect(result['contentType'], equals('application/json'));
        expect(result['test'], equals('value'));
        expect(result['hasContentType'], isTrue);
        expect(result['hasNonExistent'], isFalse);
      });

      test('Headers.delete removes header', () async {
        final result = await runtime.evalAsync('''
          const headers = new Headers({ 'X-Test': 'value' });
          const before = headers.has('X-Test');
          headers.delete('X-Test');
          const after = headers.has('X-Test');
          return { before, after };
        ''');

        expect(result['before'], isTrue);
        expect(result['after'], isFalse);
      });
    });

    group('error handling', () {
      test('fetch handles 500 error', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/error');
          return {
            ok: response.ok,
            status: response.status
          };
        ''');

        expect(result['ok'], isFalse);
        expect(result['status'], equals(500));
      });

      test('fetch handles 404 error', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/not-found');
          return {
            ok: response.ok,
            status: response.status
          };
        ''');

        expect(result['ok'], isFalse);
        expect(result['status'], equals(404));
      });

      test('response.json() throws on invalid JSON', () async {
        try {
          await runtime.evalAsync('''
            const response = await fetch('http://test.com/api/text');
            return await response.json();
          ''');
          fail('Should have thrown');
        } catch (e) {
          // JSON parse error - could be SyntaxError or unexpected token
          expect(
            e.toString().toLowerCase(),
            anyOf(
              contains('syntaxerror'),
              contains('unexpected'),
              contains('parse'),
            ),
          );
        }
      });

      test('body can only be consumed once', () async {
        try {
          await runtime.evalAsync('''
            const response = await fetch('http://test.com/api/test');
            await response.text();
            await response.text(); // Should throw
          ''');
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Body has already been consumed'));
        }
      });
    });

    group('Response object', () {
      test('response.clone() creates a copy', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/test');
          const clone = response.clone();
          
          // Read both bodies
          const originalJson = await response.json();
          const cloneJson = await clone.json();
          
          return {
            originalOk: response.ok,
            cloneOk: clone.ok,
            originalMessage: originalJson.message,
            cloneMessage: cloneJson.message
          };
        ''');

        expect(result['originalOk'], isTrue);
        expect(result['cloneOk'], isTrue);
        expect(result['originalMessage'], equals('Hello from mock!'));
        expect(result['cloneMessage'], equals('Hello from mock!'));
      });

      test('Response constructor works', () async {
        final result = await runtime.evalAsync('''
          const response = new Response(
            JSON.stringify({ test: 'value' }),
            { status: 201, ok: true, statusText: 'Created' }
          );
          
          return {
            status: response.status,
            statusText: response.statusText,
            body: await response.json()
          };
        ''');

        expect(result['status'], equals(201));
        expect(result['statusText'], equals('Created'));
        expect(result['body']['test'], equals('value'));
      });

      test('Response.bodyUsed tracks consumption', () async {
        final result = await runtime.evalAsync('''
          const response = await fetch('http://test.com/api/test');
          const before = response.bodyUsed;
          await response.text();
          const after = response.bodyUsed;
          return { before, after };
        ''');

        expect(result['before'], isFalse);
        expect(result['after'], isTrue);
      });
    });

    group('AbortController', () {
      test('AbortController creates signal', () async {
        final result = await runtime.evalAsync('''
          const controller = new AbortController();
          return {
            hasSignal: controller.signal !== undefined,
            aborted: controller.signal.aborted
          };
        ''');

        expect(result['hasSignal'], isTrue);
        expect(result['aborted'], isFalse);
      });

      test('abort() sets aborted flag', () async {
        final result = await runtime.evalAsync('''
          const controller = new AbortController();
          const before = controller.signal.aborted;
          controller.abort();
          const after = controller.signal.aborted;
          return { before, after };
        ''');

        expect(result['before'], isFalse);
        expect(result['after'], isTrue);
      });
    });

    test('fetch polyfill is not available when disabled', () {
      final runtimeNoFetch = JsRuntime(
        config: JsRuntimeConfig(enableFetch: false),
      );

      final result = runtimeNoFetch.eval('typeof fetch');
      expect(result, equals('undefined'));

      runtimeNoFetch.dispose();
    });
  });
}
