import re

file_gw = 'gateway/gateway.ino'
with open(file_gw, 'r', encoding='utf-8') as f:
    gw_code = f.read()

# Fix B_CHK SD_FAIL
gw_code = gw_code.replace(
'''        hapusLayarLCD();
        updateBarisLCD(0, "   SINKRONISASI SD  ");
        updateBarisLCD(1, "   NODE SD RUSAK!   ");
        updateBarisLCD(2, "  Gagal Minta Data  ");
        delay(2000);
        pulihkanLayarUtama();''',
'''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        hapusLayarLCD();
        updateBarisLCD(0, "   SINKRONISASI SD  ");
        updateBarisLCD(1, "   NODE SD RUSAK!   ");
        updateBarisLCD(2, "  Gagal Minta Data  ");
        delay(2000);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        pulihkanLayarUtama();'''
)

# Restore B_END logic
old_b_end = '''    if (pesan.startsWith("B_END:")) {
      int totalLines = pesan.substring(6).toInt();
      if (totalLines > 2000) totalLines = 2000;
      
      int missing = -1;
      for (int i = 0; i < totalLines; i++) {
        if (!chunkReceived[i]) {
            missing = i;
            break;
        }
      }

      if (missing == -1) {
        waitingForHistory = false;
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
        
        LoRaSerial.println("A");
      } else {
        LoRaSerial.print("M:");
        LoRaSerial.println(missing);
        Serial.print("[LORA] Minta ulang baris: ");
        Serial.println(missing);
      }
      return;
    }'''

new_b_end = '''    if (pesan.startsWith("B_END:")) {
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
    }'''

gw_code = gw_code.replace(old_b_end, new_b_end)

with open(file_gw, 'w', encoding='utf-8') as f:
    f.write(gw_code)

print("Gateway script fixed.")
