// ============================================================
//  NODE (TRANSMITTER) - Flood2Food  [FINAL UPDATE]
//  - Normal: 5 detik, Hemat: 20 menit
//  - 1 File CSV (data_npk.csv)
//  - Fix RTC Sync
// ============================================================

#include <HardwareSerial.h>
#include <ModbusMaster.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <SPI.h>
#include <SD.h>
#include <RTClib.h>
#include <esp_task_wdt.h>
#include <esp_sleep.h>
#include <esp_idf_version.h>
#include <esp_timer.h>
#include <rom/rtc.h>
#include "driver/gpio.h"
#include "driver/rtc_io.h"
#include <Preferences.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ==================================================================
// ðŸ› ï¸ BAGIAN SETTINGAN (UBAH DI SINI SAJA)
// ==================================================================

#define NODE_ID           "N01"
#define DISPLAY_HOLD_SEC  10      
#define USE_AUTO_PURGE    0

#define NORMAL_INTERVAL_SEC_DEFAULT  20      // â­ Default Mode Normal: 20 detik
#define HEMAT_INTERVAL_SEC_DEFAULT   1200    // â­ Default Mode Hemat Daya: 20 menit (1200 detik)
#define NORMAL_TIMEOUT_MENIT 60      // â­ Auto-Timeout Mode Normal: 60 Menit lalu kembali ke Hemat Daya


#define USE_WATCHDOG       0
#define WDT_TIMEOUT_SEC    30

#define ERROR_RESTART_COUNT 5

// ==================== PIN ====================
#define RXD2 14
#define TXD2 27
#define RX_LORA 33
#define TX_LORA 26
#define RS485_DE_RE 4
#define SD_CS 5
#define PIN_BUZZER_1 32
#define PIN_BUZZER_2 2
#define LORA_M0_PIN    13
#define LORA_M1_PIN    15
#define PIN_LED_STATUS 12
#define PIN_TOMBOL_MODE 25
#define PIN_AUX 34

#define LORA_TX_DELAY_MS    200
#define LORA_ACK_WAIT_MS    800
#define LORA_ACK_TIMEOUT_MS 100
#define LORA_MAX_MISSED      3
#define LORA_MAX_RETRIES     2
#define LORA_MODE_SWITCH_MS 50
#define MODBUS_RETRIES      3
#define MODBUS_RETRY_DELAY  100
#define SD_RETENTION_DAYS   30

// #################################################################
// ##   BAGIAN KALIBRASI - UBAH OFFSET DI SINI SAJA               ##
// #################################################################
// Gunakan 'const' agar tidak bisa dimodifikasi secara tidak sengaja di tempat lain.
// Untuk mengubah nilai, edit di sini saja lalu flash ulang.
const float CAL_TEMP_OFFSET = 0.0;
const float CAL_HUMI_OFFSET = 0.0;
const float CAL_COND_OFFSET = 0.0;
const float CAL_PH_OFFSET   = 0.0;
const float CAL_N_OFFSET    = 0.0;
const float CAL_P_OFFSET    = 0.0;
const float CAL_K_OFFSET    = -700.0;
// #################################################################

HardwareSerial ModbusSerial(2);
HardwareSerial LoRaSerial(1);
ModbusMaster node;
LiquidCrystal_I2C lcd(0x27, 20, 4);
RTC_DS1307 rtc;
Preferences preferences;
SemaphoreHandle_t lcdMutex = NULL;

RTC_DATA_ATTR bool     rtcSiap         = false;
RTC_DATA_ATTR bool     loraTerhubung   = false;
RTC_DATA_ATTR bool     lastLoraStatus  = false;
RTC_DATA_ATTR int      loraMissedCount = 0;
RTC_DATA_ATTR uint32_t loopCount       = 0;
RTC_DATA_ATTR int      errorCount      = 0;
RTC_DATA_ATTR uint64_t fallbackEpoch   = 0;
RTC_DATA_ATTR bool     historySent     = false;
RTC_DATA_ATTR int      globalLineIndex = -1; // -1 means uninitialized

unsigned long lastSensorReadMillis = 0;

// --- PROTOTIPE FUNGSI ---
void toggleModeAction();
void pulihkanLayarUtama();
void tampilkanDataLCD(float ph, float suhu, float humi, float n, float p, float k, float kond);
void soundBleConnect();
void soundBleDisconnect();

// ==================== BLE UUID (SAMA SEPERTI GATEWAY) ====================
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer *pNodeServer = NULL;
BLECharacteristic *pNodeTxCharacteristic = NULL;
BLECharacteristic *pNodeRxCharacteristic = NULL;
bool nodeBleConnected = false;
bool nodeOldBleConnected = false;
unsigned long lastAdvCheckNode = 0;
bool nodeWaitingForHistory = false;
bool cancelHistory = false; // Flag pembatalan dari HP

bool modeHematDaya = false; 
volatile bool modeKalibrasi = false;
volatile bool forceReadSensor = false;
uint64_t normalModeStartUs = 0;
bool silentWake = false; 
bool ghostWake = false; 
bool sdSiap = false;
bool isSyncing = false; // Flag khusus agar sinkronisasi dan pembacaan sensor tidak tabrakan
bool peripheralsInited = false;
bool isTimeSynced = false;
uint32_t syncedEpochOffset = 0;
char namaFileHariIni[24] = "/data_npk.csv"; 
char strTanggal[11];
char strWaktu[9];

// â­ Interval yang bisa diatur dari App (persistent via Preferences)
uint32_t normalIntervalSec = NORMAL_INTERVAL_SEC_DEFAULT;
uint32_t hematIntervalSec  = HEMAT_INTERVAL_SEC_DEFAULT;

class MyNodeServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    nodeBleConnected = true;
    nodeWaitingForHistory = false;
    soundBleConnect();
    Serial.printf("[BLE] Perangkat terhubung! Total koneksi: %d\n", pServer->getConnectedCount());
  }

  void onDisconnect(BLEServer *pServer) {
    // ðŸ”¥ BUG FIX: Kill-Switch Mutlak!
    nodeBleConnected = false;
    nodeWaitingForHistory = false;
    cancelHistory = true; 
    modeKalibrasi = false; // Batalkan mode kalibrasi jika HP terputus
    soundBleDisconnect();
    Serial.println(F("[BLE] HP terputus! Memicu Kill-Switch SD Card..."));
  }
};

// --- DEKLARASI FUNGSI SUARA ---
void soundBoot();
void soundSensorSuccess();
void soundLoRaSuccess();
void soundError();
void soundSleep(bool toHemat);
void soundBleConnect();
void soundBleDisconnect();
void soundCalibStart();
void soundCalibRead();
void soundCalibStop();
void soundLoRaConnect();
void soundLoRaDisconnect();
void soundSDError();
void soundSDFormat();
void formatSDCard();

class MyNodeRXCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue().c_str();
      rxValue.trim();
      if (rxValue == "SEND_HISTORY" || rxValue == "H" || rxValue == "H_ALL") {
        if (rxValue == "H_ALL") {
          preferences.putUInt("last_sd_pos", 0);
          Serial.println("[BLE CMD] HP memaksa Tarik SEMUA History (Posisi di-reset ke 0)!");
        }
        nodeWaitingForHistory = true;
        Serial.println("[BLE CMD] HP meminta History secara langsung!");
      } else if (rxValue == "DELETE_SD_NODE") {
        Serial.println("[BLE CMD] Perintah Hapus SD Card Node diterima!");
        formatSDCard();
      } else if (rxValue == "DELETE_SD_GATEWAY") {
        Serial.println("[BLE CMD] Perintah Hapus SD Card Gateway dari HP. Meneruskan ke Gateway...");
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        delay(1500);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        LoRaSerial.println("DELETE_SD_GATEWAY");
        pulihkanLayarUtama();
      } else if (rxValue == "TOGGLE_MODE") {
        Serial.println(F("[BLE] Menerima instruksi Ganti Mode secara Remote!"));
        toggleModeAction();
      } else if (rxValue == "ABORT") {
        cancelHistory = true;
        Serial.println("[BLE CMD] HP membatalkan sinkronisasi SD Card!");
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F("   SINKRONISASI SD  "));
        lcd.setCursor(0, 1); lcd.print(F("     DIBATALKAN     "));
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        delay(2000);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        pulihkanLayarUtama();
      } else if (rxValue.startsWith("TIME:")) {
        uint32_t epoch = rxValue.substring(5).toInt();
        if (epoch > 1700000000) {
          syncedEpochOffset = epoch - (esp_timer_get_time() / 1000000ULL);
          isTimeSynced = true;
          if (rtcSiap) {
            rtc.adjust(DateTime(epoch));
          }
          Serial.printf("[BLE] Waktu disinkronkan dari HP (Epoch): %lu\n", epoch);
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.clear();
          lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
          lcd.setCursor(0, 1); lcd.print(F("  Sinkronisasi Waktu"));
          lcd.setCursor(0, 2); lcd.print(F("      Berhasil!     "));
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          delay(1500);
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          pulihkanLayarUtama();
        }
      } else if (rxValue == "CALIB_START") {
        modeKalibrasi = true;
        forceReadSensor = false;
        Serial.println("[BLE CMD] Masuk Mode Kalibrasi Lahan!");
        soundCalibStart();
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.backlight();
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("   MODE KALIBRASI   "));
        lcd.setCursor(0, 2); lcd.print(F("       LAHAN        "));
        lcd.setCursor(0, 3); lcd.print(F(" Menunggu perintah. "));
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      } else if (rxValue == "CALIB_STOP") {
        modeKalibrasi = false;
        Serial.println("[BLE CMD] Keluar Mode Kalibrasi!");
        soundCalibStop();
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("  Kalibrasi Selesai "));
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        delay(1500);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        pulihkanLayarUtama();
      } else if (rxValue == "CALIB_READ") {
        if (modeKalibrasi) {
          forceReadSensor = true;
          Serial.println("[BLE CMD] Mengambil Data Kalibrasi!");
          soundCalibRead();
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.clear();
          lcd.setCursor(0, 1); lcd.print(F(" Mengambil Data...  "));
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        }
      } else if (rxValue.startsWith("SET_INTERVAL:")) {
        int firstColon = rxValue.indexOf(':');
        int secondColon = rxValue.indexOf(':', firstColon + 1);
        if (firstColon > 0 && secondColon > 0) {
          uint32_t valNormal = rxValue.substring(firstColon + 1, secondColon).toInt();
          uint32_t valHemat = rxValue.substring(secondColon + 1).toInt();
          if (valNormal >= 5 && valNormal <= 3600 && valHemat >= 60 && valHemat <= 86400) {
            normalIntervalSec = valNormal;
            hematIntervalSec = valHemat;
            preferences.putUInt("itvlNormal", valNormal);
            preferences.putUInt("itvlHemat", valHemat);
            Serial.printf("[BLE CMD] Interval diubah -> Normal: %lu s, Hemat: %lu s\n", valNormal, valHemat);
            if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
            lcd.clear();
            lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
            lcd.setCursor(0, 1); lcd.print(F("  Set Interval OK!  "));
            lcd.setCursor(0, 2); 
            lcd.print(F(" Normal : ")); lcd.print(valNormal); lcd.print(F(" dtk"));
            lcd.setCursor(0, 3);
            lcd.print(F(" Hemat  : ")); lcd.print(valHemat / 60); lcd.print(F(" mnt"));
            if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
            delay(1500);
            pulihkanLayarUtama();
          }
        }
      }
    }
};

