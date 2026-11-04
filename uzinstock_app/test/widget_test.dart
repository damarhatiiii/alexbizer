import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uzinstock_app/main.dart';
import 'package:uzinstock_app/models/models.dart';
import 'package:uzinstock_app/screens/home_shell.dart';
import 'package:uzinstock_app/screens/login_screen.dart';
import 'package:uzinstock_app/state/providers.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  _LoggedInAuthNotifier(super.ref, AppUser user) {
    state = AuthState(user: user, restoring: false);
  }
}

class _LoggedOutAuthNotifier extends AuthNotifier {
  _LoggedOutAuthNotifier(super.ref) {
    state = const AuthState(restoring: false);
  }
}

final _mockUser = AppUser(
  id: 1,
  username: 'admin',
  fullName: 'Administrator Gudang',
  role: 'admin',
);

final _mockItems = [
  Item(
    id: 1,
    sku: 'UM-0300-M',
    name: 'Uzin SC 50 @40 Kg-M',
    unit: 'sak',
    currentStock: 174,
    leadTimeDays: 7,
    safetyStock: 12,
    reorderPoint: 200,
  ),
  Item(
    id: 2,
    sku: 'BB-KRG23-M',
    name: '40x65/11x11/800 Laminasi Uz. Screed Lite @M',
    unit: 'kg',
    currentStock: 10106,
    leadTimeDays: 7,
    safetyStock: 80,
    reorderPoint: 360,
  ),
  Item(
    id: 3,
    sku: 'BB-PSR05-M',
    name: 'Pasir Lampung 30 Los @M',
    unit: 'kg',
    currentStock: 323179,
    leadTimeDays: 7,
    safetyStock: 1000,
    reorderPoint: 5000,
  ),
  Item(
    id: 4,
    sku: 'BB-OPC02',
    name: 'Semen Curah OPC Type 1@M',
    unit: 'kg',
    currentStock: 61490,
    leadTimeDays: 7,
    safetyStock: 5000,
    reorderPoint: 15000,
  ),
];

final _mockPreds = [
  Prediction(
    id: 1,
    itemId: 1,
    itemName: '40x60/11x11/800 Laminating 20 mic, 1 sisi 1 warna Uz. SL 100 @M',
    modelVersion: 'rf-v1',
    predictedDemand: 5.8,
    safetyStock: 12,
    reorderPoint: 53,
    stockAtPrediction: 0,
    status: 'REORDER',
    createdAt: '2026-10-30T18:00:00',
  ),
  Prediction(
    id: 2,
    itemId: 2,
    itemName: '40x65/11x11/800 Laminasi Uz. Screed Lite @M',
    modelVersion: 'rf-v1',
    predictedDemand: 40.0,
    safetyStock: 80,
    reorderPoint: 360,
    stockAtPrediction: 47040077,
    status: 'AMAN',
    createdAt: '2026-10-30T18:00:00',
  ),
];

final _mockTrx = [
  Trx(
    id: 1,
    itemName: '40x60/11x11/800 Laminating 20 mic, 1 sisi 1 warna Uz. SL 100 @M',
    userName: 'Administrator',
    type: 'IN',
    quantity: 500,
    stockAfter: 500,
    referenceNo: 'SJ-001',
    trxDate: '2026-10-30',
  ),
  Trx(
    id: 2,
    itemName: '40x65/11x11/800 Laminasi Uz. Screed Lite @M',
    userName: 'Administrator',
    type: 'OUT',
    quantity: 120,
    stockAfter: 47040077,
    referenceNo: 'DO-002',
    trxDate: '2026-10-30',
  ),
];

