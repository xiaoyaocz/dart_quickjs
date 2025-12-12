// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../runtime.dart';

/// A polyfill for JavaScript URL APIs.
///
/// This provides:
/// - `URL` - URL parsing and manipulation
/// - `URLSearchParams` - URL query string manipulation
///
/// Example usage:
/// ```dart
/// final runtime = JsRuntime(
///   config: JsRuntimeConfig(enableURL: true),
/// );
///
/// // URL parsing
/// runtime.eval('''
///   const url = new URL('https://example.com:8080/path?key=value#hash');
///   console.log(url.protocol); // 'https:'
///   console.log(url.hostname); // 'example.com'
///   console.log(url.port); // '8080'
///   console.log(url.pathname); // '/path'
///   console.log(url.search); // '?key=value'
///   console.log(url.hash); // '#hash'
/// ''');
///
/// // URLSearchParams
/// runtime.eval('''
///   const params = new URLSearchParams('foo=1&bar=2');
///   console.log(params.get('foo')); // '1'
///   params.append('baz', '3');
///   console.log(params.toString()); // 'foo=1&bar=2&baz=3'
/// ''');
/// ```
class URLPolyfill {
  final JsRuntime _runtime;

  /// Creates a new URLPolyfill.
  ///
  /// [runtime] is the JavaScript runtime to install the polyfill into.
  URLPolyfill(this._runtime);

