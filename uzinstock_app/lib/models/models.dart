import 'package:flutter/material.dart';

class ItemCategories {
  ItemCategories._();

  static const List<String> all = [
    'Pasir',
    'Semen',
    'Kalsium & Filler',
    'Aditif & Bahan Kimia',
    'Kemasan & Karung',
    'Bahan Bakar',
    'Mortar & Perekat',
    'Self Leveling & Pelapis',
    'Lainnya',
  ];

  static int orderOf(String category) {
    final idx = all.indexOf(category);
    return idx >= 0 ? idx : all.length;
  }

  static String defaultUnitFor(String category) {
    if (category == 'Mortar & Perekat' || category == 'Self Leveling & Pelapis') {
      return 'sak';
    }
    return 'kg';
  }

  static IconData iconFor(String category) {
    switch (category) {
      case 'Pasir':
        return Icons.landscape_rounded;
      case 'Semen':
        return Icons.foundation_rounded;
      case 'Kalsium & Filler':
        return Icons.blur_on_rounded;
      case 'Aditif & Bahan Kimia':
        return Icons.science_rounded;
      case 'Kemasan & Karung':
        return Icons.inventory_2_rounded;
      case 'Bahan Bakar':
        return Icons.local_gas_station_rounded;
      case 'Mortar & Perekat':
        return Icons.construction_rounded;
      case 'Self Leveling & Pelapis':
        return Icons.layers_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static String subtitleFor(String category) {
    switch (category) {
      case 'Pasir':
        return 'Pasir silika & pasir alam (Lampung, Bengkulu)';
      case 'Semen':
        return 'Semen Putih, OPC Curah, GGBFS & Secar 71';
      case 'Kalsium & Filler':
        return 'CaCO3, Omya Carb, Pealite & Bata';
      case 'Aditif & Bahan Kimia':
        return 'Polimer RDP, Celluast, Elotex, Pigmen & Aditif';
      case 'Kemasan & Karung':
        return 'Karung, Zak, Plastik Inner, Jerigen & Pail';
      case 'Bahan Bakar':
        return 'Solar High Speed Diesel operasional';
      case 'Mortar & Perekat':
        return 'Produk jadi Uzin SC, Plaster, Screed, Bond & TB';
      case 'Self Leveling & Pelapis':
        return 'Produk jadi Uzin SL, LS, Primer & PE';
      default:
        return 'Kategori barang lainnya';
    }
  }

  static String infer(String sku, String name) {
    final s = sku.toUpperCase().trim();
    final n = name.toUpperCase().trim();

    if (s.startsWith('BB-PSR') || n.contains('PASIR')) {
      return 'Pasir';
    }
    if (s.startsWith('BB-OPC') ||
        s.startsWith('BB-PCC') ||
        s.startsWith('BB-ALU') ||
        n.contains('SEMEN') ||
        n.contains('GGBFS') ||
        n.contains('SECAR')) {
      return 'Semen';
    }
    if (s.startsWith('BB-CCO') ||
        s.startsWith('BB-BTB') ||
        s.startsWith('BB-BTR') ||
        n.contains('CACO3') ||
        n.contains('OMYA') ||
        n.contains('PEALITE') ||
        n.contains('BATA')) {
      return 'Kalsium & Filler';
    }
    if (s.startsWith('BB-SLR') || n.contains('SOLAR') || n.contains('DIESEL')) {
      return 'Bahan Bakar';
    }
    if (s.startsWith('BB-KRG') ||
        s.startsWith('BB-ZAK') ||
        s.startsWith('BB-INN') ||
        s.startsWith('BB-JRG') ||
        s.startsWith('BB-PAL') ||
        s.startsWith('BB-BNG01') ||
        n.contains('KARUNG') ||
        n.contains('JERIGEN') ||
        n.contains('PAIL ') ||
        n.contains('KANTONG PLASTIK') ||
        n.contains('INNER HDPE') ||
        RegExp(r'^\d+X\d+').hasMatch(n)) {
      return 'Kemasan & Karung';
    }
    if (s.startsWith('BB-MC') ||
        s.startsWith('BB-FLO') ||
        s.startsWith('BB-ADD') ||
        s.startsWith('BB-RDP') ||
        s.startsWith('BB-PWD') ||
        s.startsWith('BB-BIN') ||
        s.startsWith('BB-WTR') ||
        s.startsWith('BB-BNG02') ||
        s.startsWith('RM-') ||
        s.startsWith('BB-') ||
        n.contains('CELLUAST') ||
        n.contains('HPMC') ||
        n.contains('HEADCELL') ||
        n.contains('MAHA PNS') ||
        n.contains('SNF') ||
        n.contains('CALCIUM FORMATE') ||
        n.contains('HPS ') ||
        n.contains('STRACK ETHER') ||
        n.contains('VAE ') ||
        n.contains('POLIMER') ||
        n.contains('ELOTEX') ||
        n.contains('VINNAPAS') ||
        n.contains('IRON OXIDE') ||
        n.contains('TITANIUM') ||
        n.contains('ACRONAL') ||
        n.contains('SKY BIO') ||
        n.contains('AGITAN') ||
        n.contains('MALEKI') ||
        n.contains('FIBER') ||
        n.contains('STONE DENSE')) {
      return 'Aditif & Bahan Kimia';
    }
    if (s.startsWith('US-') ||
        s.startsWith('LS-') ||
        s.startsWith('UW-') ||
        s.startsWith('UC-') ||
        s.startsWith('FG-LS') ||
        n.contains('SL ') ||
        n.contains('LS ') ||
        n.contains('PRIMER') ||
        n.contains('PE 360') ||
        n.contains('SELF LEVEL')) {
      return 'Self Leveling & Pelapis';
    }
    if (s.startsWith('UM-') ||
        s.startsWith('FG-') ||
        s.startsWith('MRT-') ||
        n.contains('MORTAR') ||
        n.contains('PLASTER') ||
        n.contains('SCREED') ||
        n.contains('BOND') ||
        n.contains('UZIN SC') ||
        n.contains('TB 20') ||
        n.contains('B. FLOOR') ||
        n.contains('B, PLUS') ||
        n.contains('SC 01')) {
      return 'Mortar & Perekat';
    }
    return 'Lainnya';
  }
}

class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String role;

  AppUser({required this.id, required this.username, required this.fullName, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        username: j['username'],
        fullName: j['full_name'],
        role: j['role'],
      );

  /// Otoritas tinggi: boleh tambah/ubah/hapus data.
  bool get canWrite => role == 'admin' || role == 'manager';
  bool get canPredict => canWrite || role == 'staff';
}

class Item {
  final int id;
  final String sku;
  final String name;
  final String category;
  final String unit;
  final int currentStock;
  final int leadTimeDays;
  final int safetyStock;
  final int reorderPoint;

  Item({
    required this.id,
    required this.sku,
    required this.name,
    String? category,
    required this.unit,
    required this.currentStock,
    required this.leadTimeDays,
    required this.safetyStock,
    required this.reorderPoint,
  }) : category = (category != null && category.isNotEmpty)
            ? category
            : ItemCategories.infer(sku, name);

  factory Item.fromJson(Map<String, dynamic> j) {
    final sku = (j['sku'] ?? '') as String;
    final name = (j['name'] ?? '') as String;
    final rawCat = (j['category'] as String?)?.trim();
    final cat = (rawCat != null && rawCat.isNotEmpty && rawCat != 'Lainnya')
        ? rawCat
        : ItemCategories.infer(sku, name);
    final rawUnit = (j['unit'] as String?)?.trim();
    final unit = (rawUnit != null && rawUnit.isNotEmpty && rawUnit != 'g')
        ? rawUnit
        : ItemCategories.defaultUnitFor(cat);
    return Item(
      id: j['id'],
      sku: sku,
      name: name,
      category: cat,
      unit: unit,
      currentStock: j['current_stock'],
      leadTimeDays: j['lead_time_days'],
      safetyStock: j['safety_stock'],
      reorderPoint: j['reorder_point'],
    );
  }

  bool get belowRop => reorderPoint > 0 && currentStock <= reorderPoint;
}

class Trx {
  final int id;
  final String itemName;
  final String itemCategory;
  final String itemUnit;
  final String userName;
  final String type; // IN / OUT / OPNAME_ADJ
  final int quantity;
  final int stockAfter;
  final String? referenceNo;
  final String trxDate;

  Trx({
    required this.id,
    required this.itemName,
    String? itemCategory,
    String? itemUnit,
    required this.userName,
    required this.type,
    required this.quantity,
    required this.stockAfter,
    this.referenceNo,
    required this.trxDate,
  })  : itemCategory = (itemCategory != null && itemCategory.isNotEmpty)
            ? itemCategory
            : ItemCategories.infer('', itemName),
        itemUnit = (itemUnit != null && itemUnit.isNotEmpty && itemUnit != 'g')
            ? itemUnit
            : ItemCategories.defaultUnitFor(
                (itemCategory != null && itemCategory.isNotEmpty)
                    ? itemCategory
                    : ItemCategories.infer('', itemName),
              );

  factory Trx.fromJson(Map<String, dynamic> j) {
    final itemName = (j['item_name'] ?? '') as String;
    final rawCat = (j['item_category'] as String?)?.trim();
    final cat = (rawCat != null && rawCat.isNotEmpty && rawCat != 'Lainnya')
        ? rawCat
        : ItemCategories.infer('', itemName);
    final rawUnit = (j['item_unit'] as String?)?.trim();
    return Trx(
      id: j['id'],
      itemName: itemName,
      itemCategory: cat,
      itemUnit: (rawUnit != null && rawUnit.isNotEmpty && rawUnit != 'g')
          ? rawUnit
          : ItemCategories.defaultUnitFor(cat),
      userName: j['user_name'],
      type: j['type'],
      quantity: j['quantity'],
      stockAfter: j['stock_after'],
      referenceNo: j['reference_no'],
      trxDate: j['trx_date'],
    );
  }
}

class Prediction {
  final int id;
  final int itemId;
  final String itemName;
  final String itemCategory;
  final String itemUnit;
  final String modelVersion;
  final double predictedDemand;
  final int safetyStock;
  final int reorderPoint;
  final int stockAtPrediction;
  final String status; // AMAN / REORDER
  final String createdAt;

  Prediction({
    required this.id,
    required this.itemId,
    required this.itemName,
    String? itemCategory,
    String? itemUnit,
    required this.modelVersion,
    required this.predictedDemand,
    required this.safetyStock,
    required this.reorderPoint,
    required this.stockAtPrediction,
    required this.status,
    required this.createdAt,
  })  : itemCategory = (itemCategory != null && itemCategory.isNotEmpty)
            ? itemCategory
            : ItemCategories.infer('', itemName),
        itemUnit = (itemUnit != null && itemUnit.isNotEmpty && itemUnit != 'g')
            ? itemUnit
            : ItemCategories.defaultUnitFor(
                (itemCategory != null && itemCategory.isNotEmpty)
                    ? itemCategory
                    : ItemCategories.infer('', itemName),
              );

  factory Prediction.fromJson(Map<String, dynamic> j) {
    final itemName = (j['item_name'] ?? '') as String;
    final rawCat = (j['item_category'] as String?)?.trim();
    final cat = (rawCat != null && rawCat.isNotEmpty && rawCat != 'Lainnya')
        ? rawCat
        : ItemCategories.infer('', itemName);
    final rawUnit = (j['item_unit'] as String?)?.trim();
    return Prediction(
      id: j['id'],
      itemId: j['item_id'],
      itemName: itemName,
      itemCategory: cat,
      itemUnit: (rawUnit != null && rawUnit.isNotEmpty && rawUnit != 'g')
          ? rawUnit
          : ItemCategories.defaultUnitFor(cat),
      modelVersion: j['model_version'],
      predictedDemand: (j['predicted_demand'] as num).toDouble(),
      safetyStock: j['safety_stock'],
      reorderPoint: j['reorder_point'],
      stockAtPrediction: j['stock_at_prediction'],
      status: j['status'],
      createdAt: j['created_at'],
    );
  }

  bool get isReorder => status == 'REORDER';
}
