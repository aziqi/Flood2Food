import re

with open("node/node.ino", "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
in_lcd_block = False
block_start_indent = ""

for i, line in enumerate(lines):
    if "lcdMutex" in line:
        if in_lcd_block:
            new_lines.append(block_start_indent + "if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);\n")
            in_lcd_block = False
        new_lines.append(line)
        continue
        
    has_lcd = bool(re.search(r'\blcd\.', line))
    
    if has_lcd:
        if not in_lcd_block:
            in_lcd_block = True
            match = re.match(r'^(\s*)', line)
            block_start_indent = match.group(1) if match else ""
            new_lines.append(block_start_indent + "if (lcdMutex != NULL) xSemaphoreTakeRecursive(lcdMutex, portMAX_DELAY);\n")
        new_lines.append(line)
    else:
        if in_lcd_block:
            new_lines.append(block_start_indent + "if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);\n")
            in_lcd_block = False
        new_lines.append(line)

if in_lcd_block:
    new_lines.append(block_start_indent + "if (lcdMutex != NULL) xSemaphoreGiveRecursive(lcdMutex);\n")

with open("node/node.ino", "w", encoding="utf-8") as f:
    f.writelines(new_lines)
print("node.ino LCD mutex applied")
