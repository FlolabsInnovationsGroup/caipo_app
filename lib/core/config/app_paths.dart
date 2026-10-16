import 'dart:io';

class AppPaths {
  const AppPaths({
    required this.documents,
    required this.transfers,
    required this.replies,
    required this.history,
  });

  final Directory documents;
  final Directory transfers;
  final Directory replies;
  final Directory history;

  Future<int> clearTransferCache() async {
    if (!transfers.existsSync()) return 0;
    final files = transfers.listSync().whereType<File>().toList();
    for (final file in files) {
      await file.delete();
    }
    return files.length;
  }
}
