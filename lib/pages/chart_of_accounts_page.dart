import 'package:flutter/material.dart';
import 'package:_/services/local_db.dart';
import 'package:_/services/accounting.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChartOfAccountsPage extends StatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  State<ChartOfAccountsPage> createState() => _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends State<ChartOfAccountsPage> {
  @override
  void initState() {
    super.initState();
    // Seed defaults if empty
    AccountingService.I.ensureDefaultCoA();
  }

  @override
  Widget build(BuildContext context) {
    final box = LocalDb.I.accounts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدليل المحاسبي'),
        actions: [
          IconButton(
            tooltip: 'إضافة حساب',
            icon: const Icon(Icons.add, color: Colors.blue),
            onPressed: () => _openEditor(context),
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, _, __) {
          final list = box
              .toMap()
              .entries
              .map((e) => MapEntry(e.key.toString(), Map<String, dynamic>.from(e.value)))
              .toList()
            ..sort((a, b) => (a.value['code'] ?? '').toString().compareTo((b.value['code'] ?? '').toString()));
          if (list.isEmpty) return const Center(child: CircularProgressIndicator());
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              final v = e.value;
              return ListTile(
                leading: CircleAvatar(backgroundColor: _colorForType(v['type']?.toString() ?? ''), child: Text((v['code'] ?? '').toString().characters.take(2).join())),
                title: Text('${v['code']} • ${v['name']}'),
                subtitle: Text(_typeLabel(v['type']?.toString() ?? 'asset')),
                trailing: PopupMenuButton<String>(
                  onSelected: (sel) {
                    switch (sel) {
                      case 'edit':
                        _openEditor(context, id: e.key, initial: v);
                        break;
                      case 'delete':
                        LocalDb.I.accounts.delete(e.key);
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
    );
  }

  Color _colorForType(String t) {
    switch (t) {
      case 'asset':
        return Colors.blue;
      case 'liability':
        return Colors.red;
      case 'equity':
        return Colors.indigo;
      case 'income':
        return Colors.teal;
      case 'contra_income':
        return Colors.orange;
      case 'expense':
        return Colors.brown;
      default:
        return Colors.grey;
    }
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

  Future<void> _openEditor(BuildContext context, {String? id, Map<String, dynamic>? initial}) async {
    final codeCtrl = TextEditingController(text: initial?['code']?.toString() ?? '');
    final nameCtrl = TextEditingController(text: initial?['name']?.toString() ?? '');
    String type = (initial?['type'] ?? 'asset').toString();
    String? parentCode = initial?['parentCode']?.toString();

    final accounts = LocalDb.I.accounts
        .toMap()
        .entries
        .map((e) => MapEntry(e.key.toString(), Map<String, dynamic>.from(e.value)))
        .toList()
      ..sort((a, b) => (a.value['code'] ?? '').toString().compareTo((b.value['code'] ?? '').toString()));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(id == null ? 'إضافة حساب' : 'تعديل حساب'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'الرمز')),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'asset', child: Text('أصل')),
                    DropdownMenuItem(value: 'liability', child: Text('خصم')),
                    DropdownMenuItem(value: 'equity', child: Text('حقوق الملكية')),
                    DropdownMenuItem(value: 'income', child: Text('إيراد')),
                    DropdownMenuItem(value: 'contra_income', child: Text('مردود/خصم مبيعات')),
                    DropdownMenuItem(value: 'expense', child: Text('مصروف')),
                  ],
                  onChanged: (v) => setSt(() => type = v ?? 'asset'),
                  decoration: const InputDecoration(labelText: 'النوع'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: parentCode,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('بدون أب (حساب رئيسي)')),
                    ...accounts
                        .where((e) => id == null || e.value['code']?.toString() != id) // avoid selecting self
                        .map((e) => DropdownMenuItem<String?>(value: e.value['code']?.toString(), child: Text('${e.value['code']} • ${e.value['name']}'))),
                  ],
                  onChanged: (v) => setSt(() => parentCode = v),
                  decoration: const InputDecoration(labelText: 'حساب أب (اختياري)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final data = {
                  'code': codeCtrl.text.trim(),
                  'name': nameCtrl.text.trim(),
                  'type': type,
                  'parentCode': parentCode,
                  'active': true,
                  'updatedAt': DateTime.now().toIso8601String(),
                };
                final key = id ?? codeCtrl.text.trim();
                await LocalDb.I.accounts.put(key, data);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
