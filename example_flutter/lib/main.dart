import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dart_quickjs/dart_quickjs.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/javascript.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickJS Playground',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade400,
          secondary: Colors.tealAccent.shade400,
          surface: const Color(0xFF1E1E1E),
          surfaceContainerHighest: const Color(0xFF2D2D30),
        ),
        textTheme: Typography().white.apply(fontFamily: '微软雅黑'),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        dividerColor: const Color(0xFF3E3E42),
      ),
      debugShowCheckedModeBanner: false,

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
  late CodeController _codeController;
  String _output = '';
  List<String> _consoleLogs = [];
  bool _isLoading = false;
  bool _isError = false;
  bool _useAsync = false;
  final List<ExecutionResult> _history = [];
  double _consoleHeight = 200;
  bool _showConsole = true;
  String? _selectedExample;
  int _consoleTabIndex = 0; // 0:输出 1:JS日志 2:执行记录
  StreamSubscription<JsConsoleLog>? _consoleLogSubscription;
  static var vsCodeDarkPlusTheme = {
    // VS Code Dark+ color mapping
    'comment': TextStyle(color: Color(0xff6a9955)), // green
    'quote': TextStyle(color: Color(0xff6a9955)),
    'variable': TextStyle(color: Color(0xff9cdcfe)), // blue
    'template-variable': TextStyle(color: Color(0xff9cdcfe)),
    'tag': TextStyle(color: Color(0xff569cd6)), // blue
    'name': TextStyle(color: Color(0xffdcdcaa)), // yellow
    'selector-id': TextStyle(color: Color(0xffd7ba7d)), // orange
    'selector-class': TextStyle(color: Color(0xffd7ba7d)),
    'regexp': TextStyle(color: Color(0xffd16969)), // red
    'deletion': TextStyle(color: Color(0xffd16969)),
    'number': TextStyle(color: Color(0xffb5cea8)), // light green
    'built_in': TextStyle(color: Color(0xff4ec9b0)), // teal
    'builtin-name': TextStyle(color: Color(0xff4ec9b0)),
    'literal': TextStyle(color: Color(0xffb5cea8)),
    'type': TextStyle(color: Color(0xff4ec9b0)),
    'params': TextStyle(color: Color(0xff9cdcfe)),
    'meta': TextStyle(color: Color(0xffd4d4d4)), // gray
    'link': TextStyle(color: Color(0xffd4d4d4)),
    'attribute': TextStyle(color: Color(0xffd7ba7d)), // orange
    'string': TextStyle(color: Color(0xffce9178)), // orange
    'symbol': TextStyle(color: Color(0xffb5cea8)),
    'bullet': TextStyle(color: Color(0xffb5cea8)),
    'addition': TextStyle(color: Color(0xffb5cea8)),
    'title': TextStyle(color: Color(0xff569cd6)), // blue
    'section': TextStyle(color: Color(0xff569cd6)),
    'keyword': TextStyle(color: Color(0xffc586c0)), // purple
    'selector-tag': TextStyle(color: Color(0xffc586c0)),
    'root': TextStyle(
      backgroundColor: Color(0xff1e1e1e), // VS Code Dark+ bg
      color: Color(0xffd4d4d4), // default fg
    ),
    'emphasis': TextStyle(fontStyle: FontStyle.italic),
    'strong': TextStyle(fontWeight: FontWeight.bold),
  };
  @override
  void initState() {
    super.initState();
    _initRuntime();
    _codeController = CodeController(
      text: '// 输入 JavaScript 代码\n// 或从左侧选择示例\n\n1 + 2 * 3',
      language: javascript,
    );
  }

  void _initRuntime() {
    _runtime = JsRuntime(
      // memoryLimit: 4 * 1024 * 1024,
      // maxStackSize: 64 * 1024,
      config: JsRuntimeConfig(
        enableFetch: true,
        enableConsole: true,
        enableTimer: true,
        enableEncoding: true,
      ),
    );

    // 订阅 console 日志,实时显示
    _consoleLogSubscription?.cancel();
    _consoleLogSubscription = _runtime.onConsoleLog.listen((log) {
      if (mounted) {
        setState(() {
          _consoleLogs.add('[${log.level}] ${log.message}');
        });
      }
    });
  }

  @override
  void dispose() {
    _consoleLogSubscription?.cancel();
    _runtime.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _executeCode({bool async = false}) async {
    setState(() {
      _isLoading = true;
      _consoleLogs = [];
      _showConsole = true;
    });

    final code = _codeController.text;
    String result;
    bool isError = false;
    final startTime = DateTime.now();

    try {
      dynamic value;
      if (async) {
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

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    setState(() {
      _output = result;
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
          duration: duration,
        ),
      );
      // 如果有输出且当前不在 JS日志 标签,切换到输出标签
      if (result.isNotEmpty && _consoleLogs.isEmpty) {
        _consoleTabIndex = 0; // 输出
      }
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

  void _runExample(String name, String code, {bool async = false}) {
    // 重置 Runtime
    _runtime.dispose();
    _initRuntime();

    _codeController.clear();
    _codeController.text = code;
    setState(() {
      _useAsync = async;
      _selectedExample = name;
      _output = '';
      _consoleLogs = [];
      _isError = false;
    });
    _executeCode(async: async);
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
      body: Column(
        children: [
          // 顶部工具栏
          _buildTopBar(),
          const Divider(height: 1),
          // 主内容区
          Expanded(
            child: Row(
              children: [
                // 左侧示例面板
                _buildSidebar(),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                // 中间编辑器和控制台
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // 代码编辑器
                      Expanded(child: _buildCodeEditor()),
                      // 控制台
                      if (_showConsole) ...[
                        GestureDetector(
                          onVerticalDragUpdate: (details) {
                            setState(() {
                              _consoleHeight =
                                  (_consoleHeight - details.delta.dy).clamp(
                                    100.0,
                                    500.0,
                                  );
                            });
                          },
                          child: Container(
                            height: 4,
                            color: Theme.of(context).dividerColor,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade600,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: _consoleHeight,
                          child: _buildConsole(),
                        ),
                      ],
                    ],
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                // 右侧文档面板
                _buildDocPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      color: const Color(0xFF2D2D30),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.code, color: Colors.blue, size: 24),
          const SizedBox(width: 8),
          const Text(
            'QuickJS Playground',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          // 异步模式切换
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _useAsync
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _useAsync
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: _useAsync
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Async',
                  style: TextStyle(
                    fontSize: 14,
                    color: _useAsync
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 20,
                  child: Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: _useAsync,
                      onChanged: (value) {
                        setState(() {
                          _useAsync = value;
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,

                      // 缩小开关尺寸
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 执行按钮
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _executeCode(async: _useAsync),
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 20),
            label: Text(
              _isLoading ? '执行中...' : '运行',
              style: const TextStyle(fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              minimumSize: const Size(90, 40),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '重置 Runtime',
            onPressed: _resetRuntime,
          ),
          IconButton(
            icon: Icon(
              _showConsole
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              size: 20,
            ),
            tooltip: _showConsole ? '隐藏控制台' : '显示控制台',
            onPressed: () {
              setState(() {
                _showConsole = !_showConsole;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final examples = _getExamples();

    return Container(
      width: 220,
      color: const Color(0xFF252526),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: const Text(
              '示例',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: examples.length,
              itemBuilder: (context, index) {
                final category = examples[index];
                return _ExampleCategory(
                  category: category,
                  selectedExample: _selectedExample,
                  onExampleTap: _runExample,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditor() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // 编辑器标题栏
          Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D30),
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.javascript, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('main.js', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Text(
                  'JavaScript (QuickJS)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // 代码编辑器
          Expanded(
            child: CodeTheme(
              data: CodeThemeData(styles: vsCodeDarkPlusTheme),

              child: SingleChildScrollView(
                child: CodeField(
                  controller: _codeController,
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                  ),
                  gutterStyle: const GutterStyle(
                    width: 80,
                    textStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Color(0xFF858585),
                    ),
                    margin: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsole() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // 控制台标题栏和标签页
          Container(
            height: 35,
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D30),
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                // 标签页
                Expanded(
                  child: Row(
                    children: [
                      _buildConsoleTab('输出', 0),
                      _buildConsoleTab('JS日志', 1),
                      _buildConsoleTab('执行记录', 2),
                    ],
                  ),
                ),
                // 清空按钮
                if ((_consoleTabIndex == 0 && _output.isNotEmpty) ||
                    (_consoleTabIndex == 1 && _consoleLogs.isNotEmpty) ||
                    (_consoleTabIndex == 2 && _history.isNotEmpty))
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_consoleTabIndex == 0) {
                          _output = '';
                        } else if (_consoleTabIndex == 1) {
                          _consoleLogs = [];
                        } else {
                          _history.clear();
                        }
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 14),
                    label: const Text('清空', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          // 控制台内容
          Expanded(
            child: IndexedStack(
              index: _consoleTabIndex,
              children: [
                // Tab 0: 输出
                _buildOutputTab(),
                // Tab 1: JS日志
                _buildConsoleLogsTab(),
                // Tab 2: 执行记录
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleTab(String label, int index) {
    final isSelected = _consoleTabIndex == index;
    int count = 0;

    if (index == 0 && _output.isNotEmpty) {
      count = 1;
    } else if (index == 1) {
      count = _consoleLogs.length;
    } else if (index == 2) {
      count = _history.length;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _consoleTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? Colors.white : Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutputTab() {
    if (_output.isEmpty) {
      return Center(
        child: Text(
          '执行结果将显示在这里',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _isError ? Icons.close : Icons.check,
              size: 14,
              color: _isError ? Colors.red.shade400 : Colors.green.shade400,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SelectableText(
                _output,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: _isError ? Colors.red.shade400 : Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
        if (_history.isNotEmpty && _history.first.duration != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                '执行耗时: ${_formatDuration(_history.first.duration!)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildConsoleLogsTab() {
    if (_consoleLogs.isEmpty) {
      return Center(
        child: Text(
          'JavaScript 控制台日志将显示在这里',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: _consoleLogs.map((log) {
        Color? logColor;
        IconData icon = Icons.info_outline;

        if (log.contains('[error]')) {
          logColor = Colors.red.shade400;
          icon = Icons.error_outline;
        } else if (log.contains('[warn]')) {
          logColor = Colors.orange.shade400;
          icon = Icons.warning_amber;
        } else if (log.contains('[info]')) {
          logColor = Colors.blue.shade400;
          icon = Icons.info_outline;
        } else if (log.contains('[debug]')) {
          logColor = Colors.purple.shade400;
          icon = Icons.bug_report;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: logColor),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(
                  log,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: logColor ?? Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Text(
          '执行历史记录将显示在这里',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final preview = item.code.length > 80
            ? '${item.code.substring(0, 80)}...'
            : item.code;
        final resultPreview = item.result.length > 100
            ? '${item.result.substring(0, 100)}...'
            : item.result;

        return InkWell(
          onTap: () {
            _codeController.text = item.code;
            setState(() {
              _useAsync = item.isAsync;
              _consoleTabIndex = 0;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF252526),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: item.isError
                    ? Colors.red.shade900.withValues(alpha: 0.3)
                    : Colors.grey.shade800,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部信息
                Row(
                  children: [
                    Icon(
                      item.isError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 14,
                      color: item.isError ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(item.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (item.duration != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(item.duration!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    if (item.isAsync) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: Colors.blue.shade700,
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'async',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.replay, size: 14, color: Colors.grey.shade600),
                  ],
                ),
                const SizedBox(height: 8),
                // 代码预览
                Text(
                  preview.replaceAll('\n', ' '),
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade300,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // 结果预览
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          resultPreview.replaceAll('\n', ' '),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: item.isError
                                ? Colors.red.shade400
                                : Colors.grey.shade400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocPanel() {
    return Container(
      width: 280,
      color: const Color(0xFF252526),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: const Text(
              '文档',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildDocSection(
                  '关于 QuickJS',
                  'QuickJS 是一个小型且可嵌入的 JavaScript 引擎,支持 ES2023 规范。',
                ),
                const SizedBox(height: 16),
                _buildDocSection(
                  '支持的特性',
                  '• ES2023 语法\n'
                      '• Promise 和 async/await\n'
                      '• 定时器 (setTimeout/setInterval)\n'
                      '• Fetch API (网络请求)\n'
                      '• Console API (日志输出)',
                ),
                const SizedBox(height: 16),
                _buildDocSection(
                  '执行模式',
                  '• 同步模式: 直接执行代码并返回结果\n'
                      '• 异步模式: 支持 await 和 Promise,适合异步操作',
                ),
                const SizedBox(height: 16),
                _buildDocSection(
                  'Console API',
                  'console.log() - 普通日志\n'
                      'console.info() - 信息日志\n'
                      'console.warn() - 警告日志\n'
                      'console.error() - 错误日志\n'
                      'console.debug() - 调试日志',
                ),
                const SizedBox(height: 16),
                _buildDocSection(
                  '快捷键',
                  '运行代码: 点击顶部运行按钮\n'
                      '切换异步模式: 使用 Async 开关\n'
                      '重置环境: 点击刷新按钮',
                ),
                const SizedBox(height: 16),
                _buildDocSection(
                  '提示',
                  '• 点击左侧示例快速加载代码\n'
                      '• 控制台分为输出/JS日志/执行记录三个标签\n'
                      '• 执行记录可点击恢复代码',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade400,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds >= 1000) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
    } else {
      return '${duration.inMilliseconds}ms';
    }
  }

  List<ExampleCategory> _getExamples() {
    return [
      ExampleCategory(
        name: '基础',
        icon: Icons.functions,
        examples: [
          Example('算术运算', '1 + 2 * 3 - 4 / 2'),
          Example('字符串', '"Hello, " + "Flutter!"'),
          Example('数组操作', '[1, 2, 3, 4, 5].map(x => x * 2)'),
          Example(
            '对象',
            '({name: "QuickJS", version: 2024, features: ["ES2023", "BigInt", "Promise"]})',
          ),
          Example('Math', 'Math.sqrt(2) + Math.PI'),
        ],
      ),
      ExampleCategory(
        name: '算法',
        icon: Icons.code,
        examples: [
          Example('Fibonacci', '''(function fib(n) {
  if (n <= 1) return n;
  let a = 0, b = 1;
  for (let i = 2; i <= n; i++) {
    [a, b] = [b, a + b];
  }
  return b;
})(20)'''),
          Example(
            'JSON',
            'JSON.stringify({hello: "world", number: 42}, null, 2)',
          ),
        ],
      ),
      ExampleCategory(
        name: 'Console',
        icon: Icons.terminal,
        examples: [
          Example('日志输出', '''console.log('Hello from JavaScript!');
console.warn('这是一个警告');
console.error('这是一个错误');
console.info('对象:', { name: 'Test', value: 42 });
console.debug('数组:', [1, 2, 3]);
'console 日志已输出';'''),
        ],
      ),
      ExampleCategory(
        name: '异步操作',
        icon: Icons.schedule,
        examples: [
          Example('Promise', '''const result = await Promise.resolve(42)
  .then(v => v * 2)
  .then(v => "计算结果: " + v);
return result;''', isAsync: true),
          Example('setTimeout', '''console.log('开始计时...');
return new Promise((resolve) => {
  setTimeout(() => {
    console.log('100ms 后执行');
    resolve('定时器完成!');
  }, 100);
});''', isAsync: true),
          Example('setInterval', '''return new Promise((resolve) => {
  let count = 0;
  const id = setInterval(() => {
    count++;
    console.log('Tick: ' + count);
    if (count >= 3) {
      clearInterval(id);
      resolve('间隔执行 ' + count + ' 次');
    }
  }, 50);
});''', isAsync: true),
          Example(
            'Delay',
            '''const delay = (ms) => new Promise(r => setTimeout(r, ms));

console.log('Step 1: 开始');
await delay(50);
console.log('Step 2: 50ms 后');
await delay(50);
console.log('Step 3: 又 50ms 后');
return '全部步骤完成!';''',
            isAsync: true,
          ),
        ],
      ),
      ExampleCategory(
        name: 'Fetch API',
        icon: Icons.cloud,
        examples: [
          Example(
            'GET 请求',
            '''const response = await fetch('https://jsonplaceholder.typicode.com/todos/1');
const data = await response.json();
console.log('状态:', response.status);
console.log('标题:', data.title);
return data;''',
            isAsync: true,
          ),
          Example(
            'POST 请求',
            '''const response = await fetch('https://jsonplaceholder.typicode.com/posts', {
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
return result;''',
            isAsync: true,
          ),
          Example('并行请求', '''console.log('开始并行请求...');
const [user, post] = await Promise.all([
  fetch('https://jsonplaceholder.typicode.com/users/1').then(r => r.json()),
  fetch('https://jsonplaceholder.typicode.com/posts/1').then(r => r.json())
]);
console.log('用户:', user.name);
console.log('文章:', post.title);
return { user: user.name, postTitle: post.title };''', isAsync: true),
        ],
      ),
      ExampleCategory(
        name: '性能测试',
        icon: Icons.speed,
        examples: [
          Example('大数组处理', '''(function() {
  console.log('创建大数组...');
  const size = 100000;
  const arr = Array.from({ length: size }, (_, i) => i);
  console.log('数组长度:', arr.length);

  console.log('开始计算...');
  const sum = arr.reduce((acc, val) => acc + val, 0);
  const avg = sum / arr.length;

  console.log('求和结果:', sum);
  console.log('平均值:', avg);
  return { size, sum, avg };
})()'''),
          Example('递归计算', '''(function() {
  // 递归斐波那契 (较慢)
  function fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
  }

  console.log('计算 fib(30)...');
  const result = fib(30);
  console.log('结果:', result);
  return result;
})()'''),
          Example('字符串拼接', '''(function() {
  console.log('开始字符串操作...');
  let str = '';
  const count = 10000;

  for (let i = 0; i < count; i++) {
    str += i.toString();
  }

  console.log('拼接完成');
  console.log('字符串长度:', str.length);
  console.log('前50字符:', str.substring(0, 50));
  return { count, length: str.length };
})()'''),
          Example('对象创建', '''(function() {
  console.log('批量创建对象...');
  const objects = [];
  const count = 50000;

  for (let i = 0; i < count; i++) {
    objects.push({
      id: i,
      name: 'Item ' + i,
      value: Math.random(),
      tags: ['tag1', 'tag2', 'tag3']
    });
  }

  console.log('创建完成');
  console.log('对象数量:', objects.length);
  console.log('首个对象:', objects[0]);
  console.log('最后对象:', objects[objects.length - 1]);
  return { count: objects.length, sample: objects[0] };
})()'''),
          Example('排序算法', '''(function() {
  console.log('生成随机数组...');
  const arr = Array.from({ length: 10000 }, () => Math.floor(Math.random() * 10000));
  console.log('数组长度:', arr.length);

  console.log('开始排序...');
  const sorted = [...arr].sort((a, b) => a - b);
  console.log('排序完成');

  console.log('最小值:', sorted[0]);
  console.log('最大值:', sorted[sorted.length - 1]);
  console.log('中位数:', sorted[Math.floor(sorted.length / 2)]);
  return { min: sorted[0], max: sorted[sorted.length - 1] };
})()'''),
          Example('JSON 序列化', '''(function() {
  console.log('创建复杂对象...');
  const data = {
    users: Array.from({ length: 1000 }, (_, i) => ({
      id: i,
      name: 'User' + i,
      email: 'user' + i + '@example.com',
      profile: {
        age: 20 + (i % 50),
        city: 'City' + (i % 10),
        hobbies: ['hobby1', 'hobby2', 'hobby3']
      }
    }))
  };

  console.log('开始序列化...');
  const json = JSON.stringify(data);
  console.log('JSON 长度:', json.length);

  console.log('开始反序列化...');
  const parsed = JSON.parse(json);
  console.log('用户数量:', parsed.users.length);
  return { jsonLength: json.length, userCount: parsed.users.length };
})()'''),
        ],
      ),
      ExampleCategory(
        name: '编码',
        icon: Icons.text_fields,
        examples: [
          Example('TextEncoder/Decoder', '''function test() {
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    // 基础编码
    const text1 = 'Hello, World!';
    const bytes1 = encoder.encode(text1);
    console.log('英文:', text1, '→', Array.from(bytes1));

    // 多字节字符
    const text2 = '你好世界😀';
    const bytes2 = encoder.encode(text2);
    const decoded = decoder.decode(bytes2);
    console.log('中文+Emoji:', text2);
    console.log('字节数:', bytes2.length);
    console.log('解码:', decoded, '✓');

    return {
        text: text2,
        byteLength: bytes2.length,
        match: text2 === decoded
    };
}
test();'''),
          Example('Base64 编码', '''function test() {
    // 文本编码
    const text = 'Hello, World!';
    const base64 = btoa(text);
    const decoded = atob(base64);
    console.log('文本:', text);
    console.log('Base64:', base64);
    console.log('解码:', decoded);
    console.log('匹配:', text === decoded, '✓');

    // 二进制编码
    const bytes = new Uint8Array([72, 101, 108, 108, 111]);
    let binaryStr = '';
    for (let i = 0; i < bytes.length; i++) {
        binaryStr += String.fromCharCode(bytes[i]);
    }
    const base64Binary = btoa(binaryStr);
    console.log('\\n二进制:', Array.from(bytes));
    console.log('Base64:', base64Binary);

    return {
        text: base64,
        binary: base64Binary
    };
}
test();'''),
          Example('JSON + UTF-8', '''function test() {
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    const data = {
        name: '张三',
        age: 30,
        city: 'Beijing',
        tags: ['开发者', '🚀']
    };

    const json = JSON.stringify(data, null, 2);
    const bytes = encoder.encode(json);
    const decodedJson = decoder.decode(bytes);
    const parsed = JSON.parse(decodedJson);

    console.log('对象:', data);
    console.log('\\nJSON字节数:', bytes.length);
    console.log('解析后:', parsed);
    console.log('名称匹配:', parsed.name === data.name, '✓');

    return {
        json,
        byteLength: bytes.length,
        parsed
    };
}
test();'''),
        ],
      ),
    ];
  }
}

class ExampleCategory {
  final String name;
  final IconData icon;
  final List<Example> examples;

  ExampleCategory({
    required this.name,
    required this.icon,
    required this.examples,
  });
}

class Example {
  final String name;
  final String code;
  final bool isAsync;

  Example(this.name, this.code, {this.isAsync = false});
}

class _ExampleCategory extends StatefulWidget {
  final ExampleCategory category;
  final String? selectedExample;
  final Function(String, String, {bool async}) onExampleTap;

  const _ExampleCategory({
    required this.category,
    required this.selectedExample,
    required this.onExampleTap,
  });

  @override
  State<_ExampleCategory> createState() => _ExampleCategoryState();
}

class _ExampleCategoryState extends State<_ExampleCategory> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Icon(widget.category.icon, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          ...widget.category.examples.map((example) {
            final isSelected = widget.selectedExample == example.name;
            return InkWell(
              onTap: () {
                widget.onExampleTap(
                  example.name,
                  example.code,
                  async: example.isAsync,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 8,
                ),
                color: isSelected
                    ? const Color(0xFF37373D)
                    : Colors.transparent,
                child: Row(
                  children: [
                    if (example.isAsync)
                      const Icon(Icons.schedule, size: 12, color: Colors.blue)
                    else
                      const SizedBox(width: 12),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        example.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class ExecutionResult {
  final String code;
  final String result;
  final bool isError;
  final DateTime timestamp;
  final bool isAsync;
  final Duration? duration;

  ExecutionResult({
    required this.code,
    required this.result,
    required this.isError,
    required this.timestamp,
    this.isAsync = false,
    this.duration,
  });
}
