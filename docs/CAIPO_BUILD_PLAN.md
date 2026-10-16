# CAIPO App: Full Build Plan

Put this file in the repo at `docs/CAIPO_BUILD_PLAN.md`. It is the source of truth for building the complete CAIPO companion app. The BLE contract already implemented in `lib/core/config/constants.dart` stays exactly as it is.

## 1. What the product does

CAIPO is a wearable. It records audio, stores it, then sends the whole recording to the phone over BLE. The app sends the recording to FloBrain AI, gets a reply, turns it into speech, and sends the reply audio back to CAIPO as one file. CAIPO stores it and plays it on its speaker. There is no real-time audio streaming over BLE. Camera, video, and live view go over Wi-Fi only. See section 9.

Main flow:

```
CAIPO records -> R03 transfer -> app decodes Opus -> STT -> FloBrain chat
-> TTS -> app encodes Opus -> R03 transfer -> CAIPO plays it
```

Platforms: iOS 15+, Android 10+ (API 29). Flutter, native BLE layers in Kotlin and Swift via Pigeon (already in place).

## 2. Ground rules

1. **No fake success.** Anything that depends on a missing outside piece (firmware, FloBrain endpoints, WiFi contract) goes behind an interface with two implementations: a clearly labeled simulator/mock and the real one. Switch with config: `DEVICE_MODE=sim|ble` and `BACKEND_MODE=mock|live`.
2. **Do not change the BLE contract.** If something in it looks wrong, write it in `docs/STATUS.md` under "Contract questions" and keep going.
3. **Do not invent FloBrain field names in live mode.** Placeholders stay in the mock only, and the live client fails clearly on a missing field.
4. **No permanent API keys inside the app.**
5. **Every phase ends with:** `flutter test` and `flutter analyze` clean, and `docs/STATUS.md` updated with a DONE / PARTIAL / NOT DONE list, marking which parts work for real and which only against the simulator.
6. **Stop after each phase** and wait for "continue".

## 3. Phase 0: Test infrastructure (build first)

Nothing can be tested end to end today because the firmware and FloBrain HTTPS are not ready. Build these so the whole app can run without them.

- **In-app simulated device** (`DEVICE_MODE=sim`): implements the full contract in memory. R03 in both directions, heartbeat 0x10 every 1 s, battery 0x180F, codec 21. It produces recordings from a bundled speech WAV encoded to the Opus container, and saves received reply audio to a file so it can be played back.
- **Laptop BLE peripheral simulator** in `tools/caipo_sim/` (Python, `bless` or similar): advertises as `CAIPO-SIM`, exposes the same service and characteristics, and speaks the same R03 protocol. This lets the real BLE stack on a real phone be tested before the firmware exists. Include a README with run steps for Windows and macOS.
- **Mock FloBrain server** in `tools/flobrain_mock/`: auth (login, refresh, logout), chat with conversation context, STT and TTS returning canned results. Same interfaces the live client uses.

Acceptance: the app runs fully in `sim` + `mock` mode with no hardware and no network.

## 4. Phase 1: Core voice loop (R01, R02, R03)

Finish the device link:

1. Wire `TransferManager` to BLE. Everything the app sends goes as writes on A1000003. The app works as sender and receiver on a live connection.
2. Save every received transfer to app storage (one file per transfer, with timestamp, content type and size).
3. Real Opus via libopus: 16 kHz mono, 20 ms frames, encode and decode with the `[uint16 len][frame]` container. Round-trip test.
4. Chunk payload from the negotiated MTU: `min(502, negotiatedMtu - 3 - 7)`. On iOS read `maximumWriteValueLength`. Receiver accepts any payload up to 502.
5. Timeouts: no reply within 5 s, resend the last unacknowledged message, up to 3 times, then TRANSFER_ERROR 0x05 and fail.
6. TRANSFER_REQUEST, TRANSFER_READY, TRANSFER_ACK are `[opcode][transfer id uint16 LE]`, 3 bytes.
7. Size limit constant = 32,000,000 bytes.
8. Discovery by service UUID; name optional, and if present it starts with `CAIPO`.
9. Parse heartbeat 0x10 on A1000004 explicitly (counter, log gaps). The 3 s rule stays OFF behind its flag until real firmware sends heartbeats.
10. Only codec 21 is supported. Any other value shows a clear error.

Then the AI loop:

