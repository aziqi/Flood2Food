/*
 * ============================================================
 *  FLOOD2FOOD - GATEWAY RECEIVER (ESP32) [FINAL UPDATE]
 *  - Timeout LoRa 30 menit (sesuai interval Node 20 menit)
 *  - BLE JSON for Flutter
 * ============================================================
 */

#include <HardwareSerial.h>
#include <LiquidCrystal_I2C.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <Update.h>
#include <SPI.h>
#include <SD.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ==================== VARIABEL GLOBAL ====================
bool sdCardGatewaySiap = false;
SemaphoreHandle_t lcdMutex = NULL;

// Variabel Paginasi LCD
int halamanLCD = 0; 
bool buttonState = HIGH;
bool lastButtonReading = HIGH;
unsigned long lastDebounceTime = 0;
String cachedFields[13];
bool hasCachedData = false;

// ==================== DEFINISI UUID BLE ====================
#define LORA_RX_PIN    16
#define LORA_TX_PIN    17
#define LORA_BAUDRATE  9600
#define LCD_SDA_PIN    21
#define LCD_SCL_PIN    22
#define LCD_I2C_ADDR   0x27
#define LCD_COLS       20
#define LCD_ROWS       4

// ==================== SD CARD PINS (VSPI) ====================
#define SD_CS_PIN      5
// (SCK=18, MISO=19, MOSI=23 terhubung otomatis via VSPI hardware)

bool sdSiap = false;
int gatewayTotalLines = -1; // -1 berarti belum diinisialisasi

#define CSV_FIELD_COUNT 13
#define SPLASH_DELAY    2000
#define LORA_TIMEOUT_MS 1800000  // ⭐ 30 menit (menyesuaikan interval Node 20 menit)

// ==================== DEFINISI PIN ====================
#define PIN_TOMBOL_LCD 4 // Tombol ganti halaman LCD (Hubungkan ke Pin 4 dan GND)
#define PIN_BUZZER_1   25   // Buzzer Melody (utama)
#define PIN_BUZZER_2    2   // Buzzer Bass/Harmony (tambahan)

// ==================== KAMUS NADA MUSIK (Hz) ====================
// ==================== KAMUS NADA MUSIK (Hz) ====================
// Oktaf 4 (Untuk Bass / Beat yang dipindahkan lebih tinggi agar terdengar)
#define NOTE_C4   262
#define NOTE_CS4  277
#define NOTE_D4   294
#define NOTE_DS4  311
#define NOTE_E4   330
#define NOTE_F4   349
#define NOTE_FS4  370
#define NOTE_G4   392
#define NOTE_GS4  415
#define NOTE_A4   440
#define NOTE_AS4  466
#define NOTE_B4   494
// Oktaf 5
#define NOTE_C5   523
#define NOTE_CS5  554
#define NOTE_D5   587
#define NOTE_DS5  622
#define NOTE_E5   659
#define NOTE_F5   698
#define NOTE_FS5  740
#define NOTE_G5   784
#define NOTE_GS5  831
#define NOTE_A5   880
#define NOTE_AS5  932
#define NOTE_B5   988
// Oktaf 6 (SWEET SPOT KEKERASAN BUZZER: Sangat Nyaring & Premium)
#define NOTE_C6  1047
#define NOTE_CS6 1109
#define NOTE_D6  1175
#define NOTE_DS6 1245
#define NOTE_E6  1319
#define NOTE_F6  1397
#define NOTE_FS6 1480
#define NOTE_G6  1568
#define NOTE_GS6 1661
#define NOTE_A6  1760
#define NOTE_AS6 1865
#define NOTE_B6  1976
// Oktaf 7 (Puncak Resonansi Piezo: Sangat Tajam & Menggema)
#define NOTE_C7  2093
#define NOTE_CS7 2217
#define NOTE_D7  2349
#define NOTE_DS7 2489
#define NOTE_E7  2637
#define NOTE_F7  2794
#define NOTE_FS7 2960
#define NOTE_G7  3136

#define REST 0  // Diam (Speaker istirahat)

// =====================================================================
//  ENGINE AUDIO: DUAL-SPEAKER COUNTERPOINT DUET
//  Speaker 1 (Pin 25) = Vokal / Melodi Utama (Nada Tinggi Oktaf 6 & 7)
//  Speaker 2 (Pin 2)  = Bass / Beat Pengiring (Nada Sedang Oktaf 5 & 6)
// =====================================================================
void initBuzzer() {
  pinMode(PIN_BUZZER_1, OUTPUT);
  pinMode(PIN_BUZZER_2, OUTPUT);
  noTone(PIN_BUZZER_1);
  noTone(PIN_BUZZER_2);
}

// _play(Melodi Speaker 1, Bass Speaker 2, Durasi, Jeda)
void _play(int mel, int harm, int durMs, int gapMs = 0) {
  if (mel  > 0) tone(PIN_BUZZER_1, mel);  else noTone(PIN_BUZZER_1);
  if (harm > 0) tone(PIN_BUZZER_2, harm); else noTone(PIN_BUZZER_2);
  delay(durMs);
  noTone(PIN_BUZZER_1);
  noTone(PIN_BUZZER_2);
  if (gapMs > 0) delay(gapMs);
}

void soundBoot() {
  _play(REST,     NOTE_C5, 60, 0); 
  _play(NOTE_G6,  REST,    60, 0); 
  _play(REST,     NOTE_E5, 60, 0); 
  _play(NOTE_C7,  REST,    60, 0); 
  _play(REST,     NOTE_G5, 60, 0); 
  _play(NOTE_E7,  REST,    60, 0); 
  _play(NOTE_C7,  NOTE_C6, 600, 0); 
}

void soundBLEConnect() {
  _play(NOTE_C6, NOTE_A5, 80, 20); 
  _play(REST,    NOTE_A5, 80, 20); 
  _play(NOTE_E6, NOTE_A5, 80, 20); 
  _play(REST,    NOTE_A5, 80, 20); 
  _play(NOTE_G6, NOTE_E5, 300, 0); 
}

void soundBLEDisconnect() {
  _play(NOTE_E6, NOTE_A5, 80, 0); 
  _play(NOTE_D6, REST,    100, 0);
  _play(NOTE_C6, NOTE_G5, 130, 0); 
  _play(NOTE_B5, REST,    160, 0);
  _play(NOTE_A5, NOTE_F5, 400, 0); 
}

void soundDataReceived() {
  _play(NOTE_C7, NOTE_C7+3, 20, 10);
  _play(NOTE_E7, NOTE_E7+3, 20, 10);
  _play(NOTE_G7, NOTE_G7+3, 60, 0);
}

