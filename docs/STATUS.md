# CAIPO status

Current state of the whole app on 16 Oct 2026. Version `1.0.0 (1)`. A plain-language tour is in `learn.md`. The plan is `docs/CAIPO_BUILD_PLAN.md`.

The app is the phone companion. It pairs with CAIPO over Bluetooth, runs the voice loop, and stores the conversation and media on the phone. It is not the wearable, and it is not the FloBrain server.

Two build-time switches pick the device and the backend. They are not a switch inside the app.

```bash
flutter run --dart-define=DEVICE_MODE=sim --dart-define=BACKEND_MODE=mock
```

With no flags, the default is `DEVICE_MODE=ble` and `BACKEND_MODE=live`. `sim` is the in-app device CAIPO-SIM. `ble` is the real radio. `mock` never opens a socket. `live` calls `https://api.flobrain.ai`.

`PROPOSED_SPEECH`, `PROPOSED_MEDIA`, `PROPOSED_COMMANDS`, `PROPOSED_WIFI`, and `PROPOSED_STREAM` are off. Off means the route is not called and the opcode is not written.

Last app verification on this tree, before the later documentation commits: `flutter test` 58 passed, `flutter analyze` clean.

## Where the product stands

| Area | State | What is true now |
| --- | --- | --- |
| Pairing and R03 | DONE in code, exercised on CAIPO-SIM | Scan, bond, GATT, transfers both ways. Not exercised on an ESP32. |
| Voice loop | DONE on sim + mock | Opus decode, canned speech-to-text, FloBrain chat, mock speech synthesis, Opus encode, reply played on the phone speaker. |
| Live speech | Hard failure | `Speech to text is not available.` and `Text to speech is not available.` No empty transcript and no empty audio. |
| FloBrain live client | PARTIAL | HTTPS client, `Token` prefix, refresh on 401, health with no token. Sign-in token JSON is still fail-closed. |
| Screens | DONE | Onboarding, pairing, Dashboard, Conversation, Library, Settings, Notifications, Diagnostics, About. |
| Library video and photos | PARTIAL | Audio clips play. Photos and video stay empty unless a transfer of that type exists. No video player and no picture-in-picture. |
| Encryption and privacy | DONE | History and media keys in the platform store. Export and delete-all-local-data work. Biometric unlock is optional and off. |
| Camera, LED, gestures, OTA | Disabled | The buttons say why. Default copy is `Needs device support`. No confirmed command opcodes were added. |
| Wi-Fi, live view, device commands | PROPOSED, flags off | Code and docs exist. The default build does not send them. |
| Advanced AI | NOT AVAILABLE | Image, video, system prompt, and offline AI are not in the FloBrain schema. Settings says so. |
| Field test on hardware | NOT DONE | Checklist is `docs/FIELD_TEST.md`. It has not been run on a device. |

## What the user can do

After sign-in and a three-page intro, the bottom bar is Dashboard, Conversation, Library, and Settings. Notifications and Diagnostics open from the app bar and from Settings. Bluetooth permission is asked when a scan starts, not on the intro. The pairing screen only pairs.

| Screen | Behavior |
| --- | --- |
| Dashboard | Connection, battery, LED color, last saved file, Talk to AI. Capture, LED, gestures, and firmware update respond with the reason they cannot run. |
| Conversation | Encrypted history, search, delete one, delete all, voice controls. Replay plays the reply WAV on the phone speaker in sim mode. |
| Library | Waveform and speeds 0.5x–2x, share, delete. Reply text sits next to the clip. FloBrain does not return word times, so captions are not synced to playback. |
| Settings | Device info when GATT returned it, rename, voice and language kept on the phone, auto-connect, biometric unlock, up to 5 Wi-Fi networks, transfer cache, export, delete local data, profile, password, sign out, delete account, About. Auto-lock is 1–30 minutes, default 15. |
| Diagnostics | Recent logs, errors, RSSI when the scan reported it, reply-transfer timing, export, FAQ, bug report with the log attached. |

Every main screen has a loading, empty, or error state. A control that cannot run still responds. There is no fake success.

LED colors in `lib/shared/theme/caipo_tokens.dart`: blue standby, white boot, green video, yellow audio, red error or low battery, cyan charging, purple processing. Brand colors and the font are neutral placeholders. Charging and video lights are not driven: the device does not report charging, and this build has no video state.

App name is `CAIPO` on Android, iOS, and the Flutter title. The icon and splash are a placeholder: dark ground `#1B1524`, purple ring. About shows version `1.0.0 (1)`, BLE contract `GATT A1000000–A1000004, heartbeat 0x10, R03`, and the current device and backend mode.

