// Example demonstrating Dart <-> JavaScript bidirectional communication
// using evalAsync and FetchPolyfill.

import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  // Create runtime with fetch and console enabled
  final runtime = JsRuntime(
    config: JsRuntimeConfig(enableFetch: true, enableConsole: true),
  );

  try {
    // ============================================================
    // Example 1: Basic Bridge Usage with evalAsync
    // ============================================================
    print('=== Example 1: Basic JsBridge Usage ===\n');

    // Register a Dart handler that can be called from JavaScript
    runtime.bridge!.registerHandler('math', (method, args) {
      switch (method) {
        case 'add':
          return (args[0] as num) + (args[1] as num);
        case 'multiply':
          return (args[0] as num) * (args[1] as num);
        case 'factorial':
          int n = args[0] as int;
          int result = 1;
          for (int i = 2; i <= n; i++) {
            result *= i;
          }
          return result;
        default:
          throw Exception('Unknown method: $method');
      }
    });

    // Use evalAsync to call Dart functions from JavaScript
    final addResult = await runtime.evalAsync('''
      return await __dart_bridge__.call('math', 'add', [10, 20]);
    ''');
    print('add(10, 20) = $addResult');

    final multiplyResult = await runtime.evalAsync('''
      return await __dart_bridge__.call('math', 'multiply', [5, 6]);
    ''');
    print('multiply(5, 6) = $multiplyResult');

    final factorialResult = await runtime.evalAsync('''
      return await __dart_bridge__.call('math', 'factorial', [5]);
    ''');
    print('factorial(5) = $factorialResult');

    // ============================================================
    // Example 2: Async Calls from JavaScript to Dart
    // ============================================================
    print('\n=== Example 2: Async Calls (JS -> Dart) ===\n');

    // Register an async handler
    runtime.bridge!.registerHandler('async', (method, args) async {
      switch (method) {
        case 'compute':
          // Simulate async computation
          await Future.delayed(Duration(milliseconds: 100));
          return (args[0] as num) * 2;
        default:
          throw Exception('Unknown method: $method');
      }
    });

    final asyncResult = await runtime.evalAsync('''
      return await __dart_bridge__.call('async', 'compute', [42]);
    ''');
    print('Async compute(42) result: $asyncResult');

    // ============================================================
    // Example 3: Fetch API with evalAsync
    // ============================================================
    print('\n=== Example 3: Fetch API with evalAsync ===\n');

    // Simple GET request using evalAsync
    final todoResult = await runtime.evalAsync('''
      const response = await fetch('https://jsonplaceholder.typicode.com/todos/1');
      return await response.json();
    ''');

    print('Fetch result:');
    print('  userId: ${todoResult['userId']}');
    print('  id: ${todoResult['id']}');
    print('  title: ${todoResult['title']}');
    print('  completed: ${todoResult['completed']}');

    // ============================================================
    // Example 4: POST Request with Custom Headers
    // ============================================================
    print('\n=== Example 4: POST Request with Custom Headers ===\n');

    final postResult = await runtime.evalAsync('''
      const response = await fetch('https://jsonplaceholder.typicode.com/posts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Custom-Header': 'custom-value'
        },
        body: JSON.stringify({
          title: 'Test Post',
          body: 'This is a test post from Dart QuickJS',
          userId: 1
        })
      });
      return await response.json();
    ''');

    print('POST result:');
    print('  id: ${postResult['id']}');
    print('  title: ${postResult['title']}');
    print('  body: ${postResult['body']}');
    print('  userId: ${postResult['userId']}');

    // ============================================================
    // Example 5: Multiple Parallel Requests
    // ============================================================
    print('\n=== Example 5: Multiple Parallel Requests ===\n');

    final parallelResults = await runtime.evalAsync('''
      const [post1, post2, post3] = await Promise.all([
        fetch('https://jsonplaceholder.typicode.com/posts/1').then(r => r.json()),
        fetch('https://jsonplaceholder.typicode.com/posts/2').then(r => r.json()),
        fetch('https://jsonplaceholder.typicode.com/posts/3').then(r => r.json())
      ]);
      return { post1, post2, post3 };
    ''');

    print('Parallel fetch results:');
    print('  Post 1: ${parallelResults['post1']['title']}');
    print('  Post 2: ${parallelResults['post2']['title']}');
    print('  Post 3: ${parallelResults['post3']['title']}');

    // ============================================================
    // Example 6: Console Output
    // ============================================================
    print('\n=== Example 6: Console Output ===\n');

    await runtime.evalAsync('''
      console.log('Logging from JavaScript');
      console.info('Info message');
      console.warn('Warning message');
      console.error('Error message');
      console.log('Object:', { name: 'Test', value: 123 });
    ''');

    print('Console logs captured:');
    for (final log in runtime.consoleLogs) {
      print('  [${log.level}] ${log.message}');
    }

    // ============================================================
    // Example 7: Error Handling with evalAsync
    // ============================================================
    print('\n=== Example 7: Error Handling ===\n');

    // Register a handler that throws errors
    runtime.bridge!.registerHandler('errorTest', (method, args) {
      if (method == 'throwError') {
        throw Exception('This is a test error from Dart');
      }
      return 'OK';
    });

    try {
      await runtime.evalAsync('''
        return await __dart_bridge__.call('errorTest', 'throwError', []);
      ''');
    } catch (e) {
      print('Error caught: $e');
    }

    // JavaScript error handling
    try {
      await runtime.evalAsync('''
        throw new Error('This is a JavaScript error');
      ''');
    } catch (e) {
      print('JavaScript error caught: $e');
    }

    // ============================================================
    // Example 8: Complex Async Workflow
    // ============================================================
    print('\n=== Example 8: Complex Async Workflow ===\n');

    // Define async functions in JavaScript and call them
    runtime.eval('''
      globalThis.api = {
        async getUser(id) {
          const response = await fetch('https://jsonplaceholder.typicode.com/users/' + id);
          return await response.json();
        },
        async getUserPosts(userId) {
          const response = await fetch('https://jsonplaceholder.typicode.com/posts?userId=' + userId);
          return await response.json();
        },
        async getUserWithPosts(id) {
          const user = await this.getUser(id);
          const posts = await this.getUserPosts(id);
          return { user, postCount: posts.length, firstPost: posts[0]?.title };
        }
      };
    ''');

    final userWithPosts = await runtime.evalAsync('''
      return await api.getUserWithPosts(1);
    ''');

    print('User with posts:');
    print('  Name: ${userWithPosts['user']['name']}');
    print('  Email: ${userWithPosts['user']['email']}');
    print('  Post count: ${userWithPosts['postCount']}');
    print('  First post: ${userWithPosts['firstPost']}');

    print('\n=== All Examples Completed ===');
  } finally {
    runtime.dispose();
  }
}
