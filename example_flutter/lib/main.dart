import 'package:flutter/material.dart';
import 'package:dart_quickjs/dart_quickjs.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickJS Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const JavaScriptPlayground(),
    );
  }
}

class JavaScriptPlayground extends StatefulWidget {
  const JavaScriptPlayground({super.key});

  @override
  State<JavaScriptPlayground> createState() => _JavaScriptPlaygroundState();
}

class _JavaScriptPlaygroundState extends State<JavaScriptPlayground> {
  late JsRuntime _runtime;
  final _codeController = TextEditingController();
  String _output = '';
  List<String> _consoleLogs = [];
  bool _isLoading = false;
  bool _isError = false;
  bool _useAsync = false;
  final List<ExecutionResult> _history = [];

  @override
  void initState() {
    super.initState();
    _initRuntime();
    _codeController.text = '// 输入 JavaScript 代码\n1 + 2 * 3';
  }

  void _initRuntime() {
    _runtime = JsRuntime(
      memoryLimit: 4 * 1024 * 1024,
      maxStackSize: 64 * 1024,
      config: JsRuntimeConfig(
        enableFetch: true,
        enableConsole: true,
        enableTimer: true,
      ),
    );
  }

  @override
  void dispose() {
    _runtime.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _executeCode({bool async = false}) async {
    setState(() {
      _isLoading = true;
      _consoleLogs = [];
    });

    final code = _codeController.text;
    String result;
    bool isError = false;

    try {
      dynamic value;
      if (async) {
        // 使用 evalAsync 执行异步代码
        value = await _runtime.evalAsync(code);
      } else {
        value = _runtime.eval(code);
      }
      result = _formatResult(value);
    } on JsException catch (e) {
      result = e.message;
      if (e.stack != null) {
        result += '\n\nStack:\n${e.stack}';
      }
      isError = true;
    } catch (e) {
      result = 'Dart Error: $e';
      isError = true;
    }

    // 获取 console 日志
    final logs = _runtime.consoleLogs;
    final logMessages = logs
        .map((log) => '[${log.level}] ${log.message}')
        .toList();
    _runtime.clearConsoleLogs();

    setState(() {
      _output = result;
      _consoleLogs = logMessages;
      _isLoading = false;
      _isError = isError;
      _history.insert(
        0,
        ExecutionResult(
          code: code,
          result: result,
          isError: isError,
          timestamp: DateTime.now(),
          isAsync: async,
        ),
      );
    });
  }

  String _formatResult(dynamic value) {
    if (value == null) {
      return 'undefined';
    } else if (value is String) {
      return '"$value"';
    } else if (value is List) {
      return '[${value.map(_formatResult).join(', ')}]';
    } else if (value is Map) {
      final entries = value.entries
          .map((e) => '${e.key}: ${_formatResult(e.value)}')
          .join(', ');
      return '{$entries}';
    } else if (value is JsFunction) {
      return '[Function]';
    } else {
      return value.toString();
    }
  }

  void _runExample(String code, {bool async = false}) {
    _codeController.text = code;
    setState(() {
      _useAsync = async;
    });
    _executeCode(async: async);
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
      _output = '';
      _consoleLogs = [];
    });
  }

  void _resetRuntime() {
    _runtime.dispose();
    _initRuntime();
    setState(() {
      _output = 'Runtime 已重置';
      _consoleLogs = [];
      _isError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('QuickJS Playground'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置 Runtime',
            onPressed: _resetRuntime,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空历史',
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // 示例按钮
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ExampleChip(
                  label: '算术',
                  onTap: () => _runExample('1 + 2 * 3 - 4 / 2'),
                ),
                _ExampleChip(
                  label: '字符串',
                  onTap: () => _runExample('"Hello, " + "Flutter!"'),
                ),
                _ExampleChip(
                  label: '数组',
                  onTap: () => _runExample('[1, 2, 3, 4, 5].map(x => x * 2)'),
                ),
                _ExampleChip(
                  label: '对象',
                  onTap: () => _runExample(
                    '({name: "QuickJS", version: 2024, features: ["ES2023", "BigInt", "Promise"]})',
                  ),
                ),
                _ExampleChip(
                  label: 'Math',
                  onTap: () => _runExample('Math.sqrt(2) + Math.PI'),
                ),
                _ExampleChip(
                  label: 'Fibonacci',
                  onTap: () => _runExample('''
(function fib(n) {
  if (n <= 1) return n;
  let a = 0, b = 1;
  for (let i = 2; i <= n; i++) {
    [a, b] = [b, a + b];
  }
  return b;
})(20)'''),
                ),
                _ExampleChip(
                  label: 'JSON',
                  onTap: () => _runExample(
                    'JSON.stringify({hello: "world", number: 42}, null, 2)',
                  ),
                ),
                _ExampleChip(
                  label: 'Console',
                  onTap: () => _runExample('''
// Console 日志示例
console.log('Hello from JavaScript!');
console.warn('这是一个警告');
console.error('这是一个错误');
console.info('对象:', { name: 'Test', value: 42 });
console.debug('数组:', [1, 2, 3]);
'console 日志已输出';'''),
                ),
                _ExampleChip(
                  label: 'Promise',
                  onTap: () => _runExample('''
// Promise 异步示例 (使用 evalAsync)
const result = await Promise.resolve(42)
  .then(v => v * 2)
  .then(v => "计算结果: " + v);
return result;''', async: true),
                ),
                _ExampleChip(
                  label: 'setTimeout',
                  onTap: () => _runExample('''
// setTimeout 示例
console.log('开始计时...');
return new Promise((resolve) => {
  setTimeout(() => {
    console.log('100ms 后执行');
    resolve('定时器完成!');
  }, 100);
});''', async: true),
                ),
                _ExampleChip(
                  label: 'setInterval',
                  onTap: () => _runExample('''
// setInterval 示例
return new Promise((resolve) => {
  let count = 0;
  const id = setInterval(() => {
    count++;
    console.log('Tick: ' + count);
    if (count >= 3) {
      clearInterval(id);
      resolve('间隔执行 ' + count + ' 次');
    }
  }, 50);
});''', async: true),
                ),
                _ExampleChip(
                  label: 'Delay',
                  onTap: () => _runExample('''
// 延时辅助函数
const delay = (ms) => new Promise(r => setTimeout(r, ms));

console.log('Step 1: 开始');
await delay(50);
console.log('Step 2: 50ms 后');
await delay(50);
console.log('Step 3: 又 50ms 后');
return '全部步骤完成!';''', async: true),
                ),
                _ExampleChip(
                  label: 'Fetch GET',
                  onTap: () => _runExample('''
// Fetch API GET 请求
const response = await fetch('https://jsonplaceholder.typicode.com/todos/1');
const data = await response.json();
console.log('状态:', response.status);
console.log('标题:', data.title);
return data;''', async: true),
                ),
                _ExampleChip(
                  label: 'Fetch POST',
                  onTap: () => _runExample('''
// Fetch API POST 请求
const response = await fetch('https://jsonplaceholder.typicode.com/posts', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    title: 'Hello from Flutter',
    body: 'QuickJS + Fetch API',
    userId: 1
  })
});
const result = await response.json();
console.log('创建成功, ID:', result.id);
return result;''', async: true),
                ),
                _ExampleChip(
                  label: 'Fetch 并行',
                  onTap: () => _runExample('''
// 并行请求示例
console.log('开始并行请求...');
const [user, post] = await Promise.all([
  fetch('https://jsonplaceholder.typicode.com/users/1').then(r => r.json()),
  fetch('https://jsonplaceholder.typicode.com/posts/1').then(r => r.json())
]);
console.log('用户:', user.name);
console.log('文章:', post.title);
return { user: user.name, postTitle: post.title };''', async: true),
                ),
                _ExampleChip(
                  label: 'Async Chain',
                  onTap: () => _runExample('''
// 异步链式调用
const steps = [];

const result = await Promise.resolve(10)
  .then(v => { steps.push('步骤1: ' + v); return v * 2; })
  .then(v => { steps.push('步骤2: ' + v); return v + 5; })
  .then(v => { steps.push('步骤3: ' + v); return v; });

steps.forEach(s => console.log(s));
return { steps, finalResult: result };''', async: true),
                ),
                _ExampleChip(
                  label: 'Error',
                  onTap: () =>
                      _runExample('throw new Error("Test error message")'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 代码输入区
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _codeController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(
                  hintText: '输入 JavaScript 代码...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),

          // 执行按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // 异步模式切换
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: _useAsync
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Async',
                        style: TextStyle(
                          fontSize: 12,
                          color: _useAsync
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                      Switch(
                        value: _useAsync,
                        onChanged: (value) {
                          setState(() {
                            _useAsync = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _executeCode(async: _useAsync),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_useAsync ? Icons.schedule : Icons.play_arrow),
                    label: Text(
                      _isLoading
                          ? '执行中...'
                          : _useAsync
                          ? '异步执行'
                          : '执行代码',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // 输出区
          Expanded(
            flex: 3,
            child: _output.isEmpty && _history.isEmpty && _consoleLogs.isEmpty
                ? const Center(
                    child: Text(
                      '点击"执行代码"运行 JavaScript',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      // Console 日志卡片
                      if (_consoleLogs.isNotEmpty) ...[
                        Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.terminal,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Console',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_consoleLogs.length} 条日志',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                ..._consoleLogs.map(
                                  (log) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: SelectableText(
                                      log,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        color: log.contains('[error]')
                                            ? Colors.red.shade700
                                            : log.contains('[warn]')
                                            ? Colors.orange.shade700
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // 结果卡片
                      if (_output.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _isError
                                          ? Icons.error
                                          : Icons.check_circle,
                                      color: _isError
                                          ? Colors.red
                                          : Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isError ? '错误' : '结果',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  _output,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    color: _isError
                                        ? Colors.red.shade700
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_history.isNotEmpty) ...[
                        Text(
                          '执行历史',
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        ..._history
                            .skip(1)
                            .take(10)
                            .map(
                              (item) => _HistoryItem(
                                result: item,
                                onTap: () {
                                  _codeController.text = item.code;
                                },
                              ),
                            ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class ExecutionResult {
  final String code;
  final String result;
  final bool isError;
  final DateTime timestamp;
  final bool isAsync;

  ExecutionResult({
    required this.code,
    required this.result,
    required this.isError,
    required this.timestamp,
    this.isAsync = false,
  });
}

class _ExampleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExampleChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _HistoryItem extends StatelessWidget {
  final ExecutionResult result;
  final VoidCallback onTap;

  const _HistoryItem({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final code = result.code.length > 50
        ? '${result.code.substring(0, 50)}...'
        : result.code;
    final output = result.result.length > 30
        ? '${result.result.substring(0, 30)}...'
        : result.result;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                result.isError
                    ? Icons.error_outline
                    : result.isAsync
                    ? Icons.schedule
                    : Icons.code,
                size: 20,
                color: result.isError
                    ? Colors.red
                    : result.isAsync
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (result.isAsync)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'async',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            code.replaceAll('\n', ' '),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '→ $output',
                      style: TextStyle(
                        fontSize: 12,
                        color: result.isError
                            ? Colors.red
                            : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                _formatTime(result.timestamp),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
