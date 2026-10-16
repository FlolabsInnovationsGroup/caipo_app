# CAIPO status

Updated after Phase 3, Phase 4, and the final polish of `docs/CAIPO_BUILD_PLAN.md`.

Run the voice loop with no radio and no FloBrain network:

```bash
flutter run --dart-define=DEVICE_MODE=sim --dart-define=BACKEND_MODE=mock
```

Defaults stay `ble` and `live`.

## Phase 1

| Piece | State | What is real |
| --- | --- | --- |
| App sends and receives R03 | DONE in code | Writes go out on A1000003. The same session receives on A1000001. Exercised against CAIPO-SIM, not against an ESP32. |
| Received transfers saved | DONE | One file per transfer under app documents `transfers/`. The name has the UTC time, content type, and size. |
| Opus 16 kHz mono, 20 ms | DONE | libopus via `opus_dart`. Container is `[uint16 length][frame]...`. Round-trip test passed. |
| CAIPO-SIM audio | DONE against the simulator | The recording is `assets/sim/speech.wav`, encoded to Opus. Replies are decoded and saved as WAV. |
| Chunk size | DONE | `min(502, maximumWriteLength - 7)`. iOS reads `maximumWriteValueLength(for: .withResponse)`. The app does not request an MTU on iOS. Android returns the negotiated ATT payload (`mtu - 3`) after `requestMtu(512)`. The receiver accepts any payload up to 502. |
| Timeouts | DONE | No reply within 5 s resends the last unacknowledged message, up to 3 times, then writes TRANSFER_ERROR 0x05 and fails. |
| Handshake layout | DONE | TRANSFER_REQUEST, TRANSFER_READY, and TRANSFER_ACK are opcode plus a uint16 transfer id. |
| Size cap | DONE | `kMaxTransferBytes` is 32,000,000. The uint16 sequence space is still 32,899,072. The header was not widened. |
| Discovery | DONE | Service UUID is enough. A name, when present, must start with `CAIPO`. |
| Heartbeat 0x10 | DONE, silence rule off | Parsed on A1000004. Counter gaps are logged. `kHeartbeatSilenceDisconnectEnabled` stays false until real firmware sends heartbeats. |
| Codec | DONE | Only 21 is accepted. Any other value, or a missing read, is shown as an error and the voice loop does not run. |
| Voice loop | DONE in sim + mock | Decode, canned STT, FloBrain chat, mock TTS PCM, Opus encode, R03 content type 0x01. States shown: Listening, Processing, Sending, Done. |
| Multi-turn, idle, cancel | DONE | One chat until 30 s idle or End session. Cancel drops the in-flight request. |
| FloBrain errors | DONE | Timeouts, 429, and 5xx still retry with backoff. A failed turn shows an alert with Retry. |
| Live STT and TTS | DONE as a hard failure | `Speech to text is not available.` and `Text to speech is not available.` They do not return empty audio or an empty transcript. |
| Conversation history | DONE | AES-GCM file in app documents `history/`. The 256-bit key is in the Keychain / Android Keystore. A key left in preferences is moved once and then removed. |
| Integration test | DONE | `test/voice/voice_loop_test.dart` runs the loop on CAIPO-SIM and the mock backend. |

`flutter test` after Phase 1: 43 passed. `flutter analyze`: no issues.

## Phase 2

| Piece | State | What is real |
| --- | --- | --- |
| Tokens, light and dark | DONE | `lib/shared/theme/caipo_tokens.dart` holds colors, the font choice, and spacing. Brand colors and the font are neutral placeholders. LED colors are the listed values: blue standby, white boot, green video, yellow audio, red error or low battery, cyan charging, purple processing. |
| Strings | DONE | `lib/shared/copy/app_strings.dart` is the catalog. |
| Accessibility | DONE | Screen-reader labels on the state light, auto-lock, and disabled actions. Text uses the theme, so the system text size applies. Key actions use a haptic tap. |
| Navigation | DONE | Bottom bar: Dashboard, Conversation, Library, Settings. Notifications and Diagnostics open from the app bar and from Settings. |
| Onboarding | DONE | Three short pages. Bluetooth permission is still requested when a scan starts, not on the intro. |
| Pairing screen | DONE | It only lists and connects devices. Voice controls and auto-lock are gone. The simulated-device line changes with the link: after connect it says `Connected to CAIPO-SIM.` |
| Dashboard | DONE | Connection, battery, LED state, last saved file, Talk to AI. Capture, LED, gestures, and firmware update are disabled with "Needs device support". No command opcodes were added. |
| Conversation | DONE | Encrypted history, search, delete one, delete all, and the voice controls. Replay plays the decoded reply WAV on the phone speaker in sim mode. |
| Library | PARTIAL | Audio clips play with a waveform and speeds 0.5x–2x. Share and delete work. Photos and video stay empty unless a transfer of that type exists. There is no video player and no picture-in-picture, because the device has not sent video. |
| Transcript sync | PARTIAL | The reply text is shown next to the clip. FloBrain does not return word times, so captions are not synced to playback. |
| Notifications | DONE in the app, OS tray depends on permission | In-app banner and a list. Preferences for low battery, connection lost, and transfer done. Android and iOS also post a local notification after the user allows it. |
| Settings | DONE | Device info when the GATT session returned it, rename, AI voice and language kept on the phone, auto-connect, biometric unlock, transfer cache, export, delete local data, profile, password, sign out, delete account, About. Auto-lock is a 1–30 minute slider, default 15. |
| Diagnostics | DONE | Recent log lines, error lines, RSSI when the scan reported it, timed reply-transfer speed, export, FAQ, and a bug report that attaches the log. |
| LED charging and video | NOT DRIVEN | The colors are in the token file. The device does not report charging, and this build has no video state, so those lights are never shown as the current state. |

