/// Every value that is not yet decided, plus the values the spec fixes.
///
/// TBD entries are development placeholders. They are listed again in
/// PLACEHOLDERS.md. Do not treat a placeholder as a CAIPO protocol decision.
library;

// ---------------------------------------------------------------------------
// FloBrain
// ---------------------------------------------------------------------------

const String kFloBrainBaseUrl = 'https://api.flobrain.ai';

/// FloBrain's profile, chat and settings views read `Authorization: Bearer <jwt>`
/// (backend `users/authentication.py` and `users/jwt_utils.py`, checked on 21 Oct
/// 2026). The OpenAPI `tokenAuth` entry comes from DRF's default
/// TokenAuthentication class, which these views do not use. Authenticated calls
/// stay on HTTPS.
const String kAuthorizationPrefix = 'Bearer';

/// Shown on Settings > About. Keep this aligned with `pubspec.yaml`.
const String kAppVersionName = '1.0.0';
const String kAppBuildNumber = '1';

/// Confirmed BLE contract the app builds against. Proposed opcodes are not part of it.
const String kBleContractVersion = 'GATT A1000000–A1000004, heartbeat 0x10, R03';

/// Specified error body: `{ "error": "description", "details": "..." }`.
const String kApiErrorField = 'error';
const String kApiDetailsField = 'details';

/// Sign-in and register answer `{"access_token", "refresh_token", "userId"}`
/// (backend `users/views.py`, checked on 21 Oct 2026). A body without both
/// tokens still fails closed.
const String kAccessTokenJsonField = 'access_token';
const String kRefreshTokenJsonField = 'refresh_token';

/// `POST /api/auth/refresh/` takes `{"refresh": ...}` and answers
/// `{"access": ...}` only. The app keeps the refresh token it already has.
const String kRefreshRequestField = 'refresh';
const String kRefreshResponseAccessField = 'access';

/// `POST /api/auth/signout/` reads `refresh_token`.
const String kSignOutRefreshField = 'refresh_token';

/// `POST /api/brain/chats/{id}/send/` takes `text` and an optional `image`
/// (base64 or URL) and answers the whole chat: `id`, `title`, `timestamp`,
/// `messages` (`id`, `role`, `text`, ...) and `usage`. The reply is the last
/// message whose role is `assistant`.
const String kChatTextField = 'text';
const String kChatImageField = 'image';
const String kChatMessagesField = 'messages';
const String kChatRoleField = 'role';
const String kChatAssistantRole = 'assistant';

/// Named in the schema descriptions for profile and sign-in.
const String kEmailJsonField = 'email';
const String kPasswordJsonField = 'password';
const String kFullNameJsonField = 'fullName';
const String kCurrentPasswordJsonField = 'current_password';
const String kNewPasswordJsonField = 'new_password';

/// TBD — owner: app team. The spec requires retries and does not give an HTTP
/// timeout. 20 seconds is a development default.
const int kHttpTimeoutSeconds = 20;

/// The spec's only numeric retry count is R03's 3 attempts. HTTP 5xx, 429 and
/// timeouts use that count. See NOTES.md.
const int kHttpMaxAttempts = 3;

/// TBD — owner: product. Phase 3 requires a configurable inactivity auto-lock
/// and does not give the default duration.
const int kDefaultAutoLockMinutes = 15;

/// R02.4. Specified.
const Duration kConversationIdleTimeout = Duration(seconds: 30);

// ---------------------------------------------------------------------------
// BLE identifiers. Confirmed by the IoT team (Antoine Beaugas).
// The firmware GATT layer is still being written. These values are what the
// app builds against. Real-device testing is not possible yet.
// BLE runs on the ESP32-S3. The Raspberry Pi is not part of BLE.
// ---------------------------------------------------------------------------

const String kCaipoUuidBase = '5fa6-43f5-9827-201f62bd377d';

const String kPrimaryServiceUuid = 'a1000000-$kCaipoUuidBase';

/// Notify. Everything the device sends, including R03 transfers.
const String kInboundCharacteristicUuid = 'a1000001-$kCaipoUuidBase';

/// Read. Audio codec ID.
const String kAudioCodecCharacteristicUuid = 'a1000002-$kCaipoUuidBase';

/// Write. Everything the app sends, including R03 transfers.
const String kOutboundCharacteristicUuid = 'a1000003-$kCaipoUuidBase';

/// Notify and write. Non-transfer commands and the device heartbeat.
const String kCommandCharacteristicUuid = 'a1000004-$kCaipoUuidBase';

/// Advertised name prefix. The prefix itself has no dash.
const String kAdvertisedNamePrefix = 'CAIPO';

/// SMP bonding is required. Android starts the bond. iOS cannot: the
/// firmware requires encryption, and that is what shows the pairing dialog.
const bool kRequiresBond = true;

/// Bluetooth SIG adopted values. These are standards, not CAIPO decisions.
const String kBatteryServiceUuid = '0000180f-0000-1000-8000-00805f9b34fb';
const String kBatteryLevelCharacteristicUuid =
    '00002a19-0000-1000-8000-00805f9b34fb';
const String kDeviceInfoServiceUuid = '0000180a-0000-1000-8000-00805f9b34fb';
const String kModelNumberCharacteristicUuid =
    '00002a24-0000-1000-8000-00805f9b34fb';
