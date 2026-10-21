import 'package:caipo_app/core/config/app_paths.dart';
import 'package:caipo_app/core/di/injector.dart';
import 'package:caipo_app/device/audio/opus_codec.dart';
import 'package:caipo_app/core/errors/error_handler.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/features/auth/auth_screen.dart';
import 'package:caipo_app/features/auth/biometric_gate.dart';
import 'package:caipo_app/features/privacy/local_data.dart';
import 'package:caipo_app/features/auth/session_controller.dart';
import 'package:caipo_app/device/protocol/transfer_archive.dart';
import 'package:caipo_app/features/conversation/photo_question.dart';
import 'package:caipo_app/features/conversation/voice_loop.dart';
import 'package:caipo_app/features/notifications/notification_center.dart';
import 'package:caipo_app/features/onboarding/onboarding_screen.dart';
import 'package:caipo_app/features/pairing/pairing_controller.dart';
import 'package:caipo_app/device/wifi/wifi_networks.dart';
import 'package:caipo_app/device/wifi/wifi_sender.dart';
import 'package:caipo_app/features/shell/app_shell.dart';
import 'package:caipo_app/flobrain/profile_repository.dart';
import 'package:caipo_app/flobrain/settings_repository.dart';
import 'package:caipo_app/shared/theme/caipo_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const onboardingDoneKey = 'caipo.onboarding_done';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const logger = AppLogger();
  installErrorHandlers(logger);
  try {
    await OpusCodec.ensureLoaded();
  } catch (error, stack) {
    logger.error('libopus did not load', error: error, stackTrace: stack);
  }
  await configureDependencies();
  final session = getIt<SessionController>();
  session.start();
  await session.bootstrap();
  runApp(const CaipoApp());
}

class CaipoApp extends StatelessWidget {
  const CaipoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CAIPO',
      theme: caipoLightTheme(),
      darkTheme: caipoDarkTheme(),
      themeMode: ThemeMode.system,
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  var _pairingStarted = false;

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionController>();
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        if (!session.ready) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!session.signedIn || session.locked) {
          return AuthScreen(
            session: session,
            locked: session.locked,
            biometricEnabled: session.locked && getIt<SettingsRepository>().biometricUnlock(),
            biometrics: getIt<BiometricGate>(),
          );
        }
        final preferences = getIt<SharedPreferences>();
        if (!(preferences.getBool(onboardingDoneKey) ?? false)) {
          return OnboardingScreen(
            onFinished: () async {
              await preferences.setBool(onboardingDoneKey, true);
              if (mounted) setState(() {});
            },
          );
        }
        final pairing = getIt<PairingController>();
        if (!_pairingStarted) {
          _pairingStarted = true;
          pairing.start();
        }
        return Listener(
          onPointerDown: (_) => session.noteActivity(),
          child: AppShell(
            session: session,
            pairing: pairing,
            settings: getIt<SettingsRepository>(),
            voice: getIt<VoiceLoopController>(),
            notices: getIt<NotificationCenter>(),
            paths: getIt<AppPaths>(),
            profile: getIt<ProfileRepository>(),
            wifiNetworks: getIt<WifiNetworkStore>(),
            wifiSender: getIt<WifiSender>(),
            privacy: getIt<PrivacyActions>(),
            biometrics: getIt<BiometricGate>(),
            photo: getIt<PhotoQuestionController>(),
            archive: getIt<TransferArchive>(),
          ),
        );
      },
    );
  }
}