void initBLE() {
  BLEDevice::init("Flood2Food_Node");
  BLEDevice::setMTU(517);
  pNodeServer = BLEDevice::createServer();
  pNodeServer->setCallbacks(new MyNodeServerCallbacks());

  BLEService *pService = pNodeServer->createService(SERVICE_UUID);

  pNodeTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pNodeTxCharacteristic->addDescriptor(new BLE2902());

  pNodeRxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE
  );
  pNodeRxCharacteristic->setCallbacks(new MyNodeRXCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Node BLE Siap (Flood2Food_Node), menunggu koneksi...");
}

void safeDelay(unsigned long ms) {
  unsigned long start = millis();
  while (millis() - start < ms) {
#if USE_WATCHDOG
    esp_task_wdt_reset();
#endif
    delay(10);
  }
}

void wdtReset() {
#if USE_WATCHDOG
  esp_task_wdt_reset();
#endif
}

unsigned long lastBlinkTime = 0;
bool ledState = false;

void updateLED(int mode) {
  unsigned long now = millis();
  int interval = 0;
  switch(mode) {
    case 0: digitalWrite(PIN_LED_STATUS, LOW); return;
    case 1: digitalWrite(PIN_LED_STATUS, HIGH); return;
    case 2: interval = 500; break;
    case 3: interval = 100; break;
    case 4: interval = 200; break;
  }
  if (interval > 0) {
    if (now - lastBlinkTime >= interval) {
      lastBlinkTime = now;
      ledState = !ledState;
      digitalWrite(PIN_LED_STATUS, ledState ? HIGH : LOW);
    }
  }
}

void printResetReason() {
  RESET_REASON reason = rtc_get_reset_reason(0);
  Serial.print(F(">>> RESET REASON (CPU0): "));
  switch (reason) {
    case POWERON_RESET:          Serial.println(F("POWERON")); break;
    case SW_RESET:               Serial.println(F("SW_RESET")); break;
    case DEEPSLEEP_RESET:        Serial.println(F("DEEPSLEEP wake")); break;
    case TG0WDT_SYS_RESET:       Serial.println(F("TG0WDT")); break;
    case TGWDT_CPU_RESET:        Serial.println(F("TGWDT")); break;
    case RTCWDT_BROWN_OUT_RESET: Serial.println(F("BROWNOUT!")); break;
    case SW_CPU_RESET:           Serial.println(F("SW_CPU (Auto-Reset)")); break;
    default:                     Serial.println(F("OTHER")); break;
  }
}

void preTransmission()  { delayMicroseconds(500); }
void postTransmission() { delayMicroseconds(500); }

void flushModbus() {
  while (ModbusSerial.available() > 0) ModbusSerial.read();
}

uint8_t readSensorWithRetry() {
  uint8_t result = 0;
  for (int retry = 0; retry < MODBUS_RETRIES; retry++) {
    flushModbus();
    result = node.readHoldingRegisters(0x0000, 7);
    if (result == node.ku8MBSuccess) {
      return result;
    }
    safeDelay(MODBUS_RETRY_DELAY);
  }
  return result;
}

#define NOTE_C4  262
#define NOTE_D4  294
#define NOTE_E4  330
#define NOTE_F4  349
#define NOTE_G4  392
#define NOTE_A4  440
#define NOTE_B4  494
#define NOTE_C5  523
#define NOTE_D5  587
#define NOTE_E5  659
#define NOTE_F5  698
#define NOTE_G5  784
#define NOTE_A5  880
#define NOTE_B5  988
#define NOTE_C6  1047
#define NOTE_CS6 1109
#define NOTE_D6  1175
#define NOTE_DS6 1245
#define NOTE_E6  1319
#define NOTE_F6  1397
#define NOTE_FS6 1480
#define NOTE_G6  1568
#define NOTE_A6  1760
#define NOTE_AS6 1865
#define NOTE_B6  1976
#define NOTE_C7  2093
#define NOTE_E7  2637
#define NOTE_G7  3136
#define NOTE_AS5 932
#define NOTE_DS5 622

#define REST 0

void initBuzzer() {
  pinMode(PIN_BUZZER_1, OUTPUT);
  pinMode(PIN_BUZZER_2, OUTPUT);
  noTone(PIN_BUZZER_1);
  noTone(PIN_BUZZER_2);
}

void _play(int mel, int harm, int durMs, int gapMs = 0) {
  if (mel > 0) tone(PIN_BUZZER_1, mel); else noTone(PIN_BUZZER_1);
  if (harm > 0) tone(PIN_BUZZER_2, harm); else noTone(PIN_BUZZER_2);
  safeDelay(durMs);
  noTone(PIN_BUZZER_1);
  noTone(PIN_BUZZER_2);
  if (gapMs > 0) safeDelay(gapMs);
}

void soundBoot() {
  Serial.println(F(">> Sound: Boot (The Orchestral Awakening)..."));
  _play(REST,     NOTE_C5, 60, 0); 
  _play(NOTE_G6,  REST,    60, 0); 
  _play(REST,     NOTE_E5, 60, 0); 
  _play(NOTE_C7,  REST,    60, 0); 
  _play(REST,     NOTE_G5, 60, 0); 
  _play(NOTE_E7,  REST,    60, 0); 
  _play(NOTE_C7,  NOTE_C6, 600, 0); 
}

void soundSensorSuccess() {
  Serial.println(F(">> Sound: Sensor Success (Harvest Complete)..."));
  _play(NOTE_C6, NOTE_C5, 50, 0);
  _play(NOTE_E6, NOTE_E5, 50, 0);
  _play(NOTE_G6, NOTE_G5, 50, 0);
  _play(NOTE_C7, NOTE_C6, 100, 0);
}

void soundLoRaSuccess() {
  Serial.println(F(">> Sound: LoRa Sent (Transmission Sent)..."));
  _play(NOTE_C7, NOTE_C7+4, 30, 20);
  _play(NOTE_E7, NOTE_E7+4, 30, 20);
  _play(NOTE_G7, NOTE_G7+4, 100, 0);
}

void soundError() {
  Serial.println(F(">> Sound: Error (System Fault)..."));
  for(int i=0; i<2; i++) {
    _play(NOTE_DS6, NOTE_C6, 100, 0); 
    _play(NOTE_C6,  NOTE_A5, 100, 0); 
    _play(NOTE_G5,  NOTE_DS5, 150, 50); 
  }
}

void soundSleep(bool toHemat) {
  Serial.println(toHemat ? F(">> Sound: Sleep (The Fall)...") : F(">> Sound: Wake (Ascend)..."));
  if (toHemat) {
    _play(NOTE_E6, NOTE_C6, 100, 0); 
    _play(NOTE_D6, NOTE_B5, 120, 0);
    _play(NOTE_C6, NOTE_A5, 140, 0); 
    _play(NOTE_B5, NOTE_G5, 160, 0); 
    _play(NOTE_A5, NOTE_F5, 400, 0); 
  } else {
    _play(NOTE_A5, NOTE_F5, 140, 0); 
    _play(NOTE_C6, NOTE_A5, 120, 0); 
    _play(NOTE_E6, NOTE_C6, 100, 0); 
    _play(NOTE_G6, NOTE_E6, 80, 0); 
    _play(NOTE_C7, NOTE_G6, 200, 0); 
  }
}

void soundBleConnect() {
  Serial.println(F(">> Sound: BLE Connected (Digital Handshake)..."));
  _play(NOTE_C6, NOTE_A5, 80, 20); 
  _play(REST,    NOTE_A5, 80, 20); 
  _play(NOTE_E6, NOTE_A5, 80, 20); 
  _play(REST,    NOTE_A5, 80, 20); 
  _play(NOTE_G6, NOTE_E5, 300, 0); 
}