void soundPageTurn() {
  _play(NOTE_C7, 0, 10, 0); 
  _play(NOTE_E7, 0, 20, 0); 
}

void soundCommandConfirm() {
  _play(NOTE_G6, NOTE_E5, 40, 20);
  _play(NOTE_C7, NOTE_G5, 100, 0);
}

void soundModeToggle() {
  _play(NOTE_G6, NOTE_E5, 50, 0);
  _play(NOTE_C7, NOTE_G5, 50, 0);
  _play(NOTE_G5, NOTE_C5, 150, 0);
}

void soundHistoryComplete() {
  _play(NOTE_C6, NOTE_C5, 80, 20);
  _play(NOTE_C6, NOTE_C5, 80, 20);
  _play(NOTE_C6, NOTE_C5, 80, 20);
  _play(NOTE_C6, NOTE_C5,   250, 20); 
  _play(NOTE_GS5, NOTE_GS4, 250, 20); 
  _play(NOTE_AS5, NOTE_AS4, 250, 20); 
  _play(NOTE_C6,  NOTE_C5,  150, 20);  
  _play(NOTE_AS5, NOTE_AS4, 150, 20);  
  _play(NOTE_C6, NOTE_C6 + 3, 800, 0);  
}

void soundLoRaDisconnect() {
  for (int i = 0; i < 3; i++) {
    _play(NOTE_G6, NOTE_CS6, 120, 20);
    _play(NOTE_A6, NOTE_DS6, 120, 20);
    _play(NOTE_B6, NOTE_F6,  120, 20);
  }
  _play(REST, REST, 300, 0);
}

void soundLoRaReconnect() {
  _play(NOTE_C6, NOTE_C5, 80, 0);
  _play(NOTE_E6, NOTE_E5, 80, 0);
  _play(NOTE_G6, NOTE_G5, 200, 0);
}

void soundNodeTimeout() {
  _play(NOTE_C6, NOTE_FS5, 100, 0);
  _play(NOTE_CS6,NOTE_G5,  100, 200);
  _play(NOTE_C6, NOTE_FS5, 100, 0);
  _play(NOTE_CS6,NOTE_G5,  100, 0);
}

void soundSDConnected() {
  _play(NOTE_C6, NOTE_C5, 60, 20); 
  _play(NOTE_E6, NOTE_E5, 60, 20); 
  _play(NOTE_G6, NOTE_C6, 60, 20); 
  _play(NOTE_C7, NOTE_C7+3, 200, 0); 
}

void soundSDError() {
  for(int i=0; i<2; i++) {
    _play(NOTE_DS6, NOTE_C6, 120, 20); 
    _play(NOTE_C6,  NOTE_A5, 120, 20); 
    _play(NOTE_G5,  NOTE_DS5, 200, 50); 
  }
}

void soundSDFormat() {
  for(int i=0; i<3; i++) {
    _play(NOTE_C7, NOTE_A6, 100, 20);
    _play(NOTE_CS6,NOTE_AS6, 100, 100);
  }
}

extern bool bleDeviceConnected;
extern BLECharacteristic *pTxCharacteristic;
extern HardwareSerial LoRaSerial;

void formatSDCard() {
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  hapusLayarLCD();
  updateBarisLCD(1, " Menghapus SD Card..");
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  Serial.println(F("[SD] Memulai penghapusan data SD Card Gateway..."));
  
  if (SD.cardType() == CARD_NONE) {
    Serial.println(F("[SD] Error: SD Card Gateway tidak terdeteksi!"));
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    hapusLayarLCD();
    updateBarisLCD(1, "  Gagal Format SD!  ");
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    soundSDError();
    
    if (bleDeviceConnected) {
      StaticJsonDocument<50> doc;
      doc["type"] = "error";
      String jsonStr;
      serializeJson(doc, jsonStr);
      pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
      pTxCharacteristic->notify();
    } else {
      LoRaSerial.println("SD_ERROR_GATEWAY");
    }
    delay(2000);
    pulihkanLayarUtama();
    return;
  }
  
  if (SD.exists("/data_npk.csv")) {
    SD.remove("/data_npk.csv");
  }
  
  gatewayTotalLines = 0; // Reset totalLines juga
  
  soundSDFormat();
  
  if (bleDeviceConnected) {
    StaticJsonDocument<50> doc;
    doc["type"] = "success";
    String jsonStr;
    serializeJson(doc, jsonStr);
    pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
    pTxCharacteristic->notify();
  } else {
    LoRaSerial.println("SD_SUCCESS_GATEWAY");
  }
  Serial.println(F("[SD] Data SD Card Gateway berhasil dihapus dan index direset."));
  
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  hapusLayarLCD();
  updateBarisLCD(0, " -- FLOOD2FOOD --   ");
  updateBarisLCD(1, "  SD Card Bersih!   ");
  delay(1500);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  pulihkanLayarUtama();
}

void soundCalibStart() {
  _play(REST,    NOTE_C5, 80, 0);
  _play(REST,    NOTE_E5, 80, 0);
  _play(NOTE_C6, NOTE_G5, 80, 0);
  _play(NOTE_E6, NOTE_C6, 80, 0);
  _play(NOTE_C7, NOTE_E6, 200, 0);
}

void soundCalibRead() {
  _play(NOTE_C7, NOTE_C7+5, 20, 10);
  _play(NOTE_E7, NOTE_E7+5, 20, 10);
  _play(NOTE_G7, NOTE_G7+5, 20, 10);
  _play(NOTE_C7, NOTE_C7+5, 40, 0);
}

void soundCalibStop() {
  _play(NOTE_E6, NOTE_C6, 80, 0);
  _play(NOTE_C6, NOTE_G5, 80, 0);
  _play(NOTE_G5, NOTE_E5, 150, 0);
  _play(REST,    REST,    50, 0);
  _play(NOTE_C7, NOTE_G5, 40, 30);
  _play(NOTE_C7, NOTE_G5, 60, 0);
}

// ==================== BLE UUID ====================
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// ==================== FIELD INDEX ENUM ====================
enum CSVField {
  IDX_NODE_ID  = 0,
  IDX_WAKTU    = 1,
  IDX_TANGGAL  = 2,
  IDX_SUHU     = 3,
  IDX_HUMI     = 4,
  IDX_KOND     = 5,
  IDX_PH       = 6,
  IDX_N        = 7,
  IDX_P        = 8,
  IDX_K        = 9,
  IDX_SD_FLAG  = 10,
  IDX_MODE_HEMAT = 11,
  IDX_CRC      = 12
};

