<#
.SYNOPSIS
Performs routine maintenance tasks on a workstation.
.DESCRIPTION
Tasks include: Check Disk, SFC Scan, Temp Cleanup, and optional shutdown.
#>

# Enable strict mode
Set-StrictMode -Version Latest

# Cleanup temp files
$TempPaths = @("$env:TEMP", "$env:WINDIR\Temp")
foreach ($Path in $TempPaths) {
    Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

# Run Check Disk (dry run)
chkdsk C: /scan

# Run SFC
sfc /scannow

# Optional shutdown
# shutdown /s /t 60
Write-Host "Maintenance complete. Shutdown commented out for safety."
