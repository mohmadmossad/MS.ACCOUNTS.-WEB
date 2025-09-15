import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:_/services/local_db.dart';

class AccountStatementPage extends StatefulWidget {
  const AccountStatementPage({super.key});

  @override
  State<AccountStatementPage> createState() => _AccountStatementPageState();
}

class _AccountStatementPageState extends State<AccountStatementPage> {
  String? contactId;

  @override
  Widget build(BuildContext context) {
    final contacts = LocalDb.I.contacts.toMap();
    final options = contacts.entries.toList()
      ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));

    final entries = <_Entry>[];

    if (contactId != null) {
      // Invoices
      LocalDb.I.invoices.toMap().forEach((k, v) {
        if (v['contactId'] == contactId) {
          final total = (v['total'] as num?)?.toDouble() ?? 0;
          final isSale = v['kind'] == 'sale' || v['kind'] == 'sale_return';
          final isReturn = v['kind'] == 'sale_return' || v['kind'] == 'purchase_return';
          final sign = isReturn ? -1 : 1;
          final amount = total * sign * (isSale ? 1 : 1);
          entries.add(_Entry(date: v['date'] ?? '', type: v['kind'] ?? 'sale', ref: k.toString(), amount: amount));
        }
      });
      // Vouchers
      LocalDb.I.vouchers.toMap().forEach((k, v) {
        if (v['contactId'] == contactId) {
          final amt = (v['amount'] as num?)?.toDouble() ?? 0;
          final sign = v['type'] == 'receipt' ? -1 : 1; // receipt reduces receivable
          entries.add(_Entry(date: v['date'] ?? '', type: v['type'] ?? 'receipt', ref: k.toString(), amount: amt * sign));
        }
      });
    }

    entries.sort((a, b) => (a.date).compareTo(b.date));
    double balance = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حساب'),
        actions: [
          IconButton(
            tooltip: 'طباعة/تصدير PDF',
            onPressed: contactId == null ? null : () => _printPdf(entries, contacts[contactId!]?.cast<String, dynamic>() ?? {}),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
          ),
          IconButton(
            tooltip: 'مشاركة عبر واتساب',
            onPressed: contactId == null ? null : () => _sharePdf(entries, contacts[contactId!]?.cast<String, dynamic>() ?? {}),
            icon: const Icon(Icons.send, color: Colors.green),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: contactId,
            items: options
                .map((e) => DropdownMenuItem<String>(
                      value: e.key.toString(),
                      child: Text('${e.value['name']} • ${e.value['kind'] == 'customer' ? 'عميل' : 'مورد'}'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => contactId = v),
            decoration: const InputDecoration(labelText: 'اختر عميلًا أو موردًا', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (contactId == null) ...[
            const SizedBox(height: 24),
            const Center(child: Text('اختر جهة لعرض كشف الحساب')),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(child: Text('الرصيد الحالي')),
                  Builder(builder: (_) {
                    final fmt = NumberFormat.decimalPattern('ar');
                    balance = 0;
                    for (final e in entries) {
                      balance += e.amount;
                    }
                    return Text(fmt.format(balance));
                  })
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final isInv = e.type == 'sale' || e.type == 'sale_return' || e.type == 'purchase' || e.type == 'purchase_return';
              final isReceipt = e.type == 'receipt';
              final isPayment = e.type == 'payment';
              final title = isInv
                  ? _titleForKind(e.type)
                  : (isReceipt ? 'سند قبض' : 'سند صرف');
              final color = isInv
                  ? Colors.blue
                  : (isReceipt ? Colors.teal : Colors.red);
              return ListTile(
                leading: CircleAvatar(backgroundColor: color, child: Icon(isInv ? Icons.receipt_long : (isReceipt ? Icons.call_received : Icons.call_made), color: Colors.white)),
                title: Text('$title • ${e.ref}'),
                subtitle: Text(e.date),
                trailing: Text(NumberFormat.decimalPattern('ar').format(e.amount)),
              );
            })
          ],
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
        return 'سجل';
    }
  }

  Future<void> _printPdf(List<_Entry> entries, Map<String, dynamic> contact) async {
    final bytes = await _buildPdf(entries, contact);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _sharePdf(List<_Entry> entries, Map<String, dynamic> contact) async {
    final bytes = await _buildPdf(entries, contact);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/statement-${contact['name'] ?? 'contact'}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'كشف حساب');
  }

  Future<Uint8List> _buildPdf(List<_Entry> entries, Map<String, dynamic> contact) async {
    final business = LocalDb.I.settings.get('business')?.cast<String, dynamic>() ?? {};
    final fmt = NumberFormat.decimalPattern('ar');

    double balance = 0;
    final rows = entries.map((e) {
      balance += e.amount;
      final type = _titleForKind(e.type);
      return '<tr><td>${e.date}</td><td>$type</td><td style="text-align:center">${fmt.format(e.amount)}</td><td>${e.ref}</td></tr>';
    }).join();

    final html = '''
<!DOCTYPE html>
<html lang="ar">
<head>
<meta charset="utf-8" />
<style>
  body { font-family: -apple-system, 'Segoe UI', Arial, Helvetica, sans-serif; direction: rtl; }
  .header { display: flex; justify-content: space-between; align-items: center; }
  .title { font-size: 18px; font-weight: 700; }
  table { width: 100%; border-collapse: collapse; margin-top: 8px; }
  th, td { border: 1px solid #999; padding: 6px; font-size: 12px; }
  .right { text-align: right; }
</style>
</head>
<body>
  <div class="header">
    <div class="title">كشف حساب</div>
    <div class="right">
      <div>${business['name']?.toString() ?? 'نشاطي التجاري'}</div>
      <div>الهاتف: ${business['phone']?.toString() ?? ''}</div>
    </div>
  </div>
  <hr />
  <div>العميل/المورد: ${contact['name'] ?? ''}</div>
  <table>
    <thead>
      <tr>
        <th>التاريخ</th>
        <th>النوع</th>
        <th>المبلغ</th>
        <th>المرجع</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>
  <div class="right" style="margin-top:12px;font-weight:700">الرصيد: ${fmt.format(balance)}</div>
</body>
</html>
''';

    final bytes = await Printing.convertHtml(html: html);
    return bytes;
  }

  pw.Widget _th(String text) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
  pw.Widget _td(String text, {pw.TextAlign? align}) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, textAlign: align));
}

class _Entry {
  _Entry({required this.date, required this.type, required this.ref, required this.amount});
  final String date;
  final String type;
  final String ref;
  final double amount;
}
