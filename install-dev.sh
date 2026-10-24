#!/bin/bash
# install-dev.sh
# Build and install AirportItlwm (MediaTek MT7921) into OpenCore EFI on macOS Tahoe

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

CONFIG="Debug"
DO_BUILD=1
BUILD_ONLY=0
MOUNT_POINT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            CONFIG="Release"
            shift
            ;;
        --debug)
            CONFIG="Debug"
            shift
            ;;
        --no-build)
            DO_BUILD=0
            shift
            ;;
        --build-only|--no-mount)
            BUILD_ONLY=1
            shift
            ;;
        --mount-point)
            MOUNT_POINT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--debug|--release] [--no-build] [--build-only] [--mount-point /Volumes/EFI]"
            exit 1
            ;;
    esac
done

BUILD_DIR="$REPO_DIR/build_artifacts"
KEXT_PATH="$BUILD_DIR/products/$CONFIG/Tahoe/AirportItlwm.kext"

if [ $DO_BUILD -eq 1 ]; then
    echo "==> Building AirportItlwm ($CONFIG configuration for Tahoe)..."
    python3 scripts/gen_mtk_fw.py firmware include/FwBinary.cpp
    xcodebuild -project itlwm.xcodeproj -scheme AirportItlwm-Tahoe \
        -configuration "$CONFIG" -jobs 8 ARCHS=x86_64 \
        -derivedDataPath "$BUILD_DIR/dd" \
        SYMROOT="$BUILD_DIR/products" OBJROOT="$BUILD_DIR/obj" \
        CODE_SIGNING_ALLOWED=NO build
fi

if [ ! -d "$KEXT_PATH" ]; then
    echo "ERROR: Built kext not found at $KEXT_PATH"
    exit 1
fi

echo "==> Built kext verified at: $KEXT_PATH"

if [ $BUILD_ONLY -eq 1 ]; then
    echo "Build-only requested. Skipping EFI mount and installation."
    exit 0
fi

# Locate EFI partition if not provided
AUTO_UNMOUNT=0
if [ -z "$MOUNT_POINT" ]; then
    # Find EFI disk identifier
    EFI_DISK=$(diskutil list | awk '/EFI EFI/ {print $NF; exit}')
    if [ -z "$EFI_DISK" ]; then
        EFI_DISK="disk0s2"
    fi

    echo "==> Mounting EFI partition ($EFI_DISK)..."
    # Check if already mounted
    EXISTING_MOUNT=$(mount | awk -v d="/dev/$EFI_DISK" '$1 == d {print $3}')
    if [ -n "$EXISTING_MOUNT" ]; then
        MOUNT_POINT="$EXISTING_MOUNT"
        echo "EFI is already mounted at: $MOUNT_POINT"
    else
        diskutil mount "$EFI_DISK" || sudo diskutil mount "$EFI_DISK"
        MOUNT_POINT=$(mount | awk -v d="/dev/$EFI_DISK" '$1 == d {print $3}')
        AUTO_UNMOUNT=1
    fi
fi

if [ ! -d "$MOUNT_POINT/EFI/OC" ]; then
    echo "ERROR: OpenCore folder not found at $MOUNT_POINT/EFI/OC"
    exit 1
fi

echo "==> OpenCore EFI found at: $MOUNT_POINT/EFI/OC"

# 1. Ensure backup exists
if [ ! -d "$MOUNT_POINT/EFI.backup" ]; then
    echo "==> Creating safety backup: $MOUNT_POINT/EFI.backup..."
    cp -a "$MOUNT_POINT/EFI" "$MOUNT_POINT/EFI.backup"
    echo "Backup created successfully."
else
    echo "==> Safety backup already present at $MOUNT_POINT/EFI.backup"
fi

# Also ensure restore-efi.ps1 is available on the ESP root for quick recovery from Windows
cp "$REPO_DIR/restore-efi.ps1" "$MOUNT_POINT/restore-efi.ps1"

# 2. Check for SimpleMtkWlan.kext conflict
if [ -d "$MOUNT_POINT/EFI/OC/Kexts/SimpleMtkWlan.kext" ]; then
    echo "==> Disabling conflicting SimpleMtkWlan.kext in EFI/OC/Kexts..."
    mv "$MOUNT_POINT/EFI/OC/Kexts/SimpleMtkWlan.kext" "$MOUNT_POINT/EFI/OC/Kexts/SimpleMtkWlan.kext.bak"
fi

# 3. Copy AirportItlwm.kext
echo "==> Copying AirportItlwm.kext into $MOUNT_POINT/EFI/OC/Kexts/..."
rm -rf "$MOUNT_POINT/EFI/OC/Kexts/AirportItlwm.kext"
cp -a "$KEXT_PATH" "$MOUNT_POINT/EFI/OC/Kexts/"

# 4. Check config.plist
CONFIG_PLIST="$MOUNT_POINT/EFI/OC/config.plist"
if [ -f "$CONFIG_PLIST" ]; then
    echo "==> Checking $CONFIG_PLIST entries..."
    python3 - <<EOF
import plistlib, sys

plist_path = "$CONFIG_PLIST"
with open(plist_path, "rb") as f:
    config = plistlib.load(f)

kernel_add = config.get("Kernel", {}).get("Add", [])
found_airport = False
found_simple = False

for kext in kernel_add:
    bundle = kext.get("BundlePath", "")
    enabled = kext.get("Enabled", False)
    if "AirportItlwm.kext" in bundle:
        found_airport = True
        print(f"  [OK] Found AirportItlwm entry: {bundle} (Enabled={enabled})")
    if "SimpleMtkWlan.kext" in bundle:
        found_simple = True
        print(f"  [WARN] Found SimpleMtkWlan entry: {bundle} (Enabled={enabled})")

if not found_airport:
    print("  [ACTION REQUIRED] AirportItlwm.kext is NOT in config.plist Kernel -> Add!")
    print("  Adding AirportItlwm.kext entry to config.plist...")
    new_entry = {
        "Arch": "x86_64",
        "BundlePath": "AirportItlwm.kext",
        "Comment": "MediaTek MT7921 Native Wi-Fi",
        "Enabled": True,
        "ExecutablePath": "Contents/MacOS/AirportItlwm",
        "MaxKernel": "",
        "MinKernel": "25.0.0",
        "PlistPath": "Contents/Info.plist"
    }
    kernel_add.append(new_entry)
    # If SimpleMtkWlan is enabled, disable it
    for kext in kernel_add:
        if "SimpleMtkWlan.kext" in kext.get("BundlePath", ""):
            kext["Enabled"] = False
            print(f"  Disabled SimpleMtkWlan in config.plist")
    with open(plist_path, "wb") as f:
        plistlib.dump(config, f)
    print("  Updated config.plist successfully.")
EOF
fi

if [ $AUTO_UNMOUNT -eq 1 ]; then
    echo "==> Unmounting EFI partition..."
    diskutil unmount "$MOUNT_POINT" || sudo diskutil unmount "$MOUNT_POINT"
fi

echo "=========================================================="
echo " Installation Complete!"
echo " Configuration: $CONFIG"
echo " Next step: Reboot to test."
echo " If you encounter any issue:"
echo "   - OpenCore picker: add boot-arg -mtkoff to skip loading."
echo "   - From Windows: run S:\restore-efi.ps1 (as Administrator)."
echo "=========================================================="
