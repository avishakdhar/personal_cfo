import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';

/// Google Drive backup and restore service.
///
/// SETUP REQUIRED (one-time):
/// 1. Go to console.cloud.google.com
/// 2. Create a project → Enable "Google Drive API"
/// 3. Create OAuth 2.0 credentials (Android client ID)
/// 4. Add SHA-1 fingerprint of your signing key
/// 5. Download google-services.json → place in android/app/
/// 6. For iOS: download GoogleService-Info.plist → place in ios/Runner/
///
/// Without this setup, sign-in will fail with "sign_in_failed".
class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._();
  GoogleDriveService._();

  static const String _backupFolderName = 'PersonalCFO_Backups';
  static const String _driveFilesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const String _driveUploadUrl =
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart';

  final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata',
             'https://www.googleapis.com/auth/drive.file'],
  );

  GoogleSignInAccount? _currentUser;

  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;

  /// Sign in with Google
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      return account != null;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Get authorization headers for Drive API calls
  Future<Map<String, String>> _getAuthHeaders() async {
    if (_currentUser == null) throw Exception('Not signed in to Google');
    final auth = await _currentUser!.authentication;
    return {
      'Authorization': 'Bearer ${auth.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  /// Create or find the backup folder in Drive
  Future<String> _getOrCreateBackupFolder() async {
    final headers = await _getAuthHeaders();

    // Search for existing folder
    final searchResp = await http.get(
      Uri.parse(
        '$_driveFilesUrl?q=name="${_backupFolderName}" and mimeType="application/vnd.google-apps.folder" and trashed=false',
      ),
      headers: headers,
    );

    if (searchResp.statusCode == 200) {
      final data = jsonDecode(searchResp.body);
      final files = data['files'] as List;
      if (files.isNotEmpty) return files.first['id'] as String;
    }

    // Create folder
    final createResp = await http.post(
      Uri.parse(_driveFilesUrl),
      headers: headers,
      body: jsonEncode({
        'name': _backupFolderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );

    if (createResp.statusCode != 200 && createResp.statusCode != 201) {
      throw Exception('Failed to create Drive folder: ${createResp.statusCode}');
    }

    return (jsonDecode(createResp.body))['id'] as String;
  }

  /// Upload a full backup to Google Drive
  Future<String> uploadBackup() async {
    if (_currentUser == null) throw Exception('Not signed in to Google');

    final db = DatabaseHelper.instance;
    final backup = {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': await db.getAccounts(),
      'transactions': await db.getAllTransactionsRaw(),
      'budgets': await db.getBudgets(),
      'goals': await db.getGoals(),
      'investments': await db.getInvestments(),
      'debts': await db.getDebts(),
      'recurring': await db.getRecurringTransactions(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);
    final bytes = utf8.encode(json);

    final now = DateTime.now();
    final fileName =
        'personal_cfo_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';

    final folderId = await _getOrCreateBackupFolder();
    final authHeaders = await _getAuthHeaders();

    // Multipart upload
    final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';

    final metadataPart = '{\n  "name": "$fileName",\n  "parents": ["$folderId"]\n}';

    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadataPart\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json\r\n\r\n'
        '${utf8.decode(bytes)}\r\n'
        '--$boundary--';

    final response = await http.post(
      Uri.parse(_driveUploadUrl),
      headers: {
        'Authorization': authHeaders['Authorization']!,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Drive upload failed: ${response.statusCode} ${response.body}');
    }

    // Clean up old backups (keep only last 5)
    await _cleanOldBackups(folderId);

    return fileName;
  }

  /// List backups available in Drive
  Future<List<Map<String, String>>> listBackups() async {
    if (_currentUser == null) throw Exception('Not signed in to Google');

    final folderId = await _getOrCreateBackupFolder();
    final headers = await _getAuthHeaders();

    final resp = await http.get(
      Uri.parse(
        '$_driveFilesUrl?q="$folderId" in parents and trashed=false&orderBy=createdTime desc&fields=files(id,name,createdTime)',
      ),
      headers: headers,
    );

    if (resp.statusCode != 200) return [];

    final data = jsonDecode(resp.body);
    final files = data['files'] as List;
    return files
        .map((f) => {
              'id': f['id'] as String,
              'name': f['name'] as String,
              'date': f['createdTime'] as String,
            })
        .toList();
  }

  /// Download and restore a backup from Drive by file ID
  Future<String> downloadAndRestore(String fileId) async {
    if (_currentUser == null) throw Exception('Not signed in to Google');

    final headers = await _getAuthHeaders();

    final resp = await http.get(
      Uri.parse('$_driveFilesUrl/$fileId?alt=media'),
      headers: headers,
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to download backup: ${resp.statusCode}');
    }

    // Save to temp file and restore
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/drive_restore_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsBytes(resp.bodyBytes);

    // Parse and restore
    final content = resp.body;
    final backup = jsonDecode(content) as Map<String, dynamic>;

    final db = DatabaseHelper.instance;
    int restored = 0;

    final accounts = backup['accounts'] as List? ?? [];
    for (final a in accounts) {
      try {
        await db.insertAccount(Map<String, dynamic>.from(a)..remove('id'));
        restored++;
      } catch (_) {}
    }

    await file.delete();
    return 'Restored $restored accounts from Google Drive backup';
  }

  /// Delete old backups, keeping only the most recent [keepCount]
  Future<void> _cleanOldBackups(String folderId, {int keepCount = 5}) async {
    try {
      final backups = await listBackups();
      if (backups.length <= keepCount) return;

      final headers = await _getAuthHeaders();
      final toDelete = backups.sublist(keepCount);

      for (final backup in toDelete) {
        await http.delete(
          Uri.parse('$_driveFilesUrl/${backup['id']}'),
          headers: headers,
        );
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }
}
