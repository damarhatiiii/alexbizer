import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/models.dart';
import '../state/providers.dart';

class PredictionScreen extends ConsumerStatefulWidget {
  const PredictionScreen({super.key});

  @override
  ConsumerState<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends ConsumerState<PredictionScreen> {
  bool _running = false;
  final Set<String> _expanded = <String>{};

  void _toggleCategory(String cat) {
    setState(() {
      if (_expanded.contains(cat)) {
        _expanded.remove(cat);
      } else {
        _expanded.add(cat);
      }
    });
  }

  Map<String, List<Prediction>> _groupByCategory(List<Prediction> preds) {
    final map = <String, List<Prediction>>{};
    for (final p in preds) {
      (map[p.itemCategory] ??= <Prediction>[]).add(p);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        final cmp = ItemCategories.orderOf(a).compareTo(ItemCategories.orderOf(b));
        return cmp != 0 ? cmp : a.compareTo(b);
      });
    return {
      for (final k in sortedKeys)
        k: (map[k]!
          ..sort((a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()))),
    };
  }

  Future<void> _runAll() async {
    setState(() => _running = true);
    try {
      final res = await ref.read(dioProvider).post('/predictions/reorder-point');
      refreshAll(ref);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${(res.data as List).length} barang diprediksi')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg(e))));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final preds = ref.watch(latestPredictionsProvider);
    final isMobile = context.isMobile;
    final hPad = context.isDesktop ? 24.0 : 14.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMobile && user.canPredict
          ? FloatingActionButton.extended(
              onPressed: _running ? null : _runAll,
              icon: _running
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_graph_rounded, size: 19),
              label: const Text('Jalankan Prediksi', style: TextStyle(fontSize: 13)),
            )
          : null,
      body: Column(
        children: [
          if (!isMobile)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.navy50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_graph_rounded,
                          color: AppColors.navy700, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prediksi Reorder Point (Random Forest)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.navy900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Menghitung rata-rata permintaan harian, safety stock, dan titik pemesanan ulang (ROP) per kategori.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (user.canPredict) ...[
                      const SizedBox(width: 14),
                      FilledButton.icon(
                        onPressed: _running ? null : _runAll,
                        icon: _running
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_graph_rounded, size: 18),
                        label: const Text('Jalankan Prediksi', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(latestPredictionsProvider),
              child: preds.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  Padding(padding: const EdgeInsets.all(24), child: Text(errMsg(e)))
                ]),
                data: (list) {
                  if (list.isEmpty) {
                    return ListView(children: const [
                      EmptyState(
                        icon: Icons.auto_graph_rounded,
                        title: 'Belum ada hasil prediksi',
                        message:
                            'Tekan tombol "Jalankan Prediksi" untuk menghitung Reorder Point dengan model Random Forest.',
                      ),
                    ]);
                  }

                  final grouped = _groupByCategory(list);
                  final entries = grouped.entries.toList();

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, isMobile ? 84 : 28),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (_, idx) {
                      final entry = entries[idx];
                      final cat = entry.key;
                      final catPreds = entry.value;
                      final isExpanded = _expanded.contains(cat);
                      final reorderCount = catPreds.where((p) => p.isReorder).length;
                      final hasReorder = reorderCount > 0;
                      final icon = ItemCategories.iconFor(cat);
                      final subtitle = ItemCategories.subtitleFor(cat);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isExpanded
                                ? AppColors.navy500.withValues(alpha: 0.45)
                                : (hasReorder
                                    ? AppColors.danger.withValues(alpha: 0.35)
                                    : AppColors.border),
                            width: isExpanded ? 1.3 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navy900
                                  .withValues(alpha: isExpanded ? 0.06 : 0.03),
                              blurRadius: isExpanded ? 14 : 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.vertical(
                                top: const Radius.circular(18),
                                bottom: Radius.circular(isExpanded ? 0 : 18),
                              ),
                              onTap: () => _toggleCategory(cat),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 14 : 18,
                                  vertical: isMobile ? 13 : 15,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        gradient: isExpanded ? AppColors.heroGradient : null,
                                        color: isExpanded
                                            ? null
                                            : (hasReorder
                                                ? AppColors.dangerSoft
                                                : AppColors.navy50),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: isExpanded
                                            ? Colors.white
                                            : (hasReorder
                                                ? AppColors.danger
                                                : AppColors.navy700),
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.navy900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            hasReorder
                                                ? '$reorderCount perlu reorder • $subtitle'
                                                : (isExpanded
                                                    ? '$subtitle • Klik untuk menutup'
                                                    : subtitle),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: hasReorder
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              color: hasReorder
                                                  ? AppColors.danger
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isExpanded
                                            ? AppColors.navy700
                                            : (hasReorder
                                                ? AppColors.dangerSoft
                                                : AppColors.navy50),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        '${catPreds.length} barang',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: isExpanded
                                              ? Colors.white
                                              : (hasReorder
                                                  ? AppColors.danger
                                                  : AppColors.navy700),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    AnimatedRotation(
                                      turns: isExpanded ? 0.5 : 0.0,
                                      duration: const Duration(milliseconds: 220),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: isExpanded
                                            ? AppColors.navy700
                                            : AppColors.textMuted,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius:
                                      BorderRadius.vertical(bottom: Radius.circular(17)),
                                  border: Border(top: BorderSide(color: AppColors.border)),
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  isMobile ? 10 : 16,
                                  12,
                                  isMobile ? 10 : 16,
                                  12,
                                ),
                                child: !isMobile
                                    ? GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 420,
                                          mainAxisExtent: 128,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemCount: catPreds.length,
                                        itemBuilder: (_, i) =>
                                            _PredCard(p: catPreds[i], inGrid: true),
                                      )
                                    : Column(
                                        children: [
                                          for (final p in catPreds) _PredCard(p: p),
                                        ],
                                      ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredCard extends StatelessWidget {
  final Prediction p;
  final bool inGrid;
  const _PredCard({required this.p, this.inGrid = false});

  @override
  Widget build(BuildContext context) {
    final color = p.isReorder ? AppColors.danger : AppColors.navy700;
    return Card(
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showAppSheet(
          context,
          (_) => _HistorySheet(itemId: p.itemId, name: p.itemName),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    p.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    p.status,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _kv('Stok (${p.itemUnit})', fmtNum(p.stockAtPrediction)),
                _kv('ROP (${p.itemUnit})', fmtNum(p.reorderPoint)),
                _kv('Safety (${p.itemUnit})', fmtNum(p.safetyStock)),
                _kv('Prediksi/hr', '${p.predictedDemand.toStringAsFixed(1)} ${p.itemUnit}'),
              ]),
              const SizedBox(height: 6),
              Text(
                '${p.modelVersion} • ${fmtDateTime(p.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(v, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
          Text(
            k,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ]),
      );
}

class _HistorySheet extends ConsumerWidget {
  final int itemId;
  final String name;
  const _HistorySheet({required this.itemId, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(predictionHistoryProvider(itemId));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Text('Riwayat Prediksi • $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.navy50,
                  foregroundColor: AppColors.navy700,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: hist.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(errMsg(e))),
            data: (list) => ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = list[i];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                  title: Text(
                      'ROP ${fmtNum(p.reorderPoint)} ${p.itemUnit} • stok ${fmtNum(p.stockAtPrediction)} ${p.itemUnit}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text(fmtDateTime(p.createdAt),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  trailing: Text(p.status,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: p.isReorder ? AppColors.danger : AppColors.navy700)),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
