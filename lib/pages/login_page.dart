import 'dart:io';
import 'package:flutter/material.dart';
import 'package:_/services/auth.dart';
import 'package:_/services/local_db.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController(text: 'admin');
  final _passwordCtrl = TextEditingController(text: '1234');
  bool _obscure = true;
  bool _loading = false;

  Future<void> _doLogin() async {
    setState(() => _loading = true);
    final ok = await AuthService.I
        .login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      // AuthGate will rebuild to show the dashboard
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تسجيل الدخول')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تسجيل الدخول، تحقق من البيانات')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = LocalDb.I.settings.get('business')?.cast<String, dynamic>() ?? {};
    final String? logoPath = ((business['logoPath'] ?? '') as String).isEmpty ? null : business['logoPath'] as String?;
    final String companyName = (business['name']?.toString().trim().isEmpty ?? true) ? 'المحاسب الذكي' : business['name'].toString();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      backgroundImage: logoPath == null ? null : FileImage(File(logoPath)),
                      child: logoPath == null ? const Icon(Icons.store, size: 40, color: Colors.blue) : null,
                    ),
                    const SizedBox(height: 8),
                    Text(companyName, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _doLogin(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login),
                        label: Text(_loading ? 'جارٍ الدخول...' : 'تسجيل الدخول'),
                        onPressed: _loading ? null : _doLogin,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('مستخدم افتراضي: admin / 1234', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
