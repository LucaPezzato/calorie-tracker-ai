import 'dart:async';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../data/local_database.dart';

class DriveBackupService {
  static const String backupFileName = 'calorie_tracker_ai_backup.sqlite';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[drive.DriveApi.driveAppdataScope],
  );

  Timer? _debounceTimer;
  GoogleSignInAccount? _currentUser;
  DateTime? lastBackupTime;
  bool isSyncing = false;

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount?> signInSilently() async {
    _currentUser = await _googleSignIn.signInSilently();
    return _currentUser;
  }

  Future<GoogleSignInAccount?> signInInteractive() async {
    _currentUser = await _googleSignIn.signIn();
    return _currentUser;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Schedules an automatic background upload to Google Drive appDataFolder
  /// 10 seconds after the latest SQLite database change (debounce).
  void scheduleAutoBackup() {
    if (_currentUser == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), () async {
      try {
        await backupNow();
      } catch (_) {
        // Silent retry on next mutation if offline
      }
    });
  }

  /// Uploads only the lightweight SQLite database file (no meal photos) to Drive appDataFolder
  Future<DateTime?> backupNow() async {
    if (_currentUser == null) {
      await signInSilently();
      if (_currentUser == null) return null;
    }

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;

    isSyncing = true;
    try {
      final driveApi = drive.DriveApi(httpClient);
      final dbFile = await LocalDatabase.instance.prepareDatabaseFileForBackup();
      final media = drive.Media(dbFile.openRead(), await dbFile.length());

      // Check if backup file already exists in appDataFolder
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$backupFileName' and trashed = false",
        $fields: 'files(id, name, modifiedTime)',
      );

      final existingFiles = fileList.files;
      if (existingFiles != null && existingFiles.isNotEmpty) {
        final fileId = existingFiles.first.id!;
        await driveApi.files.update(
          drive.File()..name = backupFileName,
          fileId,
          uploadMedia: media,
        );
      } else {
        final driveFile = drive.File()
          ..name = backupFileName
          ..parents = <String>['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      lastBackupTime = DateTime.now();
      return lastBackupTime;
    } finally {
      isSyncing = false;
      httpClient.close();
    }
  }

  /// Downloads and restores the SQLite database from Google Drive appDataFolder
  Future<bool> restoreFromDrive() async {
    if (_currentUser == null) {
      await signInInteractive();
      if (_currentUser == null) return false;
    }

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return false;

    isSyncing = true;
    try {
      final driveApi = drive.DriveApi(httpClient);
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$backupFileName' and trashed = false",
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) return false;

      final fileId = files.first.id!;
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      await LocalDatabase.instance.restoreDatabaseFromBytes(bytes);
      return true;
    } finally {
      isSyncing = false;
      httpClient.close();
    }
  }
}
