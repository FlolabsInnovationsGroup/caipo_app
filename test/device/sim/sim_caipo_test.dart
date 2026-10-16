import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:caipo_app/core/config/constants.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/device/audio/opus_codec.dart';
import 'package:caipo_app/device/audio/opus_container.dart';
import 'package:caipo_app/device/audio/wav_pcm.dart';
import 'package:caipo_app/device/ble/connection.dart';
import 'package:caipo_app/device/protocol/device_transfer_session.dart';
import 'package:caipo_app/device/protocol/messages.dart';
import 'package:caipo_app/device/protocol/proposed_commands.dart';
import 'package:caipo_app/device/stream/mjpeg_session.dart';
import 'package:caipo_app/device/protocol/transfer_manager.dart';
import 'package:caipo_app/device/sim/sim_caipo_controller.dart';
import 'package:caipo_app/device/sim/sim_sample.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/load_opus.dart';

void main() {
  setUpAll(loadOpusForTests);

  test('simulated CAIPO connects, beats, and stores a decoded Opus reply', () async {
    final dir = await Directory.systemTemp.createTemp('caipo-sim');
    final bridge = SimCaipoController.open(replyDirectory: dir);
    final connection = DeviceConnection(bridge, const AppLogger());
    final heartbeats = <int>[];
    bridge.characteristicValues.stream.listen((event) {
      if (event.characteristicUuid.toLowerCase() != kCommandCharacteristicUuid.toLowerCase()) return;
      final beat = decodeWire(event.value);
      if (beat is HeartbeatMessage) heartbeats.add(beat.counter);
    });
    final transfers = DeviceTransferSession(
      deviceId: SimCaipoController.deviceId,
      connection: connection,
      events: bridge.characteristicValues.stream,
      logger: const AppLogger(),
    )..start();

    final session = await connection.connect(SimCaipoController.deviceId);
    await Future<void>.delayed(Duration.zero);

    expect(session.codec?.id, kCodecOpus16kHz);
    expect(session.batteryPercent, 87);
    expect(session.information?.model, 'CAIPO-SIM');
    expect(await connection.maximumWriteLength(SimCaipoController.deviceId), 509);
    expect(heartbeats, isNotEmpty);
    expect(heartbeats.first, 0);

    final tone = Int16List(kOpusFrameSamples);
    tone[0] = 1200;
    final opus = OpusCodec.shared.encodeSamples(tone);
    final prepared = const TransferManager().prepare(
      payload: opus,
      transferId: 9,
      contentType: kContentTypeAudio,
    );
    await connection.writeOutbound(SimCaipoController.deviceId, prepared.request);
    await connection.writeOutbound(SimCaipoController.deviceId, prepared.metadata);
    for (final chunk in prepared.chunks) {
      await connection.writeOutbound(SimCaipoController.deviceId, chunk);
    }

    final saved = dir.listSync().whereType<File>().toList();
    expect(saved, hasLength(1));
    expect(saved.single.path, endsWith('.wav'));
    final wav = parseWav(await saved.single.readAsBytes());
    expect(wav.sampleRate, 16000);
    expect(wav.samples, isNotEmpty);
    await transfers.stop();
    await dir.delete(recursive: true);
  });

  test('bundled speech is a wav and encodes to Opus frames', () async {
    final data = await rootBundle.load(kSimSpeechAsset);
    final wavBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    expect(String.fromCharCodes(wavBytes.sublist(0, 4)), 'RIFF');
    final encoded = OpusCodec.shared.encodeWav(wavBytes);
    final frames = const OpusFrameContainer().unpack(encoded);
    expect(frames, isNotEmpty);
    expect(frames.first.length, lessThan(200));
    final pcm = OpusCodec.shared.decodeContainer(encoded);
    expect(pcm.length, greaterThan(320));
  });

  test('CAIPO-SIM answers START_STREAM with a local MJPEG stream', () async {
    final bridge = SimCaipoController.open();
    final connection = DeviceConnection(bridge, const AppLogger());
    final ready = Completer<StreamReady>();
    bridge.characteristicValues.stream.listen((event) {
      if (event.characteristicUuid.toLowerCase() != kCommandCharacteristicUuid.toLowerCase()) return;
      final decoded = decodeProposedCommand(event.value);
      if (decoded is StreamReady && !ready.isCompleted) ready.complete(decoded);
    });
    await connection.connect(SimCaipoController.deviceId);
    try {
      await connection.writeCommand(SimCaipoController.deviceId, encodeStartStream());
      final announced = await ready.future.timeout(const Duration(seconds: 5));
      expect(announced.uri.path, '/stream');
      expect(announced.tokenHex, hasLength(32));
      // The widget binding replaces HttpClient with a stub. This zone uses the real one.
      await HttpOverrides.runZoned(() async {
        final client = HttpClient();
        final denied = await client.getUrl(announced.uri.replace(queryParameters: {'token': '00' * 16}));
        final deniedResponse = await denied.close();
        expect(deniedResponse.statusCode, 403);
        await deniedResponse.drain<void>();

        final request = await client.getUrl(announced.uri);
        final response = await request.close();
        expect(response.statusCode, 200);
        expect(response.headers.value(HttpHeaders.contentTypeHeader), contains('multipart/x-mixed-replace'));
        final scanner = JpegScanner();
        Uint8List? jpeg;
        await for (final chunk in response.timeout(const Duration(seconds: 3))) {
          jpeg = scanner.push(chunk);
          if (jpeg != null) break;
        }
        expect(jpeg, isNotNull);
        expect(jpeg!.sublist(0, 2), [0xFF, 0xD8]);
        client.close(force: true);
      }, createHttpClient: (context) => _RealHttp().createHttpClient(context));
      await connection.writeCommand(SimCaipoController.deviceId, encodeStopStream());
    } finally {
      await connection.disconnect(SimCaipoController.deviceId);
    }
  });
}

class _RealHttp extends HttpOverrides {}
