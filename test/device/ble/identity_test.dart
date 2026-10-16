import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/device/ble/scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the confirmed GATT identity is what the app scans for', () {
    expect(kPrimaryServiceUuid, 'a1000000-5fa6-43f5-9827-201f62bd377d');
    expect(kInboundCharacteristicUuid, 'a1000001-5fa6-43f5-9827-201f62bd377d');
    expect(kAudioCodecCharacteristicUuid, 'a1000002-5fa6-43f5-9827-201f62bd377d');
    expect(kOutboundCharacteristicUuid, 'a1000003-5fa6-43f5-9827-201f62bd377d');
    expect(kCommandCharacteristicUuid, 'a1000004-5fa6-43f5-9827-201f62bd377d');
    expect(kAdvertisedNamePrefix, 'CAIPO');
    expect(kRequiresBond, isTrue);
    expect(kOpcodeTransferRequest, 0x01);
    expect(kOpcodeHeartbeat, 0x10);
    expect(kMaxChunkBytes, 502);
    expect(kChunkHeaderBytes + kMaxChunkBytes, kNegotiatedMtuBytes - 3);
    expect(kRealtimeAudioStreaming, isFalse);
  });

  test('a named advertisement must start with CAIPO', () {
    expect(
      caipoAdvertisementMatches(name: 'CAIPO-01', serviceUuids: const []),
      isTrue,
    );
    expect(
      caipoAdvertisementMatches(name: 'OMI', serviceUuids: const [kPrimaryServiceUuid]),
      isFalse,
    );
    expect(
      caipoAdvertisementMatches(name: '', serviceUuids: const [kPrimaryServiceUuid]),
      isTrue,
    );
  });
}
