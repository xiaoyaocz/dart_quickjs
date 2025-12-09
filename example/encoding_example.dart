// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_quickjs/dart_quickjs.dart';

void main() {
  // Create a runtime with encoding and console polyfills enabled
  final runtime = JsRuntime(
    config: JsRuntimeConfig(enableEncoding: true, enableConsole: true),
  );

  print('=== TextEncoder/TextDecoder Examples ===\n');

  // Example 1: Basic text encoding
  print('1. Encoding text to UTF-8 bytes:');
  final bytes = runtime.eval('''
    (function() {
      const encoder = new TextEncoder();
      const text = 'Hello, World!';
      const bytes = encoder.encode(text);
      return Array.from(bytes);
    })();
  ''');
  print('   Text: "Hello, World!"');
  print('   Bytes: $bytes\n');

  // Example 2: Encoding multi-byte characters
  print('2. Encoding multi-byte UTF-8 characters:');
  final chineseBytes = runtime.eval('''
    (function() {
      const encoder = new TextEncoder();
      const text = '你好，世界';
      const bytes = encoder.encode(text);
      return Array.from(bytes);
    })();
  ''');
  print('   Text: "你好，世界"');
  print('   Bytes: $chineseBytes\n');

  // Example 3: Decoding bytes to text
  print('3. Decoding bytes back to text:');
  final decodedText = runtime.eval('''
    (function() {
      const decoder = new TextDecoder();
      const bytes = new Uint8Array([72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33]);
      return decoder.decode(bytes);
    })();
  ''');
  print(
    '   Bytes: [72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33]',
  );
  print('   Text: "$decodedText"\n');

  // Example 4: Encoding and decoding emoji
  print('4. Working with emoji:');
  final emojiResult = runtime.eval('''
    (function() {
      const encoder = new TextEncoder();
      const decoder = new TextDecoder();
      const emoji = '😀🎉🚀';
      const bytes = encoder.encode(emoji);
      const decoded = decoder.decode(bytes);
      return [Array.from(bytes), decoded];
    })();
  ''');
  print('   Original: "😀🎉🚀"');
  print('   Bytes: ${emojiResult[0]}');
  print('   Decoded: "${emojiResult[1]}"\n');

  print('=== Base64 (btoa/atob) Examples ===\n');

  // Example 5: Basic base64 encoding
  print('5. Encoding to base64:');
  final base64 = runtime.eval('''
    (function() {
      const text = 'Hello, World!';
      return btoa(text);
    })();
  ''');
  print('   Text: "Hello, World!"');
  print('   Base64: $base64\n');

  // Example 6: Base64 decoding
  print('6. Decoding from base64:');
  final decoded = runtime.eval('''
    (function() {
      const base64 = 'SGVsbG8sIFdvcmxkIQ==';
      return atob(base64);
    })();
  ''');
  print('   Base64: SGVsbG8sIFdvcmxkIQ==');
  print('   Text: "$decoded"\n');

  // Example 7: Round-trip encoding
  print('7. Round-trip encoding (text -> base64 -> text):');
  final roundTrip = runtime.eval('''
    (function() {
      const original = 'The quick brown fox';
      const encoded = btoa(original);
      const decoded = atob(encoded);
      return [original, encoded, decoded, original === decoded];
    })();
  ''');
  print('   Original: "${roundTrip[0]}"');
  print('   Base64: ${roundTrip[1]}');
  print('   Decoded: "${roundTrip[2]}"');
  print('   Match: ${roundTrip[3]}\n');

  // Example 8: Encoding binary data
  print('8. Encoding binary data to base64:');
  runtime.eval('''
    (function() {
      const bytes = new Uint8Array([0, 1, 2, 3, 4, 5]);
      
      // Convert bytes to binary string for btoa
      let binaryString = '';
      for (let i = 0; i < bytes.length; i++) {
        binaryString += String.fromCharCode(bytes[i]);
      }
      
      const base64 = btoa(binaryString);
      console.log('Binary bytes:', Array.from(bytes));
      console.log('Base64:', base64);
      
      // Decode back
      const decoded = atob(base64);
      const decodedBytes = new Uint8Array(decoded.length);
      for (let i = 0; i < decoded.length; i++) {
        decodedBytes[i] = decoded.charCodeAt(i);
      }
      console.log('Decoded bytes:', Array.from(decodedBytes));
    })();
  ''');

  // Example 9: Working with JSON
  print('\n9. Encoding JSON data:');
  final jsonEncoding = runtime.eval('''
    (function() {
      const encoder = new TextEncoder();
      const decoder = new TextDecoder();
      
      const data = { name: 'John', age: 30, city: 'New York' };
      const json = JSON.stringify(data);
      const bytes = encoder.encode(json);
      
      // Later, decode it back
      const decodedJson = decoder.decode(bytes);
      const parsed = JSON.parse(decodedJson);
      
      return [json, Array.from(bytes).length, parsed.name];
    })();
  ''');
  print('   JSON: ${jsonEncoding[0]}');
  print('   Byte length: ${jsonEncoding[1]}');
  print('   Parsed name: ${jsonEncoding[2]}\n');

  // Example 10: encodeInto for better performance
  print('10. Using encodeInto for efficient encoding:');
  final encodeIntoResult = runtime.eval('''
    (function() {
      const encoder = new TextEncoder();
      const text = 'Hello';
      const buffer = new Uint8Array(20); // Pre-allocated buffer
      
      const result = encoder.encodeInto(text, buffer);
      return [result.read, result.written, Array.from(buffer.slice(0, result.written))];
    })();
  ''');
  print('   Text: "Hello"');
  print('   Characters read: ${encodeIntoResult[0]}');
  print('   Bytes written: ${encodeIntoResult[1]}');
  print('   Bytes: ${encodeIntoResult[2]}\n');

  // Clean up
  runtime.dispose();
}
