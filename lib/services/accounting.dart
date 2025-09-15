import 'package:_/services/local_db.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// AccountingService: Chart of accounts, posting, trial balance and statements.
class AccountingService {
  AccountingService._();
  static final AccountingService I = AccountingService._();

  /// Remove all journal entries linked to a specific reference (refType/refId)
  Future<void> removeJournalByRef(String refType, String refId) async {
    final jr = LocalDb.I.journal;
    final toDelete = jr
        .toMap()
        .entries
        .where((e) {
          final v = e.value;
          return (v['refType']?.toString() ?? '') == refType && (v['refId']?.toString() ?? '') == refId;
        })
        .map((e) => e.key)
        .toList();
    for (final k in toDelete) {
      await jr.delete(k);
    }
  }

  /// Ensure a minimal default Chart of Accounts exists.
  Future<void> ensureDefaultCoA() async {
    final accBox = LocalDb.I.accounts;
    if (accBox.isNotEmpty) return;

    Future<void> add(String code, String name, String type, {String? parentCode}) async {
      final id = code; // use code as id for stability
      final data = {
        'code': code,
        'name': name,
        'type': type, // asset | liability | equity | income | expense | contra_income
        'parentCode': parentCode,
        'active': true,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await accBox.put(id, data);
    }

    // Assets 1
    await add('1000', 'الأصول', 'asset');
    await add('1100', 'الصندوق', 'asset', parentCode: '1000');
    await add('1200', 'البنك', 'asset', parentCode: '1000');
    await add('1300', 'المدينون (ذمم العملاء)', 'asset', parentCode: '1000');
    await add('1400', 'المخزون', 'asset', parentCode: '1000');

    // Liabilities 2
    await add('2000', 'الخصوم', 'liability');
    await add('2100', 'الدائنون (ذمم الموردين)', 'liability', parentCode: '2000');

    // Equity 3
    await add('3000', 'حقوق الملكية', 'equity');
    await add('3100', 'رأس المال', 'equity', parentCode: '3000');
    await add('3200', 'الأرباح المبقاة', 'equity', parentCode: '3000');

    // Income 4
    await add('4000', 'الإيرادات', 'income');
    await add('4100', 'مبيعات', 'income', parentCode: '4000');
    await add('4200', 'مردودات المبيعات', 'contra_income', parentCode: '4000');

    // Expense 5
    await add('5000', 'المصروفات', 'expense');
    await add('5100', 'تكلفة البضاعة المباعة', 'expense', parentCode: '5000');
    await add('5200', 'مصروفات عامة', 'expense', parentCode: '5000');
  }

  /// Create a journal entry with lines. debit and credit are positive numbers.
  Future<String> addJournal({required String description, required List<Map<String, dynamic>> lines, String? refType, String? refId, DateTime? date}) async {
    final jrBox = LocalDb.I.journal;
    final id = LocalDb.I.newId('JRN');
    final d = date ?? DateTime.now();
    await jrBox.put(id, {
      'date': d.toIso8601String(),
      'description': description,
      'lines': lines,
      'refType': refType,
      'refId': refId,
    });
    return id;
  }

  /// Post invoice to GL (sales/purchases and returns). Uses items cost when needed.
  Future<void> postInvoice(String invoiceId) async {
    final inv = LocalDb.I.invoices.get(invoiceId)?.cast<String, dynamic>();
    if (inv == null) return;
    await ensureDefaultCoA();

    final kind = (inv['kind'] ?? 'sale').toString();
    final items = (inv['items'] as List?)?.cast<Map>() ?? [];
    final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
    final discountAmt = ((inv['discount'] as Map?)?['amount'] as num?)?.toDouble() ?? 0;
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid'] as num?)?.toDouble() ?? 0;

    // Compute COGS based on stored item costs
    double cogs = 0;
    double inventoryDeltaCost = 0;
    for (final it in items) {
      final itemId = it['itemId'] as String?;
      final qty = (it['qty'] as num?)?.toDouble() ?? 0;
      if (itemId == null) continue;
      final item = LocalDb.I.items.get(itemId)?.cast<String, dynamic>();
      final cost = (item?['cost'] as num?)?.toDouble() ?? 0;
      final unitCost = cost;
      final lineCost = unitCost * qty;
      if (kind == 'sale') {
        cogs += lineCost;
        inventoryDeltaCost -= lineCost;
      } else if (kind == 'sale_return') {
        cogs -= lineCost;
        inventoryDeltaCost += lineCost;
      } else if (kind == 'purchase') {
        // treat invoice price as cost for purchases
        final price = (it['price'] as num?)?.toDouble() ?? unitCost;
        final afterLineDiscount = _applyLineDiscount(qty: qty, price: price, discountType: (it['discountType'] ?? 'percent').toString(), discountValue: (it['discount'] as num?)?.toDouble() ?? 0);
        inventoryDeltaCost += afterLineDiscount;
      } else if (kind == 'purchase_return') {
        final price = (it['price'] as num?)?.toDouble() ?? unitCost;
        final afterLineDiscount = _applyLineDiscount(qty: qty, price: price, discountType: (it['discountType'] ?? 'percent').toString(), discountValue: (it['discount'] as num?)?.toDouble() ?? 0);
        inventoryDeltaCost -= afterLineDiscount;
      }
    }

    final lines = <Map<String, dynamic>>[];

    if (kind == 'sale') {
      // Dr Accounts Receivable, Cr Sales Revenue (net of invoice discount)
      lines.addAll([
        _dr('1300', total), // AR
        _cr('4100', (subtotal - discountAmt).clamp(0, double.infinity)), // Sales Revenue net of invoice discount
      ]);
      if (discountAmt > 0) {
        // treat invoice discount as contra income
        lines.add(_dr('4200', discountAmt));
      }
      if (cogs > 0) {
        lines.addAll([
          _dr('5100', cogs), // COGS
          _cr('1400', cogs), // Inventory
        ]);
      }
      if (paid > 0) {
        // reclassify part of AR to Cash
        lines.addAll([
          _dr('1100', paid), // Cash
          _cr('1300', paid), // Reduce AR
        ]);
      }
    } else if (kind == 'sale_return') {
      // Dr Sales Returns (contra income), Cr AR
      lines.addAll([
        _dr('4200', total),
        _cr('1300', total),
      ]);
      if (cogs < 0) {
        // for returns, cogs negative => reverse
        final invInc = -cogs;
        lines.addAll([
          _dr('1400', invInc),
          _cr('5100', invInc),
        ]);
      }
    } else if (kind == 'purchase') {
      // Dr Inventory, Cr Accounts Payable
      final inventoryValue = ((subtotal - discountAmt) < 0) ? 0.0 : (subtotal - discountAmt);
      lines.addAll([
        _dr('1400', inventoryValue),
        _cr('2100', total),
      ]);
      if (paid > 0) {
        // pay part in cash: Dr AP, Cr Cash
        lines.addAll([
          _dr('2100', paid),
          _cr('1100', paid),
        ]);
      }
    } else if (kind == 'purchase_return') {
      // Dr AP, Cr Inventory
      lines.addAll([
        _dr('2100', total),
        _cr('1400', total),
      ]);
    }

    await addJournal(description: _descForInvoice(kind, invoiceId), lines: lines, refType: 'invoice', refId: invoiceId, date: DateTime.now());
  }

  double _applyLineDiscount({required double qty, required double price, required String discountType, required double discountValue}) {
    final base = qty * price;
    if (discountType == 'percent') {
      return base - (base * (discountValue / 100));
    } else {
      return base - discountValue;
    }
  }

  /// Post voucher to GL.
  Future<void> postVoucher(String voucherId) async {
    final v = LocalDb.I.vouchers.get(voucherId)?.cast<String, dynamic>();
    if (v == null) return;
    await ensureDefaultCoA();

    final type = (v['type'] ?? 'receipt').toString();
    final amt = (v['amount'] as num?)?.toDouble() ?? 0;

    final lines = <Map<String, dynamic>>[];
    if (type == 'receipt') {
      // Dr Cash, Cr AR
      lines.addAll([
        _dr('1100', amt),
        _cr('1300', amt),
      ]);
    } else {
      // payment: Dr AP, Cr Cash
      lines.addAll([
        _dr('2100', amt),
        _cr('1100', amt),
      ]);
    }

    await addJournal(description: type == 'receipt' ? 'سند قبض' : 'سند صرف', lines: lines, refType: 'voucher', refId: voucherId, date: DateTime.now());
  }

  /// Trial balance: returns list of {code,name,debit,credit,balance,type}
  List<Map<String, dynamic>> trialBalance() {
    final accs = LocalDb.I.accounts.toMap().map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)));
    final jr = LocalDb.I.journal.toMap().values.map((e) => Map<String, dynamic>.from(e)).toList();
    final map = <String, Map<String, dynamic>>{};
    for (final e in accs.entries) {
      map[e.key] = {
        'code': e.value['code'],
        'name': e.value['name'],
        'type': e.value['type'],
        'debit': 0.0,
        'credit': 0.0,
      };
    }
    for (final j in jr) {
      final lines = (j['lines'] as List?)?.cast<Map>() ?? [];
      for (final l in lines) {
        final accId = l['accountId']?.toString() ?? l['code']?.toString();
        if (accId == null) continue;
        final debit = (l['debit'] as num?)?.toDouble() ?? 0.0;
        final credit = (l['credit'] as num?)?.toDouble() ?? 0.0;
        final row = map[accId] ?? {'code': accId, 'name': accs[accId]?['name'] ?? accId, 'type': accs[accId]?['type'] ?? 'asset', 'debit': 0.0, 'credit': 0.0};
        row['debit'] = (row['debit'] as double) + debit;
        row['credit'] = (row['credit'] as double) + credit;
        map[accId] = row;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => (a['code']?.toString() ?? '').compareTo(b['code']?.toString() ?? ''));
    return list;
  }

  /// Compute balances grouped for Balance Sheet and Income Statement.
  Map<String, double> totalsByType() {
    final tb = trialBalance();
    final res = <String, double>{
      'asset': 0,
      'liability': 0,
      'equity': 0,
      'income': 0,
      'contra_income': 0,
      'expense': 0,
    };
    for (final r in tb) {
      final type = (r['type'] ?? 'asset').toString();
      final debit = (r['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (r['credit'] as num?)?.toDouble() ?? 0.0;
      double bal = 0;
      // Normal balances: asset/expense debit; liability/equity/income credit; contra_income debit
      switch (type) {
        case 'asset':
        case 'expense':
        case 'contra_income':
          bal = debit - credit;
          break;
        default:
          bal = credit - debit;
      }
      res[type] = (res[type] ?? 0) + bal;
    }
    return res;
  }

  /// Close income and expense to retained earnings (3200) for current period.
  Future<void> closePeriod({String? note}) async {
    await ensureDefaultCoA();
    final totals = totalsByType();
    final income = (totals['income'] ?? 0) - (totals['contra_income'] ?? 0);
    final expenses = (totals['expense'] ?? 0);
    final profit = income - expenses; // could be negative

    if (profit == 0) return;

    final lines = <Map<String, dynamic>>[];
    if (profit > 0) {
      // Dr income accounts? Simplify as one line: Dr Income (4100), Cr Retained Earnings
      lines.add(_dr('4100', profit));
      lines.add(_cr('3200', profit));
    } else {
      final loss = -profit;
      lines.add(_dr('3200', loss));
      lines.add(_cr('4100', loss));
    }
    final jrId = await addJournal(description: note ?? 'إقفال الفترة', lines: lines, refType: 'closing', refId: DateTime.now().toIso8601String());
    await LocalDb.I.closures.put(jrId, {
      'date': DateTime.now().toIso8601String(),
      'profit': profit,
      'journalId': jrId,
    });
  }

  Map<String, dynamic> _dr(String accountId, double amount) => {'accountId': accountId, 'debit': amount, 'credit': 0.0};
  Map<String, dynamic> _cr(String accountId, double amount) => {'accountId': accountId, 'debit': 0.0, 'credit': amount};

  String _descForInvoice(String kind, String id) {
    switch (kind) {
      case 'sale':
        return 'قيد فاتورة مبيعات $id';
      case 'sale_return':
        return 'قيد مردود مبيعات $id';
      case 'purchase':
        return 'قيد فاتورة مشتريات $id';
      case 'purchase_return':
        return 'قيد مردود مشتريات $id';
      default:
        return 'قيد فاتورة $id';
    }
  }
}
