import re

file_node = 'node/node.ino'
with open(file_node, 'r', encoding='utf-8') as f:
    node_code = f.read()

# 1. Add lcdMutex declaration
if 'SemaphoreHandle_t lcdMutex' not in node_code:
    node_code = node_code.replace('RTC_DS3231 rtc;', 'RTC_DS3231 rtc;\nSemaphoreHandle_t lcdMutex = NULL;')

# 2. Initialize in setup
if 'xSemaphoreCreateRecursiveMutex' not in node_code:
    node_code = node_code.replace('void setup() {', 'void setup() {\n  lcdMutex = xSemaphoreCreateRecursiveMutex();')

# 3. Replace blocks in onWrite
replacements = [
    (
        '''        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        LoRaSerial.println("DELETE_SD_GATEWAY");
        delay(1500);
        pulihkanLayarUtama();''',
        '''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        delay(1500);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        LoRaSerial.println("DELETE_SD_GATEWAY");
        pulihkanLayarUtama();'''
    ),
    (
        '''        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        LoRaSerial.println("DELETE_SD_GATEWAY");
        delay(1500);
        pulihkanLayarUtama();''',
        '''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        delay(1500);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        LoRaSerial.println("DELETE_SD_GATEWAY");
        pulihkanLayarUtama();'''
    ),
    (
        '''        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F("   SINKRONISASI SD  "));
        lcd.setCursor(0, 1); lcd.print(F("     DIBATALKAN     "));
        delay(2000);
        pulihkanLayarUtama();''',
        '''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F("   SINKRONISASI SD  "));
        lcd.setCursor(0, 1); lcd.print(F("     DIBATALKAN     "));
        delay(2000);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        pulihkanLayarUtama();'''
    ),
    (
        '''          lcd.clear();
          lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
          lcd.setCursor(0, 1); lcd.print(F("  Sinkronisasi Waktu"));
          lcd.setCursor(0, 2); lcd.print(F("      Berhasil!     "));
          delay(1500);
          pulihkanLayarUtama();''',
        '''          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.clear();
          lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
          lcd.setCursor(0, 1); lcd.print(F("  Sinkronisasi Waktu"));
          lcd.setCursor(0, 2); lcd.print(F("      Berhasil!     "));
          delay(1500);
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
          pulihkanLayarUtama();'''
    ),
    (
        '''        lcd.backlight();
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("   MODE KALIBRASI   "));
        lcd.setCursor(0, 2); lcd.print(F("       LAHAN        "));
        lcd.setCursor(0, 3); lcd.print(F(" Menunggu perintah. "));''',
        '''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.backlight();
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("   MODE KALIBRASI   "));
        lcd.setCursor(0, 2); lcd.print(F("       LAHAN        "));
        lcd.setCursor(0, 3); lcd.print(F(" Menunggu perintah. "));
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);'''
    ),
    (
        '''        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("  Kalibrasi Selesai "));
        delay(1500);
        pulihkanLayarUtama();''',
        '''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("  Kalibrasi Selesai "));
        delay(1500);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        pulihkanLayarUtama();'''
    ),
    (
        '''          lcd.clear();
          lcd.setCursor(0, 1); lcd.print(F(" Mengambil Data...  "));''',
        '''          if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
          lcd.clear();
          lcd.setCursor(0, 1); lcd.print(F(" Mengambil Data...  "));
          if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);'''
    )
]

for orig, new in replacements:
    node_code = node_code.replace(orig, new)

# Now other functions:
# formatSDCard
repl1 = '''  lcd.clear();
  lcd.setCursor(0, 1); lcd.print(F(" Menghapus SD Card.."));'''
repl1_new = '''  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.clear();
  lcd.setCursor(0, 1); lcd.print(F(" Menghapus SD Card.."));
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);'''
node_code = node_code.replace(repl1, repl1_new)

# Notice there are two LoRaSerial.println("DELETE_SD_GATEWAY") chunks above (one with delay first, one after), let's ensure both handle well. 
node_code = node_code.replace('''        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        LoRaSerial.println("DELETE_SD_GATEWAY");
        delay(1500);
        pulihkanLayarUtama();''', '''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        delay(1500);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        LoRaSerial.println("DELETE_SD_GATEWAY");
        pulihkanLayarUtama();''')

node_code = node_code.replace('''        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        LoRaSerial.println("DELETE_SD_GATEWAY");
        delay(1500);''', '''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("Menghapus SD Gateway"));
        lcd.setCursor(0, 2); lcd.print(F(" Meneruskan via LoRa"));
        delay(1500);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        LoRaSerial.println("DELETE_SD_GATEWAY");''')

