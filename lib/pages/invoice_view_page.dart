import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdfshow; // alias just in case
import 'package:printing/printing.dart';
import 'package:_/services/local_db.dart';

class InvoiceViewPage extends StatelessWidget {
  const InvoiceViewPage({super.key, required this.invoiceId, required this.data});
  final String invoiceId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final contacts = LocalDb.I.contacts.toMap();
    final business = LocalDb.I.settings.get('business')?.cast<String, dynamic>() ?? {};
    final contact = contacts[data['contactId']];
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final discMap = (data['discount'] as Map?)?.cast<String, dynamic>();
    final discAmt = (discMap?['amount'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final paid = (data['paid'] as num?)?.toDouble() ?? 0;
    final due = (data['due'] as num?)?.toDouble() ?? (total - paid);
    final fmt = NumberFormat.decimalPattern('ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForKind(data['kind']?.toString() ?? '')),
        actions: [
          IconButton(onPressed: () => _printPdf(context), icon: const Icon(Icons.print, color: Colors.blue)),
          IconButton(onPressed: () => _sharePdf(), icon: const Icon(Icons.share, color: Colors.green)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.info, color: Colors.blue),
            title: Text('رقم: $invoiceId'),
            subtitle: Text('التاريخ: ${data['date'] ?? ''}'),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.teal),
            title: Text(contact?['name'] ?? ''),
            subtitle: Text(((contact?['address'] ?? '') as String).isEmpty ? (contact?['phone'] ?? '') : '${contact?['address']} • ${contact?['phone'] ?? ''}'),
          ),
          const Divider(),
          ...items.map((e) {
            final name = e['name'];
            final qty = (e['qty'] as num?)?.toDouble() ?? 0;
            final price = (e['price'] as num?)?.toDouble() ?? 0;
            final base = qty * price;
            final discType = (e['discountType'] ?? 'percent').toString();
            final discVal = (e['discount'] as num?)?.toDouble() ?? 0;
            final disc = discType == 'percent' ? base * (discVal / 100) : discVal;
            final line = base - disc;
            return ListTile(
              title: Text(name?.toString() ?? ''),
              subtitle: Text('كمية: ${qty.toStringAsFixed(2)} • سعر: ${fmt.format(price)} • خصم: ${discType == 'percent' ? '${discVal.toString()}%' : fmt.format(discVal)}'),
              trailing: Text(fmt.format(line)),
            );
          }).cast<Widget>(),
          const Divider(),
          _rowSummary(context, 'الإجمالي قبل الخصم', fmt.format(subtotal)),
          _rowSummary(context, 'إجمالي الخصم', fmt.format(discAmt)),
          _rowSummary(context, 'الإجمالي', fmt.format(total), isBold: true),
          const SizedBox(height: 6),
          _rowSummary(context, 'مدفوع', fmt.format(paid)),
          _rowSummary(context, 'المتبقي', fmt.format(due)),
        ],
      ),
    );
  }

  Widget _rowSummary(BuildContext context, String label, String value, {bool isBold = false}) {
    final style = isBold ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
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

  Future<void> _printPdf(BuildContext context) async {
    final bytes = await _buildPdf();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _sharePdf() async {
    final bytes = await _buildPdf();
    await Printing.sharePdf(bytes: bytes, filename: 'invoice-$invoiceId.pdf');
  }

  Future<Uint8List> _buildPdf() async {
    final contacts = LocalDb.I.contacts.toMap();
    final business = LocalDb.I.settings.get('business')?.cast<String, dynamic>() ?? {};
    final contact = contacts[data['contactId']];
    final items = (data['items'] as List?)?.cast<Map>() ?? [];
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final discMap = (data['discount'] as Map?)?.cast<String, dynamic>();
    final discAmt = (discMap?['amount'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final paid = (data['paid'] as num?)?.toDouble() ?? 0;
    final due = (data['due'] as num?)?.toDouble() ?? (total - paid);

    final fmt = NumberFormat.decimalPattern('ar');
    final title = _titleForKind(data['kind']?.toString() ?? '');

    final rows = items.map((e) {
      final name = e['name']?.toString() ?? '';
      final qty = (e['qty'] as num?)?.toDouble() ?? 0;
      final price = (e['price'] as num?)?.toDouble() ?? 0;
      final base = qty * price;
      final discType = (e['discountType'] ?? 'percent').toString();
      final discVal = (e['discount'] as num?)?.toDouble() ?? 0;
      final disc = discType == 'percent' ? base * (discVal / 100) : discVal;
      final line = base - disc;
      final discLabel = discType == 'percent' ? '${discVal.toString()}%' : fmt.format(discVal);
      return '<tr><td>$name</td><td style="text-align:center">${qty.toStringAsFixed(2)}</td><td style="text-align:center">${fmt.format(price)}</td><td style="text-align:center">$discLabel</td><td style="text-align:center">${fmt.format(line)}</td></tr>';
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
    <div class="title">$title</div>
    <div class="right">
      <div>${business['name']?.toString() ?? 'نشاطي التجاري'}</div>
      <div>الهاتف: ${business['phone']?.toString() ?? ''}</div>
    </div>
  </div>
  <hr />
  <div>رقم: $invoiceId</div>
  <div>العميل/المورد: ${contact?['name'] ?? ''}</div>
  <div>التاريخ: ${data['date'] ?? ''}</div>
  <table>
    <thead>
      <tr>
        <th>الصنف</th>
        <th>الكمية</th>
        <th>السعر</th>
        <th>خصم</th>
        <th>الإجمالي</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>
  <div class="right" style="margin-top:12px;">الإجمالي قبل الخصم: ${fmt.format(subtotal)}</div>
  <div class="right">إجمالي الخصم: ${fmt.format(discAmt)}</div>
  <div class="right" style="font-weight:700">الإجمالي: ${fmt.format(total)}</div>
  <div class="right">مدفوع: ${fmt.format(paid)}</div>
  <div class="right">المتبقي: ${fmt.format(due)}</div>
</body>
</html>
''';

    final bytes = await Printing.convertHtml(html: html);
    return bytes;
  }

  pw.Widget _th(String text) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
  pw.Widget _td(String text, {pw.TextAlign? align}) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, textAlign: align));
}
