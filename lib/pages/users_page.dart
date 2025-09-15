import 'package:flutter/material.dart';
import 'package:_/services/local_db.dart';
import 'package:hive_flutter/hive_flutter.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = LocalDb.I.users;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المستخدمون والصلاحيات')),
        body: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, _, __) {
            final entries = box.toMap().entries.toList()
              ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));
            if (entries.isEmpty) return const Center(child: Text('لا مستخدمين بعد'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = entries[i];
                final v = Map<String, dynamic>.from(e.value);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Text((v['name'] ?? '؟').toString().characters.first),
                  ),
                  title: Text(v['name'] ?? ''),
                  subtitle: Text('الدور: ${v['role'] ?? 'غير محدد'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _openEditor(context, id: e.key.toString(), initial: v),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة مستخدم'),
          onPressed: () => _openEditor(context),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {String? id, Map<String, dynamic>? initial}) async {
    final nameCtrl = TextEditingController(text: initial?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: initial?['phone'] ?? '');
    String role = (initial?['role'] ?? 'admin') as String; // admin, cashier, storekeeper, viewer

    final perms = {
      'sales': initial?['sales'] ?? true,
      'purchases': initial?['purchases'] ?? true,
      'inventory': initial?['inventory'] ?? true,
      'reports': initial?['reports'] ?? true,
      'settings': initial?['settings'] ?? true,
      'contacts': initial?['contacts'] ?? true,
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final sheet = Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(id == null ? 'إضافة مستخدم' : 'تعديل مستخدم', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('مدير')),
                  DropdownMenuItem(value: 'cashier', child: Text('أمين صندوق')),
                  DropdownMenuItem(value: 'storekeeper', child: Text('أمين مخزن')),
                  DropdownMenuItem(value: 'viewer', child: Text('عرض فقط')),
                ],
                onChanged: (v) => role = v ?? role,
                decoration: const InputDecoration(labelText: 'الدور'),
              ),
              const SizedBox(height: 12),
              Text('الصلاحيات', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...perms.keys.map((k) => SwitchListTile(
                    title: Text(_permLabel(k)),
                    value: perms[k] as bool,
                    onChanged: (val) => {perms[k] = val, (ctx as Element).markNeedsBuild()},
                  )),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.close, color: Colors.red), label: const Text('إلغاء'), onPressed: () => Navigator.pop(ctx))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ'),
                      onPressed: () async {
                        final data = {
                          'name': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'role': role,
                          ...perms,
                          'updatedAt': DateTime.now().toIso8601String(),
                        };
                        final key = id ?? LocalDb.I.newId('USR');
                        await LocalDb.I.users.put(key, data);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        return sheet;
      },
    );
  }

  String _permLabel(String k) {
    switch (k) {
      case 'sales':
        return 'المبيعات';
      case 'purchases':
        return 'المشتريات';
      case 'inventory':
        return 'المخزون والجرد';
      case 'reports':
        return 'التقارير';
      case 'settings':
        return 'الإعدادات';
      case 'contacts':
        return 'العملاء والموردون';
      default:
        return k;
    }
  }
}
