import 'dart:typed_data';

import 'opus_encoder.dart';

class TransmitResult {
  const TransmitResult.mock({required this.detail});

  final String detail;
  final bool sent = false;
}

/// Phase 4 mock for R02.3. Nothing is written to the outbound characteristic.
class AudioTransmitter {
  const AudioTransmitter({this.encoder = const OpusEncoder()});

  final OpusEncoder encoder;

  Future<TransmitResult> sendResponse(Uint8List pcmOrEncoded) async {
    encoder.encode(pcmOrEncoded);
    return const TransmitResult.mock(
      detail:
          'Outbound audio is not implemented. The characteristic and the '
          'R03 wire format are both TBD, so no bytes were written.',
    );
  }
}
