// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../runtime.dart';

/// A polyfill for JavaScript encoding APIs.
///
/// This provides:
/// - `TextEncoder` - encodes strings to UTF-8 bytes
/// - `TextDecoder` - decodes UTF-8 bytes to strings
/// - `atob()` - decodes base64 strings
/// - `btoa()` - encodes strings to base64
///
/// Example usage:
/// ```dart
/// final runtime = JsRuntime(
///   config: JsRuntimeConfig(enableEncoding: true),
/// );
///
/// // TextEncoder/TextDecoder
/// runtime.eval('''
///   const encoder = new TextEncoder();
///   const bytes = encoder.encode('Hello, 世界');
///   console.log(bytes); // Uint8Array
///
///   const decoder = new TextDecoder();
///   const text = decoder.decode(bytes);
///   console.log(text); // 'Hello, 世界'
/// ''');
///
/// // Base64 encoding/decoding
/// runtime.eval('''
///   const encoded = btoa('Hello World');
///   console.log(encoded); // 'SGVsbG8gV29ybGQ='
///
///   const decoded = atob(encoded);
///   console.log(decoded); // 'Hello World'
/// ''');
/// ```
class EncodingPolyfill {
  final JsRuntime _runtime;

  /// Creates a new EncodingPolyfill.
  ///
  /// [runtime] is the JavaScript runtime to install the polyfill into.
  EncodingPolyfill(this._runtime);