void soundBleDisconnect() {
  Serial.println(F(">> Sound: BLE Disconnected (Signal Lost Elegy)..."));
  _play(NOTE_E6, NOTE_A5, 80, 0); 
  _play(NOTE_D6, REST,    100, 0);
  _play(NOTE_C6, NOTE_G5, 130, 0); 
  _play(NOTE_B5, REST,    160, 0);
  _play(NOTE_A5, NOTE_F5, 400, 0); 
}

void soundCalibStart() {
  Serial.println(F(">> Sound: Calib Start (System Initialization)..."));
  _play(REST,    NOTE_C5, 80, 0);
  _play(REST,    NOTE_E5, 80, 0);
  _play(NOTE_C6, NOTE_G5, 80, 0);
  _play(NOTE_E6, NOTE_C6, 80, 0);
  _play(NOTE_C7, NOTE_E6, 200, 0);
}

void soundCalibRead() {
  Serial.println(F(">> Sound: Calib Read (Neural Scan Active)..."));
  _play(NOTE_C7, NOTE_C7+5, 20, 10);
  _play(NOTE_E7, NOTE_E7+5, 20, 10);
  _play(NOTE_G7, NOTE_G7+5, 20, 10);
  _play(NOTE_C7, NOTE_C7+5, 40, 0);
}

void soundCalibStop() {
  Serial.println(F(">> Sound: Calib Stop (Analysis Complete)..."));
  _play(NOTE_E6, NOTE_C6, 80, 0);
  _play(NOTE_C6, NOTE_G5, 80, 0);
  _play(NOTE_G5, NOTE_E5, 150, 0);
  _play(REST,    REST,    50, 0);
  _play(NOTE_C7, NOTE_G5, 40, 30);
  _play(NOTE_C7, NOTE_G5, 60, 0);
}

void soundLoRaConnect() {
  Serial.println(F(">> Sound: LoRa Connected (Link Established)..."));
  _play(NOTE_E6, NOTE_E5, 60, 20);
  _play(NOTE_G6, NOTE_G5, 60, 20);
  _play(NOTE_C7, NOTE_C6, 150, 0);
}

void soundLoRaDisconnect() {
  Serial.println(F(">> Sound: LoRa Disconnect (Link Severed)..."));
  _play(NOTE_C7, NOTE_FS6, 100, 20); 
  _play(NOTE_B6, NOTE_F6,  100, 20); 
  _play(NOTE_AS6,NOTE_E6,  200, 0);
}

void soundSDError() {
  soundError(); // Fallback ke error sound
}

void soundSDFormat() {
  for(int i=0; i<3; i++) {
    _play(NOTE_C7, NOTE_A6, 100, 20);
    _play(NOTE_CS6,NOTE_AS6, 100, 100);
  }
}

void ambilWaktuRTC() {
  if (rtcSiap) {
    DateTime now = rtc.now();
    sprintf(strTanggal, "%02d/%02d/%04d", now.day(), now.month(), now.year());
    sprintf(strWaktu,   "%02d:%02d:%02d", now.hour(), now.minute(), now.second());
  } else if (isTimeSynced) {
    uint32_t currentEpoch = syncedEpochOffset + (esp_timer_get_time() / 1000000ULL);
    DateTime now(currentEpoch); 
    sprintf(strTanggal, "%02d/%02d/%04d", now.day(), now.month(), now.year());
    sprintf(strWaktu,   "%02d:%02d:%02d", now.hour(), now.minute(), now.second());
  } else {
    uint64_t now = esp_timer_get_time() + fallbackEpoch;
    unsigned long detik = (unsigned long)(now / 1000000ULL);
    unsigned long menit = detik / 60;
    unsigned long jam   = menit / 60;
    sprintf(strTanggal, "--/--/----");
    sprintf(strWaktu,   "%02lu:%02lu:%02lu", jam, menit % 60, detik % 60);
  }
}

void updateNamaFile() {
  strcpy(namaFileHariIni, "/data_npk.csv");
}

void formatSDCard() {
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.clear();
  lcd.setCursor(0, 1); lcd.print(F(" Menghapus SD Card.."));
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  
  Serial.println(F("[SD] Memulai penghapusan data SD Card..."));
  
  if (SD.cardType() == CARD_NONE) {
    Serial.println(F("[SD] Error: SD Card Node tidak terdeteksi!"));
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    lcd.setCursor(0, 1); lcd.print(F(" Gagal Format SD! "));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    soundSDError();
    
    if (nodeBleConnected && pNodeTxCharacteristic) {
      StaticJsonDocument<50> doc;
      doc["type"] = "error";
      String jsonStr;
      serializeJson(doc, jsonStr);
      pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
      pNodeTxCharacteristic->notify();
    } else {
      LoRaSerial.println("SD_ERROR_NODE");
    }
    delay(2000);
    pulihkanLayarUtama();
    return;
  }

  if (SD.exists(namaFileHariIni)) {
    SD.remove(namaFileHariIni);
  }
  
  preferences.putUInt("last_sd_pos", 0);
  globalLineIndex = 0;
  
  soundSDFormat();
  Serial.println(F("[SD] Data SD Card berhasil dihapus dan index direset."));
  
  if (nodeBleConnected && pNodeTxCharacteristic != NULL) {
    StaticJsonDocument<50> doc;
    doc["type"] = "success";
    String jsonStr;
    serializeJson(doc, jsonStr);
    pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
    pNodeTxCharacteristic->notify();
  } else {
    LoRaSerial.println("SD_SUCCESS_NODE");
  }

  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
  lcd.setCursor(0, 1); lcd.print(F("  SD Card Bersih!   "));
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  delay(1500);
  pulihkanLayarUtama();
}

void pastikanHeader(const char* fname) {
  if (SD.exists(fname)) {
    File f = SD.open(fname, FILE_READ);
    if (f && f.size() > 0) { f.close(); return; }
    if (f) f.close();
  }
  File f = SD.open(fname, FILE_WRITE);
  if (f) {
    f.println(F("Waktu,Tanggal,Suhu_C,Kelembaban_%,Konduktivitas_uS,pH,N_mgkg,P_mgkg,K_mgkg,LoRa_Status"));
    f.close();
  }
}

void purgeOldFiles() {}

void cekSDCard() {
  if (sdSiap) {
    File root = SD.open("/");
    if (root) { root.close(); return; }
    else { sdSiap = false; SD.end(); }
  }
  SPI.begin(18, 19, 23, SD_CS);
  if (SD.begin(SD_CS, SPI, 1000000)) {
    sdSiap = true;
    updateNamaFile();
    pastikanHeader(namaFileHariIni);
    purgeOldFiles();
    
    if (globalLineIndex == -1) {
      File f = SD.open(namaFileHariIni);
      if (f) {
        f.readStringUntil('\n'); 
        int lines = 0;
        while(f.available()) {
          if (f.read() == '\n') lines++;
        }
        f.close();
        globalLineIndex = lines;
      }
    }
  }
}

void simpanKeSD(float t, float h, float c, float p, float n, float p2, float k, bool ackOK) {
  File file = SD.open(namaFileHariIni, FILE_APPEND);
  if (!file) {
    file = SD.open(namaFileHariIni, FILE_WRITE);
    if (!file) return;
  }
  file.print(strWaktu);   file.print(",");
  file.print(strTanggal); file.print(",");
  file.print(t, 1);       file.print(",");
  file.print(h, 1);       file.print(",");
  file.print(c, 0);       file.print(",");
  file.print(p, 1);       file.print(",");
  file.print(n, 0);       file.print(",");
  file.print(p2, 0);      file.print(",");
  file.print(k, 0);       file.print(",");
  file.println(ackOK ? "ACK" : "FAIL");
  file.close();

  if (globalLineIndex != -1) {
    globalLineIndex++;
  }
}

int pendingSyncIndex = -1;

bool kirimLoRa(const char* data) {
  for (int attempt = 0; attempt <= LORA_MAX_RETRIES; attempt++) {
    while (LoRaSerial.available() > 0) LoRaSerial.read();
    LoRaSerial.println(data);
    safeDelay(LORA_TX_DELAY_MS);
    LoRaSerial.setTimeout(LORA_ACK_TIMEOUT_MS);

    unsigned long ackStart = millis();
    while ((millis() - ackStart) < LORA_ACK_WAIT_MS) {
      if (LoRaSerial.available() > 0) {
        String msg = LoRaSerial.readStringUntil('\n');
        msg.trim();
        if (msg == "A") return true;
        
        if (msg.startsWith("SYNC:")) {
          pendingSyncIndex = msg.substring(5).toInt();
          return true; 
        }
      }
      wdtReset();
    }
    if (attempt < LORA_MAX_RETRIES) {
      safeDelay(500);
    }
  }
  return false;
}

void tampilkanProgressHistoryNode(int current, int total) {
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, 0); lcd.print("   SINKRONISASI SD  ");
  lcd.setCursor(0, 1); lcd.print("  Mengirim Data...  ");
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  
  char buf[21];
  snprintf(buf, sizeof(buf), "  Blok: %d/%d         ", current, total);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, 2); lcd.print(buf);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);

  int numBars = (current * 20) / total;
  char bar[21];
  for (int i = 0; i < 20; i++) {
    if (i < numBars) bar[i] = '=';
    else if (i == numBars) bar[i] = '>';
    else bar[i] = '.';
  }
  bar[20] = '\0'; 
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, 3); lcd.print(bar);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}

