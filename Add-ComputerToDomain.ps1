# Add-ComputerToDomain.ps1
# Joins a computer to a domain with optional rename
# Must be run as Administrator

# --- Configuration ---
$DomainName    = "<DomainName>"       # e.g., "contoso.com"
$NewPCName     = "<NewPCName>"        # e.g., "DESKTOP-001"
# ---------------------

$DomainCredential = Get-Credential -Message "Enter Domain Admin credentials"

Add-Computer `
    -DomainName $DomainName `
    -Credential $DomainCredential `
    -NewName $NewPCName `
    -Force `
    -Restart

# To add multiple computers from a list:
# Add-Computer -ComputerName <Computers> -LocalCredential <LocalAdminAccount> `
#   -DomainName $DomainName -Credential $DomainCredential `
#   -NewName $NewPCName -Force -Restart
