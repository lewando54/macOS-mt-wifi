#!/bin/sh

#  fw_gen.sh
#  AirportItlwm (MT7921/MT7922)

target_file="${PROJECT_DIR}/include/FwBinary.cpp"
if [ -f "$target_file" ]; then
    exit 0
fi

fw_dir="${PROJECT_DIR}/firmware"
script_file="${PROJECT_DIR}/scripts/gen_mtk_fw.py"

python3 "${script_file}" "${fw_dir}" "${target_file}"
