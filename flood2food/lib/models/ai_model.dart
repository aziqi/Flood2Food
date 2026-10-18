enum AiModelType { cloud, local }

class AiModel {
  final String id;
  final String name;
  final String description;
  final AiModelType type;
  // For cloud models
  final String? cloudModelId;
  // For local models
  final String? downloadUrl;
  final double? fileSizeGb;
  final String? localFileName;

  const AiModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.cloudModelId,
    this.downloadUrl,
    this.fileSizeGb,
    this.localFileName,
  });

  String get providerName {
    if (type == AiModelType.local) return 'Lokal (Perangkat)';
    if (id.startsWith('cloud_gemini') || id.startsWith('cloud_gemma') || cloudModelId?.startsWith('gemini-') == true) {
      return 'Google AI Studio';
    }
    if (id.startsWith('cloud_nvidia')) return 'NVIDIA NIM';
    return 'OpenRouter';
  }

  String get assetIconPath {
    if (type == AiModelType.local) return 'assets/local_ai.png';
    if (id.startsWith('cloud_gemini') || id.startsWith('cloud_gemma')) return 'assets/google_ai.png';
    if (id.startsWith('cloud_nvidia')) return 'assets/nvidia_nim.png';
    if (id.startsWith('cloud_openrouter')) return 'assets/openrouter.png';
    return 'assets/local_ai.png';
  }
}
