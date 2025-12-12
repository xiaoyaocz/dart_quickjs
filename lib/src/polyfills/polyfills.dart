// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Polyfills for JavaScript runtime.
///
/// This library exports all available polyfills:
/// - [ConsolePolyfill] - console.log, console.error, etc.
/// - [FetchPolyfill] - fetch API with Response, Headers, AbortController
/// - [TimerPolyfill] - setTimeout, setInterval, clearTimeout, clearInterval
/// - [EncodingPolyfill] - TextDecoder, TextEncoder, and Base64 (atob/btoa)
/// - [WebSocketPolyfill] - WebSocket API with web_socket_channel
/// - [URLPolyfill] - URL and URLSearchParams APIs
library;

export 'console_polyfill.dart';
export 'encoding_polyfill.dart';
export 'fetch_polyfill.dart';
export 'timer_polyfill.dart';
export 'websocket_polyfill.dart';
export 'url_polyfill.dart';
