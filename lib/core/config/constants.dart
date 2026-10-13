/// Every value that is not yet decided, plus the values the spec fixes.
///
/// TBD entries are development placeholders. They are listed again in
/// PLACEHOLDERS.md. Do not treat a placeholder as a CAIPO protocol decision.
library;

// ---------------------------------------------------------------------------
// FloBrain
// ---------------------------------------------------------------------------

const String kFloBrainBaseUrl = 'https://api.flobrain.ai';

/// Specified error body: `{ "error": "description", "details": "..." }`.
const String kApiErrorField = 'error';
const String kApiDetailsField = 'details';

/// TBD — owner: FloBrain team.
///
/// Live `/api/schema/` and `/api/swagger/` could not be fetched from the build
/// environment (connection failed / HTTP 500 on 13 Oct 2026). These names are
/// Django REST simplejwt-shaped placeholders for a Django REST backend. Auth
/// fails closed when a response does not contain them. There is no second
/// guess at runtime.
const String kAccessTokenJsonField = 'access';
const String kRefreshTokenJsonField = 'refresh';
const String kEmailJsonField = 'email';
const String kPasswordJsonField = 'password';

/// TBD — owner: FloBrain team. Not confirmed against /api/schema/.
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
// BLE identifiers
// ---------------------------------------------------------------------------

/// TBD — owner: IoT team.
/// Notion task "Define BLE service/characteristic UUIDs for CAIPO audio",
/// open since August 2025, status Not Started.
/// Development placeholder: OMI primary service. This is not a CAIPO id.
const String kPrimaryServiceUuid = '19b10000-e8f2-537e-4f6c-d104768a1214';

/// TBD — owner: IoT team. Development placeholder: OMI audio notify.
const String kAudioNotifyCharacteristicUuid =
    '19b10001-e8f2-537e-4f6c-d104768a1214';

/// TBD — owner: IoT team. Development placeholder: OMI audio codec read.
const String kAudioCodecCharacteristicUuid =
    '19b10002-e8f2-537e-4f6c-d104768a1214';

/// TBD — owner: IoT team. Outbound audio characteristic does not exist yet.
/// Development placeholder: OMI speaker/haptic write characteristic. OMI only
/// writes haptic levels here. Do not treat it as CAIPO's speaker channel.
const String kOutboundAudioCharacteristicUuid =
    'cab1ab96-2ea5-4f4d-bb56-874b72cfc984';

/// TBD — owner: IoT team. Empty means "match advertisements by service UUID
/// only". A name prefix has not been assigned.
const String kAdvertisedNamePrefix = '';

/// TBD — owner: IoT team. The spec does not say whether pairing requires an
/// SMP bond. Development placeholder: GATT connect + persisted id, no bond.
const bool kRequiresBond = false;

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

/// TBD — owner: IoT team. Whether the 3-byte audio header is retained.
/// Development placeholder follows spec section 4.3: the header is present.
const bool kAudioHeaderRetained = true;
const int kAudioHeaderSizeBytes = 3;

/// TBD — owner: IoT team. Recommended target from spec section 4.4.
/// Development placeholder: 21 (Opus 16 kHz, 320-sample frames).
const int kTargetCodecId = 21;

/// Codec map verified against OMI source, which the spec says to follow.
/// These are the development map until IoT confirms CAIPO's identifiers.
const int kCodecPcm8kHz = 1;
const int kCodecOpus8kHz = 20;
const int kCodecOpus16kHz = 21;

/// R03. Specified.
const int kNegotiatedMtuBytes = 512;
const int kMaxChunkBytes = 509;
const int kMaxTransferBytes = 32 * 1024 * 1024;
const Duration kTransferAuthorisationTimeout = Duration(seconds: 5);
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

/// TBD — owner: app team. The spec does not give a GATT ready timeout.
/// Development default. Native code mirrors this number; keep them equal.
const int kGattReadyTimeoutSeconds = 30;

/// TBD — owner: app team. Scan window for a user-initiated refresh.
const int kScanTimeoutSeconds = 8;

/// TBD — owner: unassigned. R03 says CRC32 or SHA-256 and does not choose.
/// Development placeholder: CRC-32 (ISO-HDLC). SHA-256 is also implemented.
const String kTransferChecksumAlgorithm = 'crc32';

// ---------------------------------------------------------------------------
// R03 opcodes. TBD — owner: unassigned.
// The binary wire format (opcode values, field order, header layout, error
// table) is undefined. These placeholders must not be written to a device.
// ---------------------------------------------------------------------------

const int kOpcodeTransferRequest = 0x00;
const int kOpcodeTransferReady = 0x00;
const int kOpcodeMetadata = 0x00;
const int kOpcodeChunk = 0x00;
const int kOpcodeTransferAck = 0x00;
const int kOpcodeTransferError = 0x00;

/// iOS CoreBluetooth state restoration id. CAIPO's own id, not OMI's.
const String kBleRestoreIdentifier = 'com.flolabs.caipo.ble';

/// Android Keystore key alias. Not an OMI identifier.
const String kTokenKeystoreAlias = 'caipo.token.kek';
