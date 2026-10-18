import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';
import 'package:flutter/foundation.dart';

class AiModelService {
  static const String _activeModelKey = 'active_ai_model_id_v4';
  static const String _defaultModelId = 'cloud_gemini_2_5_flash';

  // =========================================================
  // Daftar Model Cloud - 100% Gratis & Chat-Capable (Terverifikasi)
  // =========================================================
  static const List<AiModel> cloudModels = [
    // -------------------------------------------------------
    // Google AI Studio (Free Tier)
    // -------------------------------------------------------
    AiModel(
      id: 'cloud_gemini_2_5_flash',
      name: 'Google Gemini 2.5 Flash',
      description: 'Model resmi Google AI Studio yang super cepat, stabil, dan responsif.',
      type: AiModelType.cloud,
      cloudModelId: 'gemini-2.5-flash',
    ),
    AiModel(
      id: 'cloud_gemini_3_5_flash',
      name: 'Google Gemini 3.5 Flash',
      description: 'Generasi terbaru Gemini 3.5 Flash untuk penalaran tinggi.',
      type: AiModelType.cloud,
      cloudModelId: 'gemini-3.5-flash',
    ),
    AiModel(
      id: 'cloud_gemini_3_1_flash_lite',
      name: 'Google Gemini 3.1 Flash Lite',
      description: 'Model efisien dan hemat kuota dengan latensi sangat rendah.',
      type: AiModelType.cloud,
      cloudModelId: 'gemini-3.1-flash-lite',
    ),
    AiModel(
      id: 'cloud_gemini_3_flash_preview',
      name: 'Google Gemini 3 Flash Preview',
      description: 'Preview generasi Gemini 3 Flash dari Google.',
      type: AiModelType.cloud,
      cloudModelId: 'gemini-3-flash-preview',
    ),
    AiModel(
      id: 'cloud_gemini_flash_latest',
      name: 'Google Gemini Flash Latest',
      description: 'Alias dinamis yang selalu mengarah ke versi Flash paling mutakhir.',
      type: AiModelType.cloud,
      cloudModelId: 'gemini-flash-latest',
    ),
    AiModel(
      id: 'cloud_gemma_4_26b_a4b_it',
      name: 'Google Gemma 4 26B A4B IT',
      description: 'Model open-weight generasi 4 instruksi buatan Google.',
      type: AiModelType.cloud,
      cloudModelId: 'gemma-4-26b-a4b-it',
    ),

    // -------------------------------------------------------
    // NVIDIA NIM (Developer Free Tier)
    // -------------------------------------------------------
    AiModel(
      id: 'cloud_nvidia_llama_3_2_11b_vision',
      name: 'Meta Llama 3.2 11B Vision (NVIDIA)',
      description: 'Model multimodal vision dan teks canggih dari Meta via akselerasi NVIDIA NIM.',
      type: AiModelType.cloud,
      cloudModelId: 'meta/llama-3.2-11b-vision-instruct',
    ),
    AiModel(
      id: 'cloud_nvidia_nemotron_3_ultra_550b',
      name: 'Nemotron 3 Ultra 550B (NVIDIA)',
      description: 'Model super masif 550B buatan NVIDIA untuk analisis mendalam.',
      type: AiModelType.cloud,
      cloudModelId: 'nvidia/nemotron-3-ultra-550b-a55b',
    ),
    AiModel(
      id: 'cloud_nvidia_nemotron_3_nano_omni',
      name: 'Nemotron 3 Nano Omni 30B (NVIDIA)',
      description: 'Model reasoning dan penalaran cerdas berkecepatan tinggi dari NVIDIA.',
      type: AiModelType.cloud,
      cloudModelId: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning',
    ),

    // -------------------------------------------------------
    // OpenRouter (100% Free / :free)
    // -------------------------------------------------------
    AiModel(
      id: 'cloud_openrouter_free',
      name: 'Auto (Model Gratis Terbaik)',
      description: 'Otomatis memilih model gratis terbaik yang tersedia saat ini di OpenRouter.',
      type: AiModelType.cloud,
      cloudModelId: 'openrouter/free',
    ),
    AiModel(
      id: 'cloud_openrouter_gemma_4_31b_free',
      name: 'Google Gemma 4 31B (OpenRouter Free)',
      description: 'Model open-weight 31B generasi terbaru dari Google gratis di OpenRouter.',
      type: AiModelType.cloud,
      cloudModelId: 'google/gemma-4-31b-it:free',
    ),
    AiModel(
      id: 'cloud_openrouter_nemotron_ultra_free',
      name: 'Nemotron 3 Ultra 550B (OpenRouter Free)',
      description: 'Model 550B super masif dari NVIDIA gratis di OpenRouter.',
      type: AiModelType.cloud,
      cloudModelId: 'nvidia/nemotron-3-ultra-550b-a55b:free',
    ),
    AiModel(
      id: 'cloud_openrouter_nemotron_super_free',
      name: 'Nemotron 3 Super 120B (OpenRouter Free)',
      description: 'Model 120B berkecepatan tinggi dari NVIDIA gratis di OpenRouter.',
      type: AiModelType.cloud,
      cloudModelId: 'nvidia/nemotron-3-super-120b-a12b:free',
    ),
    AiModel(
      id: 'cloud_openrouter_nemotron_super_vl_free',
      name: 'Nemotron 3.5 Super VL (OpenRouter Free)',
      description: 'Model multimodal 3.5 Super VL gratis di OpenRouter.',
      type: AiModelType.cloud,
      cloudModelId: 'nvidia/nemotron-3.5-super-vl:free',
    ),
    AiModel(
      id: 'cloud_openrouter_liquid_lfm_free',
      name: 'LiquidAI LFM 2.5 2.6B (OpenRouter Free)',
      description: 'Model efisien dan ringan buatan Liquid AI gratis di OpenRouter.',
      type: AiModelType.cloud,
      cloudModelId: 'liquid/lfm-2.5-2.6b:free',
    ),
  ];

