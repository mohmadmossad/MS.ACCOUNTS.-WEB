import 'package:hive_flutter/hive_flutter.dart';
import 'package:_/services/local_db.dart';

/// AuthService: very simple local auth (no backend)
/// - Stores users in LocalDb.I.users with optional fields: username, password
/// - Stores session in LocalDb.I.settings under key 'auth'
class AuthService {
  AuthService._internal();
  static final AuthService I = AuthService._internal();

  Box<Map> get _users => LocalDb.I.users;
  Box<Map> get _settings => LocalDb.I.settings;

  /// Ensure there is at least one default admin account for first login.
  /// Default credentials: username: admin, password: 1234
  Future<void> bootstrap() async {
    // If there is any user with a username, do nothing
    final hasUserWithUsername = _users.values.any((v) {
      final map = v.cast<String, dynamic>();
      return (map['username'] ?? '').toString().trim().isNotEmpty;
    });
    if (!hasUserWithUsername) {
      // Create default admin user
      final id = LocalDb.I.newId('USR');
      await _users.put(id, {
        'name': 'مدير النظام',
        'role': 'admin',
        'phone': '',
        'username': 'admin',
        // For local-only demo we keep plain password. You can change it later from إدارة المستخدمين.
        'password': '1234',
        'sales': true,
        'purchases': true,
        'inventory': true,
        'reports': true,
        'settings': true,
        'contacts': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Map<String, dynamic> get session =>
      _settings.get('auth')?.cast<String, dynamic>() ?? <String, dynamic>{};

  bool get isLoggedIn => (session['loggedIn'] ?? false) == true;

  String? get currentUserId => session['userId'] as String?;

  Map<String, dynamic>? get currentUser => currentUserId == null
      ? null
      : _users.get(currentUserId!)?.cast<String, dynamic>();

  Future<bool> login(String username, String password) async {
    // Find user by username
    final entry = _users.toMap().entries.firstWhere(
      (e) {
        final v = e.value.cast<String, dynamic>();
        return (v['username'] ?? '').toString().trim().toLowerCase() ==
            username.trim().toLowerCase();
      },
      orElse: () => const MapEntry('', {}),
    );
    if (entry.key is String && (entry.key as String).isNotEmpty) {
      final data = entry.value.cast<String, dynamic>();
      final ok = (data['password'] ?? '') == password;
      if (ok) {
        await _settings.put('auth', {
          'loggedIn': true,
          'userId': entry.key,
          'loggedAt': DateTime.now().toIso8601String(),
        });
        return true;
      }
    }
    return false;
  }

  Future<void> logout() async {
    await _settings.put('auth', {
      'loggedIn': false,
      'userId': null,
      'loggedAt': DateTime.now().toIso8601String(),
    });
  }
}
