import 'dart:ffi';
import 'dart:io';

import 'package:caipo_app/device/audio/opus_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// libopus on Windows copies its DLL through path_provider, which tests do not ship.
/// On Linux (CI) opus_flutter has no build, so the system libopus is used.
Future<void> loadOpusForTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux) {
    OpusCodec.useLibrary(DynamicLibrary.open('libopus.so.0'));
    return;
  }
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    return Directory.systemTemp.path;
  });
  await OpusCodec.ensureLoaded();
}