  /// Installs the encoding polyfill into the JavaScript context.
  void install() {
    _runtime.eval('''
      // TextEncoder - encodes strings to UTF-8 bytes
      globalThis.TextEncoder = class TextEncoder {
        constructor(encoding = 'utf-8') {
          // Only UTF-8 is supported, like in browsers
          if (encoding.toLowerCase() !== 'utf-8' && 
              encoding.toLowerCase() !== 'utf8' && 
              encoding.toLowerCase() !== 'unicode-1-1-utf-8') {
            throw new RangeError('The encoding label provided must be utf-8');
          }
          this.encoding = 'utf-8';
        }
        
        encode(input = '') {
          const str = String(input);
          const utf8 = [];
          
          for (let i = 0; i < str.length; i++) {
            let charCode = str.charCodeAt(i);
            
            // Handle surrogate pairs
            if (charCode >= 0xD800 && charCode <= 0xDBFF && i + 1 < str.length) {
              const low = str.charCodeAt(i + 1);
              if (low >= 0xDC00 && low <= 0xDFFF) {
                charCode = 0x10000 + ((charCode - 0xD800) << 10) + (low - 0xDC00);
                i++;
              }
            }
            
            // Encode to UTF-8
            if (charCode < 0x80) {
              utf8.push(charCode);
            } else if (charCode < 0x800) {
              utf8.push(0xC0 | (charCode >> 6));
              utf8.push(0x80 | (charCode & 0x3F));
            } else if (charCode < 0x10000) {
              utf8.push(0xE0 | (charCode >> 12));
              utf8.push(0x80 | ((charCode >> 6) & 0x3F));
              utf8.push(0x80 | (charCode & 0x3F));
            } else if (charCode < 0x110000) {
              utf8.push(0xF0 | (charCode >> 18));
              utf8.push(0x80 | ((charCode >> 12) & 0x3F));
              utf8.push(0x80 | ((charCode >> 6) & 0x3F));
              utf8.push(0x80 | (charCode & 0x3F));
            }
          }
          
          return new Uint8Array(utf8);
        }
        
        encodeInto(source, destination) {
          const encoded = this.encode(source);
          const length = Math.min(encoded.length, destination.length);
          
          for (let i = 0; i < length; i++) {
            destination[i] = encoded[i];
          }
          
          return {
            read: source.length,
            written: length
          };
        }
      };
      
      // TextDecoder - decodes UTF-8 bytes to strings
      globalThis.TextDecoder = class TextDecoder {
        constructor(encoding = 'utf-8', options = {}) {
          // Only UTF-8 is supported
          const label = encoding.toLowerCase();
          if (label !== 'utf-8' && label !== 'utf8' && label !== 'unicode-1-1-utf-8') {
            throw new RangeError('The encoding label provided must be utf-8');
          }
          this.encoding = 'utf-8';
          this.fatal = options.fatal || false;
          this.ignoreBOM = options.ignoreBOM || false;
        }
        
        decode(input, options = {}) {
          if (!input) {
            return '';
          }
          
          const stream = options.stream || false;
          const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
          const result = [];
          let i = 0;
          
          // Skip BOM if not ignored
          if (!this.ignoreBOM && bytes.length >= 3 &&
              bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
            i = 3;
          }
          
          while (i < bytes.length) {
            const byte1 = bytes[i++];
            
            // 1-byte sequence (0xxxxxxx)
            if (byte1 < 0x80) {
              result.push(String.fromCharCode(byte1));
              continue;
            }
            
            // 2-byte sequence (110xxxxx 10xxxxxx)
            if ((byte1 & 0xE0) === 0xC0) {
              if (i >= bytes.length) {
                if (this.fatal) throw new TypeError('Invalid UTF-8 sequence');
                result.push('\\uFFFD');
                break;
              }
              const byte2 = bytes[i++];
              if ((byte2 & 0xC0) !== 0x80) {
                if (this.fatal) throw new TypeError('Invalid UTF-8 sequence');
                result.push('\\uFFFD');
                i--;
                continue;
              }
              const codePoint = ((byte1 & 0x1F) << 6) | (byte2 & 0x3F);
              result.push(String.fromCharCode(codePoint));
              continue;
            }
            
            // 3-byte sequence (1110xxxx 10xxxxxx 10xxxxxx)
            if ((byte1 & 0xF0) === 0xE0) {
              if (i + 1 >= bytes.length) {
                if (this.fatal) throw new TypeError('Invalid UTF-8 sequence');
                result.push('\\uFFFD');
                break;
              }
              const byte2 = bytes[i++];
              const byte3 = bytes[i++];
              if ((byte2 & 0xC0) !== 0x80 || (byte3 & 0xC0) !== 0x80) {
                if (this.fatal) throw new TypeError('Invalid UTF-8 sequence');
                result.push('\\uFFFD');
                i -= 2;
                continue;
              }
              const codePoint = ((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F);
              result.push(String.fromCharCode(codePoint));
              continue;
            }
            
            // 4-byte sequence (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
            if ((byte1 & 0xF8) === 0xF0) {
              if (i + 2 >= bytes.length) {
                if (this.fatal) throw new TypeError('Invalid UTF-8 sequence');
                result.push('\\uFFFD');
                break;
              }
              const byte2 = bytes[i++];
              const byte3 = bytes[i++];
              const byte4 = bytes[i++];
              if ((byte2 & 0xC0) !== 0x80 || (byte3 & 0xC0) !== 0x80 || (byte4 & 0xC0) !== 0x80) {
                if (this.fatal) throw new TypeError('Invalid UTF-8 sequence');
                result.push('\\uFFFD');
                i -= 3;
                continue;
              }
              let codePoint = ((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | 
                             ((byte3 & 0x3F) << 6) | (byte4 & 0x3F);
              
              // Convert to surrogate pair
              if (codePoint > 0xFFFF) {
                codePoint -= 0x10000;
                result.push(String.fromCharCode(0xD800 + (codePoint >> 10)));
                result.push(String.fromCharCode(0xDC00 + (codePoint & 0x3FF)));
              } else {
                result.push(String.fromCharCode(codePoint));
              }
              continue;
            }
            
            // Invalid byte
            if (this.fatal) {
              throw new TypeError('Invalid UTF-8 sequence');
            }
            result.push('\\uFFFD');
          }
          
          return result.join('');
        }
      };
      
      // Base64 encoding table
      const base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
      
      // btoa - encode string to base64
      globalThis.btoa = function(input) {
        if (arguments.length === 0) {
          throw new TypeError('btoa requires at least 1 argument');
        }
        
        const str = String(input);
        let result = '';
        
        // Check for invalid characters (must be Latin1/ASCII 0-255)
        for (let i = 0; i < str.length; i++) {
          const charCode = str.charCodeAt(i);
          if (charCode > 255) {
            throw new DOMException(
              "The string to be encoded contains characters outside of the Latin1 range.",
              "InvalidCharacterError"
            );
          }
        }
        
        // Encode to base64
        for (let i = 0; i < str.length; i += 3) {
          const byte1 = str.charCodeAt(i);
          const byte2 = i + 1 < str.length ? str.charCodeAt(i + 1) : 0;
          const byte3 = i + 2 < str.length ? str.charCodeAt(i + 2) : 0;
          
          const encoded1 = byte1 >> 2;
          const encoded2 = ((byte1 & 0x03) << 4) | (byte2 >> 4);
          const encoded3 = ((byte2 & 0x0F) << 2) | (byte3 >> 6);
          const encoded4 = byte3 & 0x3F;
          
          result += base64Chars[encoded1];
          result += base64Chars[encoded2];
          result += i + 1 < str.length ? base64Chars[encoded3] : '=';
          result += i + 2 < str.length ? base64Chars[encoded4] : '=';
        }
        
        return result;
      };
      
      // atob - decode base64 to string
      globalThis.atob = function(input) {
        if (arguments.length === 0) {
          throw new TypeError('atob requires at least 1 argument');
        }
        
        let str = String(input).replace(/[\\s\\r\\n]/g, '');
        
        // Validate base64 string
        if (str.length % 4 === 1) {
          throw new DOMException(
            "The string to be decoded is not correctly encoded.",
            "InvalidCharacterError"
          );
        }
        
        if (!/^[A-Za-z0-9+\\/]*={0,2}\$/.test(str)) {
          throw new DOMException(
            "The string to be decoded contains invalid characters.",
            "InvalidCharacterError"
          );
        }
        
        // Build reverse lookup
        const base64Lookup = {};
        for (let i = 0; i < base64Chars.length; i++) {
          base64Lookup[base64Chars[i]] = i;
        }
        
        let result = '';
        
        // Decode from base64
        for (let i = 0; i < str.length; i += 4) {
          const encoded1 = base64Lookup[str[i]];
          const encoded2 = base64Lookup[str[i + 1]];
          const encoded3 = str[i + 2] === '=' ? 0 : base64Lookup[str[i + 2]];
          const encoded4 = str[i + 3] === '=' ? 0 : base64Lookup[str[i + 3]];
          
          const byte1 = (encoded1 << 2) | (encoded2 >> 4);
          const byte2 = ((encoded2 & 0x0F) << 4) | (encoded3 >> 2);
          const byte3 = ((encoded3 & 0x03) << 6) | encoded4;
          
          result += String.fromCharCode(byte1);
          if (str[i + 2] !== '=') {
            result += String.fromCharCode(byte2);
          }
          if (str[i + 3] !== '=') {
            result += String.fromCharCode(byte3);
          }
        }
        
        return result;
      };
      
      // DOMException polyfill for errors
      if (typeof DOMException === 'undefined') {
        globalThis.DOMException = class DOMException extends Error {
          constructor(message, name) {
            super(message);
            this.name = name || 'Error';
          }
        };
      }
    ''');
  }

  /// Disposes of the polyfill resources.
  void dispose() {
    // Clean up if needed
  }
}
