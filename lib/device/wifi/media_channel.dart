import '../../core/config/proposed_flags.dart';

enum WifiChannelState { unprovisioned, idle, connecting, active }

/// Camera media stays on Wi-Fi. The live picture is the proposed MJPEG stream.
class MediaChannel {
  const MediaChannel();

  WifiChannelState get state => kProposedStream ? WifiChannelState.idle : WifiChannelState.unprovisioned;

  Future<void> requestLiveView() async {
    throw StateError(
      kProposedStream
          ? 'Open Live view. The stream is MJPEG on the local network.'
          : 'Live streaming is proposed and turned off.',
    );
  }
}
