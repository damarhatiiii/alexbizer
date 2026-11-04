import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/widgets.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/providers.dart';

void main() {
  runApp(const ProviderScope(child: UzinStockApp()));
}

class UzinStockApp extends StatelessWidget {
  const UzinStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UzinStock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Gate(),
    );
  }
}

class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.restoring) {
      return const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                UzinLogo(width: 240, borderRadius: 22),
                SizedBox(height: 20),
                Text('UzinStock',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                SizedBox(height: 6),
                Text('PT Uzin Utz Indonesia',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: 28),
                SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return auth.user == null ? const LoginScreen() : const HomeShell();
  }
}
