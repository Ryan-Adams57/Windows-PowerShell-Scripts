# Remove-ComputerFromDomain.ps1
# Removes the local computer from the domain and joins WORKGROUP
# Must be run as Administrator

# --- Configuration ---
$LocalAdmin = "<LocalAdminAccount>"  # e.g., "LocalAdmin"
# ---------------------

$LocalCredential  = Get-Credential -UserName $LocalAdmin -Message "Enter local admin credentials"
$DomainCredential = Get-Credential -Message "Enter domain admin credentials (Domain\ADAdmin)"

Write-Host "--- Removing Computer from Domain ---" -ForegroundColor Cyan

Remove-Computer `
    -LocalCredential $LocalCredential `
    -UnjoinDomainCredential $DomainCredential `
    -WorkGroup "WORKGROUP" `
    -Force `
    -Restart

Write-Host "Computer will restart and rejoin WORKGROUP." -ForegroundColor Green
