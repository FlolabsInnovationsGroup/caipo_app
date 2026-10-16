import 'dart:typed_data';

import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/core/config/proposed_flags.dart';
import 'package:caipo_app/core/errors/app_exception.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/device/protocol/proposed_commands.dart';
import 'package:caipo_app/device/wifi/provisioning.dart';
import 'package:caipo_app/device/wifi/wifi_networks.dart';
import 'package:caipo_app/flobrain/api_client.dart';
import 'package:caipo_app/flobrain/proposed_clients.dart';
import 'package:caipo_app/flobrain/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proposed commands round-trip and camera controls stay off without status', () {
    final status = const DeviceStatus(state: kDeviceStateActive, batteryPercent: 40, flags: kStatusFlagCharging, pendingUploads: 3);
    final decoded = decodeProposedCommand(encodeStatus(status));
    expect(decoded, isA<DeviceStatus>());
    final back = decoded! as DeviceStatus;
    expect(back.pendingUploads, 3);
    expect(back.charging, isTrue);
    expect(back.wifiConnected, isFalse);
    expect(encodeSetTime(0x01020304), [kProposedSetTime, 0x04, 0x03, 0x02, 0x01]);
    expect(encodeRecordVideo(0).last, 1);
    expect(
      cameraControlReason(commandsEnabled: false, status: status),
      'Needs device support',
    );
    expect(
      cameraControlReason(commandsEnabled: true, status: status),
      'Needs WiFi',
    );
    expect(
      cameraControlReason(
        commandsEnabled: true,
        status: const DeviceStatus(
          state: kDeviceStateActive,
          batteryPercent: 80,
          flags: kStatusFlagWifiConnected,
          pendingUploads: 0,
        ),
      ),
      isNull,
    );
    expect(kProposedStream, isFalse);
    final ready = StreamReady(address: const [192, 168, 1, 20], port: 8080, token: Uint8List.fromList(List<int>.filled(16, 0xAB)));
    final bytes = encodeStreamReady(ready);
    expect(bytes.length, 23);
    expect(bytes[0], kProposedStreamReady);
    final backReady = decodeProposedCommand(bytes)! as StreamReady;
    expect(backReady.port, 8080);
    expect(backReady.uri.toString(), 'http://192.168.1.20:8080/stream?token=${'ab' * 16}');
    expect(encodeStartStream(), [kProposedStartStream]);
    expect(encodeStopStream(), [kProposedStopStream]);
    expect(
      liveViewReason(streamEnabled: false, commandsEnabled: true, status: status),
      'Live streaming is proposed and turned off.',
    );
    expect(
      liveViewReason(streamEnabled: true, commandsEnabled: true, status: status),
      'Needs WiFi',
    );
  });

  test('wifi provisioning does not write while the flag is off', () async {
    var writes = 0;
    final result = await const WifiProvisioner(enabled: false).send(
      networks: const [WifiNetwork(ssid: 'home', password: 'secret')],
      deviceToken: 'token',
      bonded: true,
      writePayload: (_) async => writes++,
    );
    expect(result.sent, isFalse);
    expect(writes, 0);
  });

  test('wifi list keeps five networks in priority order', () async {
    var saved = '';
    final store = WifiNetworkStore(read: () async => saved.isEmpty ? null : saved, write: (value) async => saved = value);
    for (var i = 0; i < 5; i++) {
      await store.add(WifiNetwork(ssid: 'net-$i', password: 'pw'));
    }
    expect(store.add(const WifiNetwork(ssid: 'extra', password: 'pw')), throwsStateError);
    final moved = await store.move(4, 0);
    expect(moved.first.ssid, 'net-4');
  });

  test('proposed speech and media stay unavailable while their flags are off', () async {
    final api = FloBrainApi(tokenStore: MemoryTokenStore(), logger: const AppLogger(), mockBackend: true);
    final speech = ProposedSpeechClient(api, enabled: false);
    expect(speech.transcribe(Uint8List(2)), throwsA(isA<SpeechUnavailable>()));
    expect(speech.synthesize('hi'), throwsA(isA<SpeechUnavailable>()));
    final media = FloBrainMediaClient(api, enabled: false);
    expect(media.list(), throwsA(isA<AppException>()));
    expect(kAuthorizationPrefix, 'Token');
  });
}
