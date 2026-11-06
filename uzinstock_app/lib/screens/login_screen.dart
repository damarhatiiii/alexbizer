import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../state/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final isWide = !context.isMobile;

    if (isWide) {
      return _DesktopLogin(
        auth: auth,
        cs: cs,
        userCtrl: _user,
        passCtrl: _pass,
        obscure: _obscure,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onSubmit: _submit,
      );
    }

    return _MobileLogin(
      auth: auth,
      cs: cs,
      userCtrl: _user,
      passCtrl: _pass,
      obscure: _obscure,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onSubmit: _submit,
    );
  }

  void _submit() => ref.read(authProvider.notifier).login(_user.text.trim(), _pass.text);
}

class _MobileLogin extends StatelessWidget {
  final AuthState auth;
  final ColorScheme cs;
  final TextEditingController userCtrl, passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure, onSubmit;

  const _MobileLogin({
    required this.auth,
    required this.cs,
    required this.userCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(28, top + 48, 28, 44),
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    right: -70,
                    top: -90,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const UzinLogo(width: 210, borderRadius: 20),
                      const SizedBox(height: 18),
                      const Text('UzinStock',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text('PT Uzin Utz Indonesia\nInventory & Prediksi ROP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              height: 1.4)),
                    ],
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Selamat datang',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy900)),
                      const SizedBox(height: 4),
                      const Text('Masuk untuk mengelola stok gudang Anda.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 24),
                      _LoginForm(
                        auth: auth,
                        cs: cs,
                        userCtrl: userCtrl,
                        passCtrl: passCtrl,
                        obscure: obscure,
                        onToggleObscure: onToggleObscure,
                        onSubmit: onSubmit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopLogin extends StatelessWidget {
  final AuthState auth;
  final ColorScheme cs;
  final TextEditingController userCtrl, passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure, onSubmit;

  const _DesktopLogin({
    required this.auth,
    required this.cs,
    required this.userCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left branding panel (navy gradient)
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: Stack(
                children: [
                  Positioned(
                    right: -100,
                    bottom: -100,
                    child: Container(
                      width: 380,
                      height: 380,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -60,
                    top: -60,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const UzinLogo(width: 280, borderRadius: 24),
                            const SizedBox(height: 28),
                            const Text('UzinStock',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8)),
                            const SizedBox(height: 10),
                            Text(
                              'PT Uzin Utz Indonesia\nSistem Manajemen Inventaris & Prediksi Reorder Point (ROP) Berbasis Random Forest',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 14.5,
                                  height: 1.55),
                            ),
                            const SizedBox(height: 36),
                            const Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                _FeatureChip(Icons.inventory_2_outlined, 'Manajemen Stok'),
                                _FeatureChip(Icons.swap_vert_rounded, 'Transaksi & Opname'),
                                _FeatureChip(Icons.auto_graph_rounded, 'Prediksi Random Forest'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right login form (white)
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                            offset: Offset(24 * (1 - t), 0), child: child),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.navy50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'PORTAL GUDANG',
                                style: TextStyle(
                                  color: AppColors.navy700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Selamat datang',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy900,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 6),
                          const Text('Masuk dengan akun Anda untuk mengelola stok gudang.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                          const SizedBox(height: 32),
                          _LoginForm(
                            auth: auth,
                            cs: cs,
                            userCtrl: userCtrl,
                            passCtrl: passCtrl,
                            obscure: obscure,
                            onToggleObscure: onToggleObscure,
                            onSubmit: onSubmit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final AuthState auth;
  final ColorScheme cs;
  final TextEditingController userCtrl, passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure, onSubmit;

  const _LoginForm({
    required this.auth,
    required this.cs,
    required this.userCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: userCtrl,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passCtrl,
          obscureText: obscure,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: onToggleObscure,
            ),
          ),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(auth.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.error, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 26),
        FilledButton(
          onPressed: auth.loading ? null : onSubmit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: AppColors.navy800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: auth.loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Masuk',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
