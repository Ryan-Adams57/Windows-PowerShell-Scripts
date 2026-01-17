<#
Name:           Invoke-M365UserOffboarding
Description:    Disables user, revokes sessions, and converts mailbox to Shared.
Version:        1.0
#>
param(
    [Parameter(Mandatory=$true)] [string]$UserPrincipalName
)

Try {
    if (-not (Get-MgContext)) { Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" }
    Connect-ExchangeOnline

    Write-Host "Offboarding $UserPrincipalName..." -ForegroundColor Cyan
    Revoke-MgUserSignInSession -UserId $UserPrincipalName
    Update-MgUser -UserId $UserPrincipalName -AccountEnabled $false
    
    Set-Mailbox -Identity $UserPrincipalName -Type Shared
    
    $User = Get-MgUser -UserId $UserPrincipalName -Property "AssignedLicenses"
    if ($User.AssignedLicenses) {
        Set-MgUserLicense -UserId $UserPrincipalName -RemoveLicenses $User.AssignedLicenses.SkuId -AddLicenses @()
    }
    Write-Host "Offboarding complete. Account disabled, license reclaimed, mailbox converted." -ForegroundColor Green
} Catch { Write-Error $_.Exception.Message }
