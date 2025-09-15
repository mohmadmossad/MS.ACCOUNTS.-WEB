import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:_/services/accounting.dart';

class FinancialStatementsPage extends StatefulWidget {
  const FinancialStatementsPage({super.key});

  @override
  State<FinancialStatementsPage> createState() => _FinancialStatementsPageState();
}

class _FinancialStatementsPageState extends State<FinancialStatementsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    AccountingService.I.ensureDefaultCoA();
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
        title: const Text('القوائم المالية'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ميزان المراجعة'),
            Tab(text: 'الميزانية'),
            Tab(text: 'قائمة الدخل'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'إقفال الفترة',
            icon: const Icon(Icons.lock, color: Colors.brown),
            onPressed: () async {
              await AccountingService.I.closePeriod();
              if (mounted) setState(() {});
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء قيد الإقفال')));
            },
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TrialBalanceTab(),
          _BalanceSheetTab(),
          _IncomeStatementTab(),
        ],
      ),
    );
  }
}

class _TrialBalanceTab extends StatelessWidget {
  const _TrialBalanceTab();
  @override
  Widget build(BuildContext context) {
    final list = AccountingService.I.trialBalance();
    final fmt = NumberFormat.decimalPattern('ar');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = list[i];
        return ListTile(
          leading: CircleAvatar(backgroundColor: Colors.blue, child: Text((r['code'] ?? '').toString().characters.take(2).join())),
          title: Text('${r['code']} • ${r['name']}'),
          subtitle: Text(_typeLabel(r['type']?.toString() ?? 'asset')),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('مدين: ${fmt.format((r['debit'] as num?)?.toDouble() ?? 0)}'),
              Text('دائن: ${fmt.format((r['credit'] as num?)?.toDouble() ?? 0)}'),
            ],
          ),
        );
      },
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'asset':
        return 'أصل';
      case 'liability':
        return 'خصم';
      case 'equity':
        return 'حقوق الملكية';
      case 'income':
        return 'إيراد';
      case 'contra_income':
        return 'مردود/خصم مبيعات';
      case 'expense':
        return 'مصروف';
      default:
        return t;
    }
  }
}

class _BalanceSheetTab extends StatelessWidget {
  const _BalanceSheetTab();
  @override
  Widget build(BuildContext context) {
    final totals = AccountingService.I.totalsByType();
    final fmt = NumberFormat.decimalPattern('ar');
    final assets = totals['asset'] ?? 0;
    final liabilities = totals['liability'] ?? 0;
    final equity = (totals['equity'] ?? 0) + (totals['income'] ?? 0) - (totals['contra_income'] ?? 0) - (totals['expense'] ?? 0);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row(context, 'الأصول', fmt.format(assets), Colors.blue),
        const Divider(),
        _row(context, 'الخصوم', fmt.format(liabilities), Colors.red),
        _row(context, 'حقوق الملكية', fmt.format(equity), Colors.indigo),
        const Divider(),
        _row(context, 'المعادلة (الأصول - الخصوم - حقوق الملكية)', fmt.format(assets - liabilities - equity), Colors.brown),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, Color color) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CircleAvatar(backgroundColor: color, child: const Icon(Icons.pie_chart, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ]),
      );
}

class _IncomeStatementTab extends StatelessWidget {
  const _IncomeStatementTab();
  @override
  Widget build(BuildContext context) {
    final totals = AccountingService.I.totalsByType();
    final fmt = NumberFormat.decimalPattern('ar');
    final revenue = (totals['income'] ?? 0);
    final salesReturns = (totals['contra_income'] ?? 0);
    final expenses = (totals['expense'] ?? 0);
    final netSales = revenue - salesReturns;
    final profit = netSales - expenses;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row(context, 'المبيعات', fmt.format(revenue), Colors.teal),
        _row(context, 'مردودات/خصومات المبيعات', fmt.format(salesReturns), Colors.orange),
        const Divider(),
        _row(context, 'صافي المبيعات', fmt.format(netSales), Colors.indigo),
        const Divider(),
        _row(context, 'المصروفات (تشمل تكلفة البضاعة)', fmt.format(expenses), Colors.brown),
        const Divider(),
        _row(context, 'صافي الربح/الخسارة', fmt.format(profit), profit >= 0 ? Colors.green : Colors.red),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, Color color) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CircleAvatar(backgroundColor: color, child: const Icon(Icons.bar_chart, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ]),
      );
}
