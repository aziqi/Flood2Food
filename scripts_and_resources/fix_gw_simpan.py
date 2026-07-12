import re

with open('gateway/gateway.ino', 'r', encoding='utf-8') as f:
    code = f.read()

bad_func = """void simpanKeSDGateway(String payload) {
    if (!sdSiap) return;
    File f = SD.open("/data_npk.csv", FILE_APPEND);
    if (f) {
      int firstComma = payload.indexOf(',');
      if (firstComma != -1) {
        String dataAsli = payload.substring(firstComma + 1);
        f.print(dataAsli);
        f.println(",ACK");
        gatewayTotalLines++;
      }
      f.close();
    }
  }"""

good_func = """void simpanKeSDGateway(String payload) {
    if (!sdSiap) return;
    File f = SD.open("/data_npk.csv", FILE_APPEND);
    if (f) {
      f.println(payload);
      gatewayTotalLines++;
      f.close();
    }
  }"""

if bad_func in code:
    code = code.replace(bad_func, good_func)
    with open('gateway/gateway.ino', 'w', encoding='utf-8') as f:
        f.write(code)
    print("Gateway simpanKeSDGateway fixed")
else:
    print("Cannot find bad_func in gateway.ino!")
