import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';

const _onboardingCompletedKey = 'onboarding_completed';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late Future<SharedPreferences> _preferences = SharedPreferences.getInstance();
  bool? _completed;

  Future<void> _completeOnboarding() async {
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
    future: _preferences,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pengaturan aplikasi tidak dapat dimuat. '
                    'Silakan coba kembali.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(
                      () => _preferences = SharedPreferences.getInstance(),
                    ),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      final isComplete =
          _completed ?? snapshot.data!.getBool(_onboardingCompletedKey) ?? false;
      if (isComplete) return const AppRouter();
      return OnboardingScreen(
        onComplete: () async {
          final saved = await snapshot.data!.setBool(
            _onboardingCompletedKey,
            true,
          );
          if (!saved) {
            throw StateError('Status onboarding tidak dapat disimpan.');
          }
          await _completeOnboarding();
        },
      );
    },
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _busy = false;
  String? _error;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.storefront_outlined,
      title: 'Kenali Stockin',
      description: 'Kelola usaha dari satu tempat dengan lebih praktis.',
    ),
    _OnboardingPageData(
      icon: Icons.point_of_sale_outlined,
      title: 'Penjualan lebih praktis',
      description: 'Catat transaksi kasir dan pantau penjualan harian.',
    ),
    _OnboardingPageData(
      icon: Icons.inventory_2_outlined,
      title: 'Pantau stok dengan jelas',
      description: 'Catat stok masuk dan keluar serta lihat riwayat mutasi.',
    ),
    _OnboardingPageData(
      icon: Icons.groups_outlined,
      title: 'Kelola tim dan bisnis',
      description: 'Atur produk, akun karyawan, membership, dan ringkasan.',
    ),
    _OnboardingPageData(
      icon: Icons.rocket_launch_outlined,
      title: 'Mulai bersama Stockin',
      description: 'Masuk atau daftarkan usaha Anda untuk mulai menggunakan '
          'fitur kasir dan manajemen stok.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onComplete();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _finish,
                  child: const Text('Lewati'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (page) => setState(() {
                    _currentPage = page;
                    _error = null;
                  }),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(32, 24, 32, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 62,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Icon(
                              page.icon,
                              size: 58,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _currentPage ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _controller.previousPage(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                              ),
                        child: const Text('Kembali'),
                      )
                    else
                      const SizedBox(width: 84),
                    const Spacer(),
                    FilledButton(
                      onPressed: _busy ? null : _next,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _currentPage == _pages.length - 1
                                  ? 'Mulai'
                                  : 'Lanjut',
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
