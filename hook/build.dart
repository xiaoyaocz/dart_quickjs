// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // Only build code assets if requested
    if (!input.config.buildCodeAssets) {
      return;
    }

    final packageName = input.packageName;
    final targetOS = input.config.code.targetOS;

    // QuickJS source files relative to package root
    const quickjsDir = 'third_party/quickjs-ng';
    final sources = [
      '$quickjsDir/cutils.c',
      '$quickjsDir/dtoa.c',
      '$quickjsDir/libregexp.c',
      '$quickjsDir/libunicode.c',
      '$quickjsDir/quickjs.c',
      '$quickjsDir/quickjs-libc.c',
    ];

    // Platform-specific defines
    final defines = <String, String?>{'_GNU_SOURCE': null};

    // Windows-specific defines
    if (targetOS == OS.windows) {
      defines['WIN32_LEAN_AND_MEAN'] = null;
      defines['_WIN32_WINNT'] = '0x0601';
      // Export symbols on Windows
      defines['JS_EXTERN'] = '__declspec(dllexport)';
    }

    // macOS/iOS framework define
    if (targetOS == OS.macOS || targetOS == OS.iOS) {
      defines['JS_EXTERN'] = '__attribute__((visibility("default")))';
    }

    // Linux/Android shared library
    if (targetOS == OS.linux || targetOS == OS.android) {
      defines['JS_EXTERN'] = '__attribute__((visibility("default")))';
    }

    // Compiler flags
    final flags = <String>[];

    // Libraries to link
    final libraries = <String>[];

    // Add C11 standard and disable warnings for non-Windows platforms
    if (targetOS != OS.windows) {
      flags.addAll([
        '-Wno-implicit-fallthrough',
        '-Wno-sign-compare',
        '-Wno-missing-field-initializers',
        '-Wno-unused-parameter',
        '-Wno-unused-but-set-variable',
      ]);

      // On Linux, tell Clang to use the system linker instead of looking in LLVM dir
      if (targetOS == OS.linux) {
        flags.addAll(['-fuse-ld=bfd']); // Use GNU ld (binutils)
      }

      // On Android, explicitly link libm for math functions like scalbn
      if (targetOS == OS.android) {
        libraries.add('m'); // libm - math library
        // Improve compatibility with older Android devices (e.g., Android 9)
        // Disable some optimizations that may cause issues on certain ARM devices
        flags.addAll([
          '-fno-fast-math', // Ensure strict floating-point behavior
          '-fstack-protector-strong', // Stack protection
        ]);
      }
    } else {
      // MSVC requires experimental flag for C11 atomics support
      flags.add('/experimental:c11atomics');
    }

    // Build the library
    final builder = CBuilder.library(
      name: packageName,
      assetName: 'src/quickjs_bindings.g.dart',
      sources: sources,
      includes: [quickjsDir],
      defines: defines,
      flags: flags,
      libraries: libraries,
      std: 'c11', // QuickJS-ng requires C11 for stdatomic.h
    );

    await builder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}
