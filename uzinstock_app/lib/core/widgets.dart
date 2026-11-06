import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'responsive.dart';
import 'theme.dart';

final _numFmt = NumberFormat('#,###', 'id_ID');

/// Format angka dengan pemisah ribuan (contoh: 47.040.077).
String fmtNum(num value) => _numFmt.format(value);

/// Format timestamp dari backend (UTC, tanpa zona waktu) ke waktu lokal perangkat.
/// Contoh: `2026-11-02T07:06:00` → `2026-11-02 14:06` (WIB).
String fmtDateTime(String raw) {
  final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
  final parsed = DateTime.tryParse(hasZone ? raw : '${raw}Z');
  if (parsed == null) return raw.replaceFirst('T', ' ').split('.').first;
  return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
}

/// Logo resmi UZIN (putih transparan) yang menyatu di atas header/hero biru.
class UzinLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final bool showContainer;
  final EdgeInsetsGeometry padding;
  final String assetPath;

  /// Logo penuh + slogan, di dalam badge biru (splash & login).
  const UzinLogo({
    super.key,
    this.width = 220,
    this.height,
    this.borderRadius = 20,
    this.showContainer = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
  }) : assetPath = 'assets/images/uzin_logo_white.png';

  /// Wordmark "UZIN®" saja, tanpa kotak (header & sidebar).
  const UzinLogo.mark({
    super.key,
    this.width,
    this.height = 20,
  })  : borderRadius = 0,
        showContainer = false,
        padding = EdgeInsets.zero,
        assetPath = 'assets/images/uzin_mark_white.png';

  /// Badge persegi berisi wordmark "UZIN®" (sidebar ringkas).
  const UzinLogo.square({
    super.key,
    double size = 40,
    this.borderRadius = 12,
  })  : width = size,
        height = size,
        showContainer = true,
        padding = const EdgeInsets.all(6),
        assetPath = 'assets/images/uzin_mark_white.png';

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      assetPath,
      width: showContainer ? null : width,
      height: showContainer ? null : height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (!showContainer) return img;

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.navy600,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(child: img),
    );
  }
}

/// Format angka ringkas untuk kartu statistik sempit (contoh: 47,04 Jt / 10,1 Rb).
String fmtCompact(num value) {
  final abs = value.abs();
  if (abs >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  }
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} Jt';
  }
  if (abs >= 100000) {
    return '${(value / 1000).toStringAsFixed(0)} Rb';
  }
  return _numFmt.format(value);
}

/// Tombol bulat transparan di atas header navy (opsional dengan badge angka).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final String? tooltip;
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
    return Tooltip(
      message: tooltip ?? '',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          if (badge > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.navy800, width: 1.5),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Header navy melengkung untuk halaman turunan (dengan tombol kembali).
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PageHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 14),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5)),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip filter bergaya pill navy.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const AppChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy700 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.navy700 : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy700)),
      ),
    );
  }
}

/// Kolom pencarian putih dengan border tipis.
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          fillColor: Colors.white,
          enabledBorder: b(AppColors.border),
          border: b(AppColors.border),
          focusedBorder: b(AppColors.navy700, 1.4),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyState({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: AppColors.navy50, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: AppColors.navy600),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy900)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
        ],
      ),
    );
  }
}

/// Judul seksi dengan aksi opsional di kanan.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy900)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      color: AppColors.navy500, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (!context.isMobile) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: builder(ctx),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// Kerangka form dalam bottom sheet: judul, isi, error, dan tombol aksi penuh.
class SheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool busy;
  final String? error;

  const SheetFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy900)),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitle!,
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ),
                      ],
                    ),
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
              const SizedBox(height: 14),
              for (final c in children) ...[c, const SizedBox(height: 10)],
              if (error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: busy ? null : onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy800,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(actionLabel,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
