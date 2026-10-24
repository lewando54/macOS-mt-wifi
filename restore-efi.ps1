# restore-efi.ps1
# Windows Recovery Script for OpenCore EFI
# Restores EFI from EFI.backup on the ESP

# Requires Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Please run this script as Administrator (Right click -> Run with PowerShell as Administrator)."
    exit 1
}

$drive = "S:"
Write-Host "Mounting System Partition to $drive..."
mountvol $drive /s

if (-not (Test-Path "$drive\EFI")) {
    Write-Error "EFI folder not found on $drive. Checking other disks..."
    mountvol $drive /d
    exit 1
}

Write-Host "ESP mounted successfully."

if (Test-Path "$drive\EFI.backup") {
    Write-Host "Found $drive\EFI.backup. Restoring..."
    if (Test-Path "$drive\EFI.corrupt") {
        Remove-Item -Recurse -Force "$drive\EFI.corrupt"
    }
    Rename-Item -Path "$drive\EFI" -NewName "EFI.corrupt"
    Copy-Item -Recurse -Path "$drive\EFI.backup" -Destination "$drive\EFI"
    Write-Host "EFI restored successfully from EFI.backup!" -ForegroundColor Green
} else {
    Write-Warning "No EFI.backup directory found on $drive."
    Write-Host "Listing $drive\EFI\OC\Kexts:"
    Get-ChildItem "$drive\EFI\OC\Kexts"
    
    $killSwitch = Read-Host "Do you want to disable AirportItlwm.kext by renaming it? (y/n)"
    if ($killSwitch -eq 'y') {
        if (Test-Path "$drive\EFI\OC\Kexts\AirportItlwm.kext") {
            Rename-Item "$drive\EFI\OC\Kexts\AirportItlwm.kext" "AirportItlwm.kext.disabled"
            Write-Host "AirportItlwm.kext disabled." -ForegroundColor Yellow
        }
    }
}

Write-Host "Unmounting $drive..."
mountvol $drive /d
Write-Host "Done. You can now reboot into macOS." -ForegroundColor Cyan
