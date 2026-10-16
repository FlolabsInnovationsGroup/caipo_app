# Proposed device commands

PROPOSED. Not part of the confirmed BLE contract. The app writes these opcodes only when the build is run with `--dart-define=PROPOSED_COMMANDS=true`. That flag is off by default.

All of these use characteristic A1000004. Confirmed heartbeat `0x10` is unchanged.

LED, gestures, and OTA are not in this table. Those controls stay disabled with "Needs device support".

## App to device

| Opcode | Name | Payload |
| --- | --- | --- |
| `0x20` | GET_STATUS | none |
| `0x22` | CAPTURE_IMAGE | none. The picture is saved and uploaded over Wi-Fi, not BLE. |
| `0x23` | RECORD_VIDEO | duration in seconds, one uint8 |
| `0x24` | RECORD_AUDIO | duration in seconds, one uint8 |
| `0x25` | SYNC_NOW | none. Upload pending media over Wi-Fi. |
| `0x26` | SET_TIME | unix time, uint32 little-endian. Sent on every connect when the flag is on. |
| `0x27` | START_STREAM | none. Written only when `PROPOSED_STREAM` is on. |
| `0x29` | STOP_STREAM | none. Written only when `PROPOSED_STREAM` is on. The device also stops the stream itself after 2 minutes. |

## Device to app

| Opcode | Name | Payload |
| --- | --- | --- |
| `0x21` | STATUS | `[state uint8][battery % uint8][flags uint8][pending uploads uint16 LE]` |
| `0x28` | STREAM_READY | `[IPv4 4 bytes][port uint16 LE][token 16 bytes]`. The app opens `http://<ip>:<port>/stream?token=<token as hex>`. MJPEG, 640×480, 15 fps, on the local network. |
| `0x2F` | CMD_RESULT | `[command opcode][result]` |

STATUS state values:

| Value | Name |
| --- | --- |
| 0 | STANDBY |
| 1 | WAKE |
| 2 | POWERING_UP |
| 3 | PI_BOOTING |
| 4 | ACTIVE |
| 5 | SHUTDOWN |
| 6 | PI_SHUTTING_DOWN |
| 7 | POWER_GATING |

STATUS flags:

| Bit | Meaning |
| --- | --- |
| 0 | recording audio |
| 1 | recording video |
| 2 | charging |
| 3 | Pi on |
| 4 | Wi-Fi connected |

CMD_RESULT values: `0` ok, `1` busy, `2` unsupported, `3` failed.

When bit 4 is 0, Capture, Record video, and Live view show "Needs WiFi" and are not sent. Nothing from the camera is transferred over BLE.
