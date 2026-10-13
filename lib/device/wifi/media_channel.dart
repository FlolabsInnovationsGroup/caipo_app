enum WifiChannelState { unprovisioned, idle, connecting, active }

/// Phase 6 mock. The Wi-Fi state machine is specified and not driven.
class MediaChannel {
  const MediaChannel();

  WifiChannelState get state => WifiChannelState.unprovisioned;

  Future<void> requestLiveView() async {}
}