node_code = re.sub(
    r'    lcd\.clear\(\);\n    lcd\.setCursor\(0, 1\); lcd\.print\(F\(" Gagal Format SD! "\)\);\n    soundSDError\(\);\n(.*?)\n    delay\(2000\);\n    pulihkanLayarUtama\(\);',
    r'    soundSDError();\n\1\n    if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);\n    lcd.clear();\n    lcd.setCursor(0, 1); lcd.print(F(" Gagal Format SD! "));\n    delay(2000);\n    if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);\n    pulihkanLayarUtama();',
    node_code, flags=re.DOTALL
)

repl3 = '''  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
  lcd.setCursor(0, 1); lcd.print(F("  SD Card Bersih!   "));
  delay(1500);
  pulihkanLayarUtama();'''
repl3_new = '''  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
  lcd.setCursor(0, 1); lcd.print(F("  SD Card Bersih!   "));
  delay(1500);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  pulihkanLayarUtama();'''
node_code = node_code.replace(repl3, repl3_new)

# toggleModeAction
repl4 = '''  lcd.backlight();
  if (modeHematDaya) {
    soundSleep(true);
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
    lcd.setCursor(0, 1); lcd.print(F(">> MODE HEMAT DAYA<<"));
  } else {
    soundSleep(false);
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
    lcd.setCursor(0, 1); lcd.print(F(" >> MODE NORMAL <<  "));
  }
  delay(1500);
  pulihkanLayarUtama();'''
repl4_new = '''  if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
  lcd.backlight();
  if (modeHematDaya) {
    soundSleep(true);
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
    lcd.setCursor(0, 1); lcd.print(F(">> MODE HEMAT DAYA<<"));
  } else {
    soundSleep(false);
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
    lcd.setCursor(0, 1); lcd.print(F(" >> MODE NORMAL <<  "));
  }
  delay(1500);
  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
  pulihkanLayarUtama();'''
node_code = node_code.replace(repl4, repl4_new)

# loop TIME: sync
repl5 = '''        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("  Sinkronisasi Waktu"));
        lcd.setCursor(0, 2); lcd.print(F("      Berhasil!     "));
        delay(1500);
        pulihkanLayarUtama();'''
repl5_new = '''        if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);
        lcd.clear();
        lcd.setCursor(0, 0); lcd.print(F(" -- FLOOD2FOOD --   "));
        lcd.setCursor(0, 1); lcd.print(F("  Sinkronisasi Waktu"));
        lcd.setCursor(0, 2); lcd.print(F("      Berhasil!     "));
        delay(1500);
        if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
        pulihkanLayarUtama();'''
node_code = node_code.replace(repl5, repl5_new)

# tampilkanDataLCD
repl6 = '''void tampilkanDataLCD(float ph, float suhu, float humi, float n, float p, float k, float kond) {
  lastPhCal = ph; lastTempCal = suhu; lastHumiCal = humi;
  lastNCal = n; lastPCal = p; lastKCal = k; lastCondCal = kond;
  hasCachedLCDData = true;

  char buf[21];
  lcd.backlight();'''
repl6_new = '''void tampilkanDataLCD(float ph, float suhu, float humi, float n, float p, float k, float kond) {
  lastPhCal = ph; lastTempCal = suhu; lastHumiCal = humi;
  lastNCal = n; lastPCal = p; lastKCal = k; lastCondCal = kond;
  hasCachedLCDData = true;

  if (lcdMutex != NULL) {
    if (xSemaphoreTakeRecursive(lcdMutex, pdMS_TO_TICKS(50)) != pdTRUE) {
      return; // Skip rendering jika LCD sedang dipakai (misal menampilkan notifikasi transient)
    }
  }

  char buf[21];
  lcd.backlight();'''
node_code = node_code.replace(repl6, repl6_new)

repl7 = '''  lcd.setCursor(0, 3);
  lcd.print(buf);
}'''
repl7_new = '''  lcd.setCursor(0, 3);
  lcd.print(buf);

  if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);
}'''
node_code = node_code.replace(repl7, repl7_new)

# pulihkanLayarUtama
repl8 = '''void pulihkanLayarUtama() {
  if (hasCachedLCDData) {
    tampilkanDataLCD(lastPhCal, lastTempCal, lastHumiCal, lastNCal, lastPCal, lastKCal, lastCondCal);
  } else {
    lcd.clear();
  }
}'''
repl8_new = '''void pulihkanLayarUtama() {
  if (hasCachedLCDData) {
    tampilkanDataLCD(lastPhCal, lastTempCal, lastHumiCal, lastNCal, lastPCal, lastKCal, lastCondCal);
  } else {
    if (lcdMutex != NULL) {
      if (xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY) == pdTRUE) {
        lcd.clear();
        xSemaphoreGiveRecursive(lcdMutex);
      }
    }
  }
}'''
node_code = node_code.replace(repl8, repl8_new)


with open(file_node, 'w', encoding='utf-8') as f:
    f.write(node_code)

print("Node script updated successfully.")
