# dart_quickjs

` ⚠ 此项目的代码由AI生成 `

QuickJS-ng JavaScript 引擎的 Dart/Flutter 绑定。

使用 Dart 的 [Hooks](https://dart.dev/tools/hooks) 系统（原 native-assets）进行原生代码编译，支持所有平台：

- **Dart**: Linux, Windows, macOS
- **Flutter**: Android, iOS, Linux, Windows, macOS

## 特性

- 🚀 高性能 JavaScript 执行引擎
- 📦 自动编译原生代码，无需手动配置
- 🔄 Dart 和 JavaScript 之间的值自动转换
- ⚡ 支持 ES2023 语法
- 🧹 自动内存管理和垃圾回收
- 🔒 异常处理和错误信息
- 🌐 内置 Fetch API 支持
- 🔗 Dart <-> JavaScript 双向通信桥
- ⏳ 简化的异步执行 (`evalAsync`)
- ⏱️ Timer API (setTimeout/setInterval)
- 📝 Console 日志捕获

## 快速开始

### 环境要求

- Dart SDK >= 3.10.0
- C 编译器 (GCC, Clang, 或 MSVC)

### 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  dart_quickjs: ^1.0.0
```

## 使用示例

### 基本用法

```dart
import 'package:dart_quickjs/dart_quickjs.dart';

void main() {
  // 创建 JavaScript 运行时
  final runtime = JsRuntime();

  try {
    // 执行简单表达式
    final result = runtime.eval('1 + 2');
    print(result); // 3

    // 执行字符串操作
    print(runtime.eval('"Hello, " + "World!"')); // Hello, World!

    // 使用 Math 对象
    print(runtime.eval('Math.sqrt(16)')); // 4.0
  } finally {
    // 释放资源
    runtime.dispose();
  }
}
```

### 异步执行 JavaScript (evalAsync)

`evalAsync` 方法简化了异步 JavaScript 代码的执行，自动处理 Promise 和 fetch 请求：

```dart
import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  // 使用配置创建运行时，自动启用 fetch polyfill
  final runtime = JsRuntime(
    config: JsRuntimeConfig(
      enableFetch: true,
      enableConsole: true,
    ),
  );

  try {
    // 简单的异步代码
    final result = await runtime.evalAsync('''
      const response = await fetch('https://jsonplaceholder.typicode.com/todos/1');
      return await response.json();
    ''');
    print('Todo: ${result['title']}');

    // POST 请求
    final postResult = await runtime.evalAsync('''
      const response = await fetch('https://jsonplaceholder.typicode.com/posts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: 'Hello', body: 'World', userId: 1 })
      });
      return await response.json();
    ''');
    print('Created post ID: ${postResult['id']}');

    // 错误处理
    try {
      await runtime.evalAsync('''
        throw new Error('Something went wrong');
      ''');
    } catch (e) {
      print('Caught error: $e');
    }
  } finally {
    runtime.dispose();
  }
}
```

### 调用 JavaScript 函数

```dart
final runtime = JsRuntime();

// 创建可调用的函数
final add = runtime.evalFunction('((a, b) => a + b)');

print(add.call([1, 2]));  // 3
print(add.call([10, 20])); // 30

add.dispose();
runtime.dispose();
```

### 使用全局变量

```dart
final runtime = JsRuntime();

// 设置全局变量
runtime.setGlobal('myValue', 100);
runtime.setGlobal('myArray', [1, 2, 3]);
runtime.setGlobal('myObject', {'name': 'Dart', 'version': 3});

// 在 JavaScript 中使用
print(runtime.eval('myValue * 2'));  // 200
print(runtime.eval('myArray.map(x => x * 2)'));  // [2, 4, 6]
print(runtime.eval('myObject.name'));  // Dart

// 获取全局变量
print(runtime.getGlobal('myValue'));  // 100

runtime.dispose();
```

### 处理数组和对象

```dart
final runtime = JsRuntime();

// JavaScript 数组自动转换为 Dart List
final arr = runtime.eval('[1, 2, 3, 4, 5]');
print(arr); // [1, 2, 3, 4, 5]

// JavaScript 对象自动转换为 Dart Map
final obj = runtime.eval('({name: "John", age: 30})');
print(obj); // {name: John, age: 30}

runtime.dispose();
```

### 错误处理

```dart
final runtime = JsRuntime();

try {
  runtime.eval('throw new Error("Something went wrong")');
} on JsException catch (e) {
  print('JavaScript 错误: ${e.message}');
  if (e.stack != null) {
    print('堆栈跟踪:\n${e.stack}');
  }
}

