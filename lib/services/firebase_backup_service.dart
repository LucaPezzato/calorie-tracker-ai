import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/local_database.dart';

class FirebaseBackupService {
  bool _isInitialized = false;
  bool isSyncing = false;
  DateTime? lastBackupTime;
  Timer? _debounceTimer;

  bool get isInitialized => _isInitialized;
  User? get currentUser => _isInitialized ? FirebaseAuth.instance.currentUser : null;

  /// Safely initialize Firebase without hard-crashing if config is pending
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isInitialized = true;
      return true;
    } catch (_) {
      _isInitialized = false;
      return false;
    }
  }

  /// Sign in with Google Account (standard email/profile scope - ZERO sensitive Google review required!)
  Future<User?> signInWithGoogle() async {
    final ready = await initialize();
    if (!ready) {
      throw Exception('Inizializzazione Firebase fallita.');
    }

    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception('Errore Firebase Auth (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Errore accesso Google: $e');
    }
  }

  /// Sign in anonymously (instant cloud backup without linking an email)
  Future<User?> signInAnonymously() async {
    final ready = await initialize();
    if (!ready) {
      throw Exception('Inizializzazione Firebase fallita.');
    }

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'admin-restricted-operation' || e.code == 'operation-not-allowed') {
        throw Exception(
          'L\'accesso anonimo non è abilitato nel progetto Firebase. Vai su Firebase Console -> Authentication -> Sign-in method e abilita "Anonimo".',
        );
      }
      throw Exception('Errore Firebase (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Errore accesso anonimo: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (!_isInitialized) return;
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// Upload SQLite database file compressed with GZip to user's private Firestore document
  /// users/{uid}/backup/database
  Future<bool> uploadBackup() async {
    final user = currentUser;
    if (user == null || !_isInitialized || isSyncing) return false;

    isSyncing = true;
    try {
      final dbFile = await LocalDatabase.instance.prepareDatabaseFileForBackup();
      if (!await dbFile.exists()) return false;

      final rawBytes = await dbFile.readAsBytes();
      final compressedBytes = gzip.encode(rawBytes);

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('backup')
          .doc('database');

      await docRef.set({
        'updatedAt': FieldValue.serverTimestamp(),
        'uncompressedBytes': rawBytes.length,
        'compressedBytes': compressedBytes.length,
        'data': Blob(Uint8List.fromList(compressedBytes)),
      });

      lastBackupTime = DateTime.now();
      return true;
    } catch (_) {
      return false;
    } finally {
      isSyncing = false;
    }
  }

  /// Fetch latest backup metadata (date) from Firestore
  Future<DateTime?> getLatestBackupDate() async {
    final user = currentUser;
    if (user == null || !_isInitialized) return null;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('backup')
          .doc('database');

      final snap = await docRef.get();
      if (!snap.exists || snap.data() == null) return null;

      final data = snap.data()!;
      if (data['updatedAt'] is Timestamp) {
        return (data['updatedAt'] as Timestamp).toDate();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Restore SQLite database from Firestore
  Future<bool> restoreBackup() async {
    final user = currentUser;
    if (user == null || !_isInitialized || isSyncing) return false;

    isSyncing = true;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('backup')
          .doc('database');

      final snap = await docRef.get();
      if (!snap.exists || snap.data() == null) return false;

      final data = snap.data()!;
      final blob = data['data'];
      if (blob is! Blob) return false;

      final decompressedBytes = gzip.decode(blob.bytes);
      await LocalDatabase.instance.restoreDatabaseFromBytes(decompressedBytes);
      return true;
    } catch (_) {
      return false;
    } finally {
      isSyncing = false;
    }
  }

  /// Debounced auto-backup on mutations (runs after 15 seconds of inactivity)
  void scheduleAutoBackup() {
    if (currentUser == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 15), () {
      uploadBackup();
    });
  }
}
