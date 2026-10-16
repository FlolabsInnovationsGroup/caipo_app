import 'dart:typed_data';

/// Proposed command opcodes on A1000004. Not part of the confirmed BLE contract.
/// Camera and status opcodes are written only when PROPOSED_COMMANDS is on.
/// Stream opcodes 0x27 and 0x29 are written only when PROPOSED_STREAM is on.
const int kProposedGetStatus = 0x20;
const int kProposedStatus = 0x21;
const int kProposedCaptureImage = 0x22;
const int kProposedRecordVideo = 0x23;
const int kProposedRecordAudio = 0x24;
const int kProposedSyncNow = 0x25;
const int kProposedSetTime = 0x26;
const int kProposedStartStream = 0x27;
const int kProposedStreamReady = 0x28;
const int kProposedStopStream = 0x29;
const int kProposedCommandResult = 0x2F;

const int kStreamWidth = 640;
const int kStreamHeight = 480;
const int kStreamFps = 15;
const Duration kStreamAutoStop = Duration(minutes: 2);
const String kLiveStreamPath = '/stream';

const int kProposedWifiContentType = 0x04;

const int kDeviceStateStandby = 0;
const int kDeviceStateWake = 1;
const int kDeviceStatePoweringUp = 2;
const int kDeviceStatePiBooting = 3;
const int kDeviceStateActive = 4;
const int kDeviceStateShutdown = 5;
const int kDeviceStatePiShuttingDown = 6;
const int kDeviceStatePowerGating = 7;

const int kStatusFlagRecordingAudio = 1 << 0;
const int kStatusFlagRecordingVideo = 1 << 1;
const int kStatusFlagCharging = 1 << 2;
const int kStatusFlagPiOn = 1 << 3;
const int kStatusFlagWifiConnected = 1 << 4;

const int kCommandOk = 0;
const int kCommandBusy = 1;
const int kCommandUnsupported = 2;
const int kCommandFailed = 3;

class DeviceStatus {
  const DeviceStatus({
    required this.state,
    required this.batteryPercent,
    required this.flags,
    required this.pendingUploads,
  });

  final int state;
  final int batteryPercent;
  final int flags;
  final int pendingUploads;

  bool get recordingAudio => flags & kStatusFlagRecordingAudio != 0;
  bool get recordingVideo => flags & kStatusFlagRecordingVideo != 0;
  bool get charging => flags & kStatusFlagCharging != 0;
  bool get piOn => flags & kStatusFlagPiOn != 0;
  bool get wifiConnected => flags & kStatusFlagWifiConnected != 0;
}

class StreamReady {
  const StreamReady({required this.address, required this.port, required this.token});

  final List<int> address;
  final int port;
  final Uint8List token;

  String get tokenHex => [for (final byte in token) byte.toRadixString(16).padLeft(2, '0')].join();

  /// Local MJPEG URL. Direct on the LAN or the phone hotspot, not through FloBrain.
  Uri get uri => Uri(
    scheme: 'http',
    host: address.join('.'),
    port: port,
    path: kLiveStreamPath,
    queryParameters: {'token': tokenHex},
  );
}

class CommandResult {
  const CommandResult({required this.opcode, required this.result});

  final int opcode;
  final int result;

  bool get ok => result == kCommandOk;
}

Uint8List encodeGetStatus() => Uint8List.fromList([kProposedGetStatus]);

Uint8List encodeCaptureImage() => Uint8List.fromList([kProposedCaptureImage]);

Uint8List encodeRecordVideo(int seconds) => Uint8List.fromList([kProposedRecordVideo, _duration(seconds)]);

Uint8List encodeRecordAudio(int seconds) => Uint8List.fromList([kProposedRecordAudio, _duration(seconds)]);

Uint8List encodeSyncNow() => Uint8List.fromList([kProposedSyncNow]);

Uint8List encodeStartStream() => Uint8List.fromList([kProposedStartStream]);

Uint8List encodeStopStream() => Uint8List.fromList([kProposedStopStream]);

Uint8List encodeStreamReady(StreamReady ready) {
  if (ready.address.length != 4) {
    throw ArgumentError('STREAM_READY needs an IPv4 address.');
  }
  if (ready.token.length != 16) {
    throw ArgumentError('STREAM_READY needs a 16 byte token.');
  }
  final data = ByteData(23);
  data.setUint8(0, kProposedStreamReady);
  for (var i = 0; i < 4; i++) {
    data.setUint8(1 + i, ready.address[i]);
  }
  data.setUint16(5, ready.port, Endian.little);
  for (var i = 0; i < 16; i++) {
    data.setUint8(7 + i, ready.token[i]);
  }
  return data.buffer.asUint8List();
}

Uint8List encodeSetTime(int unixSeconds) {
  final data = ByteData(5);
  data.setUint8(0, kProposedSetTime);
  data.setUint32(1, unixSeconds, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List encodeStatus(DeviceStatus status) {
  final data = ByteData(6);
  data.setUint8(0, kProposedStatus);
  data.setUint8(1, status.state & 0xFF);
  data.setUint8(2, status.batteryPercent & 0xFF);
  data.setUint8(3, status.flags & 0xFF);
  data.setUint16(4, status.pendingUploads & 0xFFFF, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List encodeCommandResult({required int opcode, required int result}) {
  return Uint8List.fromList([kProposedCommandResult, opcode & 0xFF, result & 0xFF]);
}

/// Null when the bytes are not a proposed status or result.
Object? decodeProposedCommand(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  switch (bytes[0]) {
    case kProposedStatus:
      if (bytes.length != 6) return null;
      final view = ByteData.sublistView(bytes);
      return DeviceStatus(
        state: view.getUint8(1),
        batteryPercent: view.getUint8(2),
        flags: view.getUint8(3),
        pendingUploads: view.getUint16(4, Endian.little),
      );
    case kProposedCommandResult:
      if (bytes.length != 3) return null;
      return CommandResult(opcode: bytes[1], result: bytes[2]);
    case kProposedStreamReady:
      if (bytes.length != 23) return null;
      final view = ByteData.sublistView(bytes);
      return StreamReady(
        address: [for (var i = 0; i < 4; i++) view.getUint8(1 + i)],
        port: view.getUint16(5, Endian.little),
        token: Uint8List.fromList(bytes.sublist(7, 23)),
      );
    default:
      return null;
  }
}

int _duration(int seconds) {
  if (seconds < 1) return 1;
  if (seconds > 255) return 255;
  return seconds;
}

/// Live view. Null means START_STREAM may be sent.
String? liveViewReason({
  required bool streamEnabled,
  required bool commandsEnabled,
  DeviceStatus? status,
}) {
  if (!streamEnabled) return 'Live streaming is proposed and turned off.';
  if (commandsEnabled && status != null && !status.wifiConnected) return 'Needs WiFi';
  if (commandsEnabled && status == null) return 'Waiting for device status.';
  return null;
}

/// Why a camera control stays disabled. Null means the proposed command may be sent.
String? cameraControlReason({required bool commandsEnabled, DeviceStatus? status}) {
  if (!commandsEnabled) return 'Needs device support';
  if (status == null) return 'Waiting for device status.';
  if (!status.wifiConnected) return 'Needs WiFi';
  return null;
}
