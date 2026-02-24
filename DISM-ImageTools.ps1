# DISM-ImageTools.ps1
# Collection of DISM commands for capturing, applying, and maintaining Windows images
# Must be run as Administrator from an elevated command prompt or PowerShell

# --- Configuration ---
$ImagePath   = "<Path to Image Location>\<ImageName>.wim"  # e.g., "D:\Images\Win11.wim"
$CaptureDir  = "C:\"                                        # Usually C:\
$ImageDesc   = "<Just a description>"                       # e.g., "Windows 11 Base Image"
$ApplyDir    = "<Dir to Apply To>:\"                        # e.g., "D:\"
$DriverPath  = "<PathtoDriver>"
$PackagePath = "<PathtoPackage>"
# ---------------------

Write-Host "=== DISM Image Tool Reference ===" -ForegroundColor Cyan
Write-Host "Uncomment the section you need and fill in the configuration above." -ForegroundColor Yellow

# --- Capture Image ---
# Sysprep first: sysprep.exe /generalize /oobe /shutdown /unattend:(Path)\unattend.xml
# DISM /Capture-Image /ImageFile:$ImagePath /CaptureDir:$CaptureDir /Name:"$ImageDesc"

# --- Split Image (for FAT32 media, 4GB limit) ---
# Dism /Split-Image /ImageFile:"C:\sources\install.wim" /SWMFile:"C:\sources\install.swm" /FileSize:4096

# --- Apply Image ---
# DISM /Apply-Image /ImageFile:$ImagePath /Index:1 /ApplyDir:$ApplyDir

# --- Apply Split Image ---
# DISM /Apply-Image /imagefile:"<ImageName>.swm" /swmfile:"<ImageName>*.swm" /Index:1 /ApplyDir:$ApplyDir

# --- Add Driver to Offline Image ---
# DISM /Image:<Drive>: /Add-Driver:$DriverPath /Recurse

# --- Add Package to Offline Image ---
# DISM /Image:<Drive>: /Add-Package:$PackagePath

# --- Health Checks (Online) ---
Write-Host "`nRunning online health scan..." -ForegroundColor Cyan
DISM /Online /Cleanup-Image /ScanHealth

# Uncomment to restore health:
# DISM /Online /Cleanup-Image /RestoreHealth

# --- Get Image Info ---
# DISM /Get-ImageInfo /ImageFile:$ImagePath

# --- System File Checker ---
# SFC /Scannow
