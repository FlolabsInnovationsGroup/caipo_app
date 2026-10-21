# CAIPO — project guide

This app is the phone companion for the CAIPO wearable. It is not the device, and it is not the AI server. It links the phone to the device over Bluetooth, sends the user's speech to FloBrain, plays the reply as audio, and stores the conversation and files on the phone, encrypted.

Current progress is in `docs/STATUS.md`. The plan is in `docs/CAIPO_BUILD_PLAN.md`.

## What the app does

The CAIPO device records audio. The app:

1. Finds the device and pairs over Bluetooth Low Energy.
2. Receives the recording as an Opus file inside the R03 transfer protocol.
3. Turns the audio into text, sends that text to FloBrain, and receives the text reply.
4. Turns the reply into Opus audio and sends it back to the device. In simulator mode it also plays the reply on the phone speaker.
5. Stores the conversation and files on the phone, and locks the session after a time the user chooses.

Voice, commands, and status stay on Bluetooth while the phone is near the device. Camera photos, video, and live streaming do not go over Bluetooth. That path is proposed and stays off in the default build, because the Wi-Fi and command contracts are not confirmed by firmware yet.

## What the user sees

After sign-in and a short intro, the bottom bar has four screens:

| Screen | What it does |
| --- | --- |
| Dashboard | Connection, battery, status light, last saved file, and Talk to AI |
| Conversation | Encrypted history, search, delete, and replay of the reply audio |
| Library | Audio clips with a waveform and speeds from 0.5x to 2x, plus share and delete |
| Settings | Device, auto-lock, biometrics, networks, export, delete local data, About |

Notifications and Diagnostics open from the app bar or from Settings. The pairing screen only pairs. It does not run the voice loop.

Capture, Record video, Live view, LED, gestures, and firmware update are visible. When one cannot run, it says why (`Needs device support`, `Needs WiFi`, or that the proposed stream is off). There are no dead buttons and no fake success.

## Architecture

```
User
   │
   ▼
Flutter screens  (auth, shell, dashboard, conversation, library, settings)
   │
   ├── SessionController        session, lock, sign-out
   ├── VoiceLoopController      voice loop from the device to FloBrain and back
   ├── PairingController        discovery, pairing, incoming files
   │
   ├── Device
   │     sim  → SimCaipoController inside the app (CAIPO-SIM)
   │     ble  → Kotlin / Swift through Pigeon, then the radio
   │
   └── FloBrain
         mock → canned replies inside the app, no network
         live → HTTPS at https://api.flobrain.ai
```

Dependencies are wired in `lib/core/di/injector.dart` with `get_it`. Colors and spacing live in `lib/shared/theme/caipo_tokens.dart`. Copy lives in `lib/shared/copy/app_strings.dart`.

### Code layers

| Folder | Role |
| --- | --- |
| `lib/features/` | Screens and user flows |
| `lib/device/ble/` | Discovery, connection, background link |
| `lib/device/protocol/` | R03 messages, chunking, retry, file archive |
| `lib/device/audio/` | Opus, 16 kHz mono, 20 ms |
| `lib/device/sim/` | The CAIPO-SIM device and the bundled sample audio |
| `lib/flobrain/` | API client, tokens, repositories, mock backend |
| `lib/core/security/` | Keychain / Android Keystore keys and AES-GCM |
| `android/` and `ios/` | Native Bluetooth, icon, splash, permissions |

Confirmed Bluetooth identity: service `a1000000-5fa6-43f5-9827-201f62bd377d`, characteristics `A1000001` through `A1000004`, advertised name prefix `CAIPO`. Heartbeat opcode `0x10` is parsed. The rule that disconnects after 3 seconds of silence is implemented and stays off until real firmware sends heartbeats.

R03 covers the request, chunks, metadata, and transfer errors. The timeout is 5 seconds, and a failed chunk is resent up to 3 times. There is no resume from the middle of a file. A retry starts the transfer again at the first chunk, and bytes already received are kept as a `partial_` file.

Files are sealed before they are written, including while the screen is locked or the app is in the background. Android keeps the link with a connected-device foreground service. iOS uses `bluetooth-central` restoration.

## Voice loop

