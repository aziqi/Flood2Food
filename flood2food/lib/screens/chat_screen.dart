import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import '../bloc/sensor/sensor_bloc.dart';
import '../services/ai_api_service.dart';
import '../services/ai_model_service.dart';
import '../services/ai_chat_history_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/ai_model.dart';
import '../models/ai_chat_session.dart';
import '../widgets/app_drawer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  bool _isGenerating = false;
  final ScrollController _scrollController = ScrollController();

  AiChatSession _currentSession = AiChatSession();
  List<AiChatSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final sessions = await AiChatHistoryService.getSessions();

    if (mounted) {
      setState(() {
        _sessions = sessions;
        if (sessions.isNotEmpty) {
          _currentSession = sessions.first;
        } else {
          _sessions.add(_currentSession);
        }
      });
    }
  }

  void _createNewSession() {
    setState(() {
      _currentSession = AiChatSession();
      _sessions.insert(0, _currentSession);
    });
    AiChatHistoryService.saveSession(_currentSession);
    Navigator.pop(context); // close drawer
  }

  void _switchSession(AiChatSession session) {
    setState(() {
      _currentSession = session;
    });
    Navigator.pop(context); // close drawer
    _scrollToBottom();
  }

  void _deleteSession(AiChatSession session) async {
    await AiChatHistoryService.deleteSession(session.id);
    final updated = await AiChatHistoryService.getSessions();
    setState(() {
      _sessions = updated;
      if (_currentSession.id == session.id) {
        _currentSession = updated.isNotEmpty ? updated.first : AiChatSession();
        if (updated.isEmpty) _sessions.add(_currentSession);
      }
    });
  }

  void _sendMessage([String? overrideText]) async {
    final text = overrideText ?? _controller.text.trim();
    if (text.isEmpty) return;

    if (overrideText == null) {
      _controller.clear();
      setState(() {
        _currentSession.messages.add({'role': 'user', 'content': text});
      });
    }

    setState(() {
      _currentSession.messages.add({'role': 'assistant', 'content': ''});
      _isLoading = true;
      _isGenerating = true;
    });

    // update title if first user message
    if (_currentSession.messages.length <= 2 &&
        _currentSession.title == 'Obrolan Baru') {
      _currentSession.title = text.length > 25
          ? '${text.substring(0, 25)}...'
          : text;
    }
    AiChatHistoryService.saveSession(_currentSession);
    _scrollToBottom();

    final sensorData = context.read<SensorBloc>().state.latestData;

    try {
      final stream = AiApiService.chatWithAiStream(
        _currentSession.messages.sublist(
          0,
          _currentSession.messages.length - 1,
        ),
        sensorData,
      );
      await for (final chunk in stream) {
        if (!mounted) break;
        setState(() {
          _isLoading = false;
          _currentSession.messages.last['content'] =
              (_currentSession.messages.last['content'] ?? '') + chunk;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentSession.messages.last['content'] =
            'Maaf, terjadi kesalahan: $e';
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        AiChatHistoryService.saveSession(_currentSession);
      }
    }
  }

  void _regenerateLast() {
    if (_isGenerating || _currentSession.messages.isEmpty) return;

    // find last user message
    final lastUserIndex = _currentSession.messages.lastIndexWhere(
      (m) => m['role'] == 'user',
    );
    if (lastUserIndex == -1) return;

    final text = _currentSession.messages[lastUserIndex]['content'];

    setState(() {
      // remove everything after last user message
      _currentSession.messages.removeRange(
        lastUserIndex + 1,
        _currentSession.messages.length,
      );
    });

    _sendMessage(text);
  }

  void _stopGeneration() {
    AiApiService.stopAi();
    setState(() => _isGenerating = false);
    AiChatHistoryService.saveSession(_currentSession);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showModelSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;


        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.psychology_rounded, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Pilih Otak AI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _buildModelGroupCard(
                      context,
                      title: 'Google AI Studio',
                      icon: Icons.auto_awesome,
                      color: Colors.blue,
                      models: AiModelService.cloudModels.where((m) => m.id.startsWith('cloud_gemini') || m.id.startsWith('cloud_gemma')).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildModelGroupCard(
                      context,
                      title: 'NVIDIA NIM',
                      icon: Icons.memory,
                      color: Colors.green,
                      models: AiModelService.cloudModels.where((m) => m.id.startsWith('cloud_nvidia')).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildModelGroupCard(
                      context,
                      title: 'OpenRouter',
                      icon: Icons.hub_rounded,
                      color: Colors.purple,
                      models: AiModelService.cloudModels.where((m) => m.id.startsWith('cloud_openrouter')).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildModelGroupCard(
                      context,
                      title: 'Lokal (Offline)',
                      icon: Icons.dns_rounded,
                      color: Colors.orange,
                      models: AiModelService.localModels,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModelGroupCard(BuildContext context, {required String title, required IconData icon, required Color color, required List<AiModel> models}) {
    if (models.isEmpty) return const SizedBox.shrink();
    
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ...models.map((model) {
            final isActive = AiModelService.activeModelNotifier.value?.id == model.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Material(
                color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await AiModelService.setActiveModel(model);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Image.asset(model.assetIconPath, width: 24, height: 24, fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.name,
                                style: TextStyle(
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                model.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(Icons.check_circle_rounded, color: color),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      endDrawer: _buildHistoryDrawer(),
      appBar: AppBar(
        title: const Text('Tanya Bimo (AI)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ValueListenableBuilder<AiModel?>(
              valueListenable: AiModelService.activeModelNotifier,
              builder: (context, activeModel, _) {
                if (activeModel == null) {
                  return const SizedBox.shrink();
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(activeModel.assetIconPath, width: 14, height: 14, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeModel.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_rounded),
            onPressed: _showModelSelector,
            tooltip: 'Ganti Model AI',
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Riwayat Obrolan',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentSession.messages.isEmpty
                ? const Center(
                    child: Text(
                      'Tanyakan sesuatu tentang tanaman Anda!\nAI sudah terhubung dengan sensor tanah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _currentSession.messages.length,
                    itemBuilder: (context, index) {
                      final msg = _currentSession.messages[index];
                      final isUser = msg['role'] == 'user';
                      final isLastAssitant =
                          !isUser &&
                          index == _currentSession.messages.length - 1;

                      return _buildChatBubble(
                        msg['content'] ?? '',
                        isUser,
                        isLastAssitant,
                      );
                    },
                  ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    SizedBox(width: 16),
                    Icon(Icons.auto_awesome, color: colorScheme.primary, size: 20)
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 1200.ms, color: isDark ? Colors.white : colorScheme.primary.withValues(alpha: 0.5))
                        .scaleXY(begin: 0.9, end: 1.1, duration: 600.ms)
                        .then(delay: 600.ms)
                        .scaleXY(begin: 1.1, end: 0.9, duration: 600.ms),
                    const SizedBox(width: 12),
                    const Text(
                      'AI sedang memikirkan...',
                      style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                    ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: isDark ? Colors.white : colorScheme.primary.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: _stopGeneration,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Hentikan'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.red[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          _buildInputBox(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser, bool isLastAssistant) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isUser ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(24),
                      topRight: const Radius.circular(24),
                      bottomLeft: Radius.circular(isUser ? 24 : 8),
                      bottomRight: Radius.circular(isUser ? 8 : 24),
                    ),
                    boxShadow: isUser ? [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ] : null,
                  ),
                  child: isUser
                      ? Text(
                          text,
                          style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w600),
                        )
                      : MarkdownBody(
                          data: text,
                          selectable: true,
                          extensionSet: md.ExtensionSet.gitHubFlavored,
                          builders: {
                            'code': CodeElementBuilder(colorScheme: colorScheme, context: context),
                          },
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(fontSize: 15, height: 1.5, color: colorScheme.onSurface),
                            listBullet: TextStyle(color: colorScheme.onSurface),
                            blockquote: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            ),
                            blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            tableBorder: TableBorder(
                              horizontalInside: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.1), width: 1),
                              bottom: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.1), width: 1),
                              top: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.1), width: 1),
                            ),
                            tableCellsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            tableHead: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            tableBody: TextStyle(color: colorScheme.onSurface),
                            // Inline code styles (fallback if not handled by builder, though builder handles 'code')
                            code: TextStyle(
                              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
                            ),
                          ),
                        ),
                ),
                if (!isUser) // Actions for AI message
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            size: 16,
                            color: Colors.grey,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Disalin ke clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        if (isLastAssistant && !_isGenerating) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              size: 18,
                              color: Colors.grey,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _regenerateLast,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondary.withValues(alpha: 0.2),
              child: Icon(
                Icons.person_rounded,
                size: 18,
                color: colorScheme.secondary,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut).slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildInputBox() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Margin super rapat ke Nav Bar
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32), // Bentuk Pill/Kapsul
            border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12), // Ruang lega sebelum mulai ngetik
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.newline,
                  enabled: !_isGenerating,
                  maxLines: 4,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: _isGenerating ? 'AI sedang merenung...' : 'Ketik sesuatu...',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w400),
                    border: InputBorder.none, // Membuang kotak bawaan
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor: _isGenerating ? colorScheme.onSurface.withValues(alpha: 0.2) : colorScheme.primary,
                child: IconButton(
                  icon: Icon(Icons.send_rounded, color: isDark && !_isGenerating ? const Color(0xFF06231D) : Colors.white, size: 20),
                  onPressed: _isGenerating ? null : () => _sendMessage(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.history_rounded, color: colorScheme.onSecondaryContainer),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Riwayat Obrolan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _createNewSession,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Mulai Obrolan Baru'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      backgroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(),
            ),
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 64,
                            color: colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada riwayat',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final isSelected = session.id == _currentSession.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _switchSession(session),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chat_outlined,
                                      size: 20,
                                      color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        session.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(left: 8, right: 8),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                      color: isSelected ? colorScheme.primary.withValues(alpha: 0.6) : colorScheme.onSurface.withValues(alpha: 0.3),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteSession(session),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final ColorScheme colorScheme;
  final BuildContext context;
  CodeElementBuilder({required this.colorScheme, required this.context});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';
    if (element.attributes['class'] != null) {
      String lgPattern = 'language-';
      if (element.attributes['class']!.startsWith(lgPattern)) {
        language = element.attributes['class']!.substring(lgPattern.length);
      }
    }
    
    // Check if it's an inline code
    if (language.isEmpty && !element.textContent.contains('\n')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          element.textContent,
          style: preferredStyle?.copyWith(fontFamily: 'monospace', fontSize: 14, color: colorScheme.onSurface),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff282c34),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Code Header (Claude-style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black.withValues(alpha: 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.isEmpty ? 'code' : language,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: element.textContent.trimRight()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kode disalin ke clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text('Copy Code', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Code Block
            HighlightView(
              element.textContent.trimRight(),
              language: language.isEmpty ? 'plaintext' : language,
              theme: atomOneDarkTheme,
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