const String kSerialNumberCharacteristicUuid =
    '00002a25-0000-1000-8000-00805f9b34fb';
const String kFirmwareRevisionCharacteristicUuid =
    '00002a26-0000-1000-8000-00805f9b34fb';
const String kHardwareRevisionCharacteristicUuid =
    '00002a27-0000-1000-8000-00805f9b34fb';
const String kManufacturerNameCharacteristicUuid =
    '00002a29-0000-1000-8000-00805f9b34fb';

/// The 3-byte real-time audio header is not part of CAIPO. Recordings and
/// AI replies move as one R03 transfer. See [OpusFrameContainer].
const bool kRealtimeAudioStreaming = false;

/// Confirmed recording codec: Opus, 16 kHz mono, 20 ms / 320-sample frames.
const int kTargetCodecId = 21;
const int kCodecOpus16kHz = 21;

/// Older codec bytes. They are not the CAIPO recording format.
const int kCodecPcm8kHz = 1;
const int kCodecOpus8kHz = 20;

/// R03. MTU 512 leaves 509 bytes of ATT payload. A CHUNK header is 7 bytes,
/// so the payload cap is 502.
const int kNegotiatedMtuBytes = 512;
const int kChunkHeaderBytes = 7;
const int kMaxChunkBytes = 502;

/// Payload bytes that fit in one CHUNK.
///
/// [maximumWriteLength] is the ATT payload: negotiated MTU minus 3. On iOS
/// that value is `maximumWriteValueLength(for: .withResponse)`. The app does
/// not request an MTU from iOS. The header is 7 bytes, and the protocol cap
/// stays 502.
int chunkPayloadBytes(int maximumWriteLength) {
  final room = maximumWriteLength - kChunkHeaderBytes;
  if (room < 1) return 1;
  if (room > kMaxChunkBytes) return kMaxChunkBytes;
  return room;
}

/// Testing cap from the build plan. uint16 sequence numbers times 502 bytes
/// address [kSequenceAddressableBytes]. A transfer above either limit is
/// refused. The header layout stays as confirmed.
const int kMaxTransferBytes = 32000000;
const int kSequenceAddressableBytes = 65536 * kMaxChunkBytes;

const Duration kTransferAuthorisationTimeout = Duration(seconds: 5);

/// Retransmissions of the failed chunk after the first send.
const int kTransferMaxAttempts = 3;

/// R01.4. Specified reconnect schedule.
const List<Duration> kReconnectDelays = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

/// R01.4. Specified.
const Duration kDisconnectDetectionBudget = Duration(seconds: 5);

/// Poll cadence used to notice a dead link inside [kDisconnectDetectionBudget].
const Duration kLinkPollInterval = Duration(seconds: 1);

/// Device heartbeat on [kCommandCharacteristicUuid]. Opcode 0x10, then a
/// uint8 counter. The firmware sends one every second and asks for a 6 s
/// supervision timeout. The central does not set that timeout.
const int kOpcodeHeartbeat = 0x10;
const Duration kHeartbeatPeriod = Duration(seconds: 1);
const Duration kHeartbeatSilenceTimeout = Duration(seconds: 3);
const Duration kFirmwareSupervisionTimeout = Duration(seconds: 6);

/// 3 s of silence means disconnected. Off until the firmware sends
/// heartbeats, because an idle device would otherwise look dead.
const bool kHeartbeatSilenceDisconnectEnabled = false;

/// TBD — owner: app team. The spec does not give a GATT ready timeout.
/// Development default. Native code mirrors this number; keep them equal.
const int kGattReadyTimeoutSeconds = 30;

/// TBD — owner: app team. Scan window for a user-initiated refresh.
const int kScanTimeoutSeconds = 8;

/// Confirmed: CRC-32 (ISO-HDLC / zlib). SHA-256 remains implemented and is
/// not the CAIPO digest.
const String kTransferChecksumAlgorithm = 'crc32';

// ---------------------------------------------------------------------------
// R03 opcodes. 0x00 is reserved and is never a message.
// Confirmed by the IoT team. All multi-byte fields are little-endian.
// ---------------------------------------------------------------------------

const int kOpcodeTransferRequest = 0x01;
const int kOpcodeTransferReady = 0x02;
const int kOpcodeMetadata = 0x03;
const int kOpcodeChunk = 0x04;
const int kOpcodeTransferAck = 0x05;
const int kOpcodeTransferError = 0x06;

const int kContentTypeAudio = 0x01;
const int kContentTypeImage = 0x02;
const int kContentTypeOther = 0x03;

const int kErrorBusy = 0x01;
const int kErrorChecksumMismatch = 0x02;
const int kErrorSequenceGap = 0x03;
const int kErrorTooLarge = 0x04;
const int kErrorTimeout = 0x05;
const int kErrorUnsupportedType = 0x06;
const int kErrorUnknown = 0xFF;

/// Failed-sequence field when the error does not name a chunk.
const int kErrorSeqNotApplicable = 0xFFFF;

/// iOS CoreBluetooth state restoration id. CAIPO's own id, not OMI's.
const String kBleRestoreIdentifier = 'com.flolabs.caipo.ble';

/// Android Keystore key alias. Not an OMI identifier.
const String kTokenKeystoreAlias = 'caipo.token.kek';