`flutter test`: 47 passed. `flutter analyze`: no issues.

Debug APK for a phone, built with `DEVICE_MODE=sim` and `BACKEND_MODE=mock`:

`build/app/outputs/flutter-apk/app-debug.apk`

Sign in with any email and password, finish the short intro, pair with CAIPO-SIM, then use Talk to AI on the dashboard or Conversation. Play reply uses the phone speaker.

`permission_handler` is pinned to 12.0.3. Version 13 pulls an Android plugin that compiles against SDK 37, and this Flutter Android Gradle plugin stops at 36.

## Connectivity update (sections 1–7)

Flags `PROPOSED_SPEECH`, `PROPOSED_MEDIA`, `PROPOSED_COMMANDS`, `PROPOSED_WIFI`, and `PROPOSED_STREAM` are off in this build. Off means the route is not called and the opcode is not written.

| Section | State | What is real |
| --- | --- | --- |
| 1. Connectivity design | DONE as the app's rules | BLE stays the always-on link, including the Android foreground service and the iOS restore id. Camera bytes are not sent over BLE. The Pi upload and the phone hotspot are not something this app can perform. The hotspot note is in Settings. |
| 2. FloBrain API | PARTIAL | A read-only `GET http://api.flobrain.ai/api/schema/` on 16 Oct 2026 returned the OpenAPI document (200, `application/vnd.oai.openapi`, no credentials). Authenticated calls stay on HTTPS. The document confirms the route list, `current_password`, `new_password`, delete body `password`, profile `fullName` and `email`, and Authorization prefix `Token`. It does not define the sign-in token JSON, so `access` and `refresh` stay fail-closed. Sign-out sends `refresh_token` only. `userId` is not sent because the document does not say where it comes from. Health `GET /api/dashboard/health/` is implemented with no token. Proposed speech and media clients exist and throw "not available" while their flags are off. |
| 3. Device commands | PROPOSED, flag off | Codec and parser are in `lib/device/protocol/proposed_commands.dart`. `docs/COMMANDS_PROPOSAL.md` is the table. Nothing is written on A1000004 except the confirmed heartbeat path. LED, gestures, and OTA stay "Needs device support". |
| 4. Wi-Fi provisioning | PROPOSED, flag off | Settings can add, remove, and reorder up to 5 networks, stored in the platform secure store. Send checks the flag and the bond, then returns without writing. |
| 5. Live streaming | PROPOSED, flag off | MJPEG over HTTP on the local network, 640×480 at 15 fps. Opcodes `0x27` START_STREAM, `0x28` STREAM_READY, `0x29` STOP_STREAM are in the proposal and are not written while `PROPOSED_STREAM` is off. The screen has "Starting camera..." and a 2-minute countdown. CAIPO-SIM serves a local MJPEG stream from the bundled sample frames when START_STREAM is actually sent. iOS `NSLocalNetworkUsageDescription` is present and the prompt is tied to opening Live view. Capture, Record video, and Live view show "Needs WiFi" when a STATUS frame has bit 4 clear. The default build does not play the sample as a live camera. `docs/WIFI_CONTRACT_QUESTIONS.md` now only covers gaps, including remote viewing from anywhere later. |
| 6. Outside the home | PARTIAL | A failed voice turn is stored as "Not sent" with Retry, and the audio is encrypted with the history key. Upload count and Upload now wait on STATUS, so they stay disabled while the command flag is off. Reconnect after a drop is the existing background link. The device keeping recordings while the phone is away is firmware and is not verified. |
| 7. Field test | DONE as a checklist | `docs/FIELD_TEST.md`. It has not been run on hardware. |

## Phase 3