- Received audio recording, decode to PCM, STT, FloBrain chat, TTS, encode Opus, send to CAIPO with R03 content type 0x01.
- Visible states: Listening, Processing, Sending, Done (R02.2).
- Multi-turn context; session ends after 30 s idle or on user command; a running request can be cancelled (R02.4).
- FloBrain errors: clear alert with retry; timeouts, rate limit and server errors retried with backoff (R02.1, R08.3).
- Conversation history stored locally, encrypted (R05.2).

Acceptance: an integration test runs the full loop against the simulated device and the mock backend.

## 5. Phase 2: Screens (R04, R05, R06, R09, R10, R12)

Design: one theme file with tokens, light and dark mode. CAIPO state colors match the device LED: blue standby, white boot, green video, yellow audio, red error or low battery, cyan charging, purple processing. Accessibility: screen-reader labels, dynamic text size, haptics on key actions (R04.3). UI strings in one place, ready for translation.

- **Onboarding:** short intro, permissions asked just in time (R07.3), first pairing.
- **Dashboard (R04.1):** connection status, battery, CAIPO state, last media, "Talk to AI" and "Capture" buttons.
- **Conversation:** history with transcripts, replay last answer (R02.3), search, delete one or all (R05.2).
- **Media library (R05.3, R06):** audio, video, photos with metadata. Audio playback with waveform and speed 0.5x to 2x. Video player with fullscreen and picture-in-picture. Share and delete. Transcript synced with playback where available (R06.3).
- **Notifications (R09):** local notifications for low battery, connection lost, transfer done; in-app banners; user preferences.
- **Settings (R10):** device info (firmware, MAC, serial; read Device Information Service 0x180A if present), rename device, AI voice and language, auto-connect, cache. Account: profile, password, logout, delete account.
- **Diagnostics and support (R12):** connection logs, error history, live RSSI and transfer speed, export logs, help/FAQ, bug report with logs attached.

Controls that need device commands that do not exist yet (Capture, LED, gestures, OTA) are shown disabled with "Needs device support".

## 6. Phase 3: Security and robustness (R07, R08)

- Media and history encrypted at rest with AES-256, key in Keychain / Android Keystore. BLE encryption comes from bonding. TLS for all network calls.
- Optional biometric unlock; auto-lock after 1 to 30 minutes, configurable (default 15).
- Data export and full data deletion (GDPR / CCPA).
- Failed transfers retried up to 3 times with backoff; partial files kept locally. The protocol has no resume, so a retry restarts the transfer. Write this limitation in STATUS.md.

## 7. Phase 4: Parts that need other teams (interfaces and proposals only)

Do not invent contracts here. Build interfaces with simulator implementations and write proposals for the team to approve. The connectivity update in section 9 is the proposed Wi-Fi stream and command table. Advanced AI stays an interface until FloBrain defines it.

- **WiFi media (camera, live view):** no contract exists. Build the interfaces and a simulator. Write `docs/WIFI_CONTRACT_QUESTIONS.md` with the questions the IoT team must answer (provisioning, who hosts the network, transport, endpoints, file formats).
- **Device commands** (Capture, LED, gestures, OTA update): only heartbeat 0x10 exists on A1000004. Write `docs/COMMANDS_PROPOSAL.md` with a proposed opcode table in the 0x20+ range. Mark it as a proposal.
- **Advanced AI (R11):** image and video input, custom system prompts, offline AI. Interfaces only, unless FloBrain already supports them.

## 8. Known outside blockers (track in STATUS.md)

| Blocker | Owner |
| --- | --- |
| BLE GATT, heartbeat, encrypted characteristics on the ESP32-S3 | IoT |
| HTTPS on `api.flobrain.ai` (443 refused today) | Backend |
| Real JSON schema for auth and tokens | FloBrain |
| STT and TTS endpoints | FloBrain |
| WiFi media contract | IoT |
| Device command opcodes | IoT |
| Mac to build and test iOS | Team |

## 9. Connectivity, FloBrain, and proposed contracts

Anything here that needs firmware or a backend route that does not exist yet is PROPOSED. Each proposed piece has a build flag, off by default: `PROPOSED_SPEECH`, `PROPOSED_MEDIA`, `PROPOSED_COMMANDS`, `PROPOSED_WIFI`. With the flag off the app does not call the route or write the opcode.

### Connectivity

