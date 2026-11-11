import 'dart:async';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../data/local_database.dart';

class DriveBackupFileInfo {
  final String id;
  final DateTime modifiedTime;
  final int? sizeBytes;

  const DriveBackupFileInfo({
    required this.id,
    required this.modifiedTime,
    this.sizeBytes,
  });
}

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
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInInteractive() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed') {
        if (e.message != null && e.message!.contains('10')) {
          throw Exception(
            'Errore Google OAuth (Codice 10): L\'impronta SHA-1 del certificato non è registrata nella Google Cloud Console per il pacchetto "com.example.calorie_tracker_ai". Consulta la guida in Profilo.',
          );
        }
        if (e.message != null && e.message!.contains('12500')) {
          throw Exception(
            'Errore Google Play Services (12500): Verifica che i Google Play Services siano aggiornati sul dispositivo.',
          );
        }
      }
      if (e.code == 'sign_in_canceled') {
        throw Exception('Accesso Google annullato.');
      }
      throw Exception('Errore accesso Google (${e.code}): ${e.message ?? e.toString()}');
    } catch (e) {
      throw Exception('Errore accesso Google: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    lastBackupTime = null;
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

  /// Fetches metadata of the latest backup file in Drive appDataFolder (if any)
  Future<DriveBackupFileInfo?> getLatestBackupInfo() async {
    if (_currentUser == null) {
      await signInSilently();
      if (_currentUser == null) return null;
    }

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;

    try {
      final driveApi = drive.DriveApi(httpClient);
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$backupFileName' and trashed = false",
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime, size)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) return null;

      final f = files.first;
      final modTime = f.modifiedTime ?? DateTime.now();
      final size = f.size != null ? int.tryParse(f.size!) : null;

      return DriveBackupFileInfo(
        id: f.id!,
        modifiedTime: modTime,
        sizeBytes: size,
      );
    } catch (_) {
      return null;
    } finally {
      httpClient.close();
    }
  }

  /// Uploads only the lightweight SQLite database file (no meal photos) to Drive appDataFolder
  Future<DateTime> backupNow() async {
    if (_currentUser == null) {
      await signInSilently();
      if (_currentUser == null) {
        throw Exception(
          'Account Google non collegato. Tocca "Accedi con Google" per abilitare il backup su Drive.',
        );
      }
    }

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw Exception('Impossibile ottenere il client autenticato per Google Drive.');
    }

    isSyncing = true;
    try {
      final driveApi = drive.DriveApi(httpClient);
      final dbFile = await LocalDatabase.instance.prepareDatabaseFileForBackup();
      final fileSize = await dbFile.length();
      final media = drive.Media(dbFile.openRead(), fileSize);

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
      return lastBackupTime!;
    } catch (e) {
      throw Exception('Errore durante l\'upload su Google Drive: $e');
    } finally {
      isSyncing = false;
      httpClient.close();
    }
  }

  /// Downloads and restores the SQLite database from Google Drive appDataFolder
  Future<DateTime> restoreFromDrive() async {
    if (_currentUser == null) {
      await signInSilently();
      if (_currentUser == null) {
        throw Exception(
          'Account Google non collegato. Effettua l\'accesso con Google per ripristinare.',
        );
      }
    }

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw Exception('Impossibile ottenere l\'autorizzazione Google Drive.');
    }

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
      if (files == null || files.isEmpty) {
        throw Exception(
          'Nessun file di backup trovato su Google Drive per questo account. Esegui prima un "Backup Ora".',
        );
      }

      final fileId = files.first.id!;
      final backupDate = files.first.modifiedTime ?? DateTime.now();

      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      if (bytes.isEmpty) {
        throw Exception('Il file di backup scaricato da Google Drive è vuoto o corrotto.');
      }

      await LocalDatabase.instance.restoreDatabaseFromBytes(bytes);
      return backupDate;
    } catch (e) {
      throw Exception('Errore durante il ripristino da Google Drive: $e');
    } finally {
      isSyncing = false;
      httpClient.close();
    }
  }
}
