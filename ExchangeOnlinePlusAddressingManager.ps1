<#
=============================================================================================
Name:     Exchange Online Plus Addressing Manager
Version:  1.0
Author:   Ryan Adams
Website:  https://www.governmentcontrol.net/
GitHub:   https://github.com/Ryan-Adams57
GitLab:   https://gitlab.com/Ryan-Adams57
PasteBin: https://pastebin.com/u/Removed_Content

~~~~~~~~~~~~~~~~~~
Script Highlights:
~~~~~~~~~~~~~~~~~~
1. Checks whether Plus Addressing is enabled in your Exchange Online organization.
2. Allows enabling or disabling Plus Addressing.
3. Requires Exchange Online PowerShell V2 module (installed automatically if missing).
============================================================================================
#>

Param
(
    [Parameter(Mandatory = $false)]
    [switch]$CheckStatus,
    [switch]$Enable,
    [switch]$Disable
)

# Check for Exchange Online Management module (EXO V2)
$Module = Get-Module -Name ExchangeOnlineManagement -ListAvailable
if ($Module.Count -eq 0) {
    Write-Host "Exchange Online PowerShell V2 module is not available." -ForegroundColor Yellow
    $Confirm = Read-Host "Do you want to install the module? [Y] Yes [N] No"
    if ($Confirm -match "[yY]") {
        Write-Host "Installing Exchange Online Management module..."
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
    }
    else {
        Write-Host "EXO V2 module is required to connect to Exchange Online. Please install using `Install-Module ExchangeOnlineManagement`." -ForegroundColor Red
        Exit
    }
}

# Connect to Exchange Online
Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
Connect-ExchangeOnline -ErrorAction Stop

# Check Plus Addressing status
if ($CheckStatus.IsPresent) {
    $Status = Get-OrganizationConfig | Select-Object -Property AllowPlusAddressInRecipients
    if ($Status.AllowPlusAddressInRecipients -eq $true) {
        Write-Host "Plus Addressing is currently ENABLED in your organization." -ForegroundColor Green
    }
    else {
        Write-Host "Plus Addressing is currently DISABLED in your organization." -ForegroundColor Red
    }
}

# Enable Plus Addressing
if ($Enable.IsPresent) {
    Set-OrganizationConfig -AllowPlusAddressInRecipients $true
    if ($?) {
        Write-Host "Plus Addressing has been ENABLED successfully." -ForegroundColor Yellow
    }
    else {
        Write-Host "Failed to enable Plus Addressing." -ForegroundColor Red
    }
}

# Disable Plus Addressing
if ($Disable.IsPresent) {
    Set-OrganizationConfig -AllowPlusAddressInRecipients $false
    if ($?) {
        Write-Host "Plus Addressing has been DISABLED successfully." -ForegroundColor Yellow
    }
    else {
        Write-Host "Failed to disable Plus Addressing." -ForegroundColor Red
    }
}

# Disconnect session (optional cleanup)
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "`nScript execution completed." -ForegroundColor Cyan
