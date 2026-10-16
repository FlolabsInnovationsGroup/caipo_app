import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../core/config/constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../device/audio/opus_codec.dart';
import '../../device/ble/ble_bridge.dart';
import '../../device/ble/connection.dart';
import '../../device/protocol/chunker.dart';
import '../../device/protocol/frame_queue.dart';
import '../../device/protocol/transfer_archive.dart';
import '../../device/protocol/transfer_manager.dart';
import '../../flobrain/chat_repository.dart';
import '../../flobrain/speech_clients.dart';
import 'history_store.dart';

enum VoicePhase { idle, listening, processing, sending, done }

/// Recording to reply: decode, STT, FloBrain chat, TTS, Opus, R03.
class VoiceLoopController extends ChangeNotifier {
  VoiceLoopController({
    required this.connection,
    required this.bridge,
    required this.chats,
    required this.speech,
    required this.archive,
    required this.history,
    required this.logger,
    OpusCodec? codec,
    this.idleTimeout = kConversationIdleTimeout,
  }) : codec = codec ?? OpusCodec.shared;

  final DeviceConnection connection;
  final BleBridge bridge;
  final ChatRepository chats;
  final SpeechClient speech;
  final TransferArchive archive;
  final ConversationHistoryStore history;
  final AppLogger logger;
  final OpusCodec codec;
  final Duration idleTimeout;

  VoicePhase phase = VoicePhase.idle;
  String? transcript;
  String? replyText;
  String? alert;
  String? replyWavPath;
  int? lastTransferBytes;
  int? lastTransferMillis;
  var retryable = false;

  String? _deviceId;
  String? _chatId;
  String? _unsentName;
  Uint8List? _lastRecording;
  var _codecSupported = true;
  var _generation = 0;
  var _nextTransfer = 2;
  Timer? _idle;
  TransferCancellation? _cancellation;

  bool get sessionOpen => _chatId != null;

  void noteReplyWav(String path) {
    replyWavPath = path;
    final cipher = archive.cipher;
    if (cipher == null) {
      notifyListeners();
      return;
    }
    unawaited(() async {
      final file = File(path);
      if (!file.existsSync()) return;
      final plain = Uint8List.fromList(await file.readAsBytes());
      if (!cipher.isSealed(plain)) {
        await file.writeAsBytes(await cipher.seal(plain), flush: true);
      }
      if (replyWavPath == path) notifyListeners();
    }());
  }

  Future<Uint8List> readStored(String path) async {
    final bytes = Uint8List.fromList(await File(path).readAsBytes());
    final cipher = archive.cipher;
    if (cipher == null) return bytes;
    return cipher.open(bytes);
  }

  String get label {
    switch (phase) {
      case VoicePhase.idle:
        return 'Idle';
      case VoicePhase.listening:
        return 'Listening';
      case VoicePhase.processing:
        return 'Processing';
      case VoicePhase.sending:
        return 'Sending';
      case VoicePhase.done:
        return 'Done';
    }
  }

  void markListening() {
    phase = VoicePhase.listening;
    alert = null;
    retryable = false;
    _touchIdle();
    notifyListeners();
  }

  void showBlocked(String message) {
    alert = message;
    retryable = false;
    phase = VoicePhase.idle;
    notifyListeners();
  }

  Future<void> acceptTransfer(
    String deviceId,
    Uint8List payload,
    int contentType, {
    required bool codecSupported,
    bool runLoop = true,
    bool persist = true,
  }) async {
    if (persist) await archive.save(bytes: payload, contentType: contentType);
    if (!runLoop || contentType != kContentTypeAudio) return;
    _deviceId = deviceId;
    _codecSupported = codecSupported;
    _lastRecording = Uint8List.fromList(payload);
    await _run();
  }

  Future<void> retry() async {
    if (_lastRecording == null || !retryable) return;
    await _run();
  }

  Future<void> retryRecording(String name) async {
    _lastRecording = await history.readRecording(name);
    _unsentName = name;
    retryable = true;
    if (_deviceId == null) {
      alert = 'Reconnect to CAIPO, then retry.';
      notifyListeners();
      return;
    }
    await _run();
  }

  void cancel() {
    _generation++;
    _cancellation?.cancel();
    _cancellation = null;
    if (phase == VoicePhase.processing || phase == VoicePhase.sending || phase == VoicePhase.listening) {
      phase = VoicePhase.idle;
      notifyListeners();
    }
  }

  void endSession() {
    _generation++;
    _cancellation?.cancel();
    _cancellation = null;
    _idle?.cancel();
    _chatId = null;
    transcript = null;
    replyText = null;
    alert = null;
    retryable = false;
    phase = VoicePhase.idle;
    notifyListeners();
  }

