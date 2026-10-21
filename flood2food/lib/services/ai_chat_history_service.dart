import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_chat_session.dart';

class AiChatHistoryService {
  static const String _key = 'ai_chat_sessions';

  static Future<List<AiChatSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        if (list.isNotEmpty) {
          return list.map((e) => AiChatSession.fromJson(e as Map<String, dynamic>)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
      } catch (e) {
        // Fall back to seed demo session
      }
    }

    final defaultSession = AiChatSession(
      id: 'demo_flood2food_agronomy',
      title: 'Konsultasi Nutrisi Lahan Banjir',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      messages: [
        {
          'role': 'user',
          'content': 'Bagaimana status hara tanah petak sawah pasca genangan air dan apa rekomendasi pemupukan presisinya?'
        },
        {
          'role': 'assistant',
          'content': 'Halo Pak Tani! Berdasarkan integrasi telemetri sensor IoT Flood2Food di petak sawah Anda saat ini:\n\n'
              '| Parameter | Nilai Sensor | Standar Ideal | Status |\n'
              '| :--- | :--- | :--- | :--- |\n'
              '| **Nitrogen (N)** | 37.3 mg/kg | 40 - 60 mg/kg | 🟡 Agak Rendah (Pencucian) |\n'
              '| **Fosfor (P)** | 19.0 mg/kg | 15 - 25 mg/kg | 🟢 Optimal |\n'
              '| **Kalium (K)** | 154.8 mg/kg | 120 - 180 mg/kg | 🟢 Sangat Baik |\n'
              '| **pH Tanah** | 6.55 | 6.0 - 7.0 | 🟢 Netral Ideal |\n'
              '| **Konduktivitas (EC)** | 1.30 mS/cm | 1.0 - 2.0 mS/cm | 🟢 Normal |\n\n'
              '### 🌾 Rekomendasi Tindakan Agronomis:\n'
              '1. **Aplikasi Urea Susulan Ringan**: Taburkan pupuk Urea sebanyak **35 kg/ha** untuk menggantikan unsur Nitrogen yang hanyut tergenang air.\n'
              '2. **Pengaturan Pintu Air Lahan**: Turunkan muka genangan air sawah hingga 3-5 cm agar sirkulasi oksigen perakaran pulih normal.\n'
              '3. **Semprot Silika Cair**: Untuk memperkokoh batang tanaman padi agar tahan rebah terpaan cuaca ekstrem.\n\n'
              '💡 *Sistem telemetri mendeteksi pemulihan hara tanah berjalan sangat baik dengan skor kesehatan tanaman 88/100.*'
        }
      ],
    );
    return [defaultSession];
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
