import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:_/services/local_db.dart';
import 'package:_/pages/inventory_count_print.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('إدارة المخزون'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الأصناف'),
            Tab(text: 'المجموعات'),
            Tab(text: 'الوحدات'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'جرد مخزني',
            icon: const Icon(Icons.checklist_rtl, color: Colors.brown),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryCountPage())),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ItemsTab(),
          _CategoriesTab(),
          _UnitsTab(),
        ],
      ),
    );
  }
}

class _ItemsTab extends StatefulWidget {
  const _ItemsTab();
  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = LocalDb.I.items;
    final cats = LocalDb.I.categories.toMap();
    final units = LocalDb.I.units.toMap();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'بحث بالاسم أو الباركود...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (s) => setState(() => _query = s.trim()),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: items.listenable(),
            builder: (context, _, __) {
              final list = items
                  .toMap()
                  .entries
                  .where((e) {
                    final v = e.value;
                    final name = (v['name'] ?? '').toString();
                    final code = (v['barcode'] ?? '').toString();
                    return _query.isEmpty || name.contains(_query) || code.contains(_query);
                  })
                  .toList()
                ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));

              if (list.isEmpty) return const Center(child: Text('لا توجد أصناف'));

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = list[i];
                  final v = Map<String, dynamic>.from(e.value);
                  final unitName = units[v['unitId']]?['name']?.toString() ?? '';
                  final catName = cats[v['categoryId']]?['name']?.toString() ?? '';
                  final qty = (v['qty'] as num?)?.toDouble() ?? 0;
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.brown, child: Text((v['name'] ?? '؟').toString().characters.first)),
                    title: Text(v['name'] ?? ''),
                    subtitle: Text([catName, unitName, 'كمية: ${qty.toStringAsFixed(2)}'].where((s) => s.isNotEmpty).join(' • ')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (sel) {
                        switch (sel) {
                          case 'edit':
                            _openEditor(context, id: e.key.toString(), initial: v);
                            break;
                          case 'barcode':
                            _printBarcodeLabel(v);
                            break;
                          case 'delete':
                            LocalDb.I.items.delete(e.key);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'barcode', child: Text('طباعة باركود')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
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
                label: const Text('إضافة صنف'),
                onPressed: () => _openEditor(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _generateBarcode() {
    final barcode = LocalDb.I.settings.get('barcode')?.cast<String, dynamic>() ?? {};
    final format = (barcode['format'] ?? 'code128').toString();
    final prefix = (barcode['prefix'] ?? 'ITM').toString();
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (format == 'ean13') {
      // Build 12-digit base then compute check digit
      final base = (ts % 1000000000000).toString().padLeft(12, '0');
      int sum = 0;
      for (int i = 0; i < 12; i++) {
        final n = int.parse(base[i]);
        sum += (i % 2 == 0) ? n : n * 3;
      }
      final check = (10 - (sum % 10)) % 10;
      return base + check.toString();
    } else {
      return '$prefix-$ts';
    }
  }

  Future<void> _openEditor(BuildContext context, {String? id, Map<String, dynamic>? initial}) async {
    final nameCtrl = TextEditingController(text: initial?['name'] ?? '');
    final barcodeCtrl = TextEditingController(text: initial?['barcode'] ?? '');
    final priceCtrl = TextEditingController(text: (initial?['price'] ?? '').toString());
    final costCtrl = TextEditingController(text: (initial?['cost'] ?? '').toString());
    final qtyCtrl = TextEditingController(text: (initial?['qty'] ?? '0').toString());
    String? unitId = initial?['unitId'];
    String? catId = initial?['categoryId'];

    final units = LocalDb.I.units.toMap().entries.toList()
      ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));
    final cats = LocalDb.I.categories.toMap().entries.toList()
      ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(id == null ? 'إضافة صنف' : 'تعديل صنف', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الصنف')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'الباركود / SKU'))),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'توليد باركود',
                  icon: const Icon(Icons.qr_code, color: Colors.blue),
                  onPressed: () {
                    barcodeCtrl.text = _generateBarcode();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'سعر البيع'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'تكلفة الشراء'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: unitId,
                items: units.map((e) => DropdownMenuItem(value: e.key.toString(), child: Text(e.value['name'] ?? ''))).toList(),
                onChanged: (v) => unitId = v,
                decoration: const InputDecoration(labelText: 'الوحدة'),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: catId,
                items: cats.map((e) {
                  final v = e.value;
                  final name = v['name']?.toString() ?? '';
                  final parent = LocalDb.I.categories.get(v['parentId'] ?? '')?.cast<String, dynamic>();
                  final label = parent == null ? name : '${parent['name']} / $name';
                  return DropdownMenuItem(value: e.key.toString(), child: Text(label));
                }).toList(),
                onChanged: (v) => catId = v,
                decoration: const InputDecoration(labelText: 'المجموعة'),
              )),
            ]),
            const SizedBox(height: 8),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'الكمية بالمخزون'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.close, color: Colors.red), label: const Text('إلغاء'), onPressed: () => Navigator.pop(ctx))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(icon: const Icon(Icons.save), label: const Text('حفظ'), onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('اسم الصنف مطلوب')));
                  return;
                }
                final data = {
                  'name': nameCtrl.text.trim(),
                  'barcode': barcodeCtrl.text.trim(),
                  'price': double.tryParse(priceCtrl.text) ?? 0.0,
                  'cost': double.tryParse(costCtrl.text) ?? 0.0,
                  'unitId': unitId,
                  'categoryId': catId,
                  'qty': double.tryParse(qtyCtrl.text) ?? 0.0,
                  'updatedAt': DateTime.now().toIso8601String(),
                };
                final key = id ?? LocalDb.I.newId('ITM');
                await LocalDb.I.items.put(key, data);
                if (ctx.mounted) Navigator.pop(ctx);
              }))
            ])
          ],
        ),
      ),
    );
  }

  Future<void> _printBarcodeLabel(Map<String, dynamic> item) async {
    final doc = pw.Document();
    final barcode = (item['barcode'] ?? '').toString();
    final name = (item['name'] ?? '').toString();

    doc.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(12),
      pageFormat: PdfPageFormat.a4,
      build: (ctx) {
        return pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(12, (i) => _barcodeLabel(name, barcode)),
        );
      },
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Widget _barcodeLabel(String name, String code) => pw.Container(
        width: 180,
        height: 90,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(name, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
            pw.Container(
              height: 50,
              alignment: pw.Alignment.center,
              child: pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: code.isEmpty ? 'N/A' : code, drawText: false),
            ),
            pw.Text(code, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
          ],
        ),
      );
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final box = LocalDb.I.categories;
    final txt = TextEditingController();

    Future<void> openEditor({String? id, Map<String, dynamic>? initial}) async {
      final ctrl = TextEditingController(text: initial?['name'] ?? '');
      String? parentId = initial?['parentId'];
      final categories = LocalDb.I.categories.toMap().entries
          .where((e) => id == null || e.key.toString() != id)
          .toList()
        ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(id == null ? 'إضافة مجموعة' : 'تعديل مجموعة'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: parentId,
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('لا يوجد (مجموعة رئيسية)')),
                    ...categories.map((e) => DropdownMenuItem(value: e.key.toString(), child: Text(e.value['name'] ?? ''))),
                  ],
                  onChanged: (v) => parentId = v,
                  decoration: const InputDecoration(labelText: 'مجموعة رئيسية'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () async {
              final data = {
                'name': ctrl.text.trim(),
                'parentId': parentId,
                'updatedAt': DateTime.now().toIso8601String(),
              };
              final key = id ?? LocalDb.I.newId('CAT');
              await LocalDb.I.categories.put(key, data);
              if (ctx.mounted) Navigator.pop(ctx);
            }, child: const Text('حفظ')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: txt,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'بحث...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final list = box
                  .toMap()
                  .entries
                  .where((e) => txt.text.trim().isEmpty || (e.value['name']?.toString().contains(txt.text.trim()) ?? false))
                  .toList()
                ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));
              if (list.isEmpty) return const Center(child: Text('لا توجد مجموعات'));
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = list[i];
                  final v = Map<String, dynamic>.from(e.value);
                  final parent = LocalDb.I.categories.get(v['parentId'] ?? '')?.cast<String, dynamic>();
                  final subtitle = parent == null ? 'مجموعة رئيسية' : 'فرعية من: ${parent['name'] ?? ''}';
                  return ListTile(
                    leading: const Icon(Icons.folder, color: Colors.brown),
                    title: Text(v['name'] ?? ''),
                    subtitle: Text(subtitle),
                    trailing: PopupMenuButton<String>(
                      onSelected: (sel) {
                        switch (sel) {
                          case 'edit':
                            openEditor(id: e.key.toString(), initial: v);
                            break;
                          case 'delete':
                            LocalDb.I.categories.delete(e.key);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
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
              child: FilledButton.icon(icon: const Icon(Icons.add), label: const Text('إضافة مجموعة'), onPressed: () => openEditor()),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitsTab extends StatelessWidget {
  const _UnitsTab();

  @override
  Widget build(BuildContext context) {
    final box = LocalDb.I.units;
    final txt = TextEditingController();

    Future<void> openEditor({String? id, Map<String, dynamic>? initial}) async {
      String type = (initial?['type'] ?? 'count').toString(); // count | weight | length | volume | area
      bool isBase = (initial?['isBase'] ?? true) == true;
      final nameCtrl = TextEditingController(text: initial?['name'] ?? '');
      final groupCtrl = TextEditingController(text: initial?['group']?.toString() ?? '');
      final factorCtrl = TextEditingController(text: ((initial?['toBaseFactor'] ?? 1.0)).toString());

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: Text(id == null ? 'إضافة وحدة' : 'تعديل وحدة'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم (مثال: قطعة، كرتون)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(value: 'count', child: Text('عدد')),
                      DropdownMenuItem(value: 'weight', child: Text('وزن')),
                      DropdownMenuItem(value: 'length', child: Text('طول')),
                      DropdownMenuItem(value: 'volume', child: Text('حجم')),
                      DropdownMenuItem(value: 'area', child: Text('مساحة')),
                    ],
                    onChanged: (v) => setSt(() => type = v ?? 'count'),
                    decoration: const InputDecoration(labelText: 'نوع الوحدة'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: groupCtrl, decoration: const InputDecoration(labelText: 'مجموعة الوحدات (اختياري، مثال: عبوة)')),
                  const SizedBox(height: 8),
                  TextField(controller: factorCtrl, decoration: const InputDecoration(labelText: 'معامل التحويل إلى الأساس'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  CheckboxListTile(
                    value: isBase,
                    onChanged: (v) => setSt(() => isBase = v ?? true),
                    title: const Text('وحدة أساس'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(onPressed: () async {
                final factor = double.tryParse(factorCtrl.text) ?? 1.0;
                final data = {
                  'name': nameCtrl.text.trim(),
                  'type': type,
                  'group': groupCtrl.text.trim(),
                  'toBaseFactor': isBase ? 1.0 : factor,
                  'isBase': isBase,
                  'updatedAt': DateTime.now().toIso8601String(),
                };
                final key = id ?? LocalDb.I.newId('UNT');
                await LocalDb.I.units.put(key, data);
                if (ctx.mounted) Navigator.pop(ctx);
              }, child: const Text('حفظ')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: txt,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'بحث...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final list = box
                  .toMap()
                  .entries
                  .where((e) => txt.text.trim().isEmpty || (e.value['name']?.toString().contains(txt.text.trim()) ?? false))
                  .toList()
                ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));
              if (list.isEmpty) return const Center(child: Text('لا توجد وحدات'));
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = list[i];
                  final v = Map<String, dynamic>.from(e.value);
                  final subtitleParts = <String>[];
                  if ((v['group'] ?? '').toString().isNotEmpty) subtitleParts.add('مجموعة: ${v['group']}');
                  subtitleParts.add('نوع: ${_unitTypeLabel(v['type']?.toString() ?? 'count')}');
                  subtitleParts.add('معامل: ${(v['toBaseFactor'] ?? 1).toString()}');
                  subtitleParts.add(v['isBase'] == true ? 'أساس' : 'فرعية');
                  return ListTile(
                    leading: const Icon(Icons.scale, color: Colors.brown),
                    title: Text(v['name'] ?? ''),
                    subtitle: Text(subtitleParts.join(' • ')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (sel) {
                        switch (sel) {
                          case 'edit':
                            openEditor(id: e.key.toString(), initial: v);
                            break;
                          case 'delete':
                            LocalDb.I.units.delete(e.key);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
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
              child: FilledButton.icon(icon: const Icon(Icons.add), label: const Text('إضافة وحدة'), onPressed: () => openEditor()),
            ),
          ),
        ),
      ],
    );
  }

  String _unitTypeLabel(String type) {
    switch (type) {
      case 'weight':
        return 'وزن';
      case 'length':
        return 'طول';
      case 'volume':
        return 'حجم';
      case 'area':
        return 'مساحة';
      default:
        return 'عدد';
    }
  }
}

class InventoryCountPage extends StatelessWidget {
  const InventoryCountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = LocalDb.I.items.toMap().entries.toList()
      ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));

    final controllers = {
      for (final e in items) e.key.toString(): TextEditingController(text: ((e.value['qty'] as num?)?.toString() ?? '0')),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجرد المخزني'),
        actions: [
          IconButton(
            tooltip: 'طباعة نموذج الجرد',
            icon: const Icon(Icons.print, color: Colors.blue),
            onPressed: () => printInventoryCountSheet(),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...items.map((e) {
            final v = Map<String, dynamic>.from(e.value);
            final ctrl = controllers[e.key.toString()]!;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(v['name'] ?? '')),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: ctrl,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'الكمية'),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('حفظ الجرد'),
            onPressed: () async {
              for (final e in items) {
                final id = e.key.toString();
                final original = (e.value['qty'] as num?)?.toDouble() ?? 0;
                final counted = double.tryParse(controllers[id]!.text) ?? original;
                if (counted != original) {
                  final diff = counted - original;
                  await LocalDb.I.items.put(id, {
                    ...e.value,
                    'qty': counted,
                    'updatedAt': DateTime.now().toIso8601String(),
                  });
                  final mvId = LocalDb.I.newId('STK');
                  await LocalDb.I.stockMoves.put(mvId, {
                    'itemId': id,
                    'qty': diff,
                    'type': 'adjust',
                    'date': DateTime.now().toIso8601String(),
                    'note': 'جرد مخزني',
                  });
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
