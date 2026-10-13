# Notes on the specification

These are places where the spec is ambiguous, contradictory, or impossible as written. The code takes the conservative choice and names it in `lib/core/config/constants.dart` and `PLACEHOLDERS.md`.

## Live API schema could not be fetched

`https://api.flobrain.ai/api/schema/`, `/api/swagger/`, `/api/redoc/` and the auth endpoints timed out or refused the connection from this environment on 13 October 2026. An earlier fetch of `/api/schema/` returned HTTP 500. Request and response field names for tokens, email, password and change-password are therefore placeholders, not confirmed shapes. The client fails closed when those keys are absent. It does not try a second set of names.

The documented error object `{ "error", "details" }` is what the client reads.

## R03 wire format is unspecified

Section 6 specifies the message flow, chunk size, checksum choice (CRC-32 or SHA-256), timeouts and retry count. It does not specify opcode values, field order, header layout or the error-code table. The chunker and both checksums are real. `TransferManager.send` prepares chunks and a digest in memory and writes nothing.

The spec also says "CRC32 or SHA-256" without choosing. The placeholder is CRC-32.

R03's exponential backoff has no base delay. The only exponential series in the spec is R01's 1s, 2s, 4s, so the transfer retry policy uses that series.

## End of an audio packet is unspecified

Section 4.3 defines the 3-byte header and says fragments are reassembled. It does not say how the receiver knows the last fragment. The assembler holds the open packet until a different packet number arrives, or until `flush()`. A missing fragment index is marked non-contiguous and still concatenated in order. Whether the header exists at all is an open IoT decision (`kAudioHeaderRetained`).

## OMI documentation versus OMI code

Followed the spec: codec 1 is PCM 8 kHz, 20 is Opus 8 kHz / 160 samples, 21 is Opus 16 kHz / 320 samples, and every other byte falls through to PCM 8 kHz. OMI's Protocol.mdx is not implemented.

## Pairing versus bonding

R01.3 says "persist pairing". It does not say the device uses SMP bonding. This build stores the device id and reconnects. `kRequiresBond` is false. Turning it on is a one-constant change.

## Disconnect detection under 5 seconds

The app polls the native connection every 1 second and asks Android for `CONNECTION_PRIORITY_HIGH`. The radio still only reports a dead link after the supervision timeout the firmware negotiates. That timeout is not in the spec. iOS does not let the central set it directly. The poll meets the budget only after the stack has already dropped the link.

## Connect and scan timeouts are not specified

GATT ready uses 30 seconds (`kGattReadyTimeoutSeconds`), mirrored in the Android manager. A refresh scans for 8 seconds. Both are app-team defaults.

## Auto-lock duration is not specified

Phase 3 requires a configurable inactivity lock. The default is 15 minutes and the pairing screen offers 1, 5, 15 and 60. Those choices are not in the spec.

## HTTP retry count is not specified

Timeouts, HTTP 429 and HTTP 5xx retry up to 3 times because 3 is the only retry count the spec states (R03). Backoff is 0.5s, 1s, 2s unless `Retry-After` is present.

## Phase 2 says both "do not build" and "unit-test the assembler"

The brief says not to build inbound Opus decode beyond unit-testable logic, and also to test the assembler and codec negotiation. Those two are implemented. `OpusDecoder.decode` returns no PCM.

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
