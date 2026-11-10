import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/nutrition_models.dart';

class SecureKeysService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  static const _geminiKeyName = 'ai_api_key_gemini';
  static const _openaiKeyName = 'ai_api_key_openai';

  /// Remove any invisible whitespace, quotes, or newlines when pasting on mobile
  static String sanitizeKey(String raw) {
    return raw.trim().replaceAll(RegExp(r'[\s"\x27]'), '');
  }

  Future<File> _fallbackFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, '.ai_keys_store.json'));
  }

  Future<Map<String, String>> _readFallbackMap() async {
    try {
      final file = await _fallbackFile();
      if (!file.existsSync()) return {};
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeFallbackMap(Map<String, String> map) async {
    try {
      final file = await _fallbackFile();
      await file.writeAsString(jsonEncode(map), flush: true);
    } catch (_) {}
  }

  Future<String?> getApiKey(AiProviderType provider) async {
    final key = provider == AiProviderType.gemini
        ? _geminiKeyName
        : _openaiKeyName;
    try {
      final val = await _storage.read(key: key);
      if (val != null && val.trim().isNotEmpty) {
        return sanitizeKey(val);
      }
    } catch (_) {
      // Fallback to local support directory if Android Keystore fails
    }
    final fallbackMap = await _readFallbackMap();
    final fallback = fallbackMap[key];
    return fallback != null && fallback.isNotEmpty
        ? sanitizeKey(fallback)
        : null;
  }

  Future<void> saveApiKey(AiProviderType provider, String apiKey) async {
    final key = provider == AiProviderType.gemini
        ? _geminiKeyName
        : _openaiKeyName;
    final cleaned = sanitizeKey(apiKey);
    try {
      await _storage.write(key: key, value: cleaned);
    } catch (_) {
      // Ignore keystore error and rely on fallback below
    }
    final fallbackMap = await _readFallbackMap();
    fallbackMap[key] = cleaned;
    await _writeFallbackMap(fallbackMap);
  }

  Future<void> deleteApiKey(AiProviderType provider) async {
    final key = provider == AiProviderType.gemini
        ? _geminiKeyName
        : _openaiKeyName;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    final fallbackMap = await _readFallbackMap();
    fallbackMap.remove(key);
    await _writeFallbackMap(fallbackMap);
  }
}
