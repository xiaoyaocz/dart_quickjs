// Example demonstrating WebSocket custom headers usage.

import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  print('=== WebSocket Custom Headers Demo ===\n');

  final runtime = JsRuntime(
    config: JsRuntimeConfig(
      enableWebSocket: true,
      enableConsole: true,
      enableTimer: true,
    ),
  );

  try {
    // Example 1: Basic custom headers
    print('Example 1: Basic Authorization Header\n');

    await runtime.evalAsync('''
      const ws = new WebSocket('wss://ws.postman-echo.com/raw', [], {
        headers: {
          'Authorization': 'Bearer my-secret-token'
        }
      });
      
      ws.onopen = () => {
        console.log('✓ Connected with Authorization header');
        ws.send('Authenticated message');
      };
      
      ws.onmessage = (event) => {
        console.log('Received:', event.data);
        ws.close();
      };
      
      await new Promise(resolve => ws.onclose = resolve);
    ''');

    print('\n--- Logs ---');
    for (final log in runtime.consoleLogs) {
      print('[${log.level}] ${log.message}');
    }
    runtime.clearConsoleLogs();

    // Example 2: Multiple custom headers
    print('\n\nExample 2: Multiple Custom Headers\n');

    await runtime.evalAsync('''
      const ws = new WebSocket('wss://ws.postman-echo.com/raw', [], {
        headers: {
          'Authorization': 'Bearer token-123',
          'X-API-Key': 'my-api-key',
          'X-Client-Version': '1.0.0',
          'X-Platform': 'QuickJS-Dart',
          'User-Agent': 'CustomClient/1.0'
        }
      });
      
      ws.onopen = () => {
        console.log('✓ Connected with multiple headers:');
        console.log('  - Authorization');
        console.log('  - X-API-Key');
        console.log('  - X-Client-Version');
        console.log('  - X-Platform');
        console.log('  - User-Agent');
        ws.send('Multi-header test');
      };
      
      ws.onmessage = (event) => {
        console.log('✓ Echo received:', event.data);
        ws.close();
      };
      
      await new Promise(resolve => ws.onclose = resolve);
    ''');

    print('\n--- Logs ---');
    for (final log in runtime.consoleLogs) {
      print('[${log.level}] ${log.message}');
    }
    runtime.clearConsoleLogs();

    // Example 3: Headers with protocols
    print('\n\nExample 3: Headers + Protocols\n');

    await runtime.evalAsync('''
      const ws = new WebSocket(
        'wss://ws.postman-echo.com/raw',
        ['chat', 'superchat'],
        {
          headers: {
            'Authorization': 'Bearer protocol-test-token',
            'X-Protocol-Version': '2.0'
          }
        }
      );
      
      ws.onopen = () => {
        console.log('✓ Connected with protocols and headers');
        console.log('Protocol:', ws.protocol || '(none selected)');
        ws.send('Protocol + headers test');
      };
      
      ws.onmessage = (event) => {
        console.log('✓ Received:', event.data);
        ws.close();
      };
      
      await new Promise(resolve => ws.onclose = resolve);
    ''');

    print('\n--- Logs ---');
    for (final log in runtime.consoleLogs) {
      print('[${log.level}] ${log.message}');
    }

    print('\n=== Demo completed successfully ===');
  } finally {
    runtime.dispose();
  }
}
