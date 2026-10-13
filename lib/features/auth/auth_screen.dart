import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import 'session_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session, required this.locked});

  final SessionController session;
  final bool locked;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _registering = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await widget.session.register(_email.text.trim(), _password.text);
      } else {
        await widget.session.signIn(_email.text.trim(), _password.text);
      }
    } catch (error) {
      setState(() => _error = error is AppException ? error.message : '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(widget.locked ? 'Session locked' : 'Sign in to FloBrain', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              widget.locked
                  ? 'Sign in again to continue. Your CAIPO pairing is still saved on this phone.'
                  : 'Tokens stay in the Keychain on iOS and the Android Keystore.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Please wait…' : (_registering ? 'Create account' : 'Sign in')),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _registering = !_registering;
                      _error = null;
                    }),
              child: Text(_registering ? 'I already have an account' : 'Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