List<Override> _overrides({bool loggedIn = true}) => [
      authProvider.overrideWith(
        (ref) => loggedIn ? _LoggedInAuthNotifier(ref, _mockUser) : _LoggedOutAuthNotifier(ref),
      ),
      itemsProvider.overrideWith((ref) async => _mockItems),
      latestPredictionsProvider.overrideWith((ref) async => _mockPreds),
      transactionsProvider.overrideWith((ref) async => _mockTrx),
      predictionHistoryProvider.overrideWith((ref, id) async => _mockPreds),
    ];

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('App builds and shows MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(loggedIn: false),
        child: const UzinStockApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('LoginScreen renders cleanly on Android Mobile and Desktop', (tester) async {
    // Mobile
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(loggedIn: false),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);

    // Desktop
    await _setSize(tester, const Size(1440, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(loggedIn: false),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PORTAL GUDANG'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Android Mobile layout: all 4 tabs and modals work without overflow', (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(loggedIn: true),
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    // Dashboard tab (0)
    expect(find.text('Ringkasan Gudang'), findsOneWidget);
    expect(find.text('174 sak'), findsOneWidget);
    expect(find.text('395 Rb kg'), findsOneWidget);
    expect(find.text('Perlu Reorder'), findsOneWidget);

    // Navigate to Inventaris tab (1) via quick action or bottom nav
    await tester.tap(find.text('Inventaris').first);
    await tester.pumpAndSettle();
    expect(find.text('Di bawah ROP'), findsOneWidget);

    // Filter "Di bawah ROP" and click category to expand
    await tester.tap(find.text('Di bawah ROP'));
    await tester.pumpAndSettle();
    expect(find.text('Mortar & Perekat'), findsOneWidget);
    await tester.tap(find.text('Mortar & Perekat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Uzin SC 50'), findsOneWidget);

    // Open Add Item sheet on mobile
    await tester.tap(find.text('Barang'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Barang'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Navigate to Transaksi tab (2)
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeShell)));
    container.read(tabIndexProvider.notifier).state = 2;
    await tester.pumpAndSettle();
    expect(find.text('Opname'), findsOneWidget);

    // Navigate to Prediksi tab (3)
    container.read(tabIndexProvider.notifier).state = 3;
    await tester.pumpAndSettle();
    expect(find.text('Jalankan Prediksi'), findsOneWidget);
  });

  testWidgets('Desktop layout: sidebar, 2-column dashboard, grids, and dialogs work',
      (tester) async {
    await _setSize(tester, const Size(1440, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(loggedIn: true),
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    // Desktop sidebar + top bar visible
    expect(find.text('PT Uzin Utz Indonesia'), findsOneWidget);
    expect(find.text('174 sak'), findsOneWidget);
    expect(find.text('394.775 kg'), findsOneWidget);

    // Click Inventaris on left sidebar
    await tester.tap(find.text('Inventaris').first);
    await tester.pumpAndSettle();
    expect(find.text('Tambah Barang'), findsOneWidget);

    // Categories are shown separately (Pasir, Semen, Kemasan & Karung), items hidden until clicked
    expect(find.text('Pasir'), findsOneWidget);
    expect(find.text('Semen'), findsOneWidget);
    expect(find.text('Kemasan & Karung'), findsOneWidget);
    expect(find.text('Pasir Lampung 30 Los @M'), findsNothing);
    expect(find.text('Semen Curah OPC Type 1@M'), findsNothing);

    // Click "Pasir" category -> items inside Pasir appear
    await tester.tap(find.text('Pasir'));
    await tester.pumpAndSettle();
    expect(find.text('Pasir Lampung 30 Los @M'), findsOneWidget);
    expect(find.text('Semen Curah OPC Type 1@M'), findsNothing);

    // Click "Semen" category -> items inside Semen appear
    await tester.tap(find.text('Semen'));
    await tester.pumpAndSettle();
    expect(find.text('Semen Curah OPC Type 1@M'), findsOneWidget);

    // Open Tambah Barang dialog on desktop
    await tester.tap(find.text('Tambah Barang'));
    await tester.pumpAndSettle();
    expect(find.text('Isi data barang baru'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Click Transaksi on left sidebar
    await tester.tap(find.text('Transaksi').first);
    await tester.pumpAndSettle();
    expect(find.text('Catat Transaksi'), findsOneWidget);

    // Click Prediksi ROP on left sidebar
    await tester.tap(find.text('Prediksi ROP').first);
    await tester.pumpAndSettle();
    expect(find.text('Prediksi Reorder Point (Random Forest)'), findsOneWidget);
  });
}
