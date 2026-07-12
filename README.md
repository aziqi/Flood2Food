<div align="center">
  <img src="flood2food/assets/app_logo.png" width="150" alt="Flood2Food Logo" />
  
  # 🌱 Flood2Food: IoT Precision Agriculture & Gamification App
  **Sistem Pemulihan Lahan Sawah Pascabanjir Berbasis Industrial IoT dan Kecerdasan Buatan**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
  [![C++](https://img.shields.io/badge/C++-ESP32-00599C?logo=c%2B%2B)](https://www.arduino.cc/)
  [![LoRa](https://img.shields.io/badge/Network-LoRa_&_BLE-FF6C37)]()
  [![AI](https://img.shields.io/badge/AI-Gemini_&_Local-4285F4?logo=google-gemini)]()
</div>

---

## 📖 Tentang Proyek (PKM-KC)
**Flood2Food** adalah sistem terintegrasi (Hardware + Software) yang dirancang untuk memulihkan lahan sawah padi pascabanjir. Sistem ini memantau 7 parameter krusial tanah (Nitrogen, Fosfor, Kalium, pH, Konduktivitas Elektrik/EC, Suhu, dan Kelembaban) menggunakan sensor *Industrial Grade* (RS485 Modbus). Data kemudian dikirim jarak jauh via **LoRa**, dikumpulkan di **Gateway**, dan disinkronisasikan ke *Smartphone* petani via **Bluetooth Low Energy (BLE)**.

Aplikasi seluler (Flutter) tidak hanya menampilkan grafik data, tetapi juga menggunakan **AI (Google Gemini & Local Fallback)** untuk mendiagnosis masalah tanah dan memberikan "Tugas Harian" (Gamifikasi) langkah-demi-langkah bagi petani agar tanah kembali subur.

## 🏗️ Arsitektur Sistem

Proyek ini terdiri dari 3 pilar utama:

### 1. 📡 Sensor Node (Node / Transmitter)
Berada langsung di petak sawah. Menggunakan ESP32 yang terhubung dengan **Sensor NPK 7-in-1 (Modbus RS485)**.
- **Direktori:** `/node`
- **Fitur Utama:** Pembacaan presisi sensor, protokol Modbus RTU, Deep Sleep (hemat daya), dan transmisi data aman menggunakan Modul LoRa (Ra-02 / SX1278). 
- Mengirim paket data yang dikompresi ke Gateway.

### 2. 🖲️ Gateway (Receiver & Data Logger)
Diletakkan di saung/pos pantau. Menerima data dari puluhan Node.
- **Direktori:** `/gateway`
- **Fitur Utama:** Penerima LoRa, layar LCD I2C, pencatat CSV *real-time* ke **SD Card**, dan pemancar Bluetooth Low Energy (NimBLE ESP32).
- Dilengkapi sistem *Smart Chunking* dan antrean transmisi anti-crash yang sanggup mengirimkan ribuan baris riwayat (History) ke HP dalam hitungan detik.

### 3. 📱 Aplikasi Smartphone (Flutter)
Aplikasi pendamping (Companion App) modern untuk petani.
- **Direktori:** `/flood2food`
- **Fitur Utama:** 
  - **BLE Sync:** Sinkronisasi *seamless* file CSV secara otomatis.
  - **Dashboard:** Pemantauan parameter NPK, pH, EC, dll secara real-time.
  - **Gamification (Misi Harian):** Generasi misi harian secara cerdas menggunakan Google Gemini AI API (atau *Local Fallback AI* jika luring) untuk merehabilitasi tanah berdasarkan defisiensi gizi spesifik pada sensor.

## 🚀 Panduan Instalasi (Quick Start)

### Bagian 1: Perangkat Keras (Arduino IDE)
1. Buka `node/node.ino` dan `gateway/gateway.ino` menggunakan Arduino IDE.
2. Pastikan Anda telah menginstal pustaka (Library) berikut:
   - `LoRa` oleh Sandeep Mistry
   - `NimBLE-Arduino` oleh h2zero (Sangat penting! Jangan gunakan library BLE bawaan ESP32).
   - `ArduinoJson` oleh Benoit Blanchon
   - `ModbusMaster`
   - `LiquidCrystal_I2C` & `RTClib`
3. Sesuaikan pin LoRa (SS, RST, DIO0) jika menggunakan custom board, lalu *Flash* ke ESP32.

### Bagian 2: Aplikasi Seluler (Flutter)
1. Masuk ke direktori aplikasi:
   ```bash
   cd flood2food
   ```
2. Instal dependencies:
   ```bash
   flutter pub get
   ```
3. Buat file `.env` di direktori `flood2food` dan isi dengan konfigurasi API (opsional untuk AI):
   ```env
   AI_API_KEY=your_gemini_api_key_here
   AI_MODEL=gemini-1.5-flash
   ```
4. Jalankan aplikasi di perangkat Android:
   ```bash
   flutter run
   ```

## 🧠 Fitur "Offline AI" (Local Fallback)
Jika koneksi internet petani terputus atau kuota API habis, aplikasi memiliki modul pakar mini (Local Fallback AI). Modul ini tidak mengandalkan statis *if-else* biasa, melainkan merotasi *database* langkah-langkah agronomi (seperti injeksi Dolomit untuk pH asam, *flushing* air untuk EC tinggi, dll) agar instruksi harian tetap akurat secara medis dan sangat bervariasi.

## 🖼️ Tampilan Aplikasi (Screenshots)

<div align="center">
  <img src="flood2food/assets/splash.jpg" width="30%" />
</div>

---
*Dibuat dengan ❤️ untuk Program Kreativitas Mahasiswa Karsa Cipta (PKM-KC).*
