# CAIPO app — current state for the next assistant

Date: 16 October 2026. Repo: `D:\the work\flolabs\caipo_app\app`. Flutter app (Dart 3.13 / Flutter 3.47.7). Platforms: Android 10+ (minSdk 29) and iOS 15+. Native BLE is Kotlin and Swift through Pigeon.

This file is a handoff. The source of truth for what to build next is `docs/CAIPO_BUILD_PLAN.md`. The last status write-up is `docs/STATUS.md`. Phase 0 and Phase 1 are done. Phase 2 has not been started.

## Hard rules

1. No fake success. Missing firmware, FloBrain endpoints, and the Wi-Fi contract stay behind a simulator or a clear failure. Switches: `DEVICE_MODE=sim|ble` (default `ble`) and `BACKEND_MODE=mock|live` (default `live`), from `lib/core/config/app_mode.dart`.
2. Do not change the BLE contract in `lib/core/config/constants.dart` (UUIDs, opcodes, header layouts). If something looks wrong, add it under "Contract questions" in `docs/STATUS.md` and keep going.
3. Do not invent FloBrain JSON field names in live mode. The live client must fail when a field is missing. Placeholder names exist only for the mock.
4. No API keys in the app.
5. End a phase with `flutter test`, `flutter analyze` clean, and an updated `docs/STATUS.md`.
6. The plan says stop after each phase and wait for the word "continue". Phase 2 is the next unfinished phase.

Flutter is not on PATH. Use `D:\sdk\flutter\bin\flutter.bat`.

## What the product is

CAIPO is a wearable. It records audio, then sends the whole recording to the phone over BLE. The app decodes Opus, runs speech-to-text, sends text to FloBrain, gets a reply, synthesizes speech, encodes Opus, and sends that file back. CAIPO plays it. There is no real-time audio streaming. Camera and video are Wi-Fi later. Everything else is BLE. The radio is ESP32-S3 only. The Raspberry Pi is not on BLE.

```
CAIPO records -> R03 -> app decodes Opus -> STT -> FloBrain chat
-> TTS -> app encodes Opus -> R03 -> CAIPO plays it
```

## How to run what exists

```bash
flutter run --dart-define=DEVICE_MODE=sim --dart-define=BACKEND_MODE=mock
```

Debug APK already built with those two defines:

`D:\the work\flolabs\caipo_app\app\build\app\outputs\flutter-apk\app-debug.apk`

On that APK: any email and password signs in, Refresh finds `CAIPO-SIM`, connect runs the voice loop. Visible states: Listening, Processing, Sending, Done.

Last check after Phase 1: `flutter test` 43 passed, `flutter analyze` no issues.

## BLE contract (do not edit)

Service `a1000000-5fa6-43f5-9827-201f62bd377d`.

| Char | UUID tail | Role |
| --- | --- | --- |
| A1000001 | inbound | notify, device to phone |
| A1000002 | audio codec | read, one byte, only 21 is accepted |
| A1000003 | outbound | write, phone to device |
| A1000004 | command | notify + write, heartbeat and commands |

Suffix `5fa6-43f5-9827-201f62bd377d`. Advertised name prefix `CAIPO` (no dash). Battery `0x180F` / `0x2A19`. Device Information `0x180A` is read when present. Bonding is required (`kRequiresBond`). Android calls `createBond`. iOS `requestBond` returns true and does not start a bond; the firmware's encrypted characteristics raise the system dialog.

R03, little-endian. Opcodes: `0x01` REQUEST, `0x02` READY, `0x03` METADATA, `0x04` CHUNK, `0x05` ACK, `0x06` ERROR, `0x10` HEARTBEAT. Handshake messages are 3 bytes: opcode + uint16 transfer id. CHUNK header is 7 bytes, payload cap 502. METADATA is 14 bytes. CRC-32 is ISO-HDLC (zlib). SHA-256 exists in code and is not on the wire. Opus container both ways: `[uint16 LE length][frame]...`, 16 kHz mono, 20 ms, 320 samples, codec byte 21 only. `kMaxTransferBytes` is `32000000`. Sequence space is still `65536 * 502` and the header was not widened. Timeout 5 s, 3 resends, then TRANSFER_ERROR `0x05`. Discovery is by service UUID; a name is optional and, if present, must start with `CAIPO`. Heartbeat `0x10` is parsed and gaps are logged. The 3-second silence disconnect stays OFF (`kHeartbeatSilenceDisconnectEnabled = false`) until real firmware sends heartbeats.

