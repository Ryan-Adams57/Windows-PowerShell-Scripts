<#
.SYNOPSIS
Prepare Windows PC for BIOS AHCI/Secure Boot changes before installing Linux.

.DESCRIPTION
This script automates the Windows-side configuration required to safely enable AHCI 
drivers and boot into Safe Mode, minimizing boot failures when changing BIOS settings. 
It does NOT modify BIOS directly. Manual BIOS steps are still required.

.PREREQUISITES
- Run as Administrator in PowerShell.
- Save any open work before running (computer will restart).
- After script-triggered Safe Mode boot, manually enable AHCI and disable Secure Boot in BIOS.
#>

# ==============================
# Step 1: Enable Safe Mode on Next Boot
# ==============================
Write-Host "Configuring Windows to boot in Safe Mode on next restart..." -ForegroundColor Yellow
bcdedit /set {current} safeboot minimal

# ==============================
# Step 2: Enable AHCI Drivers
# ==============================
Write-Host "Setting AHCI driver registry keys..." -ForegroundColor Yellow

# Intel AHCI (iaStorV) driver
$iaStorVPath = "HKLM:\SYSTEM\CurrentControlSet\Services\iaStorV"
if (Test-Path $iaStorVPath) {
    Set-ItemProperty -Path $iaStorVPath -Name "Start" -Value 0
    Write-Host "iaStorV driver configured." -ForegroundColor Green
} else {
    Write-Host "iaStorV driver not found. Skipping..." -ForegroundColor Cyan
}

# Standard AHCI (storahci) driver
$storahciPath = "HKLM:\SYSTEM\CurrentControlSet\Services\storahci"
if (Test-Path $storahciPath) {
    Set-ItemProperty -Path $storahciPath -Name "Start" -Value 0
    Write-Host "storahci driver configured." -ForegroundColor Green
} else {
    Write-Host "storahci driver not found. Skipping..." -ForegroundColor Cyan
}

# ==============================
# Step 3: Restart Computer Immediately
# ==============================
Write-Host "Restarting computer to apply Safe Mode settings..." -ForegroundColor Yellow
Restart-Computer

# ==============================
# Manual Steps Required After Restart
# ==============================
<#
1️⃣ Enter BIOS/UEFI (commonly F2, F12, Del, or Esc during boot).
2️⃣ Navigate to Storage/SATA settings and change mode to AHCI.
3️⃣ Locate Secure Boot in Security/Boot menu and set to Disabled.
4️⃣ Save BIOS changes and exit.

Once Windows boots into Safe Mode:

# ==============================
# Step 4: Exit Safe Mode
# ==============================
Run the following PowerShell command as Administrator:

    bcdedit /deletevalue {current} safeboot

# ==============================
# Step 5: Final Restart
# ==============================
Restart the computer one final time to boot normally with AHCI enabled.
#>
