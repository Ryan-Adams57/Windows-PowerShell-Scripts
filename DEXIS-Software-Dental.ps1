#Requires -RunAsAdministrator
# DEXIS-Software-Dental.ps1
# Automates the full dental software installation workflow:
#   1. Dentrix setup batch script
#   2. Dentrix DE 11.0.20.585 installer
#   3. Dexis 9.5.1
#   4. DentrixIntegrator 3.2.0
#   5. Uninstall Kevo Connect
#   6. Restart computer
#
# Run this script as Administrator.

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Wait-ForProcess {
    param([string]$ProcessName, [string]$Description)
    Write-Host "Waiting for '$Description' to finish..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Wait-Process
    }
    Write-Host "'$Description' has completed." -ForegroundColor Green
}

# -----------------------------------------------------------------------
# STEP 1: Run Dentrix setup batch script
# -----------------------------------------------------------------------
Write-Step "STEP 1: Running dentrix.bat"

$DentrixBat = "\\SMGDNTRXPRDAPP2\DXONE\Scripts\dentrix.bat"

if (Test-Path $DentrixBat) {
    Write-Host "Launching: $DentrixBat" -ForegroundColor Yellow
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$DentrixBat`"" -Verb RunAs -PassThru -Wait
    Write-Host "dentrix.bat completed with exit code: $($proc.ExitCode)" -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot find $DentrixBat" -ForegroundColor Red
    Write-Host "Verify the network share is accessible and try again." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------
# STEP 2: Install Dentrix DE 11.0.20.585
# -----------------------------------------------------------------------
Write-Step "STEP 2: Installing Dentrix DE 11.0.20.585"

$DentrixInstaller = "\\SMGDNTRXPRDAPP2\Dental Software\Setup_DE_11.0.20.585.i1.exe"

if (Test-Path $DentrixInstaller) {
    Write-Host "Launching Dentrix installer..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  MANUAL STEPS REQUIRED during installation:" -ForegroundColor Magenta
    Write-Host "  - Install Code : 11.0install  (no spaces)" -ForegroundColor Magenta
    Write-Host "  - Custom Code  : (leave blank)" -ForegroundColor Magenta
    Write-Host "  - Optional Pkg : Choose 'Install Letter Merge add-in for Microsoft Word'" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Press ENTER when ready to launch the installer..." -ForegroundColor Yellow
    Read-Host

    $proc = Start-Process -FilePath $DentrixInstaller -Verb RunAs -PassThru
    Write-Host "Waiting for Dentrix installer to complete..." -ForegroundColor Yellow
    $proc | Wait-Process
    Write-Host "Dentrix DE installer finished." -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot find $DentrixInstaller" -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------
# STEP 3: Install Dexis 9.5.1
# -----------------------------------------------------------------------
Write-Step "STEP 3: Installing Dexis 9.5.1"

$DexisInstaller = "\\SMGDNTRXPRDAPP2\Dental Software\Dexis 9.5.1\Dexmenu.exe"

if (Test-Path $DexisInstaller) {
    Write-Host "Launching Dexis installer..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  MANUAL STEPS REQUIRED during installation:" -ForegroundColor Magenta
    Write-Host "  1. Click [English-US]" -ForegroundColor Magenta
    Write-Host "  2. Click [Install Dexis Software]" -ForegroundColor Magenta
    Write-Host "  3. Set install location to : C:\DEXIS" -ForegroundColor Magenta
    Write-Host "  4. Change destination folder to : \\DEXIS\DEXIS\DATA" -ForegroundColor Magenta
    Write-Host "  5. Click Next through all remaining screens" -ForegroundColor Magenta
    Write-Host "  6. Do NOT restart when prompted on the finish screen" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Press ENTER when ready to launch the Dexis installer..." -ForegroundColor Yellow
    Read-Host

    $proc = Start-Process -FilePath $DexisInstaller -Verb RunAs -PassThru
    Write-Host "Waiting for Dexis installer to complete..." -ForegroundColor Yellow
    $proc | Wait-Process
    Write-Host "Dexis 9.5.1 installer finished." -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot find $DexisInstaller" -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------
# STEP 4: Install DentrixIntegrator 3.2.0
# -----------------------------------------------------------------------
Write-Step "STEP 4: Installing DentrixIntegrator 3.2.0"

$IntegratorInstaller = "\\SMGDNTRXPRDAPP2\Dental Software\DentrixIntegrator 3.2.0\Dexmenu.exe"

if (Test-Path $IntegratorInstaller) {
    Write-Host "Launching DentrixIntegrator installer..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  MANUAL STEPS REQUIRED during installation:" -ForegroundColor Magenta
    Write-Host "  1. Click [Install Integrator for Dentrix]" -ForegroundColor Magenta
    Write-Host "  2. Continue through any warning prompts" -ForegroundColor Magenta
    Write-Host "  3. Accept all installation defaults" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Press ENTER when ready to launch the DentrixIntegrator installer..." -ForegroundColor Yellow
    Read-Host

    $proc = Start-Process -FilePath $IntegratorInstaller -Verb RunAs -PassThru
    Write-Host "Waiting for DentrixIntegrator installer to complete..." -ForegroundColor Yellow
    $proc | Wait-Process
    Write-Host "DentrixIntegrator 3.2.0 installer finished." -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot find $IntegratorInstaller" -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------
# STEP 5: Uninstall Kevo Connect
# -----------------------------------------------------------------------
Write-Step "STEP 5: Uninstalling Kevo Connect"

Write-Host "Searching for Kevo Connect in installed programs..." -ForegroundColor Yellow

# Search both 32-bit and 64-bit registry uninstall keys
$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$KevoApp = $UninstallPaths | ForEach-Object {
    Get-ItemProperty $_ -ErrorAction SilentlyContinue
} | Where-Object { $_.DisplayName -like "*Kevo Connect*" }

if ($KevoApp) {
    Write-Host "Found: $($KevoApp.DisplayName) - starting uninstall..." -ForegroundColor Yellow

    if ($KevoApp.UninstallString) {
        # Handle both MSI-based and EXE-based uninstallers
        $UninstallString = $KevoApp.UninstallString

        if ($UninstallString -match "msiexec") {
            # MSI-based: extract the product code and run silently
            $ProductCode = ($UninstallString -replace ".*({.*?}).*", '$1')
            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $ProductCode /qb /norestart" -Verb RunAs -PassThru -Wait
        } else {
            # EXE-based: run the uninstall string directly
            $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$UninstallString`"" -Verb RunAs -PassThru -Wait
        }

        Write-Host "Kevo Connect uninstall completed." -ForegroundColor Green
    } else {
        Write-Host "WARNING: No uninstall string found for Kevo Connect." -ForegroundColor Red
        Write-Host "Please uninstall manually via Control Panel > Programs & Features." -ForegroundColor Red
        Read-Host "Press ENTER once you have manually uninstalled Kevo Connect to continue..."
    }
} else {
    Write-Host "Kevo Connect was not found in the installed programs list." -ForegroundColor Yellow
    Write-Host "It may already be uninstalled, or the name may differ slightly." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------
# STEP 6: Restart Computer
# -----------------------------------------------------------------------
Write-Step "STEP 6: Restarting Computer"

Write-Host "All installations are complete." -ForegroundColor Green
Write-Host ""
Write-Host "The computer will restart in 30 seconds." -ForegroundColor Yellow
Write-Host "Press CTRL+C now to cancel the restart if needed." -ForegroundColor Yellow

for ($i = 30; $i -gt 0; $i--) {
    Write-Host "Restarting in $i seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}

Restart-Computer -Force
