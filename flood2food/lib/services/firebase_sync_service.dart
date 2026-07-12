import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/daily_task.dart';
import '../models/sensor_data.dart';
import 'package:flutter/foundation.dart';

class FirebaseSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _userId => _auth.currentUser?.uid;

  // Sinkronisasi Profil Pengguna
  static Future<void> syncUserProfile(UserProfile profile) async {
    if (_userId == null) return;
    try {
      await _firestore.collection('users').doc(_userId).set({
        'profile': profile.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing user profile: $e');
    }
  }

  // Sinkronisasi Tugas Harian
  static Future<void> syncDailyTasks(List<DailyTask> tasks) async {
    if (_userId == null) return;
    try {
      final tasksJson = tasks.map((t) => t.toJson()).toList();
      await _firestore.collection('users').doc(_userId).set({
        'dailyTasks': tasksJson,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing daily tasks: $e');
    }
  }

  // Lempar Data Sensor ke Awan (Riwayat)
  static Future<void> pushSensorData(SensorData data) async {
    if (_userId == null) return;
    try {
      // 🛡️ ANTI-DUPLIKASI (UPSERT): Gunakan waktu sensor (ISO8601) sebagai ID Dokumen unik.
      // Jika waktu ini sudah pernah ter-upload sebelumnya, Firebase akan menimpanya secara otomatis.
      String docId = data.timestamp.toIso8601String().replaceAll(RegExp(r'[.\/#\[\]]'), '_');
      
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('sensor_history')
          .doc(docId) // Memaksa ID statis berbasis waktu
          .set({
        // 🐛 BUG WAKTU FIXED: Gunakan waktu asli dari SD Card, BUKAN waktu HP saat proses sinkronisasi!
        'timestamp': Timestamp.fromDate(data.timestamp),
        'nitrogen': data.nitrogen,
        'phosphorus': data.phosphorus,
        'kalium': data.kalium,
        'ph': data.ph,
        'ec': data.ec,
        'temperature': data.temperature,
        'humidity': data.humidity,
        'plantHealthScore': data.plantHealthScore,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error pushing sensor data: $e');
    }
  }

  // Lempar Data Sensor ke Awan secara BATCH (Sangat Cepat & Efisien)
  static Future<void> pushSensorDataBatch(List<SensorData> list) async {
    if (_userId == null || list.isEmpty) return;
    try {
      int count = 0;
      WriteBatch batch = _firestore.batch();
      
      for (final data in list) {
        String docId = data.timestamp.toIso8601String().replaceAll(RegExp(r'[.\/#\[\]]'), '_');
        final ref = _firestore
            .collection('users')
            .doc(_userId)
            .collection('sensor_history')
            .doc(docId);
            
        batch.set(ref, {
          'timestamp': Timestamp.fromDate(data.timestamp),
          'nitrogen': data.nitrogen,
          'phosphorus': data.phosphorus,
          'kalium': data.kalium,
          'ph': data.ph,
          'ec': data.ec,
          'temperature': data.temperature,
          'humidity': data.humidity,
          'plantHealthScore': data.plantHealthScore,
        }, SetOptions(merge: true));
        
        count++;
        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
      
      if (count % 500 != 0) {
        await batch.commit();
      }
      debugPrint('Berhasil batch-upload $count riwayat sensor ke Firebase.');
    } catch (e) {
      debugPrint('Error batch-uploading sensor data: $e');
    }
  }

  // Tarik Data Sensor dari Awan (Riwayat)
  static Future<List<SensorData>> fetchSensorHistory() async {
    if (_userId == null) return [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('sensor_history')
          .orderBy('timestamp', descending: true)
          .limit(100) // Ambil 100 riwayat terbaru
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        return SensorData(
          nitrogen: (data['nitrogen'] ?? 0).toDouble(),
          phosphorus: (data['phosphorus'] ?? 0).toDouble(),
          kalium: (data['kalium'] ?? 0).toDouble(),
          ph: (data['ph'] ?? 0).toDouble(),
          ec: (data['ec'] ?? 0).toDouble(),
          temperature: (data['temperature'] ?? 0).toDouble(),
          humidity: (data['humidity'] ?? 0).toDouble(),
          timestamp: ts,
        );
      }).toList().reversed.toList(); // Balik dari terlama ke terbaru
    } catch (e) {
      debugPrint('Error fetching sensor history: $e');
      return [];
    }
  }

  // Hapus Seluruh Riwayat Sensor
  static Future<void> deleteSensorHistory() async {
    if (_userId == null) return;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('sensor_history')
          .get();

      // 🛡️ ANTI-CRASH FIREBASE: Firestore hanya bisa menghapus maksimal 500 data dalam satu Batch.
      // Kita harus memotongnya menjadi porsi kecil-kecil agar eksekusi tidak ditolak oleh awan.
      int count = 0;
      WriteBatch batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;
        
        // Eksekusi batch setiap kali mencapai 500 dokumen
        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch(); // Buat keranjang batch baru
        }
      }
      
      // Eksekusi sisa dokumen (jika ada) yang kurang dari 500
      if (count % 500 != 0) {
        await batch.commit();
      }
      
      debugPrint('Berhasil menghapus $count riwayat sensor di awan.');
    } catch (e) {
      debugPrint('Error deleting sensor history: $e');
    }
  }
}
