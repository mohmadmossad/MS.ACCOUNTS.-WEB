import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode_widget/barcode_widget.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.showPrintActions = false, this.showBarcodeDemo = false});

  final String title;
  final bool showPrintActions;
  final bool showBarcodeDemo;

  Future<void> _printSampleInvoice(BuildContext context) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('فاتورة مبيعات', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('المنشأة: نشاطي التجاري'),
                pw.Text('الهاتف: 0550000000'),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2)},
                  children: [
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الصنف', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الكمية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الإجمالي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ]),
                    ...List.generate(3, (i) => pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('صنف رقم ${i + 1}')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('2')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('50.00 ر.س')),
                    ])),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('المجموع: 150.00 ر.س')),
                pw.SizedBox(height: 24),
                pw.Center(child: pw.Text('شكراً لتسوقكم معنا')),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _shareSampleInvoice() async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(children: [pw.Text('فاتورة مبيعات (عينة)'), pw.SizedBox(height: 8), pw.Text('المجموع: 150.00 ر.س')]),
      ),
    ));

    await Printing.sharePdf(bytes: await doc.save(), filename: 'invoice-sample.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showPrintActions)
            IconButton(
              tooltip: 'طباعة',
              onPressed: () => _printSampleInvoice(context),
              icon: const Icon(Icons.print, color: Colors.blue),
            ),
          if (showPrintActions)
            IconButton(
              tooltip: 'مشاركة',
              onPressed: _shareSampleInvoice,
              icon: const Icon(Icons.share, color: Colors.green),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'هذه صفحة معاينة للميزة: $title',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          Text(
            'سيتم لاحقاً إضافة الحقول، الحفظ المحلي، البحث، والربط بين الفواتير والمخزون والعملاء والموردين.\nحالياً هذه نسخة استعراضية لتأكيد الشكل والتدفق.',
            textAlign: TextAlign.right,
          ),
          if (showBarcodeDemo) ...[
            const SizedBox(height: 24),
            Text('مثال باركود للصنف', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: 'ITEM-123456',
                      drawText: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