  // =========================================================
  // Daftar Model Lokal (Offline - GGUF)
  // =========================================================
  static const List<AiModel> localModels = [
    AiModel(
      id: 'local_llama3_1b',
      name: 'Llama 3.2 1B (Ringan)',
      description: 'Cocok untuk HP low-end. Cepat tapi kualitas standar.',
      type: AiModelType.local,
      downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      fileSizeGb: 0.8,
      localFileName: 'llama3.2-1b.gguf',
    ),
    AiModel(
      id: 'local_llama3_3b',
      name: 'Llama 3.2 3B (Seimbang)',
      description: 'Keseimbangan terbaik antara kecepatan dan kualitas. Rekomendasi!',
      type: AiModelType.local,
      downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      fileSizeGb: 2.0,
      localFileName: 'llama3.2-3b.gguf',
    ),
    AiModel(
      id: 'local_mistral_7b',
      name: 'Mistral 7B (Kuat)',
      description: 'Kualitas terbaik untuk HP bertenaga. Perlu ~4.5 GB storage.',
      type: AiModelType.local,
      downloadUrl: 'https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf',
      fileSizeGb: 4.5,
      localFileName: 'mistral-7b.gguf',
    ),
    AiModel(
      id: 'local_gemma2_2b',
      name: 'Gemma 2 2B Abliterated',
      description: 'Model uncensored ringan, cocok untuk HP dengan RAM 4 GB.',
      type: AiModelType.local,
      downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-abliterated-GGUF/resolve/main/gemma-2-2b-it-abliterated-Q4_K_M.gguf',
      fileSizeGb: 1.6,
      localFileName: 'gemma-2-2b-abliterated.gguf',
    ),
    AiModel(
      id: 'local_gemma_4_e4b',
      name: 'Gemma 4 E4B Heretic',
      description: 'Kualitas uncensored yang sangat baik untuk HP bertenaga. Perlu Min 8 GB RAM.',
      type: AiModelType.local,
      downloadUrl: 'https://huggingface.co/MoonRide/gemma-4-E4B-it-heretic-ara-GGUF/resolve/main/gemma-4-E4B-it-heretic-ara-Q4_K_M.gguf',
      fileSizeGb: 5.3,
      localFileName: 'gemma-4-e4b-heretic.gguf',
    ),
    AiModel(
      id: 'local_dolphin_llama3_8b',
      name: 'Dolphin 2.9 Llama 3 8B',
      description: 'Model uncensored yang sangat populer dengan penalaran tingkat lanjut. Perlu Min 8 GB RAM.',
      type: AiModelType.local,
      downloadUrl: 'https://huggingface.co/bartowski/dolphin-2.9-llama3-8b-GGUF/resolve/main/dolphin-2.9-llama3-8b-Q4_K_M.gguf',
      fileSizeGb: 4.9,
      localFileName: 'dolphin-2.9-llama3-8b.gguf',
    ),
    AiModel(
      id: 'local_phi_3_5_mini',
      name: 'Phi-3.5 Mini 3.8B',
      description: 'Model standar yang sangat efisien dan ringan. Perlu Min 4 GB RAM.',
      type: AiModelType.local,
      downloadUrl: 'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      fileSizeGb: 2.2,
      localFileName: 'phi-3.5-mini.gguf',
    ),
  ];

  // =========================================================
  // Metode Utilitas
  // =========================================================

  static AiModel get defaultModel => cloudModels.first;

  static final ValueNotifier<AiModel?> activeModelNotifier = ValueNotifier(null);

  static Future<AiModel> getActiveModel() async {
    if (activeModelNotifier.value != null) return activeModelNotifier.value!;
    
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeModelKey) ?? _defaultModelId;
    final allModels = [...cloudModels, ...localModels];
    final model = allModels.firstWhere((m) => m.id == activeId, orElse: () => defaultModel);
    
    activeModelNotifier.value = model;
    return model;
  }

  static Future<void> setActiveModel(AiModel model) async {
    activeModelNotifier.value = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeModelKey, model.id);
  }

  static Future<String> get modelsDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/ai_models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  static Future<bool> isModelDownloaded(AiModel model) async {
    if (model.type != AiModelType.local) return false;
    final dirPath = await modelsDirectory;
    final file = File('$dirPath/${model.localFileName}');
    return file.exists();
  }

  static Future<String?> getLocalModelPath(AiModel model) async {
    final dirPath = await modelsDirectory;
    final filePath = '$dirPath/${model.localFileName}';
    final file = File(filePath);
    return (await file.exists()) ? filePath : null;
  }

  static Future<void> deleteLocalModel(AiModel model) async {
    final dirPath = await modelsDirectory;
    final file = File('$dirPath/${model.localFileName}');
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> downloadModel({
    required AiModel model,
    required Function(double progress, double downloadedGb) onProgress,
    required CancelToken cancelToken,
  }) async {
    if (model.downloadUrl == null || model.localFileName == null) return;
    final dirPath = await modelsDirectory;
    final savePath = '$dirPath/${model.localFileName}';

    final dio = Dio();
    await dio.download(
      model.downloadUrl!,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = received / total;
          final downloadedGb = received / (1024 * 1024 * 1024);
          onProgress(progress, downloadedGb);
        }
      },
    );
  }
}