bool kirimHistorySD(int startIdx = -1) {
  isSyncing = true; 
  cancelHistory = false; 
  Serial.println(F(">> Kirim History SD (Burst Line Protocol)..."));
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.backlight(); 
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("   SINKRONISASI SD  ");
  lcd.setCursor(0, 1); lcd.print(" Menghitung Baris.. ");
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  safeDelay(500);

  File file = SD.open(namaFileHariIni);
  if (!file) {
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 2); lcd.print(F("SD Gagal Dibuka    "));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    safeDelay(1500);
    isSyncing = false;
    return false;
  }

  uint32_t last_sd_pos = preferences.getUInt("last_sd_pos", 0);
  if (startIdx == -1 && last_sd_pos > 0 && last_sd_pos <= file.size()) {
    file.seek(last_sd_pos);
  } else {
    file.readStringUntil((char)10); 
  }

  uint32_t start_pos = file.position();
  
  int totalLines = 0;
  while (file.available()) {
    if (file.read() == (char)10) totalLines++;
  }
  
  if (totalLines <= 0) {
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 2); lcd.print(F("SD Kosong/Selesai  ")); 
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    file.close();
    if (nodeBleConnected && pNodeTxCharacteristic) {
      StaticJsonDocument<100> doc;
      doc["type"]   = "history_complete";
      doc["lines"]  = 0;
      String jsonStr;
      serializeJson(doc, jsonStr);
      pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
      pNodeTxCharacteristic->notify();
    } else {
      for (int r = 0; r < 3; r++) {
        LoRaSerial.println("B_END:0");
        safeDelay(300);
      }
    }
    loraMissedCount = 0;
    loraTerhubung = true;
    isSyncing = false;
    return true;
  }

  bool isUsingBLE = (nodeBleConnected && pNodeTxCharacteristic != NULL);
  
  if (!isUsingBLE && totalLines > 2000) {
    totalLines = 2000; 
  }

  bool acked = false;
  int retryBurst = 0;
  String missingLines = ""; 

  while (!acked && retryBurst < 5) {
    file.seek(start_pos);
    int currentLine = 0;
    
    String bleBuffer = "";
    int bleStartIdx = -1;
    
    bool sendAll = (missingLines == "");
    int nextMissing = -1;
    int missingCursor = 0;
    if (!sendAll) {
      int comma = missingLines.indexOf(',', missingCursor);
      if (comma != -1) {
        nextMissing = missingLines.substring(missingCursor, comma).toInt();
        missingCursor = comma + 1;
      } else {
        nextMissing = missingLines.substring(missingCursor).toInt();
        missingCursor = missingLines.length();
      }
    }

    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 1); lcd.print(sendAll ? "  Kirim Burst...    " : "  Kirim Retransmit! ");
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);

    while (file.available() && currentLine < totalLines) {
        String line = file.readStringUntil((char)10);
        line.trim();
        if (line.length() == 0) continue;
        int lastCommaIdx = line.lastIndexOf(',');
        if (lastCommaIdx != -1) {
          line = line.substring(0, lastCommaIdx);
        }
      
      bool shouldSend = false;
      if (startIdx != -1) {
        if (currentLine >= startIdx) shouldSend = true;
      } else if (sendAll) {
        shouldSend = true;
      } else if (currentLine == nextMissing) {
        shouldSend = true;
        if (missingCursor < missingLines.length()) {
          int comma = missingLines.indexOf(',', missingCursor);
          if (comma != -1) {
            nextMissing = missingLines.substring(missingCursor, comma).toInt();
            missingCursor = comma + 1;
          } else {
            nextMissing = missingLines.substring(missingCursor).toInt();
            missingCursor = missingLines.length();
          }
        }
      }

      if (shouldSend && line.length() > 5) {
        if (isUsingBLE) {
          if (!nodeBleConnected || cancelHistory) {
            file.close();
            isSyncing = false;
            return false;
          }

          String cleanLine = line;

          if (bleBuffer.length() == 0) bleStartIdx = currentLine;
          bleBuffer += cleanLine + "|";

          if (bleBuffer.length() >= 420 || currentLine == totalLines - 1) {
            StaticJsonDocument<768> doc;
            doc["type"] = "chunk";
            doc["idx"] = bleStartIdx; 
            doc["total"] = totalLines;
            doc["data"] = bleBuffer; 
            String jsonStr;
            serializeJson(doc, jsonStr);
            pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
            pNodeTxCharacteristic->notify();
            bleBuffer = "";
            wdtReset(); 
            delay(1); // Ultra-fast yield
          }
        } else {
          if (LoRaSerial.available() > 0) {
            String rxCmd = LoRaSerial.readStringUntil((char)10);
            rxCmd.trim();
            if (rxCmd == "ABORT" || rxCmd.indexOf("ABORT") >= 0) {
              file.close();
              isSyncing = false;
              return false;
            }
          }

          unsigned long waitAux = millis();
          while (digitalRead(PIN_AUX) == LOW) {
            if (millis() - waitAux > 3000) break; 
            wdtReset();
            delay(1);
          }
          
          LoRaSerial.print("B:");
          LoRaSerial.print(currentLine);
          LoRaSerial.print(":");
          LoRaSerial.print(totalLines);
          LoRaSerial.print(":");
          LoRaSerial.print(line);
          LoRaSerial.println("|");
          LoRaSerial.flush();
        }
        
        if (currentLine % 50 == 0 || currentLine == totalLines - 1) {
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          char buf[21];
          snprintf(buf, sizeof(buf), "  Baris: %d/%d      ", currentLine + 1, totalLines);
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.setCursor(0, 2); lcd.print(buf);
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          int numBars = (currentLine * 20) / totalLines;
          char bar[21];
          for (int i = 0; i < 20; i++) {
            bar[i] = (i < numBars) ? '=' : ((i == numBars) ? '>' : '.');
          }
          bar[20] = '\0'; 
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.setCursor(0, 3); lcd.print(bar);
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        }
      }
      currentLine++;
    }
    
    uint32_t final_pos = file.position(); 
    
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 2); lcd.print(F("Tunggu Konfirmasi.."));
    lcd.setCursor(0, 3); lcd.print(F("                   "));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    
    if (isUsingBLE) {
      StaticJsonDocument<100> doc;
      doc["type"]   = "history_complete";
      doc["lines"]  = totalLines;
      String jsonStr;
      serializeJson(doc, jsonStr);
      pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
      pNodeTxCharacteristic->notify();
      acked = true; 
    } else {
      for (int r = 0; r < 3; r++) {
        LoRaSerial.print("B_END:");
        LoRaSerial.println(totalLines);
        safeDelay(500);
      }
      
      unsigned long startAck = millis();
      missingLines = "";
      bool gotReply = false;
      
      while (millis() - startAck < 8000) { 
        if (LoRaSerial.available() > 0) {
          String ackMsg = LoRaSerial.readStringUntil((char)10);
          ackMsg.replace("\r", "");
          ackMsg.trim();
          
          if (ackMsg == "A") { 
            acked = true; 
            gotReply = true;
            if (sendAll) preferences.putUInt("last_sd_pos", final_pos); 
            break; 
          }
          else if (ackMsg.startsWith("M:")) {
            missingLines = ackMsg.substring(2);
            gotReply = true;
            break; 
          }
          else if (ackMsg == "ABORT" || ackMsg.indexOf("ABORT") >= 0) {
            file.close();
            isSyncing = false;
            return false;
          }
        }
        wdtReset();
        delay(10);
      }
      
      if (!gotReply) {
        missingLines = "";
      }
    }
    
    retryBurst++;
  }

  file.close();
  
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.clear();
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  if (acked) {
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 0); lcd.print("   SINKRONISASI SD  ");
    lcd.setCursor(0, 1); lcd.print("      SELESAI!      ");
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  } else {
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 0); lcd.print("   SINKRONISASI SD  ");
    lcd.setCursor(0, 1); lcd.print("       GAGAL!       ");
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  }
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, 2); lcd.print("   Kembali ke Mode  ");
  lcd.setCursor(0, 3); lcd.print("      Normal...     ");
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  safeDelay(2000);

  loraMissedCount = 0;
  loraTerhubung = true;
  isSyncing = false; 
  return acked;
}

void updateLoRaStatus(bool ackOK) {
  if (ackOK) {
    loraMissedCount = 0;
    if (!loraTerhubung) {
      loraTerhubung = true;
      Serial.println(F("   >> LoRa: TERHUBUNG!"));
    }
  } else {
    loraMissedCount++;
    if (loraMissedCount >= LORA_MAX_MISSED) {
      if (loraTerhubung) {
        loraTerhubung = false;
        Serial.println(F("   >> LoRa: TERPUTUS!"));
      }
    }
  }
}

bool hasCachedLCDData = false;
float lastPhCal = 0, lastTempCal = 0, lastHumiCal = 0;
float lastNCal = 0, lastPCal = 0, lastKCal = 0, lastCondCal = 0;

void pulihkanLayarUtama() {
  if (hasCachedLCDData) {
    tampilkanDataLCD(lastPhCal, lastTempCal, lastHumiCal, lastNCal, lastPCal, lastKCal, lastCondCal);
  } else {
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  }
}

