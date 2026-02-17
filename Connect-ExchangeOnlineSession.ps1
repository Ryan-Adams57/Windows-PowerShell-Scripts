<#
=============================================================================================
Name:           Connect to Exchange Online PowerShell (EXO V3+)
Version:        3.0
Author:         Ryan Adams
Website:        https://www.governmentcontrol.net/
GitHub:         https://github.com/Ryan-Adams57
GitLab:         https://gitlab.com/Ryan-Adams57
PasteBin:       https://pastebin.com/u/Removed_Content
Description:    Validates Exchange Online Management module (v3 or later)
                and establishes a secure connection to Exchange Online.
=============================================================================================
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [switch]$Disconnect,

    [Parameter(Mandatory = $false)]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $false)]
    [string]$AppId,

    [Parameter(Mandatory = $false)]
    [string]$TenantName,

    [Parameter(Mandatory = $false)]
    [string]$CertificateThumbprint
)

#region Module Validation

# Ensure ExchangeOnlineManagement v3+ is installed (RPS & Basic Auth retired)
$Module = Get-Module ExchangeOnlineManagement -ListAvailable |
          Where-Object { $_.Version.Major -ge 3 }

if (-not $Module)
{
    Write-Host "Exchange Online PowerShell module (v3+) not detected." -ForegroundColor Yellow
    $Confirm = Read-Host "Install ExchangeOnlineManagement module now? [Y] Yes [N] No"

    if ($Confirm -match '^[Yy]$')
    {
        Write-Host "Installing ExchangeOnlineManagement module..."
        Install-Module ExchangeOnlineManagement -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
    }
    else
    {
        Write-Host "ExchangeOnlineManagement v3+ is required. Aborting." -ForegroundColor Red
        return
    }
}

Import-Module ExchangeOnlineManagement

#endregion Module Validation

#region Disconnect Logic

if ($Disconnect.IsPresent)
{
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Exchange Online session disconnected." -ForegroundColor Yellow
    return
}

#endregion Disconnect Logic

#region Connection Logic

Write-Host "`nConnecting to Exchange Online..." -ForegroundColor Green

try
{
    if ($AppId -and $CertificateThumbprint -and $TenantName)
    {
        # Certificate-Based Authentication (App-Only)
        Connect-ExchangeOnline `
            -AppId $AppId `
            -CertificateThumbprint $CertificateThumbprint `
            -Organization $TenantName `
            -ShowBanner:$false
    }
    elseif ($UserPrincipalName)
    {
        # User-specific interactive login
        Connect-ExchangeOnline `
            -UserPrincipalName $UserPrincipalName `
            -ShowBanner:$false
    }
    else
    {
        # Default interactive login (MFA supported)
        Connect-ExchangeOnline -ShowBanner:$false
    }

    # Connectivity validation
    if (Get-EXOMailbox -ResultSize 1 -ErrorAction SilentlyContinue)
    {
        Write-Host "Exchange Online connection established successfully." -ForegroundColor Cyan
    }
    else
    {
        Write-Host "Connected, but unable to validate mailbox access." -ForegroundColor Yellow
    }
}
catch
{
    Write-Host "Failed to connect to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
}

#endregion Connection Logic
