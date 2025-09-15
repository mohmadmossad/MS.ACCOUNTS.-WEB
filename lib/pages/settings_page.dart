import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:_/services/local_db.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _logoPath;

  // Barcode settings
  String _barcodeFormat = 'code128'; // 'code128' | 'ean13'
  final _barcodePrefixCtrl = TextEditingController(text: 'ITM');

  @override
  void initState() {
    super.initState();
    final s = LocalDb.I.settings.get('business')?.cast<String, dynamic>() ?? {};
    _nameCtrl.text = (s['name'] ?? '').toString();
    _phoneCtrl.text = (s['phone'] ?? '').toString();
    _logoPath = (s['logoPath'] ?? '').toString().isEmpty ? null : s['logoPath'] as String?;

    final barcode = LocalDb.I.settings.get('barcode')?.cast<String, dynamic>() ?? {};
    _barcodeFormat = (barcode['format'] ?? 'code128').toString();
    _barcodePrefixCtrl.text = (barcode['prefix'] ?? 'ITM').toString();
  }

  Future<void> _pickLogo() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res == null || res.files.single.path == null) return;
    setState(() => _logoPath = res.files.single.path);
  }

  Future<void> _save() async {
    await LocalDb.I.settings.put('business', {
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'logoPath': _logoPath ?? '',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await LocalDb.I.settings.put('barcode', {
      'format': _barcodeFormat,
      'prefix': _barcodePrefixCtrl.text.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات النشاط')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                backgroundImage: _logoPath == null ? null : FileImage(File(_logoPath!)),
                child: _logoPath == null ? const Icon(Icons.store, color: Colors.blue) : null,
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('اختيار الشعار'),
                onPressed: _pickLogo,
              )
            ],
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم النشاط')),
          const SizedBox(height: 8),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),

          const SizedBox(height: 24),
          Text('إعدادات الباركود', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _barcodeFormat,
            decoration: const InputDecoration(labelText: 'نوع الترميز', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'code128', child: Text('Code 128 (مرن للأحرف والأرقام)')),
              DropdownMenuItem(value: 'ean13', child: Text('EAN-13 (أرقام فقط مع رقم تحقق)')),
            ],
            onChanged: (v) => setState(() => _barcodeFormat = v ?? 'code128'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _barcodePrefixCtrl,
            decoration: const InputDecoration(labelText: 'مقدمة الكود (Prefix)', border: OutlineInputBorder(), hintText: 'مثال: ITM أو PRD'),
          ),

          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.save), label: const Text('حفظ'), onPressed: _save),
        ],
      ),
    );
  }
}