void tampilkanDataLCD(float ph, float suhu, float humi, float n, float p, float k, float kond) {
  lastPhCal = ph; lastTempCal = suhu; lastHumiCal = humi;
  lastNCal = n; lastPCal = p; lastKCal = k; lastCondCal = kond;
  hasCachedLCDData = true;

  char buf[21];
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.backlight();
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);

  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, 0); lcd.print("                    ");
  lcd.setCursor(0, 0);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  snprintf(buf, sizeof(buf), "%.8s  %.10s", strWaktu, strTanggal);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.print(buf);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);

  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, 1); lcd.print("                    ");
  lcd.setCursor(0, 1);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  snprintf(buf, sizeof(buf), "pH:%-4.1f T:%-4.1f H:%-2.0f%%", ph, suhu, humi);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.print(buf);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);

  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, 2); lcd.print("                    ");
  lcd.setCursor(0, 2);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  snprintf(buf, sizeof(buf), "N:%-3d P:%-3d K:%-3d", (int)n, (int)p, (int)k);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.print(buf);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);

  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, 3); lcd.print("                    ");
  lcd.setCursor(0, 3);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  snprintf(buf, sizeof(buf), "EC:%-4d SD:%c L:%c M:%c", 
           (int)kond, 
           sdSiap ? 'Y' : 'N', 
           loraTerhubung ? 'Y' : 'N', 
           modeHematDaya ? 'H' : 'N');
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.print(buf);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}

void initWatchdog() {
  if (USE_WATCHDOG) {
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 0, 0)
    esp_task_wdt_config_t twdt_config = {
        .timeout_ms = WDT_TIMEOUT_SEC * 1000,
        .idle_core_mask = (1 << portNUM_PROCESSORS) - 1,
        .trigger_panic = true,
    };
    esp_task_wdt_init(&twdt_config);
#else
    esp_task_wdt_init(WDT_TIMEOUT_SEC, true); 
#endif
    esp_task_wdt_add(NULL);
  }
}

void initPeripherals() {
  lcdMutex = xSemaphoreCreateRecursiveMutex();
  Serial.begin(115200);
  gpio_pulldown_dis((gpio_num_t)RXD2);
  gpio_pulldown_dis((gpio_num_t)TXD2);
  gpio_pulldown_dis((gpio_num_t)RX_LORA);
  gpio_pulldown_dis((gpio_num_t)TX_LORA);

  ModbusSerial.begin(9600, SERIAL_8N1, RXD2, TXD2);
  LoRaSerial.begin(9600, SERIAL_8N1, RX_LORA, TX_LORA);
  
  LoRaSerial.setTimeout(50);
  
  safeDelay(50);

  pinMode(RS485_DE_RE, OUTPUT);
  digitalWrite(RS485_DE_RE, LOW);

  pinMode(LORA_M0_PIN, OUTPUT);
  pinMode(LORA_M1_PIN, OUTPUT);
  digitalWrite(LORA_M0_PIN, LOW);
  digitalWrite(LORA_M1_PIN, LOW);

  pinMode(PIN_LED_STATUS, OUTPUT);
  digitalWrite(PIN_LED_STATUS, HIGH); 

  pinMode(PIN_TOMBOL_MODE, INPUT_PULLUP);
  initBuzzer();

  node.begin(1, ModbusSerial);
  node.preTransmission(preTransmission);
  node.postTransmission(postTransmission);

  Wire.begin(21, 22);
  Wire.setTimeOut(1000);
  safeDelay(50);
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.init();
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  
  peripheralsInited = true;
}

void shutdownPeripherals() {
  if (peripheralsInited) {
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    lcd.noBacklight();
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    SD.end();
    Wire.end();
    ModbusSerial.end();
    LoRaSerial.end();
    Serial.flush();
    Serial.end();
  }
  
  pinMode(RS485_DE_RE, INPUT);
  pinMode(TXD2, OUTPUT);
  digitalWrite(TXD2, HIGH);
  gpio_set_direction((gpio_num_t)RXD2, GPIO_MODE_INPUT);
  gpio_pulldown_dis((gpio_num_t)RXD2);
  gpio_pullup_dis((gpio_num_t)RXD2);
  
  gpio_set_direction((gpio_num_t)RX_LORA, GPIO_MODE_INPUT);
  gpio_set_direction((gpio_num_t)TX_LORA, GPIO_MODE_INPUT);
  gpio_pulldown_en((gpio_num_t)RX_LORA);
  gpio_pulldown_en((gpio_num_t)TX_LORA);
  gpio_pullup_dis((gpio_num_t)RX_LORA);
  gpio_pullup_dis((gpio_num_t)TX_LORA);
  
  noTone(PIN_BUZZER_1);
  pinMode(PIN_BUZZER_1, INPUT);
  noTone(PIN_BUZZER_2);
  pinMode(PIN_BUZZER_2, INPUT);
  digitalWrite(PIN_LED_STATUS, LOW);
  pinMode(PIN_LED_STATUS, INPUT);
}

void tampilkanLayarStandby() {
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(F("    NODE TIDUR      "));
  lcd.setCursor(0, 1); lcd.print(F(" (Mode Hemat Daya)  "));
  lcd.setCursor(0, 2); lcd.print(F(" Menunggu Jadwal... "));
  lcd.setCursor(0, 3); lcd.print(F("  Atau Tekan Mode   "));
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}

void toggleModeAction() {
  modeHematDaya = !modeHematDaya;
  preferences.putBool("modeHemat", modeHematDaya);
  
  // Pastikan backlight selalu nyala saat mode diubah agar teks terlihat
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.backlight();
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  
  if (modeHematDaya) {
    soundSleep(true);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
    lcd.setCursor(0, 1); lcd.print(F(">> MODE HEMAT DAYA<<"));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  } else {
    soundSleep(false);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
    lcd.setCursor(0, 1); lcd.print(F(" >> MODE NORMAL <<"));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  }
  delay(1500);
  pulihkanLayarUtama();
}

void setup() {
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();

  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT0) {
    rtc_gpio_deinit((gpio_num_t)PIN_TOMBOL_MODE);
    pinMode(PIN_TOMBOL_MODE, INPUT_PULLUP);
    delay(5); 
    
    if (digitalRead(PIN_TOMBOL_MODE) == HIGH) {
      masukLightSleep();
      return; 
    }
  }

  initPeripherals();
  printResetReason(); 
  safeDelay(200);
  initWatchdog();

  preferences.begin("flood2food", false); 
  
  preferences.remove("last_sd_pos"); 

  modeHematDaya = preferences.getBool("modeHemat", false); 
  normalIntervalSec = preferences.getUInt("itvlNormal", NORMAL_INTERVAL_SEC_DEFAULT);
  hematIntervalSec  = preferences.getUInt("itvlHemat",  HEMAT_INTERVAL_SEC_DEFAULT);
  if (!modeHematDaya) normalModeStartUs = esp_timer_get_time();

  rtc_gpio_deinit((gpio_num_t)LORA_M0_PIN);
  rtc_gpio_deinit((gpio_num_t)LORA_M1_PIN);
  if (wakeup_reason != ESP_SLEEP_WAKEUP_EXT0) {
    rtc_gpio_deinit((gpio_num_t)PIN_TOMBOL_MODE);
  }

  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
    silentWake = true;
    Serial.println(F(">> Bangun diam-diam dari Deep Sleep via LoRa AUX!"));
  } else if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT0) {
    toggleModeAction();
  }

  if (rtc.begin()) {
    String compileTime = String(__DATE__) + " " + String(__TIME__);
    String lastCompile = preferences.getString("lastCompile", "");
    
    if (compileTime != lastCompile || !rtc.isrunning()) {
      Serial.println(F(">> Kode baru terdeteksi! Menyamakan jam RTC..."));
      rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
      preferences.putString("lastCompile", compileTime);
    }
    rtcSiap = true;
  } else {
    rtcSiap = false;
  }

  if (wakeup_reason != ESP_SLEEP_WAKEUP_EXT1) {
    initBLE();
  }

  cekSDCard();

  if (wakeup_reason != ESP_SLEEP_WAKEUP_TIMER && wakeup_reason != ESP_SLEEP_WAKEUP_EXT0 && wakeup_reason != ESP_SLEEP_WAKEUP_EXT1) {
    soundBoot();
    digitalWrite(PIN_LED_STATUS, HIGH); 

    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.backlight();
    lcd.clear();
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    delay(50); 
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 0); lcd.print(F("   Flood2Food      "));
    lcd.setCursor(0, 1); lcd.print(F("      NODE         "));
    lcd.setCursor(0, 2); lcd.print(F("  NPK 7-in-1 Soil  "));
    lcd.setCursor(0, 3); lcd.print(F("  Booting...       "));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    safeDelay(1500);

    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    delay(50);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 0); lcd.print(F("Cek RTC DS1307...    "));
    lcd.setCursor(0, 1); lcd.print(rtcSiap ? F("RTC: OK!             ") : F("RTC: GAGAL!          "));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    safeDelay(800);

    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    delay(50);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 0); lcd.print(F("Cek SD Card...       "));
    lcd.setCursor(0, 1); lcd.print(sdSiap ? F("SD: OK               ") : F("SD: GAGAL!           "));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    safeDelay(800);

    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    delay(50);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 0); lcd.print(F("Node ID: ")); lcd.print(NODE_ID);
    lcd.setCursor(0, 1); lcd.print(F("Mode: "));
    if (modeHematDaya) lcd.print(F("HEMAT DAYA"));
    else lcd.print(F("NORMAL    "));
    lcd.setCursor(0, 2);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    if (modeHematDaya) {
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.print(F("Int: ")); lcd.print(hematIntervalSec / 60); lcd.print(F(" menit "));
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    } else {
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.print(F("Int: ")); lcd.print(normalIntervalSec); lcd.print(F(" detik "));
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    }
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 3);
    if (USE_WATCHDOG) lcd.print(F("WDT:ON ")); else lcd.print(F("WDT:OFF "));
    if (ERROR_RESTART_COUNT > 0) lcd.print(F("RST:ON ")); else lcd.print(F("RST:OFF"));
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    safeDelay(2000);

    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.clear();
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    delay(50);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.setCursor(0, 0); lcd.print(F("-- KALIBRASI --     "));
    lcd.setCursor(0, 1);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    char bufKal[21];
    snprintf(bufKal, sizeof(bufKal), "T:%+.1f H:%+.1f     ", CAL_TEMP_OFFSET, CAL_HUMI_OFFSET);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.print(bufKal);
    lcd.setCursor(0, 2);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    snprintf(bufKal, sizeof(bufKal), "Kd:%+.0f pH:%+.1f    ", CAL_COND_OFFSET, CAL_PH_OFFSET);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.print(bufKal);
    lcd.setCursor(0, 3);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    snprintf(bufKal, sizeof(bufKal), "N:%+.0f P:%+.0f K:%+.0f", CAL_N_OFFSET, CAL_P_OFFSET, CAL_K_OFFSET);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.print(bufKal);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    safeDelay(2500);

    soundLoRaSuccess();
  }
}

