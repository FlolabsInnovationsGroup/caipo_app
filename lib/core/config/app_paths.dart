import 'dart:io';
import 'dart:typed_data';

class AppPaths {
  const AppPaths({
    required this.documents,
    required this.transfers,
    required this.replies,
    required this.history,
    this.playback,
  });

  final Directory documents;
  final Directory transfers;
  final Directory replies;
  final Directory history;

  /// Plain copies made only so a player can read encrypted audio. They live in
  /// the temporary folder, are deleted when the tile closes, at start-up, and by
  /// "Delete all". Never next to the encrypted file.
  final Directory? playback;

  Future<int> clearTransferCache() async {
    if (!transfers.existsSync()) return 0;
    final files = transfers.listSync().whereType<File>().toList();
    for (final file in files) {
      await file.delete();
    }
    return files.length;
  }
}

/// Writes [bytes] to [directory] (or the system temp folder) for a player.
Future<File> writePlaybackCopy(Directory? directory, String name, Uint8List bytes) async {
  final dir = directory ?? Directory('${Directory.systemTemp.path}${Platform.pathSeparator}caipo-play');
  dir.createSync(recursive: true);
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Deletes a copy made by [writePlaybackCopy]. Leaves any other file alone.
Future<void> deletePlaybackCopy(Directory? directory, File? file) async {
  if (file == null || !file.existsSync()) return;
  final dir = directory ?? Directory('${Directory.systemTemp.path}${Platform.pathSeparator}caipo-play');
  if (file.parent.absolute.path != dir.absolute.path) return;
  await file.delete();
}