  /// Installs the URL polyfill into the JavaScript context.
  void install() {
    _runtime.eval('''
      // URLSearchParams - URL query string manipulation
      globalThis.URLSearchParams = class URLSearchParams {
        constructor(init) {
          this._params = [];

          if (init === undefined || init === null) {
            // Empty
          } else if (typeof init === 'string') {
            // Parse query string
            const str = init.startsWith('?') ? init.slice(1) : init;
            if (str) {
              const pairs = str.split('&');
              for (const pair of pairs) {
                const index = pair.indexOf('=');
                if (index > -1) {
                  const name = decodeURIComponent(pair.slice(0, index));
                  const value = decodeURIComponent(pair.slice(index + 1));
                  this._params.push([name, value]);
                } else {
                  this._params.push([decodeURIComponent(pair), '']);
                }
              }
            }
          } else if (init instanceof URLSearchParams) {
            // Copy from another URLSearchParams
            this._params = init._params.slice();
          } else if (Array.isArray(init)) {
            // Array of [name, value] pairs
            for (const pair of init) {
              if (!Array.isArray(pair) || pair.length !== 2) {
                throw new TypeError('Invalid URLSearchParams init');
              }
              this._params.push([String(pair[0]), String(pair[1])]);
            }
          } else if (typeof init === 'object') {
            // Object with key-value pairs
            for (const key in init) {
              if (init.hasOwnProperty(key)) {
                this._params.push([key, String(init[key])]);
              }
            }
          } else {
            throw new TypeError('Invalid URLSearchParams init');
          }
        }

        append(name, value) {
          this._params.push([String(name), String(value)]);
        }

        delete(name) {
          const nameStr = String(name);
          this._params = this._params.filter(pair => pair[0] !== nameStr);
        }

        get(name) {
          const nameStr = String(name);
          const pair = this._params.find(pair => pair[0] === nameStr);
          return pair ? pair[1] : null;
        }

        getAll(name) {
          const nameStr = String(name);
          return this._params
            .filter(pair => pair[0] === nameStr)
            .map(pair => pair[1]);
        }

        has(name) {
          const nameStr = String(name);
          return this._params.some(pair => pair[0] === nameStr);
        }

        set(name, value) {
          const nameStr = String(name);
          const valueStr = String(value);
          let found = false;

          this._params = this._params.filter(pair => {
            if (pair[0] === nameStr) {
              if (!found) {
                pair[1] = valueStr;
                found = true;
                return true;
              }
              return false;
            }
            return true;
          });

          if (!found) {
            this._params.push([nameStr, valueStr]);
          }
        }

        sort() {
          this._params.sort((a, b) => {
            if (a[0] < b[0]) return -1;
            if (a[0] > b[0]) return 1;
            return 0;
          });
        }

        toString() {
          return this._params
            .map(pair => encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1]))
            .join('&');
        }

        forEach(callback, thisArg) {
          for (const [name, value] of this._params) {
            callback.call(thisArg, value, name, this);
          }
        }

        keys() {
          return this._params.map(pair => pair[0])[Symbol.iterator]();
        }

        values() {
          return this._params.map(pair => pair[1])[Symbol.iterator]();
        }

        entries() {
          return this._params.slice()[Symbol.iterator]();
        }

        [Symbol.iterator]() {
          return this.entries();
        }
      };

      // URL - URL parsing and manipulation
      globalThis.URL = class URL {
        constructor(url, base) {
          // Parse URL
          const parsed = this._parseURL(url, base);
          if (!parsed) {
            throw new TypeError('Invalid URL');
          }

          this._protocol = parsed.protocol;
          this._username = parsed.username;
          this._password = parsed.password;
          this._hostname = parsed.hostname;
          this._port = parsed.port;
          this._pathname = parsed.pathname;
          this._search = parsed.search;
          this._hash = parsed.hash;
          this._searchParams = new URLSearchParams(this._search);

          // Keep searchParams in sync
          const self = this;
          const originalAppend = this._searchParams.append;
          const originalDelete = this._searchParams.delete;
          const originalSet = this._searchParams.set;
          const originalSort = this._searchParams.sort;

          this._searchParams.append = function(...args) {
            originalAppend.apply(this, args);
            self._search = this.toString() ? '?' + this.toString() : '';
          };

          this._searchParams.delete = function(...args) {
            originalDelete.apply(this, args);
            self._search = this.toString() ? '?' + this.toString() : '';
          };

          this._searchParams.set = function(...args) {
            originalSet.apply(this, args);
            self._search = this.toString() ? '?' + this.toString() : '';
          };

          this._searchParams.sort = function(...args) {
            originalSort.apply(this, args);
            self._search = this.toString() ? '?' + this.toString() : '';
          };
        }

        _parseURL(url, base) {
          let urlStr = String(url);

          // Handle base URL
          if (base !== undefined) {
            const baseURL = typeof base === 'string' ? new URL(base) : base;
            if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(urlStr)) {
              // Relative URL
              if (urlStr.startsWith('//')) {
                urlStr = baseURL.protocol + urlStr;
              } else if (urlStr.startsWith('/')) {
                urlStr = baseURL.origin + urlStr;
              } else {
                const basePath = baseURL.pathname.substring(0, baseURL.pathname.lastIndexOf('/') + 1);
                urlStr = baseURL.origin + basePath + urlStr;
              }
            }
          }

          // URL regex pattern
          const pattern = /^([a-zA-Z][a-zA-Z0-9+.-]*):(?:\\/\\/(?:([^:@]*)(?::([^@]*))?@)?([^:\\/?#]*)(?::(\\d+))?)?([^?#]*)(?:\\?([^#]*))?(?:#(.*))?\$/;
          const match = urlStr.match(pattern);

          if (!match) {
            return null;
          }

          // Normalize pathname (resolve . and ..)
          let pathname = match[6] || '/';
          pathname = this._normalizePath(pathname);

          return {
            protocol: match[1] + ':',
            username: match[2] || '',
            password: match[3] || '',
            hostname: match[4] || '',
            port: match[5] || '',
            pathname: pathname,
            search: match[7] ? '?' + match[7] : '',
            hash: match[8] ? '#' + match[8] : ''
          };
        }

        _normalizePath(path) {
          // Split path into segments
          const segments = path.split('/');
          const normalized = [];

          for (const segment of segments) {
            if (segment === '..') {
              // Go up one level (but not above root)
              if (normalized.length > 0 && normalized[normalized.length - 1] !== '') {
                normalized.pop();
              }
            } else if (segment !== '.' && segment !== '') {
              // Add non-empty, non-current-dir segments
              normalized.push(segment);
            } else if (segment === '' && normalized.length === 0) {
              // Keep leading slash
              normalized.push('');
            }
          }

          // Reconstruct path
          let result = normalized.join('/');

          // Ensure path starts with / for absolute paths
          if (path.startsWith('/') && !result.startsWith('/')) {
            result = '/' + result;
          }

          // Handle root path
          if (result === '') {
            result = '/';
          }

          return result;
        }

        get href() {
          return this.toString();
        }

        set href(value) {
          const parsed = this._parseURL(value);
          if (!parsed) {
            throw new TypeError('Invalid URL');
          }
          this._protocol = parsed.protocol;
          this._username = parsed.username;
          this._password = parsed.password;
          this._hostname = parsed.hostname;
          this._port = parsed.port;
          this._pathname = parsed.pathname;
          this._search = parsed.search;
          this._hash = parsed.hash;
          this._searchParams = new URLSearchParams(this._search);
        }

        get origin() {
          if (this._protocol === 'file:') {
            return 'null';
          }
          const port = this._port ? ':' + this._port : '';
          return this._protocol + '//' + this._hostname + port;
        }

        get protocol() {
          return this._protocol;
        }

        set protocol(value) {
          const str = String(value);
          const protocol = str.endsWith(':') ? str : str + ':';
          if (/^[a-zA-Z][a-zA-Z0-9+.-]*:\$/.test(protocol)) {
            this._protocol = protocol;
          }
        }

        get username() {
          return this._username;
        }

        set username(value) {
          this._username = String(value);
        }

        get password() {
          return this._password;
        }

        set password(value) {
          this._password = String(value);
        }

        get host() {
          return this._port ? this._hostname + ':' + this._port : this._hostname;
        }

        set host(value) {
          const str = String(value);
          const index = str.indexOf(':');
          if (index > -1) {
            this._hostname = str.substring(0, index);
            this._port = str.substring(index + 1);
          } else {
            this._hostname = str;
            this._port = '';
          }
        }

        get hostname() {
          return this._hostname;
        }

        set hostname(value) {
          this._hostname = String(value);
        }

        get port() {
          return this._port;
        }

        set port(value) {
          this._port = String(value);
        }

        get pathname() {
          return this._pathname;
        }

        set pathname(value) {
          const str = String(value);
          this._pathname = str.startsWith('/') ? str : '/' + str;
        }

        get search() {
          return this._search;
        }

        set search(value) {
          const str = String(value);
          this._search = str ? (str.startsWith('?') ? str : '?' + str) : '';
          this._searchParams = new URLSearchParams(this._search);
        }

        get searchParams() {
          return this._searchParams;
        }

        get hash() {
          return this._hash;
        }

        set hash(value) {
          const str = String(value);
          this._hash = str ? (str.startsWith('#') ? str : '#' + str) : '';
        }

        toString() {
          let result = this._protocol;

          if (this._protocol !== 'file:' || this._hostname) {
            result += '//';

            if (this._username || this._password) {
              result += this._username;
              if (this._password) {
                result += ':' + this._password;
              }
              result += '@';
            }

            result += this._hostname;

            if (this._port) {
              result += ':' + this._port;
            }
          }

          result += this._pathname;
          result += this._search;
          result += this._hash;

          return result;
        }

        toJSON() {
          return this.toString();
        }
      };
    ''');
  }

  /// Disposes of the polyfill resources.
  void dispose() {
    // Clean up if needed
  }
}
