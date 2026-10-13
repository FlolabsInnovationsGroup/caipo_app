# CAIPO

Flutter companion app for the CAIPO wearable. It pairs over Bluetooth Low Energy and talks to FloBrain at `https://api.flobrain.ai`.

The specification is the source of truth. Unknown protocol values are named constants in `lib/core/config/constants.dart` and listed in `PLACEHOLDERS.md`. Ambiguities are in `NOTES.md`.

## Setup

Install Flutter 3.27 or newer (this tree was generated with 3.47.7) and an Android SDK with API 29+. iOS builds require Xcode on macOS and target iOS 15.

```bash
flutter pub get
dart run pigeon --input pigeons/ble_api.dart
dart run pigeon --input pigeons/secure_store_api.dart
```

Regenerate the Pigeon files after changing `pigeons/`.

## Run

```bash
flutter run -d android
flutter run -d ios
```

Android minimum is API 29 (Android 10). The app asks for `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` on Android 12+, and location on Android 10–11 because scanning required it there. A connected-device foreground service keeps the BLE link while the app is backgrounded. iOS uses the `bluetooth-central` background mode and CoreBluetooth state restoration (`com.flolabs.caipo.ble`).

This tree was built on Windows. `flutter test` and `flutter analyze` can run here. An iOS compile needs a Mac. An Android device or emulator with Bluetooth is required to exercise a real scan; the unit tests do not need hardware.

## What is implemented

- Project layout from spec section 9, including stub screens for later phases.
- Dependency injection (`get_it`), logging, and a Flutter error handler.
- Phase 1: scan with name, RSSI and battery when known, refresh, saved devices, Bluetooth-off warning with a settings link, live adapter state, GATT connect and service discovery, a distinct message per failure, persisted device id, disconnect polling inside 5 seconds, reconnect waits of 1s then 2s then 4s, runtime permissions, background connection.
- Native BLE on Swift and Kotlin, bridged with Pigeon. CAIPO is its own device type. It does not use an OMI device-type name.
- Phase 3: Dio client, Bearer header, refresh on 401, Keychain on iOS, Android Keystore with ciphertext in an app-private file (not SharedPreferences), repositories for auth, profile, chat, memory and settings, session restore, configurable auto-lock.
- Packet assembler, codec negotiation (bytes 1, 20, 21), 509-byte chunker, CRC-32 and SHA-256.

## What is mocked

- `opus_encoder.dart` and `audio_transmitter.dart` return no bytes.
- R03 `messages.dart` and `transfer_manager.dart` do not write a wire frame. Opcode bytes are undefined.
- `chunker.dart`, `checksum.dart` and `retry_policy.dart` implement the specified sizes, digests and attempt count. The transfer manager does not send them.
- `SttClient` and `TtsClient` return nothing. Those endpoints are not published.
- Wi-Fi provisioning and the media channel do not send credentials or open a socket.

## What is not built

Phase 2 Opus-to-PCM decode, Phase 4 outbound audio and the R03 wire protocol, Phase 5 dashboard / media library / notifications / settings / diagnostics screens, Phase 6 Wi-Fi, live view and camera.

## Tests

```bash
flutter test
```

Covers the packet assembler, codec negotiation, chunker and checksum, plus the JWT refresh path and pairing-failure messages.