## Voice loop

1. The device sends an Opus recording, content type `0x01`.
2. The app decodes it.
3. Text goes to a FloBrain chat.
4. The text reply is encoded and sent back.
5. The history line is stored only after the reply succeeds.

States shown: Listening, Processing, Sending, Done. One chat lasts until 30 seconds idle or End session. Cancel drops the in-flight request. Timeouts, 429, and 5xx retry with backoff. A failed turn is kept as `Not sent` with Retry. The recording is encrypted with the history key.

On CAIPO-SIM the sample is `assets/sim/speech.wav`. The reply is decoded to WAV under app documents and played on the phone speaker. After connect the pairing line says `Connected to CAIPO-SIM.`

## Device link

Confirmed identity, unchanged: service `a1000000-5fa6-43f5-9827-201f62bd377d`, characteristics `A1000001` (notify, inbound) through `A1000004` (commands and heartbeat), advertised name prefix `CAIPO`. Codec byte 21 is the only accepted value. A missing or other codec stops the voice loop.

| Piece | State |
| --- | --- |
| R03 both ways | Writes on A1000003. Receives on A1000001. Exercised against CAIPO-SIM, not an ESP32. |
| Saved transfers | One sealed file per transfer under app documents `transfers/`. The name has the UTC time, content type, and size. |
| Opus | 16 kHz mono, 20 ms, libopus. Container `[uint16 length][frame]...`. Round-trip test passed. |
| Chunk size | `min(502, maximumWriteLength - 7)`. iOS reads `maximumWriteValueLength` and does not request an MTU. Android uses the negotiated ATT payload (`mtu - 3`) after `requestMtu(512)`. The receiver accepts any payload up to 502. |
| Timeouts | No reply within 5 s resends the last unacknowledged message, up to 3 times, then writes TRANSFER_ERROR `0x05` and fails. |
| Handshake | TRANSFER_REQUEST, TRANSFER_READY, and TRANSFER_ACK are opcode plus a uint16 transfer id. |
| Size cap | `kMaxTransferBytes` is 32,000,000. The uint16 sequence space is still 32,899,072. The header was not widened. |
| Discovery | Service UUID is enough. A name, when present, must start with `CAIPO`. |
| Heartbeat `0x10` | Parsed on A1000004. Counter gaps are logged. `kHeartbeatSilenceDisconnectEnabled` stays false until real firmware sends heartbeats. |
| Background | Android connected-device foreground service. iOS `bluetooth-central` restoration id `com.flolabs.caipo.ble`. |
| Resume | R03 has no resume. A retry starts at chunk 0. Bytes already received are a sealed `partial_` file, not a continue point. |

`permission_handler` stays at 12.0.3. Version 13 pulls compileSdk 37, and this Android Gradle plugin stops at 36. `local_auth` stays at 2.3.0.

## FloBrain

Authenticated calls stay on HTTPS. A read-only `GET http://api.flobrain.ai/api/schema/` on 16 Oct 2026 returned the OpenAPI document (200, `application/vnd.oai.openapi`, 11,748 bytes, no credentials).

The document confirms the route list, `current_password`, `new_password`, delete body `password`, profile `fullName` and `email`, and Authorization prefix `Token`. It does not define the sign-in token JSON, so `access` and `refresh` stay fail-closed. Sign-out sends `refresh_token` only. `userId` is not sent. Health `GET /api/dashboard/health/` sends no token.

`/api/settings/preferences/` has no voice or language fields. Those settings stay on the phone.

The mock backend is inside the app at `http://mock.flobrain.local`. `tools/flobrain_mock/server.py` is a separate laptop stand-in on `127.0.0.1:8765`. Unit tests use a scripted adapter or the in-app mock. They do not call the live host.

## Security

AES-256-GCM. History key `caipo.history.aes.key` and media key `caipo.media.aes.key` are in the Keychain / Android Keystore. A history key left in preferences is moved once and then removed.

A finished transfer is sealed in the BLE callback before it is written, including while the screen is locked or the process is backgrounded. The same cipher seals a dropped transfer's partial file. Reply WAVs are sealed after the simulator writes them. Native BLE code does not write transfer files.

Export shares conversation JSON only. It does not include Wi-Fi passwords or keys. Delete all local data clears history, media, saved Wi-Fi, and the on-device keys, then signs out. It does not call FloBrain. Delete account is the separate remote call and asks for the password.

Biometric unlock is off until Settings turns it on. Password sign-in stays available. Auto-lock default is 15 minutes.

