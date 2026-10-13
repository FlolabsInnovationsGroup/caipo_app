import 'package:caipo_app/core/di/injector.dart';
import 'package:caipo_app/core/errors/error_handler.dart';
import 'package:caipo_app/core/logging/app_logger.dart';
import 'package:caipo_app/features/auth/auth_screen.dart';
import 'package:caipo_app/features/auth/session_controller.dart';
import 'package:caipo_app/features/pairing/pairing_controller.dart';
import 'package:caipo_app/features/pairing/pairing_screen.dart';
import 'package:caipo_app/flobrain/settings_repository.dart';
import 'package:caipo_app/shared/theme/caipo_theme.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const logger = AppLogger();
  installErrorHandlers(logger);
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
      theme: caipoTheme(),
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
          return AuthScreen(session: session, locked: session.locked);
        }
        final pairing = getIt<PairingController>();
        if (!_pairingStarted) {
          _pairingStarted = true;
          pairing.start();
        }
        return Listener(
          onPointerDown: (_) => session.noteActivity(),
          child: PairingScreen(
            session: session,
            pairing: pairing,
            settings: getIt<SettingsRepository>(),
          ),
        );
      },
    );
  }
}
