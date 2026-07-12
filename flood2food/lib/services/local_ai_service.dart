import 'package:llamadart/llamadart.dart';
import 'ai_model_service.dart';
import '../models/ai_model.dart';

class LocalAiService {
  static LlamaEngine? _engine;
  static String? _loadedModelPath;
  static bool _isStopped = false;

  static Stream<String> chatStream(
    List<Map<String, String>> messages,
    AiModel model,
  ) async* {
    _isStopped = false;
    final modelPath = await AiModelService.getLocalModelPath(model);
    if (modelPath == null) {
      throw Exception('Model tidak ditemukan. Silakan unduh dulu.');
    }

    // Reload jika model berbeda
    if (_loadedModelPath != modelPath || _engine == null) {
      if (_engine != null) {
        await _engine!.dispose();
      }
      _engine = LlamaEngine(LlamaBackend());
      await _engine!.loadModel(modelPath);
      _loadedModelPath = modelPath;
    }

    // Buat prompt dari semua pesan
    final promptBuffer = StringBuffer();
    for (final msg in messages) {
      if (msg['role'] == 'system') {
        promptBuffer.write('${msg['content']}\n\n');
      } else if (msg['role'] == 'user') {
        promptBuffer.write('User: ${msg['content']}\n');
      } else if (msg['role'] == 'assistant') {
        promptBuffer.write('AI: ${msg['content']}\n');
      }
    }
    promptBuffer.write('AI:');

    await for (final token in _engine!.generate(promptBuffer.toString())) {
      if (_isStopped) break;
      yield token;
    }
  }

  static void stop() {
    _isStopped = true;
  }

  static Future<void> dispose() async {
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      _loadedModelPath = null;
    }
  }
}