HardwareSerial LoRaSerial(1);
LiquidCrystal_I2C lcd(LCD_I2C_ADDR, LCD_COLS, LCD_ROWS);

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
BLECharacteristic *pRxCharacteristic = NULL;
bool bleDeviceConnected = false;
bool bleOldDeviceConnected = false;

bool loraTerhubung = false;
bool sdSiapTX      = false;
String activeNodeID = "";
bool historySent = false;
bool waitingForHistory = false;
String historyCommand = "H";
unsigned long lastHRequestTime = 0;
unsigned long lastRequestHistoryTime = 0;
unsigned long retryTimeout = 4000; // Timer fleksibel untuk menghindari underflow

unsigned long waktuDataTerakhir = 0;
unsigned long dataCount         = 0;

String lastLine[4] = {"", "", "", ""};

int expectedChunks = 0;
bool chunkReceived[2000] = {false};
int receivedChunks = 0;

// Flag untuk BUG-5
bool needToWakeNode = false;

// Timer untuk FITUR-2 & FITUR-3
unsigned long lastHeartbeat = 0;
unsigned long lastAdvCheck = 0;

// Variabel Non-Blocking untuk ping WAKE
int wakePingCount = 0;
unsigned long lastWakePingTime = 0;

// Variabel Kill-Switch (Wipe SD Card)
int wipeButtonCount = 0;
unsigned long lastWipePressTime = 0;

bool needToSendHistoryBLE = false;

void kirimHistorySDBle() {
  Serial.println("[BLE] Aplikasi meminta History! Mengirimkan dari SD Card lokal Gateway...");
  
  if (!sdSiap) {
    // Jika SD Card Gateway rusak, jangan bangunkan Node (hemat baterai!).
    // Cukup cetak log dan keluar dari fungsi.
    Serial.println("[BLE] Gagal kirim History. SD Card Gateway tidak terbaca!");
    return;
  }
  
  hapusLayarLCD();
  updateBarisLCD(0, "   SINKRONISASI HP  ");
  updateBarisLCD(1, "  Mengirim Data...  ");

  File file = SD.open("/data_npk.csv", FILE_READ);
  if (!file) return;

  file.readStringUntil('\n'); // skip header

  int currentLine = 0;
  int totalLines = gatewayTotalLines; // Kita sudah tau total barisnya

  String bleBuffer = "";
  int bleStartIdx = -1;

  while (file.available() && currentLine < totalLines) {
    String line = file.readStringUntil('\n');
    line.trim();
    if (line.length() < 5) continue;
    
    // Potong ",ACK" di belakang agar format JSON bersih
    int ackPos = line.lastIndexOf(",ACK");
    if (ackPos != -1) {
      line = line.substring(0, ackPos);
    }
    
    // Potong "NodeID," di depan agar format cocok dengan HP (mulai dari Jam)
    int firstComma = line.indexOf(',');
    if (firstComma != -1) {
      line = line.substring(firstComma + 1);
    }
    
    if (bleBuffer.length() == 0) bleStartIdx = currentLine;
    bleBuffer += line + "|";

    // Chunking Ultra-Fast untuk Gateway
    if (bleBuffer.length() >= 420 || currentLine == totalLines - 1) {
      StaticJsonDocument<768> doc; // [FIX] Diperbesar ke 768 agar tidak hang saat chunking
      doc["type"] = "chunk";
      doc["idx"] = bleStartIdx;
      doc["total"] = totalLines;
      doc["data"] = bleBuffer; 
  
      String jsonStr;
      serializeJson(doc, jsonStr);
  
      if (bleDeviceConnected) {
        pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
        pTxCharacteristic->notify();
        delay(15); // [FIX] Beri nafas stack NimBLE agar tidak disconnect otomatis saat file besar
      }
      bleBuffer = "";
    }
    
    currentLine++;
    // Cegah LCD bottleneck (I2C sangat lambat). Update per 100 baris saja.
    if (currentLine % 100 == 0 || currentLine == totalLines) {
      tampilkanProgressHistory(currentLine, totalLines);
    }
  }
  file.close();

  StaticJsonDocument<100> doc;
  doc["type"]   = "history_complete";
  doc["lines"]  = totalLines;
  String jsonStr;
  serializeJson(doc, jsonStr);
  if (bleDeviceConnected) {
    pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
    pTxCharacteristic->notify();
  }

  hapusLayarLCD();
  updateBarisLCD(0, "   SINKRONISASI HP  ");
  updateBarisLCD(1, "      SELESAI!      ");
  
  Serial.println("[BLE] History Lokal Selesai!");
  
  // TRIGGER NODE UNTUK BACA SENSOR SEKARANG
  Serial.println("[LORA] Memaksa Node mengambil data terbaru...");
  LoRaSerial.println("WAKE");
  delay(150);
  LoRaSerial.println("FORCE_READ");

  delay(2000);
  pulihkanLayarUtama();
}

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    bleDeviceConnected = true;
    needToSendHistoryBLE = false; // [FIX] Tunggu HP kirim perintah 'H' setelah subscribe
    Serial.println("[BLE] Perangkat terhubung! Menunggu perintah dari HP.");
    soundBLEConnect();
    
    // AUTO-WAKE DIMATIKAN! Node tidak diganggu gugat saat HP Connect ke Gateway
  }

  void onDisconnect(BLEServer *pServer) {
    bleDeviceConnected = false;
    historySent = false;
    Serial.println("[BLE] Perangkat terputus!");
    soundBLEDisconnect();
    
    // 🔥 BUG FIX: Kill-Switch Darurat!
    // Jika HP putus saat Gateway sedang menunggu history, langsung suruh Node berhenti!
    if (waitingForHistory) {
      Serial.println("[LORA] Mengirim perintah ABORT ke Node karena HP terputus...");
      LoRaSerial.println("ABORT"); // Tembakkan ke Node
      waitingForHistory = false;
      expectedChunks = 0;
      receivedChunks = 0;
      memset(chunkReceived, 0, sizeof(chunkReceived));
      
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      hapusLayarLCD();
      updateBarisLCD(0, "   SINKRONISASI SD  ");
      updateBarisLCD(1, "     DIBATALKAN     ");
      updateBarisLCD(2, "   (HP Terputus)    ");
      delay(2000);
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      pulihkanLayarUtama();
    }
  }
};

class MyRXCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue().c_str();
    rxValue.trim();
    if (rxValue == "SEND_HISTORY" || rxValue == "H" || rxValue == "H_ALL") {
      needToSendHistoryBLE = true;
      Serial.println("[BLE CMD] HP meminta History secara langsung!");
      } else if (rxValue == "TOGGLE_MODE" || rxValue.startsWith("SET_MODE:")) {
        bool targetIsHemat;
        bool currentIsHemat = false;
        
        if (hasCachedData) {
          currentIsHemat = (cachedFields[IDX_MODE_HEMAT] == "1");
        }
        
        if (rxValue == "TOGGLE_MODE") {
          targetIsHemat = !currentIsHemat;
        } else {
          char targetMode = rxValue.charAt(9);
          targetIsHemat = (targetMode == '1');
        }
        
        if (!hasCachedData || (currentIsHemat != targetIsHemat)) {
          LoRaSerial.println("WAKE"); 
          delay(150);
          LoRaSerial.println("TOGGLE_MODE");
          hapusLayarLCD();
          updateBarisLCD(1, "  Sinkronisasi Mode");
          updateBarisLCD(2, " Meneruskan ke Node ");
          soundCommandConfirm();
          
          if (hasCachedData) {
            cachedFields[IDX_MODE_HEMAT] = targetIsHemat ? "1" : "0";
          }
        } else {
          Serial.println("[BLE] Mode Node sudah sesuai target, mengabaikan SET_MODE");
        }
      } else if (rxValue.startsWith("SET_TIME:")) {
      Serial.println(F("[BLE] Perintah Sinkronisasi Waktu dari HP. Meneruskan ke Node..."));
      hapusLayarLCD();
      updateBarisLCD(0, " -- FLOOD2FOOD --   ");
      updateBarisLCD(1, "  Sinkronisasi Waktu");
      updateBarisLCD(2, " Meneruskan ke Node ");
      LoRaSerial.println("WAKE");
      delay(150);
      LoRaSerial.println(rxValue);
      soundCommandConfirm();
      delay(1500);
      pulihkanLayarUtama();
    } else if (rxValue.startsWith("SET_INTERVAL:")) {
      Serial.println(F("[BLE] Perintah Set Interval dari HP. Meneruskan ke Node..."));
      hapusLayarLCD();
      updateBarisLCD(0, " -- FLOOD2FOOD --   ");
      updateBarisLCD(1, "  Set Interval...   ");
      updateBarisLCD(2, " Meneruskan ke Node ");
      LoRaSerial.println("WAKE");
      delay(150);
      LoRaSerial.println(rxValue);
      soundCommandConfirm();
      delay(1500);
      pulihkanLayarUtama();
    } else if (rxValue == "CALIB_START" || rxValue == "CALIB_STOP" || rxValue == "CALIB_READ") {
      if (rxValue == "CALIB_START") {
        hapusLayarLCD();
        updateBarisLCD(0, " -- FLOOD2FOOD --   ");
        updateBarisLCD(1, "   Mode Kalibrasi   ");
        updateBarisLCD(2, " Meneruskan ke Node ");
        LoRaSerial.println("WAKE");
        delay(150);
        LoRaSerial.println("CALIB_START");
        soundCalibStart();
        delay(1500);
        pulihkanLayarUtama();
      } else if (rxValue == "CALIB_READ") {
        hapusLayarLCD();
        updateBarisLCD(1, "  Mengambil Data..  ");
        updateBarisLCD(2, " Meneruskan ke Node ");
        LoRaSerial.println("WAKE");
        delay(150);
        LoRaSerial.println("CALIB_READ");
        soundCalibRead();
        delay(1500);
        pulihkanLayarUtama();
      } else if (rxValue == "CALIB_STOP") {
        hapusLayarLCD();
        updateBarisLCD(0, " -- FLOOD2FOOD --   ");
        updateBarisLCD(1, "  Kalibrasi Selesai ");
        updateBarisLCD(2, "                    ");
        LoRaSerial.println("WAKE");
        delay(150);
        LoRaSerial.println("CALIB_STOP");
        soundCalibStop();
        delay(1500);
        pulihkanLayarUtama();
      }
    } else if (rxValue == "DELETE_SD_GATEWAY") {
      Serial.println(F("[BLE] Perintah Hapus SD Card Gateway dari HP!"));
      formatSDCard();
    } else if (rxValue == "DELETE_SD_NODE") {
      Serial.println(F("[BLE] Perintah Hapus SD Card Node dari HP. Meneruskan ke Node..."));
      hapusLayarLCD();
      updateBarisLCD(0, " -- FLOOD2FOOD --   ");
      updateBarisLCD(1, "Menghapus SD Node...");
      updateBarisLCD(2, " Meneruskan ke Node ");
      LoRaSerial.println("WAKE");
      delay(150);
      LoRaSerial.println("DELETE_SD");
      soundCommandConfirm();
      delay(1500);
      pulihkanLayarUtama();
    } else if (rxValue == "ABORT") {
      Serial.println("[BLE] Menerima perintah BATAL (ABORT) dari HP!");
      waitingForHistory = false;
      
      StaticJsonDocument<100> doc;
      doc["type"]   = "history_complete";
      doc["lines"]  = receivedChunks;
      String jsonStr;
      serializeJson(doc, jsonStr);
      if (bleDeviceConnected && pTxCharacteristic != NULL) {
        pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
        pTxCharacteristic->notify();
      }
      
      expectedChunks = 0;
      receivedChunks = 0;
      updateBarisLCD(0, "   SINKRONISASI SD  ");
      updateBarisLCD(1, "     DIBATALKAN     ");
      updateBarisLCD(2, "                    ");
      updateBarisLCD(3, "                    ");
    }
  }
};

int parseCSV(String data, String fields[], int max) {
  int count = 0;
  int start = 0;
  int pos;
  data.replace("\r", "");
  data.trim();
  if (data.length() == 0) return 0;
  while (count < max) {
    pos = data.indexOf(',', start);
    if (pos == -1) {
      fields[count] = data.substring(start);
      count++;
      break;
    } else {
      fields[count] = data.substring(start, pos);
      count++;
      start = pos + 1;
    }
  }
  return count;
}

