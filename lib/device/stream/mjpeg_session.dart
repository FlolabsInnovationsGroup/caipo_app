import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Pulls JPEG frames out of an MJPEG byte stream.
class JpegScanner {
  final List<int> _pending = [];

  Uint8List? push(List<int> chunk) {
    _pending.addAll(chunk);
    final start = _find(0xFF, 0xD8, 0);
    if (start < 0) {
      if (_pending.length > 3) _pending.removeRange(0, _pending.length - 3);
      return null;
    }
    if (start > 0) _pending.removeRange(0, start);
    final end = _find(0xFF, 0xD9, 2);
    if (end < 0) return null;
    final jpeg = Uint8List.fromList(_pending.sublist(0, end + 2));
    _pending.removeRange(0, end + 2);
    return jpeg;
  }

  int _find(int a, int b, int from) {
    for (var i = from; i < _pending.length - 1; i++) {
      if (_pending[i] == a && _pending[i + 1] == b) return i;
    }
    return -1;
  }
}

/// Opens the device's local MJPEG URL. The caller closes it.
class MjpegSession {
  HttpClient? _client;
  var _open = false;

  Future<void> open(Uri uri, void Function(Uint8List jpeg) onFrame) async {
    await close();
    final client = HttpClient();
    _client = client;
    _open = true;
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('The camera refused the stream (${response.statusCode}).');
    }
    final scanner = JpegScanner();
    await for (final chunk in response) {
      if (!_open) break;
      final jpeg = scanner.push(chunk);
      if (jpeg != null) onFrame(jpeg);
    }
  }

  Future<void> close() async {
    _open = false;
    _client?.close(force: true);
    _client = null;
  }
}