void handleBLEState() {
  if (!nodeBleConnected) {
    if (nodeOldBleConnected) {
      safeDelay(500); 
      pNodeServer->startAdvertising();
      Serial.println(F("[BLE] Mulai advertising lagi (Disconnect event)..."));
      nodeOldBleConnected = false;
      nodeWaitingForHistory = false;
    } else if (millis() - lastAdvCheckNode > 60000) {
      lastAdvCheckNode = millis();
      pNodeServer->startAdvertising();
    }
  }
  
  if (nodeBleConnected) {
    nodeOldBleConnected = nodeBleConnected;
  }
}

void loop() {
  wdtReset();
  loopCount++;

  handleBLEState();

  if (!modeHematDaya && (esp_timer_get_time() - normalModeStartUs > (uint64_t)NORMAL_TIMEOUT_MENIT * 60000000ULL) && !nodeBleConnected) {
    Serial.println(F("[TIMEOUT] Batas Mode Normal habis. Kembali ke Hemat Daya!"));
    toggleModeAction();
  }

  if (ghostWake) {
    Serial.println(F("Mencekik Hantu..."));
    masukLightSleep();
    return; 
  } else if (silentWake) {
    unsigned long waitCmd = millis();
    while (millis() - waitCmd < 6000) {
      wdtReset();
      if (LoRaSerial.available() > 0) {
        String resp = LoRaSerial.readStringUntil('\n');
        resp.replace("\r", "");
        resp.trim();
        
        if (resp == "WAKE") {
        } else if (resp == "FORCE_READ") {
          Serial.println(F("[LORA] Perintah FORCE_READ dari Gateway (Silent Wake)..."));
          lastSensorReadMillis = 0;
          silentWake = false;
          break;
        } else if (resp == "H" || resp == "SEND_HISTORY") {
          Serial.println(F("[CMD] Kirim History SD (Silent Wake)..."));
          
          LoRaSerial.println("A"); 
          safeDelay(100);
          
          bool syncSuccess = kirimHistorySD();
          
          while(LoRaSerial.available() > 0) LoRaSerial.read();
          
          if (syncSuccess) {
            silentWake = false; 
          }
          break;
        } else if (resp == "TOGGLE_MODE") {
          Serial.println(F("[LORA] Perintah Ganti Mode dari Gateway (Silent Wake)..."));
          toggleModeAction();
          silentWake = false;
          break;
        } else if (resp == "DELETE_SD") {
          Serial.println(F("[LORA] Perintah Hapus SD Card dari Gateway (Silent Wake)..."));
          formatSDCard();
          silentWake = false;
          break;
        } else if (resp == "CALIB_START") {
          modeKalibrasi = true;
          forceReadSensor = false;
          Serial.println("[LORA CMD] Masuk Mode Kalibrasi Lahan!");
          soundCalibStart();
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.backlight();
          lcd.clear();
          lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
          lcd.setCursor(0, 1); lcd.print(F("   MODE KALIBRASI   "));
          lcd.setCursor(0, 2); lcd.print(F("       LAHAN        "));
          lcd.setCursor(0, 3); lcd.print(F(" Menunggu perintah. "));
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          silentWake = false;
          break;
        } else if (resp == "CALIB_STOP") {
          modeKalibrasi = false;
          Serial.println("[LORA CMD] Keluar Mode Kalibrasi!");
          soundCalibStop();
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.clear();
          lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
          lcd.setCursor(0, 1); lcd.print(F("  Kalibrasi Selesai "));
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          delay(1500);
          pulihkanLayarUtama();
          silentWake = false;
          break;
        } else if (resp == "CALIB_READ") {
          if (modeKalibrasi) {
            forceReadSensor = true;
            Serial.println("[LORA CMD] Mengambil Data Kalibrasi!");
            soundCalibRead();
            if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
            lcd.clear();
            lcd.setCursor(0, 1); lcd.print(F(" Mengambil Data...  "));
            if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          }
          silentWake = false;
          break;
        } else if (resp == "ABORT") {
          cancelHistory = true;
          silentWake = false;
          break;
        }
      }
      delay(10);
    }
    if (silentWake) {
      masukLightSleep();
      return;
    }
  }

  while (LoRaSerial.available() > 0) {
    String cmd = LoRaSerial.readStringUntil('\n');
    cmd.replace("\r", "");
    cmd.trim();
    
    if (cmd == "WAKE") {
      unsigned long waitH = millis();
      while (millis() - waitH < 2500) {
        if (LoRaSerial.available() > 0) {
          String nextCmd = LoRaSerial.readStringUntil('\n');
          nextCmd.replace("\r", "");
          nextCmd.trim();
          if (nextCmd.indexOf("TIME:") >= 0) {
            int timeIdx = nextCmd.indexOf("TIME:");
            uint32_t epoch = nextCmd.substring(timeIdx + 5).toInt();
            if (epoch > 1700000000) {
              syncedEpochOffset = epoch - (esp_timer_get_time() / 1000000ULL);
              isTimeSynced = true;
              if (rtcSiap) rtc.adjust(DateTime(epoch));
              Serial.printf("[LORA] Waktu disinkronkan (Dari dalam perangkap WAKE): %lu\n", epoch);
              
              if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
              lcd.clear();
              lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
              lcd.setCursor(0, 1); lcd.print(F("  Sinkronisasi Waktu"));
              lcd.setCursor(0, 2); lcd.print(F("      Berhasil!     "));
              if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
              delay(1500);
              pulihkanLayarUtama();
            }
          } else if (nextCmd == "H" || nextCmd == "SEND_HISTORY") {
            cmd = "H"; 
            break;
          } else if (nextCmd == "TOGGLE_MODE" || nextCmd == "CALIB_START" || nextCmd == "CALIB_STOP" || nextCmd == "CALIB_READ" || nextCmd == "ABORT" || nextCmd == "DELETE_SD" || nextCmd.startsWith("SET_INTERVAL:") || nextCmd == "FORCE_READ") {
            cmd = nextCmd; // Teruskan ke if-else utama di bawah
            break;
          }
        }
        wdtReset();
        delay(10);
      }
    }

    if (cmd.indexOf("TIME:") >= 0) {
      int timeIdx = cmd.indexOf("TIME:");
      uint32_t epoch = cmd.substring(timeIdx + 5).toInt();
      if (epoch > 1700000000) {
        syncedEpochOffset = epoch - (esp_timer_get_time() / 1000000ULL);
        isTimeSynced = true;
        if (rtcSiap) rtc.adjust(DateTime(epoch));
        Serial.printf("[LORA] Waktu disinkronkan via Gateway (Epoch): %lu\n", epoch);
        
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("  Sinkronisasi Waktu"));
        lcd.setCursor(0, 2); lcd.print(F("      Berhasil!     "));
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        delay(1500);
        pulihkanLayarUtama();
      }
    } else if (cmd == "H" || cmd == "SEND_HISTORY") {
      Serial.println(F("[CMD] Kirim History SD..."));
      LoRaSerial.println("A");
      safeDelay(100);
      bool syncSuccess = kirimHistorySD();
      
      while(LoRaSerial.available() > 0) LoRaSerial.read();
      
      if (!syncSuccess) {
        return; 
      }
      break; 
    } else if (cmd == "TOGGLE_MODE") {
      Serial.println(F("[LORA] Perintah Ganti Mode dari Gateway. Melaksanakan perintah..."));
      toggleModeAction();
    } else if (cmd == "CALIB_START") {
      modeKalibrasi = true;
      forceReadSensor = false;
      Serial.println("[LORA CMD] Masuk Mode Kalibrasi Lahan!");
      soundCalibStart();
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.backlight();
      lcd.clear();
      lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
      lcd.setCursor(0, 1); lcd.print(F("   MODE KALIBRASI   "));
      lcd.setCursor(0, 2); lcd.print(F("       LAHAN        "));
      lcd.setCursor(0, 3); lcd.print(F(" Menunggu perintah. "));
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    } else if (cmd == "CALIB_STOP") {
      modeKalibrasi = false;
      Serial.println("[LORA CMD] Keluar Mode Kalibrasi!");
      soundCalibStop();
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.clear();
      lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
      lcd.setCursor(0, 1); lcd.print(F("  Kalibrasi Selesai "));
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      delay(1500);
      pulihkanLayarUtama();
    } else if (cmd == "CALIB_READ") {
      if (modeKalibrasi) {
        forceReadSensor = true;
        Serial.println("[LORA CMD] Mengambil Data Kalibrasi!");
        soundCalibRead();
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 1); lcd.print(F(" Mengambil Data...  "));
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      }
    } else if (cmd == "ABORT") {
      cancelHistory = true;
      Serial.println("[LORA CMD] Dibatalkan!");
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.clear();
      lcd.setCursor(0, 0); lcd.print(F("   SINKRONISASI SD  "));
      lcd.setCursor(0, 1); lcd.print(F("     DIBATALKAN     "));
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      delay(2000);
      pulihkanLayarUtama();
    } else if (cmd == "DELETE_SD") {
      Serial.println(F("[LORA] Perintah Hapus SD Card diterima dari Gateway!"));
      formatSDCard();
    } else if (cmd.startsWith("SET_INTERVAL:")) {
      int firstColon = cmd.indexOf(':');
      int secondColon = cmd.indexOf(':', firstColon + 1);
      if (firstColon > 0 && secondColon > 0) {
        uint32_t valNormal = cmd.substring(firstColon + 1, secondColon).toInt();
        uint32_t valHemat = cmd.substring(secondColon + 1).toInt();
        if (valNormal >= 5 && valNormal <= 3600 && valHemat >= 60 && valHemat <= 86400) {
          normalIntervalSec = valNormal;
          hematIntervalSec = valHemat;
          preferences.putUInt("itvlNormal", valNormal);
          preferences.putUInt("itvlHemat", valHemat);
          Serial.printf("[LORA CMD] Interval diubah via LoRa -> Normal: %lu s, Hemat: %lu s\n", valNormal, valHemat);
          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.clear();
          lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
          lcd.setCursor(0, 1); lcd.print(F("  Set Interval OK!  "));
          lcd.setCursor(0, 2); 
          lcd.print(F(" Normal : ")); lcd.print(valNormal); lcd.print(F(" dtk"));
          lcd.setCursor(0, 3);
          lcd.print(F(" Hemat  : ")); lcd.print(valHemat / 60); lcd.print(F(" mnt"));
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          delay(1500);
          pulihkanLayarUtama();
        }
      }
    } else if (cmd == "FORCE_READ") {
      Serial.println(F("[LORA CMD] Memaksa baca sensor sekarang!"));
      lastSensorReadMillis = 0;
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.clear();
      lcd.setCursor(0, 1); lcd.print(F(" Mengambil Data...  "));
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    } else if (cmd == "SD_ERROR_GATEWAY") {
      Serial.println(F("[LORA] Menerima pesan SD_ERROR dari Gateway!"));
      if (nodeBleConnected && pNodeTxCharacteristic != NULL) {
        StaticJsonDocument<100> doc;
        doc["type"]   = "error";
        doc["msg"]    = "SD Card Gateway tidak terdeteksi!";
        String jsonStr;
        serializeJson(doc, jsonStr);
        pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
        pNodeTxCharacteristic->notify();
      }
    } else if (cmd == "SD_SUCCESS_GATEWAY") {
      Serial.println(F("[LORA] Menerima pesan SUCCESS dari Gateway!"));
      if (nodeBleConnected && pNodeTxCharacteristic != NULL) {
        StaticJsonDocument<100> doc;
        doc["type"]   = "success";
        doc["msg"]    = "SD Card Gateway berhasil dihapus!";
        String jsonStr;
        serializeJson(doc, jsonStr);
        pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
        pNodeTxCharacteristic->notify();
      }
    }
  }

  if (nodeWaitingForHistory) {
    Serial.println(F("[CMD] Kirim History SD (Direct BLE)..."));
    nodeWaitingForHistory = false;
    safeDelay(100);
    kirimHistorySD();
  }

  cekSDCard();
  ambilWaktuRTC();
  updateNamaFile();

  if (modeKalibrasi) {
    if (!forceReadSensor) {
      wdtReset();
      delay(50);
      return; 
    }
    forceReadSensor = false;
  }

  if (!isSyncing) {
    updateLED(3);
    uint8_t result = readSensorWithRetry();
    lastSensorReadMillis = millis(); // â­ Catat waktu pengambilan data terakhir

  if (result == node.ku8MBSuccess) {
    errorCount = 0;

    int16_t rawTemp = (int16_t)node.getResponseBuffer(0);
    int16_t rawHumi = (int16_t)node.getResponseBuffer(1);
    int16_t rawKond = (int16_t)node.getResponseBuffer(2);
    int16_t rawPH   = (int16_t)node.getResponseBuffer(3);
    int16_t rawN    = (int16_t)node.getResponseBuffer(4);
    int16_t rawP    = (int16_t)node.getResponseBuffer(5);
    int16_t rawK    = (int16_t)node.getResponseBuffer(6);

    float tempCal = ((float)rawTemp / 10.0) + CAL_TEMP_OFFSET;
    float humiCal = ((float)rawHumi / 10.0) + CAL_HUMI_OFFSET;
    float condCal = ((float)rawKond)         + CAL_COND_OFFSET;
    float phCal   = ((float)rawPH / 100.0)   + CAL_PH_OFFSET; 
    float nCal    = ((float)rawN)             + CAL_N_OFFSET;
    float pCal    = ((float)rawP)             + CAL_P_OFFSET;
    float kCal    = ((float)rawK)             + CAL_K_OFFSET;

    Serial.println(F("\n=============================================="));
    Serial.println(F(" ðŸŒ¿ DATA SENSOR NPK (KALIBRASI MENTAH) ðŸŒ¿"));
    Serial.println(F("=============================================="));
    Serial.printf(" ðŸŒ¡ï¸ Suhu       : %.1f Â°C  (Raw: %d)\n", tempCal, rawTemp);
    Serial.printf(" ðŸ’§ Kelembaban : %.1f %%   (Raw: %d)\n", humiCal, rawHumi);
    Serial.printf(" âš¡ Konduktiv. : %.0f uS  (Raw: %d)\n", condCal, rawKond);
    Serial.printf(" ðŸ§ª pH Tanah   : %.1f     (Raw: %d)\n", phCal, rawPH);
    Serial.printf(" ðŸŸ¢ Nitrogen   : %.0f mg  (Raw: %d)\n", nCal, rawN);
    Serial.printf(" ðŸŸ¡ Fosfor     : %.0f mg  (Raw: %d)\n", pCal, rawP);
    Serial.printf(" ðŸ”´ Kalium     : %.0f mg  (Raw: %d)\n", kCal, rawK);
    Serial.println(F("==============================================\n"));

    char payloadData[128];
    snprintf(payloadData, sizeof(payloadData),
             "%s,%s,%s,%.1f,%.1f,%d,%.1f,%d,%d,%d,%d,%d",
             NODE_ID, strWaktu, strTanggal,
             tempCal, humiCal, (int)condCal, phCal,
             (int)nCal, (int)pCal, (int)kCal,
             sdSiap ? 1 : 0,
             modeHematDaya ? 1 : 0);

    uint8_t crc = 0;
    for (int i = 0; payloadData[i] != '\0'; i++) {
      crc ^= (uint8_t)payloadData[i];
    }
    char dataLoRa[150];
    if (globalLineIndex != -1) {
      snprintf(dataLoRa, sizeof(dataLoRa), "L:%d:%s,%d", globalLineIndex, payloadData, crc);
    } else {
      snprintf(dataLoRa, sizeof(dataLoRa), "%s,%d", payloadData, crc);
    }

    bool ackOK = false;

    if (nodeBleConnected && pNodeTxCharacteristic) {
      StaticJsonDocument<512> doc;
      doc["node_id"]     = NODE_ID;
      
      char timestampBuf[25];
      int dd=0, MM=0, yyyy=0, hh=0, mm=0, ss=0;
      
      if (strTanggal[0] != '-') {
        sscanf(strTanggal, "%02d/%02d/%04d", &dd, &MM, &yyyy);
      } else {
        dd = 1; MM = 1; yyyy = 1970;
      }
      sscanf(strWaktu, "%02d:%02d:%02d", &hh, &mm, &ss);
      snprintf(timestampBuf, sizeof(timestampBuf), "%04d-%02d-%02dT%02d:%02d:%02d", yyyy, MM, dd, hh, mm, ss);
      
      doc["timestamp"]   = timestampBuf;
      doc["temperature"] = tempCal;
      doc["humidity"]    = humiCal;
      doc["ec"]          = condCal / 1000.0;
      doc["ph"]          = phCal;
      doc["nitrogen"]    = nCal;
      doc["phosphorus"]  = pCal;
      doc["kalium"]      = kCal;
      doc["mode_hemat"]  = modeHematDaya;
      doc["status"]      = "connected";

      String jsonStr;
      serializeJson(doc, jsonStr);
      pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
      pNodeTxCharacteristic->notify();
    }
    
    int waitMs = random(0, 1000);
    safeDelay(waitMs);
    ackOK = kirimLoRa(dataLoRa);
    updateLoRaStatus(ackOK);

    if (sdSiap) {
      simpanKeSD(tempCal, humiCal, condCal, phCal, nCal, pCal, kCal, ackOK);
    }
    
    if (pendingSyncIndex != -1) {
      Serial.printf("Gateway meminta sinkronisasi mendadak dari index %d!\n", pendingSyncIndex);
      kirimHistorySD(pendingSyncIndex);
      pendingSyncIndex = -1; 
    }

    if (ackOK) {
      digitalWrite(PIN_LED_STATUS, LOW); 
      safeDelay(150);
    }

    soundSensorSuccess();
    
    // Periksa status LoRa dan mainkan suara jika koneksi berubah
    if (loraTerhubung != lastLoraStatus) {
      if (!loraTerhubung) {
        soundLoRaDisconnect(); // Koneksi terputus
      } else {
        soundLoRaConnect();    // Koneksi kembali
      }
    }
    lastLoraStatus = loraTerhubung;

    tampilkanDataLCD(phCal, tempCal, humiCal, nCal, pCal, kCal, condCal);

    unsigned long displayStart = millis();
    bool tombolDitekan = false;
    unsigned long waitTime = modeHematDaya ? (DISPLAY_HOLD_SEC * 1000) : (normalIntervalSec * 1000);
    if (modeKalibrasi) waitTime = 2500; // Tahan data sensor 2.5 detik lalu kembali ke layar menunggu
    
    while (millis() - displayStart < waitTime) {
      wdtReset();
      
      if (digitalRead(PIN_TOMBOL_MODE) == LOW && !tombolDitekan) {
        delay(50); // Debounce hardware
        if (digitalRead(PIN_TOMBOL_MODE) == LOW) {
          tombolDitekan = true;
          toggleModeAction();
        }
      }
      if (digitalRead(PIN_TOMBOL_MODE) == HIGH) {
        tombolDitekan = false; 
      }

      // 🔥 FIX RESPONSIVITAS: Langsung potong masa tunggu jika ada perintah LoRa atau BLE history masuk!
      if (LoRaSerial.available() > 0 || nodeWaitingForHistory) {
        break; 
      }

      if (loraTerhubung) updateLED(2); 
      else updateLED(4);               
      delay(10);
    }

    if (modeKalibrasi) {
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.clear();
      lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
      lcd.setCursor(0, 1); lcd.print(F("   MODE KALIBRASI   "));
      lcd.setCursor(0, 2); lcd.print(F("       LAHAN        "));
      lcd.setCursor(0, 3); lcd.print(F(" Menunggu perintah. "));
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    }

  } else {
    errorCount++;

    if (ERROR_RESTART_COUNT > 0 && errorCount >= ERROR_RESTART_COUNT) {
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.clear();
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      delay(50);
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.setCursor(0, 0); lcd.print(F("!! SENSOR ERROR !!  "));
      lcd.setCursor(0, 1); lcd.print(F("Batas error capai  "));
      lcd.setCursor(0, 2); lcd.print(F("Auto Restart...    "));
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      safeDelay(1000);
      preferences.end();
      ESP.restart();
    }

    updateLED(1); 

    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.backlight();
    lcd.setCursor(0, 0); lcd.print(F("!! SENSOR ERROR !!  "));
    lcd.setCursor(0, 1); lcd.print(F("Gagal baca sensor   "));
    lcd.setCursor(0, 2);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    char errBuf[21];
    snprintf(errBuf, sizeof(errBuf), "Kode: 0x%02X Err:%d/%d", result, errorCount, ERROR_RESTART_COUNT);
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.print(errBuf);
    lcd.setCursor(0, 3);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    snprintf(errBuf, sizeof(errBuf), "%s  %s           ", sdSiap ? "SD:OK" : "SD:NO", loraTerhubung ? "L:OK" : "L:NO");
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    lcd.print(errBuf);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);

    unsigned long displayStart = millis();
    while (millis() - displayStart < DISPLAY_HOLD_SEC * 1000) {
      wdtReset();
      delay(10);
    }

    if (nodeBleConnected && pNodeTxCharacteristic) {
      StaticJsonDocument<128> doc;
      doc["node_id"]     = NODE_ID;
      doc["status"]      = "error";
      String jsonStr;
      serializeJson(doc, jsonStr);
      pNodeTxCharacteristic->setValue((uint8_t*)jsonStr.c_str(), jsonStr.length());
      pNodeTxCharacteristic->notify();
      Serial.println("[BLE] Notifikasi Error dikirim ke HP");
    }
  }
  
  } // Penutup blok if (!isSyncing)

  wdtReset();

  if (modeKalibrasi) {
    return; // Jangan masuk sleep
  }

  if (modeHematDaya) {
    masukLightSleep();
  }
  // Jika Mode Normal, langsung kembali ke awal loop membaca sensor
}