void cekStatusLoRa() {
  bool lastLoraStatus = loraTerhubung;
  if (loraTerhubung && (millis() - waktuDataTerakhir) > LORA_TIMEOUT_MS) {
    loraTerhubung = false;
    sdSiapTX = false;
    Serial.println("[LORA] TERPUTUS! > " + String(LORA_TIMEOUT_MS / 1000) + " detik");
  }
  
  if (loraTerhubung != lastLoraStatus) {
    if (!loraTerhubung) {
      soundLoRaDisconnect(); // LoRa terputus
      
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.setCursor(0, 0); lcd.print("                    ");
      lcd.setCursor(0, 0); lcd.print("!! LORA TERPUTUS !!");
      lcd.setCursor(0, 1); lcd.print("                    ");
      lcd.setCursor(0, 1); lcd.print("Tidak ada data Node");
      lcd.setCursor(0, 2); lcd.print("                    ");
      lcd.setCursor(0, 2); lcd.print("Cek: Jarak/Daya    ");
      lcd.setCursor(0, 3); lcd.print("                    ");
      lcd.setCursor(0, 3); lcd.print("L:NO                ");
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      for (int i = 0; i < 4; i++) lastLine[i] = "";

      StaticJsonDocument<200> doc;
      doc["node_id"] = activeNodeID.length() ? activeNodeID : "unknown";
      doc["status"]  = "disconnected";
      String jsonStr;
      serializeJson(doc, jsonStr);
      if (bleDeviceConnected) {
        pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
        pTxCharacteristic->notify();
      }
    } else {
      soundLoRaReconnect();  // LoRa kembali tersambung!
    }
  }
}

void updateBarisLCD(int baris, String teks) {
  if (baris < 0 || baris > 3) return;
  if (lastLine[baris] == teks) return;
  
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, baris);
  lcd.print("                    ");
  lcd.setCursor(0, baris);
  lcd.print(teks);
  lastLine[baris] = teks;
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}

void hapusLayarLCD() {
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.clear();
  for (int i = 0; i < 4; i++) {
    lastLine[i] = "";
  }
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}

  void pulihkanLayarUtama() {
    hapusLayarLCD();
    if (hasCachedData) {
      tampilkanDataLCD(cachedFields);
    } else {
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.setCursor(0, 0); lcd.print("Menunggu data Node  ");
      if (bleDeviceConnected) {
          lcd.setCursor(0, 1); lcd.print("  [ HP TERHUBUNG ]  ");
      } else {
          lcd.setCursor(0, 1); lcd.print("Menunggu Koneksi HP ");
      }
      lcd.setCursor(0, 2); lcd.print("BLE: Flood2Food_GW  ");
      lcd.setCursor(0, 3); lcd.print("                    ");
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    }
  }

void tampilkanDataLCD(String fields[]) {
  // Simpan ke cache agar bisa dirender ulang saat ganti halaman
  for(int i=0; i<13; i++) {
    cachedFields[i] = fields[i];
  }
  hasCachedData = true;

  if (lcdMutex != NULL) {
    if (xSemaphoreTakeRecursive(lcdMutex, pdMS_TO_TICKS(50)) != pdTRUE) {
      return; // Skip rendering dashboard jika layar sedang dipakai
    }
  }

  char buf[21];
  
  if (halamanLCD == 0) {
    // HALAMAN 1: Data Utama Lingkungan
    snprintf(buf, sizeof(buf), "%.8s  %.10s", fields[IDX_WAKTU].c_str(), fields[IDX_TANGGAL].c_str());
    updateBarisLCD(0, String(buf));

    float ph = fields[IDX_PH].toFloat();
    float suhu = fields[IDX_SUHU].toFloat();
    float humi = fields[IDX_HUMI].toFloat();
    snprintf(buf, sizeof(buf), "pH:%-4.1f T:%-4.1f H:%-2.0f%%", ph, suhu, humi);
    updateBarisLCD(1, String(buf));

    int n = fields[IDX_N].toInt();
    int p = fields[IDX_P].toInt();
    int k = fields[IDX_K].toInt();
    snprintf(buf, sizeof(buf), "N:%-3d P:%-3d K:%-3d", n, p, k);
    updateBarisLCD(2, String(buf));

    int kond = fields[IDX_KOND].toInt();
    snprintf(buf, sizeof(buf), "EC:%-4d           P1", kond);
    updateBarisLCD(3, String(buf));
  } 
  else {
    // HALAMAN 2: Panel Diagnostik (Hardware Status)
    updateBarisLCD(0, "- PANEL DIAGNOSTIK -");
    
    // Menggabungkan BLE dan LoRa di satu baris agar menghemat ruang
    snprintf(buf, sizeof(buf), "BLE:%-3s    LoRa:%-3s", 
             bleDeviceConnected ? "YES" : "NO", 
             loraTerhubung ? "OK" : "ERR");
    updateBarisLCD(1, String(buf));

    // Menuliskan Node secara utuh
    snprintf(buf, sizeof(buf), "SD Node    : %-3s", sdSiapTX ? "YES" : "NO");
    updateBarisLCD(2, String(buf));

    // Menuliskan Gateway secara utuh beserta indikator Page 2 (P2)
    snprintf(buf, sizeof(buf), "SD Gateway : %-3s  P2", sdCardGatewaySiap ? "YES" : "NO");
    updateBarisLCD(3, String(buf));
  }
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}

void tampilkanProgressHistory(int current, int total) {
  updateBarisLCD(0, "   SINKRONISASI SD  ");
  updateBarisLCD(1, "  Mengirim Data...  ");
  
  char buf[21];
  snprintf(buf, sizeof(buf), "  Data: %d/%d", current, total);
  updateBarisLCD(2, String(buf));

  // Progress bar sederhana 20 karakter
  int numBars = (current * 20) / total;
  String bar = "";
  for (int i = 0; i < 20; i++) {
    if (i < numBars) bar += "=";
    else if (i == numBars) bar += ">";
    else bar += ".";
  }
  updateBarisLCD(3, bar);
}

void initBLE() {
  BLEDevice::init("Flood2Food_Gateway");
  BLEDevice::setMTU(517);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pTxCharacteristic->addDescriptor(new BLE2902());

  pRxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE
  );
  pRxCharacteristic->setCallbacks(new MyRXCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Gateway siap, menunggu koneksi...");
}

void cekSDCardGateway() {
  SPI.begin(18, 19, 23, SD_CS_PIN); 
  
  if (SD.begin(SD_CS_PIN, SPI, 1000000)) {
    sdSiap = true;
    sdCardGatewaySiap = true; 
    File f = SD.open("/data_npk.csv", FILE_READ);
    if (!f) {
      f = SD.open("/data_npk.csv", FILE_WRITE);
      if (f) {
        f.println("NodeID,Waktu,Tanggal,Suhu,Kelembaban,Konduktivitas,pH,N,P,K,SD_Node_Siap,Mode_Hemat,ACK");
        f.close();
      }
      gatewayTotalLines = 0;
    } else {
      f.readStringUntil('\n'); // Lompati header
      int lines = 0;
      while(f.available()) {
        if (f.read() == '\n') lines++;
      }
      f.close();
      gatewayTotalLines = lines;
    }
  } else {
    sdSiap = false;
    sdCardGatewaySiap = false; 
  }
}