  Future<void> _run() async {
    final recording = _lastRecording;
    final deviceId = _deviceId;
    if (recording == null || deviceId == null) return;
    final generation = ++_generation;
    final cancellation = TransferCancellation();
    _cancellation = cancellation;
    alert = null;
    retryable = false;
    if (!_codecSupported) {
      showBlocked('Codec 21 is the only supported format.');
      return;
    }
    phase = VoicePhase.processing;
    notifyListeners();
    try {
      final pcm = codec.decodeContainer(recording);
      if (generation != _generation) return;
      final text = await speech.transcribe(pcm);
      if (generation != _generation) return;
      transcript = text;
      final chatId = await _chat();
      final sent = await chats.send(chatId, {'text': text});
      if (generation != _generation) return;
      final reply = '${sent['reply'] ?? ''}'.trim();
      if (reply.isEmpty) {
        throw const AppException('FloBrain returned no reply.');
      }
      replyText = reply;
      await history.append(role: 'user', text: text);
      await history.append(role: 'assistant', text: reply);
      final replyPcm = await speech.synthesize(reply);
      if (replyPcm.isEmpty) {
        throw const SpeechUnavailable('Text to speech is not available.');
      }
      final encoded = codec.encodeSamples(_pcmSamples(replyPcm));
      if (generation != _generation || cancellation.cancelled) return;
      phase = VoicePhase.sending;
      notifyListeners();
      final writeLength = await connection.maximumWriteLength(deviceId);
      final manager = TransferManager(chunker: Chunker(maxChunkBytes: chunkPayloadBytes(writeLength)));
      final prepared = manager.prepare(
        payload: encoded,
        transferId: _nextTransfer++,
        contentType: kContentTypeAudio,
      );
      final watch = Stopwatch()..start();
      final progress = await manager.exchange(
        prepared: prepared,
        write: (frame) {
          unawaited(connection.writeOutbound(deviceId, frame));
        },
        inbound: _inbound(deviceId),
        cancellation: cancellation,
      );
      if (generation != _generation || progress.detail == 'Cancelled.') return;
      if (progress.phase != TransferPhase.acknowledged) {
        throw AppException(progress.detail ?? 'The reply was not acknowledged.');
      }
      lastTransferBytes = encoded.length;
      lastTransferMillis = watch.elapsedMilliseconds;
      final saved = _unsentName;
      _unsentName = null;
      if (saved != null) await history.dropRecording(saved);
      phase = VoicePhase.done;
      _touchIdle();
    } on SpeechUnavailable catch (error) {
      if (generation != _generation) return;
      alert = error.message;
      await _keepUnsent(recording);
      retryable = _lastRecording != null;
      phase = VoicePhase.idle;
    } catch (error, stack) {
      if (generation != _generation) return;
      logger.error('Voice loop failed', error: error, stackTrace: stack);
      alert = _message(error);
      await _keepUnsent(recording);
      retryable = true;
      phase = VoicePhase.idle;
    }
    if (generation == _generation) notifyListeners();
  }

  Future<String> _chat() async {
    final existing = _chatId;
    if (existing != null) return existing;
    final created = await chats.create({'title': 'CAIPO'});
    final id = '${created['id'] ?? ''}';
    if (id.isEmpty) throw const AppException('FloBrain did not open a chat.');
    _chatId = id;
    return id;
  }

  Stream<Uint8List> _inbound(String deviceId) {
    return bridge.characteristicValues.stream
        .where(
          (event) =>
              event.id.toLowerCase() == deviceId.toLowerCase() &&
              event.characteristicUuid.toLowerCase() == kInboundCharacteristicUuid.toLowerCase(),
        )
        .map((event) => event.value);
  }

  Int16List _pcmSamples(Uint8List pcm) {
    final view = ByteData.sublistView(pcm);
    final samples = Int16List(pcm.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little);
    }
    return samples;
  }

  String _message(Object error) {
    if (error is AppException) return error.message;
    return 'The request failed. Try again.';
  }

  Future<void> _keepUnsent(Uint8List recording) async {
    try {
      _unsentName ??= await history.saveRecording(recording);
      final entries = await history.load();
      entries.removeWhere((entry) => entry['recording'] == _unsentName);
      entries.add({
        'role': 'user',
        'text': transcript ?? 'Not sent',
        'status': 'not_sent',
        'recording': _unsentName,
        'at': DateTime.now().toUtc().toIso8601String(),
      });
      await history.replace(entries);
    } catch (error, stack) {
      logger.error('Could not keep the unsent recording', error: error, stackTrace: stack);
    }
  }

  void _touchIdle() {
    _idle?.cancel();
    _idle = Timer(idleTimeout, endSession);
  }
}
