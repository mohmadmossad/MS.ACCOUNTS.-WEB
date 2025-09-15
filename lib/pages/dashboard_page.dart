import 'dart:io';
import 'package:flutter/material.dart';
import 'package:_/pages/placeholder_page.dart';
import 'package:_/pages/invoices_page.dart';
import 'package:_/pages/contacts_page.dart';
import 'package:_/pages/reports_page.dart';
import 'package:_/pages/account_statement_page.dart';
import 'package:_/pages/backup_page.dart';
import 'package:_/widgets/app_drawer.dart';
import 'package:_/services/local_db.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DashItem('المبيعات', Icons.point_of_sale, Colors.blue, const InvoicesPage()),
      _DashItem('المشتريات', Icons.shopping_cart, Colors.green, const InvoicesPage()),
      _DashItem('العملاء والموردون', Icons.group, Colors.teal, const ContactsPage()),
      _DashItem('التقارير', Icons.bar_chart, Colors.deepOrange, const ReportsPage()),
      _DashItem('كشف حساب', Icons.article, Colors.brown, const AccountStatementPage()),
      _DashItem('نسخ احتياطي', Icons.cloud_upload, Colors.red, const BackupPage()),
    ];

    final vouchers = LocalDb.I.vouchers;
    final business = LocalDb.I.settings.get('business')?.cast<String, dynamic>() ?? {};
    final String? logoPath = ((business['logoPath'] ?? '') as String).isEmpty ? null : business['logoPath'] as String?;
    final String companyName = (business['name']?.toString().trim().isEmpty ?? true) ? 'لوحة التحكم' : business['name'].toString();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              backgroundImage: logoPath == null ? null : FileImage(File(logoPath)),
              child: logoPath == null ? const Icon(Icons.store, size: 18, color: Colors.blue) : null,
            ),
            const SizedBox(width: 8),
            Text(companyName),
          ],
        ),
      ),
      drawer: const AppMainDrawer(),
      body: Stack(
        children: [
          if (logoPath != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.06,
                child: Image.file(
                  File(logoPath),
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: vouchers.listenable(),
                  builder: (context, _, __) {
                    double cash = 0;
                    for (final e in vouchers.toMap().values) {
                      final v = e as Map;
                      final amt = (v['amount'] as num?)?.toDouble() ?? 0.0;
                      cash += (v['type'] == 'receipt') ? amt : -amt;
                    }
                    final fmt = NumberFormat.decimalPattern('ar');
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.account_balance_wallet, color: Colors.white)),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('رصيد الصندوق')),
                          Text(fmt.format(cash), style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: GridView.builder(
                    itemCount: cards.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemBuilder: (context, index) {
                      final item = cards[index];
                      return InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Icon(item.icon, color: item.color, size: 34),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashItem {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;
  _DashItem(this.title, this.icon, this.color, this.page);
}