| Item | State | What is real |
| --- | --- | --- |
| History and media keys | DONE | AES-256-GCM. Keys are in the platform secure store (`caipo.history.aes.key`, `caipo.media.aes.key`), not preferences. A finished transfer is sealed in the BLE callback before it is written, including while the screen is locked or the app is in the background. Android keeps that callback alive with the connected-device foreground service. iOS uses bluetooth-central restoration. There is no separate plaintext path for a background transfer. A dropped transfer's partial file is sealed the same way. |
| Biometric unlock | DONE, optional | Off until Settings turns it on. After auto-lock the lock screen can use biometrics. Password sign-in stays available. |
| Export and deletion | DONE | Export shares the conversation JSON. Delete all local data removes conversation, media, saved Wi-Fi, and the on-device keys, then signs out. It does not call FloBrain. Delete account is still the remote call. |
| R03 resume | LIMITATION | R03 has no resume. A retry restarts the transfer. The app retransmits a failed chunk up to 3 times, and a new transfer starts at the first chunk. Bytes already received are kept as a `partial_` file. That file is not a place to continue from. |

## Phase 4

| Item | State | What is real |
| --- | --- | --- |
| Wi-Fi media and live view | PROPOSED, flag off | `docs/WIFI_CONTRACT_QUESTIONS.md` and the MJPEG proposal in section 5. |
| Device commands | PROPOSED, flag off | `docs/COMMANDS_PROPOSAL.md`. LED, gestures, and OTA stay "Needs device support". |
| Advanced AI | NOT AVAILABLE | Image input, video input, custom system prompts, and offline AI are not in the FloBrain schema. The client methods fail closed and Settings says so. |

## Final polish

| Item | State | What is real |
| --- | --- | --- |
| App name | DONE | The Android label, the iOS display name, and the Flutter title are `CAIPO`. |
| Icon and splash | DONE | Placeholder mark: dark ground, purple ring. Android launcher icons and `splash_mark` use it. The splash background is `#1B1524`. The iOS launch screen uses the same ground. |
| Loading, empty, error | DONE | Conversation shows a progress line, an empty line, or an error. Settings shows a progress line while the profile loads, then the email or an error. Pairing, the library, notifications, and diagnostics have empty lines. Live view has Starting camera, the picture, and a stopped or off state. A control that cannot run still responds and says why. |
| About | DONE | Settings > About shows version `1.0.0 (1)`, BLE contract `GATT A1000000–A1000004, heartbeat 0x10, R03`, and the current device and backend mode. |
| Debug APKs | DONE | `build/apk/caipo-sim.apk` is `DEVICE_MODE=sim` and `BACKEND_MODE=mock`. `build/apk/caipo-live.apk` is `DEVICE_MODE=ble` and `BACKEND_MODE=live`. |

`flutter test`: 58 passed. `flutter analyze`: no issues.

## What a tester can try

On `caipo-sim.apk`: any email and password signs in. Pair with CAIPO-SIM, then Talk to AI. Play reply uses the phone speaker, and the library lists that clip. Settings > About shows `sim / mock`. Export my data shares the conversation. Delete all local data wipes it and signs out. Auto-lock is 1–30 minutes. Biometric unlock stays off until it is turned on.

On `caipo-live.apk`: the app looks for a real CAIPO over Bluetooth and calls `https://api.flobrain.ai`. Sign-in fails closed when the token fields are missing. Capture, Record video, Live view, LED, gestures, and OTA say why they cannot run. Live view does not show a picture while `PROPOSED_STREAM` is off.

## Contract questions

Authorization prefix: the Notion doc says `Bearer`. The live OpenAPI schema (`tokenAuth`, fetched 16 Oct 2026) says the prefix is `Token`. The app uses one constant, `kAuthorizationPrefix`, and it defaults to `Token`. This stays open until the backend confirms which prefix live traffic must send.

`/api/settings/preferences/` is in the schema and defines no voice or language fields. Those settings stay on the phone.

None on the confirmed BLE contract. iOS does not request an MTU. Chunk size comes from `maximumWriteValueLength`.

R03 has no resume. A retry restarts the transfer.

Open Wi-Fi questions are only the gaps in `docs/WIFI_CONTRACT_QUESTIONS.md` (remote viewing, `device_token`, media JSON). They are not changes to the BLE contract.

## Still not real

| Item | Owner |
| --- | --- |
| ESP32-S3 GATT, heartbeat, encrypted characteristics | IoT |
| HTTPS on `api.flobrain.ai` | Backend |
| Live auth JSON schema | FloBrain |
| Live STT and TTS | FloBrain. The app fails these calls on purpose. |
| 3 second silence rule | Off until firmware heartbeats exist |
| History key in the platform keystore | Done in Phase 3. |
| iOS build | Needs a Mac. The write-length call is in the Swift stack. |
| Wi-Fi media contract and device command opcodes | IoT, Phase 4 |
| Video playback and picture-in-picture | App, once a video file exists. The library does not invent one. |
| Laptop BLE peripheral `tools/caipo_sim/` | PARTIAL. It is not the in-app simulator, and the radio path was not run. |
