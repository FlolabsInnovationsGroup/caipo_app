import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/config/proposed_flags.dart';
import '../../device/protocol/proposed_commands.dart';
import '../../device/stream/mjpeg_session.dart';
import '../../shared/copy/app_strings.dart';
import '../../shared/theme/caipo_tokens.dart';
import '../pairing/pairing_controller.dart';

/// Live view over the local network. The stream flag is off unless the build
/// sets PROPOSED_STREAM. The local-network permission is asked here, when the
/// user starts the camera, not at launch.
class LiveViewScreen extends StatefulWidget {
  const LiveViewScreen({super.key, required this.pairing});

  final PairingController pairing;

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  final MjpegSession _session = MjpegSession();
  Timer? _tick;
  Uint8List? _frame;
  Duration _left = kStreamAutoStop;
  var _starting = false;
  var _started = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.pairing.addListener(_onPairing);
    unawaited(_begin());
  }

  Future<void> _begin() async {
    if (!kProposedStream) {
      setState(() => _message = AppStrings.streamOff);
      return;
    }
    if (widget.pairing.connectedId == null) {
      setState(() => _message = AppStrings.pairCaipo);
      return;
    }
    setState(() {
      _starting = true;
      _started = true;
      _message = AppStrings.startingCamera;
    });
    await widget.pairing.sendStream(encodeStartStream());
  }

  void _onPairing() {
    final ready = widget.pairing.streamReady;
    if (!kProposedStream || ready == null || _tick != null || _frame != null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _countdown());
    unawaited(_open(ready.uri));
  }

  Future<void> _open(Uri uri) async {
    try {
      await _session.open(uri, (jpeg) {
        if (!mounted) return;
        setState(() {
          _frame = jpeg;
          _starting = false;
          _message = null;
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _message = '$error';
      });
    }
  }

  void _countdown() {
    if (!mounted) return;
    if (_left <= const Duration(seconds: 1)) {
      unawaited(_stop());
      return;
    }
    setState(() => _left -= const Duration(seconds: 1));
  }

  Future<void> _stop() async {
    _tick?.cancel();
    _tick = null;
    await _session.close();
    await widget.pairing.sendStream(encodeStopStream());
    if (!mounted) return;
    setState(() {
      _starting = false;
      _message = AppStrings.streamStopped;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.pairing.removeListener(_onPairing);
    unawaited(_session.close());
    if (_started) unawaited(widget.pairing.sendStream(encodeStopStream()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _left.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.liveView)),
      body: Padding(
        padding: const EdgeInsets.all(CaipoSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$kStreamWidth×$kStreamHeight, $kStreamFps fps'),
            if (kProposedStream && widget.pairing.connectedId != null && _message != AppStrings.streamStopped)
              Text('Stops in $minutes:$seconds'),
            const SizedBox(height: CaipoSpace.m),
            Expanded(child: _picture()),
          ],
        ),
      ),
    );
  }

  Widget _picture() {
    if (_frame != null) {
      return Image.memory(_frame!, gaplessPlayback: true, fit: BoxFit.contain);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_message ?? AppStrings.startingCamera, style: Theme.of(context).textTheme.titleMedium),
        if (_starting) ...[
          const SizedBox(height: CaipoSpace.s),
          Text(AppStrings.cameraBoot),
          if (Platform.isIOS) ...[
            const SizedBox(height: CaipoSpace.s),
            const Text(AppStrings.localNetworkAsk),
          ],
        ],
      ],
    );
  }
}
