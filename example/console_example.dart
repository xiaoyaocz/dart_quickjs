// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  print('=== Console 日志捕获示例 ===\n');

  final runtime = JsRuntime(
    config: JsRuntimeConfig(enableConsole: true, enableTimer: true),
  );

  // 示例 1: 实时日志监听
  print('示例 1: 实时日志监听');
  print('-' * 50);

  // 设置实时日志监听器 - 实时输出到控制台
  var logCount = 0;
  runtime.onConsoleLog.listen((log) {
    logCount++;
    print('  [$logCount] [实时] [${log.level}] ${log.message}');
  });

  // 执行一些 JavaScript 代码
  runtime.eval('''
    console.log('Hello from JavaScript!');
    console.warn('This is a warning');
    console.error('This is an error');
    console.info('Information message');
    console.debug('Debug message');
  ''');

  // 等待事件循环处理
  await Future.delayed(Duration(milliseconds: 50));

  print('\n示例 2: 对象和数组日志');
  print('-' * 50);

  runtime.eval('''
    console.log('Object:', { name: 'Dart', version: 3 });
    console.log('Array:', [1, 2, 3, 4, 5]);
    console.log('Nested:', { 
      user: { name: 'John', age: 30 },
      tags: ['dart', 'javascript', 'quickjs']
    });
  ''');
  // 等待事件循环处理
  await Future.delayed(Duration(milliseconds: 50));
  print('\n示例 3: 异步日志');
  print('-' * 50);

  // 使用 Promise 的异步日志
  runtime.eval('''
    Promise.resolve().then(() => {
      console.log('Async log from Promise');
    });
  ''');

  // 执行 Promise 任务
  runtime.executePendingJobs();

  print('\n示例 4: Timer 定时日志');
  print('-' * 50);

  await runtime.evalAsync('''
    return new Promise((resolve) => {
      let count = 0;
      const id = setInterval(() => {
        count++;
        console.log('Timer tick:', count);
        if (count >= 3) {
          clearInterval(id);
          resolve('Timer completed');
        }
      }, 100);
    });
  ''');

  print('\n示例 5: 查看历史日志');
  print('-' * 50);

  // 获取所有历史日志
  print('\n所有历史日志 (${runtime.consoleLogs.length} 条):');
  for (final log in runtime.consoleLogs) {
    print('  [${log.timestamp}] [${log.level}] ${log.message}');
  }

  print('\n示例 6: 清除日志');
  print('-' * 50);

  runtime.clearConsoleLogs();
  print('日志已清除');
  print('当前日志数量: ${runtime.consoleLogs.length}');

  // 再次输出一些日志
  runtime.eval('''
    console.log('New log after clear');
    console.warn('Another warning');
  ''');

  print('清除后的新日志数量: ${runtime.consoleLogs.length}');

  // 清理资源
  runtime.dispose();
  print('\n=== 示例完成 ===');
}
