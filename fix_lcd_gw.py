import re

file_gw = 'gateway/gateway.ino'
with open(file_gw, 'r', encoding='utf-8') as f:
    gw_code = f.read()

if 'SemaphoreHandle_t lcdMutex' not in gw_code:
    gw_code = gw_code.replace('LiquidCrystal_I2C lcd(LCD_I2C_ADDR, LCD_COLS, LCD_ROWS);', 'LiquidCrystal_I2C lcd(LCD_I2C_ADDR, LCD_COLS, LCD_ROWS);\nSemaphoreHandle_t lcdMutex = NULL;')

if 'xSemaphoreCreateRecursiveMutex' not in gw_code:
    gw_code = gw_code.replace('void setup() {', 'void setup() {\n  lcdMutex = xSemaphoreCreateRecursiveMutex();')

# 3. Replace blocks in onDisconnect
gw_code = gw_code.replace(
'''      hapusLayarLCD();
      updateBarisLCD(0, "   SINKRONISASI SD  ");
      updateBarisLCD(1, "     DIBATALKAN     ");
      updateBarisLCD(2, "   (HP Terputus)    ");
      delay(2000);
      pulihkanLayarUtama();''',
'''      if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
      hapusLayarLCD();
      updateBarisLCD(0, "   SINKRONISASI SD  ");
      updateBarisLCD(1, "     DIBATALKAN     ");
      updateBarisLCD(2, "   (HP Terputus)    ");
      delay(2000);
      if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
      pulihkanLayarUtama();'''
)

# Replace transient screens in loop() (button press)
# Wipe Data Confirm
gw_code = gw_code.replace(
'''          hapusLayarLCD();
          lcd.setCursor(0, 0); lcd.print("! YAKIN HAPUS DATA !");
          lcd.setCursor(0, 1); lcd.print("====================");
          lcd.setCursor(0, 2); lcd.print("2x Klik: HAPUS SEMUA");
          lcd.setCursor(0, 3); lcd.print("1x Klik: BATAL");''',
'''          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          hapusLayarLCD();
          lcd.setCursor(0, 0); lcd.print("! YAKIN HAPUS DATA !");
          lcd.setCursor(0, 1); lcd.print("====================");
          lcd.setCursor(0, 2); lcd.print("2x Klik: HAPUS SEMUA");
          lcd.setCursor(0, 3); lcd.print("1x Klik: BATAL");
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);'''
)

# Wipe Data Success
gw_code = gw_code.replace(
'''              hapusLayarLCD();
              lcd.setCursor(0, 1); lcd.print("   MEMORI GATEWAY   ");
              lcd.setCursor(0, 2); lcd.print("    DIBERSIHKAN!    ");
              delay(3000);''',
'''              if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
              hapusLayarLCD();
              lcd.setCursor(0, 1); lcd.print("   MEMORI GATEWAY   ");
              lcd.setCursor(0, 2); lcd.print("    DIBERSIHKAN!    ");
              delay(3000);
              if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);'''
)

# Wipe Data Cancelled
gw_code = gw_code.replace(
'''            hapusLayarLCD();
            lcd.setCursor(0, 1); lcd.print("   FORMAT MEMORI    ");
            lcd.setCursor(0, 2); lcd.print("     DIBATALKAN     ");
            delay(2000);''',
'''            if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
            hapusLayarLCD();
            lcd.setCursor(0, 1); lcd.print("   FORMAT MEMORI    ");
            lcd.setCursor(0, 2); lcd.print("     DIBATALKAN     ");
            delay(2000);
            if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);'''
)

# Waiting for Node
gw_code = gw_code.replace(
'''            hapusLayarLCD();
            lcd.setCursor(0, 1); lcd.print("Menunggu data Node  ");''',
'''            if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
            hapusLayarLCD();
            lcd.setCursor(0, 1); lcd.print("Menunggu data Node  ");
            if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);'''
)


# Replace SD_ERROR_NODE
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

# SD SINKRONISASI SELESAI
gw_code = gw_code.replace(
'''        hapusLayarLCD();
        updateBarisLCD(0, "   SINKRONISASI SD  ");
        updateBarisLCD(1, "      SELESAI!      ");
        updateBarisLCD(2, "  Membuka Akses HP  ");
        updateBarisLCD(3, "  Silakan Tunggu..  ");
        
        soundHistoryComplete();
        Serial.println("[LORA] History Selesai Sempurna! Kirim BLE...");
        delay(2000);
        pulihkanLayarUtama();''',
'''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        hapusLayarLCD();
        updateBarisLCD(0, "   SINKRONISASI SD  ");
        updateBarisLCD(1, "      SELESAI!      ");
        updateBarisLCD(2, "  Membuka Akses HP  ");
        updateBarisLCD(3, "  Silakan Tunggu..  ");
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        
        soundHistoryComplete();
        Serial.println("[LORA] History Selesai Sempurna! Kirim BLE...");
        delay(2000);
        pulihkanLayarUtama();'''
)

