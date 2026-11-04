import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/models.dart';

class AuthState {
  final AppUser? user;
  final bool loading;
  final bool restoring;
  final String? error;
  const AuthState({this.user, this.loading = false, this.restoring = true, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(const AuthState()) {
    _restore();
  }

  Future<void> _restore() async {
    final token = await readToken();
    if (token == null) {
      state = const AuthState(restoring: false);
      return;
    }
    try {
      final res = await ref.read(dioProvider).get('/auth/me');
      state = AuthState(user: AppUser.fromJson(res.data), restoring: false);
    } catch (_) {
      await deleteToken();
      state = const AuthState(restoring: false);
    }
  }

  Future<void> login(String username, String password) async {
    state = const AuthState(loading: true, restoring: false);
    try {
      final res = await ref.read(dioProvider).post(
            '/auth/login',
            data: {'username': username, 'password': password},
            options: Options(contentType: Headers.formUrlEncodedContentType),
          );
      await writeToken(res.data['access_token']);
      state = AuthState(user: AppUser.fromJson(res.data['user']), restoring: false);
    } catch (e) {
      state = AuthState(error: errMsg(e), restoring: false);
    }
  }

  Future<void> logout() async {
    await deleteToken();
    state = const AuthState(restoring: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));

final itemsProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final res = await ref.watch(dioProvider).get('/items');
  return (res.data as List).map((e) => Item.fromJson(e)).toList();
});

final transactionsProvider = FutureProvider.autoDispose<List<Trx>>((ref) async {
  final res = await ref.watch(dioProvider).get('/transactions');
  return (res.data as List).map((e) => Trx.fromJson(e)).toList();
});

final latestPredictionsProvider = FutureProvider.autoDispose<List<Prediction>>((ref) async {
  final res = await ref.watch(dioProvider).get('/predictions/latest');
  return (res.data as List).map((e) => Prediction.fromJson(e)).toList();
});

final predictionHistoryProvider =
    FutureProvider.autoDispose.family<List<Prediction>, int>((ref, itemId) async {
  final res = await ref.watch(dioProvider).get('/predictions/history/$itemId');
  return (res.data as List).map((e) => Prediction.fromJson(e)).toList();
});

/// Segarkan semua data setelah ada perubahan.
void refreshAll(WidgetRef ref) {
  ref.invalidate(itemsProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(latestPredictionsProvider);
}

/// Tab aktif di HomeShell (0 Dashboard, 1 Inventaris, 2 Transaksi, 3 Prediksi).
final tabIndexProvider = StateProvider<int>((ref) => 0);

/// Jumlah barang di bawah ROP (untuk badge notifikasi).
final alertCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(itemsProvider).valueOrNull;
  return items?.where((i) => i.belowRop).length ?? 0;
});
