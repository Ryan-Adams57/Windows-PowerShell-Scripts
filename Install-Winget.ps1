# Install-Winget.ps1
# Installs or reinstalls the Windows Package Manager (winget)
# Must be run as Administrator

Write-Host "--- Installing/Repairing Winget ---" -ForegroundColor Cyan

# Method 1: Install via PowerShell module
Install-Module -Name Microsoft.WinGet.Client -Scope AllUsers -Force

# Method 2: Install via MSIX bundle from GitHub (uncomment if Method 1 fails)
# Add-AppxPackage https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

# Method 3: Re-register existing installation
# Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe

# Method 4: Add from CDN source (uncomment if needed)
# Add-AppxPackage https://cdn.winget.microsoft.com/cache/source.msix

Write-Host "Winget installation complete. Test with: winget --version" -ForegroundColor Green

# --- Upgrade all packages silently ---
# winget upgrade --all --silent --accept-source-agreements --accept-package-agreements

# --- Upgrade (short form) ---
# winget upgrade -r -h -u --accept-source-agreements --accept-package-agreements
