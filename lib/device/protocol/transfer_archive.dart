import 'dart:io';
import 'dart:typed_data';

import '../../core/security/at_rest.dart';

/// One file per received transfer. The name carries the time, content type, and size.
///
/// When [cipher] is set, the bytes on disk are AES-GCM with a CENC header.
/// A retry of R03 starts a new transfer. This archive does not resume one.
class TransferArchive {
  TransferArchive(this.directory, {this.cipher});

  final Directory directory;
  final AtRestCipher? cipher;

  Future<File> save({required Uint8List bytes, required int contentType}) {
    return _write(bytes, 'transfer', contentType);
  }

  /// Bytes received before the transfer was dropped. Not a playable file.
  Future<File> savePartial(Uint8List bytes) {
    return _write(bytes, 'partial', 0);
  }

  Future<File> _write(Uint8List bytes, String prefix, int contentType) async {
    directory.createSync(recursive: true);
    final body = cipher == null ? bytes : await cipher!.seal(bytes);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final name = '${prefix}_${stamp}_type${contentType}_${bytes.length}.bin';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(body, flush: true);
    return file;
  }
}
