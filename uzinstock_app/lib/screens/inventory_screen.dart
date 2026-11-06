import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/models.dart';
import '../state/providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _query = '';
  bool _onlyLow = false;
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

  void _toggleAll(List<String> categories) {
    setState(() {
      if (_expanded.length >= categories.length) {
        _expanded.clear();
      } else {
        _expanded.addAll(categories);
      }
    });
  }

  Map<String, List<Item>> _groupByCategory(List<Item> items) {
    final map = <String, List<Item>>{};
    for (final it in items) {
      (map[it.category] ??= <Item>[]).add(it);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        final cmp = ItemCategories.orderOf(a).compareTo(ItemCategories.orderOf(b));
        return cmp != 0 ? cmp : a.compareTo(b);
      });
    return {
      for (final k in sortedKeys)
        k: (map[k]!..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()))),
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final items = ref.watch(itemsProvider);
    final isMobile = context.isMobile;
    final hPad = context.isDesktop ? 24.0 : 14.0;

    final allItems = items.valueOrNull ?? const <Item>[];
    final filteredForCats = allItems.where((i) {
      if (_onlyLow && !i.belowRop) return false;
      if (_query.isEmpty) return true;
      return i.name.toLowerCase().contains(_query) ||
          i.sku.toLowerCase().contains(_query) ||
          i.category.toLowerCase().contains(_query);
    }).toList();
    final catKeys = _groupByCategory(filteredForCats).keys.toList();
    final allExpanded = catKeys.isNotEmpty && _expanded.length >= catKeys.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMobile && user.canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Barang', style: TextStyle(fontSize: 13)),
            )
          : null,
      body: Column(
        children: [
          if (isMobile) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: SearchField(
                hint: 'Cari nama, SKU, atau kategori...',
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 4),
                children: [
                  AppChip(
                      label: 'Semua',
                      selected: !_onlyLow,
                      onTap: () => setState(() => _onlyLow = false)),
                  const SizedBox(width: 8),
                  AppChip(
                      label: 'Di bawah ROP',
                      selected: _onlyLow,
                      onTap: () => setState(() => _onlyLow = true)),
                  if (catKeys.isNotEmpty && _query.isEmpty) ...[
                    const SizedBox(width: 8),
                    AppChip(
                      label: allExpanded ? 'Tutup Semua' : 'Buka Semua',
                      selected: allExpanded,
                      onTap: () => _toggleAll(catKeys),
                    ),
                  ],
                ],
              ),
            ),
          ] else
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 8),
              child: Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: SearchField(
                      hint: 'Cari nama, SKU, atau kategori barang...',
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppChip(
                      label: 'Semua Kategori',
                      selected: !_onlyLow,
                      onTap: () => setState(() => _onlyLow = false)),
                  const SizedBox(width: 8),
                  AppChip(
                      label: 'Di bawah ROP',
                      selected: _onlyLow,
                      onTap: () => setState(() => _onlyLow = true)),
                  if (catKeys.isNotEmpty && _query.isEmpty) ...[
                    const SizedBox(width: 8),
                    AppChip(
                      label: allExpanded ? 'Tutup Semua' : 'Buka Semua',
                      selected: allExpanded,
                      onTap: () => _toggleAll(catKeys),
                    ),
                  ],
                  const Spacer(),
                  if (user.canWrite)
                    FilledButton.icon(
                      onPressed: () => _openForm(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah Barang', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemsProvider),
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  Padding(padding: const EdgeInsets.all(24), child: Text(errMsg(e)))
                ]),
                data: (all) {
                  final list = all.where((i) {
                    if (_onlyLow && !i.belowRop) return false;
                    if (_query.isEmpty) return true;
                    return i.name.toLowerCase().contains(_query) ||
                        i.sku.toLowerCase().contains(_query) ||
                        i.category.toLowerCase().contains(_query);
                  }).toList();
                  if (list.isEmpty) {
                    return ListView(children: [
                      EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: all.isEmpty ? 'Belum ada barang' : 'Tidak ditemukan',
                        message: all.isEmpty
                            ? 'Tambahkan barang pertama Anda dengan tombol "Tambah Barang".'
                            : 'Coba kata kunci atau filter yang lain.',
                      ),
                    ]);
                  }

                  final grouped = _groupByCategory(list);
                  final entries = grouped.entries.toList();

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(hPad, 6, hPad, isMobile ? 84 : 28),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (_, idx) {
                      final entry = entries[idx];
                      final cat = entry.key;
                      final catItems = entry.value;
                      final isExpanded = _query.isNotEmpty || _expanded.contains(cat);
                      return _CategorySection(
                        category: cat,
                        items: catItems,
                        expanded: isExpanded,
                        isMobile: isMobile,
                        canWrite: user.canWrite,
                        onToggle: () => _toggleCategory(cat),
                        onAddInCategory: () =>
                            _openForm(context, ref, initialCategory: cat),
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

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  Item? item,
  String? initialCategory,
}) async {
  final saved = await showAppSheet<bool>(
    context,
    (_) => _ItemSheet(item: item, initialCategory: initialCategory),
  );
  if (saved == true) refreshAll(ref);
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<Item> items;
  final bool expanded;
  final bool isMobile;
  final bool canWrite;
  final VoidCallback onToggle;
  final VoidCallback onAddInCategory;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.expanded,
    required this.isMobile,
    required this.canWrite,
    required this.onToggle,
    required this.onAddInCategory,
  });

  @override
  Widget build(BuildContext context) {
    final lowCount = items.where((i) => i.belowRop).length;
    final hasLow = lowCount > 0;
    final icon = ItemCategories.iconFor(category);
    final subtitle = ItemCategories.subtitleFor(category);
    final catUnit = items.isNotEmpty
        ? items.first.unit
        : ItemCategories.defaultUnitFor(category);
    final totalCatStock = items.fold<int>(0, (a, b) => a + b.currentStock);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: expanded
              ? AppColors.navy500.withValues(alpha: 0.45)
              : (hasLow
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : AppColors.border),
          width: expanded ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy900.withValues(alpha: expanded ? 0.06 : 0.03),
            blurRadius: expanded ? 14 : 8,
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
              bottom: Radius.circular(expanded ? 0 : 18),
            ),
            onTap: onToggle,
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
                      gradient: expanded ? AppColors.heroGradient : null,
                      color: expanded
                          ? null
                          : (hasLow ? AppColors.dangerSoft : AppColors.navy50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: expanded
                          ? Colors.white
                          : (hasLow ? AppColors.danger : AppColors.navy700),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
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
                          hasLow
                              ? '$lowCount di bawah ROP • Total ${fmtNum(totalCatStock)} $catUnit'
                              : 'Total ${fmtNum(totalCatStock)} $catUnit • $subtitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: hasLow ? FontWeight.w700 : FontWeight.w400,
                            color: hasLow ? AppColors.danger : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: expanded
                          ? AppColors.navy700
                          : (hasLow ? AppColors.dangerSoft : AppColors.navy50),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${items.length} barang',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: expanded
                            ? Colors.white
                            : (hasLow ? AppColors.danger : AppColors.navy700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: expanded ? AppColors.navy700 : AppColors.textMuted,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: EdgeInsets.fromLTRB(
                isMobile ? 10 : 16,
                12,
                isMobile ? 10 : 16,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isMobile)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 420,
                        mainAxisExtent: 126,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _ItemCard(item: items[i], inGrid: true),
                    )
                  else
                    Column(
                      children: [
                        for (final it in items) _ItemCard(item: it),
                      ],
                    ),
                  if (canWrite)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onAddInCategory,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                          label: Text(
                            'Tambah di $category',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final Item item;
  final bool inGrid;
  const _ItemCard({required this.item, this.inGrid = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;
    final low = item.belowRop;
    final accent = low ? AppColors.danger : AppColors.navy700;
    final ratio = item.reorderPoint > 0
        ? (item.currentStock / (item.reorderPoint * 2)).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: user.canWrite ? () => _actions(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: low ? AppColors.dangerSoft : AppColors.navy50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      ItemCategories.iconFor(item.category),
                      color: accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text('${item.sku} • Lead time ${item.leadTimeDays} hari',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fmtNum(item.currentStock),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
                      Text(item.unit,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: item.reorderPoint > 0 ? ratio : 1.0,
                      minHeight: 5,
                      backgroundColor: AppColors.navy50,
                      color: item.reorderPoint > 0 ? accent : AppColors.navy100,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.reorderPoint > 0
                              ? (low
                                  ? 'Di bawah ROP ${fmtNum(item.reorderPoint)} ${item.unit}'
                                  : 'ROP ${fmtNum(item.reorderPoint)} ${item.unit}')
                              : 'ROP belum dihitung',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: low ? FontWeight.w800 : FontWeight.w500,
                              color: low ? AppColors.danger : AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Safety ${fmtNum(item.safetyStock)} ${item.unit}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _actions(BuildContext context, WidgetRef ref) {
    showAppSheet(
      context,
      (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Kategori: ${item.category} • SKU: ${item.sku}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
            ListTile(
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.edit_rounded, size: 20),
              title: const Text('Ubah', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _openForm(context, ref, item: item);
              },
            ),
            ListTile(
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 20),
              title: const Text('Hapus',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmDelete(context, ref);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus barang?'),
        content: Text('${item.name} akan dihapus dari daftar. Riwayat transaksi tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/items/${item.id}');
      refreshAll(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg(e))));
      }
    }
  }
}

class _ItemSheet extends ConsumerStatefulWidget {
  final Item? item;
  final String? initialCategory;
  const _ItemSheet({this.item, this.initialCategory});

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  late final _sku = TextEditingController(text: widget.item?.sku ?? '');
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _lead = TextEditingController(text: '${widget.item?.leadTimeDays ?? 7}');
  final _stock = TextEditingController(text: '0');
  late String _category = widget.item?.category ??
      widget.initialCategory ??
      ItemCategories.all.first;
  late String _unit = widget.item?.unit ??
      ItemCategories.defaultUnitFor(
        widget.item?.category ?? widget.initialCategory ?? ItemCategories.all.first,
      );
  bool _manualCategory = false;
  bool _manualUnit = false;
  String? _error;
  bool _busy = false;

  bool get _edit => widget.item != null;

  void _autoDetectCategory() {
    if (_edit || _manualCategory || widget.initialCategory != null) return;
    final guessed = ItemCategories.infer(_sku.text, _name.text);
    if (guessed != 'Lainnya' && guessed != _category) {
      setState(() {
        _category = guessed;
        if (!_manualUnit) {
          _unit = ItemCategories.defaultUnitFor(guessed);
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final lead = int.tryParse(_lead.text) ?? 7;
      if (_edit) {
        await dio.put('/items/${widget.item!.id}', data: {
          'name': _name.text.trim(),
          'category': _category,
          'unit': _unit,
          'lead_time_days': lead,
        });
      } else {
        await dio.post('/items', data: {
          'sku': _sku.text.trim(),
          'name': _name.text.trim(),
          'category': _category,
          'unit': _unit,
          'lead_time_days': lead,
          'current_stock': int.tryParse(_stock.text) ?? 0,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = errMsg(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      ...ItemCategories.all,
      _category,
    }.toList();

    return SheetFrame(
      title: _edit ? 'Ubah Barang' : 'Tambah Barang',
      subtitle: _edit ? widget.item!.sku : 'Isi data barang baru',
      actionLabel: 'Simpan',
      onAction: _save,
      busy: _busy,
      error: _error,
      children: [
        TextField(
          controller: _sku,
          enabled: !_edit,
          onChanged: (_) => _autoDetectCategory(),
          decoration: const InputDecoration(
              labelText: 'SKU', prefixIcon: Icon(Icons.qr_code_rounded)),
        ),
        TextField(
          controller: _name,
          onChanged: (_) => _autoDetectCategory(),
          decoration: const InputDecoration(
              labelText: 'Nama barang', prefixIcon: Icon(Icons.label_outline_rounded)),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('cat_$_category'),
          initialValue: _category,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Kategori',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: categories
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(ItemCategories.iconFor(c), size: 17, color: AppColors.navy700),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _category = v;
                _manualCategory = true;
                if (!_manualUnit) {
                  _unit = ItemCategories.defaultUnitFor(v);
                }
              });
            }
          },
        ),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('unit_$_unit'),
              initialValue: _unit == 'sak' ? 'sak' : 'kg',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Satuan'),
              items: const [
                DropdownMenuItem(value: 'kg', child: Text('kg (Kilogram)')),
                DropdownMenuItem(value: 'sak', child: Text('sak (Kemasan)')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _unit = v;
                    _manualUnit = true;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _lead,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Lead time (hari)'),
            ),
          ),
        ]),
        if (!_edit)
          TextField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'Stok awal ($_unit)',
                prefixIcon: const Icon(Icons.warehouse_outlined)),
          ),
      ],
    );
  }
}
