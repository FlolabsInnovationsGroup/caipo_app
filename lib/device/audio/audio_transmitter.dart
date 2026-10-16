import 'dart:typed_data';

import '../../core/config/constants.dart';
import '../protocol/transfer_manager.dart';
import 'opus_container.dart';

/// Packs Opus frames into one R03 audio transfer.
///
/// PCM-to-Opus encoding is not in this build. The caller passes frames that
/// are already Opus, 16 kHz mono, 20 ms. Nothing is written to GATT here.
class AudioTransmitter {
  const AudioTransmitter({
    this.container = const OpusFrameContainer(),
    this.transfers = const TransferManager(),
  });

  final OpusFrameContainer container;
  final TransferManager transfers;

  PreparedTransfer prepareReply(List<Uint8List> opusFrames, {required int transferId}) {
    return transfers.prepare(
      payload: container.pack(opusFrames),
      transferId: transferId,
      contentType: kContentTypeAudio,
    );
  }
}
