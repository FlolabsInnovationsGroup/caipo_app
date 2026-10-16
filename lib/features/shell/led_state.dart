import 'package:flutter/material.dart';

import '../../device/device_state.dart';
import '../../shared/theme/caipo_tokens.dart';
import '../conversation/voice_loop.dart';

class LedReadout {
  const LedReadout({required this.color, required this.name});

  final Color color;
  final String name;
}

/// The lit LED for the current link and voice phase.
///
/// Video and charging stay in the palette. Nothing in this build reports
/// those states, so they are not shown as the current light.
LedReadout currentLed({
  required CaipoLinkState link,
  required VoicePhase phase,
  required bool failed,
  int? batteryPercent,
  bool charging = false,
  bool recordingVideo = false,
}) {
  if (failed) {
    return const LedReadout(color: CaipoPalette.ledAlert, name: 'Error or low battery');
  }
  if (charging) {
    return const LedReadout(color: CaipoPalette.ledCharging, name: 'Charging');
  }
  if (recordingVideo) {
    return const LedReadout(color: CaipoPalette.ledVideo, name: 'Video');
  }
  if (batteryPercent != null && batteryPercent <= 20) {
    return const LedReadout(color: CaipoPalette.ledAlert, name: 'Error or low battery');
  }
  if (phase == VoicePhase.processing) {
    return const LedReadout(color: CaipoPalette.ledProcessing, name: 'Processing');
  }
  if (phase == VoicePhase.listening || phase == VoicePhase.sending) {
    return const LedReadout(color: CaipoPalette.ledAudio, name: 'Audio');
  }
  if (link == CaipoLinkState.connecting || link == CaipoLinkState.reconnecting) {
    return const LedReadout(color: CaipoPalette.ledBoot, name: 'Boot');
  }
  return const LedReadout(color: CaipoPalette.ledStandby, name: 'Standby');
}

const ledLegend = <LedReadout>[
  LedReadout(color: CaipoPalette.ledStandby, name: 'Standby'),
  LedReadout(color: CaipoPalette.ledBoot, name: 'Boot'),
  LedReadout(color: CaipoPalette.ledVideo, name: 'Video'),
  LedReadout(color: CaipoPalette.ledAudio, name: 'Audio'),
  LedReadout(color: CaipoPalette.ledAlert, name: 'Error or low battery'),
  LedReadout(color: CaipoPalette.ledCharging, name: 'Charging'),
  LedReadout(color: CaipoPalette.ledProcessing, name: 'Processing'),
];
