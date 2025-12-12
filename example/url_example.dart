// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_quickjs/dart_quickjs.dart';

void main() {
  // Create a runtime with URL and console polyfills enabled
  final runtime = JsRuntime(
    config: JsRuntimeConfig(enableURL: true, enableConsole: true),
  );

  print('=== URL Examples ===\n');

  // Example 1: Basic URL parsing
  print('1. Parsing a complete URL:');
  final urlParts = runtime.eval('''
    (function() {
      const url = new URL('https://user:pass@example.com:8080/path/to/page?key=value&foo=bar#section');
      return {
        href: url.href,
        protocol: url.protocol,
        username: url.username,
        password: url.password,
        hostname: url.hostname,
        port: url.port,
        pathname: url.pathname,
        search: url.search,
        hash: url.hash,
        origin: url.origin
      };
    })();
  ''');
  print('   Protocol: ${urlParts['protocol']}');
  print('   Username: ${urlParts['username']}');
  print('   Password: ${urlParts['password']}');
  print('   Hostname: ${urlParts['hostname']}');
  print('   Port: ${urlParts['port']}');
  print('   Pathname: ${urlParts['pathname']}');
  print('   Search: ${urlParts['search']}');
  print('   Hash: ${urlParts['hash']}');
  print('   Origin: ${urlParts['origin']}\n');

  // Example 2: Modifying URL components
  print('2. Modifying URL components:');
  runtime.eval('''
    (function() {
      const url = new URL('https://example.com/old-path');
      console.log('Original:', url.href);

      url.protocol = 'http:';
      console.log('Changed protocol:', url.href);

      url.hostname = 'newdomain.com';
      console.log('Changed hostname:', url.href);

      url.port = '3000';
      console.log('Changed port:', url.href);

      url.pathname = '/new-path';
      console.log('Changed pathname:', url.href);

      url.search = '?updated=true';
      console.log('Changed search:', url.href);

      url.hash = '#section';
      console.log('Changed hash:', url.href);
    })();
  ''');
  print('');

  // Example 3: Relative URLs
  print('3. Resolving relative URLs:');
  final relativeUrls = runtime.eval('''
    (function() {
      const base = new URL('https://example.com/path/to/page.html');

      return {
        base: base.href,
        relative: new URL('other.html', base).href,
        sibling: new URL('./sibling.html', base).href,
        parent: new URL('../parent.html', base).href,
        absolute: new URL('/absolute/path.html', base).href
      };
    })();
  ''');
  print('   Base URL: ${relativeUrls['base']}');
  print('   Relative: ${relativeUrls['relative']}');
  print('   Sibling: ${relativeUrls['sibling']}');
  print('   Parent: ${relativeUrls['parent']}');
  print('   Absolute: ${relativeUrls['absolute']}\n');

  print('=== URLSearchParams Examples ===\n');

  // Example 4: Creating URLSearchParams
  print('4. Creating URLSearchParams from different sources:');
  runtime.eval('''
    (function() {
      // From string
      const params1 = new URLSearchParams('foo=1&bar=2&baz=3');
      console.log('From string:', params1.toString());

      // From object
      const params2 = new URLSearchParams({
        name: 'John',
        age: '30',
        city: 'Beijing'
      });
      console.log('From object:', params2.toString());

      // From array
      const params3 = new URLSearchParams([
        ['key1', 'value1'],
        ['key2', 'value2']
      ]);
      console.log('From array:', params3.toString());
    })();
  ''');
  print('');

  // Example 5: URLSearchParams operations
  print('5. URLSearchParams CRUD operations:');
  runtime.eval('''
    (function() {
      const params = new URLSearchParams();

      // Append
      params.append('color', 'red');
      params.append('color', 'blue');
      params.append('size', 'large');
      console.log('After append:', params.toString());

      // Get
      console.log('Get color:', params.get('color'));
      console.log('Get all colors:', params.getAll('color'));
      console.log('Has size:', params.has('size'));

      // Set (replaces all)
      params.set('color', 'green');
      console.log('After set:', params.toString());

      // Delete
      params.delete('size');
      console.log('After delete:', params.toString());

      // Sort
      params.append('zebra', '1');
      params.append('apple', '2');
      console.log('Before sort:', params.toString());
      params.sort();
      console.log('After sort:', params.toString());
    })();
  ''');
  print('');

  // Example 6: Iterating over URLSearchParams
  print('6. Iterating over URLSearchParams:');
  runtime.eval('''
    (function() {
      const params = new URLSearchParams('a=1&b=2&c=3&a=4');

      console.log('forEach:');
      params.forEach((value, key) => {
        console.log('  ' + key + ' = ' + value);
      });

      console.log('\\nkeys:');
      for (const key of params.keys()) {
        console.log('  ' + key);
      }

      console.log('\\nvalues:');
      for (const value of params.values()) {
        console.log('  ' + value);
      }

      console.log('\\nentries:');
      for (const [key, value] of params.entries()) {
        console.log('  ' + key + ' = ' + value);
      }
    })();
  ''');
  print('');

  // Example 7: URL with SearchParams
  print('7. Using URL with searchParams:');
  final apiUrl = runtime.eval('''
    (function() {
      const url = new URL('https://api.example.com/search');

      // Add query parameters
      url.searchParams.append('q', 'javascript');
      url.searchParams.append('page', '1');
      url.searchParams.append('limit', '10');

      console.log('URL with params:', url.href);

      // Modify parameter
      url.searchParams.set('page', '2');
      console.log('After modifying page:', url.href);

      // Delete parameter
      url.searchParams.delete('limit');
      console.log('After deleting limit:', url.href);

      return url.href;
    })();
  ''');
  print('   Final URL: $apiUrl\n');

  // Example 8: URL encoding
  print('8. URL encoding and decoding:');
  runtime.eval('''
    (function() {
      // Manual encoding
      const query = '你好世界';
      const encoded = encodeURIComponent(query);
      console.log('Original:', query);
      console.log('Encoded:', encoded);
      console.log('Decoded:', decodeURIComponent(encoded));

      // URLSearchParams handles encoding automatically
      const params = new URLSearchParams();
      params.append('message', '你好世界 & 特殊字符!');
      params.append('emoji', '😀🎉');
      console.log('\\nURLSearchParams encoded:', params.toString());
      console.log('Decoded message:', params.get('message'));
      console.log('Decoded emoji:', params.get('emoji'));
    })();
  ''');
  print('');

  // Example 9: Building API URLs
  print('9. Building API URLs dynamically:');
  final apiRequest = runtime.eval('''
    (function() {
      const baseUrl = 'https://api.github.com/search/repositories';
      const url = new URL(baseUrl);

      // Add search parameters
      url.searchParams.set('q', 'language:dart');
      url.searchParams.set('sort', 'stars');
      url.searchParams.set('order', 'desc');
      url.searchParams.set('per_page', '10');

      return {
        url: url.href,
        params: url.search,
        paramCount: Array.from(url.searchParams.keys()).length
      };
    })();
  ''');
  print('   API URL: ${apiRequest['url']}');
  print('   Query string: ${apiRequest['params']}');
  print('   Parameter count: ${apiRequest['paramCount']}\n');

  // Example 10: URL validation
  print('10. URL validation:');
  runtime.eval('''
    (function() {
      function isValidUrl(string) {
        try {
          new URL(string);
          return true;
        } catch (e) {
          return false;
        }
      }

      console.log('Valid URLs:');
      console.log('  https://example.com:', isValidUrl('https://example.com'));
      console.log('  http://localhost:3000:', isValidUrl('http://localhost:3000'));
      console.log('  ftp://files.example.com:', isValidUrl('ftp://files.example.com'));

      console.log('\\nInvalid URLs:');
      console.log('  not a url:', isValidUrl('not a url'));
      console.log('  //example.com:', isValidUrl('//example.com'));
      console.log('  example.com:', isValidUrl('example.com'));
    })();
  ''');
  print('');

  // Clean up
  runtime.dispose();
}
