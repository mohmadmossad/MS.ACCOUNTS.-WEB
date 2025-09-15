import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:_/services/local_db.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final invoices = LocalDb.I.invoices.toMap().values.map((e) => Map<String, dynamic>.from(e)).toList();
    final sales = invoices.where((e) => e['kind'] == 'sale').fold<double>(0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));
    final salesReturn = invoices.where((e) => e['kind'] == 'sale_return').fold<double>(0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));
    final purchases = invoices.where((e) => e['kind'] == 'purchase').fold<double>(0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));
    final purchaseReturn = invoices.where((e) => e['kind'] == 'purchase_return').fold<double>(0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));

    final netSales = sales - salesReturn;
    final netPurchases = purchases - purchaseReturn;
    final profit = netSales - netPurchases;

    final vouchers = LocalDb.I.vouchers.toMap().values.map((e) => Map<String, dynamic>.from(e)).toList();
    final receipts = vouchers.where((e) => e['type'] == 'receipt').fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    final payments = vouchers.where((e) => e['type'] == 'payment').fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    String fmt(double v) => NumberFormat.decimalPattern('ar').format(v);

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(title: 'إجمالي المبيعات', value: fmt(sales), color: Colors.blue, icon: Icons.trending_up),
          const SizedBox(height: 12),
          _InfoCard(title: 'مردود المبيعات', value: fmt(salesReturn), color: Colors.orange, icon: Icons.keyboard_return),
          const SizedBox(height: 12),
          _InfoCard(title: 'إجمالي المشتريات', value: fmt(purchases), color: Colors.green, icon: Icons.shopping_bag),
          const SizedBox(height: 12),
          _InfoCard(title: 'مردود المشتريات', value: fmt(purchaseReturn), color: Colors.brown, icon: Icons.keyboard_return),
          const SizedBox(height: 12),
          _InfoCard(title: 'صافي المبيعات', value: fmt(netSales), color: Colors.indigo, icon: Icons.ssid_chart),
          const SizedBox(height: 12),
          _InfoCard(title: 'صافي المشتريات', value: fmt(netPurchases), color: Colors.cyan, icon: Icons.shopping_cart_checkout),
          const SizedBox(height: 12),
          _InfoCard(title: 'الربح/الخسارة التقريبي', value: fmt(profit), color: profit >= 0 ? Colors.teal : Colors.red, icon: Icons.calculate),
          const Divider(height: 32),
          _InfoCard(title: 'سندات القبض', value: fmt(receipts), color: Colors.teal, icon: Icons.call_received),
          const SizedBox(height: 12),
          _InfoCard(title: 'سندات الصرف', value: fmt(payments), color: Colors.red, icon: Icons.call_made),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value, required this.color, required this.icon});
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
