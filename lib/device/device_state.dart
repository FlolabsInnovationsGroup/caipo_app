/// Spec section 9.1. Conversation states are defined and not driven.
enum CaipoLinkState {
  disconnected,
  scanning,
  notFound,
  connecting,
  pairingFailed,
  connected,
  reconnecting,
  listening,
  processing,
  responding,
}

/// Spec section 9.2. Not driven in this build. BLE stays up independently.
enum CaipoWifiState { unprovisioned, idle, connecting, active }
