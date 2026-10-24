#!/usr/bin/env python3
"""
Firmware generator for MT7921 / MT7922 MediaTek Wi-Fi.
Converts raw firmware binaries in firmware/ to C arrays in include/FwBinary.cpp.
"""

import os
import sys

HEADER = """//
//  FwBinary.cpp
//  AirportItlwm (MediaTek MT7921/MT7922)
//
//  Generated firmware bundle.
//

#include "FwData.h"

"""

FW_MAP = [
    ("mwx-mt7961_patch_mcu_1_2_hdr", "mwx_mt7961_patch_mcu_1_2_hdr.bin", "mwx_mt7961_patch_mcu_1_2_hdr"),
    ("mwx-mt7961_ram_code_1",        "mwx_mt7961_ram_code_1.bin",        "mwx_mt7961_ram_code_1"),
    ("mwx-mt7922_patch_mcu_1_1_hdr", "mwx_mt7922_patch_mcu_1_1_hdr.bin", "mwx_mt7922_patch_mcu_1_1_hdr"),
    ("mwx-mt7922_ram_code_1",        "mwx_mt7922_ram_code_1.bin",        "mwx_mt7922_ram_code_1"),
]

def generate_fw_file(fw_dir, output_path):
    out = []
    out.append(HEADER)
    
    entries = []
    for fw_name, filename, var_name in FW_MAP:
        file_path = os.path.join(fw_dir, filename)
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"Missing firmware binary: {file_path}")
        
        with open(file_path, "rb") as f:
            data = f.read()
        
        out.append(f"unsigned char {var_name}[] = {{\n")
        lines = []
        for i in range(0, len(data), 16):
            chunk = data[i:i+16]
            hex_bytes = ", ".join(f"0x{b:02x}" for b in chunk)
            lines.append("  " + hex_bytes + ",")
        out.append("\n".join(lines) + "\n};\n")
        out.append(f"unsigned int {var_name}_len = {len(data)};\n\n")
        entries.append(f'    {{MTK_FW_DESC("{fw_name}", {var_name}, (int){var_name}_len)}},')

    out.append("const struct FwDesc fwList[] = {\n")
    out.append("\n".join(entries) + "\n")
    out.append("};\n")
    out.append(f"const int fwNumber = {len(entries)};\n")

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, "w") as f:
        f.write("".join(out))
    print(f"Generated {output_path} with {len(entries)} firmware entries.")

if __name__ == "__main__":
    fw_dir = sys.argv[1] if len(sys.argv) > 1 else "firmware"
    output_path = sys.argv[2] if len(sys.argv) > 2 else "include/FwBinary.cpp"
    generate_fw_file(fw_dir, output_path)
