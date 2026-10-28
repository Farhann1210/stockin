import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'owner/owner_dashboard.dart';
import 'kasir/kasir_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'stok/stok_dashboard.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String? _profileUid;
  Future<UserModel?>? _profileFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final user = snapshot.data;
        if (user == null) {
          _profileUid = null;
          _profileFuture = null;
          return const LoginScreen();
        }
        return FutureBuilder<UserModel?>(
          future: _loadProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            if (profileSnapshot.hasError || profileSnapshot.data == null) {
              return _ProfileError(
                message:
                    'Profil akun tidak dapat dimuat. '
                    'Silakan keluar lalu coba kembali.',
              );
            }
            final profile = profileSnapshot.data!;
            if (profile.isBanned) return const _BannedAccountScreen();
            if (!profile.isActive) {
              FirebaseAuth.instance.signOut();
              return const _LoadingScreen();
            }
            switch (profile.role) {
              case roleOwner:
                return OwnerDashboard(profile: profile);
              case roleCashier:
                return KasirDashboard(
                  profile: profile,
                );
              case roleStock:
                return StokDashboard(
                  profile: profile,
                );
              case roleAdmin:
                return AdminDashboard(profile: profile);
              default:
                return _ProfileError(
                  message: 'Role akun tidak dikenal. Hubungi pemilik usaha.',
                );
            }
          },
        );
      },
    );
  }

  Future<UserModel?> _loadProfile(String uid) {
    if (_profileUid != uid) {
      _profileUid = uid;
      _profileFuture = AuthService().loadProfile(uid);
    }
    return _profileFuture!;
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Keluar'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BannedAccountScreen extends StatefulWidget {
  const _BannedAccountScreen();

  @override
  State<_BannedAccountScreen> createState() => _BannedAccountScreenState();
}

class _BannedAccountScreenState extends State<_BannedAccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice());
  }

  Future<void> _showNotice() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
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
    if (mounted) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
