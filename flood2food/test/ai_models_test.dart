import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flood2food/services/ai_api_config.dart';
import 'package:flood2food/services/ai_model_service.dart';
import 'package:flood2food/services/ai_api_service.dart';
import 'package:flood2food/models/sensor_data.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    await dotenv.load(fileName: '.env');
  });

  test('Verify API Keys and Cloud Models List', () {
    expect(AiApiConfig.isConfigured, isTrue);
    expect(AiApiConfig.isGeminiConfigured, isTrue);
    expect(AiApiConfig.isNvidiaConfigured, isTrue);

    expect(AiModelService.cloudModels.length, 15);
    final googleModels = AiModelService.cloudModels.where((m) => m.providerName == 'Google AI Studio').toList();
    final nvidiaModels = AiModelService.cloudModels.where((m) => m.providerName == 'NVIDIA NIM').toList();
    final openRouterModels = AiModelService.cloudModels.where((m) => m.providerName == 'OpenRouter').toList();

    expect(googleModels.length, 6);
    expect(nvidiaModels.length, 3);
    expect(openRouterModels.length, 6);
  });

  test('Gemini Chat Stream Works', () async {
    final geminiModel = AiModelService.cloudModels.firstWhere((m) => m.id == 'cloud_gemini_2_5_flash');
    await AiModelService.setActiveModel(geminiModel);
    final stream = AiApiService.chatWithAiStream([
      {'role': 'user', 'content': 'Halo Bimo, jawab satu kata: Bimo'}
    ], null);
    final buffer = StringBuffer();
    await for (var chunk in stream) {
      buffer.write(chunk);
    }
    expect(buffer.toString().trim(), isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('NVIDIA NIM Chat Stream Works', () async {
    final nvidiaModel = AiModelService.cloudModels.firstWhere((m) => m.id == 'cloud_nvidia_llama_3_2_11b_vision');
    await AiModelService.setActiveModel(nvidiaModel);
    final nvStream = AiApiService.chatWithAiStream([
      {'role': 'user', 'content': 'Halo Bimo, jawab satu kata: Bimo'}
    ], null);
    final nvBuffer = StringBuffer();
    await for (var chunk in nvStream) {
      nvBuffer.write(chunk);
    }
    expect(nvBuffer.toString().trim(), isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('Gemini Task Generation Works', () async {
    final geminiModel = AiModelService.cloudModels.firstWhere((m) => m.id == 'cloud_gemini_2_5_flash');
    await AiModelService.setActiveModel(geminiModel);
    final sampleData = SensorData(
      temperature: 28.5,
      humidity: 50.0,
      ph: 6.2,
      ec: 800,
      nitrogen: 85,
      phosphorus: 20,
      kalium: 150,
    );
    final tasks = await AiApiService.generateTasks(sampleData);
    expect(tasks, isNotEmpty);
    for (var t in tasks) {
      expect(t.title, isNotEmpty);
      expect(t.description, isNotEmpty);
    }
  }, timeout: const Timeout(Duration(seconds: 40)));
}
