import 'package:flutter/material.dart';
import 'package:_/services/local_db.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('العملاء والموردون'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'العملاء'),
            Tab(text: 'الموردون'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ContactsTab(kind: 'customer'),
          _ContactsTab(kind: 'supplier'),
        ],
      ),
    );
  }
}

class _ContactsTab extends StatefulWidget {
  const _ContactsTab({required this.kind});
  final String kind; // 'customer' | 'supplier'

  @override
  State<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<_ContactsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final box = LocalDb.I.contacts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث بالاسم...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (s) => setState(() => _query = s.trim()),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, _, __) {
              final filtered = box
                  .toMap()
                  .entries
                  .where((e) => (e.value['kind'] == widget.kind))
                  .where((e) => _query.isEmpty || (e.value['name']?.toString().contains(_query) ?? false))
                  .toList()
                ..sort((a, b) => (a.value['name'] ?? '').toString().compareTo((b.value['name'] ?? '').toString()));

              if (filtered.isEmpty) {
                return const Center(child: Text('لا توجد بيانات بعد'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = filtered[index];
                  final v = Map<String, dynamic>.from(e.value);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: widget.kind == 'customer' ? Colors.teal : Colors.indigo,
                      child: Icon(widget.kind == 'customer' ? Icons.person : Icons.store, color: Colors.white),
                    ),
                    title: Text(v['name'] ?? ''),
                    subtitle: Text(((v['address'] ?? '') as String).isEmpty ? (v['phone'] ?? '') : '${v['address']} • ${v['phone'] ?? ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _openEditor(context, id: e.key.toString(), initial: v),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_box_outlined),
                label: Text('إضافة ${widget.kind == 'customer' ? 'عميل' : 'مورد'}'),
                onPressed: () => _openEditor(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, {String? id, Map<String, dynamic>? initial}) async {
    final isCustomer = widget.kind == 'customer';
    final nameCtrl = TextEditingController(text: initial?['name'] ?? '');
    final addressCtrl = TextEditingController(text: initial?['address'] ?? '');
    final phoneCtrl = TextEditingController(text: initial?['phone'] ?? '');

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(id == null ? 'إضافة ${isCustomer ? 'عميل' : 'مورد'}' : 'تعديل ${isCustomer ? 'عميل' : 'مورد'}', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'العنوان'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('إلغاء'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text('حفظ'),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final data = {
                          'kind': widget.kind,
                          'name': name,
                          'address': addressCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'updatedAt': DateTime.now().toIso8601String(),
                        };
                        final key = id ?? LocalDb.I.newId(widget.kind == 'customer' ? 'CUS' : 'SUP');
                        await LocalDb.I.contacts.put(key, data);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
        return sheet;
      },
    );
  }
}
