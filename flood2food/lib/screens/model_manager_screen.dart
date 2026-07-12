import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/ai_model.dart';
import '../services/ai_model_service.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AiModel? _activeModel;
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloaded = {};
  final Map<String, CancelToken> _cancelTokens = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadState();
  }

  Future<void> _loadState() async {
    final active = await AiModelService.getActiveModel();
    final downloadedMap = <String, bool>{};
    for (final m in AiModelService.localModels) {
      downloadedMap[m.id] = await AiModelService.isModelDownloaded(m);
    }
    if (mounted) {
      setState(() {
        _activeModel = active;
        _isDownloaded.addAll(downloadedMap);
      });
    }
  }

  Future<void> _activateModel(AiModel model) async {
    await AiModelService.setActiveModel(model);
    setState(() => _activeModel = model);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Model "${model.name}" diaktifkan!'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  Future<void> _downloadModel(AiModel model) async {
    final cancelToken = CancelToken();
    _cancelTokens[model.id] = cancelToken;
    setState(() => _downloadProgress[model.id] = 0.0);

    try {
      await AiModelService.downloadModel(
        model: model,
        cancelToken: cancelToken,
        onProgress: (progress, downloadedGb) {
          if (mounted) {
            setState(() => _downloadProgress[model.id] = progress);
          }
        },
      );
      if (mounted) {
        setState(() {
          _isDownloaded[model.id] = true;
          _downloadProgress.remove(model.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model "${model.name}" berhasil diunduh!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(model.id));
        if (e is! DioException || e.type != DioExceptionType.cancel) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengunduh: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteModel(AiModel model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Model?'),
        content: Text('Hapus file model "${model.name}" dari penyimpanan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AiModelService.deleteLocalModel(model);
      setState(() => _isDownloaded[model.id] = false);
      // Jika model yang dihapus sedang aktif, reset ke default
      if (_activeModel?.id == model.id) {
        await _activateModel(AiModelService.defaultModel);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Model AI'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.cloud), text: 'Cloud (Online)'),
            Tab(icon: Icon(Icons.offline_bolt), text: 'Lokal (Offline)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCloudTab(),
          _buildLocalTab(),
        ],
      ),
    );
  }

  Widget _buildCloudTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Model Cloud membutuhkan koneksi internet dan API Key.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Google AI Studio',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ...AiModelService.cloudModels
            .where((m) => m.id.startsWith('cloud_gemini') || m.id.startsWith('cloud_gemma'))
            .map((m) => _buildModelCard(
                  model: m,
                  isActive: _activeModel?.id == m.id,
                  trailing: _activeModel?.id == m.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _activateModel(m),
                          child: const Text('Pilih'),
                        ),
                )),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'NVIDIA NIM',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
        ...AiModelService.cloudModels
            .where((m) => m.id.startsWith('cloud_nvidia'))
            .map((m) => _buildModelCard(
                  model: m,
                  isActive: _activeModel?.id == m.id,
                  trailing: _activeModel?.id == m.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _activateModel(m),
                          child: const Text('Pilih'),
                        ),
                )),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'OpenRouter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ),
        ...AiModelService.cloudModels
            .where((m) => m.id.startsWith('cloud_openrouter'))
            .map((m) => _buildModelCard(
                  model: m,
                  isActive: _activeModel?.id == m.id,
                  trailing: _activeModel?.id == m.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _activateModel(m),
                          child: const Text('Pilih'),
                        ),
                )),
      ],
    );
  }

  Widget _buildLocalTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Model Lokal berjalan 100% offline. File berukuran besar (0.8–4.5 GB). Pastikan memiliki storage yang cukup.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...AiModelService.localModels.map((m) {
          final isDownloaded = _isDownloaded[m.id] ?? false;
          final isActive = _activeModel?.id == m.id;
          final progress = _downloadProgress[m.id];
          final isDownloading = progress != null;

          return _buildModelCard(
            model: m,
            isActive: isActive,
            subtitle: '${m.fileSizeGb} GB',
            trailing: isDownloading
                ? SizedBox(
                    width: 110,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mengunduh', style: TextStyle(fontSize: 10, color: Colors.blue)),
                            Text('${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.blue.withValues(alpha: 0.2),
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            _cancelTokens[m.id]?.cancel();
                            setState(() => _downloadProgress.remove(m.id));
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                            child: Text('Batalkan', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  )
                : isDownloaded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isActive)
                            ElevatedButton(
                              onPressed: () => _activateModel(m),
                              child: const Text('Aktifkan'),
                            )
                          else
                            const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteModel(m),
                          ),
                        ],
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _downloadModel(m),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Unduh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
          );
        }),
      ],
    );
  }

  Widget _buildModelCard({
    required AiModel model,
    required bool isActive,
    String? subtitle,
    required Widget trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary.withValues(alpha: 0.1) : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? colorScheme.primary.withValues(alpha: 0.5) : colorScheme.onSurface.withValues(alpha: 0.1),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(model.assetIconPath, width: 36, height: 36, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isActive)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('AKTIF', style: TextStyle(color: colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    Flexible(
                      child: Text(
                        model.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    'Provider: ${model.providerName}',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                Text(model.description,
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text('Ukuran: $subtitle',
                      style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final ct in _cancelTokens.values) {
      ct.cancel();
    }
    super.dispose();
  }
}