iOS cannot request an MTU. The app reads `maximumWriteValueLength(for: .withResponse)` and uses `min(502, writeLength - 7)`. Android requests MTU 512 and returns `mtu - 3` as that write length. The receiver accepts any chunk payload up to 502, including chunks smaller than 502.

## What is done

### Phase 0

| Piece | State | Where |
| --- | --- | --- |
| In-app device `DEVICE_MODE=sim` | Done against the simulator | `lib/device/sim/sim_caipo_controller.dart`. Connects, codec 21, battery 87, heartbeat, R03 both ways. Recording is `assets/sim/speech.wav` encoded with libopus. Reply Opus is decoded to a WAV. |
| Mock FloBrain `BACKEND_MODE=mock` | Done, no socket | `lib/flobrain/mock_flobrain_interceptor.dart` on Dio. Sign-in, refresh, profile, chat with history. |
| Laptop mock HTTP server | Done as a script, the app does not use it | `tools/flobrain_mock/` on `127.0.0.1:8765`. |
| Laptop BLE peripheral | Partial | `tools/caipo_sim/`. `protocol.py` matches the Dart layout. `sim.py` uses `bless`. The radio path was never run on this machine. |

### Phase 1

| Piece | State | Where |
| --- | --- | --- |
| Send and receive R03 | Done in code, exercised on the in-app sim only | Writes on A1000003 via `DeviceConnection.writeOutbound`. Receive on A1000001 in `lib/device/protocol/device_transfer_session.dart`. |
| Save every received transfer | Done | `lib/device/protocol/transfer_archive.dart`. One file under app documents `transfers/`. The name has UTC time, content type, and size. |
| Real Opus | Done | `lib/device/audio/opus_codec.dart` (`opus_dart` + `opus_flutter`). Round-trip: `test/device/audio/opus_roundtrip_test.dart`. WAV parse/resample: `lib/device/audio/wav_pcm.dart`. |
| Chunk size, timeouts, handshake, 32,000,000 cap, discovery, heartbeat, codec 21 | Done | See STATUS. Tests in `test/device/protocol/` and `test/device/ble/`. |
| Voice loop in sim + mock | Done | `lib/features/conversation/voice_loop.dart`. Decode, canned STT, chat, mock TTS PCM from `assets/sim/reply.wav`, Opus encode, R03 content type `0x01`. |
| States, multi-turn, 30 s idle, cancel, retry | Done on the pairing screen | Listening, Processing, Sending, Done. One chat until idle or End session. Cancel drops the in-flight request. 429, 5xx, and timeouts retry with backoff in `lib/flobrain/api_client.dart`. |
| Live STT and TTS | Done as a hard failure | `UnavailableSpeechClient` throws `Speech to text is not available.` and `Text to speech is not available.` It does not return null or empty audio. |
| Encrypted history | Ciphertext is real, key storage is not | `lib/features/conversation/history_store.dart`. AES-GCM file in `history/`. The 256-bit key is in SharedPreferences until Phase 3 moves it to the Keychain / Android Keystore. |
| Integration test | Done | `test/voice/voice_loop_test.dart`. |

The only screens that render are sign-in (`lib/features/auth/auth_screen.dart`) and pairing (`lib/features/pairing/pairing_screen.dart`). After sign-in, `lib/main.dart` shows pairing only. There is no router.

## What is not done

### Phase 2 — screens (this is the next phase)

`lib/shared/theme/caipo_theme.dart` is one light Material 3 seed color. Missing: design tokens, dark mode, LED colors (blue standby, white boot, green video, yellow audio, red error or low battery, cyan charging, purple processing), screen-reader labels, dynamic text size, haptics, and one string catalog.

These files return `SizedBox.shrink()` and are not reachable:

- `lib/features/onboarding/onboarding_screen.dart`
- `lib/features/dashboard/dashboard_screen.dart`
- `lib/features/conversation/conversation_screen.dart` (history UI, replay, search, delete — the encrypted store exists, the screen does not)
- `lib/features/media_library/media_library_screen.dart`
- `lib/features/notifications/notifications_screen.dart`
- `lib/features/settings/settings_screen.dart` (auto-lock minutes already sit on the pairing screen)
- `lib/features/diagnostics/diagnostics_screen.dart`
- `lib/features/live_view/live_view_screen.dart` (Phase 4, not Phase 2)

