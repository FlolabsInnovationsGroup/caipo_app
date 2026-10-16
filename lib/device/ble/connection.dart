import 'dart:async';
import 'dart:typed_data';

import 'package:caipo_app/gen/ble_api.g.dart';

import '../../core/config/constants.dart';
import '../../core/logging/app_logger.dart';
import '../audio/codec_negotiation.dart';
import '../info/battery.dart';
import '../info/device_info.dart';
import 'ble_bridge.dart';
import 'characteristics.dart';
import 'pairing_failure.dart';

class GattSession {
  const GattSession({
    required this.services,
    this.batteryPercent,
    this.codec,
    this.information,
  });

  final List<String> services;
  final int? batteryPercent;
  final NegotiatedCodec? codec;
  final DeviceInformation? information;
}

class DeviceConnection {
  DeviceConnection(this.bridge, this.logger, {CaipoCharacteristics? characteristics})
    : characteristics = characteristics ?? const CaipoCharacteristics();

  final BleBridge bridge;
  final AppLogger logger;
  final CaipoCharacteristics characteristics;

  Future<GattSession> connect(String deviceId) async {
    final ready = Completer<DeviceReadyEvent>();
    final failed = Completer<PairingFailure>();
    late final StreamSubscription<DeviceReadyEvent> readySub;
    late final StreamSubscription<DisconnectEvent> dropSub;
    readySub = bridge.deviceReady.stream.listen((event) {
      if (event.id.toLowerCase() != deviceId.toLowerCase()) return;
      if (!ready.isCompleted) ready.complete(event);
    });
    dropSub = bridge.disconnected.stream.listen((event) {
      if (event.id.toLowerCase() != deviceId.toLowerCase()) return;
      if (!failed.isCompleted) {
        failed.complete(failureFromNativeError(event.error) ?? PairingFailure.linkLost);
      }
    });

    try {
      await bridge.controller.manageDevice(deviceId, kRequiresBond);
      final winner = await Future.any<Object>([
        ready.future,
        failed.future,
        Future<void>.delayed(Duration(seconds: kGattReadyTimeoutSeconds)).then((_) {
          throw const _ConnectTimedOut();
        }),
      ]);
      if (winner is PairingFailure) {
        throw ConnectFailed(winner);
      }
      final event = winner as DeviceReadyEvent;
      final serviceIds = event.services.map((service) => service.uuid).toList();
      if (!characteristics.hasService(serviceIds, characteristics.primaryService)) {
        await bridge.controller.unmanageDevice(deviceId);
        throw const ConnectFailed(PairingFailure.serviceMissing);
      }
      // Android starts SMP bonding here. iOS cannot start it. requestBond
      // on iOS returns success, and the pairing dialog appears when the
      // firmware's encrypted characteristics are accessed.
      if (kRequiresBond) {
        final bonded = await bridge.controller.requestBond(deviceId);
        if (!bonded) {
          await bridge.controller.unmanageDevice(deviceId);
          throw const ConnectFailed(PairingFailure.bondFailed);
        }
      }
      await _subscribeNotifications(deviceId, event.services);
      final battery = await _readBattery(deviceId, event.services);
      final codec = await _readCodec(deviceId, event.services);
      final info = await _readInfo(deviceId, event.services);
      return GattSession(
        services: serviceIds,
        batteryPercent: battery,
        codec: codec,
        information: info,
      );
    } on _ConnectTimedOut {
      await bridge.controller.unmanageDevice(deviceId);
      throw const ConnectFailed(PairingFailure.connectTimeout);
    } finally {
      await readySub.cancel();
      await dropSub.cancel();
    }
  }

  Future<void> disconnect(String deviceId) => bridge.controller.unmanageDevice(deviceId);

  Future<bool> isConnected(String deviceId) => bridge.controller.isPeripheralConnected(deviceId);

  Future<int> maximumWriteLength(String deviceId) {
    return bridge.controller.maximumWriteLength(deviceId);
  }

  Future<void> writeOutbound(String deviceId, Uint8List data) {
    return bridge.controller.writeCharacteristic(
      deviceId,
      characteristics.primaryService,
      characteristics.outbound,
      data,
    );
  }

