# Notes on the specification

These are places where the spec is ambiguous, contradictory, or impossible as written. The code takes the conservative choice and names it in `lib/core/config/constants.dart` and `PLACEHOLDERS.md`.

## Live API schema could not be fetched

`https://api.flobrain.ai/api/schema/`, `/api/swagger/`, `/api/redoc/` and the auth endpoints timed out or refused the connection from this environment on 13 October 2026. An earlier fetch of `/api/schema/` returned HTTP 500. Request and response field names for tokens, email, password and change-password are therefore placeholders, not confirmed shapes. The client fails closed when those keys are absent. It does not try a second set of names.

The documented error object `{ "error", "details" }` is what the client reads.

## R03 wire format

Confirmed by the IoT team. Opcode 0x00 is reserved. CHUNK, METADATA, TRANSFER_ERROR and HEARTBEAT have the layouts in `messages.dart`. CRC-32 is the digest. A failed chunk is retransmitted on its own, up to 3 times, after a 5 second wait.

TRANSFER_REQUEST, TRANSFER_READY and TRANSFER_ACK were named and not given extra fields. They are encoded as opcode plus the uint16 transfer id used by the other transfer messages.

The testing cap stays 32 MB. uint16 sequence numbers times a 502-byte payload address 32,899,072 bytes, which is smaller. The chunker refuses anything that would not fit. The header layout is unchanged.

## Real-time audio is removed

CAIPO records, stores, then sends the whole recording as one R03 transfer. The app does the same with AI reply audio. The 3-byte OMI audio header is not used. Opus frames inside a content-type 0x01 transfer are `[uint16 length][frame]...`. `PacketAssembler` throws if something still tries to stream.

## Codec byte

CAIPO recordings are codec 21: Opus, 16 kHz mono, 20 ms, 320-sample frames. Bytes 1 and 20 are still recognised. Any other byte, including an empty read, is unsupported. It is not treated as PCM.

## Pairing versus bonding

SMP bonding is required. Android calls `createBond`. iOS cannot start bonding. The firmware requires encryption on the characteristics, and that is what shows the iOS pairing dialog.

## Disconnect detection

The app still polls the native connection every 1 second. The device also sends a heartbeat every 1 second on `A1000004` (opcode 0x10, then a uint8 counter). Any byte counts as alive. Three seconds of silence means disconnected, but that rule is off (`kHeartbeatSilenceDisconnectEnabled`) until the firmware sends heartbeats. The firmware asks for a 6 second supervision timeout. The phone does not set it.

## Connect and scan timeouts are not specified

GATT ready uses 30 seconds (`kGattReadyTimeoutSeconds`), mirrored in the Android manager. A refresh scans for 8 seconds. Both are app-team defaults.

## Auto-lock duration is not specified

Phase 3 requires a configurable inactivity lock. The default is 15 minutes and the pairing screen offers 1, 5, 15 and 60. Those choices are not in the spec.

## HTTP retry count is not specified

Timeouts, HTTP 429 and HTTP 5xx retry up to 3 times because 3 is the only retry count the spec states (R03). Backoff is 0.5s, 1s, 2s unless `Retry-After` is present.

## Phase 2 says both "do not build" and "unit-test the assembler"

The real-time assembler is disabled. Codec negotiation and the Opus frame container are tested. `OpusDecoder.decode` returns no PCM.

The brief also says to mock the chunker and checksum, and to unit-test them. The chunker and checksum are real because a test of a mock would not prove the specified sizes or digests. The transfer manager around them is a mock and does not write bytes.

## STT and TTS block the audio round trip

No speech endpoint is in section 7. `SttClient` and `TtsClient` return empty results. R02.3 and R06.3 cannot be completed until FloBrain says where speech is handled.

## OMI paths in the spec have drifted

The spec points at `app/ios/Runner/Ble/OmiBleManager.swift`. That path exists in the current OMI tree. `app/lib/services/devices/models.dart` still holds the UUID table. The native stack also contains continuous-capture, companion-device and diagnostics code this app does not take. The Pigeon contract here is the BLE scan/connect/GATT surface only.

## Android token storage

The spec forbids SharedPreferences for tokens. Android Keystore stores keys, not arbitrary strings. Ciphertext is written to `filesDir/caipo_tokens.bin`. The AES-256-GCM key alias is `caipo.token.kek`. iOS uses the Keychain.

## iOS cannot be compiled on this machine

The project targets iOS 15 and includes the CoreBluetooth layer. This environment is Windows, so `flutter test` and an Android build are what can be run here. An iOS build needs a Mac.

## Change-password body

`POST /api/profile/change-password/` is listed with no schema. The body keys `current_password` and `new_password` are placeholders.

## Conversation states

Section 9.1 includes Listening, Processing and Responding. Those transitions depend on a wake word, STT, TTS and R03, none of which are available. The enum exists. The pairing screen only drives the BLE states.

## Wi-Fi

Not built, per Phase 6. BLE is never dropped in favour of holding a Wi-Fi association.