runtime.dispose();
```

## 类型转换

| JavaScript 类型 | Dart 类型 |
|----------------|-----------|
| number (整数) | int |
| number (浮点) | double |
| string | String |
| boolean | bool |
| null/undefined | null |
| Array | List |
| Object | Map<String, dynamic> |
| Function | JsFunction |
| BigInt | BigInt |

## 高级用法

### 运行时配置 (JsRuntimeConfig)

`JsRuntimeConfig` 用于配置运行时的 polyfill 和功能：

```dart
final runtime = JsRuntime(
  memoryLimit: 32 * 1024 * 1024,  // 内存限制
  maxStackSize: 256 * 1024,        // 栈大小
  config: JsRuntimeConfig(
    enableFetch: true,    // 启用 fetch API
    enableConsole: true,  // 启用 console 日志捕获
    enableTimer: true,    // 启用 setTimeout/setInterval
    httpClient: myClient, // 可选：自定义 HTTP 客户端
  ),
);
```

配置选项：
- `enableFetch`: 启用 JavaScript `fetch()` API
- `enableConsole`: 启用 `console.log/warn/error/info/debug` 捕获
- `enableTimer`: 启用 `setTimeout`/`setInterval`/`clearTimeout`/`clearInterval`
- `httpClient`: 提供自定义 `http.Client` 用于 fetch 请求

### Console 日志捕获

当启用 `enableConsole` 时，可以捕获 JavaScript 的 console 输出：

```dart
final runtime = JsRuntime(
  config: JsRuntimeConfig(enableConsole: true),
);

runtime.eval('''
  console.log('Hello from JavaScript!');
  console.warn('This is a warning');
  console.error('This is an error');
  console.log('Object:', { name: 'Test', value: 42 });
''');

// 获取所有日志
for (final log in runtime.consoleLogs) {
  print('[${log.level}] ${log.message}');
}
// 输出:
// [log] Hello from JavaScript!
// [warn] This is a warning
// [error] This is an error
// [log] Object: {"name":"Test","value":42}

// 清除日志
runtime.clearConsoleLogs();

runtime.dispose();
```

#### 实时日志监听

使用 `onConsoleLog` 流可以实时监听 JavaScript 的 console 输出：

```dart
final runtime = JsRuntime(
  config: JsRuntimeConfig(enableConsole: true),
);

// 监听实时日志输出
runtime.onConsoleLog.listen((log) {
  print('[${log.timestamp}] [${log.level}] ${log.message}');
});

// JavaScript 代码执行时，日志会实时输出
runtime.eval('''
  console.log('This will be logged immediately');
  console.error('Errors are also captured in real-time');
''');

// 异步代码的日志也会被捕获（需要手动 sync）
runtime.eval('''
  Promise.resolve().then(() => {
    console.log('Async log');
  });
''');

// 执行 Promise 任务后，同步日志
runtime.executePendingJobs();

runtime.dispose();
```

注意：
- `onConsoleLog` 流在每次调用 `eval()` 或 `consoleLogs` getter 时自动同步日志
- 对于异步代码（Promise），需要在 `executePendingJobs()` 后访问 `consoleLogs` 或手动调用同步
- 使用 `evalAsync()` 会自动处理日志同步

### Timer API (setTimeout/setInterval)

当启用 `enableTimer` 时，可以使用 JavaScript 标准的定时器 API：

```dart
final runtime = JsRuntime(
  config: JsRuntimeConfig(enableTimer: true),
);

// 基本 setTimeout - 使用 evalAsync 自动处理异步
await runtime.evalAsync('''
  return new Promise((resolve) => {
    setTimeout(() => {
      console.log('Timeout fired!');
      resolve('done');
    }, 100);
  });
''');

// setInterval 示例
await runtime.evalAsync('''
  return new Promise((resolve) => {
    let count = 0;
    const id = setInterval(() => {
      count++;
      console.log('Tick:', count);
      if (count >= 3) {
        clearInterval(id);
        resolve(count);
      }
    }, 50);
  });
''');

// clearTimeout 取消定时器
await runtime.evalAsync('''
  const id = setTimeout(() => {
    console.log('This will not be called');
  }, 1000);
  clearTimeout(id);
  return 'Timer cancelled';
''');

// 延时辅助函数
runtime.eval('''
  globalThis.delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));
''');

await runtime.evalAsync('''
  console.log('Step 1');
  await delay(50);
  console.log('Step 2');
  await delay(50);
  console.log('Step 3');
  return 'All steps completed';
''');

