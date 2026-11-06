import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/models.dart';
import '../state/providers.dart';

/// Buka form catat transaksi. [mode]: IN / OUT / OPNAME.
Future<void> showTrxSheet(BuildContext context, WidgetRef ref, {String mode = 'IN'}) async {
  final ok = await showAppSheet<bool>(context, (_) => _TrxSheet(initialMode: mode));
  if (ok == true) refreshAll(ref);
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'ALL'; // ALL / IN / OUT / OPNAME

  static const _filters = {
    'ALL': 'Semua',
    'IN': 'Masuk',
    'OUT': 'Keluar',
    'OPNAME': 'Opname',
  };

  bool _match(Trx t) {
    switch (_filter) {
      case 'IN':
        return t.type == 'IN';
      case 'OUT':
        return t.type == 'OUT';
      case 'OPNAME':
        return t.type != 'IN' && t.type != 'OUT';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final trx = ref.watch(transactionsProvider);
    final isMobile = context.isMobile;
    final hPad = context.isDesktop ? 24.0 : 14.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMobile && user.canWrite
          ? FloatingActionButton.extended(
              onPressed: () => showTrxSheet(context, ref),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Catat', style: TextStyle(fontSize: 13)),
            )
          : null,
      body: Column(
        children: [
          if (isMobile)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 6),
                children: [
                  for (final e in _filters.entries) ...[
                    AppChip(
                      label: e.value,
                      selected: _filter == e.key,
                      onTap: () => setState(() => _filter = e.key),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 10),
              child: Row(
                children: [
                  for (final e in _filters.entries) ...[
                    AppChip(
                      label: e.value,
                      selected: _filter == e.key,
                      onTap: () => setState(() => _filter = e.key),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  if (user.canWrite)
                    FilledButton.icon(
                      onPressed: () => showTrxSheet(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Catat Transaksi', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(transactionsProvider),
              child: trx.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  Padding(padding: const EdgeInsets.all(24), child: Text(errMsg(e)))
                ]),
                data: (all) {
                  final list = all.where(_match).toList();
                  if (list.isEmpty) {
                    return ListView(children: const [
                      EmptyState(
                        icon: Icons.swap_vert_rounded,
                        title: 'Belum ada transaksi',
                        message: 'Transaksi barang masuk, keluar, dan opname akan tampil di sini.',
                      ),
                    ]);
                  }
                  if (context.isDesktop) {
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 28),
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 540,
                        mainAxisExtent: 74,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => TrxTile(t: list[i], inGrid: true),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 84),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (_, i) => TrxTile(t: list[i]),
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

class TrxTile extends StatelessWidget {
  final Trx t;
  final bool inGrid;
  const TrxTile({super.key, required this.t, this.inGrid = false});

  @override
  Widget build(BuildContext context) {
    final isIn = t.type == 'IN';
    final isOut = t.type == 'OUT';
    final color = isIn ? AppColors.navy700 : (isOut ? AppColors.navy500 : AppColors.textMuted);
    final label = isIn ? 'Masuk' : (isOut ? 'Keluar' : 'Opname');
    final sign = t.quantity > 0 && !isOut ? '+' : (isOut ? '-' : '');
    return Card(
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
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
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  isIn
                      ? Icons.south_west_rounded
                      : (isOut ? Icons.north_east_rounded : Icons.fact_check_rounded),
                  color: color,
                  size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                      '$label • ${t.trxDate} • ${t.userName}${t.referenceNo != null ? " • ${t.referenceNo}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$sign${fmtNum(t.quantity)} ${t.itemUnit}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
                Text('stok ${fmtNum(t.stockAfter)} ${t.itemUnit}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrxSheet extends ConsumerStatefulWidget {
  final String initialMode;
  const _TrxSheet({required this.initialMode});

  @override
  ConsumerState<_TrxSheet> createState() => _TrxSheetState();
}

class _TrxSheetState extends ConsumerState<_TrxSheet> {
  late String _mode = widget.initialMode; // IN / OUT / OPNAME
  String _selectedCategory = 'ALL';
  int? _itemId;
  final _qty = TextEditingController();
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    final qty = int.tryParse(_qty.text);
    if (_itemId == null || qty == null || (_mode != 'OPNAME' && qty <= 0)) {
      setState(() => _error = 'Pilih barang dan isi jumlah dengan benar');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      if (_mode == 'OPNAME') {
        await dio.post('/stock-opname', data: {
          'item_id': _itemId,
          'physical_stock': qty,
          'notes': _notes.text.isEmpty ? null : _notes.text,
        });
      } else {
        await dio.post('/transactions', data: {
          'item_id': _itemId,
          'type': _mode,
          'quantity': qty,
          'reference_no': _ref.text.isEmpty ? null : _ref.text,
          'notes': _notes.text.isEmpty ? null : _notes.text,
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
    final items = ref.watch(itemsProvider).valueOrNull ?? <Item>[];
    final availableCategories = {
      for (final i in items) i.category,
    }.toList()
      ..sort((a, b) => ItemCategories.orderOf(a).compareTo(ItemCategories.orderOf(b)));

    final filteredItems = _selectedCategory == 'ALL'
        ? items
        : items.where((i) => i.category == _selectedCategory).toList();

    return SheetFrame(
      title: 'Catat Transaksi',
      subtitle: 'Barang masuk, keluar, atau stock opname',
      actionLabel: 'Simpan',
      onAction: _save,
      busy: _busy,
      error: _error,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'IN', label: Text('Masuk')),
            ButtonSegment(value: 'OUT', label: Text('Keluar')),
            ButtonSegment(value: 'OPNAME', label: Text('Opname')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('cat_$_selectedCategory'),
          initialValue: _selectedCategory,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Kategori Barang',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: [
            const DropdownMenuItem(
              value: 'ALL',
              child: Text('Semua Kategori'),
            ),
            ...availableCategories.map(
              (c) => DropdownMenuItem(
                value: c,
                child: Row(
                  children: [
                    Icon(ItemCategories.iconFor(c), size: 17, color: AppColors.navy700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$c (${items.where((i) => i.category == c).length})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _selectedCategory = v;
              if (_itemId != null &&
                  v != 'ALL' &&
                  !items.any((i) => i.id == _itemId && i.category == v)) {
                _itemId = null;
              }
            });
          },
        ),
        DropdownButtonFormField<int>(
          key: ValueKey('item_${_selectedCategory}_$_itemId'),
          initialValue: _itemId,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Barang', prefixIcon: Icon(Icons.inventory_2_outlined)),
          items: filteredItems
              .map((i) => DropdownMenuItem(
                  value: i.id,
                  child: Text('${i.name} (stok ${fmtNum(i.currentStock)} ${i.unit})',
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _itemId = v),
        ),
        Builder(builder: (context) {
          final sel = items.where((i) => i.id == _itemId).firstOrNull;
          final unitSuffix = sel != null ? ' (${sel.unit})' : '';
          return TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: _mode == 'OPNAME'
                    ? 'Stok fisik hasil hitung$unitSuffix'
                    : 'Jumlah$unitSuffix',
                prefixIcon: const Icon(Icons.numbers_rounded)),
          );
        }),
        if (_mode != 'OPNAME')
          TextField(
            controller: _ref,
            decoration: const InputDecoration(
                labelText: 'No. referensi (surat jalan/PO)',
                prefixIcon: Icon(Icons.receipt_long_outlined)),
          ),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
              labelText: 'Catatan', prefixIcon: Icon(Icons.notes_rounded)),
        ),
      ],
    );
  }
}