1. The device sends an Opus recording (content type `0x01`).
2. The app decodes it.
3. The text goes to a FloBrain chat.
4. The text reply becomes audio and goes back to the device.
5. The conversation line is stored only after the reply succeeds.

If sending fails, the recording stays saved as `Not sent`, with Retry. The text and audio are not dropped.

In live mode, speech-to-text and text-to-speech are not published by FloBrain yet. The app refuses them with a clear message (`Speech to text is not available.` and `Text to speech is not available.`). It does not return empty audio.

## What stays off

These flags are all `false` in a normal build. While a flag is off, the app does not call that route and does not write that opcode:

| Flag | Meaning |
| --- | --- |
| `PROPOSED_SPEECH` | Proposed speech routes |
| `PROPOSED_MEDIA` | Reading photos and video from FloBrain |
| `PROPOSED_COMMANDS` | Status, capture, and sync commands |
| `PROPOSED_WIFI` | Sending saved Wi-Fi networks to the device |
| `PROPOSED_STREAM` | MJPEG streaming on the local network |

Image input, a custom system prompt, and offline AI are not in the current FloBrain schema. Settings says they are not available. Voice and language stay on the phone, because the settings schema does not define those fields.

The app sends the `Bearer` authorization prefix. FloBrain's backend code reads Bearer tokens (checked on 21 Oct 2026). The OpenAPI schema's `tokenAuth` entry is a framework default and is not what the views read. The full request and response shapes are in `docs/STATUS.md`.

## Test and live

The mode is chosen at build time, not by a switch inside the app:

```bash
flutter run --dart-define=DEVICE_MODE=sim --dart-define=BACKEND_MODE=mock
```

With no flags, the default is `DEVICE_MODE=ble` and `BACKEND_MODE=live`.

| | Test (`sim` + `mock`) | Live (`ble` + `live`) |
| --- | --- | --- |
| Device | CAIPO-SIM inside the app. After connect the line is `Connected to CAIPO-SIM.` | Bluetooth scan for a real device whose name starts with CAIPO |
| Radio | None | Kotlin on Android, Swift on iOS |
| FloBrain | Canned replies inside the app. Base URL `http://mock.flobrain.local`. No socket | `https://api.flobrain.ai` |
| Sign-in | Any email and password | Fails closed when the token JSON does not have the expected fields. The app does not invent a success |
| Voice loop | Bundled `assets/sim/speech.wav`. The reply WAV plays on the phone speaker | Needs a real device and live speech routes. Those live routes still fail on purpose |
| About | `sim / mock` | `ble / live` |
| Build | `build/apk/caipo-sim.apk` | `build/apk/caipo-live.apk` |

### Trying the test APK

1. Install `build/apk/caipo-sim.apk`.
2. Sign in with any email and password.
3. Finish the short intro.
4. Pair with CAIPO-SIM.
5. On Dashboard or Conversation, tap Talk to AI.
6. Play the reply. It comes from the phone speaker, and the library lists the clip.
7. In Settings > About, confirm the mode is `sim / mock`.
8. Export my data shares the conversation text. Delete all local data wipes the conversation, files, keys, and saved networks, then signs out.

Auto-lock is 1 to 30 minutes, default 15. Biometric unlock stays off until Settings turns it on.

### Trying the live APK

1. Install `build/apk/caipo-live.apk`.
2. The app looks for a real CAIPO and calls `https://api.flobrain.ai`.
3. Sign-in does not succeed if the server returns token fields the client does not expect.
4. Capture, video, live view, LED, gestures, and firmware update say why they cannot run.
5. Live view does not show a picture while `PROPOSED_STREAM` is off.

Unit tests (`flutter test`) use the simulator and a scripted HTTP adapter. They do not call the live server or a Bluetooth radio.

## What sits outside this app

| Piece | Owner |
| --- | --- |
| ESP32-S3 GATT, heartbeats, and encrypted characteristics | Device team |
| HTTPS on `api.flobrain.ai` and the sign-in token JSON | FloBrain |
| Live speech-to-text and text-to-speech | FloBrain. The app refuses these until the routes are confirmed |
| Keeping recordings on the device while the phone is away | Firmware, not verified yet |
| An iOS build | Needs a Mac |
