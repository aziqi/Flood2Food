import re

with open('node/node.ino', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 1. Fix LIVE mode bad patch
# Find where the bad patch is:
bad_start = -1
for i, line in enumerate(lines):
    if "String line = file.readStringUntil('\\n');" in line:
        bad_start = i
        break

if bad_start != -1:
    # 15 lines of bad patch
    bad_end = bad_start + 14
    good_patch = "    uint8_t crc = 0;\n    for (int i = 0; payloadData[i] != '\\0'; i++) {\n      crc ^= (uint8_t)payloadData[i];\n    }\n"
    lines = lines[:bad_start] + [good_patch] + lines[bad_end+1:]

# 2. Patch History mode
history_start = -1
for i, line in enumerate(lines):
    if "String line = file.readStringUntil((char)10);" in line:
        history_start = i
        break

if history_start != -1:
    patch = "        String line = file.readStringUntil((char)10);\n        line.trim();\n        if (line.length() == 0) continue;\n        int lastCommaIdx = line.lastIndexOf(',');\n        if (lastCommaIdx != -1) {\n          line = line.substring(0, lastCommaIdx);\n        }\n"
    # replace "String line = file.readStringUntil((char)10);\n" and "line.trim();\n"
    lines = lines[:history_start] + [patch] + lines[history_start+2:]

with open('node/node.ino', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print("Node.ino fixed")
