// Example demonstrating WebSocket usage with the WebSocket polyfill.

import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  // Create runtime with WebSocket and console enabled
  final runtime = JsRuntime(
    config: JsRuntimeConfig(
      enableWebSocket: true,
      enableConsole: true,
      enableTimer: true,
    ),
  );

  try {
    // ============================================================
    // Example 1: Basic WebSocket Connection
    // ============================================================
    print('=== Example 1: Basic WebSocket Connection ===\n');

    await runtime.evalAsync('''
      const ws = new WebSocket('wss://ws.postman-echo.com/raw/');
      
      ws.onopen = function() {
        console.log('WebSocket connection opened');
        ws.send('Hello, WebSocket!');
      };
      
      ws.onmessage = function(event) {
        console.log('Received message:', event.data);
        ws.close();
      };
      
      ws.onerror = function(error) {
        console.error('WebSocket error:', error.message);
      };
      
      ws.onclose = function(event) {
        console.log('WebSocket closed with code:', event.code, 'reason:', event.reason);
      };
      
      // Wait for the connection to complete
      await new Promise(resolve => {
        const originalClose = ws.onclose;
        ws.onclose = function(event) {
          if (originalClose) originalClose(event);
          resolve();
        };
      });
    ''');

    print('\n--- Console logs from Example 1 ---');
    for (final log in runtime.consoleLogs) {
      print('[${log.level}] ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 2: WebSocket with addEventListener
    // ============================================================
    print('\n=== Example 2: WebSocket with addEventListener ===\n');

    await runtime.evalAsync('''
      const ws = new WebSocket('wss://ws.postman-echo.com/raw/');
      
      ws.addEventListener('open', function() {
        console.log('Connected using addEventListener');
        ws.send('Testing addEventListener');
      });
      
      ws.addEventListener('message', function(event) {
        console.log('Message received via addEventListener:', event.data);
        ws.close(1000, 'Normal closure');
      });
      
      ws.addEventListener('close', function(event) {
        console.log('Connection closed. Code:', event.code, 'Clean:', event.wasClean);
      });
      
      // Wait for the connection to complete
      await new Promise(resolve => {
        const checkState = () => {
          if (ws.readyState === WebSocket.CLOSED) {
            resolve();
          } else {
            setTimeout(checkState, 100);
          }
        };
        checkState();
      });
    ''');

    print('\n--- Console logs from Example 2 ---');
    for (final log in runtime.consoleLogs) {
      print('[${log.level}] ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 3: WebSocket State Constants
    // ============================================================
    print('\n=== Example 3: WebSocket State Constants ===\n');

    final states = await runtime.evalAsync('''
      return {
        CONNECTING: WebSocket.CONNECTING,
        OPEN: WebSocket.OPEN,
        CLOSING: WebSocket.CLOSING,
        CLOSED: WebSocket.CLOSED
      };
    ''');

    print('WebSocket.CONNECTING = ${states['CONNECTING']}');
    print('WebSocket.OPEN = ${states['OPEN']}');
    print('WebSocket.CLOSING = ${states['CLOSING']}');
    print('WebSocket.CLOSED = ${states['CLOSED']}');

    // ============================================================
    // Example 4: Multiple Messages
    // ============================================================
    print('\n=== Example 4: Sending Multiple Messages ===\n');

    await runtime.evalAsync('''
      const ws = new WebSocket('wss://ws.postman-echo.com/raw/');
      let messageCount = 0;
      const maxMessages = 3;
      
      ws.onopen = function() {
        console.log('Connection opened for multiple messages');
        sendNextMessage();
      };
      
      function sendNextMessage() {
        if (messageCount < maxMessages) {
          messageCount++;
          const message = 'Message ' + messageCount;
          console.log('Sending:', message);
          ws.send(message);
        } else {
          ws.close();
        }
      }
      
      ws.onmessage = function(event) {
        console.log('Echo received:', event.data);
        setTimeout(sendNextMessage, 500);
      };
      
      ws.onclose = function(event) {
        console.log('All messages sent and received');
      };
      
      // Wait for all messages to complete
      await new Promise(resolve => {
        ws.onclose = function(event) {
          console.log('Connection closed after all messages');
          resolve();
        };
      });
    ''');

    print('\n--- Console logs from Example 4 ---');
    for (final log in runtime.consoleLogs) {
      print('[${log.level}] ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 5: Error Handling
    // ============================================================
    print('\n=== Example 5: Error Handling ===\n');

    await runtime.evalAsync('''
      // Try to connect to an invalid WebSocket URL
      try {
        const ws = new WebSocket('ws://invalid-websocket-url-that-does-not-exist.example.com/');
        
        ws.onerror = function(error) {
          console.error('Connection error occurred:', error.message);
        };
        
        ws.onclose = function(event) {
          console.log('Connection closed. Code:', event.code);
        };
        
        // Wait a bit for the error to occur
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (e) {
        console.error('Exception:', e.message);
      }
    ''');

    print('\n--- Console logs from Example 5 ---');
    for (final log in runtime.consoleLogs) {
      print('[${log.level}] ${log.message}');
    }
    runtime.clearConsoleLogs();

    // ============================================================
    // Example 6: Custom Headers
    // ============================================================
    print('\n=== Example 6: Custom Headers ===\n');

    await runtime.evalAsync('''
      // Connect with custom HTTP headers
      const ws = new WebSocket('wss://ws.postman-echo.com/raw/', [], {
        headers: {
          'User-Agent': 'QuickJS-Dart/1.0',
          'X-Custom-Header': 'CustomValue',
          'Authorization': 'Bearer sample-token-123'
        }
      });
      
      ws.onopen = function() {
        console.log('Connected with custom headers');
        ws.send('Hello with custom headers!');
      };
      
      ws.onmessage = function(event) {
        console.log('Received:', event.data);
        ws.close(1000, 'Custom headers test complete');
      };
      
      ws.onclose = function(event) {
        console.log('Closed with code:', event.code, 'reason:', event.reason);
      };
      
      ws.onerror = function(error) {
        console.error('Error:', error.message);
      };
      
      await new Promise(resolve => {
        ws.onclose = function(event) {
          resolve();
        };
      });
    ''');

    print('\n--- Console logs from Example 6 ---');
    for (final log in runtime.consoleLogs) {
      print('[${log.level}] ${log.message}');
    }

    print('\n=== All examples completed ===');
  } finally {
    runtime.dispose();
  }
}
