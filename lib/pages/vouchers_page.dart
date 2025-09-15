import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:_/services/local_db.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:_/services/accounting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});

  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('سندات قبض/صرف'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'سند قبض'),
            Tab(text: 'سند صرف'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VouchersTab(type: 'receipt'),
          _VouchersTab(type: 'payment'),
        ],
      ),
    );
  }
}

class _VouchersTab extends StatefulWidget {
  const _VouchersTab({required this.type});
  final String type; // 'receipt' | 'payment'

  @override
  State<_VouchersTab> createState() => _VouchersTabState();
}

class _VouchersTabState extends State<_VouchersTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final box = LocalDb.I.vouchers;
    final contacts = LocalDb.I.contacts.toMap();
    final fmt = NumberFormat.decimalPattern('ar');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'بحث بالاسم أو المبلغ...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (s) => setState(() => _query = s.trim()),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final list = box
                  .toMap()
                  .entries
                  .where((e) => e.value['type'] == widget.type)
                  .where((e) {
                    if (_query.isEmpty) return true;
                    final v = e.value;
                    final name = contacts[v['contactId']]?['name']?.toString() ?? '';
                    final amt = ((v['amount'] as num?)?.toString() ?? '');
                    return name.contains(_query) || amt.contains(_query);
                  })
                  .toList()
                ..sort((a, b) => (b.value['date'] ?? '').toString().compareTo((a.value['date'] ?? '').toString()));

              if (list.isEmpty) return const Center(child: Text('لا توجد سندات'));

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = list[i];
                  final v = Map<String, dynamic>.from(e.value);
                  final contact = contacts[v['contactId']];
                  final amount = (v['amount'] as num?)?.toDouble() ?? 0;
                  final id = e.key.toString();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: widget.type == 'receipt' ? Colors.teal : Colors.red,
                      child: Icon(widget.type == 'receipt' ? Icons.call_received : Icons.call_made, color: Colors.white),
                    ),
                    title: Text('${widget.type == 'receipt' ? 'قبض' : 'صرف'} • ${fmt.format(amount)}'),
                    subtitle: Text('${contact?['name'] ?? ''} • ${v['date'] ?? ''}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (sel) async {
                        switch (sel) {
                          case 'print':
                            await _printVoucher(id, v);
                            break;
                          case 'share':
                            await _shareVoucher(id, v);
                            break;
                          case 'delete':
                            await LocalDb.I.vouchers.delete(e.key);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'print', child: Text('طباعة')),
                        PopupMenuItem(value: 'share', child: Text('مشاركة')),
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
                label: Text('إضافة ${widget.type == 'receipt' ? 'سند قبض' : 'سند صرف'}'),
                onPressed: () => _openEditor(context, type: widget.type),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, {required String type}) async {
    final contacts = LocalDb.I.contacts.toMap().entries.toList()
      ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));
    String? contactId;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

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
            Text('إضافة ${type == 'receipt' ? 'سند قبض' : 'سند صرف'}', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: contactId,
              items: contacts.map((e) => DropdownMenuItem(value: e.key.toString(), child: Text(e.value['name'] ?? ''))).toList(),
              onChanged: (v) => contactId = v,
              decoration: const InputDecoration(labelText: 'العميل/المورد'),
            ),
            const SizedBox(height: 8),
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'ملاحظات')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.close, color: Colors.red), label: const Text('إلغاء'), onPressed: () => Navigator.pop(ctx))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(icon: const Icon(Icons.save), label: const Text('حفظ'), onPressed: () async {
                if (contactId == null) return;
                final id = LocalDb.I.newId(type == 'receipt' ? 'RCV' : 'PAY');
                await LocalDb.I.vouchers.put(id, {
                  'type': type,
                  'contactId': contactId,
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'note': noteCtrl.text.trim(),
                  'date': DateTime.now().toIso8601String(),
                });
                await AccountingService.I.postVoucher(id);
                if (ctx.mounted) Navigator.pop(ctx);
              }))
            ])
          ],
        ),
      ),
    );
  }

  Future<void> _printVoucher(String id, Map<String, dynamic> voucher) async {
    final bytes = await _buildVoucherPdf(id, voucher);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _shareVoucher(String id, Map<String, dynamic> voucher) async {
    final bytes = await _buildVoucherPdf(id, voucher);
    await Printing.sharePdf(bytes: bytes, filename: 'voucher-$id.pdf');
  }

  Future<Uint8List> _buildVoucherPdf(String id, Map<String, dynamic> voucher) async {
    final business = LocalDb.I.settings.get('business')?.cast<String, dynamic>() ?? {};
    final contacts = LocalDb.I.contacts.toMap();
    final contact = contacts[voucher['contactId']];
    final isReceipt = (voucher['type']?.toString() ?? '') == 'receipt';
    final title = isReceipt ? 'سند قبض' : 'سند صرف';
    final amount = (voucher['amount'] as num?)?.toDouble() ?? 0;
    final date = (voucher['date'] ?? '').toString();
    final note = (voucher['note'] ?? '').toString();

    final fmt = NumberFormat.decimalPattern('ar');

    final html = '''
<!DOCTYPE html>
<html lang="ar">
<head>
<meta charset="utf-8" />
<style>
  body { font-family: -apple-system, 'Segoe UI', Arial, Helvetica, sans-serif; direction: rtl; }
  .header { display: flex; justify-content: space-between; align-items: center; }
  .title { font-size: 18px; font-weight: 700; }
  .right { text-align: right; }
  .box { border: 1px solid #999; padding: 10px; border-radius: 8px; }
</style>
</head>
<body>
  <div class="header">
    <div class="title">$title</div>
    <div class="right">
      <div>${business['name']?.toString() ?? 'نشاطي التجاري'}</div>
      <div>الهاتف: ${business['phone']?.toString() ?? ''}</div>
    </div>
  </div>
  <hr />
  <div class="box">
    <div>رقم السند: $id</div>
    <div>التاريخ: $date</div>
    <div>الاسم: ${contact?['name'] ?? ''}</div>
    <div style="margin-top:8px;font-weight:700">المبلغ: ${fmt.format(amount)}</div>
    ${note.isNotEmpty ? '<div style="margin-top:8px">ملاحظات: $note</div>' : ''}
  </div>
  <div style="display:flex; justify-content: space-between; margin-top: 48px;">
    <div style="text-align:center;">
      <div>المستلم</div>
      <div style="border-top:1px solid #ccc; width:120px; margin-top:30px"></div>
    </div>
    <div style="text-align:center;">
      <div>المحاسب</div>
      <div style="border-top:1px solid #ccc; width:120px; margin-top:30px"></div>
    </div>
  </div>
</body>
</html>
''';

    final bytes = await Printing.convertHtml(html: html);
    return bytes;
  }
}
