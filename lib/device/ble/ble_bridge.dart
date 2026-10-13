import 'dart:async';
import 'dart:typed_data';

import 'package:caipo_app/gen/ble_api.g.dart';

/// Native → Dart event hub. One instance is registered with Pigeon.
class BleBridge extends BleFlutterApi {
  BleBridge({BleHostApi? hostApi}) : hostApi = hostApi ?? BleHostApi();

  final BleHostApi hostApi;

  final bluetoothState = StreamController<String>.broadcast();
  final discoveries = StreamController<BlePeripheral>.broadcast();
  final deviceReady = StreamController<DeviceReadyEvent>.broadcast();
  final disconnected = StreamController<DisconnectEvent>.broadcast();
  final characteristicValues = StreamController<CharacteristicEvent>.broadcast();
  final rssiUpdates = StreamController<RssiEvent>.broadcast();
  final restored = StreamController<List<String>>.broadcast();

  bool _bound = false;

  void bind() {
    if (_bound) return;
    BleFlutterApi.setUp(this);
    _bound = true;
  }

  @override
  void onBluetoothStateChanged(String state) {
    if (!bluetoothState.isClosed) bluetoothState.add(state);
  }

  @override
  void onPeripheralDiscovered(BlePeripheral peripheral) {
    if (!discoveries.isClosed) discoveries.add(peripheral);
  }

  @override
  void onDeviceReady(String peripheralUuid, List<BleService> services) {
    if (!deviceReady.isClosed) {
      deviceReady.add(DeviceReadyEvent(peripheralUuid, services));
    }
  }

  @override
  void onPeripheralDisconnected(String peripheralUuid, String? error) {
    if (!disconnected.isClosed) {
      disconnected.add(DisconnectEvent(peripheralUuid, error));
    }
  }

  @override
  void onCharacteristicValueUpdated(
    String peripheralUuid,
    String serviceUuid,
    String characteristicUuid,
    Uint8List value,
  ) {
    if (!characteristicValues.isClosed) {
      characteristicValues.add(
        CharacteristicEvent(
          peripheralUuid,
          serviceUuid,
          characteristicUuid,
          value,
        ),
      );
    }
  }

  @override
  void onRssiUpdate(String peripheralUuid, int rssi) {
    if (!rssiUpdates.isClosed) {
      rssiUpdates.add(RssiEvent(peripheralUuid, rssi));
    }
  }

  @override
  void onStateRestored(List<String> peripheralUuids) {
    if (!restored.isClosed) restored.add(peripheralUuids);
  }
}

class DeviceReadyEvent {
  const DeviceReadyEvent(this.id, this.services);
  final String id;
  final List<BleService> services;
}

class DisconnectEvent {
  const DisconnectEvent(this.id, this.error);
  final String id;
  final String? error;
}

class CharacteristicEvent {
  const CharacteristicEvent(this.id, this.serviceUuid, this.characteristicUuid, this.value);
  final String id;
  final String serviceUuid;
  final String characteristicUuid;
  final Uint8List value;
}

class RssiEvent {
  const RssiEvent(this.id, this.rssi);
  final String id;
  final int rssi;
}
