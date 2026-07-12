import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_chat_session.dart';

class AiChatHistoryService {
  static const String _key = 'ai_chat_sessions';

  static Future<List<AiChatSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => AiChatSession.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveSession(AiChatSession session) async {
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.insert(0, session);
    }
    await _saveAll(sessions);
  }

  static Future<void> deleteSession(String id) async {
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == id);
    await _saveAll(sessions);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _saveAll(List<AiChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