# formatSDCard in gateway
gw_code = gw_code.replace(
'''  hapusLayarLCD();
  updateBarisLCD(1, " Menghapus SD Card..");
  Serial.println(F("[SD] Memulai penghapusan data SD Card Gateway..."));
  
  if (SD.cardType() == CARD_NONE) {
    Serial.println(F("[SD] Error: SD Card Gateway tidak terdeteksi!"));
    hapusLayarLCD();
    updateBarisLCD(1, " Gagal Format SD! ");
    soundSDError();
    delay(2000);
    pulihkanLayarUtama();
    return;
  }''',
'''  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  hapusLayarLCD();
  updateBarisLCD(1, " Menghapus SD Card..");
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  
  Serial.println(F("[SD] Memulai penghapusan data SD Card Gateway..."));
  
  if (SD.cardType() == CARD_NONE) {
    Serial.println(F("[SD] Error: SD Card Gateway tidak terdeteksi!"));
    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
    hapusLayarLCD();
    updateBarisLCD(1, " Gagal Format SD! ");
    delay(2000);
    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
    soundSDError();
    pulihkanLayarUtama();
    return;
  }'''
)

gw_code = gw_code.replace(
'''  hapusLayarLCD();
  updateBarisLCD(0, " -- FLOOD2FOOD --   ");
  updateBarisLCD(1, "  SD Card Bersih!   ");
  delay(1500);
  pulihkanLayarUtama();''',
'''  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  hapusLayarLCD();
  updateBarisLCD(0, " -- FLOOD2FOOD --   ");
  updateBarisLCD(1, "  SD Card Bersih!   ");
  delay(1500);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  pulihkanLayarUtama();'''
)

# Minta history retry
gw_code = gw_code.replace(
'''       hapusLayarLCD();
       updateBarisLCD(0, "   SINKRONISASI SD  ");
       updateBarisLCD(1, " Minta data dari    ");
       updateBarisLCD(2, " Node (Retry)...    ");''',
'''       if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
       hapusLayarLCD();
       updateBarisLCD(0, "   SINKRONISASI SD  ");
       updateBarisLCD(1, " Minta data dari    ");
       updateBarisLCD(2, " Node (Retry)...    ");
       if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);'''
)

# hapusLayarLCD helper
gw_code = gw_code.replace(
'''void hapusLayarLCD() {
  lcd.clear();
  for (int i = 0; i < 4; i++) {
    lastLine[i] = "";
  }
}''',
'''void hapusLayarLCD() {
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.clear();
  for (int i = 0; i < 4; i++) {
    lastLine[i] = "";
  }
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}'''
)

# updateBarisLCD helper
gw_code = gw_code.replace(
'''void updateBarisLCD(int baris, String teks) {
  if (baris < 0 || baris > 3) return;
  if (lastLine[baris] == teks) return;
  
  lcd.setCursor(0, baris);
  lcd.print("                    ");
  lcd.setCursor(0, baris);
  lcd.print(teks);
  lastLine[baris] = teks;
}''',
'''void updateBarisLCD(int baris, String teks) {
  if (baris < 0 || baris > 3) return;
  if (lastLine[baris] == teks) return;
  
  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.setCursor(0, baris);
  lcd.print("                    ");
  lcd.setCursor(0, baris);
  lcd.print(teks);
  lastLine[baris] = teks;
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}'''
)

# tampilkanDataLCD (Dashboard rendering)
gw_code = gw_code.replace(
'''void tampilkanDataLCD(String fields[]) {
  // Simpan ke cache agar bisa dirender ulang saat ganti halaman
  for(int i=0; i<13; i++) {
    cachedFields[i] = fields[i];
  }
  hasCachedData = true;''',
'''void tampilkanDataLCD(String fields[]) {
  // Simpan ke cache agar bisa dirender ulang saat ganti halaman
  for(int i=0; i<13; i++) {
    cachedFields[i] = fields[i];
  }
  hasCachedData = true;
  
  if (lcdMutex != NULL) {
    if (xSemaphoreTakeRecursive(lcdMutex, pdMS_TO_TICKS(50)) != pdTRUE) {
      return; // Skip rendering dashboard jika layar sedang dipakai
    }
  }'''
)

# Give mutex at the end of tampilkanDataLCD
gw_code = gw_code.replace(
'''      lcd.setCursor(0, 3); lcd.print("                    ");
      lcd.setCursor(0, 3); lcd.print("L:NO                ");
    }
  }
}''',
'''      lcd.setCursor(0, 3); lcd.print("                    ");
      lcd.setCursor(0, 3); lcd.print("L:NO                ");
    }
  }
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}'''
)

with open(file_gw, 'w', encoding='utf-8') as f:
    f.write(gw_code)

print("Gateway script updated successfully.")
