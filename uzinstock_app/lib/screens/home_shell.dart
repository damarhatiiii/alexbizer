import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/models.dart';
import '../state/providers.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'prediction_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _NavItem {
  final String title, label;
  final IconData icon, selectedIcon;
  const _NavItem(this.title, this.label, this.icon, this.selectedIcon);
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _items = [
    _NavItem('Dashboard', 'Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _NavItem('Inventaris', 'Inventaris', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    _NavItem('Transaksi', 'Transaksi', Icons.swap_vert_rounded, Icons.swap_vert_rounded),
    _NavItem('Prediksi ROP', 'Prediksi', Icons.auto_graph_rounded, Icons.auto_graph_rounded),
  ];
  static const _pages = [
    DashboardScreen(),
    InventoryScreen(),
    TransactionsScreen(),
    PredictionScreen(),
  ];

  void _setTab(int i) => ref.read(tabIndexProvider.notifier).state = i;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final index = ref.watch(tabIndexProvider);
    final alertCount = ref.watch(alertCountProvider);
    final showRail = context.showRail;

    if (showRail) {
      return _DesktopShell(
        index: index,
        items: _items,
        pages: _pages,
        user: user,
        alertCount: alertCount,
        onTabChange: _setTab,
        onRefresh: () => refreshAll(ref),
        onLogout: () => ref.read(authProvider.notifier).logout(),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _SideMenu(
        name: user.fullName,
        role: user.role,
        index: index,
        onSelect: (i) {
          Navigator.pop(context);
          _setTab(i);
        },
        onLogout: () => ref.read(authProvider.notifier).logout(),
      ),
      body: Column(
        children: [
          _MobileHeader(
            title: _items[index].title,
            name: user.fullName,
            role: user.role,
            alertCount: alertCount,
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onAlertTap: () => _setTab(3),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(index), child: _pages[index]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _FloatingNav(
        index: index,
        items: _items,
        onChanged: _setTab,
      ),
    );
  }
}

/// ─── Desktop / Tablet Shell ─────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  final int index;
  final List<_NavItem> items;
  final List<Widget> pages;
  final AppUser user;
  final int alertCount;
  final ValueChanged<int> onTabChange;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const _DesktopShell({
    required this.index,
    required this.items,
    required this.pages,
    required this.user,
    required this.alertCount,
    required this.onTabChange,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = context.isDesktop;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left sidebar (navy gradient)
          Container(
            width: isWide ? 236 : 72,
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo / brand
                  Padding(
                    padding: EdgeInsets.fromLTRB(isWide ? 18 : 10, 20, isWide ? 18 : 10, 10),
                    child: isWide
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const UzinLogo.mark(height: 17),
                                const SizedBox(height: 8),
                                const Text(
                                  'UzinStock',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'PT Uzin Utz Indonesia',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Center(
                            child: UzinLogo.square(size: 44, borderRadius: 12),
                          ),
                  ),
                  // User profile card
                  if (isWide)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              child: Text(
                                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppColors.navy700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    user.role.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
                      child: Center(
                        child: Tooltip(
                          message: '${user.fullName} (${user.role.toUpperCase()})',
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppColors.navy700,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  // Nav items
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 8, vertical: 4),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final selected = i == index;
                        final item = items[i];
                        final showBadge = i == 1 && alertCount > 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: selected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onTabChange(i),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isWide ? 12 : 0, vertical: 11),
                                child: isWide
                                    ? Row(
                                        children: [
                                          Icon(
                                            selected ? item.selectedIcon : item.icon,
                                            color: selected ? AppColors.navy800 : Colors.white70,
                                            size: 19,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                color:
                                                    selected ? AppColors.navy800 : Colors.white70,
                                                fontSize: 13,
                                                fontWeight: selected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (showBadge)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.danger,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$alertCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      )
                                    : Center(
                                        child: Tooltip(
                                          message: item.title,
                                          child: Icon(
                                            selected ? item.selectedIcon : item.icon,
                                            color: selected ? AppColors.navy800 : Colors.white70,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  // Logout
                  Padding(
                    padding: EdgeInsets.fromLTRB(isWide ? 12 : 8, 8, isWide ? 12 : 8, 14),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: onLogout,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: isWide ? 12 : 0, vertical: 11),
                          child: isWide
                              ? const Row(
                                  children: [
                                    Icon(Icons.logout_rounded, color: Colors.white70, size: 18),
                                    SizedBox(width: 10),
                                    Text(
                                      'Keluar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : const Center(
                                  child: Tooltip(
                                    message: 'Keluar',
                                    child: Icon(Icons.logout_rounded,
                                        color: Colors.white70, size: 20),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right content
          Expanded(
            child: Column(
              children: [
                _DesktopTopBar(
                  title: items[index].title,
                  name: user.fullName,
                  role: user.role,
                  alertCount: alertCount,
                  onRefresh: onRefresh,
                  onAlertTap: () => onTabChange(3),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(index),
                      child: pages[index],
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

class _DesktopTopBar extends StatelessWidget {
  final String title, name, role;
  final int alertCount;
  final VoidCallback onRefresh;
  final VoidCallback onAlertTap;

  const _DesktopTopBar({
    required this.title,
    required this.name,
    required this.role,
    required this.alertCount,
    required this.onRefresh,
    required this.onAlertTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy900,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Halo, ${name.split(' ').first} • Sistem Manajemen Stok & Prediksi ROP',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (alertCount > 0) ...[
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onAlertTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      '$alertCount di bawah ROP',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          IconButton.filledTonal(
            tooltip: 'Segarkan Data',
            onPressed: onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.navy50,
              foregroundColor: AppColors.navy700,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.navy50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.navy100),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                color: AppColors.navy700,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Mobile Header (Android) ──────────────────────────────────────────────────

class _MobileHeader extends StatelessWidget {
  final String title, name, role;
  final int alertCount;
  final VoidCallback onMenu;
  final VoidCallback onAlertTap;
  const _MobileHeader({
    required this.title,
    required this.name,
    required this.role,
    required this.alertCount,
    required this.onMenu,
    required this.onAlertTap,
  });

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
          RoundIconButton(icon: Icons.menu_rounded, onTap: onMenu, tooltip: 'Menu'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const UzinLogo.mark(height: 11),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('•',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                    ),
                    Flexible(
                      child: Text('Halo, ${name.split(' ').first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
              ],
            ),
          ),
          RoundIconButton(
            icon: Icons.notifications_none_rounded,
            badge: alertCount,
            tooltip: 'Peringatan ROP',
            onTap: onAlertTap,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(role.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}

/// Navigasi bawah gelap berbentuk pill yang proporsional.
class _FloatingNav extends StatelessWidget {
  final int index;
  final List<_NavItem> items;
  final ValueChanged<int> onChanged;
  const _FloatingNav({required this.index, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.navy900,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy900.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == index;
            final it = items[i];
            return Expanded(
              flex: selected ? 3 : 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(selected ? it.selectedIcon : it.icon,
                          size: 19,
                          color: selected ? AppColors.navy800 : Colors.white60),
                      if (selected) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(it.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.navy800,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// ─── Side Drawer (Android / Mobile) ───────────────────────────────────────────

class _SideMenu extends StatelessWidget {
  final String name, role;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  const _SideMenu({
    required this.name,
    required this.role,
    required this.index,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Drawer(
      width: 260,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, top + 20, 20, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const UzinLogo.mark(height: 20),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: Text(role.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy700),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('PT Uzin Utz Indonesia',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _HomeShellState._items.length; i++)
            _MenuTile(
              icon: _HomeShellState._items[i].icon,
              label: _HomeShellState._items[i].title,
              selected: i == index,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const Divider(indent: 20, endIndent: 20),
          _MenuTile(
            icon: Icons.logout_rounded,
            label: 'Keluar',
            selected: false,
            danger: true,
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected, danger;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.danger
        : (selected ? AppColors.navy700 : AppColors.navy900);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.navy50 : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
