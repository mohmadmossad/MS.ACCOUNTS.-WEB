import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:_/services/local_db.dart';

Future<void> printInventoryCountSheet() async {
  final business = LocalDb.I.settings.get('business')?.cast<String, dynamic>() ?? {};
  final list = LocalDb.I.items.toMap().entries.toList()
    ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));

  final baseFont = await PdfGoogleFonts.notoNaskhArabicRegular();
  final boldFont = await PdfGoogleFonts.notoNaskhArabicMedium();
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont));

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(16),
    build: (ctx) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(business['name']?.toString() ?? 'نشاطي التجاري', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('نموذج الجرد المخزني', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(children: [
                  _th('الصنف'),
                  _th('الباركود'),
                  _th('المتوفر'),
                  _th('المُعدّ'),
                  _th('الفرق'),
                ]),
                ...list.map((e) {
                  final v = Map<String, dynamic>.from(e.value);
                  final name = (v['name'] ?? '').toString();
                  final code = (v['barcode'] ?? '').toString();
                  final qty = ((v['qty'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
                  return pw.TableRow(children: [
                    _td(name),
                    _td(code),
                    _td(qty, align: pw.TextAlign.center),
                    _td('', align: pw.TextAlign.center),
                    _td('', align: pw.TextAlign.center),
                  ]);
                })
              ],
            ),
          ],
        ),
      );
    },
  ));

  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

pw.Widget _th(String text) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
pw.Widget _td(String text, {pw.TextAlign? align}) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text, textAlign: align));
