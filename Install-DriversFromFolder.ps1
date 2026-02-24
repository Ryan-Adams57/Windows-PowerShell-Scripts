# Install-DriversFromFolder.ps1
# Recursively finds and installs all .inf drivers from a specified folder
# Must be run as Administrator

# --- Configuration ---
$DriverFolder = "Path:\ToFolder"  # e.g., "D:\Drivers\Dell"
# ---------------------

Write-Host "--- Installing Drivers from $DriverFolder ---" -ForegroundColor Cyan

Get-ChildItem $DriverFolder -Recurse -Filter "*.inf" | ForEach-Object {
    Write-Host "Installing: $($_.FullName)" -ForegroundColor Yellow
    pnputil.exe /add-driver $_.FullName /install
}

Write-Host "Driver installation complete." -ForegroundColor Green
