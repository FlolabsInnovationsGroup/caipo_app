import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../protocol/proposed_commands.dart';

/// Local MJPEG server for CAIPO-SIM. Frames come from the bundled sample video.
///
/// The device stops the stream itself after two minutes. This is not the ESP32.
class SimMjpegServer {
  HttpServer? _server;
  Timer? _limit;
  var _open = false;
  List<Uint8List> _frames = const [];
  StreamReady? _ready;

  static const frameAssets = [
    'assets/sim/stream/frame_01.jpg',
    'assets/sim/stream/frame_02.jpg',
    'assets/sim/stream/frame_03.jpg',
    'assets/sim/stream/frame_04.jpg',
    'assets/sim/stream/frame_05.jpg',
    'assets/sim/stream/frame_06.jpg',
    'assets/sim/stream/frame_07.jpg',
    'assets/sim/stream/frame_08.jpg',
    'assets/sim/stream/frame_09.jpg',
    'assets/sim/stream/frame_10.jpg',
    'assets/sim/stream/frame_11.jpg',
    'assets/sim/stream/frame_12.jpg',
    'assets/sim/stream/frame_13.jpg',
    'assets/sim/stream/frame_14.jpg',
  ];

  Future<StreamReady> start({List<Uint8List>? frames, Duration? autoStop}) async {
    await stop();
    _frames = frames ?? await _loadFrames();
    if (_frames.isEmpty) {
      throw StateError('The sample stream has no frames.');
    }
    final token = Uint8List.fromList(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _ready = StreamReady(address: const [127, 0, 0, 1], port: server.port, token: token);
    _server = server;
    _open = true;
    server.listen(_handle);
    _limit = Timer(autoStop ?? kStreamAutoStop, () {
      unawaited(stop());
    });
    return _ready!;
  }

  StreamReady? get ready => _ready;

  Future<void> stop() async {
    _open = false;
    _limit?.cancel();
    _limit = null;
    final server = _server;
    _server = null;
    _ready = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final ready = _ready;
    final token = request.uri.queryParameters['token'];
    if (request.uri.path != kLiveStreamPath || ready == null || token != ready.tokenHex) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    final response = request.response;
    response.headers.set(HttpHeaders.contentTypeHeader, 'multipart/x-mixed-replace; boundary=frame');
    response.bufferOutput = false;
    var index = 0;
    try {
      while (_open && _server != null) {
        final jpeg = _frames[index % _frames.length];
        response.write('--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${jpeg.length}\r\n\r\n');
        response.add(jpeg);
        response.write('\r\n');
        await response.flush();
        index += 1;
        await Future<void>.delayed(Duration(milliseconds: (1000 / kStreamFps).round()));
      }
    } catch (_) {
      // The phone closed the stream.
    } finally {
      await response.close();
    }
  }

  Future<List<Uint8List>> _loadFrames() async {
    final frames = <Uint8List>[];
    for (final asset in frameAssets) {
      final data = await rootBundle.load(asset);
      frames.add(Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
    }
    return frames;
  }
}
