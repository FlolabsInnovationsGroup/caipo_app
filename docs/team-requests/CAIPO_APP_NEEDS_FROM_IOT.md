# What the CAIPO mobile app needs from the IoT team

From: CAIPO mobile app (`FlolabsInnovationsGroup/caipo_app`)
To: IoT team (Sabri, Hasnae, Antoine, Sosina, Mohamed, Ash)
Date: 22 Oct 2026

The app side of the confirmed BLE contract is built and tested against the in-app simulator (CAIPO-SIM). It has never talked to a real ESP32. Everything below is what blocks that, in priority order.

## 1. First real BLE test with the app (blocking)

Sosina's ESP32 BLE layer has to run on a real board and connect to the app. Until then nothing on the device side is verified.

What the app expects, already confirmed by Antoine:

| Item | Value |
| --- | --- |
| Advertised name | starts with `CAIPO` |
| Service | `a1000000-5fa6-43f5-9827-201f62bd377d` |
| `A1000001` | notify. Everything the device sends, including R03 transfers |
| `A1000002` | read. Audio codec id, must return `21` (Opus 16 kHz) |
| `A1000003` | write. Everything the app sends, including R03 transfers |
| `A1000004` | notify + write. Commands and heartbeat |
| Security | SMP bonding required, encrypted characteristics |
| MTU | 512 requested. CHUNK payload up to 502 bytes |
| Heartbeat | opcode `0x10` + uint8 counter on `A1000004`, once per second |
| Battery | standard Battery Service `0x180F` / `0x2A19` |
| Device info | standard `0x180A`: model, serial, firmware, hardware, manufacturer |

Done when: the app scans, bonds, reads codec 21, receives heartbeats, and completes one R03 transfer each way with a real board.

The app for this test is ready: `caipo-ble-live.apk` on the repo's `android-latest` release (rebuilt on every push to main). Install it on an Android 10+ phone. `caipo-sim-mock.apk` on the same release shows the whole flow without a board.

Ask: who owns this test, and when can Mohamed get a board plus Sosina's handover document?

## 2. R03 transfers (confirmed, please keep as is)

- Opcodes `0x01` TRANSFER_REQUEST to `0x06` TRANSFER_ERROR, little-endian, CRC-32 (zlib), 5 s timeout, 3 retries of the failed chunk, no resume.
- Audio, content type `0x01`: Opus 16 kHz mono, 20 ms (320-sample) frames, packed as `[uint16 length][frame]...`.
- Image, content type `0x02`: **JPEG or PNG only, 4 MB max.** The app refuses anything else. About 1024 px wide is ideal. This picture is what the app sends to FloBrain for "Ask about a photo", the V1 that John asked for.

Reference: `lib/device/protocol/messages.dart`, `lib/core/config/constants.dart`.

## 3. Gestures and LEDs (not in the contract yet)

The touch sensor has single tap, double tap and long press. The LEDs are GRBW, and a two-LED split was proposed. The app shows these controls as "Needs device support" because no event or command is defined.

Needed:

- A device-to-app event on `A1000004` for each gesture (opcode + gesture id), and what each gesture does on the device.
- An app-to-device LED command, if the app should change the LED. If the LED is device-only, say so and the app will only display state.

The app has an unconfirmed proposal (`docs/COMMANDS_PROPOSAL.md`, opcodes `0x20` to `0x2F`: STATUS, CAPTURE_IMAGE, RECORD_AUDIO and others). Please confirm it, change it, or replace it. Nothing there is sent unless a build flag is on.

## 4. Device status

- Battery %, from the fuel gauge, through the standard Battery Service, with notify on change.
- Charging state. Today the app cannot show it. It could be bit 2 of the proposed STATUS frame, or something else you choose.
- Device state (standby, Pi booting, active and so on), if the app should show it.

## 5. Camera and data path (decision needed)

- Is the CAIPO photo sent to the phone over BLE (R03 type `0x02`) and then to FloBrain, or does the Pi send it straight to FloBrain? John asked for a latency comparison before choosing.
- "Phone as the screen" (see what CAIPO sees): the app has a proposed MJPEG-over-Wi-Fi live view, off by default. Open questions are in `docs/WIFI_CONTRACT_QUESTIONS.md`.
- The camera has not been tested yet. Please share when it is.

## 6. Access

The app team cannot read `CAIPO-Firmware`, `CAIPO-Mobile` or `caipo-devkit`. Read access would let us check the firmware BLE layer against the app before the board test.

## Contact on the app side

Code: `FlolabsInnovationsGroup/caipo_app`. Status: `docs/STATUS.md`. Decisions from the 20 and 21 Oct meetings: `docs/IOT_SYNC_2026-10-21.md`.

## Answers

Please answer here (edit this file in a PR, or reply on the Notion task and the app team copies it in). One row per question.

| # | Question | Answer | Who | Date |
| --- | --- | --- | --- | --- |
| 1 | Who runs the first BLE test with the app, and when? | | | |
| 1 | When does Mohamed get a board and Sosina's handover document? | | | |
| 2 | Does the camera send JPEG or PNG, at what size, over R03 type 0x02? | | | |
| 3 | Gesture events: opcode and id for single, double, long press, and what each does | | | |
| 3 | LED: does the app send LED commands, or only show device state? | | | |
| 3 | Confirm, change or replace COMMANDS_PROPOSAL.md (0x20 to 0x2F) | | | |
| 4 | How is charging state reported? | | | |
| 5 | Photo path: CAIPO to app to FloBrain, or Pi straight to FloBrain? Latency of each | | | |
| 5 | Answers to WIFI_CONTRACT_QUESTIONS.md (live view) | | | |
| 6 | Read access to CAIPO-Firmware, CAIPO-Mobile, caipo-devkit | | | |
