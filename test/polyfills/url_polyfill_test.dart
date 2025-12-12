import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:test/test.dart';

void main() {
  group('URLPolyfill', () {
    late JsRuntime runtime;

    setUp(() {
      runtime = JsRuntime();
      final url = URLPolyfill(runtime);
      url.install();
    });

    tearDown(() {
      runtime.dispose();
    });

    group('URL', () {
      test('parses complete URL', () {
        final result = runtime.eval('''
          (function() {
            const url = new URL('https://user:pass@example.com:8080/path?key=value#hash');
            return {
              protocol: url.protocol,
              username: url.username,
              password: url.password,
              hostname: url.hostname,
              port: url.port,
              pathname: url.pathname,
              search: url.search,
              hash: url.hash
            };
          })();
        ''');
        expect(result['protocol'], equals('https:'));
        expect(result['username'], equals('user'));
        expect(result['password'], equals('pass'));
        expect(result['hostname'], equals('example.com'));
        expect(result['port'], equals('8080'));
        expect(result['pathname'], equals('/path'));
        expect(result['search'], equals('?key=value'));
        expect(result['hash'], equals('#hash'));
      });

      test('parses URL without port', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.port;
        ''');
        expect(result, equals(''));
      });

      test('parses URL without path', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com');
          url.pathname;
        ''');
        expect(result, equals('/'));
      });

      test('returns correct origin', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com:8080/path');
          url.origin;
        ''');
        expect(result, equals('https://example.com:8080'));
      });

      test('returns correct origin without port', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.origin;
        ''');
        expect(result, equals('https://example.com'));
      });

      test('returns correct href', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com:8080/path?key=value#hash');
          url.href;
        ''');
        expect(result, equals('https://example.com:8080/path?key=value#hash'));
      });

      test('modifies protocol', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.protocol = 'http:';
          url.href;
        ''');
        expect(result, equals('http://example.com/path'));
      });

      test('modifies hostname', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.hostname = 'newdomain.com';
          url.href;
        ''');
        expect(result, equals('https://newdomain.com/path'));
      });

      test('modifies port', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.port = '3000';
          url.href;
        ''');
        expect(result, equals('https://example.com:3000/path'));
      });

      test('modifies pathname', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/old');
          url.pathname = '/new';
          url.href;
        ''');
        expect(result, equals('https://example.com/new'));
      });

      test('modifies search', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.search = '?new=param';
          url.href;
        ''');
        expect(result, equals('https://example.com/path?new=param'));
      });

      test('modifies hash', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.hash = '#section';
          url.href;
        ''');
        expect(result, equals('https://example.com/path#section'));
      });

      test('resolves relative URL with base', () {
        final result = runtime.eval('''
          const base = new URL('https://example.com/path/to/page.html');
          const url = new URL('other.html', base);
          url.href;
        ''');
        expect(result, equals('https://example.com/path/to/other.html'));
      });

      test('resolves sibling relative URL', () {
        final result = runtime.eval('''
          const base = new URL('https://example.com/path/to/page.html');
          const url = new URL('./sibling.html', base);
          url.href;
        ''');
        expect(result, equals('https://example.com/path/to/sibling.html'));
      });

      test('resolves parent relative URL', () {
        final result = runtime.eval('''
          const base = new URL('https://example.com/path/to/page.html');
          const url = new URL('../parent.html', base);
          url.href;
        ''');
        expect(result, equals('https://example.com/path/parent.html'));
      });

      test('resolves absolute path with base', () {
        final result = runtime.eval('''
          const base = new URL('https://example.com/path/to/page.html');
          const url = new URL('/absolute/path.html', base);
          url.href;
        ''');
        expect(result, equals('https://example.com/absolute/path.html'));
      });

      test('throws on invalid URL', () {
        expect(
          () => runtime.eval('''
            new URL('not a valid url');
          '''),
          throwsA(anything),
        );
      });

      test('toString returns href', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.toString();
        ''');
        expect(result, equals('https://example.com/path'));
      });

      test('toJSON returns href', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.toJSON();
        ''');
        expect(result, equals('https://example.com/path'));
      });
    });

    group('URLSearchParams', () {
      test('creates from string', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('foo=1&bar=2&baz=3');
          params.toString();
        ''');
        expect(result, equals('foo=1&bar=2&baz=3'));
      });

      test('creates from object', () {
        final result = runtime.eval('''
          const params = new URLSearchParams({
            name: 'John',
            age: '30'
          });
          params.toString();
        ''');
        expect(result, equals('name=John&age=30'));
      });

      test('creates from array', () {
        final result = runtime.eval('''
          const params = new URLSearchParams([
            ['key1', 'value1'],
            ['key2', 'value2']
          ]);
          params.toString();
        ''');
        expect(result, equals('key1=value1&key2=value2'));
      });

      test('creates empty params', () {
        final result = runtime.eval('''
          const params = new URLSearchParams();
          params.toString();
        ''');
        expect(result, equals(''));
      });

      test('appends parameters', () {
        final result = runtime.eval('''
          const params = new URLSearchParams();
          params.append('color', 'red');
          params.append('color', 'blue');
          params.append('size', 'large');
          params.toString();
        ''');
        expect(result, equals('color=red&color=blue&size=large'));
      });

      test('gets first parameter value', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('color=red&color=blue');
          params.get('color');
        ''');
        expect(result, equals('red'));
      });

      test('gets all parameter values', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('color=red&color=blue');
          params.getAll('color');
        ''');
        expect(result, equals(['red', 'blue']));
      });

      test('checks if parameter exists', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('foo=1&bar=2');
          [params.has('foo'), params.has('baz')];
        ''');
        expect(result, equals([true, false]));
      });

      test('sets parameter (replaces all)', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('color=red&color=blue');
          params.set('color', 'green');
          params.toString();
        ''');
        expect(result, equals('color=green'));
      });

      test('deletes parameter', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('foo=1&bar=2&baz=3');
          params.delete('bar');
          params.toString();
        ''');
        expect(result, equals('foo=1&baz=3'));
      });

      test('sorts parameters', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('zebra=1&apple=2&banana=3');
          params.sort();
          params.toString();
        ''');
        expect(result, equals('apple=2&banana=3&zebra=1'));
      });

      test('iterates with forEach', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('a=1&b=2');
          const result = [];
          params.forEach((value, key) => {
            result.push(key + '=' + value);
          });
          result;
        ''');
        expect(result, equals(['a=1', 'b=2']));
      });

      test('handles URL encoding', () {
        final result = runtime.eval('''
          const params = new URLSearchParams();
          params.append('message', 'Hello World!');
          params.append('special', 'a&b=c');
          params.toString();
        ''');
        expect(result, contains('Hello%20World'));
        expect(result, contains('a%26b%3Dc'));
      });

      test('handles URL decoding', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('message=Hello%20World&special=a%26b%3Dc');
          [params.get('message'), params.get('special')];
        ''');
        expect(result, equals(['Hello World', 'a&b=c']));
      });

      test('handles UTF-8 characters', () {
        final result = runtime.eval('''
          const params = new URLSearchParams();
          params.append('text', '你好世界');
          params.append('emoji', '😀🎉');
          [params.get('text'), params.get('emoji')];
        ''');
        expect(result, equals(['你好世界', '😀🎉']));
      });

      test('parses query string with leading ?', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('?foo=1&bar=2');
          params.toString();
        ''');
        expect(result, equals('foo=1&bar=2'));
      });

      test('handles empty values', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('key1=&key2=value');
          [params.get('key1'), params.get('key2')];
        ''');
        expect(result, equals(['', 'value']));
      });

      test('returns null for non-existent key', () {
        final result = runtime.eval('''
          const params = new URLSearchParams('foo=1');
          params.get('bar');
        ''');
        expect(result, isNull);
      });
    });

    group('URL with searchParams', () {
      test('URL has searchParams property', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com?foo=1&bar=2');
          url.searchParams.toString();
        ''');
        expect(result, equals('foo=1&bar=2'));
      });

      test('modifying searchParams updates search', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com');
          url.searchParams.append('key', 'value');
          url.search;
        ''');
        expect(result, equals('?key=value'));
      });

      test('setting search updates searchParams', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com');
          url.search = '?new=param';
          url.searchParams.get('new');
        ''');
        expect(result, equals('param'));
      });

      test('searchParams changes reflect in href', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com/path');
          url.searchParams.append('q', 'search');
          url.searchParams.append('page', '1');
          url.href;
        ''');
        expect(result, equals('https://example.com/path?q=search&page=1'));
      });

      test('deleting from searchParams updates URL', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com?foo=1&bar=2');
          url.searchParams.delete('foo');
          url.href;
        ''');
        expect(result, equals('https://example.com/?bar=2'));
      });

      test('sorting searchParams updates URL', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com?z=1&a=2');
          url.searchParams.sort();
          url.href;
        ''');
        expect(result, equals('https://example.com/?a=2&z=1'));
      });
    });

    group('integration', () {
      test('can build API URLs', () {
        final result = runtime.eval('''
          const url = new URL('https://api.example.com/search');
          url.searchParams.set('q', 'javascript');
          url.searchParams.set('page', '1');
          url.searchParams.set('limit', '10');
          url.href;
        ''');
        expect(
          result,
          equals('https://api.example.com/search?q=javascript&page=1&limit=10'),
        );
      });

      test('can validate URLs', () {
        final result = runtime.eval('''
          (function() {
            function isValid(str) {
              try {
                new URL(str);
                return true;
              } catch (e) {
                return false;
              }
            }
            return [
              isValid('https://example.com'),
              isValid('not a url'),
              isValid('http://localhost:3000')
            ];
          })();
        ''');
        expect(result, equals([true, false, true]));
      });

      test('can parse and modify complex URLs', () {
        final result = runtime.eval('''
          const url = new URL('https://user:pass@example.com:8080/path?old=param#hash');
          url.hostname = 'newdomain.com';
          url.port = '9000';
          url.pathname = '/newpath';
          url.searchParams.delete('old');
          url.searchParams.append('new', 'value');
          url.hash = '#newsection';
          url.href;
        ''');
        expect(
          result,
          equals(
            'https://user:pass@newdomain.com:9000/newpath?new=value#newsection',
          ),
        );
      });

      test('handles multiple parameters with same name', () {
        final result = runtime.eval('''
          const url = new URL('https://example.com');
          url.searchParams.append('tag', 'javascript');
          url.searchParams.append('tag', 'dart');
          url.searchParams.append('tag', 'flutter');
          [url.href, url.searchParams.getAll('tag')];
        ''');
        expect(
          result[0],
          equals('https://example.com/?tag=javascript&tag=dart&tag=flutter'),
        );
        expect(result[1], equals(['javascript', 'dart', 'flutter']));
      });
    });
  });
}
