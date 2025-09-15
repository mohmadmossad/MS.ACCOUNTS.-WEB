import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:_/services/local_db.dart';
import 'package:_/services/cloud_backup.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  // Local export to JSON and share
  Future<void> _export(BuildContext context) async {
    final json = await LocalDb.I.exportToJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/smart-accounting-backup.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية');
  }

  // Local import from a picked JSON file
  Future<void> _import(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (res == null || res.files.single.path == null) return;
    final path = res.files.single.path!;
    final file = File(path);
    final content = await file.readAsString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاسترداد'),
        content: const Text('سيتم دمج البيانات من الملف المُحدد مع البيانات الحالية. هل تريد الاستمرار؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استمرار')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await LocalDb.I.importFromJson(content, replace: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاسترداد بنجاح')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاسترداد: $e')));
      }
    }
  }

  // Cloud backup (placeholder until backend is configured)
  Future<void> _cloudBackup(BuildContext context) async {
    final cloud = CloudBackupService.I;
    if (!cloud.isConfigured) {
      await _showCloudSetupDialog(context);
      return;
    }
    try {
      final json = await LocalDb.I.exportToJson();
      await cloud.backupJson(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع النسخة الاحتياطية إلى السحابة')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الرفع للسحابة: $e')));
      }
    }
  }

  // Cloud restore (placeholder until backend is configured)
  Future<void> _cloudRestore(BuildContext context) async {
    final cloud = CloudBackupService.I;
    if (!cloud.isConfigured) {
      await _showCloudSetupDialog(context);
      return;
    }
    try {
      final json = await cloud.restoreLatestJson();
      if (json.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد نسخة سحابية متاحة')));
        }
        return;
      }
      await LocalDb.I.importFromJson(json, replace: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاسترداد من السحابة')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الاسترداد من السحابة: $e')));
      }
    }
  }

  Future<void> _showCloudSetupDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفعيل النسخ السحابي'),
        content: const Text(
          'لاستخدام النسخ الاحتياطي عبر Google (Firebase)، افتح لوحة Firebase داخل DreamFlow وقم بإكمال الإعداد (ربط المشروع وإضافة الملفات التلقائية). بعد التفعيل سنقوم برفع واسترداد النسخ تلقائياً.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloudConfigured = CloudBackupService.I.isConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاسترداد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!cloudConfigured)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'النسخ السحابي غير مُفعل بعد. لتفعيله، افتح لوحة Firebase (أو Supabase) في DreamFlow وقم بالإعداد.'
                    ),
                  ),
                ],
              ),
            ),

          _Card(
            title: 'نسخ احتياطي (JSON)',
            subtitle: 'تصدير جميع البيانات (العملاء، الموردين، الفواتير، المستخدمين، الإعدادات) كملف JSON لمشاركته أو حفظه',
            icon: Icons.backup,
            color: Colors.blue,
            onTap: () => _export(context),
            action: FilledButton.icon(
              icon: const Icon(Icons.file_download),
              label: const Text('تصدير'),
              onPressed: () => _export(context),
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'استرداد من ملف JSON',
            subtitle: 'استيراد بيانات من ملف نسخ احتياطي بصيغة JSON وسيتم دمجها مع البيانات الحالية',
            icon: Icons.restore,
            color: Colors.green,
            onTap: () => _import(context),
            action: FilledButton.icon(
              icon: const Icon(Icons.file_upload),
              label: const Text('استيراد'),
              onPressed: () => _import(context),
            ),
          ),

          const SizedBox(height: 24),
          Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          const SizedBox(height: 12),

          _Card(
            title: 'نسخ احتياطي إلى السحابة (Google)',
            subtitle: 'رفع نسخة احتياطية إلى السحابة. يتطلب تفعيل Firebase من داخل DreamFlow.' ,
            icon: Icons.cloud_upload,
            color: Colors.indigo,
            onTap: () => _cloudBackup(context),
            action: FilledButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text('نسخ إلى السحابة'),
              onPressed: () => _cloudBackup(context),
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'استرداد من السحابة (Google)',
            subtitle: 'استرجاع أحدث نسخة احتياطية من السحابة. يتطلب تفعيل Firebase.' ,
            icon: Icons.cloud_download,
            color: Colors.deepPurple,
            onTap: () => _cloudRestore(context),
            action: FilledButton.icon(
              icon: const Icon(Icons.cloud_download),
              label: const Text('استرداد من السحابة'),
              onPressed: () => _cloudRestore(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.icon, required this.color, this.onTap, this.action});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