Phase 2 also needs: dashboard (link, battery, state, last media, Talk to AI, Capture), conversation history UI, media library (audio waveform and 0.5x–2x, video fullscreen and picture-in-picture, share, delete), local notifications, settings (device info, rename, voice, language, auto-connect, cache, account), diagnostics (logs, RSSI, transfer speed, export, FAQ, bug report). Capture, LED, gestures, and OTA must be visible and disabled with "Needs device support". Do not invent those opcodes.

### Phase 3 — security

Tokens already use the Keychain / Android Keystore (`lib/flobrain/secure_token_store.dart`, pigeon `pigeons/secure_store_api.dart`). Still missing: media and history keys in that store (history key is in preferences today), biometric unlock, export and full deletion, and the written limitation that R03 has no resume so a retry restarts the transfer. Auto-lock of 1–60 minutes exists as a setting on the pairing screen; the plan's range is 1–30, default 15.

### Phase 4 — other teams, interfaces only

Do not invent contracts.

- Wi-Fi: `lib/device/wifi/provisioning.dart` and `lib/device/wifi/media_channel.dart` are stubs that do not send credentials. Write `docs/WIFI_CONTRACT_QUESTIONS.md`. No live view.
- Device commands: only heartbeat `0x10` exists on A1000004. Write `docs/COMMANDS_PROPOSAL.md` as a proposal for opcodes `0x20+`. Do not implement them as if firmware agreed.
- Advanced AI (image, video, custom prompts, offline): interfaces only, unless FloBrain already documents them. It does not.

### Partial or blocked outside the app

| Item | Owner | App behavior today |
| --- | --- | --- |
| ESP32-S3 GATT, heartbeat, encrypted characteristics | IoT | Real `DEVICE_MODE=ble` cannot be proven. No device. |
| HTTPS on `https://api.flobrain.ai` | Backend | DNS is fine. Port 443 was refused or timed out on 15 Oct 2026. Live client must stay on HTTPS. Do not switch it to HTTP. |
| Live auth JSON schema | FloBrain | Client sends `email`, `password`, and expects `access` and `refresh`. Those names are unconfirmed. Live mode must keep failing closed. |
| Live STT and TTS | FloBrain | App throws "not available". Do not return empty audio to hide this. |
| iOS build | Needs a Mac | Swift reads `maximumWriteValueLength`. It has not been compiled here. |
| Laptop `tools/caipo_sim/` radio | App | Protocol module is real. The `bless` peripheral was not run. |
| 3 s heartbeat silence disconnect | IoT, then app | Flag stays false. |

## Build notes that already cost time

- `permission_handler` is pinned to `12.0.3` in `pubspec.yaml`. Version 13 pulls `permission_handler_android` 14.x, which compiles against SDK 37. This project's Android Gradle Plugin 9.1.0 stops at compileSdk 36. Do not bump it without an AGP that accepts SDK 37.
- `opus_flutter_android` declares compileSdk 33 and minSdk 19. `android/build.gradle.kts` raises library modules to compileSdk 36 and minSdk 21 so NDK r28 and AndroidX will configure. The app minSdk stays 29.
- `android/gradle.properties` has `android.ndk.suppressMinSdkVersionError=21` and `kotlin.incremental=false` (the project path contains a space, which breaks Kotlin incremental caches and ndk-build).
- NDK required by Flutter is `28.2.13676358`. This machine had no Android SDK; one was installed at `D:\sdk\android` for the APK build. `ANDROID_HOME` may be unset in a new shell.
- Pigeon: `pigeons/ble_api.dart` owns the Kotlin/Swift `FlutterError` class. `pigeons/secure_store_api.dart` sets `includeErrorClass: false` so the two generated files in package `com.flolabs.caipo` do not both declare it. Regenerate with `dart run pigeon` after editing a pigeon file, then keep that split.
- `OpusEncoder` and `OpusDecoder` in `lib/device/audio/` throw. The real codec is `OpusCodec`. Do not make the old types return empty bytes.
- Real-time streaming is off. `PacketAssembler` throws. `kRealtimeAudioStreaming` is false.

## Suggested order for the next session

1. Read `docs/CAIPO_BUILD_PLAN.md` section 5 (Phase 2) and this file.
2. Do not change BLE UUIDs, opcodes, or live FloBrain field names.
3. Build the theme, string catalog, and the screens listed above. Wire navigation from the signed-in state. Keep sim and mock working.
4. Leave Capture, LED, gestures, OTA, Wi-Fi, and live view disabled or unimplemented, with the reason visible.
5. Finish with `flutter test`, `flutter analyze`, and `docs/STATUS.md`.
