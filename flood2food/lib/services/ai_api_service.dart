import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_api_config.dart';
import 'ai_model_service.dart';
import 'local_ai_service.dart';
import '../models/sensor_data.dart';
import '../models/daily_task.dart';
import '../models/ai_model.dart';
import 'package:flutter/foundation.dart';

class AiApiService {
  static Future<List<DailyTask>> generateTasks(SensorData data) async {
    final activeModel = await AiModelService.getActiveModel();
    AiModel taskModel = activeModel;
    if (activeModel.type == AiModelType.local) {
      taskModel = AiModelService.cloudModels.firstWhere(
        (m) => m.type == AiModelType.cloud,
        orElse: () => AiModelService.defaultModel,
      );
    }

    final isGemini = taskModel.cloudModelId?.startsWith('gemini-') == true;
    final isNvidia = taskModel.cloudModelId == 'meta/llama-3.1-8b-instruct' || taskModel.cloudModelId == 'meta/llama-3.3-70b-instruct';

    if (isGemini) {
      if (!AiApiConfig.isGeminiConfigured) {
        throw Exception('API Key Gemini belum dikonfigurasi di file .env');
      }
    } else if (isNvidia) {
      if (!AiApiConfig.isNvidiaConfigured) {
        throw Exception('API Key NVIDIA belum dikonfigurasi di file .env');
      }
    } else {
      if (!AiApiConfig.isConfigured) {
        throw Exception('AI API tidak dikonfigurasi. Periksa file .env');
      }
    }

    final taskCount = '3 hingga 5';
    
    final systemPrompt = '''
Anda adalah "Bimo", maskot resmi Flood2Food. Anda berperan sebagai Pakar AI & Principal Engineer, Game Master di aplikasi Flood2Food.
Konteks Master Proyek Flood2Food (PKM-KC):
- Instrumen pemantauan pertanian presisi (Industrial Grade) berbasis ESP32, Sensor NPK 7-in-1 Modbus RS485, transmisi LoRa dan BLE.
- Tujuan Agronomi: Memulihkan lahan sawah pascabanjir dari endapan lumpur, kondisi anaerobik, pH drop, dan racun besi tereduksi.

Tugas Anda saat ini: Buat $taskCount tugas harian (Daily Tasks) berdasarkan data pembacaan sensor tanah pengguna untuk memulihkan kondisi lahan.

Aturan Pembuatan Tugas:
- Bahasa Indonesia yang santai namun profesional dan memotivasi.
- Kategori yang tersedia: watering, fertilizing, pHAdjustment, soilCheck, general
- Tingkat kesulitan: easy, medium, hard
- Hadiah XP: easy=15-20, medium=25-35, hard=40-50
- Hadiah Poin: easy=8-12, medium=15-20, hard=22-28
- PRIORITAS UTAMA: Analisis setiap data sensor. Jika ada nilai yang SANGAT MENYIMPANG dari batas ideal (contoh: pH 0.4 sangat tidak wajar/kritis, NPK sangat rendah, dll), buat tugas-tugas spesifik untuk memperbaiki MASING-MASING parameter tersebut secara bertahap. Jangan hanya memberikan tugas umum jika tanahnya sedang sakit.
- ATURAN KRITIS (WAJIB ADA ANGKA & SATUAN SPESIFIK): Setiap instruksi di `description` HARUS memiliki ukuran pasti. JANGAN PERNAH hanya menyuruh "Siram tanah" atau "Beri pupuk". 
  Contoh BENAR: "Siram dengan 500 ml air", "Taburkan 50 gram pupuk NPK", "Gunakan 100 gram kapur dolomit per meter persegi". 
  Contoh SALAH: "Beri pupuk NPK secukupnya", "Siram tanaman secara merata".
- Set `isDaily` ke true untuk semua tugas.
- Berikan penjelasan medis/agrikultur di `aiReason` mengapa tugas ini di-generate berdasarkan anomali sensor spesifik tersebut.
- Kembalikan format JSON murni.
''';

    final userMessage =
        '''
Current sensor readings:
- Temperature: ${data.temperature.toStringAsFixed(1)} °C (ideal: 25-32 °C)
- Nitrogen (Available N): ${data.nitrogen.toStringAsFixed(1)} mg/kg (ideal: 70-120 mg/kg)
- Phosphorus (Olsen P): ${data.phosphorus.toStringAsFixed(1)} mg/kg (ideal: 15-25 mg/kg)
- Kalium (Exchangeable K): ${data.kalium.toStringAsFixed(1)} mg/kg (ideal: 100-200 mg/kg)
- EC: ${data.ec.toStringAsFixed(2)} mS/cm (ideal: <2.0 mS/cm)
- Kelembapan (VWC): ${data.humidity.toStringAsFixed(1)}% (ideal: 40-60%)
- pH: ${data.ph.toStringAsFixed(1)} (ideal: 5.5-7.0)
- Plant Health Score: ${data.plantHealthScore.toStringAsFixed(0)}/100
- Health Status: ${data.healthStatus}

Generate $taskCount farming/maintenance tasks in JSON format based on these readings. Use this exact structure:
{
  "tasks": [
    {
      "title": "string",
      "description": "string",
      "category": "string (one of: watering, fertilizing, pHAdjustment, soilCheck, general)",
      "difficulty": "string (one of: easy, medium, hard)",
      "xpReward": 20,
      "pointReward": 10,
      "aiReason": "string"
    }
  ]
}''';

    http.Response response;

    if (isGemini) {
      final modelId = taskModel.cloudModelId ?? 'gemini-2.5-flash';
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=${AiApiConfig.geminiApiKey}';
      
      response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': '$systemPrompt\n\n$userMessage'}]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.7,
          }
        }),
      );
    } else {
      final url = isNvidia ? AiApiConfig.nvidiaBaseUrl : AiApiConfig.baseUrl;
      final apiKey = isNvidia ? AiApiConfig.nvidiaApiKey : AiApiConfig.apiKey;
      final defaultModel = isNvidia ? 'meta/llama-3.1-8b-instruct' : AiApiConfig.model;
      
      response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': taskModel.cloudModelId ?? defaultModel,
          'messages': [
            {'role': 'user', 'content': '$systemPrompt\n\n$userMessage'},
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.7,
        }),
      );
    }

    debugPrint(response.body, wrapWidth: 1024);

    if (response.statusCode != 200) {
      throw Exception(
        'AI API request failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    String raw = '';

    if (isGemini) {
      raw = body['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
    } else {
      raw = body['choices']?[0]?['message']?['content'] ?? '';
    }

    if (raw.isEmpty) {
      throw Exception('Invalid API response: no content in message');
    }

    raw = raw.trim();
    String cleaned = raw;
    
    // Cari bracket kurawal pertama dan terakhir untuk mengekstrak murni JSON
    int startIdx = raw.indexOf('{');
    int endIdx = raw.lastIndexOf('}');
    
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      cleaned = raw.substring(startIdx, endIdx + 1);
    }
    
    // Hapus karakter tab/newline liar yang berpotensi merusak jsonDecode
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), ' ');

    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    final tasksJson = parsed['tasks'] as List<dynamic>?;
    if (tasksJson == null) {
      throw Exception('Invalid response format: no tasks array');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return tasksJson.asMap().entries.map((entry) {
      final i = entry.key;
      final t = entry.value as Map<String, dynamic>;
      return DailyTask(
        id: 'ai_${now}_$i',
        title: t['title'] as String? ?? 'Tugas ${i + 1}',
        description: t['description'] as String? ?? '',
        category: _parseCategory(t['category'] as String?),
        difficulty: _parseDifficulty(t['difficulty'] as String?),
        xpReward: t['xpReward'] as int? ?? 20,
        pointReward: t['pointReward'] as int? ?? 10,
        aiReason: t['aiReason'] as String? ?? '',
      );
    }).toList();
  }

  static TaskCategory _parseCategory(String? value) {
    switch (value?.toLowerCase()) {
      case 'watering':
        return TaskCategory.watering;
      case 'fertilizing':
        return TaskCategory.fertilizing;
      case 'phadjustment':
        return TaskCategory.pHAdjustment;
      case 'soilcheck':
        return TaskCategory.soilCheck;
      default:
        return TaskCategory.general;
    }
  }

  static TaskDifficulty _parseDifficulty(String? value) {
    switch (value?.toLowerCase()) {
      case 'easy':
        return TaskDifficulty.easy;
      case 'medium':
        return TaskDifficulty.medium;
      case 'hard':
        return TaskDifficulty.hard;
      default:
        return TaskDifficulty.medium;
    }
  }

  static Stream<String> chatWithAiStream(List<Map<String, String>> chatHistory, SensorData? currentData) async* {
    final activeModel = await AiModelService.getActiveModel();
    
    // Build messages dengan system context
    String systemContext = '''Anda adalah "Bimo", maskot resmi Flood2Food. Anda berperan sebagai Senior Principal Engineer, Pakar IoT, dan Game Master AI yang ramah, cerdas, dan solutif, terintegrasi langsung di aplikasi "Flood2Food" (PKM-KC).

======================================================
[MASTER CONTEXT: DOKUMEN TEKNIS FLOOD2FOOD]
======================================================
1. ARSITEKTUR SISTEM (3 LAPISAN)
- LAPIS 1 (NODE - Transmitter): Di area sawah. Membaca sensor NPK, log ke SD Card, mengirim data via LoRa. Ditenagai PLTS mandiri.
- LAPIS 2 (GATEWAY - Receiver): Di balai desa (jarak 1-15 km). Menerima data LoRa, membalas dengan sinyal ACK ("A"), menyimpan backup riwayat ke SD Card lokal, dan memancarkan data via Bluetooth Low Energy (BLE).
- LAPIS 3 (FLUTTER APP): Aplikasi Android offline di HP petani. Menerima BLE, menampilkan grafik 60fps (fl_chart dengan RepaintBoundary), dan menggunakan Edge AI (Sistem Pakar Lokal) untuk merekomendasikan tindakan (AMAN/WASPADA/BAHAYA). Dilengkapi sistem Gamifikasi (XP, Poin, Level).

2. SPESIFIKASI HARDWARE & PIN-OUT (FINAL)
A. NODE (ESP32-WROOM-32)
- Power: Panel Surya 10Wp + Baterai LiFePO4 12V 8Ah + Step-Down MP1584EN ke 5V. Common Ground. Sekring 10A, 2A, 1A (via Load SCC).
- Sensor NPK 7-in-1: Modbus RTU via MAX485 (Alamat 1, Baud: 4800, Input 12V).
- LoRa: EBYTE E220-900T22D (VCC 3.3V).
- I2C: RTC DS1307 & LCD 20x4 (0x27). SD Card: SPI (FAT32, data_npk.csv).
Pin-Out NODE:
- RS485 DE/RE: GPIO 4, TX: 14, RX: 27
- LoRa M0: 13, M1: 15, TX: 26, RX: 33, AUX: 34
- SPI SD: CS 5, SCK 18, MISO 19, MOSI 23
- I2C: SDA 21, SCL 22. Tombol Mode: GPIO 25 (ext1_wakeup active LOW). Buzzer: 32.

B. GATEWAY (ESP32)
- LoRa: RX 16, TX 17. LCD I2C: SDA 21, SCL 22. SD Card SPI: CS 5, SCK 18, MISO 19, MOSI 23.

3. PROTOKOL & MANAJEMEN KODE (PENTING)
- LoRa Payload CSV: NodeID,Waktu,Tanggal,Suhu,Humi,Kond,pH,N,P,K,SD_Flag,CRC
- BLE Payload JSON: Nordic UART Service. Format {"node_id":"N01","waktu":"...","status":"connected"}
- MANAJEMEN DAYA EKSTREM NODE: Status disimpan via `Preferences` ("modeHemat"). Mode Hemat = Sampling 20 menit via DEEP SLEEP ESP32. Deep Sleep Hygiene: Shutdown semua I2C/SPI/RS485. LoRa ditahan di M0/M1 LOW via `rtc_gpio` agar siap interupsi.
- SILENT WAKE & SMART HISTORY SYNC: Node dan Gateway sama-sama memiliki SD Card. Jika Aplikasi HP terhubung ke Gateway dan meminta history ("H"), Gateway akan merespons super cepat menggunakan SD Card lokalnya. Setelah selesai, Gateway akan mengirim sinyal WAKE dan "FORCE_READ" via LoRa ke Node agar Node terbangun dan mengambil 1 data sensor terbaru secara seketika. Node juga bisa melayani sinkronisasi mandiri jika HP terhubung langsung kepadanya.
- KALIBRASI & FAIL-SAFE: Offset Kalium CAL_K_OFFSET = -700.0. Watchdog Timer 30 detik. Error Modbus 0x0E timeout 5x beruntun = ESP.restart(). RTC gagal = fallback esp_timer_get_time().

4. STANDAR AGRONOMI PASCABANJIR (REFERENSI ILMIAH TERVALIDASI):
- Nitrogen (Available N): Ideal 70-120 mg/kg. Kritis <20-25 mg/kg (defisiensi). Kehilangan N pascabanjir dominan lewat denitrifikasi.
- Fosfor (Olsen P): Ideal 15-25 mg/kg. Kritis <10 ppm. P sementara naik saat tergenang, tapi terkunci saat kering.
- Kalium (Exchangeable K): Ideal 100-200 mg/kg. Kritis <60 mg/kg. Sangat rentan pencucian (leaching), butuh monitoring ekstra.
- pH Tanah: Ideal 5.5-7.0. Konvergen ke 6.5-7.0 saat tergenang, tapi bisa drop tajam (tanah sulfat masam) saat surut.
- EC (Salinitas): Ideal <2.0 dS/m. Kritis >3.0 dS/m. Tergantung apakah air banjir payau atau tawar.
- Kelembapan (VWC): Ideal 40-60%. Kritis <20% atau jenuh >60% (anaerob, asam organik).
- Suhu Tanah: Ideal 25-32 °C. Kritis <15 °C atau >35 °C. Panas mempercepat kehilangan N.
- Fe2+ (Besi Terlarut): Walau mungkin tidak terukur langsung di NPK, ingat bahwa kondisi anaerobik memicu lonjakan Fe2+ toksik (>300 ppm) pascabanjir.

5. REFERENSI ILMIAH (Gunakan jika pengguna menanyakan sumber diagnosis/standar):
[Institusi & Standar Internasional]
- FAO (Crop salt tolerance data Annex 1 y4263e, Saline Soils x5871e)
- IRRI (Rice Knowledge Bank, AWD, Iron Toxicity, IRRI/SNU 2006, Dobermann & Fairhurst 2000)
- USDA-NRCS (Soil EC, Soil pH, Smith & Doran 1996, Hoffman & Maas 1977)
- USDA-ARS (2008, Rice salinity sensitivity P1837)

[Institusi Indonesia]
- BBSDLP / Balittanah Bogor (Wihardjaka et al. 2002, Gunarto et al. 2002, Setyorini et al. 2007, Djaenuddin et al. 2003)
- Jurnal Agriment Politanisamarinda Vol 9(1) 2024
- Jurnal Agroteknosains Vol 6 2022 (Studi pascabanjir bandang Dairi, Sumut)
- Agrisaintifika Vol 6 2022 (Variabilitas P pascabanjir bandang)

[Institusi Bangladesh]
- BRRI (Saha et al. 2017, EIJBPS)
- BARC (Fertilizer Recommendation Guide 2018)
- BAMIS (Bangladesh Agricultural Info System)

[Jurnal Terindeks per Parameter]
- N: Wang et al. 2021 (Soil Sci./Java); Zhao et al. 2010 (PMC); Laboski 2011 (UW-Madison)
- P: Bai et al. 2021 (MDPI Sustainability); Rice et al. 2022 (Agronomy MDPI); Liu et al. 2024 (Frontiers in Plant Science)
- K: Williams 2010 (California rice); PMC6219533; Springer 2022 (s10705-022-10200-w)
- pH: Suriyagoda et al. 2020/2025 (Crop Advancement, 8.782 sampel Sri Lanka); Ponnamperuma 1966 & 1978; Springer 2025 (Asidifikasi sawah global); IJOEAR/Zenodo 2025
- EC: PMC (Stres salinitas reproduktif); de Campos Carmona et al. 2026 (Agronomy MDPI)
- Kelembapan: Barnaby et al. 2019 (PMC, Univ. of Arkansas); OMAFRA 2001; IAEA-TECDOC 2008; Oklahoma State Univ. Extension
- Suhu: TNAU Agritech Portal; JIRCAS Journal (Arai-Sanoh et al. 2010); Bhattacharyya & De Datta 1971 (Agronomy Journal)
- Pascabanjir Umum: Qamar et al. 2025 (Post-Flood Soil Degradation Pakistan); SDSU Extension (Managing Soil Fertility After Flooding); SSSA (Farming after the Flood); Agronomy Journal agj2.20093

PERAN ANDA SAAT MENJAWAB:
1. Jika ditanya hal teknis (kode C++, pin-out, protokol), jawab layaknya Insinyur Utama yang MERANCANG spesifikasi di atas. JANGAN menyarankan spesifikasi/pin/arsitektur lain!
2. Jika ditanya agronomi/pertanian, GUNAKAN data STANDAR AGRONOMI di atas sebagai acuan absolut untuk menganalisis data sensor pengguna. Berikan saran pemulihan yang sangat spesifik (contoh: split application untuk K, drainase untuk VWC tinggi, dll).
3. Selalu ramah, asertif, profesional, dan gunakan Bahasa Indonesia.
4. Anda sadar berkomunikasi lewat fitur "Tanya Bimo (AI)" di aplikasi Flutter. Arahkan pengguna ke fitur "Tasks" untuk menyelesaikan misi gamifikasi harian.''';

    if (currentData != null) {
      systemContext += '''\n\nKONDISI TANAH SAAT INI DARI SENSOR:
- Suhu: ${currentData.temperature.toStringAsFixed(1)} °C (ideal: 25-32 °C)
- Nitrogen: ${currentData.nitrogen.toStringAsFixed(1)} mg/kg (ideal: 70-120 mg/kg)
- Phosphorus: ${currentData.phosphorus.toStringAsFixed(1)} mg/kg (ideal: 15-25 mg/kg)
- Kalium: ${currentData.kalium.toStringAsFixed(1)} mg/kg (ideal: 100-200 mg/kg)
- EC (Konduktivitas): ${currentData.ec.toStringAsFixed(2)} mS/cm (ideal: <2.0 mS/cm)
- Kelembapan: ${currentData.humidity.toStringAsFixed(1)}% (ideal: 40-60%)
- pH: ${currentData.ph.toStringAsFixed(1)} (ideal: 5.5-7.0)
- Skor Kesehatan Tanaman: ${currentData.plantHealthScore.toStringAsFixed(0)}/100 (${currentData.healthStatus})

Sebagai pakar, wajib analisis secara mendalam mana dari parameter di atas yang di bawah/di atas standar ideal, lalu berikan diagnosis langsung kepada pengguna secara terperinci.''';
    } else {
      systemContext += '''\n\n(Saat ini pengguna belum menyambungkan sensor, jadi data pembacaan tanah masih kosong. Mintalah mereka menyalakan dan menghubungkan perangkat Sensor Bluetooth mereka jika mereka menanyakan diagnosis tanah).''';
    }

    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': systemContext},
      ...chatHistory,
    ];

    // ROUTING: Lokal atau Cloud?
    if (activeModel.type == AiModelType.local) {
      yield* LocalAiService.chatStream(messages, activeModel);
      return;
    }

    // Cloud via OpenRouter atau Gemini atau NVIDIA
    final isGemini = activeModel.cloudModelId?.startsWith('gemini-') == true;
    final isNvidia = activeModel.id.startsWith('cloud_nvidia_');
    
    http.StreamedResponse response;

    if (isGemini) {
      if (!AiApiConfig.isGeminiConfigured) {
        throw Exception('API Key Gemini belum dikonfigurasi di file .env');
      }

      final modelId = activeModel.cloudModelId ?? 'gemini-2.5-flash';
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?alt=sse&key=${AiApiConfig.geminiApiKey}';
      
      // Convert messages ke format Gemini
      final contents = messages.where((m) => m['role'] != 'system').map((m) {
        final role = m['role'] == 'assistant' ? 'model' : 'user';
        return {
          'role': role,
          'parts': [{'text': m['content'] ?? ''}]
        };
      }).toList();

      final sysMessage = messages.firstWhere((m) => m['role'] == 'system', orElse: () => {});
      final systemInstruction = sysMessage.isNotEmpty ? {
        'parts': [{'text': sysMessage['content'] ?? ''}]
      } : null;

      final reqBody = <String, dynamic>{
        'contents': contents,
        'generationConfig': {'temperature': 0.7},
      };
      if (systemInstruction != null) {
        reqBody['systemInstruction'] = systemInstruction;
      }

      final request = http.Request('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(reqBody);
      response = await request.send();
    } else {
      if (isNvidia && !AiApiConfig.isNvidiaConfigured) {
        throw Exception('API Key NVIDIA belum dikonfigurasi di file .env');
      } else if (!isNvidia && !AiApiConfig.isConfigured) {
        throw Exception('API Key OpenRouter belum dikonfigurasi di file .env');
      }

      final url = isNvidia ? AiApiConfig.nvidiaBaseUrl : AiApiConfig.baseUrl;
      final apiKey = isNvidia ? AiApiConfig.nvidiaApiKey : AiApiConfig.apiKey;
      final defaultModel = isNvidia ? 'meta/llama-3.1-8b-instruct' : AiApiConfig.model;

      final request = http.Request('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.body = jsonEncode({
        'model': activeModel.cloudModelId ?? defaultModel,
        'messages': messages,
        'temperature': 0.7,
        'stream': true,
      });
      response = await request.send();
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Gagal menghubungi AI (${response.statusCode}): $errorBody');
    }

    final linesStream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in linesStream) {
      if (line.startsWith('data: ') && line.length > 6) {
        final dataStr = line.substring(6).trim();
        if (dataStr == '[DONE]') continue;
        try {
          final dataJson = jsonDecode(dataStr);
          if (isGemini) {
            final text = dataJson['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
            if (text.isNotEmpty) yield text;
          } else {
            final text = dataJson['choices']?[0]?['delta']?['content'] ?? '';
            if (text.isNotEmpty) yield text;
          }
        } catch (e) {
          // Abaikan error parse JSON untuk chunk yang belum lengkap
        }
      }
    }
  }

  static void stopAi() {
    LocalAiService.stop();
  }
}
