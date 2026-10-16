import 'dart:async';
import 'dart:typed_data';

import '../../core/config/constants.dart';
import '../ble/ble_bridge.dart';
import '../ble/connection.dart';
import '../protocol/chunker.dart';
import '../protocol/proposed_commands.dart';
import '../protocol/transfer_manager.dart';

/// Sends one proposed Wi-Fi payload over the existing R03 transfer.
/// Called only after [WifiProvisioner] has decided the flag and the bond allow it.
class WifiSender {
  WifiSender({required this.connection, required this.bridge});

  final DeviceConnection connection;
  final BleBridge bridge;

  Future<void> send(String deviceId, Uint8List payload) async {
    final writeLength = await connection.maximumWriteLength(deviceId);
    final manager = TransferManager(chunker: Chunker(maxChunkBytes: chunkPayloadBytes(writeLength)));
    final prepared = manager.prepare(
      payload: payload,
      transferId: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
      contentType: kProposedWifiContentType,
      proposed: true,
    );
    final progress = await manager.exchange(
      prepared: prepared,
      write: (frame) {
        unawaited(connection.writeOutbound(deviceId, frame));
      },
      inbound: bridge.characteristicValues.stream
          .where(
            (event) =>
                event.id.toLowerCase() == deviceId.toLowerCase() &&
                event.characteristicUuid.toLowerCase() == kInboundCharacteristicUuid.toLowerCase(),
          )
          .map((event) => event.value),
    );
    if (progress.phase != TransferPhase.acknowledged) {
      throw StateError(progress.detail ?? 'The Wi-Fi list was not acknowledged.');
    }
  }
}
