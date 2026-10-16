# CAIPO placeholders

Values below are still development stand-ins. The source of truth in code is `lib/core/config/constants.dart`.

The BLE identity, R03 opcodes, CRC-32, bonding, the CAIPO name prefix, and codec 21 were confirmed by the IoT team (Antoine Beaugas). They are no longer placeholders. The firmware GATT layer is still being written, so those values cannot be tested on a device yet.

| Constant | Placeholder | Owner | What breaks if it is wrong |
| --- | --- | --- | --- |
| `kAccessTokenJsonField` | `access` | FloBrain team | Sign-in fails closed when the live body uses another key. `/api/schema/` was unreachable from the build environment on 13 Oct 2026. |
| `kRefreshTokenJsonField` | `refresh` | FloBrain team | Refresh and restart both fail closed. |
| `kEmailJsonField` | `email` | FloBrain team | Register and sign-in send the wrong body and the API returns 400. |
| `kPasswordJsonField` | `password` | FloBrain team | Same as email. |
| `kCurrentPasswordJsonField` | `current_password` | FloBrain team | Change-password sends the wrong body. |
| `kNewPasswordJsonField` | `new_password` | FloBrain team | Same as the current-password field. |
| `kHttpTimeoutSeconds` | `20` | App team | Too low causes false timeouts. Too high hangs the UI. Not specified. |
| `kDefaultAutoLockMinutes` | `15` | Product | The session locks sooner or later than product wants. The screen can change it. |
| `kGattReadyTimeoutSeconds` | `30` | App team | Mirrored in `CaipoBleManager.connectTimeoutMs` (30000). A short timeout fails slow discovery. A long one leaves the user waiting. Not specified. |
| `kScanTimeoutSeconds` | `8` | App team | Refresh window. Not specified. |
| STT / TTS endpoints | none | FloBrain team | `SttClient` and `TtsClient` return no audio and no transcript. The round trip cannot be completed. |
| PCM to Opus | none | App team | `OpusEncoder` returns no bytes. The transfer path expects frames that are already Opus. |

## Not placeholders

These are specified or are Bluetooth SIG standards:

- API base URL `https://api.flobrain.ai`
- Battery service `0000180f-…` and battery level `00002a19-…`
- Device information service `0000180a-…` and its characteristic UUIDs
- Negotiated MTU 512, CHUNK payload 502 bytes, testing max transfer 32 MB
- Authorisation timeout 5 seconds, 3 retransmissions of the failed chunk
- Reconnect delays 1s, 2s, 4s
- Disconnect detection budget 5 seconds
- Heartbeat silence rule, off until firmware sends heartbeats
- Conversation idle timeout 30 seconds
- Codec 21 for CAIPO recordings (Opus 16 kHz, 320-sample frames)
- Service `a1000000-5fa6-43f5-9827-201f62bd377d` and characteristics `A1000001`–`A1000004`
- iOS restore id `com.flolabs.caipo.ble` (CAIPO's own id)
- Android Keystore alias `caipo.token.kek` (CAIPO's own alias)

## Firmware still being written

The IoT contract is confirmed. The ESP32-S3 BLE layer is not ready, so a scan will not find a CAIPO device yet. Real-device testing stays blocked.
