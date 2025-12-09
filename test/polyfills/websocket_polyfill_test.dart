import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:test/test.dart';

void main() {
  group('WebSocketPolyfill', () {
    late JsRuntime runtime;

    setUp(() {
      runtime = JsRuntime(
        config: JsRuntimeConfig(
          enableWebSocket: true,
          enableConsole: true,
          enableTimer: true,
        ),
      );
    });

    tearDown(() {
      runtime.dispose();
    });

    test('WebSocket class is available', () {
      final result = runtime.eval('typeof WebSocket');
      expect(result, equals('function'));
    });

    test('WebSocket state constants are defined', () {
      final connecting = runtime.eval('WebSocket.CONNECTING');
      final open = runtime.eval('WebSocket.OPEN');
      final closing = runtime.eval('WebSocket.CLOSING');
      final closed = runtime.eval('WebSocket.CLOSED');

      expect(connecting, equals(0));
      expect(open, equals(1));
      expect(closing, equals(2));
      expect(closed, equals(3));
    });

    test('WebSocket can be instantiated', () {
      final result = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        ws instanceof WebSocket;
      ''');

      expect(result, isTrue);
    });

    test('WebSocket has correct initial state', () {
      final readyState = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        ws.readyState;
      ''');

      expect(readyState, equals(0)); // CONNECTING
    });

    test('WebSocket has url property', () {
      final url = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        ws.url;
      ''');

      expect(url, equals('wss://ws.postman-echo.com/raw'));
    });

    test('WebSocket has event handler properties', () {
      final result = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        ({
          hasOnopen: 'onopen' in ws,
          hasOnmessage: 'onmessage' in ws,
          hasOnerror: 'onerror' in ws,
          hasOnclose: 'onclose' in ws,
        });
      ''');

      expect(result['hasOnopen'], isTrue);
      expect(result['hasOnmessage'], isTrue);
      expect(result['hasOnerror'], isTrue);
      expect(result['hasOnclose'], isTrue);
    });

    test('WebSocket can set event handlers', () {
      final result = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        ws.onopen = function() {};
        ws.onmessage = function() {};
        ws.onerror = function() {};
        ws.onclose = function() {};
        
        ({
          onopenSet: typeof ws.onopen === 'function',
          onmessageSet: typeof ws.onmessage === 'function',
          onerrorSet: typeof ws.onerror === 'function',
          oncloseSet: typeof ws.onclose === 'function',
        });
      ''');

      expect(result['onopenSet'], isTrue);
      expect(result['onmessageSet'], isTrue);
      expect(result['onerrorSet'], isTrue);
      expect(result['oncloseSet'], isTrue);
    });

    test('WebSocket has addEventListener method', () {
      final result = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        typeof ws.addEventListener;
      ''');

      expect(result, equals('function'));
    });

    test('WebSocket has removeEventListener method', () {
      final result = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        typeof ws.removeEventListener;
      ''');

      expect(result, equals('function'));
    });

    test('WebSocket has send method', () {
      final result = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        typeof ws.send;
      ''');

      expect(result, equals('function'));
    });

    test('WebSocket has close method', () {
      final result = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        typeof ws.close;
      ''');

      expect(result, equals('function'));
    });

    test('WebSocket binaryType property', () {
      final result = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        const defaultType = ws.binaryType;
        ws.binaryType = 'arraybuffer';
        const newType = ws.binaryType;
        ({ defaultType, newType });
      ''');

      expect(result['defaultType'], equals('blob'));
      expect(result['newType'], equals('arraybuffer'));
    });

    test('WebSocket throws when sending before connection is open', () {
      expect(
        () => runtime.eval('''
          const ws = new WebSocket('wss://ws.postman-echo.com/raw');
          ws.send('test'); // Should throw because not connected yet
        '''),
        throwsA(isA<JsException>()),
      );
    });

    test('WebSocket close is idempotent', () {
      // Closing multiple times should not throw
      runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw');
        ws.close();
        ws.close();
        ws.close();
      ''');
      // If we get here without exception, test passes
    });

    // Integration test with actual WebSocket connection
    test(
      'WebSocket can connect to echo server',
      () async {
        await runtime.evalAsync('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw/');
        
        await new Promise((resolve, reject) => {
          const timeout = setTimeout(() => {
            reject(new Error('Connection timeout'));
          }, 3000);
          
          ws.onopen = function() {
            clearTimeout(timeout);
            console.log('Connected to echo server');
            ws.close();
          };
          
          ws.onerror = function(error) {
            clearTimeout(timeout);
            reject(error);
          };
          
          ws.onclose = function(event) {
            resolve();
          };
        });
      ''');

        // Check console logs
        expect(runtime.consoleLogs, isNotEmpty);
        expect(
          runtime.consoleLogs.any((log) => log.message.contains('Connected')),
          isTrue,
        );
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'WebSocket can send and receive messages',
      () async {
        await runtime.evalAsync('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw/');
        
        await new Promise((resolve, reject) => {
          const timeout = setTimeout(() => {
            reject(new Error('Test timeout'));
          }, 5000);
          
          ws.onopen = function() {
            console.log('Sending message');
            ws.send('Hello WebSocket!');
          };
          
          ws.onmessage = function(event) {
            clearTimeout(timeout);
            console.log('Received:', event.data);
            ws.close();
          };
          
          ws.onerror = function(error) {
            clearTimeout(timeout);
            reject(error);
          };
          
          ws.onclose = function(event) {
            resolve();
          };
        });
      ''');

        // Check console logs
        expect(
          runtime.consoleLogs.any((log) => log.message.contains('Sending')),
          isTrue,
        );
        expect(
          runtime.consoleLogs.any((log) => log.message.contains('Received')),
          isTrue,
        );
      },
      timeout: Timeout(Duration(seconds: 8)),
    );

    test('WebSocket with protocols parameter', () {
      final url = runtime.eval('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw', ['protocol1', 'protocol2']);
        ws.url;
      ''');

      expect(url, equals('wss://ws.postman-echo.com/raw'));
    });

    test(
      'WebSocket can use addEventListener for events',
      () async {
        await runtime.evalAsync('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw/');
        
        await new Promise((resolve, reject) => {
          const timeout = setTimeout(() => {
            reject(new Error('Test timeout'));
          }, 3000);
          
          ws.addEventListener('open', function() {
            console.log('Connected via addEventListener');
            ws.close();
          });
          
          ws.addEventListener('close', function() {
            clearTimeout(timeout);
            resolve();
          });
          
          ws.addEventListener('error', function(error) {
            clearTimeout(timeout);
            reject(error);
          });
        });
      ''');

        expect(
          runtime.consoleLogs.any(
            (log) => log.message.contains('addEventListener'),
          ),
          isTrue,
        );
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'WebSocket close with code and reason',
      () async {
        await runtime.evalAsync('''
        const ws = new WebSocket('wss://ws.postman-echo.com/raw/');
        
        await new Promise((resolve, reject) => {
          const timeout = setTimeout(() => {
            reject(new Error('Test timeout'));
          }, 3000);
          
          ws.onopen = function() {
            ws.close(1000, 'Test completed');
          };
          
          ws.onclose = function(event) {
            clearTimeout(timeout);
            console.log('Closed with code:', event.code, 'reason:', event.reason);
            resolve();
          };
          
          ws.onerror = function(error) {
            clearTimeout(timeout);
            reject(error);
          };
        });
      ''');

        expect(
          runtime.consoleLogs.any((log) => log.message.contains('code')),
          isTrue,
        );
      },
      timeout: Timeout(Duration(seconds: 5)),
    );
  });
}
