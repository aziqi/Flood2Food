import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiApiConfig {
  static String get apiKey => (dotenv.env['OPENROUTER'] ?? '').trim();
  static String get geminiApiKey => (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
  static String get nvidiaApiKey => (dotenv.env['NVIDIA_API_KEY'] ?? '').trim();
  
  static String get baseUrl =>
      (dotenv.env['AI_API_URL'] ??
      'https://openrouter.ai/api/v1/chat/completions').trim();
  static String get nvidiaBaseUrl => 'https://integrate.api.nvidia.com/v1/chat/completions';

  static String get model => (dotenv.env['AI_MODEL'] ?? 'gemini-2.5-flash').trim();
  
  static bool get isConfigured => dotenv.env['OPENROUTER']?.trim().isNotEmpty ?? false;
  static bool get isGeminiConfigured => dotenv.env['GEMINI_API_KEY']?.trim().isNotEmpty ?? false;
  static bool get isNvidiaConfigured => dotenv.env['NVIDIA_API_KEY']?.trim().isNotEmpty ?? false;
}
