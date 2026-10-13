# CAIPO placeholders

Every value below is a development stand-in. The source of truth in code is `lib/core/config/constants.dart`. Substituting the real value is a one-file change unless a native comment says it mirrors a Dart constant.

| Constant | Placeholder | Owner | What breaks if it is wrong |
| --- | --- | --- | --- |
| `kPrimaryServiceUuid` | OMI primary service `19b10000-e8f2-537e-4f6c-d104768a1214` | IoT team | Scan filter and GATT service check look for the wrong device. Pairing reports "not advertising CAIPO" or connects to an OMI device during development. Notion task "Define BLE service/characteristic UUIDs for CAIPO audio" has been open since August 2025. |
| `kAudioNotifyCharacteristicUuid` | OMI audio notify `19b10001-e8f2-537e-4f6c-d104768a1214` | IoT team | Inbound audio notifications are subscribed on the wrong characteristic. Phase 2 will decode silence or the wrong stream. |
| `kAudioCodecCharacteristicUuid` | OMI codec read `19b10002-e8f2-537e-4f6c-d104768a1214` | IoT team | Codec negotiation reads the wrong characteristic and falls through to PCM 8 kHz. Audio becomes noise. |
| `kOutboundAudioCharacteristicUuid` | OMI speaker/haptic `cab1ab96-2ea5-4f4d-bb56-874b72cfc984` | IoT team | Phase 4 would write the response to OMI's haptic characteristic. Nothing is written in this build. |
| `kAdvertisedNamePrefix` | empty | IoT team | Empty means match by service UUID only. A wrong prefix hides real devices or shows unrelated ones. |
| `kRequiresBond` | `false` | IoT team | `true` shows the system pairing dialog. `false` persists the device id without SMP bonding. The spec does not say which CAIPO needs. |
| `kAudioHeaderRetained` | `true` | IoT team | If the firmware drops the 3-byte header, the assembler treats payload bytes as a header and audio frames split in the wrong place. |
| `kTargetCodecId` | `21` (Opus 16 kHz, 320-sample frames) | IoT team | Recommended by the spec and by the hardware notes. A different id decodes to noise. The OMI codec map (1, 20, 21) is what negotiation implements. |
| `kTransferChecksumAlgorithm` | `crc32` | Unassigned | R03 allows CRC-32 or SHA-256. The other side will reject the transfer if it expects the other digest. SHA-256 is implemented and selectable. |
| `kOpcodeTransferRequest` and the other five opcodes | `0x00` for every opcode | Unassigned | They are identical, so they cannot identify a message. The transfer manager refuses to write wire bytes. |
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
| R03 backoff delays | R01's 1s, 2s, 4s | Unassigned | R03 says exponential backoff and does not give the base. Wrong delays only affect retry pacing, and no wire transfer is sent in this build. |
| STT / TTS endpoints | none | FloBrain team | `SttClient` and `TtsClient` return no audio and no transcript. The round trip cannot be completed. |

## Not placeholders

These are specified or are Bluetooth SIG standards:

- API base URL `https://api.flobrain.ai`
- Battery service `0000180f-…` and battery level `00002a19-…`
- Device information service `0000180a-…` and its characteristic UUIDs
- Negotiated MTU 512, chunk size 509, max transfer 32 MB
- Authorisation timeout 5 seconds, 3 transfer attempts
- Reconnect delays 1s, 2s, 4s
- Disconnect detection budget 5 seconds
- Conversation idle timeout 30 seconds
- Codec bytes 1, 20 and 21 as verified against OMI's shipping switch
- iOS restore id `com.flolabs.caipo.ble` (CAIPO's own id)
- Android Keystore alias `caipo.token.kek` (CAIPO's own alias)

## Firmware question still open

The hardware document lists the BLE GATT audio service as planned work, and the firmware listing has no BLE module. Until that exists, a successful scan depends on something advertising the placeholder service UUID.