- BLE is always on: voice with the AI, commands, status, and provisioning. It works anywhere the phone is nearby, including with the screen locked. Android uses the connected-device foreground service. iOS uses bluetooth-central restoration.
- Wi-Fi is for everything from the camera: photos, video, and live streaming. Nothing from the camera goes over BLE.
- The Raspberry Pi uploads photos and videos straight to FloBrain/S3. The app shows them by reading from FloBrain.
- CAIPO keeps a list of saved Wi-Fi networks (home, work, the phone hotspot). With no known network it stores media and uploads later.
- Outside, the phone's mobile data is the AI gateway over BLE.
- The app cannot turn on a phone hotspot that has internet. iOS never can. Android 8+ can only start a local-only hotspot. The user turns the hotspot on.

### FloBrain

Confirmed routes, called over HTTPS only:

- Auth: `POST /api/auth/register/`, `/api/auth/signin/`, `/api/auth/signout/`, `/api/auth/refresh/`. Refresh on 401.
- Profile: `GET`/`PATCH /api/profile/`, `POST /api/profile/change-password/`, `POST /api/profile/delete/`.
- Settings: `/api/settings/preferences/` (`GET`/`POST`/`PATCH`/`DELETE`).
- Chats: `GET`/`POST /api/brain/chats/`, `GET`/`PATCH`/`DELETE /api/brain/chats/{id}/`, `POST /api/brain/chats/{id}/send/` with text and an optional image.
- Health: `GET /api/dashboard/health/` with no token.
- Errors: `{"error": "...", "details": "..."}`.

The OpenAPI document is `GET /api/schema/`. A read-only fetch may use port 80 and must send no credentials. Authenticated calls stay on HTTPS. Never send tokens or passwords over HTTP.

PROPOSED, flag off:

- `POST /api/speech/transcribe/` — WAV 16 kHz mono, response `{"text": "..."}`.
- `POST /api/speech/synthesize/` — `{"text": "...", "voice": "..."}`, response WAV 16 kHz mono.
- `GET /api/media/` and `GET /api/media/{id}/` — media the Pi uploaded.

With the speech flag off, live STT and TTS still fail with "not available".

### Device commands

Proposal only, on A1000004. Table in `docs/COMMANDS_PROPOSAL.md`. LED, gestures, and OTA stay disabled with "Needs device support". Camera controls show "Needs WiFi" when a received STATUS has Wi-Fi flag bit 4 clear. They are not sent while `PROPOSED_COMMANDS` is off.

### Wi-Fi provisioning

Proposal only. One R03 transfer, content type `0x04`, JSON:

```json
{"networks": [{"ssid": "...", "password": "..."}], "device_token": "..."}
```

Up to 5 networks, priority order, and only on a bonded link. Settings has "CAIPO WiFi networks" (add, remove, reorder) including "My phone hotspot" with the note to turn the hotspot on outside. Nothing is written while `PROPOSED_WIFI` is off.

### Live streaming

Proposed, behind `PROPOSED_STREAM`, off by default. Direct on the local network (same Wi-Fi or the phone hotspot): MJPEG over HTTP, 640×480 at 15 fps.

On A1000004, and in `docs/COMMANDS_PROPOSAL.md`:

- `0x27` START_STREAM, app to device, no payload
- `0x28` STREAM_READY, device to app: `[IPv4 4 bytes][port uint16 LE][token 16 bytes]`
- `0x29` STOP_STREAM, app to device

The app opens `http://<ip>:<port>/stream?token=<token as hex>`. The device stops the stream itself after 2 minutes.

Live view shows "Starting camera..." while the Pi boots (5–15 seconds) and an auto-stop countdown. iOS local-network permission (`NSLocalNetworkUsageDescription`) is asked when Live view starts, not at launch. CAIPO-SIM answers START_STREAM with a local MJPEG stream made from the bundled sample video. Capture, Record video, and Live view show "Needs WiFi" when STATUS flag bit 4 is 0. With the flag off, the app does not send these opcodes and does not play a sample as if it were the camera.

`docs/WIFI_CONTRACT_QUESTIONS.md` only asks what this proposal leaves open, including remote viewing from anywhere later.

### Outside the home

- Dashboard shows how many items are waiting to upload, from STATUS, and an "Upload now" button (`SYNC_NOW`). If Wi-Fi is not connected, show the hotspot hint. With the command flag off, the row says the commands are off and the button does nothing.
- No phone internet: keep the recording in history as "Not sent" with Retry. Do not drop it.
- Device disconnected: keep reconnecting in the background. Recordings the device still holds are accepted when the link returns. The device storing them while the phone is gone is firmware, not this app.

### Field test

`docs/FIELD_TEST.md` is the checklist for a later day on real hardware.
