import 'dart:async';

/// CloudBackup: placeholder for cloud backup/restore.
/// In DreamFlow, connect Firebase (or Supabase) from the backend panel first.
/// After connection, this service can be implemented to upload/download the
/// JSON exported by LocalDb to the cloud (e.g., Firebase Storage/Firestore).
class CloudBackupService {
  CloudBackupService._internal();
  static final CloudBackupService I = CloudBackupService._internal();

  /// Indicates if a cloud backend is configured.
  /// Once Firebase/Supabase is connected via DreamFlow panel, set this to true
  /// and implement the methods below accordingly.
  bool get isConfigured => false; // TODO: set based on app state/injection

  /// Upload exported JSON to cloud.
  /// Implement using Firebase Storage or Supabase Storage after backend setup.
  Future<void> backupJson(String json) async {
    if (!isConfigured) {
      throw StateError('Cloud backend not configured. Open Firebase/Supabase panel in DreamFlow and complete setup.');
    }
    // TODO: Upload `json` string to cloud storage with a timestamped filename.
  }

  /// Retrieve the latest JSON backup from cloud.
  /// Implement to fetch the latest (or selected) backup file from cloud.
  Future<String> restoreLatestJson() async {
    if (!isConfigured) {
      throw StateError('Cloud backend not configured. Open Firebase/Supabase panel in DreamFlow and complete setup.');
    }
    // TODO: Download latest backup content and return as String.
    return '';
  }
}
