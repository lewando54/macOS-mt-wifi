#!/usr/bin/env python3
import sys

pbx_path = "itlwm.xcodeproj/project.pbxproj"
with open(pbx_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add PBXBuildFile entry
build_file_entry = "\t\tMTK00001202610240000001 /* MtkMwx.cpp in Sources */ = {isa = PBXBuildFile; fileRef = MTK00002202610240000001 /* MtkMwx.cpp */; };\n"
content = content.replace(
    "/* Begin PBXBuildFile section */\n",
    "/* Begin PBXBuildFile section */\n" + build_file_entry
)

# 2. Add PBXFileReference entry
file_ref_entry = '\t\tMTK00002202610240000001 /* MtkMwx.cpp */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.cpp.cpp; name = MtkMwx.cpp; path = hal_mwx/MtkMwx.cpp; sourceTree = "<group>"; };\n'
content = content.replace(
    "/* Begin PBXFileReference section */\n",
    "/* Begin PBXFileReference section */\n" + file_ref_entry
)

# 3. Update Tahoe Sources phase (F8D94CA52B9ABFE20081A3C4)
intel_sources = [
    "A7D000012026100700000001 /* ItlDma.cpp in Sources */,\n",
    "F8D94CA62B9ABFE20081A3C4 /* rs.cpp in Sources */,\n",
    "F8D94CDD2B9ABFE20081A3C4 /* ItlIwx.cpp in Sources */,\n",
    "F8D94CDE2B9ABFE20081A3C4 /* utils.cpp in Sources */,\n",
    "F8D94CDF2B9ABFE20081A3C4 /* fw.cpp in Sources */,\n",
    "F8D94CE02B9ABFE20081A3C4 /* io.cpp in Sources */,\n",
    "F8D94CE12B9ABFE20081A3C4 /* rx.cpp in Sources */,\n",
    "F8D94CE22B9ABFE20081A3C4 /* coex.cpp in Sources */,\n",
    "F8D94CE32B9ABFE20081A3C4 /* tx.cpp in Sources */,\n",
    "F8D94CE42B9ABFE20081A3C4 /* hw.cpp in Sources */,\n",
    "F8D94CE52B9ABFE20081A3C4 /* ItlIwn.cpp in Sources */,\n",
    "F8D94CE62B9ABFE20081A3C4 /* phy.cpp in Sources */,\n",
    "F8D94CE72B9ABFE20081A3C4 /* mac80211.cpp in Sources */,\n",
    "F8D94CE82B9ABFE20081A3C4 /* nvm.cpp in Sources */,\n",
    "F8D94CE92B9ABFE20081A3C4 /* ctxt.cpp in Sources */,\n",
    "F8D94CEA2B9ABFE20081A3C4 /* led.cpp in Sources */,\n",
    "F8D94CEB2B9ABFE20081A3C4 /* power.cpp in Sources */,\n",
    "F8D94CEC2B9ABFE20081A3C4 /* scan.cpp in Sources */,\n",
    "F8D94CEE2B9ABFE20081A3C4 /* ItlIwm.cpp in Sources */,\n",
]

tahoe_sources_marker = "F8D94CA52B9ABFE20081A3C4 /* Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
if tahoe_sources_marker in content:
    idx = content.find(tahoe_sources_marker)
    end_idx = content.find(");\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};", idx)
    sources_block = content[idx:end_idx]
    # Remove intel files
    for item in intel_sources:
        sources_block = sources_block.replace("\t\t\t\t" + item, "")
    # Add MtkMwx.cpp
    sources_block += "\t\t\t\tMTK00001202610240000001 /* MtkMwx.cpp in Sources */,\n"
    content = content[:idx] + sources_block + content[end_idx:]
    print("Updated Tahoe sources build phase.")
else:
    print("ERROR: tahoe_sources_marker not found!")
    sys.exit(1)

# 4. Remove AIRPORT_VTD and add hal_mwx to Tahoe build configurations
# Debug: 7D5753727745775F75788913
# Release: D92AB006FB4B2B6A6032F9C7
for cfg_id in ["7D5753727745775F75788913", "D92AB006FB4B2B6A6032F9C7"]:
    cfg_marker = f"{cfg_id} /*"
    idx = content.find(cfg_marker)
    if idx != -1:
        end_idx = content.find("};\n", idx)
        cfg_block = content[idx:end_idx]
        cfg_block = cfg_block.replace("\t\t\t\t\tAIRPORT_VTD,\n", "")
        cfg_block = cfg_block.replace(
            'SYSTEM_HEADER_SEARCH_PATHS = "itl80211/openbsd itl80211 include";',
            'SYSTEM_HEADER_SEARCH_PATHS = "hal_mwx itl80211/openbsd itl80211 include";'
        )
        content = content[:idx] + cfg_block + content[end_idx:]
        print(f"Updated config {cfg_id}")
    else:
        print(f"ERROR: config {cfg_id} not found!")

with open(pbx_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Saved pbxproj successfully.")
