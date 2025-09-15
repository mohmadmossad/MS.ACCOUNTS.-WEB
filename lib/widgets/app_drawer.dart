import 'dart:io';
import 'package:flutter/material.dart';
import 'package:_/pages/invoices_page.dart';
import 'package:_/pages/contacts_page.dart';
import 'package:_/pages/backup_page.dart';
import 'package:_/pages/reports_page.dart';
import 'package:_/pages/users_page.dart';
import 'package:_/pages/account_statement_page.dart';
import 'package:_/pages/inventory_page.dart';
import 'package:_/pages/vouchers_page.dart';
import 'package:_/pages/settings_page.dart';
import 'package:_/pages/chart_of_accounts_page.dart';
import 'package:_/pages/financial_statements_page.dart';
import 'package:_/services/auth.dart';
import 'package:_/services/local_db.dart';

class AppMainDrawer extends StatelessWidget {
  const AppMainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Text('المحاسب الذكي', style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.space_dashboard, color: Colors.blue),
            title: const Text('لوحة التحكم'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.point_of_sale, color: Colors.blue),
            title: const Text('المبيعات والمشتريات (فواتير)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.purple),
            title: const Text('سندات قبض/صرف'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VouchersPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.inventory_2, color: Colors.brown),
            title: const Text('المخزون (أصناف/مجموعات/وحدات)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.group, color: Colors.teal),
            title: const Text('العملاء والموردون'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_circle, color: Colors.indigo),
            title: const Text('المستخدمون والصلاحيات'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.book, color: Colors.indigo),
            title: const Text('الدليل المحاسبي'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChartOfAccountsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.balance, color: Colors.deepPurple),
            title: const Text('القوائم المالية'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialStatementsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.deepOrange),
            title: const Text('التقارير'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.article, color: Colors.brown),
            title: const Text('كشف حساب (عميل/مورد)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountStatementPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_upload, color: Colors.red),
            title: const Text('نسخ احتياطي / استرداد'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.red),
            title: const Text('الإعدادات (اسم النشاط/الشعار/الهاتف)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج'),
            onTap: () async {
              await AuthService.I.logout();
              if (context.mounted) {
                Navigator.pop(context); // close drawer
                // Optionally pop to root to clean stack
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الخروج')));
              }
            },
          ),
        ],
      ),
    );
  }
}
