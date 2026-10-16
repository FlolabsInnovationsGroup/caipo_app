import 'dart:async';
import 'dart:typed_data';

import '../../core/config/constants.dart';
import '../../core/logging/app_logger.dart';
import '../audio/opus_container.dart';
import '../ble/ble_bridge.dart';
import '../ble/connection.dart';
import 'incoming_transfer.dart';

/// Listens on the device-to-app characteristic and answers R03 transfers.
///
/// Heartbeats stay on the command characteristic and are not fed in here.
/// A completed payload is handed to [onCompleted] after the ACK is written.
class DeviceTransferSession {
  DeviceTransferSession({
    required this.deviceId,
    required this.connection,
    required this.events,
    required this.logger,
    IncomingTransfer? receiver,
    this.container = const OpusFrameContainer(),
    this.onTransferStarted,
    this.onCompleted,
    this.onAbandoned,
  }) : receiver = receiver ?? IncomingTransfer();

  final String deviceId;
  final DeviceConnection connection;
  final Stream<CharacteristicEvent> events;
  final AppLogger logger;
  final IncomingTransfer receiver;
  final OpusFrameContainer container;
  final void Function()? onTransferStarted;
  final Future<void> Function(Uint8List payload, int contentType)? onCompleted;
  final Future<void> Function(Uint8List partial)? onAbandoned;

  StreamSubscription<CharacteristicEvent>? _sub;
  Timer? _idle;

  void start() {
    _sub ??= events.listen(_onEvent);
  }

  Future<void> stop() async {
    _idle?.cancel();
    _idle = null;
    await _sub?.cancel();
    _sub = null;
  }

  void _onEvent(CharacteristicEvent event) {
    if (event.id.toLowerCase() != deviceId.toLowerCase()) return;
    if (event.characteristicUuid.toLowerCase() != kInboundCharacteristicUuid.toLowerCase()) {
      return;
    }
    final wasActive = receiver.active;
    final reply = receiver.handle(event.value);
    if (!wasActive && receiver.active) onTransferStarted?.call();
    _armTimeout();
    unawaited(_apply(reply));
  }

  void _armTimeout() {
    _idle?.cancel();
    if (!receiver.active) {
      _idle = null;
      return;
    }
    _idle = Timer(kTransferAuthorisationTimeout, () {
      final frame = receiver.onTimeout();
      final abandoned = receiver.takeAbandoned();
      if (abandoned != null) unawaited(onAbandoned?.call(abandoned));
      if (frame != null) {
        unawaited(_write(frame));
      }
      _armTimeout();
    });
  }

  Future<void> _apply(TransferReply? reply) async {
    if (reply == null) return;
    final frame = reply.frame;
    if (frame != null) await _write(frame);
    final payload = reply.payload;
    if (payload == null) return;
    final type = reply.contentType ?? kContentTypeOther;
    if (type == kContentTypeAudio) {
      try {
        final frames = container.unpack(payload);
        logger.info('Recording received: ${frames.length} Opus frames, ${payload.length} bytes.');
      } on FormatException catch (error) {
        logger.warn('Recording payload was not length-prefixed Opus: $error');
      }
    } else {
      logger.info('Transfer received: ${payload.length} bytes, type $type.');
    }
    final completed = onCompleted;
    if (completed == null) return;
    try {
      await completed(payload, type);
    } catch (error) {
      logger.warn('Completed transfer was not handled: $error');
    }
  }

  Future<void> _write(Uint8List frame) async {
    try {
      await connection.writeOutbound(deviceId, frame);
    } catch (error) {
      logger.warn('R03 reply was not written: $error');
    }
  }
}
