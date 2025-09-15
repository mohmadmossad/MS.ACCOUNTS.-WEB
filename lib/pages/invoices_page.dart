import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:_/services/local_db.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:_/pages/invoice_view_page.dart';
import 'package:_/services/accounting.dart';
import 'package:_/pages/barcode_scanner_page.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'مبيعات'),
            Tab(text: 'مردود مبيعات'),
            Tab(text: 'مشتريات'),
            Tab(text: 'مردود مشتريات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _InvoicesTab(kind: 'sale'),
          _InvoicesTab(kind: 'sale_return'),
          _InvoicesTab(kind: 'purchase'),
          _InvoicesTab(kind: 'purchase_return'),
        ],
      ),
    );
  }
}

class _InvoicesTab extends StatefulWidget {
  const _InvoicesTab({required this.kind});
  final String kind; // 'sale' | 'sale_return' | 'purchase' | 'purchase_return'

  @override
  State<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<_InvoicesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final box = LocalDb.I.invoices;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'بحث برقم الفاتورة أو العميل/المورد...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (s) => setState(() => _query = s.trim()),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final entries = box
                  .toMap()
                  .entries
                  .where((e) => e.value['kind'] == widget.kind)
                  .toList()
                ..sort((a, b) => (b.value['date'] ?? '').toString().compareTo((a.value['date'] ?? '').toString()));

              final contacts = LocalDb.I.contacts.toMap();

              final filtered = entries.where((e) {
                if (_query.isEmpty) return true;
                final inv = e.value;
                final code = e.key.toString();
                final contactName = contacts[inv['contactId']]?['name']?.toString() ?? '';
                return code.contains(_query) || contactName.contains(_query);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('لا توجد فواتير بعد'));
              }

              final fmt = NumberFormat.decimalPattern('ar');
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = filtered[index];
                  final inv = e.value;
                  final contact = contacts[inv['contactId']];
                  final total = (inv['total'] as num?)?.toDouble() ?? 0;
                  final paid = (inv['paid'] as num?)?.toDouble() ?? 0;
                  final due = (inv['due'] as num?)?.toDouble() ?? (total - paid);
                  final isSale = widget.kind.startsWith('sale');
                  final isReturn = widget.kind.contains('return');
                  return ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceViewPage(invoiceId: e.key.toString(), data: Map<String, dynamic>.from(inv)))),
                    leading: CircleAvatar(
                      backgroundColor: isSale ? Colors.blue : Colors.green,
                      child: Icon(isSale ? (isReturn ? Icons.keyboard_return : Icons.sell) : (isReturn ? Icons.keyboard_return : Icons.shopping_cart), color: Colors.white),
                    ),
                    title: Text('${_titleForKind(widget.kind)} • ${e.key}'),
                    subtitle: Text('${contact?['name'] ?? 'بدون'} • ${inv['date'] ?? ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(fmt.format(total)),
                            Text('مدفوع: ${fmt.format(paid)} • متبقي: ${fmt.format(due)}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          onSelected: (sel) {
                            switch (sel) {
                              case 'edit':
                                _openEditor(context, kind: widget.kind, invoiceId: e.key.toString(), initial: Map<String, dynamic>.from(inv));
                                break;
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text('إضافة ${_titleForKind(widget.kind)}'),
                onPressed: () => _openEditor(context, kind: widget.kind),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _titleForKind(String kind) {
    switch (kind) {
      case 'sale':
        return 'فاتورة مبيعات';
      case 'sale_return':
        return 'مردود مبيعات';
      case 'purchase':
        return 'فاتورة مشتريات';
      case 'purchase_return':
        return 'مردود مشتريات';
      default:
        return 'فاتورة';
    }
  }

  Future<void> _openEditor(BuildContext context, {required String kind, String? invoiceId, Map<String, dynamic>? initial}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceEditor(kind: kind, invoiceId: invoiceId, initial: initial)));
  }
}

class InvoiceEditor extends StatefulWidget {
  const InvoiceEditor({super.key, required this.kind, this.invoiceId, this.initial});
  final String kind; // 'sale' | 'sale_return' | 'purchase' | 'purchase_return'
  final String? invoiceId;
  final Map<String, dynamic>? initial;

  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  String? contactId;
  final List<_Line> lines = [
    _Line(),
  ];