  Future<void> writeCommand(String deviceId, Uint8List data) {
    return bridge.controller.writeCharacteristic(
      deviceId,
      characteristics.primaryService,
      characteristics.commands,
      data,
    );
  }

  Future<void> _subscribeNotifications(String deviceId, List<BleService> services) async {
    for (final characteristic in [characteristics.inbound, characteristics.commands]) {
      if (!_has(services, characteristics.primaryService, characteristic)) {
        logger.warn('Characteristic $characteristic is not on the device yet.');
        continue;
      }
      try {
        await bridge.controller.subscribeCharacteristic(
          deviceId,
          characteristics.primaryService,
          characteristic,
        );
      } catch (error) {
        logger.warn('Subscribe $characteristic failed: $error');
      }
    }
  }

  Future<int?> _readBattery(String deviceId, List<BleService> services) async {
    if (!_has(services, characteristics.batteryService, characteristics.batteryLevel)) {
      return null;
    }
    try {
      final bytes = await bridge.controller.readCharacteristic(
        deviceId,
        characteristics.batteryService,
        characteristics.batteryLevel,
      );
      return parseBatteryLevel(bytes);
    } catch (error) {
      logger.warn('Battery read failed: $error');
      return null;
    }
  }

  Future<NegotiatedCodec?> _readCodec(String deviceId, List<BleService> services) async {
    if (!_has(services, characteristics.primaryService, characteristics.audioCodec)) {
      return null;
    }
    try {
      final bytes = await bridge.controller.readCharacteristic(
        deviceId,
        characteristics.primaryService,
        characteristics.audioCodec,
      );
      return const CodecNegotiation().fromCharacteristic(bytes);
    } catch (error) {
      logger.warn('Codec read failed: $error');
      return null;
    }
  }

  Future<DeviceInformation?> _readInfo(String deviceId, List<BleService> services) async {
    if (!characteristics.hasService(
      services.map((service) => service.uuid),
      characteristics.deviceInfoService,
    )) {
      return null;
    }
    Future<String?> read(String characteristic) async {
      if (!_has(services, characteristics.deviceInfoService, characteristic)) return null;
      try {
        final bytes = await bridge.controller.readCharacteristic(
          deviceId,
          characteristics.deviceInfoService,
          characteristic,
        );
        return parseDeviceInfoString(bytes);
      } catch (_) {
        return null;
      }
    }

    return DeviceInformation(
      manufacturer: await read(characteristics.manufacturerName),
      model: await read(characteristics.modelNumber),
      serial: await read(characteristics.serialNumber),
      firmware: await read(characteristics.firmwareRevision),
      hardware: await read(characteristics.hardwareRevision),
    );
  }

  bool _has(List<BleService> services, String serviceUuid, String characteristicUuid) {
    final serviceTarget = serviceUuid.toLowerCase();
    final charTarget = characteristicUuid.toLowerCase();
    for (final service in services) {
      if (service.uuid.toLowerCase() != serviceTarget) continue;
      return service.characteristicUuids.any((item) => item.toLowerCase() == charTarget);
    }
    return false;
  }
}

class ConnectFailed implements Exception {
  const ConnectFailed(this.failure);
  final PairingFailure failure;

  @override
  String toString() => failure.message;
}

class _ConnectTimedOut implements Exception {
  const _ConnectTimedOut();
}

/// CAIPO's own device type. Service and characteristic UUIDs are the IoT
/// contract, not an OMI device-type name.
class CaipoDeviceConnection {
  CaipoDeviceConnection({required this.deviceId, required this.connection});

  final String deviceId;
  final DeviceConnection connection;

  static const deviceTypeName = 'caipo';

  String get serviceUuid => kPrimaryServiceUuid;
  String get inboundCharacteristicUuid => kInboundCharacteristicUuid;

  /// Heartbeat is device to app. Other non-transfer command bytes are not
  /// in the IoT contract, so none are sent.
  int? get unmuteCommandCode => null;
  int? get muteCommandCode => null;

  Future<GattSession> connect() => connection.connect(deviceId);

  Future<void> disconnect() => connection.disconnect(deviceId);
}