void simpanKeSDGateway(String payload) {
  if (!sdSiap) return;
  File f = SD.open("/data_npk.csv", FILE_APPEND);
  if (f) {
    f.println(payload);
    gatewayTotalLines++;
    f.close();
  }
}

void setup() {
  lcdMutex = xSemaphoreCreateRecursiveMutex();
  Serial.begin(115200);
  delay(100);
  
  pinMode(PIN_TOMBOL_LCD, INPUT_PULLUP);
  
  pinMode(PIN_BUZZER_1, OUTPUT);
  pinMode(PIN_BUZZER_2, OUTPUT);
  noTone(PIN_BUZZER_1);
  noTone(PIN_BUZZER_2);

    Serial.println(F("======================================="));

  // 🔥 MAX SPEED OPTIMIZATION
  LoRaSerial.setRxBufferSize(1024); 
  LoRaSerial.begin(9600, SERIAL_8N1, 16, 17);
  
  // 🔥 NOISE IMMUNITY OPTIMIZATION
  LoRaSerial.setTimeout(50);
  
  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  hapusLayarLCD();
  
  cekSDCardGateway();

  lcd.setCursor(0, 0); lcd.print("   Flood2Food      ");
  lcd.setCursor(0, 1); lcd.print("     GATEWAY       ");
  lcd.setCursor(0, 2); lcd.print("    + BLE UART     ");
  lcd.setCursor(0, 3); lcd.print("  Booting...       ");
  
  initBuzzer();
  soundBoot(); 
  delay(SPLASH_DELAY / 2); 

  initBLE();

  lcd.setCursor(0, 0); lcd.print("                    ");
  lcd.setCursor(0, 0); lcd.print("Cek LoRa & BLE...   ");
  delay(800);

  lcd.setCursor(0, 0); lcd.print("                    ");
  lcd.setCursor(0, 1); lcd.print("                    ");
  lcd.setCursor(0, 2); lcd.print("                    ");
  lcd.setCursor(0, 3); lcd.print("                    ");
  
  lcd.setCursor(0, 0); lcd.print("SD CARD Gateway:    ");
  
  if (sdCardGatewaySiap) {
    lcd.setCursor(0, 1); lcd.print("  [ CONNECTED ]     ");
    soundSDConnected();
  } else {
    lcd.setCursor(0, 1); lcd.print("  [ MISSING! ]      ");
    lcd.setCursor(0, 2); lcd.print("  Data tidak akan   ");
    lcd.setCursor(0, 3); lcd.print("  tersimpan!        ");
    soundSDError();
  }
  delay(1500);
  
  hapusLayarLCD();
  loraTerhubung = false;
  sdSiapTX = false;
  waktuDataTerakhir = millis();

  lcd.setCursor(0, 0); lcd.print("                    ");
  lcd.setCursor(0, 0); lcd.print("Menunggu data Node  ");

  lcd.setCursor(0, 1); lcd.print("                    ");
  lcd.setCursor(0, 1); lcd.print("Menunggu Koneksi HP ");

  lcd.setCursor(0, 2); lcd.print("                    ");
  lcd.setCursor(0, 2); lcd.print("BLE: Flood2Food_GW  ");

  lcd.setCursor(0, 3); lcd.print("                    ");

  Serial.println("[LORA] Menunggu data dari Node...");
}