runtime.dispose();
```

支持的 Timer API：
- ✅ `setTimeout(callback, delay)` - 延迟执行
- ✅ `setInterval(callback, delay)` - 周期执行
- ✅ `clearTimeout(id)` - 取消延迟执行
- ✅ `clearInterval(id)` - 取消周期执行

### Dart <-> JavaScript 双向通信 (JsBridge)

JsBridge 提供了一个通用的 Dart 与 JavaScript 双向通信机制。配合 `evalAsync` 使用更加简洁：

```dart
import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  // 使用配置创建运行时，自动启用 fetch 和 console
  final runtime = JsRuntime(
    config: JsRuntimeConfig(
      enableFetch: true,
      enableConsole: true,
    ),
  );

  // 注册 Dart 处理器，可以从 JavaScript 调用
  runtime.bridge!.registerHandler('math', (method, args) {
    switch (method) {
      case 'add':
        return (args[0] as num) + (args[1] as num);
      case 'multiply':
        return (args[0] as num) * (args[1] as num);
      default:
        throw Exception('Unknown method: $method');
    }
  });

  // 使用 evalAsync 调用 Dart 函数（自动处理 Promise）
  final result = await runtime.evalAsync('''
    return await __dart_bridge__.call('math', 'add', [10, 20]);
  ''');
  print(result); // 30

  // 注册异步处理器
  runtime.bridge!.registerHandler('async', (method, args) async {
    if (method == 'compute') {
      await Future.delayed(Duration(milliseconds: 100));
      return (args[0] as num) * 2;
    }
    throw Exception('Unknown method');
  });

  // 调用异步处理器
  final asyncResult = await runtime.evalAsync('''
    return await __dart_bridge__.call('async', 'compute', [42]);
  ''');
  print(asyncResult); // 84

  runtime.dispose();
}
```

### Fetch API 支持

使用 `evalAsync` 配合 Fetch API 非常简洁：

```dart
import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  // 启用 fetch polyfill
  final runtime = JsRuntime(
    config: JsRuntimeConfig(enableFetch: true),
  );

  // GET 请求 - 使用 evalAsync 自动处理异步
  final data = await runtime.evalAsync('''
    const response = await fetch('https://jsonplaceholder.typicode.com/todos/1');
    return await response.json();
  ''');
  print('Todo: ${data['title']}');

  // POST 请求
  final postResult = await runtime.evalAsync('''
    const response = await fetch('https://jsonplaceholder.typicode.com/posts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title: 'Hello', body: 'World', userId: 1 })
    });
    return await response.json();
  ''');
  print('Created post ID: ${postResult['id']}');

  // 并行请求
  final results = await runtime.evalAsync('''
    const [post1, post2] = await Promise.all([
      fetch('https://jsonplaceholder.typicode.com/posts/1').then(r => r.json()),
      fetch('https://jsonplaceholder.typicode.com/posts/2').then(r => r.json())
    ]);
    return { post1, post2 };
  ''');
  print('Post 1: ${results['post1']['title']}');
  print('Post 2: ${results['post2']['title']}');

  runtime.dispose();
}
```

支持的 Fetch 功能：
- ✅ GET, POST, PUT, DELETE, PATCH, HEAD 方法
- ✅ 自定义请求头
- ✅ JSON/文本请求体
- ✅ Response 对象 (status, ok, headers, json(), text())
- ✅ Headers 类
- ✅ AbortController (基础支持)
- ✅ 超时设置

### 内存限制

```dart
// 限制 JavaScript 堆内存为 32MB
final runtime = JsRuntime(memoryLimit: 32 * 1024 * 1024);
```

### 手动垃圾回收

```dart
final runtime = JsRuntime();

// 执行一些操作...

// 手动触发垃圾回收
runtime.runGC();

runtime.dispose();
```

### 执行异步任务

使用 `evalAsync` 简化异步代码执行：

```dart
final runtime = JsRuntime(
  config: JsRuntimeConfig(enableFetch: true),
);

// evalAsync 自动处理 Promise，直接返回结果
final result = await runtime.evalAsync('''
  return await Promise.resolve(42);
''');
print(result); // 42

// 复杂的异步工作流
runtime.eval('''
  globalThis.api = {
    async getUser(id) {
      const response = await fetch('https://jsonplaceholder.typicode.com/users/' + id);
      return await response.json();
    }
  };
''');

final user = await runtime.evalAsync('''
  return await api.getUser(1);
''');
print('User: ${user['name']}'); // User: Leanne Graham

runtime.dispose();
```

如果需要手动处理 Promise，仍然可以使用传统方式：

```dart
final runtime = JsRuntime();

runtime.eval('''
  Promise.resolve().then(() => {
    globalThis.result = 42;
  });
''');

// 手动执行待处理的 Promise 任务
runtime.executePendingJobs();

print(runtime.getGlobal('result')); // 42

runtime.dispose();
```

## 构建原理

本包使用 Dart 3.10+ 的 [Hooks](https://dart.dev/tools/hooks) 系统自动编译 QuickJS-ng 源代码。

在运行 `dart run` 或 `flutter run` 时：
1. Dart/Flutter 工具链自动检测 `hook/build.dart`
2. 使用 `native_toolchain_c` 编译 QuickJS-ng C 代码
3. 生成平台特定的动态库
4. 自动链接到 Dart 应用程序

不需要手动编译或下载预编译库！

## 示例

### Dart 示例

```bash
cd example
dart run dart_quickjs_example.dart
```

### Flutter 示例

一个完整的 JavaScript Playground 应用，展示如何在 Flutter 中使用 QuickJS：

```bash
cd example_flutter
flutter run
```

特性：
- 交互式 JavaScript 代码编辑器
- 实时执行 JavaScript 代码
- 输出显示面板
- 重置运行时功能
- 完整的错误处理

## 许可证

MIT License

## 致谢

- [QuickJS-ng](https://github.com/nickhurst) - 现代化的 QuickJS 分支
- [dart-lang/native](https://github.com/dart-lang/native) - Dart Native 工具链