## Proposed, off by default

| Flag | What the code would do if turned on | Default build |
| --- | --- | --- |
| `PROPOSED_SPEECH` | Proposed transcribe and synthesize routes | Throws "not available". Routes are not called. |
| `PROPOSED_MEDIA` | `GET /api/media/` | Not called. |
| `PROPOSED_COMMANDS` | `0x20`–`0x26` and `0x2F` on A1000004, documented in `docs/COMMANDS_PROPOSAL.md` | Not written. Only the confirmed heartbeat path uses A1000004. |
| `PROPOSED_WIFI` | One R03 transfer, content type `0x04`, up to 5 networks, only on a bonded link | Settings can edit the list. Send returns without writing. `device_token` is empty because nothing issues it. |
| `PROPOSED_STREAM` | `0x27` START_STREAM, `0x28` STREAM_READY, `0x29` STOP_STREAM. MJPEG `http://<ip>:<port>/stream?token=<hex>`, 640×480 at 15 fps, device stops after 2 minutes | Opcodes are not written. Live view stays off and does not play the sample as a camera. |

CAIPO-SIM can answer START_STREAM with a local MJPEG stream from `assets/sim/stream/` when those bytes are actually written. iOS `NSLocalNetworkUsageDescription` is asked when Live view starts, not at launch. Capture, Record video, and Live view say `Needs WiFi` only when a STATUS frame has bit 4 clear. With the command flag off there is no STATUS frame, so the UI says `Needs device support`.

Open gaps, not BLE changes, are in `docs/WIFI_CONTRACT_QUESTIONS.md`: remote viewing from anywhere, who creates `device_token`, and the media JSON.

Outside the home: the upload count and Upload now wait on STATUS, so they stay disabled while the command flag is off. Reconnect after a drop is the existing background link. The device keeping recordings while the phone is away is firmware and is not verified. The app cannot turn on a phone hotspot. Settings says the user turns it on.

## Builds

| File | Defines |
| --- | --- |
| `build/apk/caipo-sim.apk` | `DEVICE_MODE=sim`, `BACKEND_MODE=mock`, proposed flags off |
| `build/apk/caipo-live.apk` | `DEVICE_MODE=ble`, `BACKEND_MODE=live`, proposed flags off |

Both were built on 16 Oct 2026 and are still on disk. They are debug APKs and are not committed. `build/app/outputs/flutter-apk/app-debug.apk` is the last Gradle output, not a third labeled build.

On `caipo-sim.apk`: any email and password signs in. Pair with CAIPO-SIM, then Talk to AI. Play reply uses the phone speaker, and the library lists that clip. About shows `sim / mock`. Export shares the conversation. Delete all local data wipes it and signs out.

On `caipo-live.apk`: the app looks for a real CAIPO and calls `https://api.flobrain.ai`. Sign-in fails closed when the token fields are missing. Capture, Record video, Live view, LED, gestures, and OTA say why they cannot run. Live view does not show a picture.

## Contract questions

Authorization prefix: the Notion doc says `Bearer`. The live OpenAPI schema (`tokenAuth`, fetched 16 Oct 2026) says `Token`. The app uses one constant, `kAuthorizationPrefix`, default `Token`, until the backend confirms it.

`/api/settings/preferences/` defines no voice or language fields. Those settings stay on the phone.

None on the confirmed BLE contract. iOS does not request an MTU.

R03 has no resume.

Wi-Fi questions are only the gaps in `docs/WIFI_CONTRACT_QUESTIONS.md`.

## Still not real

| Item | Owner |
| --- | --- |
| ESP32-S3 GATT, heartbeat, encrypted characteristics | IoT |
| HTTPS on `api.flobrain.ai` | Backend. Port 443 was refused from this machine on 15 Oct 2026. Port 80 answered the schema GET. Authenticated calls stay on HTTPS. |
| Live sign-in token JSON | FloBrain. `access` and `refresh` stay fail-closed. |
| Live STT and TTS | FloBrain. The app fails these calls on purpose. |
| 3 second heartbeat silence rule | Off until firmware heartbeats exist. |
| iOS build | Needs a Mac. The write-length call is in the Swift stack. |
| Confirmed Wi-Fi media contract and device command opcodes | IoT. The proposal stays behind flags. |
| Video playback and picture-in-picture | App, once a video file exists. The library does not invent one. |
| Laptop BLE peripheral `tools/caipo_sim/` | PARTIAL. It is not the in-app simulator, and the radio path was not run. |
| Field test | Checklist written. Not run on hardware. |