void loop() {
  bool currentReading = digitalRead(PIN_TOMBOL_LCD);
  if (currentReading != lastButtonReading) {
    lastDebounceTime = millis();
  }
  if ((millis() - lastDebounceTime) > 50) {
    if (currentReading != buttonState) {
      buttonState = currentReading;
      if (buttonState == LOW) {
        
        if (millis() - lastWipePressTime > 1500) {
          wipeButtonCount = 0; 
        }
        wipeButtonCount++;
        lastWipePressTime = millis();
        
        if (wipeButtonCount >= 10) {
          Serial.println("[CMD] PERINGATAN HAPUS DATA AKTIF. Menunggu Konfirmasi...");
          
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          hapusLayarLCD();
          lcd.setCursor(0, 0); lcd.print("! YAKIN HAPUS DATA !");
          lcd.setCursor(0, 1); lcd.print("====================");
          lcd.setCursor(0, 2); lcd.print("2x Klik: HAPUS SEMUA");
          lcd.setCursor(0, 3); lcd.print("1x Klik: BATAL");
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          
          soundBoot();
          
          unsigned long startConfirmWait = millis();
          int confirmClicks = 0;
          bool confirmBtnState = digitalRead(PIN_TOMBOL_LCD); 
          
          while (millis() - startConfirmWait < 5000) {
             bool cReading = digitalRead(PIN_TOMBOL_LCD);
             if (cReading != confirmBtnState) {
                delay(50);
                cReading = digitalRead(PIN_TOMBOL_LCD);
                if (cReading != confirmBtnState) {
                   confirmBtnState = cReading;
                   if (confirmBtnState == LOW) {
                      confirmClicks++;
                      startConfirmWait = millis(); 
                      soundCommandConfirm();
                   }
                }
             }
             if (confirmClicks >= 2) break;
             yield();
          }

          if (confirmClicks >= 2) {
            Serial.println(F("[SD] Memformat SD Card..."));
            soundSDFormat();
            File root = SD.open("/");
            if (sdSiap) {
              SD.remove("/data_npk.csv");
              File file = SD.open("/data_npk.csv", FILE_WRITE);
              if (file) {
                file.println("NodeID,Waktu,Tanggal,Suhu,Kelembaban,Konduktivitas,pH,N,P,K,SD_Node_Siap,Mode_Hemat,ACK");
                file.close();
              }
              gatewayTotalLines = 0;
              
              soundSDError();
              
              if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
              hapusLayarLCD();
              lcd.setCursor(0, 1); lcd.print("   MEMORI GATEWAY   ");
              lcd.setCursor(0, 2); lcd.print("    DIBERSIHKAN!    ");
              delay(3000);
              if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
            }
          } else {
            Serial.println("[CMD] Format dibatalkan oleh pengguna atau Timeout.");
            if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
            hapusLayarLCD();
            lcd.setCursor(0, 1); lcd.print("   FORMAT MEMORI    ");
            lcd.setCursor(0, 2); lcd.print("     DIBATALKAN     ");
            delay(2000);
            if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          }
          
          // Render ulang layar utama
          if (hasCachedData) {
            lastLine[0]=""; lastLine[1]=""; lastLine[2]=""; lastLine[3]="";
            tampilkanDataLCD(cachedFields);
          } else {
            if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
            hapusLayarLCD();
            lcd.setCursor(0, 0); lcd.print("Menunggu data Node  ");
            if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          }
          
          wipeButtonCount = 0; // Reset setelah wipe/batal berhasil
        } else {
          // --- LOGIKA NORMAL (GANTI HALAMAN LCD) ---
          halamanLCD = (halamanLCD == 0) ? 1 : 0; // Ganti halaman (Toggle)
          soundPageTurn(); // Suara klik antarmuka
          
          if (hasCachedData) {
            // Paksa layar me-refresh ulang seluruh baris (hapus cache teks lama)
            lastLine[0]=""; lastLine[1]=""; lastLine[2]=""; lastLine[3]="";
            tampilkanDataLCD(cachedFields); // Render ulang sekejap mata
          }
        }
      }
    }
  }
  lastButtonReading = currentReading;

  if (needToSendHistoryBLE) {
    needToSendHistoryBLE = false;
    kirimHistorySDBle();
  }
  
  cekStatusLoRa();

  // FITUR-3: Re-advertise BLE jika putus tanpa trigger disconnect event (misal HP menjauh tiba-tiba)
  if (!bleDeviceConnected) {
    if (bleOldDeviceConnected) {
      delay(500);
      pServer->startAdvertising();
      Serial.println("[BLE] Mulai advertising lagi (Disconnect event)...");
      bleOldDeviceConnected = bleDeviceConnected;
      waitingForHistory = false;
    } else if (millis() - lastAdvCheck > 60000) {
      lastAdvCheck = millis();
      pServer->startAdvertising();
    }
  }

  if (bleDeviceConnected) {
    bleOldDeviceConnected = bleDeviceConnected;
    
    // FITUR-2: Kirim Heartbeat ke HP setiap 30 detik agar HP tahu Gateway tidak freeze
    if (millis() - lastHeartbeat > 30000) {
      lastHeartbeat = millis();
      StaticJsonDocument<100> doc;
      doc["type"] = "heartbeat";
      doc["lora"] = loraTerhubung;
      String jsonStr;
      serializeJson(doc, jsonStr);
      if (pTxCharacteristic != NULL) {
        pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
        pTxCharacteristic->notify();
      }
    }
    
    // Blok Wake Node telah dimatikan (Sistem Pasif)
    
    // ⭐ FIX: Mekanisme RETRY untuk 'H'
    unsigned long waktuSekarang = millis();
    if (waitingForHistory && !historySent && (waktuSekarang - lastRequestHistoryTime >= 10000)) { 
       lastRequestHistoryTime = waktuSekarang; 
       Serial.println("[LORA] Retry meminta baris yang hilang ke Node...");
       
       if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
       hapusLayarLCD();
       updateBarisLCD(0, "   SINKRONISASI SD  ");
       updateBarisLCD(1, " Minta data dari    ");
       updateBarisLCD(2, " Node (Retry)...    ");
       if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
       
       LoRaSerial.println(historyCommand);
    }
  }

  if (LoRaSerial.available() > 0) {
    String pesan = LoRaSerial.readStringUntil('\n');
    pesan.replace("\r", "");
    pesan.trim();

    if (pesan.length() == 0) return;

    if (pesan == "DELETE_SD_GATEWAY") {
      Serial.println(F("[LORA] Menerima perintah DELETE_SD_GATEWAY dari Node!"));
      formatSDCard();
      return;
    }
    
    if (pesan == "SD_ERROR_NODE") {
      Serial.println(F("[LORA] SD Card Node Error! Membatalkan Sinkronisasi!"));
      waitingForHistory = false;
      if (needToSendHistoryBLE) {
        needToSendHistoryBLE = false;
        
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        hapusLayarLCD();
        updateBarisLCD(0, "   SINKRONISASI SD  ");
        updateBarisLCD(1, "   NODE SD RUSAK!   ");
        updateBarisLCD(2, "  Gagal Minta Data  ");
        delay(2000);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        pulihkanLayarUtama();
        
        StaticJsonDocument<50> doc;
        doc["type"] = "error";
        String jsonStr;
        serializeJson(doc, jsonStr);
        if (bleDeviceConnected && pTxCharacteristic != NULL) {
            pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
            pTxCharacteristic->notify();
        }
        return;
      }
    }

    if (pesan == "SD_SUCCESS_NODE") {
      Serial.println(F("[LORA] Menerima pesan SUCCESS dari Node!"));
      if (bleDeviceConnected && pTxCharacteristic != NULL) {
        StaticJsonDocument<50> doc;
        doc["type"] = "success";
        String jsonStr;
        serializeJson(doc, jsonStr);
        pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
        pTxCharacteristic->notify();
      }
      return;
    }

    // FIX TABRAKAN RETRI: Jika Node sudah membalas 'A' (Siap), berikan kelonggaran waktu!
    if (pesan == "A" && waitingForHistory) {
      Serial.println("[LORA] Node merespons (ACK)! Menunda Retri...");
      lastHRequestTime = millis(); 
      retryTimeout = 15000; // Beri napas tambahan 15 detik dengan AMAN (bebas underflow)
      return;
    }

    if (pesan.startsWith("B:")) {
      waitingForHistory = false;

      int firstColon = pesan.indexOf(':');
      int secondColon = pesan.indexOf(':', firstColon + 1);
      int thirdColon = pesan.indexOf(':', secondColon + 1);

      if (firstColon == -1 || secondColon == -1 || thirdColon == -1) return;

      int idx = pesan.substring(firstColon + 1, secondColon).toInt();
      int total = pesan.substring(secondColon + 1, thirdColon).toInt();
      String chunkData = pesan.substring(thirdColon + 1);

      // --- FATAL EDGE CASE FIX: KEDUA SD CARD MATI ---
      if (chunkData.startsWith("SD_FAIL")) {
        StaticJsonDocument<100> doc;
        doc["type"]   = "history_complete";
        doc["lines"]  = 0;
        String jsonStr;
        serializeJson(doc, jsonStr);
        
        if (bleDeviceConnected) {
          pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
          pTxCharacteristic->notify();
        }
        
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        hapusLayarLCD();
        updateBarisLCD(0, "   SINKRONISASI SD  ");
        updateBarisLCD(1, "   NODE SD RUSAK!   ");
        updateBarisLCD(2, "  Gagal Minta Data  ");
        delay(2000);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        pulihkanLayarUtama();
        return;
      }

      if (idx >= 0 && total > 0 && idx < 2000) {
        if (!chunkReceived[idx]) {
          receivedChunks++;
          chunkReceived[idx] = true;
          
          // === FITUR SINKRONISASI SD CARD GATEWAY ===
          if (idx == gatewayTotalLines) {
            String dataSD = chunkData;
            dataSD.replace("|", "");
            simpanKeSDGateway(dataSD);
          }
        }
        expectedChunks = total;
        
        StaticJsonDocument<768> doc;
        doc["type"] = "chunk";
        doc["idx"] = idx;
        doc["total"] = total;
        doc["data"] = chunkData;

        String jsonStr;
        serializeJson(doc, jsonStr);

        if (bleDeviceConnected) {
          pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
          pTxCharacteristic->notify();
          delay(10); 
        }

        tampilkanProgressHistory(idx + 1, total);
      }
      return;
    }

    if (pesan.startsWith("B_END:")) {
      int totalLines = pesan.substring(6).toInt();
      if (totalLines > 2000) totalLines = 2000;
      
      String missing = "";
      for (int i = 0; i < totalLines; i++) {
        if (!chunkReceived[i]) {
          if (missing.length() > 0) missing += ",";
          missing += String(i);
          if (missing.length() > 50) break; // Jangan kepanjangan stringnya
        }
      }

      if (missing == "") {
        waitingForHistory = false;
        LoRaSerial.println("A"); // Semua komplit!
        
        StaticJsonDocument<100> doc;
        doc["type"]   = "history_complete";
        doc["lines"]  = receivedChunks;
        String jsonStr;
        serializeJson(doc, jsonStr);
        if (bleDeviceConnected) {
          pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
          pTxCharacteristic->notify();
          historySent = true;
        }
        
        expectedChunks = 0;
        receivedChunks = 0;
        memset(chunkReceived, 0, sizeof(chunkReceived)); // Reset
        
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        hapusLayarLCD();
        updateBarisLCD(0, "   SINKRONISASI SD  ");
        updateBarisLCD(1, "      SELESAI!      ");
        updateBarisLCD(2, "  Membuka Akses HP  ");
        updateBarisLCD(3, "  Silakan Tunggu..  ");
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        
        soundHistoryComplete();
        Serial.println("[LORA] History Selesai Sempurna! Kirim BLE...");
        delay(2000);
        pulihkanLayarUtama();
      } else {
        LoRaSerial.print("M:");
        LoRaSerial.println(missing);
        Serial.print("[LORA] Minta ulang baris: ");
        Serial.println(missing);
      }
      return;
    }

    // === TAMBAHAN UNTUK LIVE SINKRONISASI ===
    int recvIdx = -1;
    String payloadAsli = pesan;
    
    if (pesan.startsWith("L:")) {
      int firstColon = pesan.indexOf(':');
      int secondColon = pesan.indexOf(':', firstColon + 1);
      if (secondColon != -1) {
        recvIdx = pesan.substring(firstColon + 1, secondColon).toInt();
        payloadAsli = pesan.substring(secondColon + 1);
      }
    }

    if (!loraTerhubung) {
      loraTerhubung = true;
      Serial.println("\n[LORA] TERHUBUNG!");
    }
    waktuDataTerakhir = millis();
    dataCount++;

    String fields[CSV_FIELD_COUNT];
    int jumlahField = parseCSV(payloadAsli, fields, CSV_FIELD_COUNT);

    if (jumlahField != CSV_FIELD_COUNT) return;

    // 🔥 DEEP OPTIMIZATION: Zero-Allocation CRC Calculation
    uint8_t calcCrc = 0;
    for (int i = 0; i <= IDX_MODE_HEMAT; i++) {
      if (i > 0) calcCrc ^= ','; // Tambahkan koma pemisah secara virtual
      for (int j = 0; j < fields[i].length(); j++) {
        calcCrc ^= (uint8_t)fields[i].charAt(j);
      }
    }

    int recvCrc = fields[IDX_CRC].toInt();
    if (calcCrc != recvCrc) return;

    float suhu = fields[IDX_SUHU].toFloat();
    float humi = fields[IDX_HUMI].toFloat();
    float ph   = fields[IDX_PH].toFloat();
    float n    = fields[IDX_N].toFloat();
    float p    = fields[IDX_P].toFloat();
    float k    = fields[IDX_K].toFloat();
    float kond = fields[IDX_KOND].toFloat();

    activeNodeID = fields[IDX_NODE_ID];
    sdSiapTX = (fields[IDX_SD_FLAG] == "1");

    // ===============================================
    // PENCOCOKAN INDEKS DIMATIKAN (MODE PASIF)
    // ===============================================
    // Gateway tidak peduli lagi apakah indeks datanya tertinggal dari Node atau tidak.
    // Apapun yang datang, langsung balas ACK (A) dan simpan secara membabi-buta!
    LoRaSerial.println("A");
    simpanKeSDGateway(payloadAsli);

    tampilkanDataLCD(fields);
    soundDataReceived();

    String tgl = fields[IDX_TANGGAL];
    String wkt = fields[IDX_WAKTU];
    int dd=0, MM=0, yyyy=0, hh=0, mm=0, ss=0;
    
    // Cegah parsing jika formatnya rusak / berisi strip dari Node
    if (tgl.indexOf('-') == -1) {
      sscanf(tgl.c_str(), "%d/%d/%d", &dd, &MM, &yyyy);
    } else {
      dd = 1; MM = 1; yyyy = 1970;
    }
    sscanf(wkt.c_str(), "%d:%d:%d", &hh, &mm, &ss);
    
    char timestampBuf[25];
    snprintf(timestampBuf, sizeof(timestampBuf), "%04d-%02d-%02dT%02d:%02d:%02d", yyyy, MM, dd, hh, mm, ss);

    bool nodeModeHemat = (fields[IDX_MODE_HEMAT] == "1");

    StaticJsonDocument<512> doc;
    doc["node_id"]     = activeNodeID;
    doc["timestamp"]   = timestampBuf;
    doc["temperature"] = suhu;
    doc["humidity"]    = humi;
    doc["ec"]          = kond / 1000.0;
    doc["ph"]          = ph;
    doc["nitrogen"]    = n;
    doc["phosphorus"]  = p;
    doc["kalium"]      = k;
    doc["sd"]          = sdSiapTX;
    doc["mode_hemat"]  = nodeModeHemat;
    doc["lora"]        = loraTerhubung;
    doc["status"]      = "connected";

    String jsonStr;
    serializeJson(doc, jsonStr);

    if (bleDeviceConnected) {
      pTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
      pTxCharacteristic->notify();
    }
  }
}
