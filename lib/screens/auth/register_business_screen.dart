import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class RegisterBusinessScreen extends StatefulWidget {
  const RegisterBusinessScreen({super.key});

  @override
  State<RegisterBusinessScreen> createState() => _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _business.dispose();
    _owner.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().register(
        businessName: _business.text,
        ownerName: _owner.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      setState(
        () => _error = switch (error.code) {
          'email-already-in-use' => 'Email sudah terdaftar.',
          'weak-password' => 'Kata sandi minimal 6 karakter.',
          'invalid-email' => 'Format email tidak valid.',
          _ => error.message ?? 'Pendaftaran gagal.',
        },
      );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Daftarkan Usaha')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  Image.asset(
                    'assets/images/stockin_logo.png',
                    height: 160,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo Stockin',
                  ),
                  const SizedBox(height: 12),
                  _field(_business, 'Nama usaha'),
                _field(_owner, 'Nama pemilik'),
                _field(_email, 'Email', email: true),
                _field(_password, 'Kata sandi (min. 6 karakter)', secret: true),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _register,
                  child: _busy
                      ? const CircularProgressIndicator()
                      : const Text('Buat Akun Owner'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool email = false,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: email ? TextInputType.emailAddress : null,
      obscureText: secret,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '$label wajib diisi.';
        if (email && !value.contains('@')) return 'Format email tidak valid.';
        if (secret && value.length < 6) return 'Kata sandi minimal 6 karakter.';
        return null;
      },
    ),
  );
}
