# Enable-PSRemotingFromList.ps1
# Enables PowerShell Remoting on a list of PCs using PsExec
# Requires PsExec in PATH and admin credentials
# PC names listed one per line in the text file

# --- Configuration ---
$PCListFile  = "C:\Temp\Whirley-PCs.txt"
$AdminUser   = "<DomainOrAdmin>"   # e.g., "CONTOSO\Administrator"
$AdminPass   = "<Password>"        # e.g., "P@ssw0rd" (consider using Get-Credential instead)
# ---------------------

Write-Host "--- Enabling PSRemoting on PCs from $PCListFile ---" -ForegroundColor Cyan

foreach ($i in Get-Content $PCListFile) {
    if (Test-Connection -ComputerName $i -Quiet -Count 1) {
        Write-Host "Enabling PSRemoting on $i ..." -ForegroundColor Yellow
        psexec \\$i -u $AdminUser -p $AdminPass -h PowerShell "Enable-PSRemoting -Force"
    } else {
        Write-Host "Skipping $i (unreachable)" -ForegroundColor Red
    }
}

Write-Host "Done." -ForegroundColor Green
