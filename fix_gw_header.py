import re

with open('gateway/gateway.ino', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if 'f.println("Waktu,Tanggal,Suhu_C,Kelembaban_%,Konduktivitas_uS,pH,N_mgkg,P_mgkg,K_mgkg,LoRa_Status");' in line:
        line = line.replace('Waktu,Tanggal,Suhu_C,Kelembaban_%,Konduktivitas_uS,pH,N_mgkg,P_mgkg,K_mgkg,LoRa_Status', 'NodeID,Waktu,Tanggal,Suhu,Kelembaban,Konduktivitas,pH,N,P,K,SD_Node_Siap,Mode_Hemat,ACK')
    new_lines.append(line)

with open('gateway/gateway.ino', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("Gateway.ino header fixed")
