# Get-ComputerInfoFromList.ps1
# Gathers computer info from a list of PC names and appends to a CSV
# Requires PowerShell remoting enabled on targets

# --- Configuration ---
$PCListFile  = "C:\Temp\Computerlist.txt"
$OutputFile  = "C:\Temp\Computerdata.csv"
# ---------------------

Write-Host "--- Gathering Computer Info from $PCListFile ---" -ForegroundColor Cyan

foreach ($pcname in Get-Content $PCListFile) {
    if (Test-Connection -ComputerName $pcname -Quiet -Count 1) {
        Write-Host "Querying $pcname ..." -ForegroundColor Yellow
        Invoke-Command -ComputerName $pcname -ScriptBlock {
            Get-ComputerInfo | Select-Object CSName, WindowsProductName, WindowsVersion, OSVersion, OSHardwareAbstractionLayer
        } | Out-File -Append $OutputFile
    } else {
        Write-Host "Skipping $pcname (unreachable)" -ForegroundColor Red
    }
}

Write-Host "Done. Results saved to $OutputFile" -ForegroundColor Green
