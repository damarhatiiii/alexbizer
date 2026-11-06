import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/models.dart';
import '../state/providers.dart';
import 'transactions_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;
    final items = ref.watch(itemsProvider);
    final preds = ref.watch(latestPredictionsProvider);
    final trx = ref.watch(transactionsProvider);
    final isDesktop = context.isDesktop;

    return RefreshIndicator(
      onRefresh: () async => refreshAll(ref),
      child: isDesktop
          ? _DesktopDashboard(
              user: user,
              items: items,
              preds: preds,
              trx: trx,
              ref: ref,
            )
          : _MobileDashboard(
              user: user,
              items: items,
              preds: preds,
              trx: trx,
              ref: ref,
            ),
    );
  }
}

class _MobileDashboard extends StatelessWidget {
  final AppUser user;
  final AsyncValue<List<Item>> items;
  final AsyncValue<List<Prediction>> preds;
  final AsyncValue<List<Trx>> trx;
  final WidgetRef ref;

  const _MobileDashboard({
    required this.user,
    required this.items,
    required this.preds,
    required this.trx,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        items.when(
          loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (e, _) => Text(errMsg(e)),
          data: (list) {
            final totalSak = list
                .where((i) => i.unit.toLowerCase() == 'sak')
                .fold<int>(0, (a, b) => a + b.currentStock);
            final totalKg = list
                .where((i) => i.unit.toLowerCase() != 'sak')
                .fold<int>(0, (a, b) => a + b.currentStock);
            final low = list.where((i) => i.belowRop).length;
            return Column(
              children: [
                _Hero(low: low, total: list.length, totalSak: totalSak, totalKg: totalKg),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Stat('Produk (Sak)', '${fmtCompact(totalSak)} sak',
                          Icons.inventory_2_rounded, AppColors.navy700,
                          tooltip: '${fmtNum(totalSak)} sak'),
                      const SizedBox(width: 8),
                      _Stat('Bahan (Kg)', '${fmtCompact(totalKg)} kg',
                          Icons.scale_rounded, AppColors.navy600,
                          tooltip: '${fmtNum(totalKg)} kg'),
                      const SizedBox(width: 8),
                      _Stat('Di Bawah ROP', fmtNum(low), Icons.warning_amber_rounded,
                          low > 0 ? AppColors.danger : AppColors.navy500),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Aksi Cepat'),
        _QuickActionsRow(user: user, ref: ref),
        const SizedBox(height: 16),
        SectionTitle(
          'Perlu Reorder',
          action: 'Lihat semua',
          onAction: () => ref.read(tabIndexProvider.notifier).state = 3,
        ),
        _ReorderSection(preds: preds, maxItems: 4),
        const SizedBox(height: 10),
        SectionTitle('Transaksi Terakhir',
            action: 'Lihat semua',
            onAction: () => ref.read(tabIndexProvider.notifier).state = 2),
        trx.when(
          loading: () => const SizedBox(),
          error: (e, _) => Text(errMsg(e)),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.swap_vert_rounded,
                  title: 'Belum ada transaksi',
                  message: 'Catat barang masuk atau keluar untuk mulai.',
                )
              : Column(children: list.take(5).map((t) => TrxTile(t: t)).toList()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DesktopDashboard extends StatelessWidget {
  final AppUser user;
  final AsyncValue<List<Item>> items;
  final AsyncValue<List<Prediction>> preds;
  final AsyncValue<List<Trx>> trx;
  final WidgetRef ref;

  const _DesktopDashboard({
    required this.user,
    required this.items,
    required this.preds,
    required this.trx,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main left column
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  items.when(
                    loading: () => const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                    error: (e, _) => Text(errMsg(e)),
                    data: (list) {
                      final totalSak = list
                          .where((i) => i.unit.toLowerCase() == 'sak')
                          .fold<int>(0, (a, b) => a + b.currentStock);
                      final totalKg = list
                          .where((i) => i.unit.toLowerCase() != 'sak')
                          .fold<int>(0, (a, b) => a + b.currentStock);
                      final low = list.where((i) => i.belowRop).length;
                      return Column(
                        children: [
                          _Hero(low: low, total: list.length, totalSak: totalSak, totalKg: totalKg),
                          const SizedBox(height: 14),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Stat('Jenis Barang', fmtNum(list.length),
                                    Icons.category_rounded, AppColors.navy700),
                                const SizedBox(width: 14),
                                _Stat('Produk (Sak)', '${fmtNum(totalSak)} sak',
                                    Icons.inventory_2_rounded, AppColors.navy600),
                                const SizedBox(width: 14),
                                _Stat('Bahan (Kg)', '${fmtNum(totalKg)} kg',
                                    Icons.scale_rounded, AppColors.navy600),
                                const SizedBox(width: 14),
                                _Stat('Di Bawah ROP', fmtNum(low),
                                    Icons.warning_amber_rounded,
                                    low > 0 ? AppColors.danger : AppColors.navy500),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle('Aksi Cepat'),
                  _QuickActionsRow(user: user, ref: ref, horizontalLayout: true),
                  const SizedBox(height: 22),
                  SectionTitle('Transaksi Terakhir',
                      action: 'Lihat semua',
                      onAction: () => ref.read(tabIndexProvider.notifier).state = 2),
                  trx.when(
                    loading: () => const SizedBox(),
                    error: (e, _) => Text(errMsg(e)),
                    data: (list) => list.isEmpty
                        ? const EmptyState(
                            icon: Icons.swap_vert_rounded,
                            title: 'Belum ada transaksi',
                            message: 'Catat barang masuk atau keluar untuk mulai.',
                          )
                        : Column(children: list.take(6).map((t) => TrxTile(t: t)).toList()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Right column: Reorder panel
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    'Perlu Reorder',
                    action: 'Tab Prediksi',
                    onAction: () => ref.read(tabIndexProvider.notifier).state = 3,
                  ),
                  _ReorderSection(preds: preds, maxItems: 8),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final AppUser user;
  final WidgetRef ref;
  final bool horizontalLayout;
  const _QuickActionsRow({
    required this.user,
    required this.ref,
    this.horizontalLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(width: horizontalLayout ? 12 : 8);
    return Row(
      children: [
        if (user.canWrite) ...[
          _QuickAction(
            icon: Icons.south_west_rounded,
            label: horizontalLayout ? 'Barang Masuk' : 'Barang Masuk',
            horizontal: horizontalLayout,
            onTap: () => showTrxSheet(context, ref, mode: 'IN'),
          ),
          gap,
          _QuickAction(
            icon: Icons.north_east_rounded,
            label: horizontalLayout ? 'Barang Keluar' : 'Barang Keluar',
            horizontal: horizontalLayout,
            onTap: () => showTrxSheet(context, ref, mode: 'OUT'),
          ),
          gap,
        ],
        _QuickAction(
          icon: Icons.inventory_2_rounded,
          label: 'Inventaris',
          horizontal: horizontalLayout,
          onTap: () => ref.read(tabIndexProvider.notifier).state = 1,
        ),
        if (!user.canWrite || horizontalLayout) ...[
          gap,
          _QuickAction(
            icon: Icons.auto_graph_rounded,
            label: 'Prediksi ROP',
            horizontal: horizontalLayout,
            onTap: () => ref.read(tabIndexProvider.notifier).state = 3,
          ),
        ],
      ],
    );
  }
}

class _ReorderSection extends StatelessWidget {
  final AsyncValue<List<Prediction>> preds;
  final int maxItems;
  const _ReorderSection({required this.preds, this.maxItems = 5});

  @override
  Widget build(BuildContext context) {
    return preds.when(
      loading: () => const SizedBox(),
      error: (e, _) => Text(errMsg(e)),
      data: (list) {
        final alerts = list.where((p) => p.isReorder).toList();
        if (alerts.isEmpty) {
          return const Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Icon(Icons.check_circle_rounded, color: AppColors.navy600, size: 26),
              title: Text('Semua stok aman',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('Jalankan prediksi di tab Prediksi untuk memperbarui.',
                  style: TextStyle(fontSize: 11.5)),
            ),
          );
        }
        final shown = alerts.take(maxItems).toList();
        return Column(
          children: shown
              .map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: AppColors.dangerSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_rounded,
                                color: AppColors.danger, size: 17),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                    'Stok ${fmtNum(p.stockAtPrediction)} ${p.itemUnit} ≤ ROP ${fmtNum(p.reorderPoint)} ${p.itemUnit}',
                                    style: const TextStyle(
                                        color: AppColors.textMuted, fontSize: 11.5)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('REORDER',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool horizontal;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: horizontal ? 13 : 11,
              horizontal: horizontal ? 14 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: horizontal
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.navy800,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy900,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.navy800,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 17),
                      ),
                      const SizedBox(height: 6),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy900)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int low, total, totalSak, totalKg;
  const _Hero({
    required this.low,
    required this.total,
    this.totalSak = 0,
    this.totalKg = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ok = low == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppColors.heroGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy800.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ringkasan Gudang',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                const SizedBox(height: 3),
                Text(ok ? 'Semua stok aman' : '$low barang perlu reorder',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    'Memantau $total jenis barang • ${fmtNum(totalSak)} sak & ${fmtNum(totalKg)} kg',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: Icon(ok ? Icons.verified_rounded : Icons.notifications_active_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? tooltip;
  const _Stat(this.label, this.value, this.icon, this.color, {this.tooltip});

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
    return Expanded(
      child: tooltip != null ? Tooltip(message: tooltip!, child: card) : card,
    );
  }
}
