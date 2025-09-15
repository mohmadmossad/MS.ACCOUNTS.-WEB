import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// LocalDb: Lightweight storage service using Hive without TypeAdapters.
/// Data is stored as Map<String, dynamic> for flexibility and fast iteration.
class LocalDb {
  LocalDb._internal();
  static final LocalDb I = LocalDb._internal();

  static const String boxContacts = 'contacts';
  static const String boxInvoices = 'invoices';
  static const String boxUsers = 'users';
  static const String boxSettings = 'settings';
  static const String boxItems = 'items';
  static const String boxCategories = 'categories';
  static const String boxUnits = 'units';
  static const String boxVouchers = 'vouchers';
  static const String boxStockMoves = 'stock_moves';
   static const String boxAccounts = 'accounts';
   static const String boxJournal = 'journal';
   static const String boxClosures = 'fiscal_closures';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(boxContacts),
      Hive.openBox<Map>(boxInvoices),
      Hive.openBox<Map>(boxUsers),
      Hive.openBox<Map>(boxSettings),
      Hive.openBox<Map>(boxItems),
      Hive.openBox<Map>(boxCategories),
      Hive.openBox<Map>(boxUnits),
      Hive.openBox<Map>(boxVouchers),
      Hive.openBox<Map>(boxStockMoves),
      Hive.openBox<Map>(boxAccounts),
      Hive.openBox<Map>(boxJournal),
      Hive.openBox<Map>(boxClosures),
    ]);
    _initialized = true;
  }

  // Utils
  String newId([String prefix = 'ID']) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey()}';

  // Boxes
  Box<Map> get contacts => Hive.box<Map>(boxContacts);
  Box<Map> get invoices => Hive.box<Map>(boxInvoices);
  Box<Map> get users => Hive.box<Map>(boxUsers);
  Box<Map> get settings => Hive.box<Map>(boxSettings);
  Box<Map> get items => Hive.box<Map>(boxItems);
  Box<Map> get categories => Hive.box<Map>(boxCategories);
  Box<Map> get units => Hive.box<Map>(boxUnits);
  Box<Map> get vouchers => Hive.box<Map>(boxVouchers);
  Box<Map> get stockMoves => Hive.box<Map>(boxStockMoves);
  Box<Map> get accounts => Hive.box<Map>(boxAccounts);
  Box<Map> get journal => Hive.box<Map>(boxJournal);
  Box<Map> get closures => Hive.box<Map>(boxClosures);

  // Backup all boxes to a single JSON string
  Future<String> exportToJson() async {
    final data = {
      boxContacts: contacts.toMap(),
      boxInvoices: invoices.toMap(),
      boxUsers: users.toMap(),
      boxSettings: settings.toMap(),
      boxItems: items.toMap(),
      boxCategories: categories.toMap(),
      boxUnits: units.toMap(),
      boxVouchers: vouchers.toMap(),
      boxStockMoves: stockMoves.toMap(),
      boxAccounts: accounts.toMap(),
      boxJournal: journal.toMap(),
      boxClosures: closures.toMap(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // Restore from JSON (replace = true to clear boxes first)
  Future<void> importFromJson(String json, {bool replace = false}) async {
    final obj = jsonDecode(json);
    if (obj is! Map) throw Exception('ملف غير صالح');

    Future<void> applyBox(String name, Box<Map> box) async {
      final src = (obj[name] as Map?)?.cast<dynamic, dynamic>() ?? {};
      if (replace) await box.clear();
      for (final entry in src.entries) {
        final k = entry.key.toString();
        final v = (entry.value as Map?)?.cast<String, dynamic>() ?? {};
        await box.put(k, v);
      }
    }

    await applyBox(boxContacts, contacts);
    await applyBox(boxInvoices, invoices);
    await applyBox(boxUsers, users);
    await applyBox(boxSettings, settings);
    await applyBox(boxItems, items);
    await applyBox(boxCategories, categories);
    await applyBox(boxUnits, units);
    await applyBox(boxVouchers, vouchers);
    await applyBox(boxStockMoves, stockMoves);
    await applyBox(boxAccounts, accounts);
    await applyBox(boxJournal, journal);
    await applyBox(boxClosures, closures);
  }
}