// Fungsi standarisasi untuk memastikan persiapan Light Sleep selalu sempurna
void masukLightSleep() {
  // Hanya matikan layar LCD untuk menghemat daya secara instan
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.noBacklight();
  lcd.clear();
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);

  unsigned long intervalMs = hematIntervalSec * 1000UL;
  unsigned long timePassed = millis() - lastSensorReadMillis;
  
  // Jika waktu tidur sudah habis atau terlewati, jangan tidur, langsung kembali untuk baca sensor
  if (timePassed >= intervalMs && lastSensorReadMillis != 0) {
    return;
  }

  unsigned long timeRemaining = (lastSensorReadMillis == 0) ? intervalMs : (intervalMs - timePassed);
  unsigned long startSleep = millis();

  Serial.printf("[STANDBY] Memasuki mode siaga. Sisa waktu tidur: %lu detik. BLE/LoRa AKTIF...\n", timeRemaining / 1000);

  // Kita gunakan "Software Sleep" (delay pintar) BUKAN hardware sleep.
  // Ini krusial agar sinyal Bluetooth (BLE) tetap memancar 24 jam nonstop
  // sehingga Anda bisa mengkoneksikan HP kapan saja Anda mau!
  
  Serial.println(F("[POWER] Mengurangi kecepatan CPU ke 80MHz (Hemat Daya Ekstrem)"));
  setCpuFrequencyMhz(80); // Turunkan clock ke 80MHz, konsumsi daya drop ke ~20mA (BLE tetap aman)

  while (millis() - startSleep < timeRemaining) {
    wdtReset();
    
    // ðŸ”¥ FIX UTAMA: BLE HARUS DITANGANI WALAUPUN SEDANG TIDUR!
    // Mencegah Bluetooth menghilang ketika disconnect terjadi tepat sebelum Light Sleep.
    handleBLEState();
    
    // 1. Cek jika tombol fisik ditekan
    if (digitalRead(PIN_TOMBOL_MODE) == LOW) {
      delay(50);
      if (digitalRead(PIN_TOMBOL_MODE) == LOW) {
        modeHematDaya = !modeHematDaya;
        preferences.putBool("modeHemat", modeHematDaya);
        if (!modeHematDaya) normalModeStartUs = esp_timer_get_time();
        
        digitalWrite(PIN_LED_STATUS, HIGH);
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.backlight();
        lcd.clear();
        lcd.setCursor(0, 1); lcd.print(F("  MODE DIUBAH KE:   "));
        lcd.setCursor(0, 2);
        if (modeHematDaya) lcd.print(F("   HEMAT DAYA       "));
        else lcd.print(F("      NORMAL        "));
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        
        soundSleep(modeHematDaya);
        safeDelay(2000);
        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        
        silentWake = false;
        ghostWake = false;
        Serial.println(F("[POWER] Mengembalikan kecepatan CPU ke 240MHz"));
        setCpuFrequencyMhz(240); // Kembalikan ke performa penuh
        return; // Langsung keluar untuk membaca sensor
      }
    }

    // 2. Cek jika ada perintah WAKE dari LoRa (Gateway)
    if (LoRaSerial.available() > 0) {
      String resp = LoRaSerial.readStringUntil('\n');
      resp.replace("\r", "");
      resp.trim();
      if (resp.indexOf("TIME:") >= 0) {
        int timeIdx = resp.indexOf("TIME:");
        uint32_t epoch = resp.substring(timeIdx + 5).toInt();
        if (epoch > 1700000000) {
          syncedEpochOffset = epoch - (esp_timer_get_time() / 1000000ULL);
          isTimeSynced = true;
          if (rtcSiap) rtc.adjust(DateTime(epoch));
          Serial.printf("[LORA] Waktu disinkronkan (LIVE Loop): %lu\n", epoch);
        }
      } else if (resp == "WAKE" || resp == "H" || resp == "SEND_HISTORY" || resp == "FORCE_READ") {
        if (resp == "FORCE_READ") {
          silentWake = false; 
          ghostWake = false;
          lastSensorReadMillis = 0;
          Serial.println(F(">> Bangun kilat via LoRa AUX (FORCE_READ)!"));
        } else {
          silentWake = true;
          ghostWake = false;
          Serial.println(F(">> Bangun kilat via LoRa AUX (Silent Wake)!"));
        }
        Serial.println(F("[POWER] Mengembalikan kecepatan CPU ke 240MHz"));
        setCpuFrequencyMhz(240);
        return; 
      }
    }

    if (nodeWaitingForHistory) {
      silentWake = false; 

      ghostWake = false;
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.backlight(); 
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      Serial.println(F("[POWER] Mengembalikan kecepatan CPU ke 240MHz (Sinkronisasi History Aktif)"));
      setCpuFrequencyMhz(240);
      lastSensorReadMillis = 0; // Paksa reset agar langsung membaca sensor setelah history selesai
      return;
    }

    if (!modeHematDaya) {
      silentWake = false;
      ghostWake = false;
      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      lcd.backlight();
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      Serial.println(F("[POWER] Mode berubah ke NORMAL via Remote. Keluar dari Light Sleep..."));
      setCpuFrequencyMhz(240);
      return;
    }

    delay(10);
  }

  // Jika waktu habis (sudah 20 menit), bangun normal untuk membaca rutin
  silentWake = false;
  ghostWake = false;
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.backlight();
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  Serial.println(F("[POWER] Waktu Standby habis. Mengembalikan kecepatan CPU ke 240MHz"));
  setCpuFrequencyMhz(240);
}
