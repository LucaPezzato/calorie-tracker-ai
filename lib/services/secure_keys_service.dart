import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/nutrition_models.dart';

class SecureKeysService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _geminiKeyName = 'ai_api_key_gemini';
  static const _openaiKeyName = 'ai_api_key_openai';

  Future<String?> getApiKey(AiProviderType provider) async {
    final key = provider == AiProviderType.gemini
        ? _geminiKeyName
        : _openaiKeyName;
    return _storage.read(key: key);
  }

  Future<void> saveApiKey(AiProviderType provider, String apiKey) async {
    final key = provider == AiProviderType.gemini
        ? _geminiKeyName
        : _openaiKeyName;
    await _storage.write(key: key, value: apiKey.trim());
  }
}