  // Invoice level discount and payment
  String invDiscountType = 'percent'; // percent | amount
  final TextEditingController invDiscountCtrl = TextEditingController(text: '0');
  final TextEditingController paidCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      contactId = initial['contactId']?.toString();
      lines.clear();
      final items = (initial['items'] as List?)?.cast<Map>() ?? [];
      for (final it in items) {
        final l = _Line();
        l.itemId = it['itemId']?.toString();
        l.nameCtrl.text = (it['name'] ?? '').toString();
        l.qtyCtrl.text = ((it['qty'] as num?)?.toString() ?? '0');
        l.priceCtrl.text = ((it['price'] as num?)?.toString() ?? '0');
        l.discountType = (it['discountType'] ?? 'percent').toString();
        l.discountCtrl.text = ((it['discount'] as num?)?.toString() ?? '0');
        lines.add(l);
      }
      if (lines.isEmpty) {
        lines.add(_Line());
      }
      final disc = (initial['discount'] as Map?)?.cast<String, dynamic>();
      invDiscountType = (disc?['type'] ?? 'percent').toString();
      invDiscountCtrl.text = ((disc?['value'] as num?)?.toString() ?? '0');
      paidCtrl.text = ((initial['paid'] as num?)?.toString() ?? '0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsBox = LocalDb.I.contacts;
    final isSaleFlow = widget.kind.startsWith('sale');
    final contacts = contactsBox
        .toMap()
        .entries
        .where((e) => e.value['kind'] == (isSaleFlow ? 'customer' : 'supplier'))
        .toList()
      ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));

    double subtotal = 0;
    for (final l in lines) {
      final qty = double.tryParse(l.qtyCtrl.text) ?? 0;
      final price = double.tryParse(l.priceCtrl.text) ?? 0;
      final base = qty * price;
      double discountAmt = 0;
      if (l.discountType == 'percent') {
        final p = double.tryParse(l.discountCtrl.text) ?? 0;
        discountAmt = base * (p / 100);
      } else {
        discountAmt = double.tryParse(l.discountCtrl.text) ?? 0;
      }
      subtotal += (base - discountAmt);
    }

    double invoiceDiscountAmount = 0;
    final invDiscVal = double.tryParse(invDiscountCtrl.text) ?? 0;
    if (invDiscountType == 'percent') {
      invoiceDiscountAmount = subtotal * (invDiscVal / 100);
    } else {
      invoiceDiscountAmount = invDiscVal;
    }

    final total = (subtotal - invoiceDiscountAmount).clamp(0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForKind(widget.kind)),
        actions: [
          IconButton(
            tooltip: 'مسح باركود',
            icon: const Icon(Icons.qr_code_scanner, color: Colors.brown),
            onPressed: _scanAndAddItem,
          ),
          IconButton(
            tooltip: 'حفظ',
            icon: const Icon(Icons.save, color: Colors.blue),
            onPressed: () async {
              if (contactId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر العميل/المورد')));
                return;
              }

              // Validate lines: must be picked from inventory (itemId not null) and have a name
              for (final l in lines) {
                final hasAny = l.nameCtrl.text.trim().isNotEmpty || (double.tryParse(l.qtyCtrl.text) ?? 0) > 0 || (double.tryParse(l.priceCtrl.text) ?? 0) > 0;
                if (!hasAny) continue; // skip empty rows
                if (l.itemId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب اختيار الصنف من المخزون قبل حفظ الفاتورة')));
                  return;
                }
                final item = LocalDb.I.items.get(l.itemId!)?.cast<String, dynamic>();
                if (item == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الصنف غير موجود في المخزون. قم بحفظه أولاً من شاشة الأصناف.')));
                  return;
                }
              }

              final items = lines
                  .where((l) => l.itemId != null)
                  .map((l) {
                    final qty = double.tryParse(l.qtyCtrl.text) ?? 0.0;
                    final price = double.tryParse(l.priceCtrl.text) ?? 0.0;
                    final base = qty * price;
                    double discountAmt;
                    if (l.discountType == 'percent') {
                      final p = double.tryParse(l.discountCtrl.text) ?? 0;
                      discountAmt = base * (p / 100);
                    } else {
                      discountAmt = double.tryParse(l.discountCtrl.text) ?? 0;
                    }
                    final lineTotal = (base - discountAmt).clamp(0, double.infinity);
                    return {
                      'itemId': l.itemId,
                      'name': l.nameCtrl.text.trim(),
                      'qty': qty,
                      'price': price,
                      'discountType': l.discountType,
                      'discount': double.tryParse(l.discountCtrl.text) ?? 0.0,
                      'lineTotal': lineTotal,
                    };
                  })
                  .toList();

              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف صنفاً واحداً على الأقل')));
                return;
              }

              final subtotal = items.fold<double>(0, (s, it) => s + ((it['lineTotal'] as num?)?.toDouble() ?? 0));
              final invDiscVal = double.tryParse(invDiscountCtrl.text) ?? 0.0;
              final invDiscAmt = invDiscountType == 'percent' ? subtotal * (invDiscVal / 100) : invDiscVal;
              final total = (subtotal - invDiscAmt).clamp(0, double.infinity);
              final paid = (double.tryParse(paidCtrl.text) ?? 0.0).clamp(0, total);
              final due = total - paid;

              final bool isEdit = widget.invoiceId != null;
              final id = widget.invoiceId ?? LocalDb.I.newId(_prefixForKind(widget.kind));
              final dateStr = isEdit ? (widget.initial?['date']?.toString() ?? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())) : DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

              if (isEdit) {
                // Reverse previous stock moves and delete vouchers and journals for this invoice
                final moves = LocalDb.I.stockMoves
                    .toMap()
                    .entries
                    .where((e) => (e.value['type']?.toString() ?? '') == 'invoice' && (e.value['ref']?.toString() ?? '') == id)
                    .toList();
                for (final m in moves) {
                  final v = Map<String, dynamic>.from(m.value);
                  final itemId = v['itemId']?.toString();
                  final delta = (v['qty'] as num?)?.toDouble() ?? 0.0;
                  if (itemId != null) {
                    final item = LocalDb.I.items.get(itemId)?.cast<String, dynamic>();
                    if (item != null) {
                      final newQty = ((item['qty'] as num?)?.toDouble() ?? 0) - delta; // reverse
                      await LocalDb.I.items.put(itemId, {...item, 'qty': newQty, 'updatedAt': DateTime.now().toIso8601String()});
                    }
                  }
                  await LocalDb.I.stockMoves.delete(m.key);
                }

                // Remove vouchers linked to this invoice and their journal postings
                final vouchers = LocalDb.I.vouchers
                    .toMap()
                    .entries
                    .where((e) => (e.value['invoiceId']?.toString() ?? '') == id)
                    .toList();
                for (final v in vouchers) {
                  await AccountingService.I.removeJournalByRef('voucher', v.key.toString());
                  await LocalDb.I.vouchers.delete(v.key);
                }

                // Remove GL posting for this invoice
                await AccountingService.I.removeJournalByRef('invoice', id);
              }

              await LocalDb.I.invoices.put(id, {
                'kind': widget.kind,
                'contactId': contactId,
                'date': dateStr,
                'items': items,
                'subtotal': subtotal,
                'discount': {
                  'type': invDiscountType,
                  'value': invDiscVal,
                  'amount': invDiscAmt,
                },
                'total': total,
                'paid': paid,
                'due': due,
              });

              // Adjust stock for linked items (apply new state)
              for (final it in items) {
                final itemId = it['itemId'] as String?;
                if (itemId == null) continue;
                final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
                double delta;
                switch (widget.kind) {
                  case 'sale':
                    delta = -qty;
                    break;
                  case 'sale_return':
                    delta = qty;
                    break;
                  case 'purchase':
                    delta = qty;
                    break;
                  case 'purchase_return':
                    delta = -qty;
                    break;
                  default:
                    delta = 0;
                }
                final item = LocalDb.I.items.get(itemId)?.cast<String, dynamic>();
                if (item != null) {
                  final newQty = ((item['qty'] as num?)?.toDouble() ?? 0) + delta;
                  await LocalDb.I.items.put(itemId, {...item, 'qty': newQty, 'updatedAt': DateTime.now().toIso8601String()});
                  final mvId = LocalDb.I.newId('STK');
                  await LocalDb.I.stockMoves.put(mvId, {
                    'itemId': itemId,
                    'qty': delta,
                    'type': 'invoice',
                    'ref': id,
                    'date': DateTime.now().toIso8601String(),
                  });
                }
              }

              // Auto create voucher for paid amount
              if (paid > 0) {
                final voucherType = _voucherTypeForInvoice(widget.kind);
                final vId = LocalDb.I.newId(voucherType == 'receipt' ? 'RCV' : 'PAY');
                final voucherData = {
                  'type': voucherType,
                  'contactId': contactId,
                  'amount': paid,
                  'note': 'دفعة على فاتورة $id',
                  'date': DateTime.now().toIso8601String(),
                  'invoiceId': id,
                };
                await LocalDb.I.vouchers.put(vId, voucherData);
                await AccountingService.I.postVoucher(vId);
              }

              // Post to general ledger
              await AccountingService.I.postInvoice(id);

              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: contactId,
                  items: contacts
                      .map((e) => DropdownMenuItem<String>(
                            value: e.key.toString(),
                            child: Text(e.value['name'] ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => contactId = v),
                  decoration: InputDecoration(
                    labelText: isSaleFlow ? 'العميل' : 'المورد',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'إضافة جهة جديدة',
                icon: const Icon(Icons.person_add, color: Colors.teal),
                onPressed: () => _quickAddContact(context, isCustomer: isSaleFlow),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('الأصناف', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...List.generate(lines.length, (i) => _LineEditor(
                index: i,
                line: lines[i],
                onRemove: lines.length == 1 ? null : () => setState(() => lines.removeAt(i)),
                onPickItem: () => _pickItem(context, lines[i]),
              )),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف'),
              onPressed: () => setState(() => lines.add(_Line())),
            ),
          ),
          const SizedBox(height: 16),
          // Invoice discount
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: invDiscountType,
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('خصم الفاتورة %')),
                  DropdownMenuItem(value: 'amount', child: Text('خصم الفاتورة مبلغ')),
                ],
                onChanged: (v) => setState(() => invDiscountType = v ?? 'percent'),
                decoration: const InputDecoration(labelText: 'نوع الخصم'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: invDiscountCtrl,
                decoration: const InputDecoration(labelText: 'قيمة الخصم'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('الإجمالي قبل الخصم: ${NumberFormat.decimalPattern('ar').format(subtotal)}', style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text('إجمالي الخصم: ${NumberFormat.decimalPattern('ar').format(invoiceDiscountAmount)}', style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('الإجمالي', style: Theme.of(context).textTheme.titleMedium)),
              Text(NumberFormat.decimalPattern('ar').format(total), style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          // Payment section
          Row(children: [
            Expanded(child: TextField(controller: paidCtrl, decoration: const InputDecoration(labelText: 'مدفوع الآن'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            Expanded(child: Text('المتبقي (سيُضاف للحساب): ${NumberFormat.decimalPattern('ar').format((total - (double.tryParse(paidCtrl.text) ?? 0)).clamp(0, total))}')),
          ]),
        ],
      ),
    );
  }

  String _titleForKind(String kind) {
    switch (kind) {
      case 'sale':
        return 'فاتورة مبيعات';
      case 'sale_return':
        return 'مردود مبيعات';
      case 'purchase':
        return 'فاتورة مشتريات';
      case 'purchase_return':
        return 'مردود مشتريات';
      default:
        return 'فاتورة';
    }
  }

  String _prefixForKind(String kind) {
    switch (kind) {
      case 'sale':
        return 'SAL';
      case 'sale_return':
        return 'SRN';
      case 'purchase':
        return 'PUR';
      case 'purchase_return':
        return 'PRN';
      default:
        return 'INV';
    }
  }

  String _voucherTypeForInvoice(String kind) {
    switch (kind) {
      case 'sale':
        return 'receipt'; // قبض من عميل
      case 'purchase':
        return 'payment'; // صرف لمورد
      case 'sale_return':
        return 'payment'; // اعادة من عميل => دفع له
      case 'purchase_return':
        return 'receipt'; // اعادة للمورد => نستلم منه
      default:
        return 'receipt';
    }
  }

  Future<void> _quickAddContact(BuildContext context, {required bool isCustomer}) async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة ${isCustomer ? 'عميل' : 'مورد'}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 8),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف'), keyboardType: TextInputType.phone),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            final id = LocalDb.I.newId(isCustomer ? 'CUS' : 'SUP');
            await LocalDb.I.contacts.put(id, {
              'kind': isCustomer ? 'customer' : 'supplier',
              'name': nameCtrl.text.trim(),
              'address': addressCtrl.text.trim(),
              'phone': phoneCtrl.text.trim(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
            contactId = id;
            if (mounted) setState(() {});
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('حفظ')),
        ],
      ),
    );
  }

  Future<void> _pickItem(BuildContext context, _Line line) async {
    final items = LocalDb.I.items.toMap().entries.toList()
      ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));
    String query = '';

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'بحث عن صنف...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (s) => setSt(() => query = s.trim()),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: items
                      .where((e) => query.isEmpty || (e.value['name']?.toString().contains(query) ?? false) || (e.value['barcode']?.toString().contains(query) ?? false))
                      .map((e) {
                    final v = Map<String, dynamic>.from(e.value);
                    return ListTile(
                      leading: const Icon(Icons.inventory_2, color: Colors.brown),
                      title: Text(v['name'] ?? ''),
                      subtitle: Text('سعر: ${(v['price'] ?? 0).toString()} • باركود: ${(v['barcode'] ?? '').toString()}'),
                      onTap: () {
                        line.itemId = e.key.toString();
                        line.nameCtrl.text = v['name'] ?? '';
                        // Always set price from inventory upon selection
                        line.priceCtrl.text = (v['price'] ?? 0).toString();
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              )
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }}

  Future<void> _scanAndAddItem() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerPage(title: 'مسح باركود صنف'),
        fullscreenDialog: true,
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final scanned = code.trim();

    // Try exact then try trimming leading zeros for EAN-13 variations
    MapEntry<dynamic, Map>? found;
    final itemsMap = LocalDb.I.items.toMap();
    found = itemsMap.entries.firstWhere(
      (e) => (e.value['barcode']?.toString() ?? '') == scanned,
      orElse: () => const MapEntry('', {}),
    );
    if (found.key == '') {
      final trimmed = scanned.replaceFirst(RegExp(r'^0+'), '');
      found = itemsMap.entries.firstWhere(
        (e) => (e.value['barcode']?.toString() ?? '') == trimmed,
        orElse: () => const MapEntry('', {}),
      );
    }
    if (found.key == '') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على صنف بهذا الباركود')));
      }
      return;
    }

    final id = found.key.toString();
    final v = Map<String, dynamic>.from(found.value);
    final isSaleFlow = widget.kind.startsWith('sale');

    // If line for same item exists, increase qty; else add new line
    _Line? existing = lines.firstWhere(
      (l) => l.itemId == id,
      orElse: () => _Line(),
    );
    if (existing.itemId == id) {
      final current = double.tryParse(existing.qtyCtrl.text) ?? 0;
      existing.qtyCtrl.text = (current + 1).toString();
    } else {
      final l = _Line();
      l.itemId = id;
      l.nameCtrl.text = v['name']?.toString() ?? '';
      l.qtyCtrl.text = '1';
      final price = isSaleFlow ? (v['price'] as num?)?.toDouble() ?? 0.0 : (v['cost'] as num?)?.toDouble() ?? 0.0;
      l.priceCtrl.text = price.toString();
      lines.add(l);
    }

    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة: ${v['name'] ?? ''}')));
    }
  }
}

class _Line {
  String? itemId;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController(text: '0');
  final TextEditingController discountCtrl = TextEditingController(text: '0');
  String discountType = 'percent'; // percent | amount
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({required this.index, required this.line, this.onRemove, required this.onPickItem});
  final int index;
  final _Line line;
  final VoidCallback? onRemove;
  final VoidCallback onPickItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: line.nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم الصنف',
                    suffixIcon: IconButton(
                      tooltip: 'اختيار من الأصناف',
                      icon: const Icon(Icons.list, color: Colors.brown),
                      onPressed: onPickItem,
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: line.qtyCtrl,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: line.priceCtrl,
                  decoration: const InputDecoration(labelText: 'السعر'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_forever, color: Colors.red)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: line.discountType,
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('خصم %')),
                  DropdownMenuItem(value: 'amount', child: Text('خصم مبلغ')),
                ],
                onChanged: (v) => line.discountType = v ?? 'percent',
                decoration: const InputDecoration(labelText: 'نوع الخصم'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: line.discountCtrl,
                decoration: const InputDecoration(labelText: 'قيمة الخصم'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
