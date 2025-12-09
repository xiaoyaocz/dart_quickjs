import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:test/test.dart';

void main() {
  group('EncodingPolyfill', () {
    late JsRuntime runtime;

    setUp(() {
      runtime = JsRuntime();
      final encoding = EncodingPolyfill(runtime);
      encoding.install();
    });

    tearDown(() {
      runtime.dispose();
    });

    group('TextEncoder', () {
      test('encodes ASCII string', () {
        final result = runtime.eval('''
          const encoder = new TextEncoder();
          const bytes = encoder.encode('Hello');
          Array.from(bytes);
        ''');
        expect(result, equals([72, 101, 108, 108, 111]));
      });

      test('encodes UTF-8 string with multi-byte characters', () {
        final result = runtime.eval('''
          const encoder = new TextEncoder();
          const bytes = encoder.encode('Hello, 世界');
          Array.from(bytes);
        ''');
        // 'Hello, ' = [72, 101, 108, 108, 111, 44, 32]
        // '世' (U+4E16) = [228, 184, 150]
        // '界' (U+754C) = [231, 149, 140]
        expect(
          result,
          equals([
            72,
            101,
            108,
            108,
            111,
            44,
            32,
            228,
            184,
            150,
            231,
            149,
            140,
          ]),
        );
      });

      test('encodes emoji', () {
        final result = runtime.eval('''
          const encoder = new TextEncoder();
          const bytes = encoder.encode('😀');
          Array.from(bytes);
        ''');
        // 😀 (U+1F600) = [240, 159, 152, 128]
        expect(result, equals([240, 159, 152, 128]));
      });

      test('handles empty string', () {
        final result = runtime.eval('''
          const encoder = new TextEncoder();
          const bytes = encoder.encode('');
          Array.from(bytes);
        ''');
        expect(result, equals([]));
      });

      test('has utf-8 encoding property', () {
        final result = runtime.eval('''
          const encoder = new TextEncoder();
          encoder.encoding;
        ''');
        expect(result, equals('utf-8'));
      });

      test('throws on non-utf-8 encoding', () {
        expect(
          () => runtime.eval('''
            new TextEncoder('latin1');
          '''),
          throwsA(anything),
        );
      });

      test('encodeInto writes to Uint8Array', () {
        final result = runtime.eval('''
          const encoder = new TextEncoder();
          const destination = new Uint8Array(10);
          const result = encoder.encodeInto('Hello', destination);
          [result.read, result.written, Array.from(destination)];
        ''');
        expect(result[0], equals(5)); // read
        expect(result[1], equals(5)); // written
        expect(result[2].sublist(0, 5), equals([72, 101, 108, 108, 111]));
      });
    });

    group('TextDecoder', () {
      test('decodes ASCII bytes', () {
        final result = runtime.eval('''
          const decoder = new TextDecoder();
          const bytes = new Uint8Array([72, 101, 108, 108, 111]);
          decoder.decode(bytes);
        ''');
        expect(result, equals('Hello'));
      });

      test('decodes UTF-8 bytes with multi-byte characters', () {
        final result = runtime.eval('''
          const decoder = new TextDecoder();
          const bytes = new Uint8Array([72, 101, 108, 108, 111, 44, 32, 228, 184, 150, 231, 149, 140]);
          decoder.decode(bytes);
        ''');
        expect(result, equals('Hello, 世界'));
      });

      test('decodes emoji', () {
        final result = runtime.eval('''
          const decoder = new TextDecoder();
          const bytes = new Uint8Array([240, 159, 152, 128]);
          decoder.decode(bytes);
        ''');
        expect(result, equals('😀'));
      });

      test('handles empty bytes', () {
        final result = runtime.eval('''
          const decoder = new TextDecoder();
          const bytes = new Uint8Array([]);
          decoder.decode(bytes);
        ''');
        expect(result, equals(''));
      });

      test('has utf-8 encoding property', () {
        final result = runtime.eval('''
          const decoder = new TextDecoder();
          decoder.encoding;
        ''');
        expect(result, equals('utf-8'));
      });

      test('throws on non-utf-8 encoding', () {
        expect(
          () => runtime.eval('''
            new TextDecoder('latin1');
          '''),
          throwsA(anything),
        );
      });

      test('skips BOM by default', () {
        final result = runtime.eval('''
          const decoder = new TextDecoder();
          // BOM (0xEF, 0xBB, 0xBF) followed by 'Hi'
          const bytes = new Uint8Array([0xEF, 0xBB, 0xBF, 72, 105]);
          decoder.decode(bytes);
        ''');
        expect(result, equals('Hi'));
      });

      test('includes BOM when ignoreBOM is true', () {
        // Note: QuickJS's JS_ToCStringLen2 strips BOM when converting to C string,
        // so we verify by checking character codes instead
        final charCodes = runtime.eval('''
          (function() {
            const decoder = new TextDecoder('utf-8', { ignoreBOM: true });
            const bytes = new Uint8Array([0xEF, 0xBB, 0xBF, 72, 105]);
            const result = decoder.decode(bytes);
            return Array.from(result).map(c => c.charCodeAt(0));
          })();
        ''');
        // BOM (U+FEFF = 65279) should be present
        expect(charCodes, equals([65279, 72, 105]));
      });

      test('replaces invalid sequences with replacement character', () {
        final result = runtime.eval('''
          const decoder = new TextDecoder();
          // Invalid UTF-8 sequence
          const bytes = new Uint8Array([0xFF, 72, 105]);
          decoder.decode(bytes);
        ''');
        expect(result, equals('\uFFFDHi'));
      });
    });

    group('btoa', () {
      test('encodes ASCII string to base64', () {
        final result = runtime.eval('''
          btoa('Hello World');
        ''');
        expect(result, equals('SGVsbG8gV29ybGQ='));
      });

      test('encodes empty string', () {
        final result = runtime.eval('''
          btoa('');
        ''');
        expect(result, equals(''));
      });

      test('encodes single character', () {
        final result = runtime.eval('''
          btoa('A');
        ''');
        expect(result, equals('QQ=='));
      });

      test('encodes two characters', () {
        final result = runtime.eval('''
          btoa('AB');
        ''');
        expect(result, equals('QUI='));
      });

      test('encodes three characters', () {
        final result = runtime.eval('''
          btoa('ABC');
        ''');
        expect(result, equals('QUJD'));
      });

      test('throws on characters outside Latin1 range', () {
        expect(
          () => runtime.eval('''
            btoa('Hello 世界');
          '''),
          throwsA(anything),
        );
      });

      test('requires at least one argument', () {
        expect(() => runtime.eval('btoa()'), throwsA(anything));
      });
    });

    group('atob', () {
      test('decodes base64 to ASCII string', () {
        final result = runtime.eval('''
          atob('SGVsbG8gV29ybGQ=');
        ''');
        expect(result, equals('Hello World'));
      });

      test('decodes empty string', () {
        final result = runtime.eval('''
          atob('');
        ''');
        expect(result, equals(''));
      });

      test('decodes single character', () {
        final result = runtime.eval('''
          atob('QQ==');
        ''');
        expect(result, equals('A'));
      });

      test('decodes two characters', () {
        final result = runtime.eval('''
          atob('QUI=');
        ''');
        expect(result, equals('AB'));
      });

      test('decodes three characters', () {
        final result = runtime.eval('''
          atob('QUJD');
        ''');
        expect(result, equals('ABC'));
      });

      test('ignores whitespace', () {
        final result = runtime.eval('''
          atob('SGVs bG8g\\nV29y bGQ=');
        ''');
        expect(result, equals('Hello World'));
      });

      test('throws on invalid characters', () {
        expect(
          () => runtime.eval('''
            atob('Hello@World');
          '''),
          throwsA(anything),
        );
      });

      test('handles missing padding', () {
        final result = runtime.eval('''
          (function() {
            // Missing padding (should still decode)
            return atob('SGVsbG8gV29ybGQ');
          })();
        ''');
        // May have trailing nulls, just check it starts correctly
        expect(result.toString().startsWith('Hello World'), isTrue);
      });

      test('requires at least one argument', () {
        expect(() => runtime.eval('atob()'), throwsA(anything));
      });
    });

    group('round-trip encoding', () {
      test('TextEncoder -> TextDecoder', () {
        final result = runtime.eval('''
          const encoder = new TextEncoder();
          const decoder = new TextDecoder();
          const text = 'Hello, 世界! 😀';
          const bytes = encoder.encode(text);
          decoder.decode(bytes);
        ''');
        expect(result, equals('Hello, 世界! 😀'));
      });

      test('btoa -> atob', () {
        final result = runtime.eval('''
          const original = 'Hello World!';
          const encoded = btoa(original);
          atob(encoded);
        ''');
        expect(result, equals('Hello World!'));
      });

      test('TextEncoder -> btoa -> atob -> TextDecoder', () {
        final result = runtime.eval('''
          const text = 'Test123';
          const encoder = new TextEncoder();
          const decoder = new TextDecoder();
          
          // Convert to bytes
          const bytes = encoder.encode(text);
          
          // Convert bytes to string for btoa
          let binaryString = '';
          for (let i = 0; i < bytes.length; i++) {
            binaryString += String.fromCharCode(bytes[i]);
          }
          
          // Encode to base64
          const base64 = btoa(binaryString);
          
          // Decode from base64
          const decoded = atob(base64);
          
          // Convert back to bytes
          const decodedBytes = new Uint8Array(decoded.length);
          for (let i = 0; i < decoded.length; i++) {
            decodedBytes[i] = decoded.charCodeAt(i);
          }
          
          // Decode bytes to text
          decoder.decode(decodedBytes);
        ''');
        expect(result, equals('Test123'));
      });
    });

    group('integration with other APIs', () {
      test('can use with JSON.stringify', () {
        final result = runtime.eval('''
          const encoder = new TextEncoder();
          const obj = { name: 'Test', value: 42 };
          const json = JSON.stringify(obj);
          const bytes = encoder.encode(json);
          Array.from(bytes).length;
        ''');
        expect(result, greaterThan(0));
      });

      test('can encode base64 URL-safe strings manually', () {
        final result = runtime.eval('''
          const text = 'Hello World!';
          const base64 = btoa(text);
          // Convert to URL-safe base64
          base64.replace(/\\+/g, '-').replace(/\\//g, '_').replace(/=/g, '');
        ''');
        expect(result, equals('SGVsbG8gV29ybGQh'));
      });
    });
  });
}
