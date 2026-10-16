import 'dart:typed_data';

import '../../core/config/constants.dart';

/// Real-time audio streaming is not part of CAIPO.
///
/// The device records, stores, then sends the whole recording as one R03
/// transfer. The 3-byte OMI-style audio header is not used. AI reply audio
/// goes out the same way. See [OpusFrameContainer] and [TransferManager].
class PacketAssembler {
  List<Object> add(Uint8List notification) {
    if (!kRealtimeAudioStreaming) {
      throw UnsupportedError(
        'Real-time audio streaming is disabled. Ignored ${notification.length} '
        'bytes. CAIPO sends the whole recording as one R03 transfer.',
      );
    }
    return const [];
  }

  List<Object> flush() => add(Uint8List(0));
}
