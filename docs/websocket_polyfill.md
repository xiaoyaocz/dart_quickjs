# WebSocket Polyfill 添加说明

## 更新内容

本次更新为 `dart_quickjs` 项目添加了 WebSocket API 支持，使用 `web_socket_channel` 包实现。

## 新增文件

1. **lib/src/polyfills/websocket_polyfill.dart**
   - 实现 WebSocket Polyfill 类
   - 使用 `web_socket_channel` 包处理实际的 WebSocket 连接
   - 提供标准的 JavaScript WebSocket API

2. **example/websocket_example.dart**
   - 展示 WebSocket 基本用法
   - 包含 5 个示例：
     - 基本 WebSocket 连接
     - 使用 addEventListener
     - WebSocket 状态常量
     - 发送多条消息
     - 错误处理

3. **test/polyfills/websocket_polyfill_test.dart**
   - 完整的单元测试套件
   - 测试所有 WebSocket API 功能
   - 包含集成测试（实际连接到 echo.websocket.org）

## 修改文件

1. **pubspec.yaml**
   - 添加依赖：`web_socket_channel: ^3.0.1`

2. **lib/src/polyfills/polyfills.dart**
   - 导出 `websocket_polyfill.dart`

3. **lib/src/runtime.dart**
   - `JsRuntimeConfig` 添加 `enableWebSocket` 配置选项
   - `JsRuntime` 类添加 `_webSocketPolyfill` 字段和 getter
   - `_initializePolyfills()` 方法中初始化 WebSocket polyfill
   - `dispose()` 方法中清理 WebSocket 资源

4. **README.md**
   - 在特性列表中添加 WebSocket API
   - 在配置选项中添加 `enableWebSocket` 说明
   - 添加完整的 WebSocket API 使用文档和示例

## 功能特性

### 支持的 API

- ✅ `WebSocket(url, protocols?, options?)` - 创建 WebSocket 连接
  - `url`: WebSocket 服务器地址
  - `protocols`: 可选的子协议数组
  - `options`: 可选配置对象，支持 `headers` 属性
- ✅ `send(data)` - 发送数据
- ✅ `close(code?, reason?)` - 关闭连接
- ✅ `onopen` / `onmessage` / `onerror` / `onclose` - 事件处理器
- ✅ `addEventListener()` / `removeEventListener()` - 事件监听
- ✅ `readyState` - 连接状态
- ✅ `url` - 连接 URL
- ✅ 状态常量: `CONNECTING`, `OPEN`, `CLOSING`, `CLOSED`
- ✅ `binaryType` 属性（支持 'blob' 和 'arraybuffer'）
- ✅ 自定义 HTTP Headers 支持

### 使用方式

#### 基本连接

```dart
import 'package:dart_quickjs/dart_quickjs.dart';

void main() async {
  final runtime = JsRuntime(
    config: JsRuntimeConfig(
      enableWebSocket: true,
      enableConsole: true,
    ),
  );

  await runtime.evalAsync('''
    const ws = new WebSocket('wss://echo.websocket.org/');
    
    ws.onopen = function() {
      console.log('Connected!');
      ws.send('Hello WebSocket!');
    };
    
    ws.onmessage = function(event) {
      console.log('Received:', event.data);
      ws.close();
    };
    
    await new Promise(resolve => {
      ws.onclose = resolve;
    });
  ''');

  runtime.dispose();
}
```

#### 使用自定义 Headers

```dart
await runtime.evalAsync('''
  // 创建带自定义 headers 的连接
  const ws = new WebSocket('wss://your-server.com', [], {
    headers: {
      'Authorization': 'Bearer your-token',
      'X-Custom-Header': 'custom-value',
      'X-API-Key': 'your-api-key',
      'User-Agent': 'MyApp/1.0'
    }
  });
  
  ws.onopen = () => {
    console.log('Connected with custom headers');
  };
''');
```

## 技术实现

1. **Dart 端实现**：
   - 使用 `JsBridge` 处理 JavaScript 到 Dart 的调用
   - 使用 `web_socket_channel` 处理实际的 WebSocket 连接
   - 通过 `StreamSubscription` 监听消息和事件
   - 通过 `runtime.eval()` 将事件推送回 JavaScript

2. **JavaScript 端实现**：
   - 完整的 WebSocket 类实现
   - 符合 W3C WebSocket API 标准
   - 支持事件处理器和 addEventListener/removeEventListener
   - 自动状态管理（CONNECTING、OPEN、CLOSING、CLOSED）

3. **资源管理**：
   - 在 `dispose()` 时自动关闭所有活动的 WebSocket 连接
   - 清理所有流订阅和映射

## 测试

运行测试：
```bash
# 运行所有 WebSocket 测试
dart test test/polyfills/websocket_polyfill_test.dart

# 运行特定测试
dart test test/polyfills/websocket_polyfill_test.dart --name "WebSocket class is available"
```

运行示例：
```bash
dart run example/websocket_example.dart
```

## 兼容性

- 支持所有 dart_quickjs 支持的平台
- 需要网络连接来测试实际的 WebSocket 功能
- 依赖 `web_socket_channel: ^3.0.1`

## 注意事项

1. WebSocket 连接需要在 `evalAsync` 中执行以正确处理异步事件
2. 建议同时启用 `enableConsole` 来调试 WebSocket 通信
3. 所有 WebSocket 连接会在 `runtime.dispose()` 时自动关闭
4. 使用标准的 WebSocket URL（ws:// 或 wss://）

## 后续改进建议

1. 支持二进制数据（ArrayBuffer、Blob）
2. 添加更多的 WebSocket 选项（如 headers、compression）
3. 添加重连机制
4. 添加连接超时控制
