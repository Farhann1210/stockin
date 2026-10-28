import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../onboarding_screen.dart';
import 'register_business_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_email.text, _password.text);
    } on BannedAccountException {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Akun Diblokir'),
          content: const Text(
            'Akun ini sudah dibanned dan tidak dapat digunakan lagi.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (error) {
      setState(
        () => _error = switch (error.code) {
          'invalid-credential' ||
          'user-not-found' ||
          'wrong-password' => 'Email atau kata sandi salah.',
          'invalid-email' => 'Format email tidak valid.',
          'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti.',
          _ => error.message ?? 'Login gagal.',
        },
      );
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/stockin_logo.png',
                  height: 190,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo Stokin',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kasir dan stok usaha dalam satu aplikasi',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      value == null ||
                          !value.contains('@') ||
                          value.trim().isEmpty
                      ? 'Masukkan email yang valid.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Kata sandi'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Masukkan kata sandi.'
                      : null,
                  onFieldSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Masuk'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterBusinessScreen(),
                          ),
                        ),
                  child: const Text('Daftarkan usaha baru'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OnboardingScreen(
                              onComplete: () async {
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ),
                  child: const Text('On Boarding'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
